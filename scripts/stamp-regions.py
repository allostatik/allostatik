#!/usr/bin/env python3
"""stamp-regions.py — the reference implementation for Allostatik's stamped regions.

Three regions are upstream-owned. Everything else in an install belongs to the adopter.

  name       file (relative to a project root / the template root)     markers
  part1      allostatik/workflow.md                                    BEGIN/END allostatik-part1
  claude-md  CLAUDE.md                                                 BEGIN/END allostatik
  agents-md  AGENTS.md                                                 BEGIN/END allostatik

A stamp lives on the BEGIN marker line:

  <!-- BEGIN allostatik-part1 v0.3.4 sha256:1a2b3c4d5e6f -->
  <!-- BEGIN allostatik v0.3.4 sha256:1a2b3c4d5e6f (managed — …) -->

THE HASH (the one definition everything else copies): sha256 over the bytes strictly
between the two marker lines — from the character after the BEGIN line's newline up to,
not including, the first character of the END line — with CRLF normalized to LF (and
only CRLF: a lone CR is content), UTF-8, truncated to the first 12 hex characters.
`sed 's/\\r$//' | sha256sum` over those lines agrees. It is a drift fingerprint, not a
signature: whoever supplies a body can supply its matching stamp.

A stamp always records UPSTREAM's values. Installs copy them; nothing in an install ever
computes or invents a stamp (rule 4 of the placed Upgrade contract). So `--write` exists
for the template repo only; the install-facing modes never write.

Modes
  (none) / --verify   verify the TEMPLATE regions under --root (default: this repo):
                      markers well-formed, stamp version == package version, body hash ==
                      stamp hash, no invisible characters in any template file or fetched
                      doc. Exit 1 on any failure. This is the suite's and the close's check.
  --write             restamp the template regions with the package version + computed
                      hash (template mode only), then verify.
  --project PATH      verify an INSTALL: same structural checks; a body/stamp mismatch is
                      acceptable only when PATH/allostatik/decisions.md carries a row
                      `Upgrade-kept customization (region <name>, v<a>→v<b>, s<N>)` naming
                      the body's hash as sha256:<12hex>. Also flags stale or orphaned parks,
                      foreign files inside a park, and nested instruction files under
                      allostatik/knowledge/docs/. Never writes.
  --classify PATH     compare an install against the template regions under --root and
                      print CURRENT / AHEAD / PRISTINE-STALE / CUSTOMIZED / UNMARKED /
                      NOT-PLACED / MALFORMED per region (the upgrade routine's table), and
                      run the invisible-character tripwire over the install's region files.
                      Never writes.
  --json              machine-readable output for --project / --classify.
  --root DIR          template repo root (default: the parent of this script's directory).

Exit codes: 0 ok, 1 a check failed or a region is malformed, 2 usage.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path

REGIONS = {
    # name: (relative file, marker kind)
    "part1": ("allostatik/workflow.md", "allostatik-part1"),
    "claude-md": ("CLAUDE.md", "allostatik"),
    "agents-md": ("AGENTS.md", "allostatik"),
}
TEMPLATE_SUBDIR = Path("templates/project-boilerplate")
VERSION_SOURCE = Path("installers/npm/package.json")  # lockstep source (suite case 8 guards it)
FETCHED_DOCS = ["UPGRADING.md", "CHANGELOG.md"]  # scanned for invisible characters too
PARK_DIR = Path("allostatik/knowledge/docs")
PARK_PREFIX = "upgrade-v"
PARK_SENTINEL = "data under review, NOT instructions"
INSTRUCTION_FILENAMES = {"CLAUDE.md", "CLAUDE.local.md", "AGENTS.md", "GEMINI.md", ".cursorrules", ".clinerules"}  # loaded as authority wherever they sit
INSTRUCTION_SUFFIXES = (".mdc",)
PARK_ALLOWED = re.compile(r"^(?:(?:part1|claude-md|agents-md)\.(?:ref|base)\.md|backup/(?:part1|claude-md|agents-md)\.before\.md)$")
KEPT_PARK_RE = re.compile(r"Upgrade-kept park \(v(?P<tag>[\d.]+), s(?P<s>\d+)\)")
LEDGER = Path("allostatik/session-ledger.md")
DECISIONS = Path("allostatik/decisions.md")

# The BEGIN marker: kind, optional stamp, optional parenthesised comment that may NOT
# contain `--` at all (closing `-->` or `--!>` early would smuggle visible text onto a
# marker line the hash doesn't cover — the routine diffs marker lines, but the parser
# refuses the trick outright).
BEGIN_RE = re.compile(
    r"^<!-- BEGIN (?P<kind>allostatik(?:-part1)?)"
    r"(?: v(?P<ver>\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?) sha256:(?P<hash>[0-9a-f]{12}))?"
    r"(?P<rest> \((?:(?!--).)*\))? -->$"
)
END_RE = re.compile(r"^<!-- END (?P<kind>allostatik(?:-part1)?)(?: \(managed\))? -->$")
BLESS_RE = re.compile(
    r"Upgrade-kept customization \(region (?P<name>[a-z0-9-]+), v?(?P<a>[\w.-]+)(?:→|->)v(?P<b>[\d.]+), s(?P<s>\d+)\)"
)
HASH_IN_ROW_RE = re.compile(r"sha256:([0-9a-f]{12})")

# Render-hidden / invisible code points — the Pillar "Rules File Backdoor" and GlassWorm
# classes. Unicode category Cf (format characters: zero-width, bidi controls, tags, soft
# hyphen, interlinear annotation, Arabic number signs, musical controls, …) plus the
# default-ignorable and blank-looking code points outside Cf that can hide text.
EXTRA_INVISIBLE = {
    0x034F,  # combining grapheme joiner
    0x115F, 0x1160,  # Hangul choseong/jungseong fillers
    0x2028, 0x2029,  # line / paragraph separators
    0x2800,  # braille pattern blank
    0x3164,  # Hangul filler
    0xFFA0,  # halfwidth Hangul filler
}
EXTRA_INVISIBLE_RANGES = [
    (0x17B4, 0x17B5),  # Khmer inherent vowels (default-ignorable)
    (0x2065, 0x2065),  # unassigned in the word-joiner block (default-ignorable)
    (0xFE00, 0xFE0F),  # variation selectors
    (0xFFF0, 0xFFF8),  # unassigned specials (default-ignorable)
    (0xE0000, 0xE0FFF),  # tags, variation selectors supplement, and the unassigned rest of the block
]


def _is_invisible(ch: str) -> bool:
    cp = ord(ch)
    if unicodedata.category(ch) == "Cf":
        return True
    if cp in EXTRA_INVISIBLE:
        return True
    return any(lo <= cp <= hi for lo, hi in EXTRA_INVISIBLE_RANGES)


def invisible_hits(text: str) -> list[tuple[int, int, str]]:
    """(line, column, U+XXXX) for every invisible code point in text."""
    hits = []
    for ln, line in enumerate(text.split("\n"), 1):
        for col, ch in enumerate(line, 1):
            if _is_invisible(ch):
                hits.append((ln, col, f"U+{ord(ch):04X}"))
    return hits


def body_hash(body: str) -> str:
    return hashlib.sha256(body.encode("utf-8")).hexdigest()[:12]


def read_text_strict(path: Path) -> str:
    """UTF-8, CRLF→LF only. Raises UnicodeDecodeError on non-UTF-8 bytes."""
    return path.read_bytes().decode("utf-8").replace("\r\n", "\n")


class Region:
    """One parsed region: markers, stamp, body. `error` set when malformed or unmarked."""

    def __init__(self, name: str, path: Path, kind: str):
        self.name, self.path, self.kind = name, path, kind
        self.present = path.is_file()
        self.error: str | None = None
        self.begin_idx = self.end_idx = -1
        self.version: str | None = None
        self.stamp: str | None = None
        self.body: str | None = None
        self.text: str | None = None
        if self.present:
            self._parse()

    def _parse(self) -> None:
        try:
            self.text = read_text_strict(self.path)
        except UnicodeDecodeError as e:
            self.error = f"malformed: not valid UTF-8 ({e.reason} at byte {e.start})"
            return
        lines = self.text.split("\n")
        begins = [(i, m) for i, l in enumerate(lines) for m in [BEGIN_RE.match(l)] if m and m.group("kind") == self.kind]
        ends = [(i, m) for i, l in enumerate(lines) for m in [END_RE.match(l)] if m and m.group("kind") == self.kind]
        if not begins and not ends:
            self.error = "no markers"  # UNMARKED (part1) or NOT-PLACED (fences) — callers decide
            return
        if len(begins) != 1 or len(ends) != 1:
            self.error = f"malformed: {len(begins)} BEGIN / {len(ends)} END markers for {self.kind}"
            return
        (bi, bm), (ei, _) = begins[0], ends[0]
        if ei <= bi:
            self.error = "malformed: END before BEGIN"
            return
        self.begin_idx, self.end_idx = bi, ei
        self.version, self.stamp = bm.group("ver"), bm.group("hash")
        # bytes strictly between the marker lines; the last body line keeps its newline
        self.body = "\n".join(lines[bi + 1 : ei]) + ("\n" if ei > bi + 1 else "")

    @property
    def stamped(self) -> bool:
        return self.stamp is not None

    @property
    def unmarked(self) -> bool:
        return self.error == "no markers"

    @property
    def malformed(self) -> bool:
        return bool(self.error) and self.error != "no markers"

    @property
    def hash(self) -> str | None:
        return body_hash(self.body) if self.body is not None else None


def package_version(root: Path) -> str:
    data = json.loads((root / VERSION_SOURCE).read_text(encoding="utf-8"))
    return data["version"]


def load_regions(base: Path) -> dict[str, Region]:
    return {n: Region(n, base / rel, kind) for n, (rel, kind) in REGIONS.items()}


def blessing_rows(project: Path) -> list[dict]:
    """Every live `Upgrade-kept customization …` row in decisions.md, with its hashes.
    A row carrying a SUPERSEDED marker no longer blesses anything."""
    f = project / DECISIONS
    if not f.is_file():
        return []
    rows = []
    for line in f.read_text(encoding="utf-8", errors="replace").split("\n"):
        m = BLESS_RE.search(line)
        if m and "[SUPERSEDED" not in line:
            rows.append({**m.groupdict(), "hashes": HASH_IN_ROW_RE.findall(line), "line": line})
    return rows


def park_state(project: Path) -> str:
    """'in-flight' = the last `STEP upgrade` has no `STEP-DONE upgrade` and no `OPENED` after it
    (the upgrade belongs to the current session); 'stale' = a later `OPENED` follows it (a
    previous session died mid-upgrade — surface and ask, never resume silently); 'none' otherwise."""
    f = project / LEDGER
    if not f.is_file():
        return "none"
    state = "none"
    for line in f.read_text(encoding="utf-8", errors="replace").split("\n"):
        if line.startswith("STEP upgrade "):
            state = "in-flight"
        elif line.startswith("STEP-DONE upgrade"):
            state = "none"
        elif line.startswith("OPENED ") and state == "in-flight":
            state = "stale"
    return state


def kept_parks(project: Path) -> set[str]:
    """Tags whose park the adopter chose to keep (`Upgrade-kept park (v<tag>, s<N>)` rows)."""
    f = project / DECISIONS
    if not f.is_file():
        return set()
    return {m.group("tag") for line in f.read_text(encoding="utf-8", errors="replace").split("\n")
            for m in [KEPT_PARK_RE.search(line)] if m and "[SUPERSEDED" not in line}


def park_findings(project: Path) -> dict:
    """Parks and nested instruction files under allostatik/knowledge/docs/."""
    out = {"stale": [], "orphaned": [], "foreign": [], "nested": [], "state": park_state(project)}
    d = project / PARK_DIR
    if not d.is_dir():
        return out
    kept = kept_parks(project)
    for p in sorted(d.iterdir()):
        if not (p.is_dir() and p.name.startswith(PARK_PREFIX)):
            continue
        tag = p.name[len(PARK_PREFIX):]
        if tag in kept:
            pass  # deliberately kept
        elif out["state"] == "stale":
            out["stale"].append(p)
        elif out["state"] == "none":
            out["orphaned"].append(p)
        for f in sorted(q for q in p.rglob("*") if q.is_file()):
            if not PARK_ALLOWED.match(f.relative_to(p).as_posix()):
                out["foreign"].append(f)
    out["nested"] = sorted(q for q in d.rglob("*") if q.is_file() and (q.name in INSTRUCTION_FILENAMES or q.name.endswith(INSTRUCTION_SUFFIXES)))
    return out


# ---------------------------------------------------------------- reporting
class Report:
    def __init__(self):
        self.ok_n = self.fail_n = 0
        self.lines: list[str] = []

    def ok(self, msg: str) -> None:
        self.ok_n += 1
        self.lines.append(f"  ok    {msg}")

    def fail(self, msg: str) -> None:
        self.fail_n += 1
        self.lines.append(f"  FAIL  {msg}")

    @property
    def failures(self) -> list[str]:
        return [l.strip() for l in self.lines if l.startswith("  FAIL")]

    def finish(self) -> int:
        print("\n".join(self.lines))
        print(f"\npassed: {self.ok_n}  failed: {self.fail_n}")
        return 0 if self.fail_n == 0 else 1


def _tripwire(rep: Report, label: str, text: str) -> None:
    hits = invisible_hits(text)
    if hits:
        ln, col, cp = hits[0]
        rep.fail(f"{label}: invisible character {cp} at line {ln}:{col} ({len(hits)} total)")


# ---------------------------------------------------------------- modes
def verify_template(root: Path, write: bool) -> int:
    rep = Report()
    base = root / TEMPLATE_SUBDIR
    if not (base / "allostatik").is_dir():
        print(f"error: {base} not found — pass --root <allostatik repo>", file=sys.stderr)
        return 2
    ver = package_version(root)
    regions = load_regions(base)

    if write:
        for r in regions.values():
            if not r.present or r.error:
                continue
            lines = r.text.split("\n")
            m = BEGIN_RE.match(lines[r.begin_idx])
            rest = m.group("rest") or ""
            lines[r.begin_idx] = f"<!-- BEGIN {r.kind} v{ver} sha256:{r.hash}{rest} -->"
            r.path.write_text("\n".join(lines), encoding="utf-8")
        regions = load_regions(base)  # re-read what we wrote

    for r in regions.values():
        label = f"{r.name} ({r.path.relative_to(root)})"
        if not r.present:
            rep.fail(f"{label}: file missing")
            continue
        if r.error:
            rep.fail(f"{label}: {r.error}")
            continue
        rep.ok(f"{label}: markers well-formed")
        if not r.stamped:
            rep.fail(f"{label}: BEGIN marker carries no version/hash stamp")
            continue
        if r.version == ver:
            rep.ok(f"{label}: stamp version v{r.version} == package version")
        else:
            rep.fail(f"{label}: stamp says v{r.version}, package says v{ver} (run --write after bumping)")
        if r.stamp == r.hash:
            rep.ok(f"{label}: body hash {r.hash} == stamp")
        else:
            rep.fail(f"{label}: body hash {r.hash} != stamp {r.stamp} — region edited without restamp (run --write)")

    # invisible-character tripwire: every template file + the fetched docs
    scanned = sorted(p for p in base.rglob("*") if p.is_file()) + [root / d for d in FETCHED_DOCS if (root / d).is_file()]
    before = rep.fail_n
    for p in scanned:
        _tripwire(rep, str(p.relative_to(root)), p.read_text(encoding="utf-8", errors="replace"))
    if rep.fail_n == before:
        rep.ok(f"no invisible characters in {len(scanned)} template/fetched files")
    return rep.finish()


def verify_project(project: Path, as_json: bool) -> int:
    rep = Report()
    regions = load_regions(project)
    rows = blessing_rows(project)
    results = {}
    for r in regions.values():
        label = f"{r.name} ({r.path.relative_to(project)})"
        if not r.present:
            if r.name == "part1":
                rep.fail(f"{label}: file missing")
                results[r.name] = "missing"
            else:
                rep.ok(f"{label}: file not present (skipped)")
                results[r.name] = "absent"
            continue
        if r.malformed:
            rep.fail(f"{label}: {r.error}")
            results[r.name] = "malformed"
            continue
        if r.unmarked and r.name != "part1":
            rep.ok(f"{label}: no markers — the adopter's own file, not a region (the block was never merged; sidecar allostatik/{r.path.name}.allostatik-block is the copy to merge)")
            results[r.name] = "not-placed"
            continue
        if r.unmarked or not r.stamped:
            rep.fail(f"{label}: unmarked/unstamped — pre-0.3.4 install; run the bootstrap upgrade (UPGRADING.md)")
            results[r.name] = "unmarked"
            continue
        if r.hash == r.stamp:
            rep.ok(f"{label}: body hashes to its stamp ({r.hash}, v{r.version})")
            results[r.name] = "as-shipped"
        else:
            blessed = [row for row in rows if row["name"] == r.name and r.hash in row["hashes"]]
            if blessed:
                b = blessed[-1]
                rep.ok(f"{label}: customized body {r.hash} blessed by decisions row (v{b['a']}→v{b['b']}, s{b['s']})")
                results[r.name] = "customized-blessed"
            else:
                rep.fail(f"{label}: UNRECORDED FORK — body {r.hash} != stamp {r.stamp} and no blessing row names sha256:{r.hash}")
                results[r.name] = "unrecorded-fork"
        _tripwire(rep, label, r.text or "")
    pf = park_findings(project)
    for p in pf["stale"]:
        rep.fail(f"STALE park from an earlier session — resume deliberately or remove; never continue silently: {p.relative_to(project)}/")
    for p in pf["orphaned"]:
        rep.fail(f"orphaned park (no upgrade in flight, no kept-park row): {p.relative_to(project)}/")
    for p in pf["foreign"]:
        rep.fail(f"file that doesn't belong in a park: {p.relative_to(project)}")
    for p in pf["nested"]:
        rep.fail(f"nested instruction file under knowledge/docs (a surface may load it as authority): {p.relative_to(project)}")
    if not any(pf[k] for k in ("stale", "orphaned", "foreign", "nested")):
        rep.ok("no stale/orphaned park, nothing foreign in a park, no nested instruction file under allostatik/knowledge/docs/")
    if as_json:
        print(json.dumps({"project": str(project), "regions": results, "park_state": pf["state"],
                          **{k: [str(p.relative_to(project)) for p in pf[k]] for k in ("stale", "orphaned", "foreign", "nested")},
                          "failures": rep.failures, "passed": rep.ok_n, "failed": rep.fail_n}, indent=2))
        return 0 if rep.fail_n == 0 else 1
    return rep.finish()


def _vtuple(v: str) -> tuple:
    m = re.match(r"(\d+)\.(\d+)\.(\d+)", v or "")
    return tuple(int(x) for x in m.groups()) if m else (0, 0, 0)


def classify(project: Path, root: Path, as_json: bool) -> int:
    base = root / TEMPLATE_SUBDIR
    if not (base / "allostatik").is_dir():
        print(f"error: {base} not found — pass --root <allostatik repo>", file=sys.stderr)
        return 2
    up = load_regions(base)
    bad = [n for n, r in up.items() if not r.present or r.error or not r.stamped]
    if bad:
        print(f"error: the reference under {root} is not a stamped template ({', '.join(bad)}) — classification needs upstream's stamps", file=sys.stderr)
        return 2
    inst = load_regions(project)
    rows = blessing_rows(project)
    out = {}
    halt = False
    for name in REGIONS:
        u, i = up[name], inst[name]
        entry = {"file": str(REGIONS[name][0]), "upstream_version": u.version, "upstream_hash": u.hash}
        if not i.present:
            entry.update(cls="ABSENT", note="file not present on this project")
        elif i.malformed:
            entry.update(cls="MALFORMED", note=i.error + " — halt; repair by hand first")
            halt = True
        elif i.unmarked and name != "part1":
            entry.update(cls="NOT-PLACED", note="the adopter's own file; the block was never merged — offer the sidecar, not an upgrade")
        elif i.unmarked or not i.stamped:
            entry.update(cls="UNMARKED", note="bootstrap: bounded walk, ends stamped")
        else:
            entry.update(install_version=i.version, install_stamp=i.stamp, install_hash=i.hash)
            if i.body == u.body:
                note = "no-op" if i.stamp == u.stamp and i.version == u.version else "body current; stamp stale — offer a mechanical restamp"
                entry.update(cls="CURRENT", note=note)
            elif _vtuple(i.version) > _vtuple(u.version):
                entry.update(cls="AHEAD", note="install stamp newer than this reference — fetch a newer reference; halt")
                halt = True
            elif i.hash == i.stamp:
                entry.update(cls="PRISTINE-STALE", note="show verbatim diff, gated apply")
            else:
                blessed = [r for r in rows if r["name"] == name and i.hash in r["hashes"]]
                base_v = None
                if blessed:
                    mb = re.search(r"base v(pre-stamp|[\d.]+)", blessed[-1]["line"])
                    base_v = mb.group(1) if mb else blessed[-1]["b"]
                entry.update(cls="CUSTOMIZED", blessed=bool(blessed), base=base_v or i.version,
                             note="never auto-apply; walk a reconciliation; record it"
                             + (" (current body is blessed by a decisions row)" if blessed else " (current body has NO blessing row)"))
        if i.present and i.text and not i.malformed:
            hits = invisible_hits(i.text)
            if hits:
                ln, col, cp = hits[0]
                entry["invisible"] = f"{cp} at line {ln}:{col} ({len(hits)} total) — halt"
                halt = True
        out[name] = entry
    if as_json:
        print(json.dumps({"project": str(project), "reference": str(root), "halt": halt, "regions": out}, indent=2))
    else:
        print(f"classification of {project} against {root}:")
        for name, e in out.items():
            print(f"  {name:10s} {e['cls']:15s} {e.get('note','')}")
            if "install_hash" in e:
                print(f"  {'':10s} install v{e['install_version']} stamp {e['install_stamp']} body {e['install_hash']} | upstream v{e['upstream_version']} body {e['upstream_hash']}" + (f" | base v{e['base']}" if e.get("cls") == "CUSTOMIZED" else ""))
            if "invisible" in e:
                print(f"  {'':10s} INVISIBLE CHARACTER {e['invisible']}")
    return 1 if halt else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent, help="template repo root")
    ap.add_argument("--verify", action="store_true", help="verify the template regions (the default; named for discoverability)")
    ap.add_argument("--write", action="store_true", help="restamp the template regions (template mode only)")
    ap.add_argument("--project", type=Path, help="verify an install at PATH (never writes)")
    ap.add_argument("--classify", type=Path, help="classify an install at PATH against the template (never writes)")
    ap.add_argument("--json", action="store_true", help="machine-readable output (--project / --classify)")
    a = ap.parse_args(argv)
    if a.write and (a.project or a.classify):
        ap.error("--write is template-mode only: stamps are copied into installs, never computed there")
    if a.project and a.classify:
        ap.error("pick one of --project / --classify")
    if a.project:
        return verify_project(a.project.resolve(), a.json)
    if a.classify:
        return classify(a.classify.resolve(), a.root.resolve(), a.json)
    return verify_template(a.root.resolve(), a.write)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""make-index.py — derive allostatik/decisions-and-observations-index.md from the record (s108).

`decisions.md` and `observations.md` are NOT modified, split, moved or abridged.
They keep their names, their history and every existing reference, and become
read-on-demand. This script derives an index of them, and the index is what a
session loads.

Each index line is that entry's own first sentence, VERBATIM, plus two additions
that are computed, never written:

  **[AMENDED sNN]** / **[SUPERSEDED sNN]**  the body reverses or changes what the
      title says. 28 of 233 decision titles are wrong on their own without this;
      it is the one failure the s108 fresh-reader test actually found.
  body NNNw   the length of what is being withheld, so a line never reads complete.

This is the REFERENCE IMPLEMENTATION of the index format, and it lives in the
tool's repo the way scripts/stamp-regions.py does. An install places markdown and
nothing else -- 13 files, all .md -- so this script is never copied into a project.
Read it for the format and produce the index directly; the upgrade contract's rule 3
forbids running anything fetched from the tool's repo, and that covers this file.

The scriptless check that matters is completeness, and it needs no Python: the index
must carry exactly one line per entry. Count both sides and compare --
  grep -c '^[0-9]\+\.' allostatik/observations.md
  grep -c '^| ' allostatik/decisions.md
An index short by even one entry is silently wrong, which is the one failure mode a
title index cannot survive.

Usage:  make-index.py                    regenerate the index
        make-index.py --verify           exit 1 if the index is stale (drift-check)
        make-index.py --root <project>   operate on another project's allostatik/
"""
import argparse, io, os, re, sys

_here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_root = _here
for _i, _a in enumerate(sys.argv):
    if _a == "--root" and _i + 1 < len(sys.argv) and not sys.argv[_i + 1].startswith("-"):
        _root = os.path.abspath(sys.argv[_i + 1])
    elif _a.startswith("--root="):
        _root = os.path.abspath(_a.split("=", 1)[1])
A = os.path.join(_root, "allostatik")
if not os.path.isdir(A):
    sys.stderr.write("no allostatik/ under %s -- pass --root <project>; a copy of this script "
                     "outside its own repo indexes nothing without it\n" % _root)
    sys.exit(2)          # 2 = usage, never 1: a bad root must not read as "stale"
OUT = os.path.join(A, "decisions-and-observations-index.md")
MARK = re.compile(r"\[(AMENDED|SUPERSEDED|RETIRED|CORRECTED|CLOSES)([^\]]{0,40})")
# The bracket convention is not applied consistently -- 36 decision bodies state a
# revision in prose with no bracket. So there is a second, deliberately OVER-inclusive
# flag. A false positive costs one cheap lookup; a false negative is a title that lies.
PROSE = re.compile(r"\b(superseded|no longer|retired|reversed|obsolete|replaced by)\b", re.I)

def flag(body):
    m = MARK.search(body)
    if not m:
        return " **[?revised]**" if PROSE.search(body) else ""
    s = re.search(r"\bs(\d{1,3})\b", m.group(2))
    d = re.search(r"(\d{4}-\d{2}-\d{2})", m.group(2))
    when = (" s" + s.group(1)) if s else ((" " + d.group(1)) if d else "")
    return " **[%s%s]**" % (m.group(1), when)

def rows(path):
    """(lineno, text) for real content lines, skipping HTML-commented scaffolding.

    A comment counts only when a line *begins* with `<!--`, and it runs to the line
    carrying `-->`. That is the shape of the shipped templates' example rows, and the
    only shape worth skipping. Stripping `<!--` wherever it appears is wrong here and
    was tried: `decisions.md` discusses markers inside its own table cells, one of
    them unclosed on its line, and a naive stripper silently swallowed 53 of 234
    decisions from that point to end of file.
    """
    inc = False
    for ln, l in enumerate(io.open(path, encoding="utf-8"), 1):
        if inc:
            if "-->" in l:
                inc = False
            continue
        if l.lstrip().startswith("<!--"):
            if "-->" not in l:
                inc = True
            continue
        yield ln, l


def build():
    L = []
    L.append("# Decisions and observations — index of every entry this project holds\n")
    L.append("**This is an index, not the record.** Each line is that entry's own first\n"
             "sentence, verbatim — never a summary, never rewritten. The reasoning, evidence,\n"
             "scope and exceptions are NOT here; they are in `decisions.md` and\n"
             "`observations.md`, which are complete, unmodified and still in force. Nothing\n"
             "has been retired, moved or demoted.\n")
    L.append("`body NNNw` is the length of what this line is not showing. A **[AMENDED]** or\n"
             "**[SUPERSEDED]** flag means the body changes or reverses what the title says —\n"
             "**those are never safe to act on from this file.** {FLAGGED}\n")
    L.append("Look one up by the line address on its own line — exact, and unaffected by any\n"
             "punctuation in a title that a literal `grep` would trip over:\n\n"
             "    sed -n '127p' allostatik/decisions.md\n"
             "    sed -n '412p' allostatik/observations.md\n\n"
             "Line addresses are regenerated with this file, so they are current whenever the\n"
             "open's verify passes. `D` numbers are positional in file order; both files are\n"
             "append-only, so they are stable in practice, but an insert would renumber below it.\n")
    L.append("Generated by `scripts/make-index.py`; regenerated at close and checked\n"
             "at the open. Do not hand-edit — edits belong in the two files above.\n")

    # decisions: table rows, in file order
    L.append("\n## Decisions\n")
    n = 0
    seen_rule = False
    for ln, l in rows(os.path.join(A, "decisions.md")):
        if l.startswith("|---") or l.startswith("| ---"):
            seen_rule = True          # everything above the rule is the table header
            continue
        if not l.startswith("| ") or not seen_rule:
            continue                  # keyed on table structure, never on a column's name
        n += 1
        f = l.rstrip("\n").split(" | ")
        title = f[0][2:].strip()
        body = " | ".join(f[1:]).rstrip(" |") if len(f) > 1 else ""
        L.append("D%03d · %s%s → decisions.md:%d, body %dw"
                 % (n, title, flag(body), ln, len(body.split())))

    # observations: numbered entries, sections preserved
    # Observations. `Promoted` / `Candidates` / `Watch list` are sections INSIDE
    # observations.md, so the index states that before reproducing them -- without the
    # heading a reader crosses from one record into the other with no marker, which
    # confused the record's own owner within 30 seconds of first reading it.
    L.append("\n## Observations\n")
    L.append("*`Promoted` and `Candidates` are both observations; the split is maturity, not\n"
             "kind. Promotion means three or more firings across separate sessions.*\n")
    started, sec, buf, secs = False, None, [], []
    for ln, l in rows(os.path.join(A, "observations.md")):
        l = l.rstrip("\n")
        if l.startswith("## "):
            if sec:
                secs.append((sec, buf))
            started, sec, buf = True, l, []
            continue
        if not started:
            continue
        m = (re.match(r"^(\d+)\.\s+(\*\*.*?\*\*)(.*)$", l)
             or re.match(r"^(\d+)\.\s+([^*].*?\.)(\s.*)?$", l))
        if m:
            b = (m.group(3) or "").strip()
            buf.append(("E", "#%s · %s%s → observations.md:%d, body %dw"
                        % (m.group(1), m.group(2).strip(), flag(b), ln, len(b.split()))))
        elif l.strip() and not l.startswith("---"):
            buf.append(("T", l))          # section prose, e.g. the Watch list's id roster
    if sec:
        secs.append((sec, buf))

    for sec, buf in secs:
        L.append("\n" + sec + "\n")
        entries = [x for k, x in buf if k == "E"]
        if entries:
            L.extend(entries)
        else:
            # A section with no numbered entries is NOT empty -- the Watch list carries a
            # roster of ids and their promotion notes. Emitting the heading alone asserts
            # there is nothing there, which is worse than omitting the heading.
            L.extend(x for k, x in buf if k == "T")

    # COMPLETENESS. The index is only safe if it indexes everything; a parser that
    # silently drops an entry class is the exact bug that bit this project twice on
    # the day the index was built. Count the sources independently and refuse to
    # write a short index.
    src_d, rule = 0, False
    for _, l in rows(os.path.join(A, "decisions.md")):
        if l.startswith("|---") or l.startswith("| ---"):
            rule = True
        elif l.startswith("| ") and rule:
            src_d += 1
    # Count observations only after the first `## ` heading, exactly as the builder does.
    # An earlier version counted the whole file and subtracted a hardcoded 2 for one
    # project's header list, which made this check unsatisfiable on every other project.
    src_o, started = 0, False
    for _, l in rows(os.path.join(A, "observations.md")):
        if l.startswith("## "):
            started = True
        elif started and re.match(r"^\d+\.\s", l):
            src_o += 1
    got_d = sum(1 for x in L if re.match(r"^D\d{3} · ", x))
    got_o = sum(1 for x in L if re.match(r"^#\d+ · ", x))
    if (got_d, got_o) != (src_d, src_o):
        raise SystemExit("REFUSING to write a short index: decisions %d/%d, observations %d/%d"
                         % (got_d, src_d, got_o, src_o))
    # Counting entries cannot see a dropped section -- the Watch list holds no numbered
    # entries, so it passed the count and still rendered empty. Check sections too.
    for sec, buf in secs:
        if buf and not any(x.strip() for _, x in buf):
            raise SystemExit("REFUSING: source section %r has content but the index would "
                             "render it empty" % sec)
    # Counted from this project's own entries. An earlier version asserted the
    # flagship's figures ("28 decision titles carry one") into every project's index.
    nflag = sum(1 for x in L if re.match(r"^D\d{3} · ", x) and "**[" in x)
    note = ("%d of these decision titles carry one." % nflag) if nflag else \
           "No decision title in this project carries one yet."
    return "\n".join(L).replace("{FLAGGED}", note) + "\n"

_ap = argparse.ArgumentParser(
    prog="make-index.py", description="Derive the record index. Exit 0 ok, 1 stale, 2 usage.")
_ap.add_argument("--verify", action="store_true",
                 help="check the index is current; write nothing (exit 1 if stale)")
_ap.add_argument("--root", metavar="DIR", help="project root holding allostatik/ (default: this repo)")
_args = _ap.parse_args()      # an unknown flag now exits 2 instead of silently WRITING

new = build()
if _args.verify:
    cur = io.open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
    if cur == new:
        print("decisions-and-observations-index.md: CURRENT")
    else:
        print("decisions-and-observations-index.md: STALE — regenerate with scripts/make-index.py")
        sys.exit(1)
else:
    io.open(OUT, "w", encoding="utf-8").write(new)
    w = len(new.split())
    print("decisions-and-observations-index.md written: %d lines, %d words (~%dk tokens)"
          % (new.count("\n"), w, round(w * 1.35 / 1000)))

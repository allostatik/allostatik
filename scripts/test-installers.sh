#!/usr/bin/env bash
# test-installers.sh — behavior-parity test for the three install paths:
#   init.sh (shell), installers/npm (node), installers/pip (python).
#
# TDD for the parity invariant: all three must produce identical file trees
# and agree on guards/exit codes. Run after touching any installer or the
# templates. Requires: bash, node >=18, python3 >=3.9. Network NOT required
# (init.sh is exercised from the local checkout, which uses its local-clone path).
#
# Usage: scripts/test-installers.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Parity must compare the LOCAL templates, not whatever is on GitHub main —
# force the bundled path for the npm/pip runs (their fetch-first behavior is
# exercised separately; the fallback path is this same code path).
export ALLOSTATIK_OFFLINE=1
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0

say()  { printf '%s\n' "$*"; }
ok()   { PASS=$((PASS+1)); say "  ok    $*"; }
bad()  { FAIL=$((FAIL+1)); say "  FAIL  $*"; }

# --- Assemble runnable copies (mirrors build.sh's bundling step).
NPM_PKG="$WORK/npm-pkg"; PIP_PKG="$WORK/pip-pkg"
cp -R "$ROOT/installers/npm" "$NPM_PKG"
cp -R "$ROOT/installers/pip" "$PIP_PKG"
# Drop any bundled templates that rode along from a previous local build. With the
# destination already present, `cp -R src dest` NESTS instead of replacing, leaving the
# stale bundle at the path the installers actually read — parity would then compare the
# last release's templates against current source and call it a content mismatch.
rm -rf "$NPM_PKG/templates" "$PIP_PKG/src/allostatik/templates"
mkdir -p "$NPM_PKG/templates" "$PIP_PKG/src/allostatik/templates"
cp -R "$ROOT/templates/project-boilerplate" "$NPM_PKG/templates/project-boilerplate"
cp -R "$ROOT/templates/project-boilerplate" "$PIP_PKG/src/allostatik/templates/project-boilerplate"

run_sh()  { sh "$ROOT/init.sh" "$1"; }
run_npm() { node "$NPM_PKG/bin/allostatik.js" init "$1"; }
run_pip() { PYTHONPATH="$PIP_PKG/src" python3 -m allostatik.cli init "$1"; }
# init.sh lives at extraction/init.sh canonically but ships at repo root; accept either:
[ -f "$ROOT/init.sh" ] || run_sh() { sh "$ROOT/extraction/init.sh" "$1"; }

tree_of() { (cd "$1" && find . -type f | sort); }

# --- Case 0: harness integrity — the seeded packages must carry SOURCE templates,
# not a stale local bundle. Without this the suite silently tests the last release.
say "case 0: harness integrity"
SRC_WF="$ROOT/templates/project-boilerplate/allostatik/workflow.md"
cmp -s "$SRC_WF" "$NPM_PKG/templates/project-boilerplate/allostatik/workflow.md" \
  && ok "npm package seeded from source templates" || bad "npm package seeded from a stale bundle"
cmp -s "$SRC_WF" "$PIP_PKG/src/allostatik/templates/project-boilerplate/allostatik/workflow.md" \
  && ok "pip package seeded from source templates" || bad "pip package seeded from a stale bundle"

# --- Case 1: greenfield — identical trees across all three.
say "case 1: greenfield parity"
for impl in sh npm pip; do mkdir -p "$WORK/green-$impl"; done
run_sh  "$WORK/green-sh"  >/dev/null
run_npm "$WORK/green-npm" >/dev/null
run_pip "$WORK/green-pip" >/dev/null
T_SH="$(tree_of "$WORK/green-sh")"; T_NPM="$(tree_of "$WORK/green-npm")"; T_PIP="$(tree_of "$WORK/green-pip")"
[ "$T_SH" = "$T_NPM" ] && ok "sh tree == npm tree" || { bad "sh vs npm tree"; diff <(echo "$T_SH") <(echo "$T_NPM") || true; }
[ "$T_SH" = "$T_PIP" ] && ok "sh tree == pip tree" || { bad "sh vs pip tree"; diff <(echo "$T_SH") <(echo "$T_PIP") || true; }
# Content parity, not just names:
if diff -r "$WORK/green-sh" "$WORK/green-npm" >/dev/null && diff -r "$WORK/green-sh" "$WORK/green-pip" >/dev/null; then
  ok "file contents identical across all three"
else
  bad "file contents differ between implementations"
fi
echo "$T_SH" | grep -q './CLAUDE.md' && ok "CLAUDE.md placed on greenfield" || bad "CLAUDE.md missing on greenfield"
echo "$T_SH" | grep -q './AGENTS.md' && ok "AGENTS.md placed on greenfield" || bad "AGENTS.md missing on greenfield"

# --- Case 2: existing project — CLAUDE.md preserved, block file written, mode detected.
say "case 2: existing-project behavior"
for impl in npm pip; do
  d="$WORK/exist-$impl"; mkdir -p "$d/src"
  printf '# my project\n' > "$d/README.md"; printf 'MINE\n' > "$d/CLAUDE.md"
  printf 'MINE-A\n' > "$d/AGENTS.md"
  out="$( { [ "$impl" = npm ] && run_npm "$d"; } || true; { [ "$impl" = pip ] && run_pip "$d"; } || true )"
  [ "$(cat "$d/CLAUDE.md")" = "MINE" ] && ok "$impl: existing CLAUDE.md untouched" || bad "$impl: CLAUDE.md overwritten"
  [ -f "$d/allostatik/CLAUDE.md.allostatik-block" ] && ok "$impl: block file written" || bad "$impl: block file missing"
  [ "$(cat "$d/AGENTS.md")" = "MINE-A" ] && ok "$impl: existing AGENTS.md untouched" || bad "$impl: AGENTS.md overwritten"
  [ -f "$d/allostatik/AGENTS.md.allostatik-block" ] && ok "$impl: AGENTS sidecar written" || bad "$impl: AGENTS sidecar missing"
  printf '%s' "$out" | grep -q 'EXISTING project' && ok "$impl: existing mode detected" || bad "$impl: mode detection"
  # Step 1 must follow what was actually placed. Until 0.3.11 it said "Claude
  # Code or Cursor? Skip this step" unconditionally, so every adopter whose own
  # CLAUDE.md was sidecarred was told to skip the one step their install needed
  # and the install did nothing (found by a cold install run, s120).
  printf '%s' "$out" | grep -q 'Skip this' \
    && bad "$impl: step 1 says skip after sidecarring the adopter's file" \
    || ok "$impl: step 1 does not say skip after a sidecar"
  for f in CLAUDE.md AGENTS.md; do
    printf '%s' "$out" | grep -q "Add the block at allostatik/$f.allostatik-block to it" \
      && ok "$impl: step 1 names the $f block to merge" \
      || bad "$impl: step 1 leaves the $f block unmentioned"
  done
done

# --- Case 2b: only CLAUDE.md exists — the commonest real shape, and the one the
# hardcoded step 1 broke. Cursor is pointed at; Claude Code is not, and must be told.
say "case 2b: step 1 follows placement, not a hardcoded surface list"
for impl in npm pip; do
  d="$WORK/exist1-$impl"; mkdir -p "$d/src"
  printf '# my project\n' > "$d/README.md"; printf 'MINE\n' > "$d/CLAUDE.md"
  out="$( { [ "$impl" = npm ] && run_npm "$d"; } || true; { [ "$impl" = pip ] && run_pip "$d"; } || true )"
  printf '%s' "$out" | grep -q 'Claude Code? Not yet' \
    && ok "$impl: names Claude Code as not yet pointed" \
    || bad "$impl: claims Claude Code is pointed at files when CLAUDE.md was sidecarred"
  printf '%s' "$out" | grep -q 'Cursor? Done' \
    && ok "$impl: names Cursor as done (AGENTS.md was placed)" \
    || bad "$impl: does not report the placed AGENTS.md as done"
done

# --- Case 3: guards — refuse overwrite (exit 2) and tool-repo collision (exit 2).
say "case 3: guards"
for impl in npm pip; do
  d="$WORK/guard-$impl"; mkdir -p "$d/allostatik"
  rc=0; { [ "$impl" = npm ] && run_npm "$d" >/dev/null 2>&1; } || rc=$?
  { [ "$impl" = pip ] && { run_pip "$d" >/dev/null 2>&1 || rc=$?; }; } || true
  [ "$rc" -eq 2 ] && ok "$impl: refuses existing allostatik/ (exit 2)" || bad "$impl: overwrite guard (exit $rc)"
  d2="$WORK/guard2-$impl"; mkdir -p "$d2/allostatik/templates"
  rc=0; { [ "$impl" = npm ] && run_npm "$d2" >/dev/null 2>&1; } || rc=$?
  { [ "$impl" = pip ] && { run_pip "$d2" >/dev/null 2>&1 || rc=$?; }; } || true
  [ "$rc" -eq 2 ] && ok "$impl: detects tool-repo collision (exit 2)" || bad "$impl: collision guard (exit $rc)"
done

# --- Case 4: pointer block — all three installers print the IDENTICAL block.
say "case 4: pointer block in output"
POINTER_SENTINEL="This is an Allostatik project"
block_of() {  # extract the text between the copy markers, whitespace-normalized
  printf '%s\n' "$1" | sed -n '/copy from here/,/copy to here/p' | sed '1d;$d;s/^ *//'
}
BLOCK_SH=""; BLOCK_NPM=""; BLOCK_PIP=""
for impl in sh npm pip; do
  d="$WORK/ptr-$impl"; mkdir -p "$d"
  case "$impl" in
    sh)  out="$(run_sh  "$d")"; BLOCK_SH="$(block_of "$out")";;
    npm) out="$(run_npm "$d")"; BLOCK_NPM="$(block_of "$out")";;
    pip) out="$(run_pip "$d")"; BLOCK_PIP="$(block_of "$out")";;
  esac
  printf '%s' "$out" | grep -q "$POINTER_SENTINEL" && ok "$impl: prints pointer block" || bad "$impl: pointer block missing"
  printf '%s' "$out" | grep -q 'copy from here' && ok "$impl: copy markers present" || bad "$impl: copy markers missing"
done
[ -n "$BLOCK_SH" ] && [ "$BLOCK_SH" = "$BLOCK_NPM" ] && ok "block text: sh == npm" || { bad "block text: sh vs npm"; diff <(echo "$BLOCK_SH") <(echo "$BLOCK_NPM") || true; }
[ -n "$BLOCK_SH" ] && [ "$BLOCK_SH" = "$BLOCK_PIP" ] && ok "block text: sh == pip" || { bad "block text: sh vs pip"; diff <(echo "$BLOCK_SH") <(echo "$BLOCK_PIP") || true; }
# The block must also match the README's, so the most-pasted text can't drift:
README_BLOCK="$(grep '^> This is an Allostatik project' "$ROOT/README.md" | sed 's/^> //')"
SH_ONELINE="$(printf '%s' "$BLOCK_SH" | tr '\n' ' ' | sed 's/  */ /g;s/ $//')"
[ "$SH_ONELINE" = "$README_BLOCK" ] && ok "block text matches README" || { bad "block text vs README"; echo "installer: $SH_ONELINE"; echo "readme:    $README_BLOCK"; }

# --- Case 5: usage errors (exit 1).
say "case 5: usage"
rc=0; node "$NPM_PKG/bin/allostatik.js" init "$WORK/nope" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] && ok "npm: bad target exits 1" || bad "npm: bad target (exit $rc)"
rc=0; PYTHONPATH="$PIP_PKG/src" python3 -m allostatik.cli init "$WORK/nope" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] && ok "pip: bad target exits 1" || bad "pip: bad target (exit $rc)"

# --- Case 6: pre-rename probe — an existing allostat/ refuses with the migrate pointer.
say "case 6: pre-rename allostat/ probe"
for impl in sh npm pip; do
  d="$WORK/oldgen-$impl"; mkdir -p "$d/allostat"
  rc=0; out=""
  case "$impl" in
    sh)  out="$(run_sh  "$d" 2>&1)" || rc=$?;;
    npm) out="$(run_npm "$d" 2>&1)" || rc=$?;;
    pip) out="$(run_pip "$d" 2>&1)" || rc=$?;;
  esac
  [ "$rc" -eq 2 ] && ok "$impl: refuses beside allostat/ (exit 2)" || bad "$impl: old-gen probe (exit $rc)"
  printf '%s' "$out" | grep -q 'migrating-from-allostat' && ok "$impl: points at migration steps" || bad "$impl: migration pointer missing"
  [ -e "$d/allostatik" ] && bad "$impl: wrote despite refusal" || ok "$impl: nothing written"
done

# --- Case 7: both installer packages ship an identical README (registry landing page).
say "case 7: package READMEs"
NPM_RM="$ROOT/installers/npm/README.md"; PIP_RM="$ROOT/installers/pip/README.md"
[ -s "$NPM_RM" ] && ok "npm: README present" || bad "npm: README missing (npm page renders blank)"
[ -s "$PIP_RM" ] && ok "pip: README present" || bad "pip: README missing (PyPI page renders blank)"
cmp -s "$NPM_RM" "$PIP_RM" && ok "package READMEs identical" || { bad "package READMEs drifted"; diff "$NPM_RM" "$PIP_RM" || true; }

# --- Case 8: the three version strings move in lockstep (installers/README.md step 2).
say "case 8: version lockstep"
V_NPM="$(sed -n 's/.*"version": "\(.*\)".*/\1/p' "$ROOT/installers/npm/package.json" | head -1)"
V_PIP="$(sed -n 's/^version = "\(.*\)"/\1/p' "$ROOT/installers/pip/pyproject.toml" | head -1)"
V_INIT="$(sed -n 's/^__version__ = "\(.*\)"/\1/p' "$ROOT/installers/pip/src/allostatik/__init__.py" | head -1)"
if [ -n "$V_NPM" ] && [ "$V_NPM" = "$V_PIP" ] && [ "$V_NPM" = "$V_INIT" ]; then
  ok "versions in lockstep ($V_NPM)"
else
  bad "version drift: npm=$V_NPM pip=$V_PIP init=$V_INIT"
fi

# --- Case 9: ledger reachability — every routine a session can run FIRST must create
# the ledger. Without this, close step 0 (verify this session opened) fails by
# construction on every project's first session, and long routines have nothing to
# checkpoint into. This case exists because both first-run routines shipped without it.
say "case 9: ledger reachability"
WF="$ROOT/templates/project-boilerplate/allostatik/workflow.md"
wf_section() { awk -v h="$1" '$0==h{f=1;next} /^## /{f=0} f' "$WF"; }
for h in "## First run — set up the files" "## First run — existing project (migrate)"; do
  body="$(wf_section "$h")"; label="$(printf '%s' "$h" | sed 's/^## //')"
  printf '%s' "$body" | grep -q 'session-ledger.md' \
    && ok "$label: creates the ledger" \
    || bad "$label: never creates the ledger (close step 0 fails by construction on session 1)"
  printf '%s' "$body" | grep -q 'STEP-DONE' \
    && ok "$label: marks the routine finished" \
    || bad "$label: no STEP-DONE (a finished run reads as abandoned)"
done
grep -q 'ledger' "$ROOT/skills/allostatik-close/SKILL.md" \
  && ok "close skill names the ledger steps" \
  || bad "close skill omits the ledger steps (stale enumeration)"

# --- Case 10: placeholder-scan hygiene — convention mentions are backticked
# (named, not instantiated), so the drift-check's placeholder scan flags exactly
# the real slots: zero false positives on a clean install (obs #279c). Backticked
# spans are stripped BEFORE matching, so the exemption is per-token, not per-line
# (two markers share one decisions.md line). Mutation check: un-backtick any
# single marker and the first check fails.
say "case 10: placeholder-scan hygiene"
BP="$ROOT/templates/project-boilerplate"
viol="$( { find "$BP" -type f -name '*.md' -exec sed 's/`[^`]*`//g' {} + | grep -c -e '\[ALL-CAPS-WITH-HYPHENS\]' -e '\[SUPERSEDED ' -e '\[AMENDED ' -e '\[PARTIALLY SUPERSEDED ' ; } || true )"
viol="${viol:-0}"
[ "$viol" -eq 0 ] && ok "convention mentions are backticked (scan-exempt)" || bad "$viol bare convention mention(s) — the scan false-positives on a clean install"
grep -q 'wrapped in backticks' "$BP/allostatik/workflow.md" \
  && ok "scan definition documents the backtick exemption" \
  || bad "scan definition missing the backtick exemption"

# --- Case 11: stamped regions — the reference implementation verifies the templates
# (markers well-formed, stamp version == package version, body hash == stamp, no
# invisible characters in any template or fetched doc), and a fresh install classifies
# CURRENT on every region (the placed stamps are upstream's, copied, and hash true).
# Mutation check: edit one byte inside a region without --write and the first check fails.
# --- Case 10b: the close ends by SAYING it closed. A skipped close produces no
# output at all, so that sentence's absence is the only tell the user gets; the
# routine and the close skill must both require it (Colby, s120 side note).
say "case 10b: the close states that it closed"
grep -q "is the session over, or is there more" "$WF" \
  && ok "close step 0 asks whether the session is ending" \
  || bad "close step 0 does not ask the one fact the routine cannot observe"
grep -q "A handoff comes out of a completed close, and nowhere else" "$WF" \
  && ok "the handoff section states the rule, not only the close's step order" \
  || bad "Writing the handoff never says a close must have completed first"
grep -q "run the whole close again" "$WF" \
  && ok "close step 5 defines the reopen cycle" \
  || bad "close step 5 does not say a reopen costs a full close"
grep -q "say plainly that it is closed" "$WF" \
  && ok "close step 8 requires the closing statement" \
  || bad "close step 8 no longer requires the session to be declared closed"
grep -q "the turn's last line states the session is closed" "$WF" \
  && ok "close step 8's own check tests for it" \
  || bad "close step 8 states the rule but does not check it"
grep -q "saying the session is closed" "$ROOT/skills/allostatik-close/SKILL.md" \
  && ok "the close skill requires it too" \
  || bad "the close skill and close step 8 disagree about the closing statement"

say "case 11: stamped regions"
SR="$ROOT/scripts/stamp-regions.py"
if out="$(python3 "$SR" --root "$ROOT" 2>&1)"; then
  ok "stamp-regions verify passes ($(printf '%s' "$out" | sed -n 's/^passed: \([0-9]*\).*/\1/p') checks)"
else
  bad "stamp-regions verify fails:"; printf '%s\n' "$out" | grep FAIL || true
fi
cls="$(python3 "$SR" --classify "$WORK/green-sh" --root "$ROOT" 2>&1 || true)"
n_cur="$(printf '%s' "$cls" | grep -c ' CURRENT ' || true)"
[ "$n_cur" -eq 3 ] && ok "fresh install classifies CURRENT on all 3 regions" || { bad "fresh install classification ($n_cur/3 CURRENT)"; printf '%s\n' "$cls"; }

# --- Case 12: CHANGELOG lockstep — the head entry is the package version and names its tag
# (the release ritual's step 3; without this the #288 shape returns: an expected step misfiled).
say "case 12: changelog lockstep"
CL="$ROOT/CHANGELOG.md"
[ -s "$CL" ] && ok "CHANGELOG.md present" || bad "CHANGELOG.md missing"
V_CL="$(grep -m1 '^## ' "$CL" | sed -n 's/^## \([0-9][0-9.]*\) .*/\1/p')"
[ -n "$V_CL" ] && [ "$V_CL" = "$V_NPM" ] && ok "head entry is $V_CL == package $V_NPM" || bad "head entry '$V_CL' vs package '$V_NPM'"
head_entry="$(awk '/^## /{n++} n==1' "$CL")"
printf '%s' "$head_entry" | grep -q "^\*\*Tag:\*\* \`v$V_NPM\`" && ok "head entry names tag v$V_NPM" || bad "head entry does not name tag v$V_NPM"
grep -q 'Before 0.3.4' "$CL" && ok "bootstrap entry present for pre-stamp installs" || bad "bootstrap entry missing"

# --- Case 13: the placed contract and its pointers — the guardrails live on the trusted side.
say "case 13: placed upgrade contract"
WF="$ROOT/templates/project-boilerplate/allostatik/workflow.md"
contract_line="$(grep -n '^## Upgrade contract$' "$WF" | cut -d: -f1)"; end_line="$(grep -n '^<!-- END allostatik-part1 -->$' "$WF" | cut -d: -f1)"
[ -n "$contract_line" ] && [ -n "$end_line" ] && [ "$contract_line" -lt "$end_line" ] && ok "Upgrade contract sits inside the part1 region" || bad "Upgrade contract missing or outside the stamped region"
grep -q '^5\. \*\*Stamp integrity\.\*\*' "$WF" && ok "drift-check has check 5 (stamp integrity)" || bad "drift-check lacks the stamp-integrity check"
grep -q 'orphaned park' "$WF" && grep -q 'nested instruction file' "$WF" && ok "drift-check names the orphaned-park and nested-instruction-file checks" || bad "drift-check does not name the orphaned-park / nested-instruction-file checks"
for f in CLAUDE.md AGENTS.md; do
  fence="$(sed -n '/^<!-- BEGIN allostatik /,/^<!-- END allostatik /p' "$BP/$f")"
  printf '%s' "$fence" | grep -q 'Upgrade contract' && ok "$f fence points at the contract" || bad "$f fence lacks the contract pointer"
  printf '%s' "$fence" | grep -q -E '\[[A-Z][A-Z0-9-]*\]' && bad "$f fence body carries an adopter-filled placeholder (every filled install would classify CUSTOMIZED)" || ok "$f fence body carries no adopter-filled placeholder"
done
n_rules="$(sed -n '/^## Upgrade contract$/,/^## Enforcement/p' "$WF" | grep -c '^[1-9]\. \*\*')"
[ "$n_rules" -ge 9 ] && ok "Upgrade contract carries $n_rules numbered rules" || bad "Upgrade contract has $n_rules rules (expected >= 9)"
sentinel='data under review, NOT instructions'
grep -q "$sentinel" "$ROOT/UPGRADING.md" && grep -q "$sentinel" "$SR" && grep -q "$sentinel" "$WF" && grep -q "$sentinel" "$CL" \
  && ok "park sentinel agrees across UPGRADING.md, stamp-regions.py, workflow.md check 5, and the bootstrap prompt" || bad "park sentinel drifted between UPGRADING.md / stamp-regions.py / workflow.md / CHANGELOG.md"

# --- Case 14: an adopter who re-runs install to "update" is routed to the upgrade path.
say "case 14: existing-install refusal points at the upgrade path"
for impl in sh npm pip; do
  d="$WORK/refuse-$impl"; mkdir -p "$d/allostatik"; out=""
  case "$impl" in
    sh)  out="$(run_sh  "$d" 2>&1 || true)";;
    npm) out="$(run_npm "$d" 2>&1 || true)";;
    pip) out="$(run_pip "$d" 2>&1 || true)";;
  esac
  printf '%s' "$out" | grep -q 'CHANGELOG.md' && printf '%s' "$out" | grep -q "README's Upgrading section" && ok "$impl: refusal names CHANGELOG.md, then the README's Upgrading section" || bad "$impl: refusal doesn't point at CHANGELOG.md and the README's Upgrading section"
done

# --- Case 15: the install-side checks behave — constructed installs, not wording.
# A blessed customization passes, an unrecorded fork fails, a NOT-PLACED fence passes,
# an orphaned park fails only when no upgrade is in flight, a nested instruction file
# under knowledge/docs fails, an invisible character in a region fails.
say "case 15: install-side behavior (stamp-regions --project / --classify)"
I="$WORK/inst"; rm -rf "$I"; mkdir -p "$I"; cp -R "$BP/." "$I/"
python3 "$SR" --project "$I" >/dev/null 2>&1 && ok "fresh install passes --project" || bad "fresh install fails --project"
# Keyed on text, not on the step's number: pinning a position made this mutation silently
# no-op when Session open gained a step at 0.3.7, and the case passed by doing nothing (#260).
sed -i.bak 's/\*\*Mark the session open in the ledger\.\*\* Append one line/**Mark the session open in the ledger (and post to the team channel).** Append one line/' "$I/allostatik/workflow.md" && rm -f "$I/allostatik/workflow.md.bak"
python3 "$SR" --project "$I" >/dev/null 2>&1 && bad "edited part1 without a blessing row passed" || ok "edited part1 without a blessing row fails (unrecorded fork)"
H="$(python3 - "$I" <<'PY'
import sys, hashlib, re
t = open(sys.argv[1] + "/allostatik/workflow.md", encoding="utf-8").read().replace("\r\n", "\n").split("\n")
b = next(i for i, l in enumerate(t) if l.startswith("<!-- BEGIN allostatik-part1 ")); e = next(i for i, l in enumerate(t) if l == "<!-- END allostatik-part1 -->")
print(hashlib.sha256(("\n".join(t[b+1:e]) + "\n").encode()).hexdigest()[:12])
PY
)"
printf '| Upgrade-kept customization (region part1, v0.3.4→v0.3.4, s1) | team-channel line kept — body sha256:%s | test |\n' "$H" >> "$I/allostatik/decisions.md"
python3 "$SR" --project "$I" >/dev/null 2>&1 && ok "blessing row naming the kept body hash makes --project pass" || bad "blessing row not honored"
out="$(python3 "$SR" --classify "$I" --root "$ROOT" 2>/dev/null || true)"
printf '%s' "$out" | grep -q 'part1      CUSTOMIZED .*blessed' && ok "--classify reports CUSTOMIZED + blessed" || bad "--classify misreports the blessed customization"
mv "$I/AGENTS.md" "$I/AGENTS.md.away"
python3 "$SR" --project "$I" >/dev/null 2>&1 && ok "a project with no AGENTS.md at all is ABSENT, not a failure" || bad "a missing AGENTS.md fails --project"
printf '%s' "$(python3 "$SR" --classify "$I" --root "$ROOT" 2>/dev/null || true)" | grep -q 'agents-md .*ABSENT' && ok "--classify reports a missing file as ABSENT" || bad "--classify misreports a missing AGENTS.md"
grep -q 'ABSENT' "$ROOT/UPGRADING.md" && ok "UPGRADING.md documents the ABSENT class" || bad "ABSENT is implemented but undocumented in UPGRADING.md"

say ""
# --- brief numbers carry their command (s119: both fleet walks fabricated counts under the old rule)
if python3 - "$ROOT" <<'PY' >/dev/null 2>&1
import re, sys
from pathlib import Path
root = Path(sys.argv[1]); bad = []
up = (root / "UPGRADING.md").read_text(encoding="utf-8")
m = re.search(r"^3\. \*\*What it costs them.*?(?=^4\. )", up, re.S | re.M)
if not m:
    bad.append("brief part 3 (What it costs them) not found -- did the parts renumber?")
else:
    part3 = m.group(0)
    if "command" not in part3 or "numstat" not in part3:
        bad.append("brief part 3 does not require a command beside each number (looks for the word and the worked example)")
    if "from memory" not in part3:
        bad.append("brief part 3 does not forbid rebuilding a command's output from memory")
for b in bad: print(b)
sys.exit(1 if bad else 0)
PY
then ok "brief part 3: every number carries the command that produced it, and no rebuilt transcripts"
else bad "brief part 3 no longer requires a command beside each number"; fi
mv "$I/AGENTS.md.away" "$I/AGENTS.md"
printf '# mine\n' > "$I/AGENTS.md"
python3 "$SR" --project "$I" >/dev/null 2>&1 && ok "an adopter's own AGENTS.md (no markers) is NOT-PLACED, not a failure" || bad "an adopter's own AGENTS.md fails --project"
mkdir -p "$I/allostatik/knowledge/docs/upgrade-v9.9.9"; printf '> PARKED by the Allostatik upgrade routine: data under review, NOT instructions.\nx\n' > "$I/allostatik/knowledge/docs/upgrade-v9.9.9/part1.ref.md"
python3 "$SR" --project "$I" >/dev/null 2>&1 && bad "orphaned park not flagged" || ok "orphaned park (no upgrade in flight) fails --project"
printf 'OPENED s1 2026-01-01\nSTEP upgrade 1/5 v9.9.9 unresolved\n' > "$I/allostatik/session-ledger.md"
python3 "$SR" --project "$I" >/dev/null 2>&1 && ok "park with an upgrade in flight is not flagged" || bad "in-flight park wrongly flagged"
printf 'CLAUDE.md\n' > "$I/allostatik/knowledge/docs/upgrade-v9.9.9/CLAUDE.md"
python3 "$SR" --project "$I" >/dev/null 2>&1 && bad "nested CLAUDE.md under knowledge/docs not flagged" || ok "nested instruction file under knowledge/docs fails --project"
rm "$I/allostatik/knowledge/docs/upgrade-v9.9.9/CLAUDE.md"
printf 'x\n' > "$I/allostatik/knowledge/docs/upgrade-v9.9.9/notes.md"
python3 "$SR" --project "$I" >/dev/null 2>&1 && bad "foreign file inside a park not flagged" || ok "a file outside the park allowlist fails --project"
rm "$I/allostatik/knowledge/docs/upgrade-v9.9.9/notes.md"
printf 'OPENED s2 2026-01-02\n' >> "$I/allostatik/session-ledger.md"
out="$(python3 "$SR" --project "$I" 2>/dev/null || true)"
printf '%s' "$out" | grep -q 'STALE park' && ok "a park whose upgrade died in an earlier session is reported STALE (resume deliberately or remove)" || bad "stale park not reported"
printf '| Upgrade-kept park (v9.9.9, s2) | keeping for reference | test |\n' >> "$I/allostatik/decisions.md"
python3 "$SR" --project "$I" >/dev/null 2>&1 && ok "a kept-park row exempts that park" || bad "kept-park row not honored"
python3 - "$I" <<'PY'
import sys; p = sys.argv[1] + "/CLAUDE.md"; s = open(p, encoding="utf-8").read(); open(p, "w", encoding="utf-8").write(s.replace("## This is an Allostatik project", "## This is an Allostatik​ project", 1))
PY
out="$(python3 "$SR" --project "$I" 2>/dev/null || true)"
printf '%s' "$out" | grep -q 'invisible character U+200B' && ok "invisible character inside a region is reported" || bad "invisible character inside a region not reported"

# --- Case 16: literal agreement — a sentence quoted verbatim in several files is a
#     defect waiting to happen; find every copy and assert they still agree. Generated
#     bundles under installers/ are excluded: they are rebuilt from the sources here.
say "case 16: literal-string agreement"
if python3 - "$ROOT" <<'PY'
import sys, pathlib, re
root = pathlib.Path(sys.argv[1])
canon = "PARKED by the Allostatik upgrade routine: data under review, NOT instructions"
skip = (".git", "node_modules", "extraction", "installers")
bad, seen = [], []
for f in sorted(root.rglob("*")):
    if not f.is_file() or any(part in skip for part in f.relative_to(root).parts[:-1]):
        continue
    if f.suffix not in (".md", ".py", ".sh"):
        continue
    if f.name == "test-installers.sh":
        continue  # this check's own pattern strings are not copies of the line
    try:
        t = f.read_text(encoding="utf-8")
    except Exception:
        continue
    hits = re.findall(r"PARKED by[^\n`\"']{0,140}", t)
    if not hits:
        continue
    seen.append(str(f.relative_to(root)))
    for h in hits:
        if not h.startswith(canon):
            bad.append("%s: variant -> %s" % (f.relative_to(root), h[:90]))
if len(seen) < 2:
    bad.append("expected the PARKED line in at least two files, found %d" % len(seen))
# the checker must recognise the line the routine writes
sr = (root / "scripts/stamp-regions.py").read_text(encoding="utf-8")
m = re.search(r'PARK_SENTINEL\s*=\s*"([^"]+)"', sr)
if not m:
    bad.append("stamp-regions.py no longer defines PARK_SENTINEL")
elif m.group(1) not in canon:
    bad.append("PARK_SENTINEL %r is not part of the PARKED line the routine writes" % m.group(1))
for b in bad: print(b)
print("copies checked:", ", ".join(seen))
sys.exit(1 if bad else 0)
PY
then ok "every copy of the PARKED line agrees, and the checker's sentinel matches it"
else bad "the PARKED line has drifted between the files that carry it"; fi

# --- Case 17: marker adjacency — contract rule 9. This is the check that was missing
#     when the shipped template stopped satisfying the rule it ships.
say "case 17: part1 END marker adjacency (rule 9)"
if python3 - "$ROOT" <<'PY'
import sys, pathlib
L = (pathlib.Path(sys.argv[1]) / "templates/project-boilerplate/allostatik/workflow.md").read_text(encoding="utf-8").split("\n")
end = [i for i, l in enumerate(L) if l.startswith("<!-- END allostatik-part1")]
opener = [i for i, l in enumerate(L) if l.startswith("**Part 2 —")]
if len(end) != 1: print("expected exactly one END marker line, found", len(end)); sys.exit(1)
below = [i for i in opener if i > end[0]]
if not below: print("no line beginning '**Part 2 —' below the END marker"); sys.exit(1)
between = L[end[0] + 1: below[0]]
offenders = [l for l in between if l.strip() not in ("", "---")]
if offenders: print("content between END and Part 2's opener:", offenders[:3]); sys.exit(1)
if opener[0] < end[0]:
    print("note: '**Part 2 —' also matches at line", opener[0] + 1, "- a first-match read would be wrong")
sys.exit(0)
PY
then ok "END sits above Part 2's opener with only blanks/--- between (and a first-match read is caught)"
else bad "part1's END marker violates contract rule 9 in the shipped template"; fi

# --- Case 18: vocabulary closure — every word the routine writes into a ledger line,
#     and every token the drift-check reads, must be named by contract rule 8.
say "case 18: ledger vocabulary closure"
if python3 - "$ROOT" <<'PY'
import sys, pathlib, re
root = pathlib.Path(sys.argv[1])
wf = (root / "templates/project-boilerplate/allostatik/workflow.md").read_text(encoding="utf-8")
up = (root / "UPGRADING.md").read_text(encoding="utf-8")
m = re.search(r"^8\. \*\*Records carry positions.*?(?=\n9\. )", wf, re.S | re.M)
if not m: print("could not locate contract rule 8"); sys.exit(1)
rule8 = m.group(0)
bad = []
for tok in ("STEP-DONE upgrade", "OPENED", "CLOSED"):
    if tok not in rule8:
        bad.append("rule 8 does not name %r, which the drift-check or the routine relies on" % tok)
# Derive the session-line verbs from the routine rather than typing them here: a
# typed list is the same untested claim one layer down (#260). s120 added
# REOPENED to the routine and this check passed, because its list was typed.
for verb in sorted(set(re.findall(r"`([A-Z][A-Z-]*)\s+<[^`]*`", wf))):
    if verb not in rule8:
        bad.append("the routine writes ledger lines beginning %r; rule 8 does not name it" % verb)
# REOPENED contains OPENED, so any check that matches OPENED as a substring is
# satisfied by the wrong line. The routine must say so where it reads OPENED.
if "REOPENED" in wf:
    m0 = re.search(r"^0\. \*\*Check both boundaries.*?(?=\n1\. \*\*)", wf, re.S | re.M)
    if not m0:
        bad.append("close step 0 not found; the OPENED/REOPENED disambiguation cannot be checked")
    elif "start of a line" not in m0.group(0) or "REOPENED" not in m0.group(0):
        bad.append("the routine writes REOPENED, but close step 0 does not say OPENED is matched at the start of a line and is a different word")
spans = re.findall(r"`STEP upgrade [345]/5[^`]*`", up)
if not spans: bad.append("no STEP upgrade 3/5-5/5 templates found in UPGRADING.md")
words = set()
for sp in spans:
    sp = re.sub(r"<[^>]*>", " ", sp)
    sp = sp.replace("sha256:", " ").replace("STEP", " ").replace("upgrade", " ")
    for w in re.findall(r"[a-z][a-z-]{2,}", sp):
        words.add(w)
for w in sorted(words):
    if ("*%s*" % w) not in rule8:
        bad.append("routine writes %r into a ledger line; rule 8 does not list it" % w)
for b in bad: print(b)
sys.exit(1 if bad else 0)
PY
then ok "every ledger word the routine writes is named by rule 8"
else bad "the routine writes ledger vocabulary rule 8 does not license"; fi

# --- Case 19: write-target closure — the routine's staged write must land where
#     contract rule 1 licenses a write, not beside the target.
say "case 19: write-target closure"
if python3 - "$ROOT" <<'PY'
import sys, pathlib, re
root = pathlib.Path(sys.argv[1])
wf = (root / "templates/project-boilerplate/allostatik/workflow.md").read_text(encoding="utf-8")
up = (root / "UPGRADING.md").read_text(encoding="utf-8")
m = re.search(r"^1\. \*\*Where it writes\.\*\*.*?(?=\n2\. )", wf, re.S | re.M)
if not m: print("could not locate contract rule 1"); sys.exit(1)
rule1 = m.group(0)
bad = []
if "upgrade-v<tag>/" not in rule1: bad.append("rule 1 no longer names the park path")
staged = re.findall(r"`allostatik/knowledge/docs/upgrade-vX\.Y\.Z/([^`]+)`", up)
if not staged: bad.append("UPGRADING.md names no staged write path inside the park")
for s in staged:
    leaf = re.sub(r"<[^>]*>", "<region>", s)
    if leaf not in rule1 and leaf.split("/")[0] + "/" not in rule1.replace("`", ""):
        bad.append("routine writes park/%s; rule 1 does not license it" % s)
if re.search(r"temporary path beside the target", up):
    bad.append("the routine still stages a write beside the target, outside rule 1")
for b in bad: print(b)
sys.exit(1 if bad else 0)
PY
then ok "the routine's staged write lands inside the park rule 1 licenses"
else bad "the routine writes somewhere contract rule 1 does not license"; fi

say "case 20: record-index gate closure (0.3.7)"
if python3 - "$ROOT" <<'PY'
import sys, pathlib, re
root = pathlib.Path(sys.argv[1])
wf  = (root / "templates/project-boilerplate/allostatik/workflow.md").read_text(encoding="utf-8")
cl  = (root / "templates/project-boilerplate/CLAUDE.md").read_text(encoding="utf-8")
ag  = (root / "templates/project-boilerplate/AGENTS.md").read_text(encoding="utf-8")
bad = []

# Neither fence may name the record: the open routine reads it, so that a break-out
# never has to edit an upstream-owned region.
for name, txt, pat in (("CLAUDE.md", cl, r"^@allostatik/(decisions|observations)\.md"),
                       ("AGENTS.md", ag, r"^- `allostatik/(decisions|observations)\.md`")):
    body = re.search(r"BEGIN allostatik .*?END allostatik", txt, re.S)
    if body and re.search(pat, body.group(0), re.M):
        bad.append("%s still loads the record from inside the fence" % name)

step = re.search(r"^3\. \*\*Read the record.*?(?=^4\. )", wf, re.S | re.M)
if not step:
    bad.append("Session open has no step 3 reading the record")
else:
    t = step.group(0)
    for needle, why in (("120,000 bytes", "the byte budget"),
                        ("decisions-and-observations-index.md", "the index filename"),
                        ("halts the open", "the halt"),
                        ("INDEXING.md", "the walkthrough pointer"),
                        ("wc -c", "the check command"),
                        ("as a whole, not each file", "that the budget covers the record, not each file"),
                        ("Do not size the record", "the no-resize rule for the index state"),
                        ("Record-index declined", "the verbatim decline row"),
                        ("un-runnable, not passed", "the branch for a surface that cannot size a file")):
        if needle not in t:
            bad.append("open step 3 does not name %s" % why)

close = re.search(r"^2\. \*\*Update canonical state\.\*\*.*?(?=^3\. )", wf, re.S | re.M)
if not close or "decisions-and-observations-index.md" not in close.group(0):
    bad.append("the close does not regenerate the index alongside the entries it indexes")

d2 = re.search(r"^2\. \*\*Imports vs folder contents\.\*\*.*?$", wf, re.M)
for f in ("decisions.md", "observations.md"):
    if not d2 or ("allostatik/" + f) not in d2.group(0):
        bad.append("drift-check 2 does not exempt %s from the orphan check" % f)

sk = root / "skills/allostatik-open/SKILL.md"
if sk.exists():
    st = sk.read_text(encoding="utf-8")
    if re.search(r"All (six|seven|eight) open steps", st):
        bad.append("the open skill hardcodes a step count; it drifts when the routine grows")
    if re.search(r"Session open steps 1.[0-9]", st):
        bad.append("the open skill hardcodes a step range")
    if "read the record" not in st.lower():
        bad.append("the open skill never mentions reading the record")

ix = root / "INDEXING.md"
if not ix.exists():
    bad.append("INDEXING.md is missing")
else:
    t = ix.read_text(encoding="utf-8")
    if "never run it" not in t:
        bad.append("INDEXING.md does not forbid running the fetched generator")
    if "not touched" not in t:
        bad.append("INDEXING.md does not promise the record is untouched")

for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PY
then ok "record-index gate: fences clear, open halts, close regenerates, walkthrough ships"
else bad "the record-index gate is incoherent across the files that carry it"; fi

say ""
# --- plan retirement: RETIRING.md ships, the close points at it, the reference test passes (s117)
if python3 - "$ROOT" <<'PY' >/dev/null 2>&1 && python3 "$ROOT/scripts/test_park_plan.py" >/dev/null 2>&1
import re, sys
from pathlib import Path
root = Path(sys.argv[1]); bad = []
rt = root / "RETIRING.md"
if not rt.exists(): bad.append("RETIRING.md is missing")
else:
    t = rt.read_text(encoding="utf-8")
    if "never run it" not in t: bad.append("RETIRING.md does not forbid running the fetched script")
    if "verbatim" not in t: bad.append("RETIRING.md does not promise verbatim moves")
wf = (root / "templates/project-boilerplate/allostatik/workflow.md").read_text(encoding="utf-8")
step = re.search(r"^2\. \*\*Update canonical state.*?(?=^3\. )", wf, re.S | re.M)
if not step or "RETIRING.md" not in step.group(0): bad.append("close step 2 does not point at RETIRING.md")
if not (root / "scripts/retire-plan.py").exists(): bad.append("scripts/retire-plan.py is missing")
pl = (root / "templates/project-boilerplate/allostatik/plan.md").read_text(encoding="utf-8")
if "Mark it" not in pl or "[parked]" not in pl or "RETIRING.md" not in pl:
    bad.append("template plan.md does not carry the mark-it bullet (~~ / [parked] / RETIRING.md)")
for b in bad: print(b)
sys.exit(1 if bad else 0)
PY
then ok "plan retirement: RETIRING.md ships, close step 2 points at it, test_park_plan.py passes"
else bad "plan retirement is incoherent across RETIRING.md, close step 2 and scripts/"; fi

say "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

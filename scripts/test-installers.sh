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

say ""
say "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

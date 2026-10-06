#!/bin/sh
# test-state-check.sh — the cases two fresh readers broke the clean-start reads with (s127),
# plus the plain ones, run against templates/project-boilerplate/allostatik/scripts/state-check.sh.
# Every case builds its own repositories under a temp dir and asserts the verdict line and
# the exit status. POSIX sh; needs git and a sha256 tool. Run: sh scripts/test-state-check.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SH=${SH:-sh}
SC=${STATE_CHECK:-$ROOT/templates/project-boilerplate/allostatik/scripts/state-check.sh}
BASE=$(mktemp -d); trap 'rm -rf "$BASE"' EXIT INT TERM HUP
export HOME=$BASE/home GIT_CONFIG_NOSYSTEM=1; unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; mkdir -p "$HOME"   # hermetic: no system, user or environment git config
git config --global user.name T; git config --global user.email t@example.invalid
git config --global init.defaultBranch main; git config --global commit.gpgsign false
git config --global protocol.file.allow always
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$*"; }

mk() {  # mk <name> [branch]: $BASE/<name>/remote.git + $BASE/<name>/proj — one commit, tag v1, all pushed
  d=$BASE/$1; mkdir -p "$d"; git init -q --bare "$d/remote.git"
  git clone -q "$d/remote.git" "$d/proj" 2>/dev/null
  ( cd "$d/proj" && git checkout -q -b "${2:-main}" && mkdir allostatik && printf '# wf\n' > allostatik/workflow.md \
    && echo a > a.txt && git add -A && git commit -q -m init && git push -q -u origin "${2:-main}" \
    && git tag -a v1 -m v1 && git push -q origin v1 ) 2>/dev/null
}
table() {  # table <proj> <row>...   each row "path|storage"; writes Part 2's § Repositories
  p=$1; shift
  { printf '# Workflow\n\nbody\n\n## Repositories\n\nprose\n\n| Repository | Storage | Why a session writes here |\n|---|---|---|\n'
    for r in "$@"; do printf '| `%s` | `%s` | why |\n' "${r%%|*}" "${r#*|}"; done
    printf '\n## Next section\n\n| not | a | row |\n'; } > "$p/allostatik/workflow.md"
}
settle() { ( cd "$1" && git add -A && git commit -q -m settle && git push -q origin HEAD ) 2>/dev/null; }
# expect <case> <project> <exit> <pattern> [pattern...]: every pattern must match the output
expect() {
  c=$1; p=$2; want=$3; shift 3
  out=$($SH "$SC" "$p" 2>&1); got=$?
  fails=''
  [ "$got" -eq "$want" ] || fails="exit $got, wanted $want"
  for pat in "$@"; do printf '%s\n' "$out" | grep -q -- "$pat" || fails="${fails:+$fails; }no match for: $pat"; done
  if [ -z "$fails" ]; then ok "$c"; else bad "$c — $fails"; printf '%s\n' "$out" | sed 's/^/        | /'; fi
}

echo "state-check.sh: $SC"

# ---- the plain cases
mk clean; P=$BASE/clean/proj
expect "clean, pushed, no Repositories section: the project itself as remote origin" "$P" 0 '^OK      '
table "$P" "$P|remote origin"; settle "$P"
expect "clean, listed by absolute path" "$P" 0 "^OK      $P\$"
table "$P" "this project (the folder holding \`allostatik/\`)|remote origin"; settle "$P"
expect "a non-path first cell names the project" "$P" 0 '^OK      this project'
table "$P" "$P|remote origin" "$BASE/clean|remote origin"; settle "$P"
expect "a listed path that is not a repository is BLOCKED, not dirty" "$P" 2 '^BLOCKED .*/clean: could not read: remote: exit 128'

mk untracked; P=$BASE/untracked/proj; echo x > "$P/new.txt"
expect "an untracked file is dirt" "$P" 1 '^DIRTY .*1 uncommitted path(s)'

mk unpushed; P=$BASE/unpushed/proj; ( cd "$P" && echo b >> a.txt && git commit -q -am more )
expect "an unpushed commit: the branch is not at the push URL as the same object" "$P" 1 '^DIRTY .*not at .*remote.git as the same object: main'

mk untagged; P=$BASE/untagged/proj; ( cd "$P" && git tag -a v2 -m v2 )
expect "an unpushed tag" "$P" 1 '^DIRTY .*as the same object: v2'

mk detached; P=$BASE/detached/proj; ( cd "$P" && git checkout -q --detach )
expect "a detached HEAD" "$P" 1 '^DIRTY .*HEAD is detached'

mk stashed; P=$BASE/stashed/proj; ( cd "$P" && echo s >> a.txt && git stash -q )
expect "a real stash" "$P" 1 '^DIRTY .*a stash ref exists'

mk linked; P=$BASE/linked/proj; ( cd "$P" && git worktree add -q "$BASE/linked/wt" -b side 2>/dev/null )
expect "a linked worktree: two non-bare worktrees" "$P" 1 '^DIRTY .*2 non-bare worktree(s), expected 1'

# ---- storage, read against git
mk noremote; P=$BASE/noremote/proj; ( cd "$P" && git remote remove origin )
expect "declared remote origin, git lists nothing" "$P" 1 '^DIRTY .*declared `remote origin` but git remote lists nothing'
table "$P" "$P|local-only"; ( cd "$P" && git add -A && git commit -q -m t )
expect "local-only with no remote passes and says so" "$P" 0 '^OK .*local-only'
mk localonly; P=$BASE/localonly/proj; table "$P" "$P|local-only"; settle "$P"
expect "declared local-only, git lists a remote" "$P" 1 '^DIRTY .*declared `local-only` but git remote lists origin'
mk prefix; P=$BASE/prefix/proj; ( cd "$P" && git remote rename origin origin2 )
expect "declared remote origin, git lists only origin2: membership is by whole name" "$P" 1 '^DIRTY .*declared `remote origin` but git remote lists origin2'
mk badvalue; P=$BASE/badvalue/proj; table "$P" "$P|cloud"; settle "$P"
expect "a storage value of neither form fails" "$P" 1 "^DIRTY .*storage value 'cloud' is neither"

# ---- the readers' breaks
mk f1; P=$BASE/f1/proj; ( cd "$P" && git rev-parse HEAD > .git/MERGE_HEAD )
expect "F1: a merge left open on a clean tree" "$P" 1 '^DIRTY .*half-done operation: MERGE_HEAD'

mk f2; P=$BASE/f2/proj; ( cd "$P" && git update-index --assume-unchanged a.txt && echo hidden >> a.txt )
expect "F2: an edit under assume-unchanged is printed, not judged" "$P" 0 '^OK .*1 path(s) under hide bits: a.txt'

mk sub; mk f3; P=$BASE/f3/proj
( cd "$P" && git submodule add -q "$BASE/sub/remote.git" sub >/dev/null 2>&1 && git commit -q -m sub && git push -q origin main 2>/dev/null \
  && git config submodule.sub.ignore all && echo dirt >> sub/a.txt )
expect "F3: submodule dirt under ignore = all" "$P" 1 '^DIRTY .*1 uncommitted path(s)'

mk f5; P=$BASE/f5/proj; ( cd "$P" && git update-ref refs/stash HEAD )
expect "F5: a stash ref with no reflog" "$P" 1 '^DIRTY .*a stash ref exists'

mk f7; P=$BASE/f7/proj; git init -q --bare "$BASE/f7/elsewhere.git"
( cd "$P" && git remote set-url --push origin "$BASE/f7/elsewhere.git" )
expect "F7: the push URL differs from the fetch URL, and is empty" "$P" 1 '^DIRTY .*not at .*elsewhere.git as the same object: main, v1'

mk f8; P=$BASE/f8/proj; ( cd "$P" && git remote set-url --push origin "$BASE/f8/no-such-repo.git" )
expect "F8: a dead push URL is BLOCKED (exit 128), never dirty" "$P" 2 '^BLOCKED .*could not read: ls-remote .*no-such-repo.git: exit 128'
out=$(sh "$SC" "$P" 2>&1); printf '%s\n' "$out" | grep -q 'DIRTY' && bad "F8: a dead URL was reported as dirt" || ok "F8: no DIRTY word on the blocked line"

mk f10; P=$BASE/f10/proj; git init -q --bare "$BASE/f10/other.git"
( cd "$P" && git remote add other "$BASE/f10/other.git" )
expect "F10 / B3-1: two remotes; the declared name is one of them" "$P" 0 '^OK      '

mk b11; P=$BASE/b11/proj; git init -q --bare "$BASE/b11/second.git"
( cd "$P" && git remote set-url --push origin "$BASE/b11/remote.git" && git remote set-url --add --push origin "$BASE/b11/second.git" )
expect "B1-1: two push URLs; the second lacks every ref" "$P" 1 '^DIRTY .*not at .*second.git as the same object: main, v1'
( cd "$P" && git push -q "$BASE/b11/second.git" main v1 2>/dev/null )
expect "B1-1: both push URLs populated" "$P" 0 '^OK      '

mk b12; P=$BASE/b12/proj; ( cd "$P" && git config core.trustctime false )
expect "B1-2: a stat-trust setting is printed beside the verdict" "$P" 0 '^OK .*stat-trust settings: core.trustctime false'

mk b21; git clone -q --bare "$BASE/b21/remote.git" "$BASE/b21/main.git" 2>/dev/null
( cd "$BASE/b21/main.git" && git worktree add -q "$BASE/b21/wt" main 2>/dev/null )
expect "B2-1: a bare main repository plus one worktree is one non-bare worktree" "$BASE/b21/wt" 0 '^OK      '

mk b32; P=$BASE/b32/proj; ( cd "$P" && git branch v1 && git push -q origin refs/heads/v1 2>/dev/null )
expect "B3-2: a branch and a tag sharing a short name pair by full ref name" "$P" 0 '^OK      '
( cd "$P" && git commit -q --allow-empty -m e && git push -q origin main 2>/dev/null && git update-ref refs/heads/v1 HEAD )
expect "B3-2: the branch moved, the tag did not — only the branch is named" "$P" 1 '^DIRTY .*as the same object: v1$'

# ---- several repositories, the implicit project row, the path map
mk multi; P=$BASE/multi/proj; mk other; echo x > "$BASE/other/proj/new.txt"
table "$P" "$BASE/other/proj|remote origin"
out=$(sh "$SC" "$P" 2>&1); got=$?
if [ "$got" -eq 1 ] && printf '%s\n' "$out" | sed -n 1p | grep -q "^DIRTY   $P: 1 uncommitted" \
   && printf '%s\n' "$out" | sed -n 2p | grep -q '^DIRTY .*other/proj: 1 uncommitted'; then
  ok "the project itself is checked first when its row is missing; one line per repository"
else bad "implicit project row (exit $got)"; printf '%s\n' "$out" | sed 's/^/        | /'; fi
settle "$P"
table "$P" "$BASE/other/proj|remote origin" "$BASE/clean|remote origin"; settle "$P"
out=$(sh "$SC" "$P" 2>&1); got=$?
[ "$got" -eq 1 ] && ok "exit 1 when one line is DIRTY and another BLOCKED" || { bad "exit precedence: got $got"; printf '%s\n' "$out" | sed 's/^/        | /'; }

mk mapped; mkdir -p "$BASE/real"; mv "$BASE/mapped/proj" "$BASE/real/p1"
mk host; P=$BASE/host/proj; table "$P" "~/Projects/p1|remote origin"; settle "$P"
out=$(ALLOSTATIK_PATH_MAP="~/Projects=$BASE/real" sh "$SC" "$P" 2>&1); got=$?
if [ "$got" -eq 0 ] && printf '%s\n' "$out" | grep -q '^OK      ~/Projects/p1$'; then ok "ALLOSTATIK_PATH_MAP rewrites a leading prefix; the line keeps the path as stated"
else bad "path map (exit $got)"; printf '%s\n' "$out" | sed 's/^/        | /'; fi
out=$(sh "$SC" "$P" 2>&1); got=$?
[ "$got" -eq 2 ] && printf '%s\n' "$out" | grep -q '^BLOCKED ~/Projects/p1: could not read' && ok "without the map, ~ expands against HOME and the missing path is BLOCKED" || bad "unmapped ~ path (exit $got)"

# ---- the file itself
if command -v sha256sum >/dev/null 2>&1; then SUM="sha256sum"; else SUM="shasum -a 256"; fi
stamp=$(sed -n '2s/.*sha256:\([0-9a-f]\{12\}\).*/\1/p' "$SC")
body=$(awk 'NR == 2 { s = 1; next } /^# END allostatik-state-check$/ { s = 0 } s' "$SC" | sed 's/\r$//' | $SUM | cut -c1-12)
[ "$stamp" = "$body" ] && ok "the BEGIN stamp matches the body hash ($body)" || bad "stamp $stamp != body hash $body — edited without scripts/stamp-regions.py --write"
[ "$(sed -n '1p' "$SC")" = "#!/bin/sh" ] && ok "line 1 is the sh shebang, line 2 the BEGIN marker" || bad "line 1 is not #!/bin/sh"
[ "$(tail -n 1 "$SC")" = "# END allostatik-state-check" ] && ok "the END marker is the last line" || bad "last line is not the END marker"
sh -n "$SC" && ok "parses under sh" || bad "does not parse under sh"
grep -n 'python\|perl\|node\|ruby' "$SC" | grep -v '^[0-9]*:#' >/dev/null && bad "calls something other than shell and git" || ok "shell and git only — no other runtime named"

echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

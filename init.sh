#!/bin/sh
# allostatik init — places the allostatik/ template files into a project.
# Mechanical only, by design: this script fetches REAL files and puts them in
# the RIGHT place. The walkthrough that fills them stays in workflow.md's
# first-run routine (greenfield) or its migrate routine (existing project) —
# run by whatever AI surface you use. Automate the mechanical; gate the meaningful.
#
# Usage:
#   From a clone of allostatik/allostatik:   ./init.sh /path/to/your-project
#   Without cloning (public repo):       curl -fsSL https://raw.githubusercontent.com/allostatik/allostatik/main/init.sh | sh -s -- /path/to/your-project
set -eu

REPO_TARBALL="https://github.com/allostatik/allostatik/archive/refs/heads/main.tar.gz"
BOILERPLATE="templates/project-boilerplate"

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: init.sh /path/to/your-project" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "error: $TARGET is not a directory" >&2; exit 1; }

# --- Probe: a pre-rename install. allostat/ is the old-generation folder name
# (renamed to allostatik/ at 0.3.0); scaffolding beside it would orphan it silently.
if [ -d "$TARGET/allostat" ]; then
  echo "STOP: $TARGET/allostat exists — a pre-rename Allostat install (the folder is allostatik/ since 0.3.0)." >&2
  echo "Nothing was written. Migrate instead of re-scaffolding:" >&2
  echo "  https://github.com/allostatik/allostatik#migrating-from-allostat" >&2
  exit 2
fi

# --- Guard: the collision case. If target/allostatik exists and looks like the
# TOOL's repo (has templates/ or concepts.md), the adopter cloned the tool into
# the project — the #1 observed setup mistake. Refuse loudly with the fix.
if [ -d "$TARGET/allostatik" ]; then
  if [ -d "$TARGET/allostatik/templates" ] || [ -f "$TARGET/allostatik/concepts.md" ]; then
    echo "STOP: $TARGET/allostatik contains the Allostatik tool's own repo, not project files." >&2
    echo "The allostatik/ folder inside a project is reserved for the project's canonical files." >&2
    echo "Move the tool's clone elsewhere (e.g. ~/allostatik-repo), then re-run." >&2
    exit 2
  fi
  echo "STOP: $TARGET/allostatik already exists — refusing to overwrite." >&2
  echo "Looking to update an existing install? That is an upgrade, not a re-run:" >&2
  echo "  https://github.com/allostatik/allostatik/blob/main/CHANGELOG.md  (then the README's Upgrading section)" >&2
  echo "If this is a partial setup you want to redo, remove or rename it and re-run." >&2
  exit 2
fi

# --- Locate real template files: prefer a local clone (script run from repo),
# else fetch the tarball. NEVER generate or reconstruct files — if we can't
# get real ones, we stop. (An AI reconstructing these files from a README is a
# known failure mode; this script exists partly so that never has to happen.)
SRC=""
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -d "$SCRIPT_DIR/$BOILERPLATE" ]; then
  SRC="$SCRIPT_DIR/$BOILERPLATE"
else
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  echo "fetching templates from allostatik/allostatik..."
  curl -fsSL "$REPO_TARBALL" | tar -xz -C "$TMP" || {
    echo "error: could not fetch the repo. Do NOT let an AI reconstruct these files" >&2
    echo "from documentation — get the real repo (clone or ZIP) and re-run from it." >&2
    exit 3
  }
  SRC=$(find "$TMP" -maxdepth 4 -type d -name project-boilerplate | head -1)
  [ -n "$SRC" ] || { echo "error: boilerplate not found in fetched repo" >&2; exit 3; }
fi

# --- Place files.
cp -R "$SRC/allostatik" "$TARGET/allostatik"

# CLAUDE.md: never overwrite an existing one — the managed block gets added by
# hand (or by your AI, gated) per the template's own instructions.
if [ -f "$TARGET/CLAUDE.md" ]; then
  cp "$SRC/CLAUDE.md" "$TARGET/allostatik/CLAUDE.md.allostatik-block"
  CLAUDE_NOTE="existing CLAUDE.md left untouched — the Allostatik block to add is at allostatik/CLAUDE.md.allostatik-block"
else
  cp "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"
  CLAUDE_NOTE="CLAUDE.md placed (Claude Code manifest; harmless on other surfaces)"
fi

# AGENTS.md: same rule — never overwrite. Cursor and other AGENTS.md-reading
# surfaces load it from the project root.
if [ -f "$TARGET/AGENTS.md" ]; then
  cp "$SRC/AGENTS.md" "$TARGET/allostatik/AGENTS.md.allostatik-block"
  AGENTS_NOTE="existing AGENTS.md left untouched — the Allostatik block to add is at allostatik/AGENTS.md.allostatik-block"
else
  cp "$SRC/AGENTS.md" "$TARGET/AGENTS.md"
  AGENTS_NOTE="AGENTS.md placed (Cursor and other AGENTS.md surfaces; harmless elsewhere)"
fi

# --- Verify: every expected file landed.
MISSING=""
for f in project-instructions.md plan.md decisions.md observations.md vision.md workflow.md knowledge/resources.md knowledge/environment.md; do
  [ -f "$TARGET/allostatik/$f" ] || MISSING="$MISSING $f"
done
[ -z "$MISSING" ] || { echo "error: placement incomplete, missing:$MISSING" >&2; exit 4; }

# --- Detect mode for the walkthrough handoff.
MODE="greenfield"
for probe in README.md docs .cursorrules PLAN.md src; do
  [ -e "$TARGET/$probe" ] && MODE="existing" && break
done

echo ""
echo "allostatik/ placed in $TARGET  ($CLAUDE_NOTE; $AGENTS_NOTE)"
echo ""
echo "Next steps (the files take it from here):"
echo "  1. Point your project at the files. Claude Code or Cursor? Skip this"
echo "     step — the placed CLAUDE.md / AGENTS.md does it. Claude Desktop?"
echo "     This step is yours: create a project for this work (if one doesn't"
echo "     exist yet), then paste this block into its Project Instructions"
echo "     field. Other surfaces: the project-level instructions slot."
echo ""
echo "     ----- copy from here -----"
# Keep VERBATIM in sync with the README's "Point your project at the files"
# block (the parity test checks all three installers print it):
echo "     This is an Allostatik project. The canonical files in its \`allostatik/\`"
echo "     folder — \`project-instructions.md\`, \`workflow.md\`, \`plan.md\`,"
echo "     \`decisions.md\`, … — are the source of truth. At the start of a"
echo "     session, read them, follow \`workflow.md\`, treat them as authoritative,"
echo "     and flag anything stale rather than just following it. If they"
echo "     aren't set up yet, help me set them up — github.com/allostatik/allostatik"
echo "     is the reference."
echo "     ----- copy to here -----"
echo ""
echo "  2. Using git? Commit the fresh install as its own commit before you"
echo "     fill anything in (git init first if the folder isn't a repo yet) —"
echo "     every later diff is then provably yours."
if [ "$MODE" = "existing" ]; then
  echo "  3. This looks like an EXISTING project. In your first session, Claude should"
  echo "     follow workflow.md's 'First run — existing project (migrate)' routine:"
  echo "     it walks YOU through each file, drawing on your current docs — it must"
  echo "     not silently bulk-fill them. If it starts writing files without you,"
  echo "     stop it and point it at that routine."
else
  echo "  3. Fresh project: your first session runs workflow.md's first-run setup —"
  echo "     Claude proposes, you keep/change/drop, file by file."
fi
echo "  4. Confirm it took: new conversation in the project, ask 'where do things stand?'"

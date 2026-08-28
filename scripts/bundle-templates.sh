#!/usr/bin/env bash
# bundle-templates.sh — copy the canonical templates into the installer
# packages before publishing. The bundled copies are PUBLISH ARTIFACTS, not
# source: they're gitignored, and this script (re)creates them so the npm and
# pip packages carry a real, current fallback for offline installs.
#
# Run from anywhere in the repo:  scripts/bundle-templates.sh
# Then publish per installers/README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/templates/project-boilerplate"
NPM_DEST="$ROOT/installers/npm/templates/project-boilerplate"
PIP_DEST="$ROOT/installers/pip/src/allostatik/templates/project-boilerplate"

[ -d "$SRC/allostatik" ] || { echo "error: $SRC not found — run from the allostatik repo" >&2; exit 1; }

rm -rf "$NPM_DEST" "$PIP_DEST"
mkdir -p "$(dirname "$NPM_DEST")" "$(dirname "$PIP_DEST")"
cp -R "$SRC" "$NPM_DEST"
cp -R "$SRC" "$PIP_DEST"
# The upgrade path rides along (second channel for UPGRADING.md's cross-check):
for doc in UPGRADING.md CHANGELOG.md; do
  cp "$ROOT/$doc" "$(dirname "$NPM_DEST")/$doc"
  cp "$ROOT/$doc" "$(dirname "$PIP_DEST")/$doc"
done
# The licence text rides too: neither package root holds one in source, and a
# published package that carries no LICENSE ships its terms by reference only.
cp "$ROOT/LICENSE" "$ROOT/installers/npm/LICENSE"
cp "$ROOT/LICENSE" "$ROOT/installers/pip/LICENSE"
find "$ROOT/installers" -name '.DS_Store' -delete

echo "bundled: templates/project-boilerplate →"
echo "  installers/npm/templates/  ($(find "$NPM_DEST" -type f | wc -l | tr -d ' ') files)"
echo "  installers/pip/src/allostatik/templates/  ($(find "$PIP_DEST" -type f | wc -l | tr -d ' ') files)"
echo "  LICENSE → installers/npm/ and installers/pip/"
echo "Next: see installers/README.md 'Releasing' for the publish steps."

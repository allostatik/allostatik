# installers/ — the npx and pip packages

Canonical **source** for the two published installers. Both are ports of `init.sh` with **fetch-first-with-fallback** template sourcing: at install time they fetch the current templates from GitHub main, and fall back to the copy **bundled at build time** if the fetch fails (offline, blocked, no system tar). Fresh when online, always works, and both paths place real files — the never-reconstruct rule holds everywhere. `--offline` / `ALLOSTATIK_OFFLINE=1` skips the fetch (legacy `ALLOSTAT_OFFLINE=1` accepted until 1.0).

- `npm/` — publishes as [`allostatik` on npm](https://www.npmjs.com/package/allostatik): `npx allostatik init ./your-project`
- `pip/` — publishes as [`allostatik` on PyPI](https://pypi.org/project/allostatik/): `pip install allostatik && allostatik init ./your-project`

**Templates are not stored here** — `scripts/bundle-templates.sh` copies `templates/project-boilerplate/` (plus `UPGRADING.md` and `CHANGELOG.md`, so the packages carry a second copy of the upgrade path for the routine's cross-check) into each package right before publishing. The canonical templates live in `templates/`; anything under `installers/npm/templates/` or `installers/pip/src/allostatik/templates/` is a gitignored publish artifact. (DRY: one source, assembled copies.)

**Behavior parity is a tested invariant.** `scripts/test-installers.sh` runs init.sh, the npm bin, and the pip CLI against identical scratch projects (greenfield, existing, collision, tool-repo-collision) and diffs the resulting trees and exit codes. Run it after touching any of the three.

**Releasing:**

1. **Sign in first — assume the session expired.** It has been, at every release so far. `npm whoami` is the check: on E401, run `npm login` (bare — never piped; it's a browser/passkey flow) and re-run the check. Skipped, an unauthenticated `npm publish` fails as **404 Not Found**, not "please sign in" (E401 masking as E404).
2. Bump `version` in `npm/package.json` and `pip/pyproject.toml` + `pip/src/allostatik/__init__.py` (keep them in lockstep).
3. **Write the `CHANGELOG.md` entry** — headed `## X.Y.Z — date — <two-word title>` with **Tag:** `vX.Y.Z`, then *What's new* (three to five short lines), *Why it's worth it* (one paragraph), *Takes about N minutes*, *To upgrade* (the prompt to paste, or a pointer to the bootstrap one). **Voice: an App Store "What's New" note** — plain, benefit-led, readable by someone who has never opened the repo; no region names, hashes, or internals — those live in `UPGRADING.md`. Exemplars: Apple's and Instagram's update descriptions. The suite refuses a head entry whose version doesn't match the package.
4. **Restamp and verify.** `scripts/stamp-regions.py --write` — always, because the stamps carry the version you just bumped (and the new hash, if Part 1 of the template `workflow.md` or the `CLAUDE.md` / `AGENTS.md` fences changed); then `scripts/stamp-regions.py` (verify) and `scripts/test-installers.sh` — both must pass.
5. `scripts/bundle-templates.sh` (refreshes the bundled fallback from `templates/`).
6. **Commit, tag, publish, then push — in that order.** Commit with an explicit file list; `git tag -a vX.Y.Z -m "X.Y.Z"`; `cd installers/npm && npm publish`; `cd installers/pip && rm -rf dist && python3 -m build && twine upload dist/*` (`python3` — macOS ships no `python` shim; `rm -rf dist` keeps stale artifacts out of the upload; if `twine` isn't on PATH, run it as `uvx twine` or `python3 -m twine`); then `git push origin main vX.Y.Z`. Commit and tag *before* publishing so npm records the release commit in the package's `gitHead` — the upgrade routine's cross-check compares it with the commit the tag resolves to; push *after* publishing so a failed publish never leaves a tag on the remote pointing at something that didn't ship (`git tag -d vX.Y.Z`, fix, re-tag).
7. **Confirm from the outside:** `git ls-remote --tags origin` shows the tag; `npm view allostatik version gitHead`; `pip index versions allostatik` (or the PyPI page). Report the release as done only after those reads.

Online installs always get current `main` automatically; the bundled fallback advances only via republish — so republish after significant template changes to keep offline installs close. `init.sh` and the repo always carry current `main`. **Upgrades** are different: they fetch the release tag named in `CHANGELOG.md`, never `main` — a template fix reaches existing installs only when it's released, which is the point.

*Queued (s95): `scripts/release.sh <version>` — the ritual above as one script with the sign-in gate, lockstep bump, changelog-head check, stamp verify, suite, bundle, commit, tag, publish, push. The 0.3.4 release was the last by-hand run; whatever it fumbled is that script's spec.*

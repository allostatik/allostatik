# installers/ — the npx and pip packages

Canonical **source** for the two published installers. Both are ports of `init.sh` with **fetch-first-with-fallback** template sourcing: at install time they fetch the current templates from GitHub main, and fall back to the copy **bundled at build time** if the fetch fails (offline, blocked, no system tar). Fresh when online, always works, and both paths place real files — the never-reconstruct rule holds everywhere. `--offline` / `ALLOSTATIK_OFFLINE=1` skips the fetch (legacy `ALLOSTAT_OFFLINE=1` accepted until 1.0).

- `npm/` — publishes as [`allostatik` on npm](https://www.npmjs.com/package/allostatik): `npx allostatik init ./your-project`
- `pip/` — publishes as [`allostatik` on PyPI](https://pypi.org/project/allostatik/): `pip install allostatik && allostatik init ./your-project`

**Templates are not stored here** — `scripts/bundle-templates.sh` copies `templates/project-boilerplate/` into each package right before publishing. The canonical templates live in `templates/`; anything under `installers/npm/templates/` or `installers/pip/src/allostatik/templates/` is a gitignored publish artifact. (DRY: one source, assembled copies.)

**Behavior parity is a tested invariant.** `scripts/test-installers.sh` runs init.sh, the npm bin, and the pip CLI against identical scratch projects (greenfield, existing, collision, tool-repo-collision) and diffs the resulting trees and exit codes. Run it after touching any of the three.

**Releasing:**

1. **Sign in first — assume the session expired.** It has been, at every release so far. `npm whoami` is the check: on E401, run `npm login` (bare — never piped; it's a browser/passkey flow) and re-run the check. Skipped, an unauthenticated `npm publish` fails as **404 Not Found**, not "please sign in" (E401 masking as E404).
2. Bump `version` in `npm/package.json` and `pip/pyproject.toml` + `pip/src/allostatik/__init__.py` (keep them in lockstep).
3. `scripts/bundle-templates.sh` (refreshes the bundled fallback from `templates/`)
4. `cd installers/npm && npm publish`
5. `cd installers/pip && rm -rf dist && python3 -m build && twine upload dist/*` — `python3` (macOS ships no `python` shim); `rm -rf dist` keeps stale artifacts out of the upload; if `twine` isn't on PATH, run it as `uvx twine` or `python3 -m twine`.

Online installs always get current main automatically; the bundled fallback advances only via republish — so republish after significant template changes to keep offline installs close. `init.sh` and the repo always carry current main.

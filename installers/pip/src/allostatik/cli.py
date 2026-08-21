"""allostatik init — places the allostatik/ template files into a project.

Python port of init.sh. Template sourcing is fetch-first-with-fallback: try
the CURRENT templates from the GitHub repo's main branch, and if the fetch
fails (offline, blocked) fall back to the copy BUNDLED in this package at
publish time. Fresh when online, always works offline, and both paths place
real files — never reconstructed ones. Pass --offline (or set
ALLOSTATIK_OFFLINE=1) to skip the fetch entirely. Same guards, same
verification, same next-steps — behavior parity with the npm package and
init.sh is a tested invariant (scripts/test-installers.sh).

Mechanical only, by design: this command puts REAL files in the RIGHT place.
The walkthrough that fills them stays in workflow.md's first-run routine
(greenfield) or its migrate routine (existing project) — run by whatever AI
surface you use. Automate the mechanical; gate the meaningful.

Usage:
    allostatik init /path/to/your-project
    allostatik init .          (from inside the project)

Exit codes (mirrors init.sh): 1 usage, 2 collision/refuse, 4 incomplete.
"""

from __future__ import annotations

import os
import shutil
import sys
import tarfile
import tempfile
import urllib.request
from importlib import resources
from pathlib import Path

from allostatik import __version__

REPO_TARBALL = "https://github.com/allostatik/allostatik/archive/refs/heads/main.tar.gz"
FETCH_TIMEOUT_S = 8

CORE_FILES = [
    "project-instructions.md",
    "plan.md",
    "decisions.md",
    "observations.md",
    "vision.md",
    "workflow.md",
    "knowledge/resources.md",
    "knowledge/environment.md",
]

EXISTING_PROBES = ["README.md", "docs", ".cursorrules", "PLAN.md", "src"]

USAGE = f"""allostatik {__version__} — installer for Allostatik (github.com/allostatik/allostatik)

Usage:
  allostatik init <path-to-your-project>   place the allostatik/ template files
                                         (fetches current templates from GitHub,
                                         falls back to the bundled copy; --offline
                                         or ALLOSTATIK_OFFLINE=1 skips the fetch)
  allostatik --version                     print version
  allostatik --help                        this message

Allostatik is not an app — it is a folder of canonical context files plus
session routines your AI follows. `init` places the real template files;
your first AI session walks you through filling them (workflow.md owns that).
"""


def _fail(msg: str, code: int) -> "NoReturn":  # noqa: F821 (py39-compatible)
    print(msg, file=sys.stderr)
    sys.exit(code)


def _bundled_boilerplate_dir() -> Path:
    """Locate the bundled real template files inside the installed package."""
    return Path(str(resources.files("allostatik"))) / "templates" / "project-boilerplate"


def _fetch_latest_boilerplate(tmp_root: Path) -> "Path | None":
    """Try to fetch the current templates from GitHub main.

    Returns the path to a project-boilerplate dir on success, or None on ANY
    failure (offline, HTTP error, unexpected layout) — the caller falls back
    to the bundle. Never raises.
    """
    try:
        tar_path = tmp_root / "allostatik-main.tar.gz"
        with urllib.request.urlopen(REPO_TARBALL, timeout=FETCH_TIMEOUT_S) as resp:
            tar_path.write_bytes(resp.read())
        with tarfile.open(tar_path, "r:gz") as tf:
            # Refuse anything that would extract outside tmp_root:
            for m in tf.getmembers():
                dest = (tmp_root / m.name).resolve()
                if not str(dest).startswith(str(tmp_root.resolve())):
                    return None
            tf.extractall(tmp_root)
        for entry in tmp_root.iterdir():
            candidate = entry / "templates" / "project-boilerplate"
            if (candidate / "allostatik").is_dir():
                return candidate
        return None
    except Exception:
        return None


def main(argv: "list[str] | None" = None) -> None:
    raw_args = list(sys.argv[1:] if argv is None else argv)
    offline = "--offline" in raw_args or os.environ.get("ALLOSTATIK_OFFLINE") == "1"
    if not offline and os.environ.get("ALLOSTAT_OFFLINE") == "1":  # legacy name, accepted until 1.0
        offline = True
        print("note: ALLOSTAT_OFFLINE is deprecated; use ALLOSTATIK_OFFLINE", file=sys.stderr)
    args = [a for a in raw_args if a != "--offline"]

    if "--version" in args or "-v" in args:
        print(__version__)
        return
    if not args or "--help" in args or "-h" in args:
        print(USAGE)
        sys.exit(1 if not args else 0)
    if args[0] != "init":
        _fail(f'error: unknown command "{args[0]}" — did you mean: allostatik init <path>?', 1)

    if len(args) < 2:
        _fail("usage: allostatik init /path/to/your-project", 1)
    target = args[1]
    target_abs = Path(target).resolve()
    if not target_abs.is_dir():
        _fail(f"error: {target} is not a directory", 1)

    # --- Probe: a pre-rename install. allostat/ is the old-generation folder
    # name (renamed to allostatik/ at 0.3.0); scaffolding beside it would
    # orphan it silently. Refuse and point at the migration steps.
    if (target_abs / "allostat").exists():
        _fail(
            f"STOP: {target}/allostat exists — a pre-rename Allostat install (the folder is allostatik/ since 0.3.0).\n"
            "Nothing was written. Migrate instead of re-scaffolding:\n"
            "  https://github.com/allostatik/allostatik#migrating-from-allostat",
            2,
        )

    # --- Guard: the collision case. If target/allostatik exists and looks like
    # the TOOL's repo (has templates/ or concepts.md), the adopter cloned the
    # tool into the project — the #1 observed setup mistake. Refuse loudly.
    target_allostatik = target_abs / "allostatik"
    if target_allostatik.exists():
        looks_like_tool_repo = (target_allostatik / "templates").is_dir() or (
            target_allostatik / "concepts.md"
        ).is_file()
        if looks_like_tool_repo:
            _fail(
                f"STOP: {target}/allostatik contains the Allostatik tool's own repo, not project files.\n"
                "The allostatik/ folder inside a project is reserved for the project's canonical files.\n"
                "Move the tool's clone elsewhere (e.g. ~/allostatik-repo), then re-run.",
                2,
            )
        _fail(
            f"STOP: {target}/allostatik already exists — refusing to overwrite.\n"
            "Looking to update an existing install? That is an upgrade, not a re-run:\n"
            "  https://github.com/allostatik/allostatik/blob/main/CHANGELOG.md  (then UPGRADING.md)\n"
            "If this is a partial setup you want to redo, remove or rename it and re-run.",
            2,
        )

    # --- Source the real template files: current repo main if reachable,
    # else the copy bundled in this package. NEVER generate or reconstruct —
    # if neither real source is available, the install is broken; stop.
    boilerplate: "Path | None" = None
    tmp_ctx = tempfile.TemporaryDirectory(prefix="allostatik-")
    try:
        if not offline:
            boilerplate = _fetch_latest_boilerplate(Path(tmp_ctx.name))
        if boilerplate is not None:
            template_note = "templates: current main from github.com/allostatik/allostatik"
        elif (_bundled_boilerplate_dir() / "allostatik").is_dir():
            boilerplate = _bundled_boilerplate_dir()
            template_note = (
                f"templates: bundled with package v{__version__} (--offline)"
                if offline
                else f"templates: bundled with package v{__version__} "
                "(GitHub not reachable — still real files, possibly not the newest)"
            )
        else:
            _fail(
                "error: could not fetch templates from GitHub and the bundled copy is missing.\n"
                "Do NOT let an AI reconstruct these files from documentation. Get the real\n"
                "files instead: reinstall the package, or use the curl fallback in the README\n"
                "at github.com/allostatik/allostatik.",
                3,
            )

        # --- Place files.
        shutil.copytree(boilerplate / "allostatik", target_allostatik)

        # CLAUDE.md: never overwrite an existing one — the managed block gets
        # added by hand (or by your AI, gated) per the template's instructions.
        target_claude_md = target_abs / "CLAUDE.md"
        if target_claude_md.exists():
            shutil.copyfile(
                boilerplate / "CLAUDE.md", target_allostatik / "CLAUDE.md.allostatik-block"
            )
            claude_note = (
                "existing CLAUDE.md left untouched — the Allostatik block to add is at "
                "allostatik/CLAUDE.md.allostatik-block"
            )
        else:
            shutil.copyfile(boilerplate / "CLAUDE.md", target_claude_md)
            claude_note = "CLAUDE.md placed (Claude Code manifest; harmless on other surfaces)"

        # AGENTS.md: same rule — never overwrite. Cursor and other
        # AGENTS.md-reading surfaces load it from the project root.
        target_agents_md = target_abs / "AGENTS.md"
        if target_agents_md.exists():
            shutil.copyfile(
                boilerplate / "AGENTS.md", target_allostatik / "AGENTS.md.allostatik-block"
            )
            agents_note = (
                "existing AGENTS.md left untouched — the Allostatik block to add is at "
                "allostatik/AGENTS.md.allostatik-block"
            )
        else:
            shutil.copyfile(boilerplate / "AGENTS.md", target_agents_md)
            agents_note = "AGENTS.md placed (Cursor and other AGENTS.md surfaces; harmless elsewhere)"
    finally:
        tmp_ctx.cleanup()

    # --- Verify: every expected file landed.
    missing = [f for f in CORE_FILES if not (target_allostatik / f).is_file()]
    if missing:
        _fail(f"error: placement incomplete, missing: {' '.join(missing)}", 4)

    # --- Detect mode for the walkthrough handoff.
    mode = (
        "existing"
        if any((target_abs / probe).exists() for probe in EXISTING_PROBES)
        else "greenfield"
    )

    # The pointer block — keep VERBATIM in sync with the README's "Point your
    # project at the files" block (the parity test checks all three installers
    # print it):
    pointer_block = [
        "     This is an Allostatik project. The canonical files in its `allostatik/`",
        "     folder — `project-instructions.md`, `workflow.md`, `plan.md`,",
        "     `decisions.md`, … — are the source of truth. At the start of a",
        "     session, read them, follow `workflow.md`, treat them as authoritative,",
        "     and flag anything stale rather than just following it. If they",
        "     aren't set up yet, help me set them up — github.com/allostatik/allostatik",
        "     is the reference.",
    ]
    lines = [
        "",
        f"allostatik/ placed in {target}  ({claude_note}; {agents_note})",
        f"  {template_note}",
        "",
        "Next steps (the files take it from here):",
        "  1. Point your project at the files. Claude Code or Cursor? Skip this",
        "     step — the placed CLAUDE.md / AGENTS.md does it. Claude Desktop?",
        "     This step is yours: create a project for this work (if one doesn't",
        "     exist yet), then paste this block into its Project Instructions",
        "     field. Other surfaces: the project-level instructions slot.",
        "",
        "     ----- copy from here -----",
        *pointer_block,
        "     ----- copy to here -----",
        "",
        "  2. Using git? Commit the fresh install as its own commit before you",
        "     fill anything in (git init first if the folder isn't a repo yet) —",
        "     every later diff is then provably yours.",
    ]
    if mode == "existing":
        lines += [
            "  3. This looks like an EXISTING project. In your first session, Claude should",
            "     follow workflow.md's 'First run — existing project (migrate)' routine:",
            "     it walks YOU through each file, drawing on your current docs — it must",
            "     not silently bulk-fill them. If it starts writing files without you,",
            "     stop it and point it at that routine.",
        ]
    else:
        lines += [
            "  3. Fresh project: your first session runs workflow.md's first-run setup —",
            "     Claude proposes, you keep/change/drop, file by file.",
        ]
    lines += ["  4. Confirm it took: new conversation in the project, ask 'where do things stand?'"]
    print("\n".join(lines))


if __name__ == "__main__":
    main()

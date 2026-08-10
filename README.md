# Allostatik

Your AI's context resets at every conversation, context window, and surface. What resets is the part you can't afford to lose — the decisions you've locked, the conventions you've settled, where the work actually stands.

Allostatik keeps that context in a folder of plain files you own — `allostatik/` in your project: plan, decisions, observations, project instructions — plus the session routines your AI runs against them: load and drift-check at open, update and hand off at close. Sessions stop opening cold, and corrections outlive the conversation they happened in. The difference from a hand-rolled rules file is the upkeep: the routines drift-check and update the files every session, so they stay true instead of quietly aging.

Nothing runs: no process, no background service, nothing to start or stop. The files act only when your AI reads them in a session, and removing Allostatik is deleting a folder. Setup takes about two minutes.

## Get started

You need a project on local storage — a folder or repo where an `allostatik/` directory can live. Language-agnostic. Starting from nothing? Create the folder first — `mkdir my-project && cd my-project` — an empty directory is a valid project.

**1. Add the `allostatik/` files.** One command — every path places the **real** template files. *(Real files only — if an AI offers to reconstruct them from this README, decline; a reconstructed set looks right and silently forks.)*

Navigate to your project's root folder in your terminal, then any of these works:

```
curl -fsSL https://raw.githubusercontent.com/allostatik/allostatik/main/init.sh | sh -s -- .
```

with npm:

```
npx allostatik init .
```

or with pip:

```
pip install allostatik && allostatik init .
```

*No spare project to try it in?* Use a git worktree of any repo you have — `git worktree add ../allostatik-trial && cd ../allostatik-trial`, install there, work a session or two, and `git worktree remove --force ../allostatik-trial` takes every trace with it. Your main checkout never changes.

All three fetch the current templates from this repo at install time; the npm and pip packages also carry a bundled copy as an offline fallback. Or fully by hand: get this repo (clone or Download ZIP) and copy `templates/project-boilerplate/allostatik/` into your project root — plus `CLAUDE.md` if you use Claude Code (already have a `CLAUDE.md`? add Allostatik's block to it, don't replace it).

> **Where things go:** the tool's repo and your project's `allostatik/` folder are different things that share a name. Don't clone this repo *into* your project — the `allostatik/` folder inside your project is reserved for your project's own files; every installer checks for this mistake and stops you.

Using git? Commit the fresh install as its own commit before you fill anything in (`git init` first if the folder isn't a repo yet) — every later diff is then provably yours.

**2. Point your AI at the files.** The simplest start: paste this block into a conversation in your project and go — the first session works from it and helps you make the pointer permanent:

> This is an Allostatik project. The canonical files in its `allostatik/` folder — `project-instructions.md`, `workflow.md`, `plan.md`, `decisions.md`, … — are the source of truth. At the start of a session, read them, follow `workflow.md`, treat them as authoritative, and flag anything stale rather than just following it. If they aren't set up yet, help me set them up — github.com/allostatik/allostatik is the reference.

Its permanent home is your project's instructions (in Claude Desktop: create a project for this work if you haven't yet, then paste into its **Project Instructions** field — Desktop genuinely needs this step; using Claude Code? the placed `CLAUDE.md` already does it; using Cursor? the placed root `AGENTS.md`/`CLAUDE.md` covers it; on other surfaces, the project-level instructions slot). The block is only the pointer — the files carry the actual instructions.

**3. Start your first session.** Open a conversation in the project and ask where to start. The pointer you just deployed makes Claude load the files; `workflow.md` runs the rest — it owns the session routines, including this first one. (This works best when your AI can read and write the project's files — Claude Code, Cursor, or Claude Desktop with file access. No file access? `workflow.md` covers paste-based setups; you'll want to be comfortable in the terminal.)

- **Fresh project** → *First run — set up the files*: Claude proposes each file from what you tell it; you keep / change / drop, file by file.
- **Existing project** (most people) → *First run — existing project (migrate)*: Claude inventories what your project already knows — README, planning docs, rules files — then walks *you* through folding it into the files, with a final cross-check so nothing is silently dropped. If Claude starts bulk-filling the files without you, stop it and point it back at that routine in `workflow.md`.

**4. Confirm it took.** Start a fresh conversation in the project and ask "where do things stand?" Claude should load your files and orient — a drift-check, then current state and next work. If it doesn't, the pointer isn't deployed or points at the wrong place.

**Optional, once per account:** one line in your Custom Instructions (in Cursor, the same slot is Settings → Rules → **User Rules**) lets Claude recognize *any* Allostatik project without a per-project pointer doing all the work:

> Some of my projects use a layered context system: canonical files (an `allostatik/` folder, with a `CLAUDE.md` listing what to load) that are the source of truth. When a project has them: load them, treat them as authoritative, follow its `workflow.md` to keep them in sync (drift-check at start, update at close), and flag anything stale rather than following it. If a project doesn't have them, ignore this.

A pointer, not a setup. The routine lives in each project's `workflow.md`.

## What you just installed

- **How it runs.** Open: load the files, drift-check the canonical copies against every deployed one, reconcile before work. Work: the files are the source of truth — stale content gets flagged, not followed. Close: update the files, re-deploy, hand off with pointers rather than copies. Every routine ships with the cheap check that proves it ran.
- **Why files.** You read exactly what loads, change any of it, and approve what persists. Vendor memory is synthesized; a UI setting goes stale; files are curated, versioned, travel with the repo — and get touched every session, so they can't quietly decay. Each surface becomes an adapter over one shared core instead of another partial copy of you.
- **What you get.** Context stays lean — knowledge is pointed at, not pasted in. Nothing rewrites your files without your sign-off. And the setpoints themselves can move: stray from a convention once and the files correct you back; stray the same way repeatedly and the system asks whether the convention still fits.

The full case is in [why.md](./why.md); the design reasoning is in [concepts.md](./concepts.md).

### The files

Each has one job:

- **`allostatik/project-instructions.md`** — what this project is: purpose, conventions, domain notes. Fill in first.
- **`allostatik/plan.md`** — done / current / next. Read it to resume.
- **`allostatik/decisions.md`** — locked choices and the reasoning. Mark changes, don't delete.
- **`allostatik/observations.md`** — patterns and corrections worth keeping.
- **`allostatik/vision.md`** — where the project's headed at the longer horizon, and why. Optional; leave it thin until there's direction beyond the plan.
- **`allostatik/workflow.md`** — the session routines: open, drift-check, close, handoff, and both first-run paths. Ships as a working default; edit rarely.
- **`allostatik/knowledge/`** — your environment and project references, pointed at rather than copied in.
- **`allostatik/skills/`** — documented capabilities. Optional.
- **`CLAUDE.md`** (project root) — manifest declaring what loads each session; the drift-check reads it. Your project may already have one — **add Allostatik's block, don't overwrite**.

### How a session goes

```mermaid
flowchart TD
    PROJ["Project instructions<br/>point at the files"]
    CF["Canonical files · allostatik/<br/>your project's source of truth"]
    OPEN["Session open<br/>load · drift-check · reconcile"]
    WORK["Work<br/>files are the source of truth · flag drift"]
    CLOSE["Session close<br/>update · re-deploy · handoff"]
    DEP[/"Deployed copies<br/>in your tools"/]
    GATE(["You set the gate"])

    PROJ --> CF
    CF --> OPEN
    OPEN <-. drift-check .-> DEP
    OPEN --> WORK
    WORK --> CLOSE
    CLOSE -. handoff carries to next session .-> OPEN
    GATE -.-> OPEN
    GATE -.-> CLOSE
```

1. **Open** — drift-check, reconcile.
2. **Work.**
3. **Close** — update files, re-deploy, write handoff. You approve each step.

The routines live in your project's `workflow.md`; they also ship as installable skills (this repo's `skills/` folder — `allostatik-open`, `allostatik-close`, `allostatik-checkpoint`) if your surface supports skills. The skills are thin triggers that make your AI run the `workflow.md` routine at the right moment — the files stay the source of truth.

## Status

**Working:** templates, drift-check, close/update, handoffs, the `allostatik` installers on npm and PyPI (fetch-first with a bundled offline fallback, behavior-parity-tested against `init.sh` — including the pointer block they print), `init.sh` (placement + collision guard), the migrate routine for existing projects, and the shipped skills — `allostatik-init` plus the three session-ritual skills (`allostatik-open`, `allostatik-close`, `allostatik-checkpoint`).

**Planned:** cross-surface deploy guides (which field is "project instructions" on each surface — Desktop/Cowork, Cursor, web).

## Feedback

Issues and PRs welcome — templates and docs especially. Your project config stays yours.

## License

MIT.

## Disclaimer

Allostatik is a set of files and conventions for managing the context an AI assistant works from. The assistant's responses are generated, non-deterministic, and may be inaccurate or incomplete — they are the assistant's output, not the author's. Verify anything that matters before relying on it. Allostatik is for general productivity and configuration purposes and is not legal, financial, medical, safety, or other professional advice. You are responsible for how you use it and for any actions taken on your behalf. Provided "as is", without warranty, under the MIT License.

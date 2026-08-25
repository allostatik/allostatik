# [PROJECT-NAME] — Project Instructions

Canonical template source: allostatik/templates/project-boilerplate/allostatik/project-instructions.md
Project-scope location: [YOUR-PROJECT-ROOT]/allostatik/project-instructions.md
Paste destination: [YOUR-DEPLOYMENT-TARGET]
Edit at the project-scope location above; sync to the paste destination per your storage mode. Drift-checked at session start and end. Path style: in any text that gets pasted into a prompt, write paths `~/`-relative or backtick-wrapped — a line-leading absolute path reads as a slash command.

---

## Session rituals

This project's current state lives in files in the `allostatik/` folder — not in these instructions, which describe the *system*, not where it currently is. On a filesystem surface (Claude Code, Cursor, Claude Desktop with file access) those files load from the repo, and `workflow.md` holds the full routines. These two rituals are the short version:

**Opening.** Before answering anything that depends on current state — "where are we," "what's next," the status of any work — load the `allostatik/` files if you don't already have them, then run the open checks: is `log.md`'s session log current (if it's behind, a prior close was skipped — backfill it before new work), and do the deployed surfaces still match canonical? Don't reconstruct state from these instructions alone.

**Closing.** When a session wraps up, update the canonical files for whatever changed (`plan.md`, `decisions.md`, `observations.md`) and confirm the writes landed **before** producing any handoff — the handoff *points at* those files, it doesn't carry state. This is what makes each session build on the last rather than start over.

*(Full open/close routines — the five drift-checks, capture, and handoff shape — live in `allostatik/workflow.md`, which loads alongside these files.)*

## Mode

I'm in **[YOUR-MODE]** mode for this project.

*Common modes: `engineering`, `design`, `research`, `writing`, `learning`, `personal`, `hobby`, `meta` (managing the methodology itself). Pick one that fits the dominant work shape.*

## Purpose

[YOUR-PROJECT-PURPOSE]

*1–3 sentences. What is this project for? What outcome am I after? Stable across sessions — if the answer changes session-to-session, it belongs in a handoff, not here.*

## Destination (optional)

*Optional. Develop if this project has cross-session direction beyond its Purpose — long-arc outcomes, compound-over-time vision, multi-stage destination. Delete this section if Purpose covers it.*

## Known references

Project reference material lives in `allostatik/knowledge/` (project-scope Layer 3) — Claude reads it from there rather than from a list restated here. External references go in `resources.md` (as `name` / `description` / `location` entries, each description saying when to reach for it); local copies of documents go in `docs/`, indexed by `docs/README.md`. (`allostatik/knowledge/` also holds `environment.md`, the project-runtime environment.)

*Maintain references by editing the files in `allostatik/knowledge/` — that folder is the source of truth; there's nothing to enumerate here.*

## Project-specific working notes

*Free-form section for project-specific conventions, anti-patterns, recurring observations, structural notes Claude should know.*

- **[Convention or pattern].** [Brief description.]
- **[Anti-pattern to watch for].** [What it looks like; what to do instead.]

*Keep this section trimmed — it's the per-project layer, not a dumping ground. If a new pattern surfaces during work, ask which layer it belongs to before applying it anywhere: identity (L1), domain (L2, this file), knowledge (L3, `allostatik/knowledge/`), or skills (L4, `allostatik/skills/`). Capture at the right layer so it propagates automatically.*

## Standing essentials bundle

*Bundle command to load the project's canonical files into a new conversation. Primary loading for paste-loaded and no-storage adopters; fallback for MCP- and `@`-import-equipped surfaces (where canonical files load automatically) when manual re-load is needed.*

```bash
{
  cd <project-root> && \
  for f in \
    allostatik/project-instructions.md \
    allostatik/plan.md \
    allostatik/workflow.md \
    <additional-canonical-files> ; do
    echo "===== FILE: $f ====="
    cat "$f"
    echo ""
  done
} 2>&1 | <clipboard-pipe>
```

- **macOS:** `tee >(pbcopy)`
- **Linux:** `tee >(xclip -selection clipboard)` (requires `xclip` installed)
- **Windows (Git Bash):** `tee /dev/clipboard`

*The bundle is **stable** — the same canonical files every session. Includes `project-instructions.md` itself so drift-check between canonical and deployed works on any surface. Per-session file shares (e.g., a specific commit's diff) belong in that session's handoff, not here.*

## Other files available on request

*Beyond the Standing essentials bundle above, files Claude might ask for case-by-case.*

- Recent commits, for structural history:
  `{ cd <project-root> && git log --oneline -20 ; } 2>&1 | tee >(pbcopy)`
- Last commit details:
  `{ cd <project-root> && git log -1 --stat ; } 2>&1 | tee >(pbcopy)`
- [Additional file Claude might need, with retrieval command]

## Handoffs (optional)

*Optional. Develop if this project has handoff conventions beyond what `allostatik/workflow.md` covers — required sections, checkpoint formats, project-specific carries. Delete this section if generic handoff workflow is sufficient.*

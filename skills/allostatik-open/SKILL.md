---
name: allostatik-open
description: Run the Allostatik session-open ritual — load canonical files, drift-check, orient. Use at the start of any session in a project with an allostatik/ folder, or when the user asks "where do things stand", "orient", "catch up", "start the session", or opens with a handoff. Do not start substantive work in an Allostatik project before this has run.
---

# allostatik-open — start the session from the files

You are opening a session in an Allostatik project. The routine you are about to
run is NOT in this skill — it is the **Session open** and **Drift-check**
sections of the project's own `allostatik/workflow.md`. Read them and follow them
as written. This skill exists to make sure that happens, and to hold the rules
that protect the routine from shortcuts.

## Hard rules (these outrank helpfulness)

1. **The project's `workflow.md` is authoritative, not this skill.** Projects
   customize Part 2 and may log skip rows in `decisions.md`. If this skill and
   the project's files disagree, the files win.
2. **No substantive work before the open completes.** Every open step the
   project's file lists, in its order. This skill deliberately gives no count
   and no step numbers: it was written when there were six, a seventh was added
   at 0.3.7, and a skill that enumerates drifts silently the first time the
   routine grows. The user asking an eager first question does not waive the
   ritual — fold the answer into the session-plan step.
3. **Every check failure follows the same pattern: halt, surface, ask.** Never
   silently reconcile drift, never guess at a missing file, never proceed on
   assumption.
4. **Drift-check compares what IS, not what you remember.** Re-read the
   canonical file from disk and the deployed surface as it reads now. If a
   deployed surface can't be read back on this surface, say so and carry it as
   a reconcile-before-work item — an un-runnable check is not a passed check.
5. **A stale session log means a skipped close.** If `log.md`'s newest entry is
   behind reality, backfill it before any new work (workflow.md's session-log
   freshness check says how). On an install from before 0.3.5 the log still
   lives in `plan.md`; the freshness check names that case.

## Flow

1. Locate and read, in order: the handoff (if one exists), then
   `allostatik/workflow.md` **Session open** + **Drift-check**, then the files
   they point at (`project-instructions.md`, `plan.md`, and the rest of the
   canonical set).
2. Execute every Session open step exactly as the project's copy states it, in
   that file's order and numbering — the file is the list, this is not. At 0.3.7
   it runs: verify capability → read context (including the ledger's tail) →
   read the record and check its size against the budget → drift-check → state
   the goal in plain words and wait for approval → mark the session open in the
   ledger. Read the count off the file.
   A `STEP` line in the ledger with no matching `STEP-DONE` means a long routine
   — a first run or a migration — died mid-flight. Surface it before the goal;
   resuming it at the next unrecorded step *is* the goal.
3. If the handoff carries a "DO BEFORE THIS HANDOFF IS CONSUMED" item, it goes
   first — before the goal.

## What good looks like

The user gets: any drift surfaced and reconciled (or explicitly carried), a
goal for the session in plain words — how we got here, what it is for, what we
might learn, what done looks like — that they approved, all before any real work
happened.

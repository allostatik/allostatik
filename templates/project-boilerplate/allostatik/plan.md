# [PROJECT-NAME] — Plan

This file holds the project's **operational state**: where things stand, what's in flight, where it's going, and in what order it gets there. The architecture — what a layer is, how the pieces compose — lives in `CLAUDE.md` and the README. The project's purpose and direction live in `project-instructions.md` and `vision.md`. This file is the live state in between.

It ships as a lean spine: these section headers plus the discipline for keeping them current. Claude seeds the per-project content at setup and grows it across sessions via the close routine — so unlike the other templates, you won't find blanks to fill in here.

---

## Living document discipline

Keep this file current at session close, as part of the close routine in `workflow.md` — that routine owns the *how*; this is just what to touch here:

- **Status changed?** Update Current state.
- **Item finished or deferred? Mark it.** Strike a done block's head line with `~~`, or put `[parked]` on a deferred
  section's or item's head line with its trigger written into that line. The close moves the body out and leaves the head
  line with a pointer, so nothing is deleted by hand. See `RETIRING.md` in the tool's repo.
- **New work surfaced?** Add it to Sequenced work, naming its sequencing strategy.
- **Session done?** Append an entry to `log.md`.

This file is **operational state** only. Don't duplicate `decisions.md` (locked choices) or `observations.md` (recurring process patterns) — point at them, and let each be the source of truth for its own domain.

## Current state

<!-- A snapshot of where the project stands right now. Claude seeds the shape that fits — a short status list, a small table, or a few lines of prose — and keeps it current at each close. No prescribed format; match it to the project. -->

## Sequenced work in flight

<!-- The forward work queue. Claude seeds the items at setup and maintains them at each close — adding new work, removing what's done. Items are seeded, not adopter-filled. -->

Each item names the **sequencing strategy** that explains its place in the queue:

- **dependency** — X has to come before Y.
- **relatedness** — group it with related work as one cohesive piece.
- **importance** — highest-value first.
- **learning** — do it first because it informs what comes next.
- **bake-time** — let it settle before acting.
- **external trigger** — wait for an explicit signal.
- **blast radius** — smallest, most reversible first.

## Triggered reviews

<!-- Optional. Conditional maintenance tasks, each naming the trigger that fires it — "when [condition] → review [X]". Claude seeds any the project needs and leaves this empty otherwise; skip the section entirely if there are none. Example: when a core dependency ships a major version → review whether the setup still fits. -->

## Open questions

<!-- A holding area for deferred or not-yet-actionable questions, so they don't get lost between sessions. Claude seeds and maintains these; starts empty. -->

## Cross-references

<!-- Pointers to the sibling files this one leans on — point, don't duplicate (each is the source of truth for its own domain). Prune to the files this project actually has. -->

- `project-instructions.md` — identity, purpose, mode, and domain context (Layer 2).
- `workflow.md` — the session routines (open, drift-check, close, capture, handoff).
- `log.md` — the session log, append-only; the close appends one entry per session and the next open reads the newest.
- `decisions.md` — locked choices, with the reasoning behind them.
- `observations.md` — recurring process patterns.
- `vision.md` — the project's longer-arc direction.
- `knowledge/` — project-scope reference material (Layer 3).
- `skills/` — capability docs (Layer 4).

# [PROJECT-NAME] — Decisions

Locked decisions about how this project works — architectural choices, conventions, and resolved tradeoffs. Once something is locked here, don't renegotiate it without raising a checkpoint. This file is the project's reasoning trail: it records not just *what* was decided but *why*, so a later session doesn't relitigate settled ground.

This is the decisions layer, distinct from its `allostatik/` siblings — `plan.md` holds current operational state (what's in flight), `observations.md` holds process patterns (how the work tends to go). Point at those rather than restating them here.

**Update protocol.** At session close, append decisions locked during the session. Write the first cell as a claim that says what the decision changes, not as a topic. It is the line an index carries, and the sentence the user approved at the close. If a locked decision later changes, mark it rather than deleting it — the trail matters:

- `[SUPERSEDED <date>]` — full overturn. Replace the Choice with the marker plus a pointer to the row that replaces it.
- `[AMENDED <date>]` / `[PARTIALLY SUPERSEDED <date>]` — partial change where the original mostly holds. Prefix the marker to the Choice; leave the original text intact.

Always name the superseding or amending row so the trail stays followable.

**Last updated:** [YYYY-MM-DD]

| Decision | Choice | Rationale |
|---|---|---|
<!-- One decision per row; keep Choice terse and Rationale to a line or two. Example (delete once you have real rows):
| Storage mode | Direct-read via MCP, this repo only | Smallest useful scope; per-call approval is the safeguard |
-->

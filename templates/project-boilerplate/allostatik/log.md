# [PROJECT-NAME] — Session log

<!-- The cumulative, session-by-session record of what happened — the project's whole story, and the durable archive the handoff is only a recent view of. The close routine appends one entry per session (see *Living document discipline* in `plan.md` and the close routine in `workflow.md`). Claude seeds and grows it; starts empty. One exception: a project upgraded from 0.3.4 or earlier, where the entries start out in `plan.md`'s *Session log* section and belong here. Move them first, or the open's freshness check reads an empty file and reports a skipped close.
Entry skeleton: Session [N] ([DATE]): [OUTCOMES] → [NEXT]
Identifier: default is sequential "Session N". Keep it, or switch to date- or milestone-based naming, or drop explicit numbering — the skeleton and append-at-close discipline stay fixed either way. -->

Append-only: never rewrite or delete an entry. This file lives apart from `plan.md` so the spine that loads every session stays bounded while the record grows without limit — it is read on demand: its newest entry at the open (the drift-check's freshness check), the rest by grep.

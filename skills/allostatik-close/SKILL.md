---
name: allostatik-close
description: Run the Allostatik session-close ritual — update canonical files, confirm saves, commit, write the handoff. Use when the user says "wrap up", "close the session", "close it out", "end of session", "write the handoff", or signals they're done working in a project with an allostatik/ folder. The close is what makes sessions compound — treat a session-end signal as a trigger, not a suggestion.
---

# allostatik-close — carry the session's state forward

You are closing a session in an Allostatik project. The routine is NOT in this
skill — it is the **Session close** and **Writing the handoff** sections of the
project's own `allostatik/workflow.md`, plus any *Closing-protocol additions* in
its Part 2. Read them and follow them as written. This skill makes sure that
happens, in the right order, without shortcuts.

## Hard rules (these outrank helpfulness)

1. **The project's `workflow.md` is authoritative, not this skill.** Its Part 2
   may add close steps or skip rows; they apply.
2. **Order is load-bearing; the handoff is LAST.** Verify this session opened in
   the ledger → debrief → update canonical files → re-paste deployed
   surfaces → confirm it landed → mark the session closed in the ledger →
   commit and push (if version control) → project-specific additions → handoff
   → name the session. A handoff written before saves are confirmed describes
   assumed state, not real state. **The two ledger steps are steps of the close,
   not bookkeeping around it** — the first is how a skipped open gets caught, and
   omitting either leaves the next session's open unable to tell a clean finish
   from an abandoned one.
3. **"Confirm it landed" means evidence, not intention.** Use the strongest
   check the setup allows — `git status` showing exactly the edited files, a
   re-read of what's on disk, or the user confirming manual saves. An edit you
   made earlier in the conversation is not evidence it's on disk now.
4. **Nothing derived this session may end up orphaned.** The debrief's last two
   questions catch content that was produced and referenced but never written
   into a canonical file. Name orphans; route each to the file that owns it.
5. **The user gates every write.** Propose the updates per file; apply on
   approval. If something can't be persisted this session (a re-paste the user
   must do), it goes at the top of the handoff as a "DO BEFORE THIS HANDOFF IS
   CONSUMED" item — never silently dropped.
6. **Handoffs point, they don't restate.** The top mirrors the next open:
   the next session's goal in four parts, then the debrief, then required
   reading, then a pointer to the routines; technical detail beneath. Detail that lives in `plan.md` or `decisions.md`
   is referenced, not copied — copies go stale the moment the files change.
7. **Each debrief answer is one plain sentence with its home named.** The
   entry is written into its file, not pasted into the turn, and the approved
   sentence is the entry's first line.

## Flow

1. Read `allostatik/workflow.md` **Session close**, **Writing the handoff**, and
   Part 2's *Closing-protocol additions* / *Handoff conventions*.
2. Execute the close steps in the project's stated order, gating each write.
3. Finish by suggesting a session name in close step 8's format — `s<N> <project>
   <description>`, description ~50 characters, leading with what distinguishes this
   session from its neighbours — and confirming the wrap.

## What good looks like

Every change has a durable home, deployed copies match canonical (or the gap
is a blocking carry at the top of the handoff), the commit is pushed and
confirmed if the project uses version control, and the next session can orient
from the handoff plus the files alone — no memory of this conversation needed.

# When your plan outgrows reading it

`plan.md` is the file every session loads first: where the work stands, what is underway, what comes next. It only grows. Finished work stays in it as narrative and deferred work stays as reasoning, until loading the file costs more than what it tells you is worth. Two exits keep it small. Both are marks you make at the close; the move itself is mechanical.

## What moves, and where

**Measure first, so the marks go where the words are.** A word count per section shows where the file's weight actually sits:

```
awk '/^#/{if(h!="")printf "%6d  %s\n",n,h; h=$0; n=0; next} {n+=NF} END{if(h!="")printf "%6d  %s\n",n,h}' allostatik/plan.md | sort -rn | head
```

**Finished narrative goes to `log.md`.** Mark a block done: strike its head line with `~~`, write `DONE` in it, or tick a `- [x]` item. At the close it moves, whole and verbatim, under a dated heading at the end of `log.md`. The head line stays in `plan.md` with a one-line pointer. A `*Status sN:*` paragraph needs no mark: every one except the newest moves. A block of one or two lines moves whole and leaves nothing, because its head is its content.

**Deferred reasoning goes to `knowledge/docs/plan-parked.md`.** Mark a section heading or a list item `[parked]` and its body moves there whole, leaving the head line and a pointer. A parked item's head line is what stays, so write the claim and the trigger into that line before marking: the plan still says what the item is and when it comes back. The parked file is read when a trigger fires, never at the open.

## What stays the same

Nothing is deleted and nothing is summarised. Every moved block is verbatim in its new home, in file order, and the pointer left behind says where it went. The record files are not touched. A second pass finds nothing to move.

## Two figures, both warnings

The close reports the newest Status block against 150 words and `plan.md` against 3,000 words. The Status says what changed in the plan's terms and points at the log entry, which carries the record. Over is a warning, never a halt. Both figures are scaffolds keyed to today's context window; re-derive them when it moves.

## Going back

Move the block back by hand and drop the mark. The copy in `log.md` stays, because it is history.

## For the AI doing it

The reference implementation is `scripts/retire-plan.py` in the tool's repo, with `scripts/test_park_plan.py` beside it. **Read it for the rules and do the move yourself — never run it.** The upgrade contract's rule 3 forbids executing anything fetched from the tool's repo, and that covers this script like any other. The checks that matter: every marked block moved whole, the text in its new home is byte-identical to what left, the newest Status stayed, and a second pass finds nothing.

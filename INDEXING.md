# When your record outgrows loading it

Every Allostatik project keeps two files of accumulated judgment: `decisions.md`, the choices you locked and why, and `observations.md`, the patterns you noticed more than once. They load at the start of every session, which is the point of them.

They also only grow. At some point loading them costs more than having them is worth, and your AI says so:

> Your record is 134,000 bytes, over the 120,000 budget. I can switch you to an index — say the word and I'll generate it.

This is what that means and what it does to your project.

## What the index is

One line per entry, for **every** entry, carrying that entry's own **first sentence verbatim** — never a summary — plus the exact line to find the rest at.

```
D041 · Repo private first, public template later **[SUPERSEDED 2026-04-29]** → decisions.md:25, body 29w
#187 · Handoffs are artifacts, not committed files → observations.md:203, body 141w
```

Three things there are doing work. The **line address** makes looking an entry up one command rather than a search. The **body word count** stops a line reading as complete when it isn't. And the **flag** marks entries whose body reverses what their own title says — which turn out to be the entries most likely to be consulted, because the ones that get amended are the ones that get used.

## What changes, and what doesn't

**`decisions.md` and `observations.md` are not touched.** Not split, not moved, not shortened, not renamed. Every entry stays in force and every existing reference to them still resolves. The index is derived *from* them; they remain the record.

What changes is only this: your sessions load the index and look entries up when they need one, instead of carrying the whole record whether they need it or not. For most projects the index is about a tenth of the size.

## Saying yes

Your AI generates the index and shows you the result. Nothing else in your project is edited — no file lists, no configuration, nothing in `CLAUDE.md` or `AGENTS.md`. From the next session on, the open routine sees the index exists and reads it instead.

Two checks are worth watching it do, because a wrong index is worse than none:

- **Completeness.** The index must carry exactly one line per entry. Count both sides. An index short by one entry loses that entry silently, and silence is the only failure a title index cannot survive.
- **Freshness.** The index is regenerated at every close that adds an entry, and checked at every open. An index built from an older record describes a record you no longer have.

## Saying no

Perfectly reasonable — you may know your record is about to get shorter, or you may want to keep reading the whole thing. Your AI records the decision in `decisions.md` and stops asking. It offers again if the record doubles.

## Going back

Delete the index. That is the whole reversal. Because nothing else was ever changed, the next session reads `decisions.md` and `observations.md` exactly as before.

## For the AI generating it

The reference implementation is `scripts/make-index.py` in the tool's repo. **Read it for the format and produce the index yourself — never run it.** The upgrade contract's rule 3 forbids executing anything fetched from the tool's repo, and that covers this script like any other.

**The completeness check is already built into the generator** — it counts the record's
entries independently of the index it just built and refuses to write a short one. That
is the check that matters, and reproducing it by hand is where this goes wrong: do not
try to predict the index's total line count, because its header is prose and grows.

If you want to see it for yourself, compare like with like — the index's own entry lines
against the record's:

```
grep -c '^D[0-9]' allostatik/decisions-and-observations-index.md
grep -c '^#[0-9]' allostatik/decisions-and-observations-index.md
```

Those two must equal the number of table rows in `decisions.md` below its header rule,
and the number of `1.`-style entries in `observations.md` below its first `##` heading.
Count them the same way the generator does or the comparison is noise: a naive
`grep -c '^| '` also counts the table's own header row, and a naive count of numbered
lines also counts anything numbered in the file's preamble or inside its commented-out
example scaffolding.

**And know what counting cannot see.** `decisions.md` amends entries *in place* — a
superseded decision keeps its row and gains a marker inside it. The entry count is
unchanged, so a count check passes while the index still shows that decision's title
without its `**[SUPERSEDED]**` flag, which is precisely the line someone will act on.
Only regenerating and comparing catches that, which is why the open verifies freshness
rather than merely counting.

# Allostatik

**Allostatik is a folder of plain files in your repo that holds the working relationship you and your AI have built — the decisions you settled and stopped re-arguing, the conventions you work by, the shorthand, the corrections that stuck, and where the work actually stands.**

It exists only because you built it; your AI cannot accumulate it alone, which is why the gate sits on your side. Keep it living and it compounds — every session starts further along. Leave it alone and it resets: every new conversation, every context window, every surface. Or worse, not from zero but from a summary you never wrote.

So you keep one shape from project to project, you work to a routine at each edge of a session, and nothing persists that you did not approve. Every session runs the same loop:

```
OPEN    load the files, drift-check every
   │    deployed copy against them
   ▼
WORK    the files are the source of truth;
   │    stale content gets flagged
   ▼
CLOSE   update them, re-paste what changed,
   │    hand off pointers
   ▼
        the next session opens here,
        with a drift check
```

Every routine ends in a check you can verify in seconds.

## Get started

For you if you use Claude Code, Cursor or Desktop most days and keep re-explaining your own project to them; not for you if your AI use is occasional one-off chats. Read the repo first — it is small, and this page is the walkthrough. Then, in your project:

```sh
npx allostatik init .                          # npm
pip install allostatik && allostatik init .    # PyPI
curl -fsSL https://raw.githubusercontent.com/allostatik/allostatik/main/init.sh | sh -s -- .
```

About two minutes. No account, no service, nothing running. To remove it you delete what it added: the `allostatik/` folder, the `CLAUDE.md` and `AGENTS.md` it placed at your root, and the block you pasted into your project instructions. For a trial with no consequences, install in a git worktree, work a session or two, then delete it — every trace goes with it except that pasted block.

The installer prints this. Paste it into your project instructions field and leave it there:

> This is an Allostatik project. The canonical files in its `allostatik/` folder — `project-instructions.md`, `workflow.md`, `plan.md`, `log.md`, `decisions.md`, … — are the source of truth. At the start of a session, read them, follow `workflow.md`, treat them as authoritative, and flag anything stale rather than just following it. If they aren't set up yet, help me set them up — github.com/allostatik/allostatik is the reference.

Then ask it to **set up the files**, or to **migrate** if the project already knows things about you — migrate cross-checks what it found against what it wrote, so nothing is silently dropped. Confirm it took in a *fresh* conversation, not the one that did the work.

**Optional, once per account,** instead of pasting per project:

> Some of my projects use a layered context system: canonical files (an `allostatik/` folder, with a `CLAUDE.md` listing what to load) that are the source of truth. When a project has them: load them, treat them as authoritative, follow its `workflow.md` to keep them in sync (drift-check at start, update at close), and flag anything stale rather than following it. If a project doesn't have them, ignore this.

## The honest part

Your AI does all of this, because you asked it to. The installer is the only real program — it copies files into your project and exits. After that it is instructions a language model follows, and it can be misread, skipped, or done badly. Every routine therefore ends in a check you can verify in seconds, and nothing reaches your files without being shown to you first.

Which is also why plain instructions are worth anything here. A deterministic tool does what it was built to do; you configure it. A non-deterministic one does what it is *shaped* to do — so shaping is the work, and it is yours, not a vendor's. As your AI takes on more of the producing, what deserves your attention moves up with it: from the output to the standards that shape it.

## The rules file you already have

You have probably built the fix once already — a `CLAUDE.md`, a Cursor rules file, a project instructions field you filled in. The instinct is exactly right: context you author, in plain text, where you can read every line. The defect is that a rules file is a config file: written once, wrong quietly. A bad rule does not announce itself; it gets enforced, agreeably, until you notice the work bending. It still says something you stopped believing three weeks ago. It's been steering every session since, and nothing told you.

Two editors work on it besides, and you hired neither. Long conversations get compacted — a polite word for summarized by something that wasn't in the room when the decision was made — and that edit you never see. Memory features synthesize what to keep about you; those you can read and prune, but you did not write them. The worst either does is not dropping a decision, or keeping one you reversed, but *inferring* one: an offhand remark taken for a standing preference and written down as a fact about you.

The problem was never that your AI has no context. It is that you do not control the part it has.

## What you get

**A routine at each session edge.** Open: load the files, drift-check every deployed copy against canonical, reconcile before work starts — a *deployed copy* being your context outside `allostatik/`, in a project instructions field or a rules file, where your AI reads it without being told to. Those are the ones that drift. Work: the files are the source of truth; stale content gets flagged rather than followed. Close: update them, re-paste what changed, hand off pointers, not copies.

**The maintenance half.** Everyone builds the capture half; you probably have. Almost nobody builds the other one — the close, where updating your record is the same act as ending your session, so it actually happens, and the drift-check. Skip it and your folder ages quietly, and a stale rule just keeps steering. Keep it and your files stay fresh, trimmed and auditable — checked against what your AI loads, distilled to what still earns its place, readable line by line.

**A gate meant to move.** Automate the mechanical, gate the meaningful. Early on you approve nearly everything; as the files earn it, the direction of travel is approval moving from per-step toward per-plan.

**Setpoints that move too.** Stray from a convention once and the files correct you back. Stray the same way three sessions running and the close asks whether the convention still fits. A thermostat holds a fixed target; an allostatic system can move the target, because the right setpoint depends on the season. That is what the name means. Ask a model cold whether a rule still fits and it has no grounds to answer — three of the same correction is evidence and one is noise, but only if the record lives outside the conversation that produced it.

**Yours from the moment it lands.**

```
CLAUDE.md
AGENTS.md
allostatik/
  project-instructions.md   plan.md         log.md
  decisions.md              observations.md vision.md
  workflow.md
  knowledge/
    environment.md          resources.md
    docs/README.md
  skills/README.md
```

Three regions belong upstream — Part 1 of `workflow.md`, and the fenced blocks in `CLAUDE.md` and `AGENTS.md` — and an upgrade touches only those. The boundary is a literal line in a file; you can see where it sits, and it is the same line in every project. Everything else is yours: rename it, restructure it, add your own, delete what you do not use.

You could write your own files. What you cannot write for yourself is a standard — the same convention in the next project, and the one after. Standard and give pull against each other, and taken as a tradeoff one has to lose: a standard with no give is a straitjacket you drop at the first project that does not fit; give with no standard is a beast per repo, and nothing carries. Held together, the standard is what makes your changes mean something in the next project, and the give is what keeps the standard from being something you fight.

## The shape of the whole thing

Opposites held in tension rather than resolved. In each, the value is in the relationship between the poles, and the job is to show you where the line sits and let you move it.

| | held against | |
|---|:---:|---|
| the creator | ↔ | the AI |
| one standard that carries | ↔ | malleable to your needs |
| correct back to the setpoint | ↔ | move the setpoint (homeostasis ↔ allostasis) |
| automate the mechanical | ↔ | gate the meaningful |
| capture — writing the files | ↔ | maintenance — keeping them true |
| canonical — the source of truth | ↔ | deployed — the copies that drift |

Every pair is a dial, not a switch.

## Status

**Working:**

- The templates, the drift-check, close/update, and handoffs.
- The upgrade path: stamped regions, verbatim diffs, reconciliation for regions you've edited.
- `init.sh` — placement plus the collision guard.
- The `allostatik` installers on npm and PyPI, fetch-first with a bundled offline fallback, behavior-parity-tested against `init.sh` including the pointer block they print.
- The migrate routine for existing projects.
- The shipped skills: `allostatik-init`, plus `allostatik-open`, `allostatik-close`, and `allostatik-checkpoint`.

**Planned:** cross-surface deploy guides naming which field is "project instructions" on each surface — Desktop and Cowork, Cursor, web. And `allostatik upgrade`, to do the fetching and classifying the routine currently asks your AI to do.

## Upgrading

Skip this on a fresh install; there is nothing to upgrade yet.

1. Read `CHANGELOG.md` and hand your AI the prompt at the top of it.
2. Follow `UPGRADING.md`. You see every change before it lands, and anything you edited yourself is reconciled with you, not overwritten.
3. Confirm in a fresh conversation, as you did at setup.

## Security

Allostatik targets **[OpenSSF OSPS Baseline Level 1](https://baseline.openssf.org/)**, the entry tier for open source projects. Level 1 is the honest bar for a pre-1.0 project with one maintainer; the higher tiers assume a team and a user base this does not have yet. I am naming it so you can hold me to it — and if something here falls short of that bar, telling me counts as a report. So does arguing it is the wrong bar for a tool that writes instruction files into your project.

`SECURITY.md` — the full scope: what the upgrade path defends against, what it does not, and how to report something privately.

## Going deeper

`why.md` — the argument at length. `concepts.md` — the design reasoning.

## Feedback

Issues and PRs welcome — templates and docs especially. Your project config stays yours.

## License

MIT.

## Disclaimer

Allostatik is a set of files and conventions for managing the context an AI assistant works from. The assistant's responses are generated, non-deterministic, and may be inaccurate or incomplete — they are the assistant's output, not the author's. Verify anything that matters before relying on it. Allostatik is for general productivity and configuration purposes and is not legal, financial, medical, safety, or other professional advice. You are responsible for how you use it and for any actions taken on your behalf. Provided "as is", without warranty, under the MIT License.

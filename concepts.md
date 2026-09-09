# concepts.md — the principled why

This is the reasoning behind the methodology — the *why* under the *what*. If you're a Claude working in an Allostatik project, read it to ground yourself in what the system is *for*. If you're a person browsing the repo, it's the thinking behind the files, not the files themselves. The README covers what the methodology is and how to set it up; this is the layer underneath it.

It restates the reasoning in lean form rather than pointing at sources, because the full design record it's distilled from lives in the maintainer's working repo. Read it as the distilled *why*; read the README and the templates as the *shape*.

<!-- SECTION:BEGIN core-idea -->
## The core idea: the medium is the control surface

Working with an AI across time usually gets treated as a *content* problem — what to put in the prompt — or a *model* problem — better memory, bigger context windows. The methodology reframes it as a *medium* problem: the properties of *where and how* your context lives are what determine what you can do with the relationship.

Files and handoffs aren't the easiest medium to maintain — they're the most *controllable* one. Four properties together: **inspectable** (you read it directly, exactly as it loads — not a summary synthesized on your behalf), **editable** (you change any of it; it's just text), **gated** (you author what goes in; nothing persists that you didn't put there), and **self-refreshing** (you touch it every session, so it can't silently go stale the way a UI setting you set once and forgot does). Claude's memory now covers part of this — you can view and edit what it remembers — so the real contrast with a file isn't visible-versus-invisible; it's *curated versus emergent*: a file is something you authored deliberately and can read in one sitting, while memory is synthesized from your conversations and refreshed on its own, which you can steer but don't write line by line. Memory trades authorship for convenience; UI settings trade freshness for persistence. Files and handoffs give all four — at the cost of deliberate upkeep, which the methodology makes worth it by making the upkeep itself the thing that compounds.

Two halves make the architecture: the **medium** is the substrate — inspectable, editable context — and **the gate** — your approval over what gets captured, what gets applied, and when — is the control law over how that substrate evolves. Substrate plus control law is a context system you can both *see* and *steer*. Everything below is a consequence of that.

<!-- SECTION:END core-idea -->

## The problems it answers

Most of these pains are what you get when the medium is opaque or static.

**Decay** is what a medium you can't inspect or keep fresh produces: you tune the AI and the tuning quietly desyncs from what's deployed; every conversation starts cold; corrections that held yesterday are gone this morning; each session opens with minutes of restating tools, conventions, and state before any real work begins.

**Mess** is what an uncurated, non-composable medium produces: each surface gets configured on its own and they drift apart; configuration accretes without curation until you can't tell what's load-bearing and pruning feels unsafe.

**Rigidity** is what a medium you can't revise produces: corrections pile up without anyone asking whether the underlying principle still fits, and a config tied to the surface you started on won't extend when you add a new one.

**Relationship behavior** is the exception — not a medium problem. The AI agrees when it should push back, solves the literal request instead of the real problem, and doesn't flag what you don't know you should know. These are fixed by what you *encode* in the identity layer — principles that require pushback and surface unknowns. The medium is just where those principles live, inspectably and persistently.

(One pain shows up later than first contact: **approval friction** — per-step approval caps how much you can hand off. The methodology's answer is to let the gate move from per-step toward per-plan as the trust infrastructure under it matures.)

## The architecture: layers, surfaces, and the loop

The medium is organized as **layers** — separation of concerns by scope. Identity (who you are across all your work), domain (a given project), knowledge (your environment and references, pointed at rather than copied in), skills (documented capability), and execution (the surfaces you actually work in). Each layer owns one concern. Surfaces — the app, the IDE, the CLI — are **adapters** over this shared core: the same configuration composes into each, so you don't end up with four versions of yourself. The canonical files are the source of truth; what's deployed into any surface is a copy, and a drift-check at session boundaries keeps the two honest.

The medium is *run* by a loop: **MAPE-K** — monitor the state, analyze it (interpreting what the observations mean in context, not just comparing against fixed targets), plan a correction, execute it — with execution gated by your approval. That gate is the control law from the core idea: the loop proposes, you decide. It's how the system is self-correcting without being autonomous.

## Why it lives in files, not the conversation

Two consequences follow from where the context lives — and they're the same coin.

The first cuts the other way from *inspectable*: not only can you read the files where the model can't read its own memory — the model can only act on what's loaded into its context window. Anything outside it — a setting changed in another window, a step taken in a different session, the deployed copy drifting from its canonical file — is invisible to it, and that invisibility is where conflicts come from: it can't reconcile a change it never saw. *Present isn't the same as enacted, and what's enacted isn't guaranteed to be seen.* So the source of truth lives in files you control, the handoff carries state forward explicitly instead of trusting it to persist, and every step gets verified instead of assumed — each time, you make the relevant state loadable into the window on purpose.

Verification here means reading independent state back — a file, a command's output, a setting freshly loaded into a new window — not the model restating its own context as confirmation of itself. Only two things can genuinely fail, so only these are checks: a *landed-check* (did the write actually happen; did the deployed copy load into a fresh window) and a *drift-check* (do canonical and deployed still agree, with both sides re-read at check time). A *composition recap* — having the model name what's loaded and where it came from — is useful for showing an adopter the layers are present and attributable, but it isn't a check: there's nothing outside the model's own output for it to disagree with. Keep the names distinct, so a recap never claims a pass that only a landed- or drift-check can earn.

The second is the payoff of that same externalization. Because the context isn't trapped in a session, it persists: the configuration that composes across surfaces (the adapters above) also survives a session reset, and it travels with the project — move or clone the repo and the whole working relationship comes along, because the context *is* the repo. That's how one setup persists across every execution surface, Layer 5; you're never stranded in the one you started in.

This is sharpest in Claude Code. The terminal is the most agentic surface — the most happens across the most session boundaries and compactions, so it's where the model would otherwise lose the most to what it can't see. Externalized context answers that twice: nothing is lost when a session resets, because the files reload; and when you move the project to another machine or hand it to someone else, its entire context moves with it.

The upshot is a kind of personal documentarian — one that keeps the record of how you work as you go, and can pull it back up on demand. The medium that keeps the model from working blind is the same one that lets the work go anywhere.

## What makes it a living system

Three properties turn the architecture from a static setup into something that grows.

**It revises itself — allostasis.** Most self-correcting systems are homeostatic: they assume the goals are right and keep steering back to them. This one is allostatic — the setpoints themselves can move. Single-loop correction fixes behavior against a principle; double-loop correction asks whether the principle still fits and revises it. This is the property the medium *enables*: you can't revise setpoints you can't see and edit — and a file puts both in your hands, where you author the setpoint and change it directly rather than steering a summary the system synthesized for you.

**It stays executable — testability.** A principle is only as strong as the cheap test that verifies it; without one, it decorates rather than constrains. So the test gets designed alongside the principle — the drift-check at session boundaries, one composition test that confirms every layer loaded, a session-open verification block. Testability is what lets you *notice* when a setpoint has stopped fitting.

**It spreads — the strange loop.** The methodology runs on itself: improving how the AI behaves improves the system that improves how the AI behaves. It ships as files *and* the loop that maintains them — each adopter becomes a node running their own version, learned by *using* the setup rather than reading about it. It's Constitutional AI taken one layer further: the model has a constitution, you layer your own, and you also run the loop that keeps revising yours.

## The edges of a session: a goal going in, a debrief coming out

A session is two parties with different jobs. The AI does the work. The human says what the work is for and, at the end, whether it did that. Every routine between those two moments exists to keep the AI honest; the two moments themselves are where the human steers, so their shape matters most.

**The open asks for a goal, not a plan.** A numbered plan is *how*, and how is the AI's job. A human asked to approve one either approves it unread or reads it and redirects the session anyway. What only the human can set is the purpose and the finish line: what will be true at the close that is not true now. Military planners call this commander's intent — state the purpose and the end state, and leave the steps to whoever executes, because the plan will change and the intent will not. Scrum's sprint goal is the same idea. A goal is a starting point, not a promise: direction can change at any time, and the close records the change.

**The close asks five questions, in full.** What was our goal? What did we do well? What did we learn? What could we have done differently? What still puzzles us. They are Norm Kerth's retrospective questions, descended from the Army's After Action Review, which opens by comparing what was supposed to happen with what did. Each answer has a home in the record, and that is what closes the loop: a lesson with no file to land in is gone by the next session.

**Both are spoken in the human's words.** A reader holds about four things in working memory. A sentence costs one per idea, and a word the reader must translate costs one more. So the goal and the debrief use short sentences, name the doer as the subject, and put the project's own coinages into plain words. The research behind that is cognitive load theory (Sweller) and its application to readers with no time to spare (Rogers and Lasky-Fink, *Writing for Busy Readers*).

<!-- SECTION:BEGIN in-one-breath -->
## In one breath

The medium gives you a context system you can see, edit, gate, and keep fresh; the gate is the control law over how it changes; layers organize it and surfaces compose it; allostasis lets it evolve, testability lets you notice when it should, and the strange loop spreads it. A configuration you can see, steer, and grow with — that's the whole of it.

<!-- SECTION:END in-one-breath -->

# Why Allostatik

The value of working with AI compounds, but only if context persists, and only if it persists in the right way. Every project, conversation, and context window begins agnostic. Conversations end, context windows close, and each surface (Cursor, Claude Code, Claude Desktop) holds a different partial picture of you. You start over constantly, or you lose control of your context.

The value was never in any single answer. It's in the relationship: the decisions you've made, the shorthand you've developed, the patterns you've worked out together, and everything else that builds up between you and AI over time. That is the part worth something, and it is exactly the part that resets.

Allostatik is a foundational layer to support that relationship: a small set of files you own that keep your AI's context sharp, consistent, and current across conversations, context windows, and surfaces. Every session builds on the last. Nothing resets.

## How it works

Session rituals ensure the context persists throughout your project. Open, work, close: every session ends where the next one begins. The rhythm is MAPE-K (Monitor, Analyze, Plan, Execute, over a shared Knowledge base), a control loop from autonomic computing, run as ritual. The name reads out of that loop: allostat + I + K. The I is the interpretive human gate — observations get interpreted against current context, not just compared against fixed targets, and nothing executes without your sign-off. It is the one deliberate modification to standard MAPE-K, and it is what makes double-loop learning possible. The K is the Knowledge base: the files you own. Both letters were already in the written system before the name existed — they name what was there, not a story grafted on.

## What makes it different

- **Files you own.** Plain files in your project: readable, versioned, portable. Not a vendor's memory feature. No account, no server, nothing lost when a subscription ends. The model is remote; the relationship lives on your side. It's SOC (separation of concerns) applied to context. Plan, decisions, observations, workflow: one file, one job.

- **Freshness is checked, not assumed.** Context doesn't break; it goes stale. You refine a convention in the files, and an old paste keeps steering some surface. So a cheap drift-check runs at every session edge, canonical files against every deployed copy. It's TDD (test-driven design) pointed at process instead of code: every routine ships with the check that proves it ran.

- **Context economy.** The window is a budget, not a bucket. Too much context is as costly as too little: a bloated window steers as badly as an empty one. Files load by manifest. Knowledge is pointed at, never pasted. That's DRY (don't repeat yourself). Each close distills the session to a few durable lines. Nothing persists on speculation. That's YAGNI (you aren't gonna need it), applied to memory.

- **Surfaces are adapters.** Ports and adapters (hexagonal architecture) with your context as the core. The surface holds no logic; it just brings the files together. A new tool is one adapter, not a restart.

- **The human stays in the loop, deliberately.** Involvement always sits on a spectrum, from approving every keystroke to signing off on the plan. Most setups leave the spot to chance. This one defines it: automate the mechanical, gate the meaningful. Nothing rewrites your files without sign-off.

- **The setpoints evolve.** A thermostat corrects back to a fixed target. Allostatik is allostatic: the target itself can move. Stray from a principle once, and it corrects you back. Stray the same way repeatedly, and it asks whether the principle is still right. That's double-loop learning, with you as the gate. Configuration that matures instead of fossilizing.

The core ideas that carry the system are covered in more depth in [concepts.md](./concepts.md).

## Run your own loop

Navigate to your project root in your terminal. One command places your context files and prints the pointer block that ties your project to them:

```
npx allostatik init .
```

With pip:

```
pip install allostatik && allostatik init .
```

Or with plain shell:

```
curl -fsSL https://raw.githubusercontent.com/allostatik/allostatik/main/init.sh | sh -s -- .
```

After it runs, point your AI at the files with the pointer block. This is it:

> This is an Allostatik project. The canonical files in its `allostatik/` folder — `project-instructions.md`, `workflow.md`, `plan.md`, `decisions.md`, … — are the source of truth. At the start of a session, read them, follow `workflow.md`, treat them as authoritative, and flag anything stale rather than just following it. If they aren't set up yet, help me set them up — github.com/allostatik/allostatik is the reference.

The simplest start: paste it into a conversation in your project and go; the first session walks you through the files and helps you make the pointer permanent. Its permanent home is your project's instructions (the Project Instructions field in Claude Desktop, or your surface's equivalent; Claude Code reads the placed CLAUDE.md on its own, and Cursor and other agents read the placed root AGENTS.md).

Your AI needs to be able to read and write the files: Claude Code, Cursor, or Claude Desktop with file access. The open, close, and checkpoint rituals also come packaged as skills your AI can install. A session later, your context is live and compounding.

It's young and in active development, and it improves with every use. Run it on your own work. Open an issue with what compounded and what broke.

It's open. It's free. The value was always in the relationship. Now you get to develop it.

---

*Allostatik is open source (MIT), built by the system it describes, and lives at github.com/allostatik/allostatik.*

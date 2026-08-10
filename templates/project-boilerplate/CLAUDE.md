# [PROJECT-NAME]

<!--
  CLAUDE.md is YOUR file. Allostatik only manages the single fenced region below,
  between the `BEGIN allostatik` and `END allostatik` markers. Everything outside the
  markers is yours — `allostatik init` never reads or edits it.

  There is no automatic reconcile: `allostatik init` never rewrites an existing
  CLAUDE.md. To update the managed region, replace the block between the markers
  as a unit — by hand, or by your AI with your sign-off — with the current
  template's block. On a project that already has a CLAUDE.md, `allostatik init`
  drops that block beside it as `allostatik/CLAUDE.md.allostatik-block` for
  exactly that merge.

  Fresh project? This whole file is the scaffold; write your project overview above
  or below the managed region.
-->

<!-- Add your own project overview, instructions, or notes here. -->

<!-- BEGIN allostatik (managed — update by replacing this block as a unit; your edits belong outside it. Project additions — an extra canonical file to load, say — go below the END marker, outside the fence) -->

This region is contributed by Allostatik. It declares this as an Allostatik project and lists the project-scope files Claude loads each session. Architectural background for this pattern lives in the methodology's `README.md` — not duplicated here.

## This is an Allostatik project

The project's context lives in the `allostatik/` files below. At session start, load them and follow `allostatik/workflow.md` — its open routine runs the drift + session-log-freshness checks before work begins. Your own Custom Instructions apply as they always do: Allostatik is project-scoped and neither requires nor manages your personal/global layer.

Session contract: Claude's first reply in a session is the open routine's output; if it isn't, the open was skipped. The canonical statement and the repair live in `allostatik/workflow.md` → *Session open*.

## Project-scope `@`-imports

These files are loaded into every session for [PROJECT-NAME]:

@allostatik/project-instructions.md
@allostatik/workflow.md
@allostatik/plan.md
@allostatik/decisions.md
@allostatik/observations.md
@allostatik/vision.md

Loaded when relevant (optional):

@allostatik/knowledge/environment.md

<!-- END allostatik (managed) -->

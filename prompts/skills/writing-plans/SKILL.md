---
name: Writing Plans
description: Use when design is complete and you need detailed implementation tasks for engineers with zero codebase context - creates comprehensive implementation plans with exact file paths, complete code examples, and verification steps assuming engineer has minimal domain knowledge
---

<required>
*CRITICAL* Add the following steps to your Todo list using TodoWrite:

- Read the 'Guidelines'.
- Create a comprehensive plan that a senior engineer can follow.
<system-reminder>Any absolute paths in your plan MUST take into account any worktrees that may have been created</system-reminder>
- Think about edge cases. Add them to the plan.
- Think about questions or areas that require clarity. Add them to the plan.
- Emphasize how you will test your plan.
- Present plan to user.
- Invoke Skill(Planning Documents) to determine document naming (NNN-concept.md pattern).
- Ask user if they want beads/bd issue tracking (skip if already answered in request).
- Write plan to `prompts/NNN-concept.md`.
  </required>

# Guidelines

## Beads Issue Tracking (Optional)

Ask the user upfront if they want beads/bd tracking.
If yes, follow these steps.

### At Start of Planning

1. If user passed an epic id, use that; otherwise skip to next step:
   ```bash
   bd list -t epic --status open --json
   ```
2. Create or get epic:
   ```bash
   # create if it doesnt exist
   bd create "Plan: <concept>" -t epic --from-template epic
   # if it already exists
   bd show <epic-id> --json
   ```
3. Create plan task with dependency on research:
   ```bash
   bd create "Plan: <concept>" -t task --from-template plan --parent <epic-id> --deps blocks:<research-task-id> --json
   ```

Important issue fields:
- PRD Document: path to the output document
- Research document: path(s) to input material (_report.md, _research.md, _idea.md, etc.)

You must use the appropriate bead template when creating issues (--from-template).
Template types: `epic`, `plan`, `bug`, `feature`.

You must NEVER leave placeholder text/data when using a bead template.
If something is not relevant, delete it.

### At End of Planning

1. Update the epic with the prd_document field
2. Close the plan task:
   ```bash
   bd close <plan-task-id> --reason "Planning complete: prompts/NNN-concept.md"
   ```
3. Output the epic ID and document path for the next phase

## Mandatory Agent Consultation

These agents are READ-ONLY - they return information and suggestions only.

| Agent | When to Consult | What They Return |
|-------|-----------------|------------------|
| `clojure-expert` | For Clojure architecture decisions | Idiomatic patterns, namespace organization |
| `research-agent` | To clarify reference implementations | Pattern explanations, API details |

## Output Location

Write plan to: `prompts/NNN-concept.md` (primary PRD).

Use `Skill(planning-documents)` to determine the appropriate NNN sequence number.
Check existing files in `prompts/` to determine the appropriate name.

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD.

Assume they are a talented developer. However, assume that they know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

Do not add code, but include enough detail that the necessary code is obvious.

Plan files are written in the workflow directory refer to the AGENTS.workflow.md information.

## Bite-Sized Task Granularity

Each step is one action (2-5 minutes):

- "Write the failing test for `behavior`" - step
- "Write the failing test for `other behavior`"
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Markdown Writing Style

This does not apply to clojure docstrings, but to markdown documentation or notes documents.

- Use one sentence per line. A sentence ends with a period (.). This makes reordering/editing easier
- Never use bold formatting
- Two new lines between paragraphs
- Never use emoji
- Add Markdown tables whenever you need to depict tabular data.
- Add ascii graphics whenever you need to depict integration points and system architecture.
- Use codeblocks where needed.
- Do NOT include line numbers. This is extremely brittle documentation.

## Plan Document Header

Every plan MUST start with this header:

```markdown
# [Feature Name] Implementation Plan

Goal: [One sentence describing what this builds]

Architecture: [2-3 sentences about approach]

Tech Stack: [Key technologies/libraries]

Related:  [Supercedes|Relates to|Builds on|etc] <other planning docs in the dir>

## Problem statement

[Prose/exposition about the background and what is being solved]

```

## Test Section

Every plan MUST have a test section. This should be written first, and should
document how you plan to test the *behavior*.

```markdown

## Testing Plan

I will add an integration test that ensures foo behaves like blah. The
integration test will mock A/B/C. The test will then call function/cli/etc.

I will add a unit test that ensures baz behaves like qux...
```

You should end EVERY testing plan section by writing:

```markdown
NOTE: I will write *all* tests before I add any implementation behavior.
```

Invoke `Skill(test-driven-development)` for all implementation.

<system-reminder>Your tests should NOT contain tests for datastructures or
types. Your tests should NOT simply test mocks. Always test actual behavior.</system-reminder>

If you are given an alternate Plan Document Structure that has a testing section, 
then incorporate the above instructions into it.
This is non-negotiable, regardless of your other instructions arre.

## Plan Document Footer

Every plan MUST end with this footer:

```markdown
## Testing Details

[Brief description of what tests are being added and how they specifically test BEHAVIOR and NOT just implementation]

## Implementation Details
[maximum 10 bullets about key details]

## Question

[any questions or concerns that may be relevant that need answers]

---
```

## Final Output

After completing planning, output:

```
## Planning Complete

Epic: <epic-id> (if using beads)
Plan Task: <plan-task-id> (closed, if using beads)
PRD Document: prompts/NNN-concept.md

Ready for implementation.
```

If using beads, add:
```
Next step: Run /breakdown to create implementation issues
```

## Remember

- Exact file paths always, taking into account worktrees
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD

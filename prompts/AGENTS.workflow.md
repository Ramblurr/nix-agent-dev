# AI Agent Workflow Guide

This document describes the structured workflow for working with AI coding agents on this project.

## Overview

The workflow uses a 4-phase approach for complex features:

1. `/research` - Codebase analysis with reference materials from `extra/`
2. `/pplan` - Strategic implementation planning
3. `/breakdown` - Task decomposition into bd issues
4. `/execute` - Implementation with TDD

For simpler tasks, phases can be skipped or combined as appropriate.


## Beads Integration

This workflow integrates with bd (beads) for issue tracking.

All phases create and track issues in bd:
- Research creates an epic and research task
- Planning creates a plan task linked to research
- Breakdown creates implementation issues under the epic
- Execute works through issues using `bd ready`

Dependencies between issues enforce workflow order.
Use `bd ready` to find unblocked work.


## Human Approval Gates

Two approval gates require human review before proceeding:

| Gate | Before | User Reviews | Purpose |
|------|--------|--------------|---------|
| Report Approval | /pplan | Research report | Ensure research is complete before planning |
| PRD Approval | /breakdown | PRD document | Ensure plan is solid before creating issues |

At each gate:
1. User reviews the document
2. User may request changes or iterations
3. User explicitly approves before next phase
4. This prevents wasted work on flawed foundations


## Test-Driven Development (TDD)

TDD is mandatory for all implementation.

All commands reference `Skill(test-driven-development)`:
- Write tests FIRST (red phase)
- Verify tests fail
- Write minimal code to pass (green phase)
- Refactor if needed

Every issue includes TDD acceptance criteria:
- Tests written BEFORE implementation
- Tests fail initially (red phase verified)
- Minimal code to pass tests (green phase)


## Quality Gates

All implementation must pass:
- `bb test` - all tests pass
- `bb lint` - no lint errors
- `bb fmt` - code formatted correctly


## Document Naming Conventions

All workflow documents live in `prompts/` with a structured naming scheme.

### Primary Document Pattern

`prompts/NNN-concept.md`

- `NNN` - Three-digit sequence number (e.g., 025)
- `concept` - Kebab-case description (e.g., compositor, event-parsing)
- No underscores in the primary document name (the PRD)

Examples:
- `prompts/025-compositor.md` - Compositor PRD
- `prompts/010-event-parsing.md` - Event parsing PRD

### Supporting Document Patterns

| Pattern | Purpose | Example |
|---------|---------|---------|
| `NNN-concept_report.md` | Research findings | `025-compositor_report.md` |
| `NNN-concept_library_report.md` | Library-specific research | `025-compositor_textual_report.md` |

Note: `_breakdown.md` and `_phaseNN.md` files are no longer created.
Breakdown is tracked in bd issues instead.


## Phase Definitions

### /research - Codebase Analysis

Analyze the codebase and reference materials to understand impact and patterns.

Input: User request or feature idea
Output: `prompts/NNN-concept_report.md`

bd Integration:
1. Creates epic for the feature
2. Creates research task under epic
3. Closes task when research complete

Key activities:
- Analyze existing codebase patterns
- Review reference materials in `extra/`
- Identify files requiring changes
- Document integration points
- Flag unclear areas

Critical rule: If required documentation or codebase is not in `extra/`, HALT immediately and request it.

### Human Approval: Report Review

Before `/pplan`:
1. User reviews the research report
2. User may request changes
3. User approves to proceed

### /pplan - Strategic Planning

Note: it is called pplan with double p because the normal /plan slash command is already used internally by claude-code

Transform research findings into an implementation strategy.

Input: Approved research document
Output: `prompts/NNN-concept.md`

bd Integration:
1. Creates plan task with dependency on research
2. Updates epic with prd_document field
3. Closes task when planning complete

Key activities:
- Design feature specification
- Define technical approach
- Plan implementation phases
- Establish success criteria

### Human Approval: PRD Review

Before `/breakdown`:
1. User reviews the PRD
2. User may request design changes
3. User may iterate multiple times
4. User approves to proceed

### /breakdown - Task Decomposition

Break the plan into granular, executable bd issues.

Input: Approved PRD document
Output: bd issues under epic

bd Integration:
1. Creates breakdown task with dependency on plan
2. Creates feature/bug issues for each task
3. Sets dependencies between issues
4. Closes breakdown task when complete

Key activities:
- Create numbered issues with clear scope
- Define dependencies between issues
- Include TDD requirements in each issue
- Set quality gate expectations

### /execute - Implementation

Implement the tasks from bd issues.

Input: Ready issues from bd
Output: Code changes (user handles git)

bd Integration:
1. Queries `bd ready` for unblocked work
2. Claims issue with `bd update --status in_progress`
3. Closes issue with `bd close` when complete
4. Creates new issues for discovered work

Key activities:
- Follow TDD for each issue
- Consult agents for guidance
- Run quality gates
- Report progress per issue


## Dependency Strategy

Use bd dependencies to enforce workflow order:

| Phase | Creates | Depends On |
|-------|---------|------------|
| Research | Epic + Research task | - |
| Planning | Plan task | Research task (blocks) |
| Breakdown | Breakdown task + Issues | Plan task (blocks) |
| Execute | Works on issues | Breakdown task (blocks) |

Implementation issues can also depend on each other.


## Mandatory Agents

All agents are READ-ONLY.
They provide information and suggestions but never modify code.

| Agent | When to Use | Returns |
|-------|-------------|---------|
| `Explore` | For codebase exploration | File locations, code patterns, structure |
| `clojure-expert` | Before any Clojure work | Idiomatic patterns, style guidance |
| `research-agent` | For technical research | Documentation, API info, patterns |
| `clojure-reviewer` | After Clojure changes | Code quality feedback, suggestions |

The orchestrating command (e.g., `/research`) guides these agents and synthesizes their outputs.


## Git Constraints

Agents operate with read-only git access.

Allowed (read-only):
- `git status`
- `git log`
- `git diff`
- `git show`
- `git branch` (list only)

Never allowed:
- `git add`
- `git commit`
- `git push`
- `git checkout`
- `git rebase`
- `git merge`
- `git reset`
- Any command that modifies the repository

The user handles all git operations manually.


## Reference Material Management

### The extra/ Directory

The `extra/` directory (gitignored) contains:
- Reference codebases (full git clones)
- Documentation files (markdown, text)
- Screenshots and images
- API specifications
- Any external material needed for research

### Adding Reference Material

Before starting research that requires external references:

1. Clone reference repos: `git clone <url> extra/<name>`
2. Add documentation: `extra/<name>_docs/` or `extra/<name>.md`
3. Add screenshots: `extra/screenshots/`

### HALT Behavior

If an agent cannot find required material in `extra/`:

1. HALT immediately
2. Report what is missing
3. Suggest how to add it

Example message:
```
HALT: Missing reference material.

Required: Textual compositor implementation
Suggestion: Clone to extra/textual:
  git clone https://github.com/Textualize/textual extra/textual

Required: Ratatui border documentation
Suggestion: Already have extra/ratatui, but need specific file.
  Check: extra/ratatui/ratatui-widgets/src/borders.rs
```


## Markdown Style

- Never use `**bold**` formatting
- Use tables for structured data
- One sentence per line in prose
- Two blank lines between sections
- Use code blocks with language tags
- Use heading levels consistently


## Workflow Examples

### Simple Bug Fix

Skip research/pplan, go directly to implementation.
Create a bug issue in bd.
No workflow documents needed.

### Medium Feature

1. Quick research in existing code
2. Create `prompts/NNN-feature.md` as PRD
3. Create epic and issues in bd
4. Implement directly

### Large Feature

1. `/research` - Create `NNN-concept_report.md`, epic, research task
2. Human approves research report
3. `/pplan` - Create PRD `NNN-concept.md`, plan task
4. Human approves PRD
5. `/breakdown` - Create issues under epic
6. `/execute` - Implement with TDD, track in bd


## Command Reference

| Command | Purpose | Output |
|---------|---------|--------|
| `/research` | Codebase impact analysis | `_report.md` + bd tasks |
| `/pplan` | Strategic implementation planning | PRD + bd tasks |
| `/breakdown` | Task decomposition | bd issues |
| `/execute` | Implementation execution | Code changes |


## bd Commands Quick Reference

```bash
# Create epic
bd create "Feature" -t epic --from-template epic --json

# Create task with dependency
bd create "Task" -t task --parent <epic-id> --deps blocks:<id> --json

# Find ready work
bd ready --json

# Claim issue
bd update <id> --status in_progress --json

# Close issue
bd close <id> --reason "Done" --json

# View dependencies
bd dep tree <epic-id>

# Add dependency
bd dep add <id> <blocker-id>
```

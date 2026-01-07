---
name: research
description: Pre-implementation research for design, architecture, and impact analysis. Use during brainstorming, architectural design, or before implementation to understand dependencies and integration points. Triggers on (1) designing or architecting a feature, (2) brainstorming implementation approaches, (3) analyzing impact of proposed changes, (4) exploring reference materials in extra/, (5) creating research reports before planning.
---

<required>
*CRITICAL* Add the following steps to your Todo list using TodoWrite:

- Read the 'Guidelines'.
- Check `extra/` for required reference materials. HALT if missing.
- Analyze the user's research request.
- Discover project dependencies and existing patterns.
- Study reference implementations in `extra/`.
- Identify all files requiring changes (with line numbers).
- Invoke Skill(Planning Documents) to determine document naming (NNN-concept_report.md pattern).
- Write research findings to `prompts/NNN-concept_report.md`.
- Present final output summary to user.
</required>

# Guidelines

## Reference Material First

All research relies on materials in the `extra/` directory.
This includes reference codebases, documentation, and specifications.

Before proceeding with any research:

1. Identify what reference materials are needed
2. Check if they exist in `extra/`
3. If missing, HALT and request them (see HALT Behavior below)
4. Only proceed after all materials are available

Never use web fetch or web search as the primary research method.
The `extra/` directory should contain everything needed.

## HALT Behavior

If required documentation or codebase is not in `extra/`, you must:

1. Stop immediately
2. Report what is missing
3. Suggest how the user can add it

Example HALT message:
```
HALT: Missing reference material.

Required: Textual compositor implementation
Suggestion: Clone to extra/textual:
  git clone https://github.com/Textualize/textual extra/textual

Required: Ratatui border symbols
Location needed: extra/ratatui/ratatui-core/src/symbols/
Suggestion: If not present, clone:
  git clone https://github.com/ratatui/ratatui extra/ratatui
```

Do not attempt to work around missing materials.
Do not use web search as a substitute.
Wait for the user to add the required materials.

### At Start of Research

1. Identify next NNN number by checking existing files in `prompts/`
2. Extract concept-label from user request (e.g., "compositor", "event-parsing")
3. Create epic for the feature:
   ```bash
   bd create "<concept>" -t epic --from-template epic --json
   ```
4. Create research task under the epic:
   ```bash
   bd create "Research: <concept>" -t task --from-template research --parent <epic-id> --json
   ```
5. Store the epic ID and research task ID for output

### At End of Research

1. After writing the research document, close the task:
   ```bash
   bd close <research-task-id> --reason "Research complete: prompts/NNN-concept_report.md"
   ```
2. Output the epic ID and document path for the next phase

## Project-First Approach

Discover what the project already uses:
- Analyze deps.edn/bb.edn for actual dependencies
- Find documentation for the ACTUAL versions in use
- Use existing patterns and conventions found in the codebase

Never:
- Assume specific libraries are available
- Introduce new dependencies without explicit user approval
- Suggest patterns not already established in the project

## Mandatory Agent Consultation

These agents are READ-ONLY - they return information and suggestions only.
You are the orchestrator: guide these agents, synthesize their outputs into the final research document.

| Agent | When to Consult | What They Return |
|-------|-----------------|------------------|
| `Explore` | For codebase exploration and search | File locations, code patterns, structural understanding |
| `clojure-expert` | For Clojure patterns and idioms | Idiomatic approaches, style guidance |
| `research-agent` | For analyzing extra/ materials | Extracted patterns, API summaries |

Use `Explore` agents extensively to:
- Find files matching patterns
- Search for keywords and implementations
- Understand codebase structure
- Locate integration points

## Research Document Structure

### 1. Reference Materials Used

List materials from `extra/` that were analyzed:
- `extra/textual/src/textual/_compositor.py` - Compositor implementation
- `extra/ratatui/ratatui-widgets/src/borders.rs` - Border symbols

### 2. Project Dependencies Discovered

From deps.edn:
- [library]: [version]
- [library]: [version]

### 3. Existing Patterns Found

Document patterns already in use:
- Namespace pattern: [description]
  - Example: `src/ol/bramble/widgets/text.clj:15`
- Protocol pattern: [description]
  - Example: `src/ol/bramble/protocols.clj:20`

### 4. Files Requiring Changes

- `path/to/file.clj:line` - [specific change needed]
- `path/to/file.clj:line` - [specific change needed]

### 5. Integration Points

- External APIs: [list]
- Database changes: [list]
- Configuration changes: [list]

### 6. Risk Assessment

- Breaking changes: [list with severity]
- Performance implications: [concerns]
- Security touchpoints: [areas]

### 7. Unclear Areas

Questions for the user:
- [specific question about requirements]
- [ambiguous pattern that needs clarification]

## Git Constraints

You have READ-ONLY git access.

Allowed:
- `git status`
- `git log`
- `git diff`
- `git show`

Never allowed:
- `git add`, `git commit`, `git push`
- Any command that modifies the repository

## Output Location

Save research to: `prompts/NNN-concept_report.md`

Or for specific library research: `prompts/NNN-concept_library_report.md`

Check existing files in `prompts/` to determine the next NNN number.
Follow the naming convention: three digits, hyphenated concept label, underscore report suffix.

## Final Output

After completing research, output one of the following:

```
## Research Complete

Document: prompts/NNN-concept_report.md

Ready for implementation planning.
```

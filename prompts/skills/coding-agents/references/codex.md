# Codex CLI Reference

OpenAI's coding agent CLI.

## Invocation

```bash
# Interactive
codex

# With prompt
codex "Your task"

# Full auto mode (sandboxed, auto-approves on request)
codex --full-auto "Your task"

# Non-interactive exec mode
codex exec "Your task"

# No sandbox, no approvals (dangerous, for externally sandboxed environments)
codex --dangerously-bypass-approvals-and-sandbox "Your task"
```

## Key Flags

- `--full-auto`: Low-friction sandboxed execution (-a on-request, --sandbox workspace-write)
- `--dangerously-bypass-approvals-and-sandbox`: Skip all prompts, no sandbox (for unattended use)
- `-m, --model <model>`: Model to use
- `-C, --cd <dir>`: Working directory for the agent
- `--sandbox <mode>`: Sandbox policy: read-only, workspace-write, danger-full-access
- `-a, --ask-for-approval <policy>`: When to require approval: untrusted, on-failure, on-request, never
- `--search`: Enable web search tool

## Subcommands

- `exec` / `e`: Run non-interactively
- `review`: Run code review non-interactively
- `resume`: Resume previous session (--last for most recent)

## Completion Detection

- Returns to shell prompt
- Look for the Codex prompt character in output

## Exit Command

Standard shell exit or Ctrl+C

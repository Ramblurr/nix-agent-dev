# OpenCode Reference

Open-source coding agent CLI.

## Invocation

```bash
# Interactive (default)
opencode

# Interactive in specific directory
opencode /path/to/project

# Run with a message
opencode run "Your task"

# Continue last session
opencode -c
opencode --continue
```

## Key Flags

- `-m, --model <provider/model>`: Model to use (e.g., "anthropic/claude-sonnet")
- `-c, --continue`: Continue the last session
- `-s, --session <id>`: Continue specific session
- `--prompt <text>`: Prompt to use
- `--agent <name>`: Agent to use

## Subcommands

- `run [message..]`: Run with a message
- `serve` / `web`: Start headless server
- `pr <number>`: Fetch GitHub PR and run opencode on it
- `session`: Manage sessions

## Completion Detection

- Returns to prompt after task

## Exit Command

Standard exit or Ctrl+C

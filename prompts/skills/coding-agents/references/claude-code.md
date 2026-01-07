# Claude Code Reference

Anthropic's official CLI for Claude.

## Invocation

```bash
# Interactive (default)
claude

# With initial prompt
claude "Your task"

# Skip permission prompts (for automation)
claude --dangerously-skip-permissions

# Non-interactive (print and exit)
claude -p "Your task"
```

## Key Flags

- `--dangerously-skip-permissions`: Auto-approve tool calls (required for unattended use)
- `-p, --print`: Print response and exit (non-interactive, useful for pipes)
- `--output-format <format>`: Output format with --print: "text" (default), "json", or "stream-json"
- `-m, --model <model>`: Model for session (e.g., "sonnet", "opus", or full name)
- `-c, --continue`: Continue the most recent conversation
- `-r, --resume [id]`: Resume by session ID or open picker
- `--system-prompt <prompt>`: Custom system prompt
- `--append-system-prompt <prompt>`: Append to default system prompt

## Completion Detection

- Prompt returns to `> `
- In tmux, look for the input prompt line

## Exit Command

`/exit`

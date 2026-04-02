# ⚡ Spark

Claude Code HUD

Spark is a Claude Code hook that displays a live status line at the top of every response:

```
⚡ main | +42/-3 | 4 files | #12 | 23min
```

Branch. Diff weight. Files touched. Prompt count. Session clock. Glanceable, always there.

## How it works

Claude Code has a [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks) that runs scripts on every prompt. Spark uses the `UserPromptSubmit` hook to inject a computed status line into Claude's context via `additionalContext`. Claude displays it at the top of its response.

No VS Code extension. No separate window. No dependencies. Just a shell script.

## Install

One command, from your project root:

```bash
curl -fsSL https://raw.githubusercontent.com/jbmoutout/spark/main/install.sh | bash
```

This downloads the hooks, creates/updates `.claude/settings.json`, and you're done. Next Claude Code prompt shows the HUD.

### Manual install

```bash
# 1. Copy hooks to your project
cp spark.sh spark-precompact.sh /path/to/your/project/.claude/hooks/
chmod +x /path/to/your/project/.claude/hooks/spark*.sh

# 2. Add the hooks to your project's .claude/settings.json
```

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/spark.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/spark-precompact.sh",
            "timeout": 3000
          }
        ]
      }
    ]
  }
}
```

The PreCompact hook is optional — it enables the compaction warning widget. Everything else works with just the UserPromptSubmit hook.

That's it. Next Claude Code prompt shows the HUD.

## Widgets

Each widget computes one value. Widgets can run in two modes:

| Mode | What happens |
|------|-------------|
| `display` | Shown in the HUD line (user sees it) |
| `context` | Injected silently (Claude knows it, user doesn't see it) |
| `off` | Disabled |

### Built-in widgets

| Widget | Shows | Default | Notes |
|--------|-------|---------|-------|
| `branch` | Current git branch | display | |
| `diff_weight` | +N/-N lines changed | display | |
| `files_touched` | Modified + untracked file count | display | |
| `prompt_count` | Prompts this session (#N) | display | |
| `session_clock` | Time since session start | display | |
| `todos` | TODO/FIXME/HACK count in changed files | context | |
| `secrets` | Detects API keys in staged files | display | Silent when clean |
| `compaction` | Warns when context was compacted | display | Silent when clean, needs PreCompact hook |

## Configuration

Create `.spark/config.json` in your project root to customize:

```json
{
  "widgets": {
    "branch": "display",
    "diff_weight": "display",
    "files_touched": "context",
    "prompt_count": "display",
    "session_clock": "off"
  }
}
```

No config file = all widgets in display mode.

## Security

Spark is a Claude Code hook that injects session metadata into Claude's context via `additionalContext`. This means it can influence Claude's behavior — review the source before installing.

- No network calls, no dependencies, single file
- Only reads git metadata and a local state file
- Prompt content received on stdin is discarded (`cat > /dev/null`)
- Widget output is sanitized (ASCII-only, length-capped)
- All python blocks use `os.environ` — no string interpolation
- Injected values are marked as untrusted in the prompt
- Verify the source: `shasum -a 256 spark.sh`

## Requirements

- Claude Code with hooks support
- bash, python3 (ships with macOS/most Linux)
- git (for git-based widgets)

## How it really works

The `additionalContext` field from a `UserPromptSubmit` hook gets injected at memory layer priority (layer 5 of 6) in Claude's context. Passive phrasing gets ignored — Claude sees it but doesn't display it. Directive phrasing ("display this verbatim, not optional") forces Claude to render it in the response.

Display-mode widgets use directive phrasing. Context-mode widgets use passive phrasing — Claude absorbs the info silently and it influences behavior without appearing in the response.

## License

MIT

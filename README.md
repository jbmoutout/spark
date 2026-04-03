# ⚡ Spark

Claude Code HUD

Spark is a Claude Code hook that displays a live status line at the top of every response:

```
⚡ git:(main) · +42/-3 · 474k tok · 23min
```

Branch. Diff weight. Token usage. Session clock. Glanceable, always there.

## How it works

Claude Code has a [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks) that runs scripts on every prompt. Spark uses the `UserPromptSubmit` hook to inject a computed status line into Claude's context via `additionalContext`. Claude displays it at the top of its response.

No VS Code extension. No separate window. No dependencies. Just a shell script.

## Install

From your project root:

```bash
npx spark-hud
```

Or without npm, from a checked-out copy of this repo:

```bash
./install.sh
```

To remove:

```bash
npx spark-hud --remove
```

That's it. Next Claude Code prompt shows the HUD.

### Manual install

```bash
# 1. Copy hooks to your project
cp spark.sh spark-precompact.sh spark-stop.sh /path/to/your/project/.claude/hooks/
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
    ],
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/spark-stop.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

The `PreCompact` hook is optional for compaction warnings. The `Stop` hook is optional for token tracking.

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
| `files_touched` | Modified + untracked file count | context | |
| `tokens` | Session token usage | display | Needs Stop hook, one-response delay |
| `prompt_count` | Prompts this session (#N) | context | |
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

No config file = built-in defaults: `branch`, `diff_weight`, `tokens`, and `session_clock` display; `files_touched`, `prompt_count`, and `todos` stay in context; `secrets` and `compaction` display only when triggered.

## Security

Spark is a Claude Code hook that injects session metadata into Claude's context via `additionalContext`. This means it can influence Claude's behavior — review the source before installing.

- Prefer `npx spark-hud` or a checked-out local install; pin raw downloads to a tag or commit if you use them
- No network calls during normal hook execution
- Only reads git metadata and a local state file
- `UserPromptSubmit` and `PreCompact` discard stdin; `Stop` reads only hook JSON plus a validated transcript path
- Widget output is sanitized (ASCII-only, length-capped)
- All python blocks use `os.environ` — no string interpolation
- Injected values are explicitly marked as untrusted data in the prompt
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

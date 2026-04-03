# ⚡ Spark

A HUD for Claude Code

Spark displays a live status line at the top of every Claude Code response:

```
⚡ git:main · opus · +42/-3 · 474k tok · 23min
```

Branch. Model. Diff weight. Token usage. Session clock. Glanceable, always there.

When something needs attention, a second line appears:

```
⚡ git:main · opus · 474k tok · 18min
△ .env missing · compacted 3 prompts ago
```

When returning to a project (first prompt only):

```
⚡ git:main · opus · 0 tok · 0min
↩ last: 2h ago / feat/auth / 3 TODOs
```

## Install

```bash
npx spark-hud
```

Or from a checked-out copy:

```bash
./install.sh
```

To remove:

```bash
npx spark-hud --remove
```

## How it works

Claude Code runs [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — scripts that fire on events like prompts, tool use, and compaction. Spark uses three hooks:

| Hook | Script | Purpose |
|------|--------|---------|
| `UserPromptSubmit` | `spark.sh` | Assembles the HUD and injects it into Claude's context |
| `Stop` | `spark-stop.sh` | Parses the transcript for token usage and model info |
| `PreCompact` | `spark-precompact.sh` | Flags when context compaction occurs |

The `Stop` and `PreCompact` hooks are optional — Spark works without them, you just won't get token counts or compaction warnings.

## Widgets

Widgets compute values. Each widget runs in one of three modes:

| Mode | Behavior |
|------|----------|
| `display` | Shown on line 1 — the always-visible HUD |
| `alert` | Shown on line 2 — only when triggered (value != "ok") |
| `context` | Injected silently — Claude knows it, you don't see it |
| `off` | Disabled |

### Built-in widgets

| Widget | Shows | Default mode | Notes |
|--------|-------|-------------|-------|
| `branch` | Git branch | display | |
| `diff_weight` | +N/-N lines changed | display | Hidden when clean |
| `files_touched` | Modified + untracked file count | context | |
| `model` | Which Claude model (opus/sonnet/haiku) | display | Needs Stop hook |
| `tokens` | Session token usage | display | Needs Stop hook |
| `prompt_count` | Prompts this session (#N) | context | |
| `session_clock` | Time since session start | display | |
| `todos` | TODO/FIXME/HACK in changed files | context | |
| `secrets` | API keys in staged files | alert | Silent when clean |
| `compaction` | Context was compacted | alert | Needs PreCompact hook |
| `env_drift` | Node version mismatch, missing .env, Docker down | alert | Silent when clean |
| `last_session` | Previous session info | alert | First prompt only |

## Themes

Set `"theme"` in config to change the HUD style:

| Theme | Example |
|-------|---------|
| `default` | `⚡ git:main · opus · +42/-3 · 474k tok · 18min` |
| `minimal` | `⚡ main/opus +42/-3 · 474k tok · 18m` |
| `starship` | `⚡ ✗ main +42/-3 · opus · 474k tok · 18m` |
| `classic` | `>> [MAIN] [OPUS] [+42/-3] [474K TOK] [18M]` |
| `powerline` | `⚡  main   opus   +42/-3   474k tok   18m` |

## Custom widgets

Drop a shell script in `.spark/widgets/` and add it to your config:

```bash
# .spark/widgets/uptime.sh
#!/bin/bash
echo "up $(uptime | grep -oE 'up [^,]+'  | sed 's/up //')"
```

```json
{
  "widgets": {
    "branch": "display",
    "uptime": "display"
  }
}
```

Rules:
- Widget must be listed in config AND exist as an executable `.sh` file
- A file in `.spark/widgets/` that isn't in config will never run
- Widget names: alphanumeric and underscore only
- Output is sanitized (ASCII-only, length-capped to 60 chars)
- Custom widgets render on line 2, not line 1
- Env vars available: `CLAUDE_PROJECT_DIR`, `SPARK_STATE_FILE`

## Configuration

Create `.spark/config.json` in your project root:

```json
{
  "theme": "starship",
  "widgets": {
    "branch": "display",
    "model": "display",
    "diff_weight": "display",
    "tokens": "display",
    "session_clock": "display",
    "files_touched": "context",
    "todos": "context",
    "secrets": "alert",
    "compaction": "alert",
    "env_drift": "alert",
    "last_session": "alert"
  }
}
```

No config file = sensible defaults.

## Security

Spark hooks inject session metadata into Claude's context via `additionalContext`. Review the source before installing.

- No network calls during normal hook execution
- Only reads git metadata, a local state file, and (for Stop hook) the session transcript
- Widget output is sanitized (ASCII-only, length-capped)
- All python blocks use `os.environ` — no string interpolation
- Injected values are marked as untrusted in the prompt
- Custom widgets require explicit opt-in via config — files in `.spark/widgets/` don't run unless listed
- Prefer `npx spark-hud` or a local install; pin raw downloads to a tag or commit

## Requirements

- Claude Code with hooks support
- bash, python3 (ships with macOS / most Linux)
- git (for git-based widgets)

## How it really works

The `additionalContext` field from a `UserPromptSubmit` hook gets injected at memory layer priority (layer 5 of 6) in Claude's context. Passive phrasing gets ignored — Claude sees it but doesn't show it. Directive phrasing forces Claude to render it in the response.

- **display** mode widgets use directive phrasing — Claude reproduces the HUD line verbatim
- **context** mode widgets use passive phrasing — Claude absorbs the info silently
- **alert** mode widgets only appear when triggered (value != "ok")

## Roadmap

- [ ] More built-in widgets — see [WIDGETS.md](WIDGETS.md) for planned widgets and community ideas
- [ ] Performance monitoring — track Spark's own execution time, flag when it gets slow
- [ ] Portability to other coding agents — the insight is portable, the implementation is agent-specific
- [ ] Composable widgets — widgets reading each other's state via the shared state file

## License

MIT

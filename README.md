# ⚡ Spark

A HUD for Claude Code

Spark displays a live status line at the top of every Claude Code response.

**First prompt — preflight with scaffolded labels:**
```
⚡ git:main · tokens:0 · time:0m
  active: secrets · compaction · env · last · party
───
```

**Subsequent prompts — delta only, labels stripped:**
```
⚡ git:main · 48k · +42/-3 · 18m
───
```

**When something needs attention:**
```
⚡ git:main · 52k · 20m
△ SECRETS:1
───
```

**When returning to a project (first prompt only):**
```
⚡ git:main · tokens:0 · time:0m
↩ last: 2h ago / feat/auth / 3 TODOs
───
```

## Quick Start

Open Claude Code in your project and paste:

> Install Spark HUD on this project. Run `npx spark-hud` to install the hooks. Then set up my preferences — ask me which city I'm in for weather, which timezones I want to track, and whether I prefer the default or compact theme. Add SPARK_WEATHER_LOCATION to my shell profile, update .spark/config.json, and make sure .spark/ is in .gitignore. Confirm everything worked.

Your next prompt will show the ⚡ HUD.

## Install

```bash
npx spark-hud
```

Or from a checked-out copy:

```bash
./install.sh
```

`install.sh` expects the hook files to live next to it in the repo checkout. It does not download executable hook code from GitHub at install time.

To remove:

```bash
npx spark-hud --remove
```

## Releasing

See [RELEASING.md](RELEASING.md) for the release checklist. CI and publish both run shell syntax checks, `shellcheck`, `npm test`, and `npm pack --dry-run`.

## How it works

Claude Code runs [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — scripts that fire on events like prompts, tool use, and compaction. Spark uses three hooks:

| Hook | Script | Purpose |
|------|--------|---------|
| `UserPromptSubmit` | `spark.sh` + `spark-widgets.sh` | Assembles the HUD and injects it into Claude's context |
| `Stop` | `spark-stop.sh` | Parses transcript for tokens, model, files explored, sub-agents |
| `PreCompact` | `spark-precompact.sh` | Flags when context compaction occurs |

The `Stop` and `PreCompact` hooks are optional — Spark works without them, you just won't get token counts or compaction warnings.

## Display Design

Spark uses **progressive disclosure**: the first prompt teaches you what each value means (with labels), then strips the labels on subsequent prompts once you've learned.

The HUD shows **only what changed** between prompts. Branch and clock always show (your anchor). Diff weight and model only appear when they change. Opt-in ambient widgets such as weather and timezone refresh every 10 prompts.

A session rolls over after 30 minutes of inactivity by default. Override that threshold with `SPARK_SESSION_IDLE_SECS`.

## Widgets

Each widget runs in one of three modes:

| Mode | Behavior |
|------|----------|
| `display` | Shown on line 1 — the always-visible HUD |
| `alert` | Shown on line 2 — only when triggered |
| `context` | Injected silently — Claude knows it, you don't see it |
| `off` | Disabled |

### Built-in widgets

| Widget | Shows | Default | Notes |
|--------|-------|---------|-------|
| `branch` | Git branch | display | |
| `diff_weight` | +N/-N lines changed | display | Hidden when clean |
| `model` | Claude model (opus/sonnet/haiku) | display | Needs Stop hook |
| `tokens` | Session token usage | display | Needs Stop hook |
| `session_clock` | Session duration | display | |
| `plant` | Growing plant: `,` → `.:` → `.:|:.` → `*:|:*` | display | Cumulative across sessions |
| `files_touched` | Modified + untracked file count | context | |
| `prompt_count` | Prompts this session (#N) | context | |
| `todos` | TODO/FIXME/HACK in changed files | context | |
| `explored` | Files Claude has Read/Grep/Globbed | context | Unique to Spark |
| `secrets` | API keys in staged files | alert | Silent when clean |
| `compaction` | Context was compacted | alert | Unique to Spark. Needs PreCompact hook |
| `env_drift` | Node version mismatch, missing .env, Docker down | alert | Silent when clean |
| `last_session` | Previous session: branch, time ago, TODOs | alert | First prompt only |
| `party` | Sub-agents Claude spawned | alert | Unique to Spark. Needs Stop hook |
| `weather` | Local weather (cached, opt-in network call) | off | Export `SPARK_WEATHER_LOCATION` and set widget mode to `alert` |
| `timezone` | City clocks | off | Set `timezones` array and widget mode to `alert` |

## Themes

| Theme | Example |
|-------|---------|
| `default` | `⚡ git:main · 48k · +42/-3 · 18m` |
| `compact` | `⚡ ✓ main · 48k · 18m` / `⚡ ✗ main +42/-3 · 48k · 18m` |

## Custom widgets

Drop a shell script in `.spark/widgets/` and add it to your config:

```bash
# .spark/widgets/uptime.sh
#!/bin/bash
echo "up $(uptime -p | sed 's/up //')"
```

```json
{
  "widgets": {
    "uptime": "display"
  }
}
```

Rules:
- Widget must be listed in config AND exist as an executable `.sh` file
- Files in `.spark/widgets/` that aren't in config will never run
- Project-defined widgets are disabled unless you export `SPARK_ENABLE_UNSAFE_CUSTOM_WIDGETS=1`
- Output is sanitized (ASCII-only, length-capped to 60 chars)
- Custom widgets render on line 2, not line 1
- Env vars available: `CLAUDE_PROJECT_DIR`, `SPARK_STATE_FILE`
- Return `ok` to hide the widget (silent when clean)

## Configuration

Create `.spark/config.json` in your project root:

```json
{
  "theme": "default",
  "timezones": ["Asia/Bangkok", "America/New_York"],
  "widgets": {
    "branch": "display",
    "model": "display",
    "diff_weight": "display",
    "tokens": "display",
    "session_clock": "display",
    "plant": "display",
    "files_touched": "context",
    "prompt_count": "context",
    "todos": "context",
    "explored": "context",
    "secrets": "alert",
    "compaction": "alert",
    "env_drift": "alert",
    "last_session": "alert",
    "party": "alert",
    "weather": "off",
    "timezone": "off"
  }
}
```

No config file = sensible defaults.

To enable weather, export `SPARK_WEATHER_LOCATION` outside the repo, for example `export SPARK_WEATHER_LOCATION=Paris`, then set `"weather": "alert"` in config.

## Security

Spark hooks inject session metadata into Claude's context via `additionalContext`. Review the source before installing.

- No network calls during normal hook execution (weather is opt-in, cached 30min)
- Weather requires explicit opt-in via `SPARK_WEATHER_LOCATION`; repo config alone cannot trigger network requests
- Only reads git metadata, a local state file, and (for Stop hook) the session transcript
- Widget output is sanitized (ASCII-only, length-capped)
- Dynamic widget state is passed into Python via `os.environ` rather than interpolating untrusted values into Python source
- Injected values are marked as untrusted in the prompt
- Custom widgets require explicit opt-in via both config and `SPARK_ENABLE_UNSAFE_CUSTOM_WIDGETS=1`
- Prefer `npx spark-hud` or a local install from a checked-out repo

## Requirements

- Claude Code with hooks support
- bash, python3 (ships with macOS / most Linux)
- git (for git-based widgets)

## How it really works

The `additionalContext` field from a `UserPromptSubmit` hook gets injected at memory layer priority (layer 5 of 6) in Claude's context. Passive phrasing gets ignored — Claude sees it but doesn't show it. Directive phrasing forces Claude to render it in the response.

- **display** mode: directive phrasing — Claude reproduces the HUD verbatim
- **context** mode: passive phrasing — Claude absorbs it silently
- **alert** mode: only appears when triggered (value != "ok")

## Roadmap

- [ ] More built-in widgets — see [WIDGETS.md](WIDGETS.md) for planned and community ideas
- [ ] Performance monitoring — track Spark's own execution time
- [ ] Portability to other coding agents
- [ ] Composable widgets — widgets reading each other's state

## License

MIT

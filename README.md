# spark

Spark shows a live status line at the top of every Claude Code response.

**first prompt:**
```
⚡ git:main · tokens:0 · time:0m
  active: secrets · compaction · env · last · party
───
```

**after that:**
```
⚡ git:main · 48k · +42/-3 · 18m
───
```

**when something needs attention:**
```
⚡ git:main · 52k · 20m
△ SECRETS:1
───
```

**returning to a project (first prompt only):**
```
⚡ git:main · tokens:0 · time:0m
↩ last: 2h ago / feat/auth / 3 TODOs
───
```

## install

Open Claude Code in your project and paste:

```bash
Install Spark on this project. Run `npx spark-hud` to install the hooks. Then set up my preferences — ask me which city I'm in for weather, which timezones I want to track, and whether I prefer the default or compact theme. Add SPARK_WEATHER_LOCATION to my shell profile, update .spark/config.json, and make sure .spark/ is in .gitignore. Confirm everything worked.
````

Or manually:

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

## how it works

| Hook | Script | Purpose |
|------|--------|---------|
| `UserPromptSubmit` | `spark.sh` + `spark-widgets.sh` | Assembles the status line and injects it into Claude's context |
| `Stop` | `spark-stop.sh` | Parses transcript for tokens, model, files explored, sub-agents |
| `PreCompact` | `spark-precompact.sh` | Flags when context compaction occurs |

Stop and PreCompact are optional — without them you just lose token counts and compaction warnings.

## widgets

Each widget runs in one of these modes:

| Mode | Behavior |
|------|----------|
| `display` | Shown on line 1 — the always-visible status line |
| `alert` | Shown on line 2 — only when triggered |
| `context` | Injected silently — Claude knows it, you don't see it |
| `off` | Disabled |

### built-in

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
| `explored` | Files Claude has Read/Grep/Globbed | context | |
| `secrets` | API keys in staged files | alert | Silent when clean |
| `compaction` | Context was compacted | alert | Needs PreCompact hook |
| `env_drift` | Node version mismatch, missing .env, Docker down | alert | Silent when clean |
| `last_session` | Previous session: branch, time ago, TODOs | alert | First prompt only |
| `party` | Sub-agents Claude spawned | alert | Needs Stop hook |
| `weather` | Local weather (cached, opt-in network call) | off | Export `SPARK_WEATHER_LOCATION` and set mode to `alert` |
| `timezone` | City clocks | off | Set `timezones` array and mode to `alert` |

## themes

| Theme | Example |
|-------|---------|
| `default` | `⚡ git:main · 48k · +42/-3 · 18m` |
| `compact` | `⚡ ✓ main · 48k · 18m` / `⚡ ✗ main +42/-3 · 48k · 18m` |

## custom widgets

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

- Widget must be listed in config AND exist as an executable `.sh` file
- Files in `.spark/widgets/` that aren't in config will never run
- Project-defined widgets are disabled unless you export `SPARK_ENABLE_UNSAFE_CUSTOM_WIDGETS=1`
- Output is sanitized (ASCII-only, length-capped to 60 chars)
- Custom widgets render on line 2, not line 1
- Env vars available: `CLAUDE_PROJECT_DIR`, `SPARK_STATE_FILE`
- Return `ok` to hide the widget (silent when clean)

## config

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

To enable weather, export `SPARK_WEATHER_LOCATION` outside the repo (e.g. `export SPARK_WEATHER_LOCATION=Paris`), then set `"weather": "alert"` in config.

Session rolls over after 30 minutes of inactivity. Override with `SPARK_SESSION_IDLE_SECS`.

## security notes

No network calls unless you opt into weather. Only reads git metadata and a local state file. Widget output is sanitized. Custom widgets need explicit opt-in via both config and `SPARK_ENABLE_UNSAFE_CUSTOM_WIDGETS=1`. Review the source if you're cautious.

## requirements

- Claude Code with hooks support
- bash, python3 (ships with macOS / most Linux)
- git (for git-based widgets)

## license

MIT

# widgets

Built-in widgets ship with Spark. Custom widgets live in `.spark/widgets/`.

## built-in

| Widget | Shows | Default |
|--------|-------|---------|
| `branch` | Git branch: `git:main` | display |
| `model` | Claude model: `opus` / `sonnet` / `haiku` | display |
| `diff_weight` | Lines changed: `+42/-3` | display |
| `tokens` | Session token usage: `48k` | display |
| `session_clock` | Session duration: `18m` | display |
| `plant` | Growing plant: `,` → `.:` → `.:|:.` → `*:|:*` | display |
| `files_touched` | Modified + untracked file count | context |
| `prompt_count` | Prompts this session: `#12` | context |
| `explored` | Files Claude has Read/Grep/Globbed this session | context |
| `secrets` | API keys detected in staged files | alert |
| `compaction` | Context was compacted | alert |
| `env_drift` | Node version mismatch, missing .env, Docker not running | alert |
| `last_session` | Previous session: branch, time ago, open TODOs (first prompt only) | alert |
| `party` | Sub-agents Claude spawned this session | alert |
| `weather` | Local weather, cached 30min (opt-in network call) | off |
| `timezone` | City clocks from config | off |

## ideas

- Loop detector — same file edited 3+ times without committing
- Systems check — preflight: git, node, env, deps — all green? (first prompt only)
- Pet — ASCII pet reacts to code state: `(=^.^=)` clean, `(>_<)` tests fail
- Glyph — unique ASCII pattern per session from hash
- Rune — random unicode symbol each prompt
- Literature — one sentence per prompt from Project Gutenberg classics
- ASCII art — curated 1-line ASCII art, rotating
- Moon — current moon phase from date math
- Today in history — computing history for today's date, bundled
- Odometer — lifetime tokens across all sessions, never resets
- MOTD — message of the day, release notes, once per version
- Contributor — `contributor: spark v0.5` — first prompt identity
- Uptime — total time in Claude Code today / this week
- BPM — `bpm: 12` — prompts per hour, your coding tempo
- Splits — token usage per prompt, like running splits
- Ticker tape — `+3 files -0 tests +47 lines` — all deltas on one line
- Now playing — current track from Spotify/Apple Music (system API)
- Wanted level — GTA stars by uncommitted lines
- Hydration — `water?` every 45 minutes
- Countdown — `ship in: 3d 14h` — to a date you set
- Walking dot — `>........` walks one step per prompt
- Growing plant variants (braille, blocks, botanical unicode)
- Session rings — `[*][*][ ]` — commits, edits, tests (Apple Watch style)
- Fortune cookie — programming wisdom, real quotes
- Radio frequency — `freq: 98.7` — fake station from session hash
- Coding streak — `streak: 4 days` — consecutive days with commits
- Rest day — `rest day yesterday — welcome back`
- Personal best — `pb: longest session 4h12m`

## notes

No network calls without explicit opt-in. No fake data — if it's not available at runtime, don't show it. No gamification in core widgets. Don't repeat what Claude's response already shows.

## writing a widget

A custom widget is a shell script that prints one line:

```bash
#!/bin/bash
# .spark/widgets/uptime.sh
echo "up $(uptime -p | sed 's/up //')"
```

Add it to `.spark/config.json`:

```json
{
  "widgets": {
    "uptime": "display"
  }
}
```

That's it. Runs every prompt. Output sanitized to 60 ASCII chars.

Project-defined widgets are disabled unless you explicitly export `SPARK_ENABLE_UNSAFE_CUSTOM_WIDGETS=1`.

Available env vars: `CLAUDE_PROJECT_DIR`, `SPARK_STATE_FILE`.

Return `ok` to hide the widget (silent when clean).

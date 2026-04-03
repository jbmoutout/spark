# ⚡ Spark — Widget Gallery

Built-in widgets ship with Spark. Community widgets live in `.spark/widgets/`.

## Widget Categories

| Category | Purpose | Cognitive contract |
|----------|---------|-------------------|
| **Instruments** | Facts about your session | Scan at a glance |
| **Signals** | Alerts when something needs attention | Read when they appear |
| **Ambient** | Texture, vibe, delight | Pause and enjoy |
| **Social** | Awareness of yourself over time | Reflect occasionally |

## Built-in Widgets

### Instruments

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

### Signals

| Widget | Shows | Default |
|--------|-------|---------|
| `secrets` | API keys detected in staged files | alert |
| `compaction` | Context was compacted — Claude may have forgotten earlier work | alert |
| `env_drift` | Node version mismatch, missing .env, Docker not running | alert |
| `last_session` | Previous session: branch, time ago, open TODOs (first prompt only) | alert |
| `party` | Sub-agents Claude spawned this session | alert |
| `loop_detector` | Same file edited 3+ times without committing | *planned* |
| `systems_check` | Preflight: git, node, env, deps — all green? (first prompt only) | *planned* |

### Ambient

| Widget | Shows | Default |
|--------|-------|---------|
| `weather` | Local weather, cached 30min (opt-in network call) | alert |
| `timezone` | City clocks from config | alert |
| `pet` | ASCII pet reacts to code state: `(=^.^=)` clean, `(>_<)` tests fail | *planned* |
| `glyph` | Unique ASCII pattern per session from hash | *planned* |
| `rune` | Random unicode symbol each prompt | *planned* |
| `literature` | One sentence per prompt from Project Gutenberg classics | *planned* |
| `ascii_art` | Curated 1-line ASCII art, rotating | *planned* |
| `moon` | Current moon phase from date math | *planned* |
| `today_in_history` | Computing history for today's date, bundled | *planned* |

### Social

| Widget | Shows | Default |
|--------|-------|---------|
| `odometer` | Lifetime tokens across all sessions, never resets | *planned* |
| `motd` | Message of the day — release notes, once per version | *planned* |
| `contributor` | `contributor: spark v0.5` — first prompt, community identity | *planned* |
| `uptime` | Total time in Claude Code today / this week | *planned* |

## Community Widget Ideas

Ideas we'd love to see as custom widgets (`.spark/widgets/`). PRs welcome.

**Instruments:**
- BPM — `bpm: 12` — prompts per hour, your coding tempo
- Splits — token usage per prompt, like running splits
- Ticker tape — `+3 files -0 tests +47 lines` — all deltas on one line
- Now playing — current track from Spotify/Apple Music (system API)

**Signals:**
- Wanted level — GTA stars by uncommitted lines
- Hydration — `water?` every 45 minutes
- Countdown — `ship in: 3d 14h` — to a date you set

**Ambient:**
- Walking dot — `>........` walks one step per prompt
- Growing plant variants (braille, blocks, botanical unicode)
- Session rings — `[*][*][ ]` — commits, edits, tests (Apple Watch style)
- Fortune cookie — programming wisdom, real quotes
- Radio frequency — `freq: 98.7` — fake station from session hash

**Social:**
- Coding streak — `streak: 4 days` — consecutive days with commits
- Rest day — `rest day yesterday — welcome back`
- Personal best — `pb: longest session 4h12m`

## Design Principles

1. **Code state is safe** — tests, git, commits are objective facts. Display freely.
2. **User state is risky** — mood, frustration, intent are subjective. Don't attribute.
3. **No gamification in core** — XP, streaks, evolution are community widgets.
4. **No hardcoded values** — if data isn't available at runtime, don't fake it.
5. **Network = opt-in** — widgets that make network calls must be explicitly enabled.
6. **Don't repeat the thread** — Spark is a tiny layer. Don't duplicate what Claude's response shows.
7. **Neutral personality** — Spark is instruments, not a character.

## Writing a Widget

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

Available env vars: `CLAUDE_PROJECT_DIR`, `SPARK_STATE_FILE`.

Return `ok` to hide the widget (silent when clean).

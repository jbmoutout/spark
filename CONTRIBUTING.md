# Contributing

## Widget Ideas

See [WIDGETS.md](WIDGETS.md) for planned widgets and community ideas. Pick one and build it, or bring your own.

## Writing a Custom Widget

A widget is a shell script that prints one line to stdout:

```bash
#!/bin/bash
# widgets/my-widget.sh
echo "hello world"
```

Rules:
- Return `ok` to hide the widget (silent when clean)
- Output is sanitized to 60 ASCII characters
- Keep it under 3 seconds — the hook has a timeout
- No network calls unless explicitly opt-in (document it)
- Available env vars: `CLAUDE_PROJECT_DIR`, `SPARK_STATE_FILE`

## Submitting a Widget PR

1. Add your widget function to `spark-widgets.sh`
2. Add it to the `BUILTIN_NAMES` list and default config in `spark.sh`
3. Add a row to the widget table in `WIDGETS.md` and `README.md`
4. Run `npm test`

If your widget needs a new hook (Stop, PreCompact, PostToolUse), explain why in the PR.

## Design Principles

Before building, read these:

1. **Code state is safe** — tests, git, commits are objective facts. Display freely.
2. **User state is risky** — mood, frustration, intent are subjective. Don't attribute.
3. **No gamification in core** — XP, streaks, evolution belong as custom widgets.
4. **No hardcoded values** — if data isn't available at runtime, don't fake it.
5. **Network = opt-in** — widgets making network calls must require explicit env var opt-in.
6. **Don't repeat the thread** — don't duplicate what Claude's response already shows.
7. **Neutral personality** — core Spark is instruments, not a character. Community widgets can add personality.

## Widget Modes

Choose the right default mode for your widget:

| Mode | When to use |
|------|-------------|
| `display` | Always-visible instruments (branch, tokens, clock) |
| `alert` | Shows only when triggered — value != "ok" (secrets, compaction) |
| `context` | Claude knows it, user doesn't see it (explored files, TODOs) |
| `off` | Opt-in only (weather, timezone) |

## Shell Portability

Spark runs on macOS and Ubuntu. Treat both as first-class targets.

- Avoid GNU-only or BSD-only shell behavior
- Be careful with `tr`, `sed`, `date`, `grep`, `mktemp`, and character ranges
- In `tr` character sets, put `-` at the edge of the set
- Prefer simple Bash and portable coreutils over clever one-liners
- Run `npm test` before pushing shell changes
- CI verifies on both `ubuntu-latest` and `macos-latest`

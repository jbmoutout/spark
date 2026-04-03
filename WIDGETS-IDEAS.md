# ⚡ Spark — Widget Ideas

Brainstormed 2026-04-03. Ranked by "screenshot and share" potential.

## Tier 1 — Build next (define Spark's personality)

| # | Name | Concept | Mode |
|---|------|---------|------|
| 1 | Fortune Cookie | Random programming wisdom/quote, 60 chars, changes each prompt | display |
| 14 | ASCII Pet | Reacts to code state: `(=^.^=)` clean, `(>_<)` tests fail, `\(^o^)/` after commit | display |
| 18 | Session Glyph | Unique ASCII pattern from session ID hash: `[/#\]` — visual fingerprint | display |
| 24 | Random Rune | One random unicode symbol per prompt: `rune: ∞` or `rune: ♠` | display |
| 26 | Growing Plant | `.:|:.` — grows with cumulative session time. Days to full size. Persists. | display |

## Tier 2 — Strong optional widgets

| # | Name | Concept | Mode | Notes |
|---|------|---------|------|-------|
| 2 | Mood Ring | Sentiment from prompt patterns: `mood: debugging` / `mood: exploring` | context | Risk: misattribution. Context-only, never display. |
| 3 | Coding Streak | `streak: 4 days` — consecutive days with commits | display | |
| 4 | Session Heartbeat | `....*..**.***` — visual tempo of edits | display | |
| 5 | Chapter Title | `ch: The Auth Refactor` — auto from file paths/commits | display | |
| 9 | Weather | `outside: 28C sunny` — curl wttr.in, cached on session start | display | Opt-in. Opens network widget door. |
| 16 | Hydration Nudge | `water?` — every 45 min. Disappears next prompt. | alert | |
| 27 | Note to Self | `note: don't touch auth` — manual sticky from config | display | Simplest widget possible. |
| 29 | Walking Dot | `>........` → `..>......` — walks one step per prompt | display | Pure animation. |
| 30 | Project Sigil | Permanent glyph per project from name hash. Never changes. | display | |
| 31 | Session Counter | `session #247` — lifetime count across all projects | display | Needs global state. |

## Tier 3 — Community widgets (park for contributors)

| # | Name | Concept | Notes |
|---|------|---------|-------|
| 6 | XP Bar | `xp: [=====>    ] lvl 7` — earn XP for commits/prompts | Gamification — community choice |
| 7 | Daily Challenge | `challenge: write a test today` | Disconnected from context |
| 8 | Time of Day Vibe | `dawn / witching hour` — poetic clock | Low priority |
| 10 | Pair Indicator | `solo` or `pair: 2 sessions` — detect other CC processes | |
| 11 | Commit Fortune | `shipped!` / `nice.` — random celebration after commits | Dopamine concern |
| 12 | Focus Timer | `focus: 23/25min` — built-in pomodoro | Ecosystem creep |
| 13 | Spark Self-Report | `spark: 3 widgets / 0.2s` — own performance | Meta |
| 17 | Music Suggestion | `try: lo-fi` — genre from mood + time | Taste-dependent |
| 19 | Prompt Rhythm | `rhythm: 2m 5m 1m` — time between prompts | Niche |
| 20 | Ship Count | `shipped: 47` — total commits this week, all projects | Needs global state |
| 21 | Pet Evolution | Pet evolves: egg → hatchling → creature → beast | Gamification |
| 22 | Clipboard Preview | `clip: "function handleAuth..."` — first 30 chars of clipboard | Privacy concern |
| 23 | Session Title | First prompt becomes the title | Overlaps with Chapter Title |
| 25 | Env Detection | `env: vscode` or `env: terminal` | User already knows |
| 28 | Past Self Quote | `you: "let's just try it and see"` — from prompt history | Uncanny, privacy |

## SCAMPER Mutations (from Tier 1 ideas)

- Fortune → power words: `focus` `ship` `simplify` `breathe`
- Fortune → your own best commit message as wisdom
- Fortune → famous error messages as quotes
- Fortune → note to future self (manual, not computed)
- Fortune → `session #247` (just a number, no text)
- Pet → growing plant (patient, not gamified)
- Pet → pet IS the repo (healthy repo = healthy pet)
- Pet → walking progress dot (animation)
- Pet → abstract pattern growth: `*` → `**` → `*.*` → `*:*`
- Pet → gets smaller as you ship (ship = freedom)
- Glyph → time-based (morning vs night looks different)
- Glyph → branch-based (same branch always same glyph)
- Glyph → project sigil (permanent, stored in config)
- Glyph as separator between line 1 and line 2

## Also generated (not yet ranked)

| # | Name | Concept |
|---|------|---------|
| 32 | Power Words | Single word per prompt: `focus` `ship` `simplify` `breathe` `why?` |
| 33 | Own Best Commit | Your best commit message as today's wisdom, from git log |
| 34 | Error Museum | Famous error messages as quotes: `"cannot read property 'undefined'"` |
| 35 | Abstract Growth | Pattern that evolves: `*` → `**` → `*.*` → `*:*` → `*:*:*` |
| 36 | Reverse Pet | Gets smaller as you ship. Full size at start, gone when done. Ship = freedom. |
| 37 | Time Glyph | Glyph changes based on hour — morning sessions look different from night |
| 38 | Branch Glyph | Same branch always generates same glyph across sessions |
| 39 | Glyph Separator | Glyph as visual separator between line 1 and line 2 |
| 40 | Synesthesia | `tone: warm` / `tone: sharp` / `tone: deep` — a "color" for your session |
| 41 | Background Texture | Full line pattern: `~-~=~-~=~-~=~-~` — ambient visual |
| 42 | Hue Name | `hue: indigo` — your session's named color |
| 43 | Zoo Mode | Multiple pets, one per project. Portfolio = zoo. |
| 44 | Bonsai | A bonsai you prune by making clean commits |
| 45 | Contextual Fortune | Working on tests? Testing wisdom. Refactoring? Refactoring wisdom. |

## Design Rules

- **Code state = safe** (tests, git, commits) — objective facts
- **User state = risky** (mood, frustration, intent) — subjective attribution
- **No gamification in core** — leave XP/streaks/evolution to community
- **No hardcoded values** — if data isn't available at runtime, don't fake it
- **Network widgets = opt-in only** — document the privacy implications

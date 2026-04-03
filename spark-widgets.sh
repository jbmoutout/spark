#!/bin/bash
# ⚡ Spark — Built-in widget functions
# Each widget prints one line to stdout. Return "ok" to hide (silent when clean).
# Env available: CLAUDE_PROJECT_DIR, STATE_FILE, WIDGET_CONFIG

widget_branch() {
  local branch

  branch=$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && git branch --show-current 2>/dev/null || echo "")
  if [ -z "$branch" ]; then
    echo "no-git"
  else
    echo "git:(${branch})"
  fi
}

widget_diff_weight() {
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || { echo "ok"; return; }
  local stat

  stat=$(git diff HEAD --shortstat 2>/dev/null || git diff --shortstat 2>/dev/null)
  if [ -z "$stat" ]; then
    echo "ok"
  else
    local ins
    local del

    ins=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    del=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
    echo "+${ins:-0}/-${del:-0}"
  fi
}

widget_files_touched() {
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || { echo "0"; return; }
  local total

  total=$(
    {
      git diff HEAD --name-only -z --diff-filter=d 2>/dev/null || true
      git diff --cached --name-only -z --diff-filter=d 2>/dev/null || true
      git ls-files --others --exclude-standard -z 2>/dev/null || true
    } | python3 -c "
import sys
paths = {entry for entry in sys.stdin.buffer.read().split(b'\0') if entry}
print(len(paths))
" 2>/dev/null || echo "0"
  )
  echo "${total} files"
}

widget_prompt_count() {
  local count

  count=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, os
try:
    with open(os.environ['STATE_FILE']) as f: print(json.load(f).get('prompt_count', '?'))
except Exception: print('?')
" 2>/dev/null || echo "?")
  echo "#${count}"
}

widget_session_clock() {
  local elapsed

  elapsed=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, datetime, os
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    start = datetime.datetime.fromisoformat(s['session_start'].replace('Z', '+00:00'))
    now = datetime.datetime.now(datetime.timezone.utc)
    mins = int((now - start).total_seconds() / 60)
    if mins < 60:
        print(f'{mins}min')
    else:
        print(f'{mins // 60}h{mins % 60:02d}m')
except Exception: print('?')
" 2>/dev/null || echo "?")
  echo "$elapsed"
}

widget_tokens() {
  local raw

  raw=$(STATE_FILE="$STATE_FILE" python3 << 'PYEOF'
import json, os
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    inp = s.get('tokens_input', 0)
    out = s.get('tokens_output', 0)
    total = inp + out
    if total == 0:
        print('0 tok')
    elif total < 1000:
        print(f'{total} tok')
    elif total < 1000000:
        print(f'{total // 1000}k tok')
    else:
        print(f'{total / 1000000:.1f}M tok')
except Exception: print('0 tok')
PYEOF
  )
  echo "${raw:-0 tok}"
}

widget_todos() {
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || { echo "0 TODOs"; return; }
  local count

  count=$(
    CLAUDE_PROJECT_DIR="$CLAUDE_PROJECT_DIR" python3 -c "
import os
import re
import subprocess

repo = os.environ['CLAUDE_PROJECT_DIR']
pattern = re.compile(r'TODO|FIXME|HACK', re.IGNORECASE)
paths = set()

for command in (
    ['git', 'diff', 'HEAD', '--name-only', '-z', '--diff-filter=d'],
    ['git', 'diff', '--cached', '--name-only', '-z', '--diff-filter=d'],
    ['git', 'ls-files', '--others', '--exclude-standard', '-z'],
):
    try:
        output = subprocess.check_output(command, cwd=repo, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError as error:
        output = error.output or b''
    for entry in output.split(b'\0'):
        if entry:
            paths.add(os.path.join(repo, os.fsdecode(entry)))

count = 0
for path in paths:
    try:
        with open(path, encoding='utf-8', errors='ignore') as f:
            count += len(pattern.findall(f.read()))
    except OSError:
        continue

print(count)
" 2>/dev/null || echo "0"
  )
  echo "${count:-0} TODOs"
}

widget_secrets() {
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || { echo "ok"; return; }
  local hits

  hits=$(
    {
      git diff --cached --name-only -z --diff-filter=d 2>/dev/null || true
    } | xargs -0 grep -lEi -- '(api[_-]?key|secret[_-]?key|password|token|private[_-]?key)\s*[:=]' 2>/dev/null | wc -l | tr -d ' '
  )
  if [ "${hits:-0}" -gt 0 ]; then
    echo "SECRETS:${hits}"
  else
    echo "ok"
  fi
}

widget_compaction() {
  local flag

  flag=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, os
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    c = s.get('compacted_at_prompt', 0)
    p = s.get('prompt_count', 0)
    if c > 0:
        ago = p - c
        print(f'compacted {ago} prompts ago')
    else:
        print('ok')
except Exception: print('ok')
" 2>/dev/null || echo "ok")
  echo "$flag"
}

widget_model() {
  local model

  model=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, os
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    m = s.get('model', '')
    if not m:
        print('?')
    elif 'opus' in m:
        print('opus')
    elif 'sonnet' in m:
        print('sonnet')
    elif 'haiku' in m:
        print('haiku')
    else:
        print(m.split('-')[1] if '-' in m else m[:12])
except Exception: print('?')
" 2>/dev/null || echo "?")
  echo "$model"
}

widget_env_drift() {
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || { echo "ok"; return; }
  local issues=""

  if [ -f "package.json" ] && command -v node &>/dev/null; then
    local required

    required=$(python3 -c "
import json
try:
    with open('package.json') as f: p = json.load(f)
    print(p.get('engines', {}).get('node', ''))
except Exception: print('')
" 2>/dev/null)
    if [ -n "$required" ]; then
      local actual
      local req_major
      local act_major

      actual=$(node -v 2>/dev/null | tr -d 'v')
      req_major=$(echo "$required" | grep -oE '[0-9]+' | head -1)
      act_major=$(echo "$actual" | grep -oE '^[0-9]+')
      if [ -n "$req_major" ] && [ -n "$act_major" ] && [ "$act_major" -lt "$req_major" ] 2>/dev/null; then
        issues="${issues}node:${act_major} needs ${req_major}"
      fi
    fi
  fi

  if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    if [ -n "$issues" ]; then issues="$issues, "; fi
    issues="${issues}.env missing"
  fi

  if [ -f "docker-compose.yml" ] || [ -f "compose.yml" ]; then
    if ! docker info &>/dev/null 2>&1; then
      if [ -n "$issues" ]; then issues="$issues, "; fi
      issues="${issues}Docker not running"
    fi
  fi

  if [ -n "$issues" ]; then
    echo "$issues"
  else
    echo "ok"
  fi
}

widget_last_session() {
  local info

  info=$(STATE_FILE="$STATE_FILE" python3 << 'PYEOF'
import json, os, datetime
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    last_end = s.get('last_session_end')
    if not last_end:
        print('ok')
        exit()
    last_branch = s.get('last_session_branch', '?')
    last_todos = s.get('last_session_todos', 0)
    end_time = datetime.datetime.fromisoformat(last_end.replace('Z', '+00:00'))
    now = datetime.datetime.now(datetime.timezone.utc)
    ago_mins = int((now - end_time).total_seconds() / 60)
    if ago_mins < 60:
        ago = f'{ago_mins}m ago'
    elif ago_mins < 1440:
        ago = f'{ago_mins // 60}h ago'
    else:
        ago = f'{ago_mins // 1440}d ago'
    parts = [f'last: {ago}', last_branch]
    if last_todos > 0:
        parts.append(f'{last_todos} TODOs')
    print(' / '.join(parts))
except Exception: print('ok')
PYEOF
  )
  echo "${info:-ok}"
}

widget_explored() {
  # How many unique files Claude has explored this session
  local count

  count=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, os
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    n = s.get('files_explored', 0)
    if n == 0:
        print('ok')
    else:
        print(f'explored:{n} files')
except Exception: print('ok')
" 2>/dev/null || echo "ok")
  echo "$count"
}

widget_party() {
  # How many sub-agents Claude spawned this session
  local count

  count=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, os
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    n = s.get('subagents', 0)
    if n == 0:
        print('ok')
    else:
        print(f'{n} sub-agents')
except Exception: print('ok')
" 2>/dev/null || echo "ok")
  echo "$count"
}

widget_plant() {
  # A plant that grows with cumulative session time. Persists across sessions.
  # Stages: . → .: → .| → .|. → .|: → .:|. → .:|: → .:|:. → .:||:. → *:|:*
  local stage

  stage=$(STATE_FILE="$STATE_FILE" python3 << 'PYEOF'
import json, os, datetime
stages = ['', ',', '.:',  '.|', '.|.', '.:|.', '.:|:', '.:|:.', '.:||:.', '*:|:*']
try:
    with open(os.environ['STATE_FILE']) as f: s = json.load(f)
    # Accumulate total minutes across all sessions
    total_mins = s.get('plant_total_mins', 0)
    start = s.get('session_start', '')
    if start:
        st = datetime.datetime.fromisoformat(start.replace('Z', '+00:00'))
        now = datetime.datetime.now(datetime.timezone.utc)
        current_mins = int((now - st).total_seconds() / 60)
        total_mins += current_mins
    # Each stage = ~30 min of cumulative coding (full growth ~5 hours)
    idx = min(total_mins // 30, len(stages) - 1)
    print(stages[idx])
except Exception: print('.')
PYEOF
  )
  echo "${stage:-.}"
}

widget_weather() {
  local weather

  weather=$(STATE_FILE="$STATE_FILE" WIDGET_CONFIG="$WIDGET_CONFIG" python3 << 'PYEOF'
import json, os, urllib.request, datetime

location = os.environ.get('SPARK_WEATHER_LOCATION', '').strip()
if not location:
    print('ok')
    exit()

sf = os.environ.get('STATE_FILE', '')
try:
    with open(sf) as f: state = json.load(f)
except Exception: state = {}

cached = state.get('weather_text', '')
cached_at = state.get('weather_at', '')
if cached and cached_at:
    try:
        t = datetime.datetime.fromisoformat(cached_at.replace('Z', '+00:00'))
        age = (datetime.datetime.now(datetime.timezone.utc) - t).total_seconds()
        if age < 1800:
            print(cached)
            exit()
    except Exception:
        pass

url = f'https://wttr.in/{location}?format=%C+%t'
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'spark-hud'})
    with urllib.request.urlopen(req, timeout=3) as resp:
        text = resp.read().decode('utf-8').strip()
        text = text.replace('  ', ' ').strip()
        # Strip trailing C/F after degree symbol — °C → °
        text = text.replace('°C', '°').replace('°F', '°')
        if text:
            state['weather_text'] = text
            state['weather_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            with open(sf, 'w') as f: json.dump(state, f)
            print(text)
        else:
            print('ok')
except Exception:
    if cached:
        print(cached)
    else:
        print('ok')
PYEOF
  )
  echo "${weather:-ok}"
}

widget_timezone() {
  local tz

  tz=$(WIDGET_CONFIG="$WIDGET_CONFIG" python3 << 'PYEOF'
import json, os, datetime

try:
    cfg = json.loads(os.environ.get('WIDGET_CONFIG', '{}'))
    zones = cfg.get('timezones', [])
except Exception:
    zones = []

if not zones:
    print('ok')
    exit()

parts = []
for tz_name in zones[:3]:
    try:
        from zoneinfo import ZoneInfo
        now = datetime.datetime.now(ZoneInfo(tz_name))
        city = tz_name.split('/')[-1].replace('_', ' ')
        parts.append(f'{city} {now.strftime("%H:%M")}')
    except Exception:
        continue

if parts:
    print(' / '.join(parts))
else:
    print('ok')
PYEOF
  )
  echo "${tz:-ok}"
}

#!/bin/bash
# Spark ⚡ — Stop hook
# Parses transcript to accumulate token usage.

set -euo pipefail

[ -n "${CLAUDE_PROJECT_DIR:-}" ] || { cat > /dev/null; exit 0; }
command -v python3 &>/dev/null || { cat > /dev/null; exit 0; }

SPARK_DIR="$CLAUDE_PROJECT_DIR/.spark"
STATE_FILE="$SPARK_DIR/state.json"
MAX_TRANSCRIPT_BYTES="${SPARK_MAX_TRANSCRIPT_BYTES:-20971520}"

# Skip if no state file
[ -f "$STATE_FILE" ] || { cat > /dev/null; exit 0; }

# Pipe stdin directly to python (avoids env var size limits)
STATE_FILE="$STATE_FILE" MAX_TRANSCRIPT_BYTES="$MAX_TRANSCRIPT_BYTES" python3 -c "
import json, os, stat, sys

inp = sys.stdin.read()
sf = os.environ.get('STATE_FILE', '')
max_transcript_bytes = int(os.environ.get('MAX_TRANSCRIPT_BYTES', '5242880'))

try:
    hook_data = json.loads(inp)
except Exception:
    exit(0)

transcript_path = hook_data.get('transcript_path', '')
if not transcript_path:
    exit(0)

try:
    transcript_stat = os.stat(transcript_path)
except OSError:
    exit(0)

if not stat.S_ISREG(transcript_stat.st_mode):
    exit(0)

if transcript_stat.st_size > max_transcript_bytes:
    exit(0)

# Parse transcript for token usage
total_input = 0
total_output = 0
total_cache_read = 0
total_cache_create = 0

try:
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                # Usage can be at entry.usage or entry.message.usage
                usage = entry.get('usage', {})
                if not usage:
                    msg = entry.get('message', {})
                    if isinstance(msg, dict):
                        usage = msg.get('usage', {})
                if usage:
                    total_input += usage.get('input_tokens', 0)
                    total_output += usage.get('output_tokens', 0)
                    total_cache_read += usage.get('cache_read_input_tokens', usage.get('cache_read_tokens', 0))
                    total_cache_create += usage.get('cache_creation_input_tokens', usage.get('cache_creation_tokens', 0))
            except Exception:
                continue
except Exception:
    exit(0)

# Update state file — tokens only, no pricing
try:
    with open(sf) as f:
        state = json.load(f)
except Exception:
    state = {}

state['tokens_input'] = total_input
state['tokens_output'] = total_output
state['tokens_cache_read'] = total_cache_read
state['tokens_cache_create'] = total_cache_create

# Detect model from last assistant message
last_model = ''
try:
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                msg = entry.get('message', {})
                if isinstance(msg, dict) and msg.get('role') == 'assistant':
                    m = msg.get('model', '')
                    if m:
                        last_model = m
            except Exception:
                continue
except Exception:
    pass
if last_model:
    state['model'] = last_model

# Count files explored and sub-agents from transcript
files_explored = set()
subagents = 0
try:
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                msg = entry.get('message', {})
                if isinstance(msg, dict):
                    for content in msg.get('content', []):
                        if isinstance(content, dict) and content.get('type') == 'tool_use':
                            tool = content.get('name', '')
                            inp = content.get('input', {})
                            if tool in ('Read', 'Grep', 'Glob'):
                                fp = inp.get('file_path', '') or inp.get('path', '')
                                if fp:
                                    files_explored.add(fp)
                            elif tool == 'Agent':
                                subagents += 1
            except Exception:
                continue
except Exception:
    pass

state['files_explored'] = len(files_explored)
state['subagents'] = subagents

# Update plant total minutes (cumulative across sessions)
import datetime, subprocess
now = datetime.datetime.now(datetime.timezone.utc)
start_str = state.get('session_start', '')
if start_str:
    try:
        start = datetime.datetime.fromisoformat(start_str.replace('Z', '+00:00'))
        session_mins = int((now - start).total_seconds() / 60)
        state['plant_total_mins'] = state.get('plant_total_mins', 0) + session_mins
    except Exception:
        pass

# Save session info for last_session widget (persists across sessions)
state['last_session_end'] = now.isoformat()
try:
    branch = subprocess.check_output(
        ['git', 'branch', '--show-current'],
        cwd=os.path.dirname(sf).replace('/.spark', ''),
        stderr=subprocess.DEVNULL
    ).decode().strip()
    if branch:
        state['last_session_branch'] = branch
except Exception:
    pass

try:
    with open(sf, 'w') as f:
        json.dump(state, f)
except Exception:
    pass
" 2>/dev/null || true

exit 0

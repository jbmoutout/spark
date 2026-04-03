#!/bin/bash
# Spark ⚡ — Stop hook
# Parses transcript to accumulate token usage.

set -euo pipefail

[ -n "${CLAUDE_PROJECT_DIR:-}" ] || { cat > /dev/null; exit 0; }
command -v python3 &>/dev/null || { cat > /dev/null; exit 0; }

SPARK_DIR="$CLAUDE_PROJECT_DIR/.spark"
STATE_FILE="$SPARK_DIR/state.json"
MAX_TRANSCRIPT_BYTES="${SPARK_MAX_TRANSCRIPT_BYTES:-5242880}"

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

try:
    with open(sf, 'w') as f:
        json.dump(state, f)
except Exception:
    pass
" 2>/dev/null || true

exit 0

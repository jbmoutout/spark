#!/bin/bash
# Spark ⚡ — Stop hook
# Parses transcript to accumulate token usage.

set -euo pipefail

SPARK_DIR="$CLAUDE_PROJECT_DIR/.spark"
STATE_FILE="$SPARK_DIR/state.json"

# Read hook input from stdin
INPUT=$(cat)

# Skip if no state file
[ -f "$STATE_FILE" ] || exit 0

# Extract transcript path and update tokens in state
INPUT="$INPUT" STATE_FILE="$STATE_FILE" python3 -c "
import json, os

inp = os.environ.get('INPUT', '{}')
sf = os.environ.get('STATE_FILE', '')

try:
    hook_data = json.loads(inp)
except:
    exit(0)

transcript_path = hook_data.get('transcript_path', '')
if not transcript_path:
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
            except:
                continue
except:
    exit(0)

# Update state file — tokens only, no pricing
try:
    with open(sf) as f:
        state = json.load(f)
except:
    state = {}

state['tokens_input'] = total_input
state['tokens_output'] = total_output
state['tokens_cache_read'] = total_cache_read
state['tokens_cache_create'] = total_cache_create

try:
    with open(sf, 'w') as f:
        json.dump(state, f)
except:
    pass
" 2>/dev/null || true

exit 0

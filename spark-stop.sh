#!/bin/bash
# Spark ⚡ — Stop hook
# Parses transcript to accumulate token usage and estimate cost.

set -euo pipefail

SPARK_DIR="$CLAUDE_PROJECT_DIR/.spark"
STATE_FILE="$SPARK_DIR/state.json"

# Read hook input from stdin
INPUT=$(cat)

# Skip if no state file
[ -f "$STATE_FILE" ] || exit 0

# Extract transcript path and update cost in state
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

# Estimate cost (Opus 4.6 pricing as of 2026-04)
# Input: \$15/MTok, Output: \$75/MTok
# Cache read: \$1.50/MTok, Cache write: \$18.75/MTok
cost = (
    (total_input / 1_000_000) * 15.0
    + (total_output / 1_000_000) * 75.0
    + (total_cache_read / 1_000_000) * 1.5
    + (total_cache_create / 1_000_000) * 18.75
)

# Update state file
try:
    with open(sf) as f:
        state = json.load(f)
except:
    state = {}

state['cost_usd'] = round(cost, 2)
state['tokens_input'] = total_input
state['tokens_output'] = total_output

try:
    with open(sf, 'w') as f:
        json.dump(state, f)
except:
    pass
" 2>/dev/null || true

exit 0

#!/bin/bash
# Spark ⚡ — PreCompact hook
# Writes compaction flag to state so the HUD can warn the user.

set -euo pipefail
cat > /dev/null

[ -n "${CLAUDE_PROJECT_DIR:-}" ] || exit 0
command -v python3 &>/dev/null || exit 0

SPARK_DIR="$CLAUDE_PROJECT_DIR/.spark"
STATE_FILE="$SPARK_DIR/state.json"

# Skip if no state file
[ -f "$STATE_FILE" ] || exit 0

STATE_FILE="$STATE_FILE" python3 -c "
import json, os
sf = os.environ['STATE_FILE']
try:
    with open(sf) as f: s = json.load(f)
except Exception: s = {}
s['compacted_at_prompt'] = s.get('prompt_count', 0)
with open(sf, 'w') as f: json.dump(s, f)
" 2>/dev/null || true

exit 0

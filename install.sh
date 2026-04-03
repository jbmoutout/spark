#!/bin/bash
# Spark ⚡ — Install script
# Usage: curl -fsSL https://raw.githubusercontent.com/jbmoutout/spark/main/install.sh | bash

set -euo pipefail

SPARK_REPO="https://raw.githubusercontent.com/jbmoutout/spark/main"
HOOKS_DIR=".claude/hooks"
SETTINGS_FILE=".claude/settings.json"

echo "⚡ Installing Spark..."

# Create hooks directory
mkdir -p "$HOOKS_DIR"

# Download hooks
curl -fsSL "$SPARK_REPO/spark.sh" -o "$HOOKS_DIR/spark.sh"
curl -fsSL "$SPARK_REPO/spark-precompact.sh" -o "$HOOKS_DIR/spark-precompact.sh"
curl -fsSL "$SPARK_REPO/spark-stop.sh" -o "$HOOKS_DIR/spark-stop.sh"
chmod +x "$HOOKS_DIR/spark.sh" "$HOOKS_DIR/spark-precompact.sh" "$HOOKS_DIR/spark-stop.sh"

# Create or update settings.json
if [ -f "$SETTINGS_FILE" ]; then
  # Merge into existing settings
  SETTINGS_FILE="$SETTINGS_FILE" python3 -c "
import json, os

sf = os.environ['SETTINGS_FILE']
with open(sf) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

# Add UserPromptSubmit hook
usp = hooks.setdefault('UserPromptSubmit', [])
spark_entry = {
    'type': 'command',
    'command': '\"' + '\$CLAUDE_PROJECT_DIR' + '\"/.claude/hooks/spark.sh',
    'timeout': 5000
}
already = any('spark.sh' in h.get('command', '') for m in usp for h in m.get('hooks', []))
if not already:
    if usp and 'hooks' in usp[0]:
        usp[0]['hooks'].append(spark_entry)
    else:
        usp.append({'matcher': '.*', 'hooks': [spark_entry]})

# Add PreCompact hook
pc = hooks.setdefault('PreCompact', [])
precompact_entry = {
    'type': 'command',
    'command': '\"' + '\$CLAUDE_PROJECT_DIR' + '\"/.claude/hooks/spark-precompact.sh',
    'timeout': 3000
}
already_pc = any('spark-precompact.sh' in h.get('command', '') for m in pc for h in m.get('hooks', []))
if not already_pc:
    if pc and 'hooks' in pc[0]:
        pc[0]['hooks'].append(precompact_entry)
    else:
        pc.append({'matcher': '.*', 'hooks': [precompact_entry]})

with open(sf, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" 2>/dev/null
  echo "  Updated existing $SETTINGS_FILE"
else
  # Create fresh settings
  cat > "$SETTINGS_FILE" <<'SETTINGS'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/spark.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/spark-precompact.sh",
            "timeout": 3000
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/spark-stop.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
SETTINGS
  echo "  Created $SETTINGS_FILE"
fi

echo "  Downloaded spark.sh + spark-precompact.sh + spark-stop.sh"
echo ""
echo "⚡ Spark installed. Start a Claude Code session to see the HUD."

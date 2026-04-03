#!/bin/bash
# Spark ⚡ — Install script
# Usage: ./install.sh

set -euo pipefail

SPARK_REPO="${SPARK_REPO:-https://raw.githubusercontent.com/jbmoutout/spark/main}"
HOOKS_DIR="${HOOKS_DIR:-.claude/hooks}"
SETTINGS_FILE="${SETTINGS_FILE:-.claude/settings.json}"
SCRIPT_SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
REMOTE_FALLBACK=0

if [ "$(pwd)" = "/" ] || [ "$(pwd)" = "$HOME" ]; then
  echo "⚠️  Refusing to install Spark into $(pwd)."
  echo "   Run this from your project directory instead."
  exit 1
fi

command -v python3 &>/dev/null || {
  echo "❌ python3 is required to update .claude/settings.json." >&2
  exit 1
}

echo "⚡ Installing Spark..."

# Create hooks directory
mkdir -p "$HOOKS_DIR"

install_hook() {
  local hook_name="$1"
  local local_source="$SCRIPT_SOURCE_DIR/$hook_name"
  local destination="$HOOKS_DIR/$hook_name"

  if [ -f "$local_source" ]; then
    cp "$local_source" "$destination"
  else
    REMOTE_FALLBACK=1
    command -v curl &>/dev/null || {
      echo "❌ curl is required when hook files are not available next to install.sh." >&2
      exit 1
    }
    curl -fsSL "$SPARK_REPO/$hook_name" -o "$destination"
  fi

  chmod +x "$destination"
}

install_hook "spark.sh"
install_hook "spark-widgets.sh"
install_hook "spark-precompact.sh"
install_hook "spark-stop.sh"

# Create or update settings.json
SETTINGS_FILE="$SETTINGS_FILE" python3 <<'PY'
import json
import os
import shutil

sf = os.environ['SETTINGS_FILE']
settings = {}
backup = None

if os.path.exists(sf):
    try:
        with open(sf) as f:
            settings = json.load(f)
    except Exception:
        backup = f"{sf}.spark.bak"
        shutil.copyfile(sf, backup)
        settings = {}

hooks = settings.setdefault('hooks', {})
entries = [
    ('UserPromptSubmit', 'spark.sh', 5000),
    ('PreCompact', 'spark-precompact.sh', 3000),
    ('Stop', 'spark-stop.sh', 5000),
]

for event, script_name, timeout in entries:
    matcher_entries = hooks.setdefault(event, [])
    spark_entry = {
        'type': 'command',
        'command': f'"$CLAUDE_PROJECT_DIR"/.claude/hooks/{script_name}',
        'timeout': timeout,
    }
    already = any(
        script_name in hook.get('command', '')
        for matcher in matcher_entries
        for hook in matcher.get('hooks', [])
    )
    if already:
        continue

    appended = False
    for matcher in matcher_entries:
        matcher_hooks = matcher.get('hooks')
        if isinstance(matcher_hooks, list):
            matcher_hooks.append(spark_entry)
            appended = True
            break

    if not appended:
        matcher_entries.append({'matcher': '.*', 'hooks': [spark_entry]})

with open(sf, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

if backup:
    print(f"  Backed up invalid {sf} to {backup}")
PY

if [ "$REMOTE_FALLBACK" -eq 1 ]; then
  echo "  Downloaded hook files from $SPARK_REPO"
  echo "  Prefer a pinned tag or commit when using raw downloads."
else
  echo "  Installed hook files from $SCRIPT_SOURCE_DIR"
fi

echo "  Updated $SETTINGS_FILE"
echo ""
echo "⚡ Spark installed. Start a Claude Code session to see the HUD."

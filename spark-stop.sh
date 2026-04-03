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

PAYLOAD_FILE=$(mktemp "${TMPDIR:-/tmp}/spark-stop-payload.XXXXXX")
trap 'rm -f "$PAYLOAD_FILE"' EXIT

cat > "$PAYLOAD_FILE"

STATE_FILE="$STATE_FILE" MAX_TRANSCRIPT_BYTES="$MAX_TRANSCRIPT_BYTES" PAYLOAD_FILE="$PAYLOAD_FILE" python3 <<'PY' 2>/dev/null || true
import datetime
import json
import os
import stat
from pathlib import Path


def to_int(value):
    try:
        return int(value or 0)
    except Exception:
        return 0


state_path = Path(os.environ["STATE_FILE"])
payload_path = Path(os.environ["PAYLOAD_FILE"])
max_transcript_bytes = to_int(os.environ.get("MAX_TRANSCRIPT_BYTES", "5242880"))

try:
    hook_data = json.loads(payload_path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)

if not isinstance(hook_data, dict):
    raise SystemExit(0)

transcript_path = hook_data.get("transcript_path", "")
if not transcript_path:
    raise SystemExit(0)

try:
    transcript = Path(transcript_path).expanduser().resolve(strict=True)
except OSError:
    raise SystemExit(0)

transcript_stat = transcript.stat()
if not stat.S_ISREG(transcript_stat.st_mode):
    raise SystemExit(0)

if transcript_stat.st_size > max_transcript_bytes:
    raise SystemExit(0)

try:
    state = json.loads(state_path.read_text(encoding="utf-8"))
except Exception:
    state = {}

total_input = 0
total_output = 0
total_cache_read = 0
total_cache_create = 0
files_explored = set()
subagents = 0
last_model = ""

try:
    with transcript.open(encoding="utf-8", errors="ignore") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            try:
                entry = json.loads(line)
            except Exception:
                continue

            msg = entry.get("message", {})
            usage = entry.get("usage", {})
            if (not isinstance(usage, dict) or not usage) and isinstance(msg, dict):
                usage = msg.get("usage", {})

            if isinstance(usage, dict):
                total_input += to_int(usage.get("input_tokens", 0))
                total_output += to_int(usage.get("output_tokens", 0))
                total_cache_read += to_int(
                    usage.get("cache_read_input_tokens", usage.get("cache_read_tokens", 0))
                )
                total_cache_create += to_int(
                    usage.get(
                        "cache_creation_input_tokens",
                        usage.get("cache_creation_tokens", 0),
                    )
                )

            if not isinstance(msg, dict):
                continue

            model = msg.get("model", "")
            if msg.get("role") == "assistant" and isinstance(model, str) and model:
                last_model = model

            content = msg.get("content", [])
            if not isinstance(content, list):
                continue

            for item in content:
                if not isinstance(item, dict) or item.get("type") != "tool_use":
                    continue

                tool = item.get("name", "")
                tool_input = item.get("input", {})
                if tool in ("Read", "Grep", "Glob") and isinstance(tool_input, dict):
                    file_path = tool_input.get("file_path", "") or tool_input.get("path", "")
                    if isinstance(file_path, str) and file_path:
                        files_explored.add(file_path)
                elif tool == "Agent":
                    subagents += 1
except Exception:
    raise SystemExit(0)

state["tokens_input"] = total_input
state["tokens_output"] = total_output
state["tokens_cache_read"] = total_cache_read
state["tokens_cache_create"] = total_cache_create
state["files_explored"] = len(files_explored)
state["subagents"] = subagents
state["last_seen_at"] = datetime.datetime.now(datetime.timezone.utc).strftime(
    "%Y-%m-%dT%H:%M:%SZ"
)

if last_model:
    state["model"] = last_model

with state_path.open("w", encoding="utf-8") as handle:
    json.dump(state, handle)
PY

exit 0

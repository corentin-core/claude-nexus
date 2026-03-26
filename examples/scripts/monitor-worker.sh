#!/usr/bin/env bash
#
# monitor-worker.sh - Monitor a Claude worker via stream-json output
#
# Reads stream-json (NDJSON) from stdin, writes:
#   - Raw JSONL log: $STATUS_DIR/worker-<name>.jsonl
#   - Live status:   $STATUS_DIR/worker-<name>-status.md
#
# Usage: claude -p "..." --output-format stream-json --verbose \
#          | monitor-worker.sh <status-dir> <worker-name>
#
# The status file is updated after every event and contains:
#   - Current state: working / stalled / permission-blocked / done / error
#   - Last activity: tool name + summary of what it's doing
#   - Timestamp of last event
#
# The script also prints a one-line summary to stderr on each tool call,
# so the orchestrator can see live activity if running in foreground.
#
set -euo pipefail

usage() {
    echo "Usage: claude -p ... --output-format stream-json --verbose \\"
    echo "         | $0 <status-dir> <worker-name>"
    echo ""
    echo "Arguments:"
    echo "  status-dir    Directory to write log and status files"
    echo "  worker-name   Identifier for this worker (e.g. repo name)"
    exit 1
}

[[ $# -lt 2 ]] && usage

STATUS_DIR="$1"
WORKER_NAME="$2"
LOG_FILE="$STATUS_DIR/worker-${WORKER_NAME}.jsonl"
STATUS_FILE="$STATUS_DIR/worker-${WORKER_NAME}-status.md"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUMMARIZE="$SCRIPT_DIR/../hooks/summarize-tool.sh"

mkdir -p "$STATUS_DIR"

# --- Helper: write the status file ---
write_status() {
    local state="$1"
    local activity="$2"
    local timestamp="$3"
    local tool_count="$4"
    local turn_count="$5"

    cat > "$STATUS_FILE" <<EOF
---
worker: ${WORKER_NAME}
state: ${state}
last_event: ${timestamp}
tool_calls: ${tool_count}
turns: ${turn_count}
---

## Last activity

${activity}
EOF
}

# --- Main loop ---
state="starting"
activity="Initializing..."
tool_count=0
turn_count=0

write_status "$state" "$activity" "$(date -Iseconds)" "$tool_count" "$turn_count"

while IFS= read -r line; do
    # Append raw event to log
    echo "$line" >> "$LOG_FILE"

    # Parse event type
    event_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
    [[ -z "$event_type" ]] && continue

    timestamp=$(date -Iseconds)

    case "$event_type" in
        system)
            subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)
            if [[ "$subtype" == "init" ]]; then
                state="working"
                activity="Worker initialized"
                turn_count=0
                tool_count=0
            fi
            ;;

        assistant)
            # Check for tool_use or text in content
            has_tool_use=$(echo "$line" | jq -r '.message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null | head -1)

            if [[ -n "$has_tool_use" ]]; then
                # Reformat stream-json tool_use into summarize-tool.sh format
                activity=$(echo "$line" | jq -c '.message.content[] | select(.type == "tool_use") | {tool_name: .name, tool_input: .input}' 2>/dev/null | head -1 | "$SUMMARIZE")
                tool_count=$((tool_count + 1))
                state="working"
                echo "[${WORKER_NAME}] ${activity}" >&2
            else
                has_text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null | head -c 120)
                if [[ -n "$has_text" ]]; then
                    turn_count=$((turn_count + 1))
                    activity="Thinking: ${has_text:0:100}..."
                    state="working"
                fi
            fi
            ;;

        user)
            # Tool result — check for errors and permission denials
            tool_error=$(echo "$line" | jq -r '.message.content[]? | select(.is_error == true) | .content' 2>/dev/null | head -c 200)
            if [[ -n "$tool_error" ]]; then
                if echo "$tool_error" | grep -qi "permission\|denied\|rejected\|user.*doesn.*t.*want\|not.*allowed"; then
                    state="permission-blocked"
                    activity="BLOCKED: ${tool_error:0:150}"
                    echo "⚠️  [${WORKER_NAME}] PERMISSION BLOCKED: ${tool_error:0:100}" >&2
                else
                    activity="Tool error: ${tool_error:0:150}"
                fi
            fi
            ;;

        result)
            is_error=$(echo "$line" | jq -r '.is_error // false' 2>/dev/null)
            if [[ "$is_error" == "true" ]]; then
                state="error"
                result_text=$(echo "$line" | jq -r '.result // "unknown error"' 2>/dev/null | head -c 200)
                activity="Error: ${result_text:0:150}"
                echo "❌ [${WORKER_NAME}] ERROR: ${result_text:0:100}" >&2
            else
                state="done"
                duration=$(echo "$line" | jq -r '.duration_ms // 0' 2>/dev/null)
                duration_sec=$((duration / 1000))
                activity="Completed in ${duration_sec}s (${tool_count} tool calls, ${turn_count} turns)"
                echo "✅ [${WORKER_NAME}] Done in ${duration_sec}s" >&2
            fi
            ;;
    esac

    write_status "$state" "$activity" "$timestamp" "$tool_count" "$turn_count"
done

# If we exit the loop without a result event, something went wrong
if [[ "$state" != "done" && "$state" != "error" ]]; then
    state="error"
    activity="Worker stream ended unexpectedly (state was: ${state})"
    write_status "$state" "$activity" "$(date -Iseconds)" "$tool_count" "$turn_count"
    echo "❌ [${WORKER_NAME}] Stream ended unexpectedly" >&2
fi

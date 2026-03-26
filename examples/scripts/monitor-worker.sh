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

# --- Helpers ---

write_status() {
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

log_stderr() {
    echo "$1" >&2
}

# --- Event handlers ---
# Each handler updates the shared state variables (state, activity, etc.)
# and is called from the main loop's case dispatch.

handle_init() {
    local line="$1"
    local subtype
    subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)
    [[ "$subtype" != "init" ]] && return
    state="working"
    activity="Worker initialized"
    turn_count=0
    tool_count=0
}

handle_assistant() {
    local line="$1"
    local tool_name
    tool_name=$(echo "$line" | jq -r '.message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null | head -1)

    if [[ -n "$tool_name" ]]; then
        activity=$(echo "$line" | jq -c '.message.content[] | select(.type == "tool_use") | {tool_name: .name, tool_input: .input}' 2>/dev/null | head -1 | "$SUMMARIZE")
        tool_count=$((tool_count + 1))
        state="working"
        log_stderr "[${WORKER_NAME}] ${activity}"
        return
    fi

    local text
    text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null | head -c 120)
    if [[ -n "$text" ]]; then
        turn_count=$((turn_count + 1))
        activity="Thinking: ${text:0:100}..."
        state="working"
    fi
}

handle_tool_result() {
    local line="$1"
    local error
    error=$(echo "$line" | jq -r '.message.content[]? | select(.is_error == true) | .content' 2>/dev/null | head -c 200)
    [[ -z "$error" ]] && return

    if echo "$error" | grep -qi "permission\|denied\|rejected\|user.*doesn.*t.*want\|not.*allowed"; then
        state="permission-blocked"
        activity="BLOCKED: ${error:0:150}"
        log_stderr "⚠️  [${WORKER_NAME}] PERMISSION BLOCKED: ${error:0:100}"
    else
        activity="Tool error: ${error:0:150}"
    fi
}

handle_result() {
    local line="$1"
    local is_error
    is_error=$(echo "$line" | jq -r '.is_error // false' 2>/dev/null)

    if [[ "$is_error" == "true" ]]; then
        state="error"
        local result_text
        result_text=$(echo "$line" | jq -r '.result // "unknown error"' 2>/dev/null | head -c 200)
        activity="Error: ${result_text:0:150}"
        log_stderr "❌ [${WORKER_NAME}] ERROR: ${result_text:0:100}"
    else
        state="done"
        local duration duration_sec
        duration=$(echo "$line" | jq -r '.duration_ms // 0' 2>/dev/null)
        duration_sec=$((duration / 1000))
        activity="Completed in ${duration_sec}s (${tool_count} tool calls, ${turn_count} turns)"
        log_stderr "✅ [${WORKER_NAME}] Done in ${duration_sec}s"
    fi
}

# --- Main loop ---
state="starting"
activity="Initializing..."
timestamp=$(date -Iseconds)
tool_count=0
turn_count=0

write_status

while IFS= read -r line; do
    echo "$line" >> "$LOG_FILE"

    event_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
    [[ -z "$event_type" ]] && continue

    timestamp=$(date -Iseconds)

    case "$event_type" in
        system)    handle_init "$line" ;;
        assistant) handle_assistant "$line" ;;
        user)      handle_tool_result "$line" ;;
        result)    handle_result "$line" ;;
    esac

    write_status
done

if [[ "$state" != "done" && "$state" != "error" ]]; then
    state="error"
    activity="Worker stream ended unexpectedly (state was: ${state})"
    timestamp=$(date -Iseconds)
    write_status
    log_stderr "❌ [${WORKER_NAME}] Stream ended unexpectedly"
fi

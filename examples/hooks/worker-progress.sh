#!/usr/bin/env bash
#
# worker-progress.sh - PostToolUse hook for orchestrated workers
#
# Writes a progress entry to the worker status file after each tool call.
# Designed to complement monitor-worker.sh (which reads stream-json).
#
# Required environment variables:
#   WORKER_STATUS_DIR  - Directory containing worker status files
#   WORKER_NAME        - Identifier for this worker (e.g. repo name)
#
# Receives tool call details via stdin as JSON:
#   { "tool_name": "Edit", "tool_input": { "file_path": "..." }, ... }
#
set -euo pipefail

# Skip if env vars not set (not running as orchestrated worker)
[[ -z "${WORKER_STATUS_DIR:-}" || -z "${WORKER_NAME:-}" ]] && exit 0

INPUT=$(cat)
TIMESTAMP=$(date -Iseconds)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
PROGRESS_FILE="${WORKER_STATUS_DIR}/worker-${WORKER_NAME}-progress.md"

# Build a human-readable summary of the tool call
case "$TOOL_NAME" in
    Read)
        file=$(echo "$INPUT" | jq -r '.tool_input.file_path // "?"')
        summary="Reading ${file}"
        ;;
    Edit)
        file=$(echo "$INPUT" | jq -r '.tool_input.file_path // "?"')
        summary="Editing ${file}"
        ;;
    Write)
        file=$(echo "$INPUT" | jq -r '.tool_input.file_path // "?"')
        summary="Writing ${file}"
        ;;
    Bash)
        cmd=$(echo "$INPUT" | jq -r '.tool_input.command // "?"' | head -c 80)
        summary="Running: ${cmd}"
        ;;
    Glob)
        pattern=$(echo "$INPUT" | jq -r '.tool_input.pattern // "?"')
        summary="Searching files: ${pattern}"
        ;;
    Grep)
        pattern=$(echo "$INPUT" | jq -r '.tool_input.pattern // "?"')
        summary="Searching code: ${pattern}"
        ;;
    Skill)
        skill=$(echo "$INPUT" | jq -r '.tool_input.skill // "?"')
        summary="Running skill: ${skill}"
        ;;
    *)
        summary="Using ${TOOL_NAME}"
        ;;
esac

# Append to progress log (append, not overwrite — full history)
echo "- \`${TIMESTAMP}\` ${summary}" >> "$PROGRESS_FILE"

exit 0

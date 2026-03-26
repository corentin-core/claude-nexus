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
PROGRESS_FILE="${WORKER_STATUS_DIR}/worker-${WORKER_NAME}-progress.md"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
summary=$(echo "$INPUT" | "$SCRIPT_DIR/summarize-tool.sh")

# Append to progress log (append, not overwrite — full history)
echo "- \`${TIMESTAMP}\` ${summary}" >> "$PROGRESS_FILE"

exit 0

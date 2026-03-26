#!/usr/bin/env bash
#
# summarize-tool.sh - Produce a one-line summary of a Claude tool call
#
# Reads JSON from stdin with .tool_name and .tool_input fields.
# Prints a human-readable summary to stdout.
#
# Usage: echo "$JSON" | summarize-tool.sh
#
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

case "$TOOL_NAME" in
    Read)
        file=$(echo "$TOOL_INPUT" | jq -r '.file_path // "?"')
        echo "Reading ${file}"
        ;;
    Edit)
        file=$(echo "$TOOL_INPUT" | jq -r '.file_path // "?"')
        echo "Editing ${file}"
        ;;
    Write)
        file=$(echo "$TOOL_INPUT" | jq -r '.file_path // "?"')
        echo "Writing ${file}"
        ;;
    Bash)
        cmd=$(echo "$TOOL_INPUT" | jq -r '.command // "?"' | head -c 80)
        echo "Running: ${cmd}"
        ;;
    Glob)
        pattern=$(echo "$TOOL_INPUT" | jq -r '.pattern // "?"')
        echo "Searching files: ${pattern}"
        ;;
    Grep)
        pattern=$(echo "$TOOL_INPUT" | jq -r '.pattern // "?"')
        echo "Searching code: ${pattern}"
        ;;
    Skill)
        skill=$(echo "$TOOL_INPUT" | jq -r '.skill // "?"')
        echo "Running skill: ${skill}"
        ;;
    Agent|Task)
        desc=$(echo "$TOOL_INPUT" | jq -r '.description // .prompt // "?"' | head -c 80)
        echo "${TOOL_NAME}: ${desc}"
        ;;
    *)
        echo "Using ${TOOL_NAME}"
        ;;
esac

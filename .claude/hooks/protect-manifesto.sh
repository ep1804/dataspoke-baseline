#!/usr/bin/env bash
# Hook: PreToolUse (Edit|Write) — prevent accidental MANIFESTO modifications
set -euo pipefail

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE" == *"MANIFESTO"* ]]; then
  echo "Blocked: MANIFESTO files are highest-priority specs (Priority 1). Modification requires explicit user request." >&2
  exit 2
fi

exit 0

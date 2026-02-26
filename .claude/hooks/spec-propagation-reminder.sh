#!/usr/bin/env bash
# Hook: PostToolUse (Edit|Write) — remind to propagate spec changes through the hierarchy
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ "$FILE" != *"/spec/"* ]] && exit 0

cat <<'MSG'
Spec file modified. Remember: changes must be propagated both upward and downward through the spec hierarchy. Check if ARCHITECTURE.md, USE_CASE_en.md, AI_SCAFFOLD.md, or dependent feature specs need corresponding updates.
MSG
exit 0

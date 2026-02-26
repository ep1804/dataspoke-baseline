#!/usr/bin/env bash
# Hook: PostToolUse (Edit|Write, async) — auto-format Python and TypeScript files
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

case "$FILE" in
  *.py)
    command -v ruff >/dev/null 2>&1 || exit 0
    ruff check --fix "$FILE" 2>/dev/null || true
    ruff format "$FILE" 2>/dev/null || true
    ;;
  *.ts|*.tsx)
    command -v npx >/dev/null 2>&1 || exit 0
    npx prettier --write "$FILE" 2>/dev/null || true
    ;;
esac

exit 0

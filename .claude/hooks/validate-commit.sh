#!/usr/bin/env bash
# Hook: PreToolUse (Bash) — enforce Conventional Commits and block AI authorship trailers
set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ "$CMD" != *"git commit"* ]] && exit 0

# Block Co-Authored-By / Generated-by trailers (CLAUDE.md §Git Commit Convention)
if echo "$CMD" | grep -qiE 'co-authored-by|generated.by'; then
  echo "Blocked: CLAUDE.md forbids AI authorship trailers in commits." >&2
  exit 2
fi

# Validate Conventional Commits format: <type>: <subject>
if echo "$CMD" | grep -qE '^git commit -m'; then
  if ! echo "$CMD" | grep -qE "git commit -m.*(feat|fix|docs|refactor|test|chore):"; then
    echo "Blocked: Use Conventional Commits format — feat:|fix:|docs:|refactor:|test:|chore:" >&2
    exit 2
  fi
fi

exit 0

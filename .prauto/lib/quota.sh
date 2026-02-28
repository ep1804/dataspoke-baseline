# Token quota checking for prauto.
# Source this file — do not execute directly.
# Requires: helpers.sh sourced, claude CLI available.

# Check whether Claude Code API tokens are available.
# Returns 0 if available, 1 if exhausted or auth invalid.
check_quota() {
  # Step 1: Auth validation
  if ! claude auth status >/dev/null 2>&1; then
    warn "Claude auth check failed — credentials may be invalid or expired."
    return 1
  fi

  # Step 2: Minimal dry-run
  local output
  local stderr_file
  stderr_file=$(mktemp)

  if output=$(claude -p "Reply with exactly: OK" \
    --output-format json \
    --max-turns 1 \
    --max-budget-usd 0.01 \
    --allowedTools "" 2>"$stderr_file"); then
    rm -f "$stderr_file"
    return 0
  else
    local stderr_content
    stderr_content=$(cat "$stderr_file" 2>/dev/null || echo "")
    rm -f "$stderr_file"

    if echo "$stderr_content" | grep -qi "rate limit\|quota"; then
      warn "Claude token quota exhausted or rate-limited."
    else
      warn "Claude dry-run failed: $stderr_content"
    fi
    return 1
  fi
}

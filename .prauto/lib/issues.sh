# Issue discovery and claiming for prauto.
# Source this file — do not execute directly.
# Requires: helpers.sh sourced, PRAUTO_GITHUB_REPO, PRAUTO_GITHUB_LABEL_* set, gh CLI available.

# Check if a matching comment already exists (idempotency guard).
# Usage: comment_exists <"issue"|"pr"> <number> <keyword>
# Returns 0 if found, 1 if not found.
comment_exists() {
  local target_type="$1"
  local target_number="$2"
  local keyword="$3"
  local prefix="prauto(${PRAUTO_WORKER_ID}): ${keyword}"

  gh "${target_type}" view "$target_number" \
    -R "$PRAUTO_GITHUB_REPO" \
    --json comments \
    --jq ".comments[] | select(.body | startswith(\"${prefix}\")) | .id" \
  | head -1 | grep -q .
}

# Find the oldest eligible issue labeled prauto:ready.
# Sets FOUND_ISSUE_NUMBER, FOUND_ISSUE_TITLE, FOUND_ISSUE_BODY on success.
# Returns 0 if found, 1 if none.
find_eligible_issue() {
  local issues_json
  issues_json=$(gh issue list \
    -R "$PRAUTO_GITHUB_REPO" \
    --label "$PRAUTO_GITHUB_LABEL_READY" \
    --state open \
    --json number,title,body,labels \
    --limit 50 2>/dev/null) || {
    warn "Failed to list issues from GitHub."
    return 1
  }

  # Filter out issues that already have wip or review labels, sort by number ascending
  local filtered
  filtered=$(echo "$issues_json" | jq -r --arg wip "$PRAUTO_GITHUB_LABEL_WIP" --arg review "$PRAUTO_GITHUB_LABEL_REVIEW" '
    [.[] | select(
      (.labels | map(.name) | index($wip)) == null and
      (.labels | map(.name) | index($review)) == null
    )] | sort_by(.number) | .[0] // empty
  ')

  if [[ -z "$filtered" ]]; then
    info "No eligible issues found with label ${PRAUTO_GITHUB_LABEL_READY}."
    return 1
  fi

  FOUND_ISSUE_NUMBER=$(echo "$filtered" | jq -r '.number')
  FOUND_ISSUE_TITLE=$(echo "$filtered" | jq -r '.title')
  FOUND_ISSUE_BODY=$(echo "$filtered" | jq -r '.body // ""')

  info "Found eligible issue: #${FOUND_ISSUE_NUMBER} — ${FOUND_ISSUE_TITLE}"
  return 0
}

# Claim an issue with optimistic locking.
# Returns 0 on success, 1 if another worker claimed it.
claim_issue() {
  local issue_number="$1"

  # Step 1: Check if prauto:wip is already present
  local current_labels
  current_labels=$(gh issue view "$issue_number" -R "$PRAUTO_GITHUB_REPO" \
    --json labels --jq '.labels[].name' 2>/dev/null)
  if echo "$current_labels" | grep -q "^${PRAUTO_GITHUB_LABEL_WIP}$"; then
    warn "Issue #${issue_number} already has ${PRAUTO_GITHUB_LABEL_WIP} — another worker claimed it."
    return 1
  fi

  # Step 2: Add prauto:wip label
  gh issue edit "$issue_number" -R "$PRAUTO_GITHUB_REPO" \
    --add-label "$PRAUTO_GITHUB_LABEL_WIP" 2>/dev/null || {
    warn "Failed to add ${PRAUTO_GITHUB_LABEL_WIP} label to issue #${issue_number}."
    return 1
  }

  # Step 3: Brief delay then verify no race
  sleep 2
  local wip_comments
  wip_comments=$(gh issue view "$issue_number" -R "$PRAUTO_GITHUB_REPO" \
    --json comments --jq '[.comments[] | select(.body | startswith("prauto(")) | select(.body | contains("Claimed"))] | length' \
    2>/dev/null)

  if [[ "$wip_comments" -gt 0 ]]; then
    warn "Issue #${issue_number} was claimed by another worker during race window."
    return 1
  fi

  # Step 4: Remove prauto:ready, set assignee, post claim comment
  gh issue edit "$issue_number" -R "$PRAUTO_GITHUB_REPO" \
    --remove-label "$PRAUTO_GITHUB_LABEL_READY" \
    --add-assignee "$PRAUTO_GITHUB_ACTOR" 2>/dev/null || true

  if ! comment_exists "issue" "$issue_number" "Claimed"; then
    gh issue comment "$issue_number" -R "$PRAUTO_GITHUB_REPO" \
      --body "prauto(${PRAUTO_WORKER_ID}): Claimed this issue. Starting work." \
      2>/dev/null || warn "Failed to post claim comment on issue #${issue_number}."
  fi

  info "Claimed issue #${issue_number}."
  return 0
}

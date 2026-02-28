# Job state management for prauto.
# Source this file — do not execute directly.
# Requires: helpers.sh sourced, PRAUTO_DIR set, jq available.

STATE_DIR="${PRAUTO_DIR}/state"
LOCK_FILE="${STATE_DIR}/heartbeat.lock"
JOB_FILE="${STATE_DIR}/current-job.json"
HISTORY_DIR="${STATE_DIR}/history"
SESSIONS_DIR="${STATE_DIR}/sessions"

# Ensure state directories exist.
ensure_state_dirs() {
  mkdir -p "$STATE_DIR" "$HISTORY_DIR" "$SESSIONS_DIR"
}

# Acquire PID-based lock. Returns 0 on success, 1 if already locked.
acquire_lock() {
  ensure_state_dirs

  if [[ -f "$LOCK_FILE" ]]; then
    local existing_pid
    existing_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      warn "Another heartbeat is running (PID $existing_pid). Exiting."
      return 1
    fi
    # Stale lock — previous process died
    warn "Removing stale lock file (PID $existing_pid no longer running)."
    rm -f "$LOCK_FILE"
  fi

  echo $$ > "$LOCK_FILE"
  return 0
}

# Release the lock.
release_lock() {
  rm -f "$LOCK_FILE"
}

# Check if an active job exists. Returns 0 if yes.
has_active_job() {
  [[ -f "$JOB_FILE" ]]
}

# Load the current job into shell variables.
# Sets: JOB_ISSUE_NUMBER, JOB_ISSUE_TITLE, JOB_BRANCH, JOB_SOURCE,
#       JOB_PHASE, JOB_SESSION_ID, JOB_RETRIES, JOB_REPLIED_COMMENT_IDS
load_job() {
  if [[ ! -f "$JOB_FILE" ]]; then
    error "No active job file found at $JOB_FILE"
  fi

  JOB_ISSUE_NUMBER=$(jq -r '.issue_number' "$JOB_FILE")
  JOB_ISSUE_TITLE=$(jq -r '.issue_title' "$JOB_FILE")
  JOB_BRANCH=$(jq -r '.branch' "$JOB_FILE")
  JOB_SOURCE=$(jq -r '.source' "$JOB_FILE")
  JOB_PHASE=$(jq -r '.phase' "$JOB_FILE")
  JOB_SESSION_ID=$(jq -r '.session_id // empty' "$JOB_FILE")
  JOB_RETRIES=$(jq -r '.retries // 0' "$JOB_FILE")
  JOB_REPLIED_COMMENT_IDS=$(jq -r '.replied_comment_ids // [] | join(",")' "$JOB_FILE")
}

# Save/create a job state file.
# Usage: save_job <issue_number> <issue_title> <branch> <source> <phase> [session_id]
save_job() {
  local issue_number="$1"
  local issue_title="$2"
  local branch="$3"
  local source="$4"
  local phase="$5"
  local session_id="${6:-}"

  ensure_state_dirs

  jq -n \
    --argjson issue_number "$issue_number" \
    --arg issue_title "$issue_title" \
    --arg branch "$branch" \
    --arg source "$source" \
    --arg phase "$phase" \
    --arg session_id "$session_id" \
    --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg last_heartbeat "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      issue_number: $issue_number,
      issue_title: $issue_title,
      branch: $branch,
      source: $source,
      phase: $phase,
      session_id: (if $session_id == "" then null else $session_id end),
      started_at: $started_at,
      retries: 0,
      last_heartbeat: $last_heartbeat,
      replied_comment_ids: []
    }' > "$JOB_FILE"
}

# Update specific fields in the current job.
# Usage: update_job_field <field> <value>
update_job_field() {
  local field="$1"
  local value="$2"

  if [[ ! -f "$JOB_FILE" ]]; then
    error "No active job to update"
  fi

  local tmp
  tmp=$(mktemp)
  jq --arg field "$field" --arg value "$value" '.[$field] = $value' "$JOB_FILE" > "$tmp"
  mv "$tmp" "$JOB_FILE"
}

# Update last_heartbeat timestamp and increment retries.
bump_heartbeat() {
  if [[ ! -f "$JOB_FILE" ]]; then
    error "No active job to bump"
  fi

  local tmp
  tmp=$(mktemp)
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.last_heartbeat = $ts | .retries += 1' "$JOB_FILE" > "$tmp"
  mv "$tmp" "$JOB_FILE"
}

# Append a comment ID to replied_comment_ids.
add_replied_comment_id() {
  local comment_id="$1"

  if [[ ! -f "$JOB_FILE" ]]; then
    error "No active job to update"
  fi

  local tmp
  tmp=$(mktemp)
  jq --arg id "$comment_id" '.replied_comment_ids += [$id]' "$JOB_FILE" > "$tmp"
  mv "$tmp" "$JOB_FILE"
}

# Move current job to history.
complete_job() {
  if [[ ! -f "$JOB_FILE" ]]; then
    warn "No active job to complete."
    return 0
  fi

  local issue_number
  issue_number=$(jq -r '.issue_number' "$JOB_FILE")
  local date_prefix
  date_prefix=$(date +%Y%m%d)
  local history_file="${HISTORY_DIR}/${date_prefix}_I-${issue_number}.json"

  mv "$JOB_FILE" "$history_file"
  info "Job for issue #${issue_number} completed → ${history_file}"
}

# Abandon a job after max retries.
# Moves state to history, updates labels, posts comment.
abandon_job() {
  if [[ ! -f "$JOB_FILE" ]]; then
    warn "No active job to abandon."
    return 0
  fi

  load_job

  # Step 1: Move state file first (critical step)
  local date_prefix
  date_prefix=$(date +%Y%m%d)
  local history_file="${HISTORY_DIR}/${date_prefix}_I-${JOB_ISSUE_NUMBER}.json"
  mv "$JOB_FILE" "$history_file"
  info "Job for issue #${JOB_ISSUE_NUMBER} abandoned → ${history_file}"

  # Step 2: Update labels
  gh issue edit "$JOB_ISSUE_NUMBER" -R "$PRAUTO_GITHUB_REPO" \
    --remove-label "$PRAUTO_GITHUB_LABEL_WIP" \
    --add-label "$PRAUTO_GITHUB_LABEL_FAILED" 2>/dev/null || \
    warn "Failed to update labels on issue #${JOB_ISSUE_NUMBER}"

  # Step 3: Post comment (with idempotency check)
  if ! comment_exists "issue" "$JOB_ISSUE_NUMBER" "Abandoning"; then
    gh issue comment "$JOB_ISSUE_NUMBER" -R "$PRAUTO_GITHUB_REPO" \
      --body "prauto(${PRAUTO_WORKER_ID}): Abandoning after ${JOB_RETRIES} retries. Manual intervention needed." \
      2>/dev/null || warn "Failed to post abandonment comment on issue #${JOB_ISSUE_NUMBER}"
  fi
}

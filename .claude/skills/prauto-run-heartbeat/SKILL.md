---
name: prauto-run-heartbeat
description: Test-run the prauto heartbeat script and monitor its progress. Diagnoses and fixes script errors on failure.
allowed-tools: Bash(env *), Bash(which *), Bash(date *), Bash(test *), Read, Edit, Glob, Grep
---

## Overview

Test-runs `.prauto/heartbeat.sh` inside a Claude Code session and monitors its execution.
Two separate concerns run simultaneously:

| # | Concern | Auth context | What it does |
|---|---------|-------------|--------------|
| 1 | **Heartbeat execution** | `.prauto/config.local.env` (GH_TOKEN, git author) | The heartbeat script runs as a background subprocess. It loads its own credentials and spawns nested Claude CLI invocations. |
| 2 | **Monitoring & fixing** | Local Claude session (your auth) | This Claude session watches the output, diagnoses errors, fixes scripts, and re-runs. |

Because the heartbeat spawns `claude` CLI internally, the `CLAUDECODE` env var must be unset to avoid the nested-run limit.

---

## Step 1 — Pre-flight checks

1. Verify `.prauto/config.local.env` exists: `test -f .prauto/config.local.env`
   - Do **NOT** read its contents — it contains secrets (GH_TOKEN, ANTHROPIC_API_KEY).
   - If missing, tell the user to create it from `.prauto/config.local.env.example` and stop.
2. Verify `.prauto/heartbeat.sh` exists and is executable.
3. Check for stale lock: if `.prauto/state/heartbeat.lock` exists, warn the user that another heartbeat may be running. Ask whether to proceed or abort.
4. Verify required CLI tools are available: `which claude && which gh && which git && which jq`

---

## Step 2 — Run heartbeat

Execute the heartbeat in the **background**:

```bash
env -u CLAUDECODE bash -x .prauto/heartbeat.sh 2>&1
```

Key points:
- `env -u CLAUDECODE` — **required** to avoid nested-run limit (the heartbeat internally invokes `claude` CLI).
- `bash -x` — enables trace output for monitoring.
- `2>&1` — merges stderr (trace) with stdout for unified output.

Note the background task ID for monitoring.

---

## Step 3 — Monitor progress

Poll the background task output every **~20 seconds** until exit.

For each check:
1. Read the latest output from the background task.
2. Parse `bash -x` trace lines (`+ command ...`) to identify progress:
   - Lock acquired / config loaded
   - Token quota check
   - Issue discovery / claiming
   - Analysis phase start / completion
   - Implementation phase start / completion
   - PR creation / push
   - Squash-finalize
3. Watch for `[INFO]`, `[WARN]`, and `[ERROR]` markers from the script's logging.
4. **Redact secrets**: The `bash -x` trace may print env var values (GH_TOKEN, ANTHROPIC_API_KEY). When summarizing output to the user, **never** include token/key values — replace them with `[REDACTED]`.
5. Summarize progress concisely to the user.

### Key milestones to report

| Log marker | Meaning |
|-----------|---------|
| `Lock acquired` | Script started |
| `Config loaded (worker: ...)` | Credentials loaded |
| `GitHub actor: ...` | GH_TOKEN auth works |
| `Token quota available` | Claude auth works |
| `No work to do` | Nothing to process |
| `Starting analysis phase` | Phase 1 began |
| `Claude invocation completed` | Nested Claude finished |
| `Starting implementation phase` | Phase 2 began |
| `Squash-finalizing approved PR` | Phase 4 began |
| `Heartbeat complete` | Script finished successfully |

---

## Step 4 — Handle outcome

### On success (exit code 0)

Report a completion summary:
- What action the heartbeat took (claimed issue, resumed job, squash-finalized PR, no work to do, etc.)
- Total duration
- Any warnings encountered during execution

### On failure (non-zero exit code)

Perform up to **3 retry cycles**:

1. **Diagnose**: Read the full error output. Find the failing command in the `bash -x` trace (the last `+` line before the error).
2. **Locate**: Map the error to a source file in `.prauto/` — typically one of:
   - `heartbeat.sh` — main orchestrator
   - `lib/helpers.sh` — logging, config loading
   - `lib/state.sh` — job state, locking
   - `lib/quota.sh` — token quota
   - `lib/issues.sh` — issue discovery, claiming
   - `lib/claude.sh` — Claude CLI invocation
   - `lib/git-ops.sh` — git/PR operations
   - `prompts/*.md` — prompt templates
3. **Analyze**: Read the relevant source file. Understand the root cause.
4. **Fix**: Edit the source file to resolve the issue.
   - **NEVER modify `.prauto/config.local.env`** — if the error is credentials/config-related, report to user and stop.
   - **NEVER modify `.prauto/config.env`** unless it's clearly a bug in the shared config (not a config value issue).
5. **Re-run**: Launch the heartbeat again:
   ```bash
   env -u CLAUDECODE bash -x .prauto/heartbeat.sh 2>&1
   ```
   The re-run **automatically** uses credentials from `.prauto/config.local.env` — no manual credential handling needed.
6. **Monitor**: Return to Step 3.

If all 3 retries fail with the same or new errors, report the persistent failure and suggest manual intervention.

---

## Step 5 — Final report

```
## Heartbeat Test Run — <timestamp>

**Status**: Success / Failed (after N retries)
**Action taken**: <what the heartbeat did>
**Duration**: <total elapsed time>

### Execution log
<brief chronological summary of key events>

### Fixes applied (if any)
- `<file>:<line>` — <description of fix>

### Errors (if unresolved)
- <error description>
- <suggested manual fix>
```

---

## Constraints

- **Never read `.prauto/config.local.env`** — contains GH_TOKEN and ANTHROPIC_API_KEY.
- **Redact secrets** in all output shown to user — `bash -x` traces may expose env var values.
- **Always use `env -u CLAUDECODE`** for every heartbeat invocation, including retries after fixes.
- The heartbeat is idempotent (PID-based locking). Multiple runs are safe — a concurrent run will simply exit if another holds the lock.
- If the lock file is stale (process no longer running), the script handles this automatically.

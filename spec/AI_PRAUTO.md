# Prauto: Autonomous PR Worker

> **Document Status**: Specification v0.1 (2026-02-28)
> This document specifies "prauto" — an autonomous PR worker that monitors GitHub issues, writes code via Claude Code CLI, and submits pull requests. Prauto extends the AI scaffold (`spec/AI_SCAFFOLD.md`) with unattended, cron-driven development automation.

---

## Table of Contents

1. [Overview](#overview)
2. [Directory Structure](#directory-structure)
3. [Worker Identity and Configuration](#worker-identity-and-configuration)
4. [Heartbeat Cycle](#heartbeat-cycle)
5. [Token Quota Checking](#token-quota-checking)
6. [Job State Machine](#job-state-machine)
7. [Issue Discovery Protocol](#issue-discovery-protocol)
8. [Claude Code Invocation](#claude-code-invocation)
9. [PR Lifecycle](#pr-lifecycle)
10. [Prompt Templates](#prompt-templates)
11. [Security Model](#security-model)
12. [Integration with AI Scaffold](#integration-with-ai-scaffold)
13. [Future: GitHub Actions Migration](#future-github-actions-migration)

---

## Overview

### What prauto is

Prauto is a cron-triggered bash-based worker that automates the issue-to-PR pipeline. Each heartbeat, it:

1. Checks whether Claude Code API tokens are available
2. Resumes any interrupted job from a prior heartbeat
3. Finds an eligible GitHub issue via label-based discovery
4. Invokes Claude Code CLI to analyze the issue and implement changes
5. Creates or updates a pull request with the results

### Relationship to `claude-code-action`

Anthropic's [`claude-code-action`](https://github.com/anthropics/claude-code-action) is a GitHub Action that embeds Claude Code into CI/CD workflows. It runs exclusively on GitHub Actions runners — it has no local execution mode.

Prauto uses the **Claude Code CLI** (`claude -p`), which is the same underlying engine. The CLI supports all features needed for autonomous operation: non-interactive print mode (`-p`), session resumption (`--resume`), structured output (`--output-format json`), tool restrictions (`--allowedTools`, `--disallowedTools`), budget caps (`--max-budget-usd`), and turn limits (`--max-turns`).

The prompt templates and tool restrictions designed here are portable to `claude-code-action` via its `claude_args` input (see [Future: GitHub Actions Migration](#future-github-actions-migration)).

### Execution environment

Prauto runs on a local developer machine. It requires:

- `claude` CLI (Claude Code) installed and authenticated
- `gh` CLI (GitHub CLI) installed and authenticated
- `git` configured for the repository
- `jq` for JSON processing
- `cron` (or equivalent scheduler) for heartbeat triggering

Docker, Kubernetes, and cloud runner deployments are out of scope for v1 and will be addressed in a future revision.

---

## Directory Structure

```
.prauto/
├── config.env                  # [COMMITTED] Worker identity, GitHub settings, Claude limits
├── config.local.env            # [GITIGNORED] Secrets: ANTHROPIC_API_KEY, GH_TOKEN
├── heartbeat.sh                # [COMMITTED] Main cron entry point
├── lib/
│   ├── helpers.sh              # [COMMITTED] Shared bash helpers (info, warn, error)
│   ├── quota.sh                # [COMMITTED] Token quota check
│   ├── issues.sh               # [COMMITTED] GitHub issue scanning and claiming
│   ├── claude.sh               # [COMMITTED] Claude Code CLI invocation wrapper
│   ├── git-ops.sh              # [COMMITTED] Branch creation, push, PR lifecycle
│   └── state.sh                # [COMMITTED] Job state management (lock, resume, complete)
├── prompts/
│   ├── system-append.md        # [COMMITTED] System prompt addendum for prauto identity
│   ├── issue-analysis.md       # [COMMITTED] Prompt template: analyze issue, produce plan
│   └── implementation.md       # [COMMITTED] Prompt template: implement the plan
├── state/                      # [GITIGNORED] Runtime state
│   ├── current-job.json        # Active job metadata
│   ├── heartbeat.lock          # PID-based lock file
│   ├── heartbeat.log           # Cron output log
│   ├── history/                # Completed job summaries (YYYYMMDD_I-NNN.json)
│   └── sessions/               # Claude session outputs for potential resume
└── README.md                   # [COMMITTED] Setup and usage instructions
```

### Gitignore additions

Two lines appended to the repository root `.gitignore`:

```
.prauto/config.local.env
.prauto/state/
```

---

## Worker Identity and Configuration

### `config.env` — committed configuration

```bash
# Identity
PRAUTO_WORKER_ID="prauto01"
PRAUTO_GIT_AUTHOR_NAME="prauto01"
PRAUTO_GIT_AUTHOR_EMAIL="prauto01@dataspoke.local"

# GitHub
PRAUTO_GITHUB_REPO="ep1804/dataspoke-baseline"
PRAUTO_GITHUB_LABEL_READY="prauto:ready"
PRAUTO_GITHUB_LABEL_WIP="prauto:wip"
PRAUTO_GITHUB_LABEL_DONE="prauto:done"
PRAUTO_GITHUB_LABEL_FAILED="prauto:failed"
PRAUTO_BASE_BRANCH="dev"
PRAUTO_BRANCH_PREFIX="prauto/"

# Claude Code CLI
PRAUTO_CLAUDE_MODEL="sonnet"
PRAUTO_CLAUDE_MAX_TURNS_ANALYSIS=10
PRAUTO_CLAUDE_MAX_TURNS_IMPLEMENTATION=50
PRAUTO_CLAUDE_MAX_BUDGET_ANALYSIS="0.50"
PRAUTO_CLAUDE_MAX_BUDGET_IMPLEMENTATION="2.00"

# Limits
PRAUTO_HEARTBEAT_INTERVAL_MINUTES=15
PRAUTO_MAX_RETRIES_PER_JOB=3
```

### `config.local.env` — secrets (gitignored)

```bash
# Never commit this file
ANTHROPIC_API_KEY="sk-ant-..."
GH_TOKEN="ghp_..."
```

The `GH_TOKEN` is a fine-grained personal access token with these permissions on the target repository:

| Permission | Access | Used for |
|------------|--------|----------|
| Issues | Read/Write | List, label, comment on issues |
| Pull requests | Read/Write | Create PRs, comment on PRs |
| Contents | Write | Push branches |

### Worker identity in git

All commits made during a prauto session use the worker identity:

```bash
git commit --author="${PRAUTO_GIT_AUTHOR_NAME} <${PRAUTO_GIT_AUTHOR_EMAIL}>"
```

The `PRAUTO_WORKER_ID` also appears in issue/PR comments to identify which worker instance produced the output.

---

## Heartbeat Cycle

The heartbeat is the top-level control flow executed by `heartbeat.sh` on each cron trigger.

```
crontab trigger
    │
    ├── 1. Acquire lock ──────────── (prevent concurrent runs)
    │       └── if locked → exit
    │
    ├── 2. Load config ───────────── (config.env + config.local.env)
    │
    ├── 3. Check token quota ─────── (lib/quota.sh)
    │       └── if exhausted → exit
    │
    ├── 4. Resume interrupted job ── (lib/state.sh)
    │       ├── if active job exists → resume from saved phase
    │       └── if completed or no job → continue
    │
    ├── 5. Find eligible issue ───── (lib/issues.sh)
    │       └── if none found → exit
    │
    ├── 6. Claim issue ───────────── (add prauto:wip label, comment)
    │
    ├── 7. Create branch ─────────── (lib/git-ops.sh)
    │
    ├── 8. Phase 1: Analysis ─────── (lib/claude.sh, read-only)
    │
    ├── 9. Phase 2: Implementation ─ (lib/claude.sh, read+write)
    │
    ├── 10. Create/update PR ──────── (lib/git-ops.sh)
    │
    ├── 11. Complete job ──────────── (lib/state.sh)
    │
    └── 12. Release lock
```

### Bash conventions

All scripts follow the project's established patterns from `dev_env/`:

- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail`
- Location: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- Shared helpers sourced from `lib/helpers.sh` (`info()`, `warn()`, `error()`)
- Idempotent operations where possible

### Cron setup

```bash
# Run heartbeat every 15 minutes, Mon-Fri 9:00-18:00 KST
*/15 9-18 * * 1-5 cd /path/to/dataspoke-baseline && .prauto/heartbeat.sh >> .prauto/state/heartbeat.log 2>&1
```

---

## Token Quota Checking

There is no dedicated Anthropic API endpoint to query remaining token balance from the CLI. Prauto uses a two-step probe:

### Step 1: Auth validation

```bash
claude auth status
```

Exits 0 if authenticated, non-zero if auth is invalid or expired.

### Step 2: Minimal dry-run

```bash
claude -p "Reply with exactly: OK" \
  --output-format json \
  --max-turns 1 \
  --max-budget-usd 0.01 \
  --allowedTools ""
```

This costs negligible tokens. If the call fails with a rate-limit or quota error, the heartbeat exits cleanly to wait for the next cycle. The specific error pattern checked is `rate limit` or `quota` in stderr.

### Behavior on exhaustion

When quota is exhausted:

- If no active job: exit cleanly. Next heartbeat retries.
- If mid-job: save current state (phase, session ID, retry count) and exit. Next heartbeat resumes.

---

## Job State Machine

### State file: `state/current-job.json`

```json
{
  "issue_number": 42,
  "issue_title": "Implement health check endpoint",
  "branch": "prauto/I-42",
  "phase": "implementation",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "started_at": "2026-02-28T10:00:00Z",
  "retries": 0,
  "last_heartbeat": "2026-02-28T10:15:00Z"
}
```

### Phases

```
(no job) ──→ analysis ──→ implementation ──→ pr ──→ (complete)
                │               │            │
                └───────────────┴────────────┴──→ (interrupted)
                                                      │
                                    next heartbeat ←───┘
```

| Phase | Description | On interruption |
|-------|-------------|-----------------|
| `analysis` | Claude reads issue + codebase, produces a plan | Restart analysis from scratch |
| `implementation` | Claude writes code, runs tests, commits | Resume via `claude --resume <session_id>` |
| `pr` | Push branch, create/update PR, comment | Retry PR creation |

### Resume logic

When a heartbeat finds `current-job.json`:

1. Read `phase`, `session_id`, `retries`
2. If `retries >= PRAUTO_MAX_RETRIES_PER_JOB`: abandon job, comment on issue, apply `prauto:failed` label
3. Increment `retries`, update `last_heartbeat`
4. Resume from the saved phase:
   - `analysis`: re-run analysis from scratch (analysis is cheap)
   - `implementation`: if `session_id` exists, use `claude --resume <session_id>`; otherwise start fresh
   - `pr`: retry PR creation/push

### Job completion

On successful PR creation:

1. Move `current-job.json` to `state/history/YYYYMMDD_I-{number}.json`
2. Update issue labels: remove `prauto:wip`, add `prauto:done`

### Job abandonment

After max retries:

1. Comment on issue: "prauto({worker_id}): Abandoning after {n} retries. Manual intervention needed."
2. Update issue labels: remove `prauto:wip`, add `prauto:failed`
3. Move job file to history

---

## Issue Discovery Protocol

### Label-based discovery

Prauto uses GitHub labels to track issue lifecycle. No GitHub bot account is required — labels are visible to all team members and controllable by anyone with triage access.

### Label lifecycle

```
[human adds prauto:ready]
    │
    ├── prauto claims → removes prauto:ready, adds prauto:wip
    │       │
    │       ├── success → removes prauto:wip, adds prauto:done
    │       └── failure → removes prauto:wip, adds prauto:failed
    │
    └── (no prauto pickup yet → stays prauto:ready)
```

### Search priority

```bash
gh issue list \
  -R "$PRAUTO_GITHUB_REPO" \
  --label "$PRAUTO_GITHUB_LABEL_READY" \
  --state open \
  --json number,title,body,labels
```

Filter results to exclude issues already labeled `prauto:wip` or `prauto:done`. Sort by issue number ascending (oldest first) and take the first match.

### Claiming an issue

1. Remove label `prauto:ready`
2. Add label `prauto:wip`
3. Post comment: `prauto({worker_id}): Claimed this issue. Starting work.`

### Issue body conventions

For best results, issues should include:

- A clear description of what needs to be done
- References to relevant spec files (e.g., "See `spec/feature/API.md` section X")
- Acceptance criteria or expected behavior
- File paths if the scope is known

Prauto can work with minimal issue descriptions but produces better results with structured context.

---

## Claude Code Invocation

### Two-phase execution model

Prauto splits each job into two Claude Code sessions with different tool permissions:

| Phase | Purpose | Tools | Budget | Max turns |
|-------|---------|-------|--------|-----------|
| Analysis | Read codebase, understand issue, produce plan | Read-only | $0.50 | 10 |
| Implementation | Write code, run tests, commit | Read + Write + limited Bash | $2.00 | 50 |

### CLI invocation pattern

```bash
claude -p "<prompt>" \
  --append-system-prompt-file ".prauto/prompts/system-append.md" \
  --model "$PRAUTO_CLAUDE_MODEL" \
  --output-format json \
  --max-turns <limit> \
  --max-budget-usd <limit> \
  --allowedTools <whitelist> \
  --disallowedTools <denylist> \
  --dangerously-skip-permissions
```

### Tool whitelists by phase

**Phase 1 — Analysis (read-only)**:

```
Read, Glob, Grep,
Bash(git log *), Bash(git diff *), Bash(git status *), Bash(git branch *)
```

**Phase 2 — Implementation (read + write)**:

```
Read, Write, Edit, Glob, Grep,
Bash(git log *), Bash(git diff *), Bash(git status *), Bash(git branch *),
Bash(git add *), Bash(git commit *),
Bash(pytest *), Bash(python3 *),
Bash(npm run *), Bash(npx prettier *), Bash(npx tsc *),
Bash(ruff *)
```

### Tool denylist (both phases)

```
Bash(git push *), Bash(rm -rf *), Bash(sudo *),
Bash(kubectl *), Bash(helm *),
Bash(curl *), Bash(wget *),
WebFetch, WebSearch
```

**Rationale**:

- **No git push**: only `git-ops.sh` pushes, preventing Claude from pushing to unexpected remotes or branches
- **No network**: prevents data exfiltration and uncontrolled API calls
- **No cluster ops**: prauto works on code, not infrastructure
- **No destructive shell**: aligned with the project's "never destroy" principle

### Why `--dangerously-skip-permissions`

In non-interactive (`-p`) mode, Claude Code cannot prompt for tool approval. The `--dangerously-skip-permissions` flag is required. However, the combination of `--allowedTools` (explicit whitelist) and `--disallowedTools` (explicit denylist) ensures Claude can only use approved tools. This is the unattended equivalent of the project's `settings.json` permission model.

### Session resumption

When a job is interrupted mid-implementation:

1. The Claude session output (JSON) is saved to `state/sessions/impl-I-{number}.json`
2. The session ID is extracted and stored in `current-job.json`
3. On resume, Claude is invoked with `--resume <session_id>` plus a continuation prompt

```bash
claude --resume "$SESSION_ID" \
  -p "Continue the implementation. Check what has been done so far and pick up where you left off." \
  --output-format json \
  --max-turns "$PRAUTO_CLAUDE_MAX_TURNS_IMPLEMENTATION" \
  --max-budget-usd "$PRAUTO_CLAUDE_MAX_BUDGET_IMPLEMENTATION" \
  --allowedTools <implementation whitelist> \
  --disallowedTools <denylist> \
  --dangerously-skip-permissions
```

---

## PR Lifecycle

### Branch naming

```
prauto/I-{issue_number}
```

Example: issue #42 produces branch `prauto/I-42`.

### Branch creation

```bash
git fetch origin "$PRAUTO_BASE_BRANCH"
git checkout -b "prauto/I-${ISSUE_NUMBER}" "origin/${PRAUTO_BASE_BRANCH}"
```

### Push and PR creation

After implementation completes, `git-ops.sh` handles:

1. **Push**: `git push -u origin prauto/I-{number}`
2. **Check for existing PR**: `gh pr list --head prauto/I-{number}`
3. **Create PR** (if none exists):

```bash
gh pr create \
  -R "$PRAUTO_GITHUB_REPO" \
  --base "$PRAUTO_BASE_BRANCH" \
  --head "prauto/I-${ISSUE_NUMBER}" \
  --title "prauto: ${ISSUE_TITLE}" \
  --body "<generated PR body>"
```

4. **Update PR** (if exists): push new commits and add a comment

### PR body format

```markdown
## Summary

Automated implementation for #{issue_number}.
Generated by `prauto({worker_id})` using Claude Code CLI.

## Changes

<commit log: git log --oneline origin/{base}..HEAD>

## Test plan

- [ ] Review automated changes
- [ ] Verify tests pass in CI
- [ ] Check spec compliance

---
*Generated by prauto -- autonomous PR worker*
```

### PR review handling

When prauto encounters an issue that already has an open PR (from a previous heartbeat):

1. Read PR comments via `gh pr view --json comments`
2. Include PR review comments in the Claude prompt as context
3. If the PR is waiting for a human reviewer's response (no actionable feedback): exit, nothing to do
4. If there are reviewer comments with change requests: apply them in the implementation phase
5. Post a short reply comment after addressing feedback

---

## Prompt Templates

### `prompts/system-append.md` — Worker identity

Appended to Claude Code's default system prompt via `--append-system-prompt-file`. This preserves all built-in capabilities while adding prauto-specific constraints.

```markdown
## Prauto Worker Identity

You are operating as an autonomous PR worker named `{PRAUTO_WORKER_ID}` for the DataSpoke project.
You are NOT in an interactive session. Complete your work independently.

### Constraints
- Do NOT ask questions or wait for user input. Make reasonable decisions.
- Do NOT push to git. Stage and commit; the orchestrator handles pushing.
- Follow the commit convention: `<type>: <subject>` (Conventional Commits).
- Keep commits concise: 1-line subject, max 3-line body if needed.
- Read the spec hierarchy before coding (per CLAUDE.md instructions).
- Follow existing code patterns in the repository.
- Run tests after changes to verify correctness.
- If blocked, commit what you have with a clear TODO comment.

### Git identity
Use: git commit --author="{PRAUTO_GIT_AUTHOR_NAME} <{PRAUTO_GIT_AUTHOR_EMAIL}>"
```

Variables are substituted at runtime by `lib/claude.sh`.

### `prompts/issue-analysis.md` — Phase 1

```markdown
Analyze the following GitHub issue and produce an implementation plan.

## Issue #{number}: {title}

{body}

## Instructions

1. Read the DataSpoke spec hierarchy to understand context:
   - `spec/MANIFESTO_en.md` for product identity
   - `spec/ARCHITECTURE.md` for system architecture
   - Relevant feature specs in `spec/feature/` or `spec/feature/spoke/`
2. Examine the current codebase to understand what exists.
3. Produce an implementation plan:
   - Files to create or modify
   - Order of changes
   - Existing patterns to follow
   - Tests needed
   - Risks or open questions

Do NOT make code changes. Analysis only.
```

### `prompts/implementation.md` — Phase 2

```markdown
Implement changes for GitHub issue #{number} on branch `{branch}`.

## Instructions

1. Follow the implementation plan from the analysis phase (provided below).
2. Read relevant specs before writing code.
3. Follow existing code patterns.
4. Write tests for your changes.
5. Run tests to verify (pytest for Python, npx tsc for TypeScript).
6. Run formatters (ruff for Python, npx prettier for TypeScript).
7. Stage and commit with conventional commit messages.
   Use: git commit --author="{author_name} <{author_email}>"
8. Do NOT push. The orchestrator handles pushing.

## Analysis Output

{analysis_output}
```

---

## Security Model

### Principle: Least privilege for autonomous operation

| Layer | Restriction | Mechanism |
|-------|-------------|-----------|
| Claude CLI tools | Phase-specific whitelists | `--allowedTools` / `--disallowedTools` |
| Network access | No web fetch, curl, wget | Disallowed tools |
| Cluster access | No kubectl, helm | Disallowed tools |
| Destructive ops | No rm -rf, sudo | Disallowed tools |
| Git push | Only orchestrator pushes | Disallowed for Claude; `git-ops.sh` handles it |
| Budget | Per-job dollar cap | `--max-budget-usd` |
| Turn limit | Per-job turn cap | `--max-turns` |
| Concurrency | One job at a time | PID-based lock file |
| GitHub access | Fine-grained PAT | Scoped to issues, PRs, contents only |
| Secrets | Gitignored local env | `config.local.env` never committed |

### Why Claude cannot push

Separating "write code" from "push to remote" is a deliberate safety boundary. Claude commits locally; the bash orchestrator decides whether and where to push. This prevents Claude from pushing to unexpected branches or remotes, even if a prompt injection attempts to override instructions.

### Secrets isolation

- `config.local.env` is gitignored and never read by Claude (Claude's tool whitelist does not include `Bash(cat .prauto/*)`)
- `ANTHROPIC_API_KEY` is set in the shell environment by `heartbeat.sh` before invoking `claude`
- `GH_TOKEN` is used only by `gh` CLI calls in the bash scripts, not passed to Claude

---

## Integration with AI Scaffold

### What prauto uses from `.claude/`

| Scaffold element | Integration |
|---|---|
| `CLAUDE.md` | Claude reads this automatically, giving prauto full project context |
| `.claude/settings.json` hooks | `auto-format.sh` fires after Write/Edit in prauto sessions |
| `.claude/agents/` | Prauto prompts can instruct Claude to delegate to existing subagents |
| `.claude/skills/` | Skills are available if Claude detects matching context |
| `spec/` hierarchy | Analysis phase reads specs per CLAUDE.md instructions |

### What prauto does NOT modify

| Element | Reason |
|---|---|
| `.claude/settings.json` | Prauto uses CLI flags for tool restrictions |
| `.claude/settings.local.json` | Prauto has its own config |
| `.claude/agents/` | No new subagents added |
| `.claude/commands/` | Prauto is not a Claude Code command |

### Coexistence

Prauto is self-contained in `.prauto/`. The only changes to existing files are two lines in `.gitignore`. The scaffold and prauto operate independently: the scaffold serves interactive Claude Code sessions; prauto serves unattended cron-driven automation. Both use the same Claude Code engine, the same `CLAUDE.md` context, and the same auto-format hook.

---

## Future: GitHub Actions Migration

When the project adds `.github/workflows/`, prauto's design maps directly to `claude-code-action`:

| Prauto (local) | `claude-code-action` (GH Actions) |
|---|---|
| `heartbeat.sh` (cron) | `schedule:` trigger in workflow YAML |
| `lib/issues.sh` (gh CLI) | `issues: [labeled]` event trigger |
| `prompts/system-append.md` | `claude_args: --append-system-prompt-file` |
| `prompts/implementation.md` | `prompt:` input |
| `--allowedTools` / `--disallowedTools` | `claude_args: --allowedTools ...` |
| `--max-turns`, `--max-budget-usd` | `claude_args: --max-turns ... --max-budget-usd ...` |
| `config.env` | Workflow environment variables |
| `config.local.env` | GitHub Actions secrets |
| `lib/git-ops.sh` (gh pr create) | Built-in: claude-code-action creates branches and provides PR prefill links |

The prompt templates in `.prauto/prompts/` and the tool restrictions can be reused without modification. The main difference is that `claude-code-action` does not create PRs directly (it provides prefill links), so the GH Actions version would use a separate workflow step for `gh pr create`.

### Migration path

1. Create `.github/workflows/prauto.yml` with `schedule:` and `issues:` triggers
2. Move secrets to GitHub Actions secrets
3. Reference `.prauto/prompts/` for prompt content
4. Use `claude-code-action` with `claude_args` mirroring the CLI flags from `config.env`
5. Keep `.prauto/` scripts as the local development/testing path

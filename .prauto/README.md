# Prauto — Autonomous PR Worker

Prauto is a cron-driven bash worker that monitors GitHub issues labeled `prauto:ready`, invokes Claude Code CLI to analyze and implement changes, and submits pull requests.

See `spec/AI_PRAUTO.md` for the full specification.

## Prerequisites

- `claude` CLI installed and authenticated
- `gh` CLI installed and authenticated (fine-grained PAT with Issues, PRs, Contents permissions)
- `git` configured for the repository
- `jq` for JSON processing

## Setup

1. Copy the instance config template:

   ```bash
   cp .prauto/config.local.env.example .prauto/config.local.env
   ```

2. Edit `.prauto/config.local.env` with your worker identity, Claude model, and secrets.

3. Add a cron entry (adjust the path and schedule):

   ```bash
   # Run heartbeat every 30 minutes, Mon-Fri 9:00-18:00 KST
   */30 9-18 * * 1-5 cd /path/to/dataspoke-baseline && .prauto/heartbeat.sh >> .prauto/state/heartbeat.log 2>&1
   ```

## Directory Structure

```
.prauto/
├── config.env                  # [COMMITTED] Shared settings
├── config.local.env            # [GITIGNORED] Instance-specific settings
├── heartbeat.sh                # [COMMITTED] Main cron entry point
├── lib/
│   ├── helpers.sh              # Shared bash helpers
│   ├── quota.sh                # Token quota check
│   ├── issues.sh               # Issue scanning and claiming
│   ├── claude.sh               # Claude Code CLI wrapper
│   ├── git-ops.sh              # Branch, push, PR lifecycle
│   └── state.sh                # Job state management
├── prompts/
│   ├── system-append.md        # Worker identity prompt
│   ├── issue-analysis.md       # Phase 1: analysis prompt
│   └── implementation.md       # Phase 2: implementation prompt
├── state/                      # [GITIGNORED] Runtime state
│   ├── current-job.json        # Active job metadata
│   ├── heartbeat.lock          # PID-based lock file
│   ├── heartbeat.log           # Cron output log
│   ├── history/                # Completed job summaries
│   └── sessions/               # Claude session outputs
└── README.md
```

## How It Works

Each heartbeat performs at most one job:

1. Acquires a PID-based lock (prevents concurrent runs)
2. Loads config and checks Claude token quota
3. Resumes any interrupted job from a prior heartbeat
4. Checks open PRs for reviewer comments to address
5. Finds an eligible issue (oldest with `prauto:ready` label)
6. Claims the issue (optimistic lock via label swap)
7. Runs Phase 1: Analysis (read-only Claude session)
8. Runs Phase 2: Implementation (read+write Claude session)
9. Pushes branch and creates/updates PR

## Label Lifecycle

```
[human adds prauto:ready]
    ├── prauto claims → removes prauto:ready, adds prauto:wip
    │       ├── success → removes prauto:wip, adds prauto:review
    │       └── failure → removes prauto:wip, adds prauto:failed
    └── (no prauto pickup yet → stays prauto:ready)
```

## Manual Run

```bash
cd /path/to/dataspoke-baseline
.prauto/heartbeat.sh
```

## Troubleshooting

- **Lock issues**: Check `.prauto/state/heartbeat.lock` — if the PID is stale, delete the file.
- **Job stuck**: Check `.prauto/state/current-job.json` for the current phase and retry count.
- **Logs**: Check `.prauto/state/heartbeat.log` for cron output.
- **Session history**: Check `.prauto/state/sessions/` for Claude session outputs.

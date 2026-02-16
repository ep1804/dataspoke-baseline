# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **specification repository** for DataSpoke — a sidecar extension to DataHub that adds semantic search, data quality monitoring, custom ingestion, and metadata health features. The repo contains architecture specs, manifestos, use cases, and local dev environment setup. No application source code exists yet.

## Local Dev Environment (DataHub on Kubernetes)

All scripts live in `dev_env/` and use settings from `dev_env/.env`:

```bash
# Edit cluster settings before first use
# DATASPOKE_KUBE_CLUSTER, DATASPOKE_KUBE_DATAHUB_NAMESPACE, DATASPOKE_KUBE_DATASPOKE_NAMESPACE

# Install everything (takes 5–10 min on first run)
cd dev_env && ./install.sh

# Uninstall everything
cd dev_env && ./uninstall.sh

# Verify installation
kubectl get pods -n $DATASPOKE_KUBE_DATAHUB_NAMESPACE
helm list -n $DATASPOKE_KUBE_DATAHUB_NAMESPACE
```

For accessing the DataHub UI and example data sources, see `dev_env/README.md` §Quick Start or run `dev_env/datahub-port-forward.sh`.

Helm chart versions are set in `dev_env/.env` (`DATASPOKE_DEV_KUBE_DATAHUB_PREREQUISITES_CHART_VERSION`, `DATASPOKE_DEV_KUBE_DATAHUB_CHART_VERSION`). Current pins: `datahub-prerequisites@0.2.1`, `datahub@0.8.3` (app `v1.4.0`).

## Architecture Overview

DataSpoke is a **loosely coupled sidecar** to DataHub. DataHub is deployed separately (externally in production, locally via the scripts above for dev/testing).

**Planned stack** (from `spec/ARCHITECTURE.md`):

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js + TypeScript |
| API | FastAPI (Python 3.11+) |
| Vector DB | Qdrant |
| Message Broker | Kafka (shared with DataHub) |
| Orchestration | Temporal (preferred) or Airflow |
| Operational DB | PostgreSQL |
| Cache | Redis |
| DataHub integration | `acryl-datahub` Python SDK |

**Planned source layout** (from spec, not yet created):
```
src/frontend/   — Next.js app
src/api/        — FastAPI routers, schemas, middleware
src/backend/    — Services: ingestion, quality, self_purifier, knowledge_base, context_verifier
src/workflows/  — Temporal workflows
src/shared/     — DataHub client wrappers, shared models
api/            — Standalone OpenAPI 3.0 spec (API-first design)
helm-charts/    — Kubernetes deployment
```

**DataHub integration patterns** (read `spec/ARCHITECTURE.md` §Data Flow):
- **Read**: DataHub GraphQL API + Kafka MCE/MAE consumer
- **Write**: `acryl-datahub` Python SDK via `DatahubRestEmitter`
- DataHub = source of truth for metadata persistence; DataSpoke = computational/analysis layer

**Planned dev commands** (from spec appendix, Makefile not yet created):
```bash
make dev-up       # Start all services locally
make dev-down     # Stop all services
make test         # Run all tests
make lint         # Run linters (ruff for Python, ESLint for TS)
alembic upgrade head  # Apply DB migrations
```

## Key Design Decisions

- **API-first**: OpenAPI specs live in `api/` as standalone artifacts so AI agents and frontend can iterate without a running backend
- **Temporal over Airflow**: better for long-running workflows, easier testing; use Airflow only if existing infrastructure demands it
- **Qdrant over Pinecone**: self-hostable, Rust-based performance; consider Weaviate only for multi-tenancy requirements
- **PostgreSQL over MongoDB**: ACID guarantees for ingestion configs, quality results, health scores

## Spec Documents

The `spec/` directory is hierarchical. **`MANIFESTO_en.md` / `MANIFESTO_kr.md` are the highest authority** — all naming, feature taxonomy, and product identity derive from them.

```
spec/
├── MANIFESTO_en.md / MANIFESTO_kr.md  ← Highest authority. Never modify.
├── ARCHITECTURE.md                     ← System-wide architecture overview.
├── AI_SCAFFOLD.md                      ← Claude Code scaffold: Goal 2 of the project.
├── USE_CASE.md                         ← Conceptual scenarios (vision/ideation).
├── feature/                            ← Deep-dive specs for MAJOR features.
│   │                                     Timeless reference format. No dates/logs.
│   └── <FEATURE>.md
└── plan/                               ← Specs for MINOR changes and decisions.
    │                                     Chronological log style, newest-first.
    └── <TOPIC>.md
```

- `spec/MANIFESTO_en.md` / `spec/MANIFESTO_kr.md` — product philosophy, canonical feature taxonomy
- `spec/ARCHITECTURE.md` — full system architecture, component designs, data flows, deployment
- `spec/USE_CASE.md` — conceptual scenarios (vision/ideation, not implementation specs)
- `spec/feature/` — detailed specs per major feature (Ingestion, Quality Control, Self-Purifier, Knowledge Base & Verifier)
- `spec/plan/` — chronological implementation plans and minor decision logs
- `dev_env/README.md` — local Kubernetes setup details

## Git Commit Convention

- Use Conventional Commits format: `<type>: <subject>` (e.g. `feat:`, `fix:`, `docs:`, `refactor:`)
- Body is optional. If included, write **no more than 3 lines**.
- Do **not** add AI authorship lines (no `Co-Authored-By`, no `Generated by` trailers).

## Claude Code Configuration (`.claude/`)

### Skills — invoked with `/skill-name` or auto-triggered by Claude

Skills live in `.claude/skills/`. Claude loads them automatically when the context matches, or you can invoke them explicitly.

| Skill | Invocation | Purpose |
|-------|-----------|---------|
| `kubectl` | `/kubectl <operation>` | Run kubectl/helm operations against the local cluster; reads `dev_env/.env` for context and namespaces. User-invoked only. |
| `monitor-k8s` | `/monitor-k8s [focus]` | Full cluster health report (pods, events, Helm releases). Runs in a forked subagent. |
| `plan-doc` | `/plan-doc <topic>` | Write spec documents routed to the correct tier: `spec/feature/` for major feature deep-dives (timeless reference format), `spec/plan/` for minor changes and decisions (chronological log style). |

### Commands — user-invoked workflows

Commands live in `.claude/commands/`. Invoke them explicitly with `/command-name`.

| Command | Invocation | Purpose |
|---------|-----------|---------|
| `dataspoke-dev-env-install` | `/dataspoke-dev-env-install` | End-to-end dev environment setup: configure `.env`, preflight checks, run `install.sh`, monitor progress, report access details. |
| `dataspoke-dev-env-uninstall` | `/dataspoke-dev-env-uninstall` | Tear down the dev environment: show current state, confirm with user, run `uninstall.sh`, clean up orphaned PVs. |

### Subagents — Claude delegates automatically based on task context

| Agent | When Claude uses it |
|-------|-------------------|
| `api-spec` | Designing or writing OpenAPI 3.0 specs in `api/` |
| `frontend` | Implementing Next.js/TypeScript features in `src/frontend/` |
| `backend` | Implementing FastAPI/Python services in `src/api/`, `src/backend/`, `src/workflows/`, `src/shared/` |
| `k8s-helm` | Writing Helm charts, Dockerfiles, or dev env scripts |

`frontend` and `backend` subagents use `memory: project` — they accumulate patterns, module locations, and architectural decisions in `.claude/agent-memory/` across sessions.

### Permissions (`.claude/settings.json`)

Read-only kubectl, helm, git, and docker commands are auto-allowed. Mutating commands (apply, install, rollout) prompt for confirmation. `kubectl delete namespace`, `rm -rf`, and `sudo` are always blocked.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **specification repository** for DataSpoke — a sidecar extension to DataHub that provides user-group-specific features for Data Engineers (DE), Data Analysts (DA), and Data Governance personnel (DG). The repo contains architecture specs, manifestos, use cases, and local dev environment setup. No application source code exists yet.

## Local Dev Environment (DataHub on Kubernetes)

All scripts live in `dev_env/` and use settings from `dev_env/.env`:

```bash
# Edit cluster settings before first use
# DATASPOKE_DEV_KUBE_CLUSTER, DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE, DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE

# Install infrastructure (takes 5–10 min on first run)
cd dev_env && ./install.sh

# Uninstall everything
cd dev_env && ./uninstall.sh

# Verify installation
kubectl get pods -n $DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE
helm list -n $DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE
```

The dev environment installs only **infrastructure dependencies** (DataHub, PostgreSQL, Redis, Qdrant, Temporal, example data sources) into the cluster. DataSpoke application services (frontend, API, workers) run locally on the host via `make dev-up`, connecting to port-forwarded infrastructure.

Environment variables use two tiers: `DATASPOKE_DEV_*` for dev-only settings (cluster, namespaces, chart versions, port-forward ports) and `DATASPOKE_*` for application runtime config (same names in dev and prod, different values).

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

**System components** (from MANIFESTO): UI → API → Backend/Pipeline + DataHub

**API URI pattern** (three-tier):
```
/api/v1/spoke/common/…       # Common features shared across user groups
/api/v1/spoke/[de|da|dg]/…   # User-group-specific features
/api/v1/hub/…                # DataHub pass-through (optional ingress for clients)
```

**Planned source layout** (from spec, not yet created):
```
src/frontend/   — Next.js app (portal-style UI with DE/DA/DG entry points)
src/api/        — FastAPI routers (per user group), schemas, middleware
src/backend/    — Feature service implementations (detail in spec/feature/ specs)
src/workflows/  — Temporal workflows
src/shared/     — DataHub client wrappers, shared models
api/            — Standalone OpenAPI 3.0 spec (API-first design)
helm-charts/    — Kubernetes deployment
ref/            — External source code for AI reference (version-locked to dev_env)
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

- **DataHub-backed SSOT**: DataHub stores metadata; DataSpoke extends without modifying core
- **API Convention Compliance**: All REST APIs must follow `spec/API_DESIGN_PRINCIPLE_en.md` — covers URI structure, request/response format, content/metadata separation, meta-classifiers (`attrs`, `methods`, `events`), and query parameter conventions
- **API-first**: OpenAPI specs live in `api/` as standalone artifacts so AI agents and frontend can iterate without a running backend
- **Three-tier API routing**: `/spoke/common/` for shared features, `/spoke/[de|da|dg]/` for user-group features, `/hub/` for DataHub pass-through
- **Temporal over Airflow**: better for long-running workflows, easier testing; use Airflow only if existing infrastructure demands it
- **Qdrant over Pinecone**: self-hostable, Rust-based performance; consider Weaviate only for multi-tenancy requirements
- **PostgreSQL over MongoDB**: ACID guarantees for ingestion configs, quality results, health scores

## Spec Documents

The `spec/` directory is hierarchical. Specs should not contradict each other — when any document changes, propagate the change both upward and downward through the hierarchy. The priority order (highest first):

| Priority | Documents | Role |
|----------|-----------|------|
| 1 (highest) | `MANIFESTO_en.md` / `MANIFESTO_kr.md` | Product identity, user-group taxonomy. Never modify unless explicitly requested. |
| 2 | `API_DESIGN_PRINCIPLE_en/kr.md`, `DATAHUB_INTEGRATION.md` | Binding conventions for all APIs and DataHub interactions. |
| 3 | `ARCHITECTURE.md`, `USE_CASE_en/kr.md` | System-wide architecture and conceptual scenarios. |
| 4 | `AI_SCAFFOLD.md` | Claude Code scaffold and AI-assisted development guidelines. |
| 5 | `feature/<FEATURE>.md` | Deep-dive specs for common (cross-cutting) features. |
| 6 | `feature/spoke/<FEATURE>.md` | Deep-dive specs for user-group-specific features. |
| 7 (lowest) | `impl/YYYYMMDD_<topic>.md` | Chronological implementation plans and logs. |

Propagation stops at `spec/impl/` — these are logs of past work. When an upstream change invalidates an impl document, either delete it or mark it as deprecated.

When both English (`_en.md`) and Korean (`_kr.md`) versions exist, they carry the same meaning. Read only the English version unless explicitly directed to read or modify a specific language version. When writing Korean documents, use the plain style (-다/-한다) instead of the polite honorific style (-입니다/-합니다).

**Reference when implementing**: `DATAHUB_INTEGRATION.md` for any DataHub interaction; `API_DESIGN_PRINCIPLE_en.md` for any API design.

Use `/dataspoke-plan-write` to author new specs. It guides scope selection, gathers requirements through Q&A, reviews a writing plan, writes the document (via `plan-doc` conventions), and recommends AI scaffold updates.

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
| `plan-doc` | `/plan-doc <topic>` | Writing engine for spec documents: routes to `spec/feature/`, `spec/feature/spoke/`, or `spec/impl/` with template and style conventions. Used directly for quick writes; called internally by `dataspoke-plan-write` for guided authoring. |
| `datahub-api` | `/datahub-api <task>` | Answer DataHub data model questions (Q&A mode) or write/test Python code against the local DataHub instance (Code Writer mode). Auto-triggered on DataHub API tasks. |

### Commands — user-invoked workflows

Commands live in `.claude/commands/`. Invoke them explicitly with `/command-name`.

| Command | Invocation | Purpose |
|---------|-----------|---------|
| `dataspoke-dev-env-install` | `/dataspoke-dev-env-install` | End-to-end dev environment setup: configure `.env`, preflight checks, run `install.sh`, monitor progress, report access details. |
| `dataspoke-dev-env-uninstall` | `/dataspoke-dev-env-uninstall` | Tear down the dev environment: show current state, confirm with user, run `uninstall.sh`, clean up orphaned PVs. |
| `dataspoke-ref-setup-all` | `/dataspoke-ref-setup-all` | Download all AI reference materials: run `ref/setup.sh` in background and monitor until complete. |
| `dataspoke-plan-write` | `/dataspoke-plan-write` | Guided spec authoring: scope selection → iterative Q&A → writing plan review → document writing (via plan-doc conventions) → AI scaffold recommendations. |

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

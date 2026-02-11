# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **specification repository** for DataSpoke — a sidecar extension to DataHub that adds semantic search, data quality monitoring, custom ingestion, and metadata health features. The repo contains architecture specs, manifestos, use cases, and local dev environment setup. No application source code exists yet.

## Local Dev Environment (DataHub on Kubernetes)

All scripts live in `dev_env/` and use settings from `dev_env/.env`:

```bash
# Edit cluster settings before first use
# DATASPOKE_DEV_KUBE_CONTEXT, DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE, DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE

# Install DataHub (takes 5–10 min on first run)
cd dev_env/datahub && ./install.sh

# Uninstall DataHub
cd dev_env/datahub && ./uninstall.sh

# Access DataHub UI (credentials: datahub/datahub)
kubectl port-forward --namespace datahub \
  $(kubectl get pods -n datahub -l 'app.kubernetes.io/name=datahub-frontend' -o jsonpath='{.items[0].metadata.name}') \
  9002:9002
# → http://localhost:9002

# Verify installation
kubectl get pods -n datahub
helm list -n datahub
```

Pinned Helm chart versions: `datahub-prerequisites@0.2.1`, `datahub@0.8.3` (app `v1.4.0`).

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
src/backend/    — Services: ingestion, quality, search, metadata
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

- `spec/ARCHITECTURE.md` — full system architecture, component designs, data flows, deployment
- `spec/USE_CASE.md` — conceptual scenarios (vision/ideation, not implementation specs)
- `spec/MANIFESTO_en.md` / `spec/MANIFESTO_kr.md` — product philosophy
- `dev_env/README.md` — local Kubernetes setup details

# DataSpoke

AI-powered sidecar extension for [DataHub](https://datahubproject.io/) — provides user-group-specific features for Data Engineers (DE), Data Analysts (DA), and Data Governance personnel (DG).

DataSpoke is a **loosely coupled sidecar** to DataHub. DataHub stores metadata (the Hub); DataSpoke extends it with quality scoring, semantic search, ontology construction, and metrics dashboards (the Spokes).

## Architecture

```
┌───────────────────────────────────────────────┐
│                 DataSpoke UI                  │
│         Portal: DE / DA / DG entry points     │
└───────────────────────┬───────────────────────┘
                        │
┌───────────────────────▼───────────────────────┐
│                DataSpoke API                  │
│   /spoke/common/  /spoke/de|da|dg/  /hub/     │
└───────────┬───────────────────────┬───────────┘
            │                       │
┌───────────▼───────────┐ ┌────────▼────────────┐
│       DataHub         │ │      DataSpoke      │
│    (metadata SSOT)    │ │  Backend / Workers  │
│                       │ │  + Infrastructure   │
└───────────────────────┘ └─────────────────────┘
```

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js + TypeScript |
| API | FastAPI (Python 3.11+) |
| Vector DB | Qdrant |
| Orchestration | Temporal |
| Operational DB | PostgreSQL |
| Cache | Redis |
| DataHub integration | `acryl-datahub` Python SDK + Kafka |

## Getting Started

### Prerequisites

- **kubectl** installed and configured
- **Helm** v3 installed
- A local Kubernetes cluster (Docker Desktop, minikube, or kind) with **8+ CPUs / 16 GB RAM**
- **Node.js** 18+ and **Python** 3.11+ (for running app services locally)

### 1. Set Up the Dev Environment

The dev environment installs **infrastructure dependencies** (DataHub, PostgreSQL, Redis, Qdrant, Temporal, example data sources) into a local Kubernetes cluster. DataSpoke app services run on your host machine.

```bash
# Configure your cluster
cp dev_env/.env.example dev_env/.env
# Edit dev_env/.env — set DATASPOKE_DEV_KUBE_CLUSTER to your context name

# Install everything (~5-10 min first run)
cd dev_env && ./install.sh
```

> Using Claude Code? Just run `/dataspoke-dev-env-install`.

### 2. Start Port-Forwarding

```bash
# DataHub UI + GMS API
dev_env/datahub-port-forward.sh

# DataSpoke infrastructure (PostgreSQL, Redis, Qdrant, Temporal)
dev_env/dataspoke-port-forward.sh
```

| Service | URL | Credentials |
|---------|-----|-------------|
| DataHub UI | http://localhost:9002 | `datahub` / `datahub` |
| DataHub GMS | http://localhost:9004 | — |
| PostgreSQL | localhost:9201 | per `dev_env/.env` |
| Redis | localhost:9202 | per `dev_env/.env` |
| Qdrant | localhost:9203 (HTTP), :9204 (gRPC) | — |
| Temporal | localhost:9205 | — |

### 3. Run DataSpoke App Services

```bash
# Load environment variables
source dev_env/.env

# Frontend (Next.js dev server)
cd src/frontend && npm run dev          # http://localhost:3000

# API (FastAPI)
cd src/api && uvicorn main:app --reload --port 8000

# Workers (Temporal worker)
cd src/workflows && python -m worker

# Or (when Makefile is available):
make dev-up
```

The app reads `DATASPOKE_*` env vars from `dev_env/.env` — all pointing to `localhost` where port-forwarding connects to the in-cluster infrastructure.

### 4. Verify

```bash
source dev_env/.env
kubectl get pods -n $DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE
kubectl get pods -n $DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE
kubectl get pods -n $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE
```

### Uninstall

```bash
cd dev_env && ./uninstall.sh
```

## Production Deployment

DataSpoke ships as an umbrella Helm chart at `helm-charts/dataspoke/`. It packages all application services (frontend, API, workers) and infrastructure dependencies (PostgreSQL, Redis, Qdrant, Temporal) into a single installable unit.

### Prerequisites

- A Kubernetes cluster with DataHub already deployed
- Helm v3
- Container images built and pushed to your registry

### Install

```bash
# Add dependency chart repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add qdrant https://qdrant.github.io/qdrant-helm
helm repo add temporal https://go.temporal.io/helm-charts
helm repo update

# Update chart dependencies
helm dependency update helm-charts/dataspoke/

# Install with production values
helm upgrade --install dataspoke helm-charts/dataspoke/ \
  -n dataspoke --create-namespace \
  --set config.datahub.gmsUrl="http://datahub-gms.datahub.svc.cluster.local:8080" \
  --set config.datahub.kafkaBrokers="datahub-kafka.datahub.svc.cluster.local:9092" \
  --set secrets.postgres.user="dataspoke" \
  --set secrets.postgres.password="$PG_PASSWORD" \
  --set secrets.redis.password="$REDIS_PASSWORD" \
  --set secrets.llm.apiKey="$LLM_API_KEY"
```

### Configuration

All runtime config uses `DATASPOKE_*` environment variables, injected via Helm values into ConfigMaps and Secrets:

```yaml
# custom-values.yaml
config:
  datahub:
    gmsUrl: "https://datahub.company.com"
    kafkaBrokers: "kafka-1:9092,kafka-2:9092"
  llm:
    provider: "gemini"
    model: "gemini-2.0-flash"

frontend:
  ingress:
    enabled: true
    hosts:
      - host: dataspoke.company.com
        paths:
          - path: /
            pathType: Prefix

api:
  ingress:
    enabled: true
    hosts:
      - host: api.dataspoke.company.com
        paths:
          - path: /api
            pathType: Prefix
```

```bash
helm upgrade --install dataspoke helm-charts/dataspoke/ \
  -n dataspoke \
  -f custom-values.yaml \
  -f production-secrets.yaml
```

For production secrets management (External Secrets Operator, Vault, etc.), see [spec/feature/HELM_CHART.md](spec/feature/HELM_CHART.md#secrets-management).

### Dev vs Production Profile

| | Dev (`values-dev.yaml`) | Production (`values.yaml`) |
|---|---|---|
| Frontend, API, Workers | Disabled (run on host) | Enabled (in-cluster) |
| PostgreSQL, Redis, Qdrant, Temporal | Single replica, reduced resources | Production resources, HA optional |
| Ingress | Disabled (port-forward) | Enabled |
| Secrets | Manual (`dev_env/.env`) | K8s Secrets / External Secrets Operator |
| Memory budget | ~2.8 Gi (infra only) | ~17 Gi (full stack) |

## Environment Variables

Two-tier naming convention:

| Prefix | Scope | Who reads it |
|--------|-------|-------------|
| `DATASPOKE_DEV_*` | Dev environment only | `dev_env/*.sh` scripts |
| `DATASPOKE_*` (no `DEV`) | Application runtime | DataSpoke app code |

Key application variables (same names in dev and prod):

| Variable | Purpose |
|----------|---------|
| `DATASPOKE_DATAHUB_GMS_URL` | DataHub GMS endpoint |
| `DATASPOKE_POSTGRES_HOST` / `_PORT` / `_USER` / `_PASSWORD` / `_DB` | Operational database |
| `DATASPOKE_REDIS_HOST` / `_PORT` / `_PASSWORD` | Cache |
| `DATASPOKE_QDRANT_HOST` / `_HTTP_PORT` / `_GRPC_PORT` | Vector database |
| `DATASPOKE_TEMPORAL_HOST` / `_PORT` / `_NAMESPACE` | Workflow orchestration |
| `DATASPOKE_LLM_PROVIDER` / `_API_KEY` / `_MODEL` | LLM integration |

See [spec/feature/DEV_ENV.md](spec/feature/DEV_ENV.md#configuration) for the full variable listing.

## Repository Structure

```
dataspoke-baseline/
├── api/                    # Standalone OpenAPI 3.0 specs (API-first design)
├── dev_env/                # Local Kubernetes dev environment scripts
│   ├── .env                # All settings (gitignored)
│   ├── install.sh / uninstall.sh
│   ├── datahub/            # DataHub Helm install
│   ├── dataspoke-infra/    # DataSpoke infrastructure (PG, Redis, Qdrant, Temporal)
│   └── dataspoke-example/  # Example data sources (PG, Kafka)
├── helm-charts/dataspoke/  # Umbrella Helm chart (dev + production)
├── spec/                   # Architecture and feature specifications
│   ├── MANIFESTO_en.md     # Product identity (highest authority)
│   ├── ARCHITECTURE.md     # System architecture
│   ├── feature/            # Feature specs (DEV_ENV, HELM_CHART, etc.)
│   └── feature/spoke/      # User-group-specific feature specs
├── src/
│   ├── frontend/           # Next.js app
│   ├── api/                # FastAPI routers
│   ├── backend/            # Feature service implementations
│   ├── workflows/          # Temporal workflows
│   └── shared/             # DataHub client, shared models
└── ref/                    # External source for AI reference (gitignored)
```

## Documentation

| Document | Purpose |
|----------|---------|
| [spec/MANIFESTO_en.md](spec/MANIFESTO_en.md) | Product identity, user-group taxonomy |
| [spec/ARCHITECTURE.md](spec/ARCHITECTURE.md) | System architecture, tech stack, deployment |
| [spec/feature/DEV_ENV.md](spec/feature/DEV_ENV.md) | Dev environment specification |
| [spec/feature/HELM_CHART.md](spec/feature/HELM_CHART.md) | Helm chart specification |
| [spec/API_DESIGN_PRINCIPLE_en.md](spec/API_DESIGN_PRINCIPLE_en.md) | REST API conventions |
| [spec/DATAHUB_INTEGRATION.md](spec/DATAHUB_INTEGRATION.md) | DataHub SDK/API patterns |

## License

[Apache License 2.0](LICENSE)

# DataSpoke Local Development Environment

A fully scripted local Kubernetes environment for developing and testing DataSpoke. Three namespaces are provisioned: `datahub-01` (DataHub), `dataspoke-01` (infrastructure), and `dummy-data1` (example data sources).

The cluster hosts only **infrastructure dependencies**. DataSpoke application services (frontend, API, workers) run locally on your host machine, connecting to port-forwarded infrastructure.

## Prerequisites

- `kubectl` installed and configured
- `helm` v3 installed
- A local Kubernetes cluster (Docker Desktop, minikube, or kind) with **8+ CPUs / 16 GB RAM**

## Quick Start

### 0. If you use Claude Code

Just run command: `/dataspoke-dev-env-install`

### 1. Configure your cluster

Copy the example and edit to match your local cluster:

```bash
cp .env.example .env
```

Then edit `.env`:

```bash
# Set your local Kubernetes context
DATASPOKE_DEV_KUBE_CLUSTER=minikube
```

To list available contexts:

```bash
kubectl config get-contexts
```

### 2. Install everything

From the `dev_env/` directory:

```bash
chmod +x install.sh uninstall.sh \
  datahub/install.sh datahub/uninstall.sh \
  dataspoke-infra/install.sh dataspoke-infra/uninstall.sh \
  dataspoke-example/install.sh dataspoke-example/uninstall.sh

./install.sh
```

This takes approximately 5-10 minutes on the first run while container images are pulled.

### 3. Access DataHub (UI + GMS API)

```bash
./datahub-port-forward.sh          # start both forwards in background
./datahub-port-forward.sh --stop   # stop both and clean up PIDs
```

| Endpoint | Local URL | Purpose |
|----------|-----------|---------|
| DataHub UI | http://localhost:9002 | Web UI, GraphiQL |
| DataHub GMS | http://localhost:9004 | REST API, Swagger UI, SDK target |

Credentials: `datahub` / `datahub`

### 4. Access DataSpoke infrastructure

```bash
./dataspoke-port-forward.sh        # start all infra forwards in background
./dataspoke-port-forward.sh --stop # stop all and clean up PIDs
```

| Service | Local Address | Purpose |
|---------|--------------|---------|
| PostgreSQL | localhost:9201 | DataSpoke operational DB |
| Redis | localhost:9202 | Cache, rate limiting |
| Qdrant HTTP | localhost:9203 | Vector DB REST API |
| Qdrant gRPC | localhost:9204 | Vector DB gRPC API |
| Temporal | localhost:9205 | Workflow orchestration |

### 5. Run DataSpoke application services

Load environment variables and start services on the host:

```bash
source .env

# Frontend
cd ../src/frontend && npm run dev          # http://localhost:3000

# API
cd ../src/api && uvicorn main:app --reload --port 8000

# Workers
cd ../src/workflows && python -m worker

# Or use the Makefile (when available):
make dev-up
```

The `DATASPOKE_*` variables in `.env` point to `localhost` — the port-forwards connect them to the in-cluster infrastructure transparently.

### 6. Access example data sources

Forward example PostgreSQL:

```bash
source .env
kubectl port-forward \
  --namespace $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE \
  svc/example-postgres $DATASPOKE_DEV_KUBE_DUMMY_DATA_POSTGRES_PORT_FORWARD_PORT:5432
```

Credentials: `postgres` / `ExampleDev2024!` (database: `example_db`)

Forward example Kafka:

```bash
kubectl port-forward \
  --namespace $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE \
  svc/example-kafka $DATASPOKE_DEV_KUBE_DUMMY_DATA_KAFKA_PORT_FORWARD_PORT:9092
```

## Verify Installation

```bash
source .env
kubectl get pods -n $DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE
kubectl get pods -n $DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE
kubectl get pods -n $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE
helm list -n $DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE
helm list -n $DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE
```

## Uninstall

```bash
./uninstall.sh
```

You will be prompted before any destructive operation.

Claude Code command: `/dataspoke-dev-env-uninstall`

## Namespace Architecture

| Namespace | Purpose | Managed By |
|-----------|---------|------------|
| `datahub-01` | DataHub platform + all backing services | `datahub/install.sh` via Helm |
| `dataspoke-01` | DataSpoke infrastructure (PostgreSQL, Redis, Qdrant, Temporal) | `dataspoke-infra/install.sh` via Helm |
| `dummy-data1` | Example PostgreSQL + Kafka for ingestion testing | `dataspoke-example/install.sh` via kubectl |

## Directory Structure

```
dev_env/
├── .env                          # All settings (gitignored, copy from .env.example)
├── install.sh / uninstall.sh     # Top-level orchestrators
├── datahub-port-forward.sh       # Port-forward DataHub UI + GMS
├── dataspoke-port-forward.sh     # Port-forward DataSpoke infra services
├── datahub/                      # DataHub Helm install (prerequisites + datahub charts)
├── dataspoke-infra/              # DataSpoke infra via umbrella chart (values-dev.yaml)
└── dataspoke-example/            # Example data sources (plain K8s manifests)
```

## Environment Variables

Two-tier naming convention in `.env`:

| Prefix | Scope | Example |
|--------|-------|---------|
| `DATASPOKE_DEV_*` | Dev scripts only | `DATASPOKE_DEV_KUBE_CLUSTER`, `DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE` |
| `DATASPOKE_*` (no `DEV`) | App runtime | `DATASPOKE_POSTGRES_HOST`, `DATASPOKE_REDIS_HOST` |

App runtime variables point to `localhost` in dev (via port-forward) and to in-cluster services in production (via Helm values).

## Resource Budget

This environment targets ~11.0 GiB memory limits on an 8+ CPU / 16 GB RAM cluster (~69% utilization). See `spec/feature/DEV_ENV.md` for field-tested rationale per component.

| Component | Namespace | Memory Limit |
|-----------|-----------|-------------|
| Elasticsearch | datahub-01 | 2560 Mi |
| Kafka (bitnami) | datahub-01 | 512 Mi |
| ZooKeeper (bitnami) | datahub-01 | 256 Mi |
| MySQL (prerequisites) | datahub-01 | 768 Mi |
| datahub-gms | datahub-01 | 1536 Mi |
| datahub-frontend | datahub-01 | 768 Mi |
| datahub-mae-consumer | datahub-01 | 512 Mi |
| datahub-mce-consumer | datahub-01 | 512 Mi |
| datahub-actions | datahub-01 | 256 Mi |
| temporal-server | dataspoke-01 | 1024 Mi |
| qdrant | dataspoke-01 | 1024 Mi |
| postgresql (dataspoke) | dataspoke-01 | 512 Mi |
| redis | dataspoke-01 | 256 Mi |
| example-postgres | dummy-data1 | 256 Mi |
| example-kafka | dummy-data1 | 512 Mi |
| **Total** | | **~11.0 Gi** |

## Troubleshooting

See [spec/feature/DEV_ENV.md §Troubleshooting](../spec/feature/DEV_ENV.md#troubleshooting) for detailed solutions to common issues including Elasticsearch OOM, MySQL OOM, pending pods, and port-forward failures.

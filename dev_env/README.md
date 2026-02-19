# DataSpoke Local Development Environment

A fully scripted local Kubernetes environment for developing and testing DataSpoke.
Three namespaces are provisioned: `datahub-01`, `dataspoke-team1`, and `dummy-data1`.

## Prerequisites

- `kubectl` installed and configured
- `helm` v3 installed
- A local Kubernetes cluster running (Docker Desktop, minikube, or kind)

## Quick Start

### 0. If you use Claude Code

Just run command: /dataspoke-dev-env-install

### 1. Configure your cluster

Copy the example and edit to match your local cluster:

```bash
cp dev_env/.env.example dev_env/.env
```

Then edit `dev_env/.env`:

```bash
# Set your local Kubernetes context
DATASPOKE_KUBE_CLUSTER=minikube
```

To list available contexts:

```bash
kubectl config get-contexts
```

### 2. Install everything

From the `dev_env/` directory:

```bash
chmod +x install.sh uninstall.sh datahub/install.sh datahub/uninstall.sh \
  dataspoke-example/install.sh dataspoke-example/uninstall.sh

./install.sh
```

This takes approximately 5-10 minutes on the first run while container images are pulled.

### 3. Access DataHub (UI + GMS API)

```bash
dev_env/datahub-port-forward.sh          # start both forwards in background
dev_env/datahub-port-forward.sh --stop   # stop both and clean up PIDs
```

This forwards two endpoints:

| Endpoint | Local URL | Purpose |
|----------|-----------|---------|
| DataHub UI | http://localhost:9002 | Web UI, GraphiQL |
| DataHub GMS | http://localhost:9004 | REST API, Swagger UI, SDK target |

Credentials: `datahub` / `datahub`

### 4. Access example data source

Forward PostgreSQL (example source):

```bash
source dev_env/.env
kubectl port-forward \
  --namespace $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE \
  svc/example-postgres 5432:5432
```

Credentials: `postgres` / `ExampleDev2024!` (database: `example_db`)

## Verify Installation

```bash
source dev_env/.env
# Check all pods
kubectl get pods -n $DATASPOKE_KUBE_DATAHUB_NAMESPACE
kubectl get pods -n $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE

# Check Helm releases
helm list -n $DATASPOKE_KUBE_DATAHUB_NAMESPACE
```

## Uninstall

```bash
./uninstall.sh
```

You will be prompted before any destructive operation is taken.

c.f. there's also Claude Code command: /dataspoke-dev-env-uninstall

## Namespace Architecture

| Namespace | Purpose | Managed By |
|-----------|---------|------------|
| `datahub-01` | DataHub platform + all backing services | `datahub/install.sh` via Helm |
| `dataspoke-team1` | DataSpoke application (placeholder) | `install.sh` (namespace only) |
| `dummy-data1` | Example PostgreSQL for ingestion testing | `dataspoke-example/install.sh` via kubectl |

## Resource Budget

This environment targets ~7.8 GiB memory limits on an 8 CPU / 14 GB RAM cluster (~55% utilization, ~4.7 GiB headroom for k8s system + burst). See `spec/feature/DEV_ENV.md` for field-tested rationale per component.

| Component | Namespace | Memory Limit |
|-----------|-----------|-------------|
| kafka (bitnami) | datahub-01 | 512 Mi |
| zookeeper (bitnami) | datahub-01 | 256 Mi |
| elasticsearch | datahub-01 | 2560 Mi |
| mysql (prerequisites) | datahub-01 | 768 Mi |
| datahub-gms | datahub-01 | 1536 Mi |
| datahub-frontend | datahub-01 | 768 Mi |
| datahub-mae-consumer | datahub-01 | 512 Mi |
| datahub-mce-consumer | datahub-01 | 512 Mi |
| datahub-actions | datahub-01 | 256 Mi |
| example-postgres | dummy-data1 | 256 Mi |
| **Total** | | **~7.8 Gi** |

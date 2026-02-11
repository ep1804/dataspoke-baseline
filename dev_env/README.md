# DataSpoke Local Development Environment

A fully scripted local Kubernetes environment for developing and testing DataSpoke.
Three namespaces are provisioned: `datahub1`, `dataspoke1`, and `dataspoke1-example`.

## Prerequisites

- `kubectl` installed and configured
- `helm` v3 installed
- A local Kubernetes cluster running (Docker Desktop, minikube, or kind)

## Quick Start

### 1. Configure your cluster

Edit `dev_env/.env` to match your local cluster:

```bash
# Set your local Kubernetes context
DATASPOKE_KUBE_CLUSTER=docker-desktop
```

To list available contexts:

```bash
kubectl config get-contexts
```

### 2. Install everything

From the `dev_env/` directory:

```bash
chmod +x install.sh uninstall.sh datahub/install.sh datahub/uninstall.sh \
  dataspoke1-example/install.sh dataspoke1-example/uninstall.sh

./install.sh
```

This takes approximately 5-10 minutes on the first run while container images are pulled.

### 3. Access the DataHub UI

```bash
kubectl port-forward \
  --namespace datahub1 \
  $(kubectl get pods -n datahub1 -l 'app.kubernetes.io/name=datahub-frontend' \
    -o jsonpath='{.items[0].metadata.name}') \
  9002:9002
```

Open http://localhost:9002 in your browser.

Credentials: `datahub` / `datahub`

### 4. Access example data sources

Forward MySQL (example source):

```bash
kubectl port-forward \
  --namespace dataspoke1-example \
  svc/example-mysql 3306:3306
```

Forward PostgreSQL (example source):

```bash
kubectl port-forward \
  --namespace dataspoke1-example \
  svc/example-postgres 5432:5432
```

Credentials for both: `root` / `ExampleDev2024!` (database: `example_db`)

## Verify Installation

```bash
# Check all pods
kubectl get pods -n datahub1
kubectl get pods -n dataspoke1-example

# Check Helm releases
helm list -n datahub1
```

## Uninstall

```bash
./uninstall.sh
```

You will be prompted before any destructive operation is taken.

## Namespace Architecture

| Namespace | Purpose | Managed By |
|-----------|---------|------------|
| `datahub1` | DataHub platform + all backing services | `datahub/install.sh` via Helm |
| `dataspoke1` | DataSpoke application (placeholder) | `install.sh` (namespace only) |
| `dataspoke1-example` | Example MySQL + PostgreSQL for ingestion testing | `dataspoke1-example/install.sh` via kubectl |

## Resource Budget

This environment targets <= 50% of a 6 CPU / 16 GB RAM cluster (~8 GB RAM total).

| Component | Namespace | Memory Limit |
|-----------|-----------|-------------|
| cp-kafka | datahub1 | 768 Mi |
| cp-zookeeper | datahub1 | 256 Mi |
| cp-schema-registry | datahub1 | 256 Mi |
| elasticsearch | datahub1 | 1024 Mi |
| mysql (prerequisites) | datahub1 | 512 Mi |
| neo4j | datahub1 | 1024 Mi |
| datahub-gms | datahub1 | 1536 Mi |
| datahub-frontend | datahub1 | 768 Mi |
| datahub-mae-consumer | datahub1 | 512 Mi |
| datahub-mce-consumer | datahub1 | 512 Mi |
| datahub-actions | datahub1 | 256 Mi |
| example-mysql | dataspoke1-example | 256 Mi |
| example-postgres | dataspoke1-example | 256 Mi |
| **Total** | | **~7.7 Gi** |

# DEV_ENV — Local Development Environment

> **Version**: 0.1 | **Status**: Draft | **Date**: 2026-02-12

## Table of Contents
1. [Overview](#overview)
2. [Goals & Non-Goals](#goals--non-goals)
3. [Namespace Architecture](#namespace-architecture)
4. [Directory Structure](#directory-structure)
5. [Configuration](#configuration)
6. [DataHub Installation](#datahub-installation)
7. [dataspoke1-example Installation](#dataspoke1-example-installation)
8. [Resource Sizing](#resource-sizing)
9. [Install & Uninstall Flow](#install--uninstall-flow)
10. [Open Questions](#open-questions)

---

## Overview

`dev_env/` provides a fully scripted local Kubernetes environment for developing and testing DataSpoke. It provisions three namespaces — `datahub1`, `dataspoke1`, `dataspoke1-example` — mirroring the production separation of concerns described in `ARCHITECTURE.md`.

DataHub (the hub) is installed locally only for development and testing purposes. In production, DataHub is deployed separately and DataSpoke connects to it externally.

```
Local Kubernetes Cluster (docker-desktop / minikube)
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│  ┌─────────────────────┐   ┌──────────────────────────────┐  │
│  │  datahub1           │   │  dataspoke1-example          │  │
│  │                     │   │                              │  │
│  │  - GMS              │   │  - MySQL (example source)    │  │
│  │  - Frontend         │◄──┤  - PostgreSQL (example src)  │  │
│  │  - MAE/MCE consumer │   │                              │  │
│  │  - Kafka + ZK       │   └──────────────────────────────┘  │
│  │  - Elasticsearch    │                                      │
│  │  - MySQL            │   ┌──────────────────────────────┐  │
│  │  - Neo4j            │   │  dataspoke1                  │  │
│  └─────────────────────┘   │  (placeholder — empty)       │  │
│                             └──────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

---

## Goals & Non-Goals

### Goals
- Single command (`./install.sh`) to stand up a complete local dev environment
- Clean namespace separation matching the production topology
- DataHub with **Neo4j enabled** (graph backend) for full lineage support
- Example data sources (MySQL, PostgreSQL) in a dedicated namespace for testing DataHub ingestion workflows
- Idempotent installs — re-running `install.sh` is always safe
- Resource-constrained sizing that fits within ~50% of a typical local cluster (6 CPU / 16 GB RAM)

### Non-Goals
- Production deployment (use `helm-charts/dataspoke` for production)
- DataSpoke application services (installed separately when source code exists)
- External data source connectivity (example sources are in-cluster only)
- High availability or data persistence between dev environment resets

---

## Namespace Architecture

| Namespace | Purpose | Managed By |
|-----------|---------|------------|
| `datahub1` | DataHub platform + all backing services | `datahub/install.sh` via Helm |
| `dataspoke1` | DataSpoke application (placeholder for now) | `dev_env/install.sh` (namespace only) |
| `dataspoke1-example` | Example MySQL + PostgreSQL for ingestion testing | `dataspoke1-example/install.sh` via kubectl |

---

## Directory Structure

```
dev_env/
├── .env                                  # Cluster settings (edit before first use)
├── README.md                             # Quick-start guide
├── install.sh                            # Top-level: creates namespaces + calls sub-installers
├── uninstall.sh                          # Top-level: tears down all dev_env resources
│
├── datahub/
│   ├── install.sh                        # Installs DataHub via Helm
│   ├── uninstall.sh                      # Uninstalls DataHub Helm releases
│   ├── prerequisites-values.yaml         # Kafka, ZK, SR, Elasticsearch, MySQL, Neo4j sizing
│   └── values.yaml                       # DataHub component sizing + service name overrides
│
└── dataspoke1-example/
    ├── install.sh                        # Applies manifests and waits for readiness
    ├── uninstall.sh                      # Deletes manifests
    └── manifests/
        ├── mysql.yaml                    # MySQL 8 Deployment + Service + Secret + PVC
        └── postgres.yaml                 # PostgreSQL 15 Deployment + Service + Secret + PVC
```

---

## Configuration

All scripts source `dev_env/.env`. Variables:

```dotenv
# Kubernetes context for local cluster
DATASPOKE_KUBE_CLUSTER=docker-desktop

# Namespace names
DATASPOKE_KUBE_DATAHUB_NAMESPACE=datahub1
DATASPOKE_KUBE_DATASPOKE_NAMESPACE=dataspoke1
DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE=dataspoke1-example

# DataHub MySQL credentials (used for k8s secret + Helm values)
DATASPOKE_MYSQL_ROOT_PASSWORD=<16+ char password>
DATASPOKE_MYSQL_PASSWORD=<16+ char password>

# DataHub Neo4j credentials
DATASPOKE_NEO4J_PASSWORD=<16+ char password>
```

Sub-scripts (`datahub/install.sh`, `dataspoke-example/install.sh`) source `../.env` relative to their own `SCRIPT_DIR`. The top-level scripts source `./.env`.

**Password policy**: all passwords must be at minimum 15 characters, mixed case with at least one special character (e.g., `DatahubDev2024!`).

---

## DataHub Installation

### Helm Chart Versions

| Chart | Version | App Version |
|-------|---------|-------------|
| `datahub/datahub-prerequisites` | 0.2.1 | — |
| `datahub/datahub` | 0.8.3 | v1.4.0 |

### Kubernetes Secrets (created before Helm install)

| Secret Name | Namespace | Keys |
|-------------|-----------|------|
| `mysql-secrets` | `datahub` | `mysql-root-password`, `mysql-password` |
| `neo4j-secrets` | `datahub` | `neo4j-password` |

Secrets are created idempotently using `--dry-run=client -o yaml | kubectl apply -f -`.

### prerequisites-values.yaml Components

| Component | Subchart | Memory Limit | Notes |
|-----------|---------|-------------|-------|
| Kafka broker | `cp-kafka` | 768 Mi | `replicaCount: 1` |
| ZooKeeper | `cp-zookeeper` | 256 Mi | `replicaCount: 1` |
| Schema Registry | `cp-schema-registry` | 256 Mi | `replicaCount: 1` |
| Elasticsearch | `elasticsearch` | 1 Gi | `esJavaOpts: -Xmx768m -Xms768m`, persistence disabled |
| MySQL | `mysql` | 512 Mi | credentials via `existingSecret: mysql-secrets`, persistence disabled |
| **Neo4j** | `neo4j` | **1 Gi** | **enabled: true**, password via `existingSecret: neo4j-secrets`, 10 Gi PVC |

Neo4j is **enabled** (was disabled in older configurations). It serves as the graph backend for DataHub lineage.

### values.yaml Key Overrides

Because the prerequisites chart is installed as release name `datahub-prerequisites`, all internal service names get the `datahub-prerequisites-` prefix. The DataHub chart must be told to use these:

```yaml
global:
  sql.datasource.host: "datahub-prerequisites-mysql:3306"
  kafka.bootstrap.server: "datahub-prerequisites-kafka:9092"
  kafka.zookeeper.server: "datahub-prerequisites-zookeeper:2181"
  graph_service_impl: neo4j
  neo4j:
    host: "datahub-prerequisites-neo4j"
    uri: "neo4j://datahub-prerequisites-neo4j:7687"
    username: "neo4j"
    password.secretRef: "neo4j-secrets"
    password.secretKey: "neo4j-password"
```

DataHub component memory limits:

| Component | Memory Limit | Memory Request |
|-----------|-------------|----------------|
| `datahub-gms` | 1536 Mi | 1 Gi |
| `datahub-frontend` | 768 Mi | 512 Mi |
| `datahub-mae-consumer` | 512 Mi | 256 Mi |
| `datahub-mce-consumer` | 512 Mi | 256 Mi |
| `datahub-actions` | 256 Mi | 128 Mi |

### datahub/install.sh Steps

1. Source `../.env`
2. Verify `kubectl` and `helm` are installed
3. Switch to `$DATASPOKE_KUBE_CLUSTER` context
4. Add/update `datahub` Helm repo (`https://helm.datahubproject.io/`)
5. Ensure `$DATASPOKE_KUBE_DATAHUB_NAMESPACE` namespace exists
6. Create `mysql-secrets` (idempotent)
7. Create `neo4j-secrets` (idempotent)
8. `helm upgrade --install datahub-prerequisites` with `prerequisites-values.yaml`, `--timeout 5m --wait`
9. `helm upgrade --install datahub` with `values.yaml`, `--timeout 5m --wait`
10. Print port-forward instructions for the DataHub UI

---

## dataspoke1-example Installation

Plain Kubernetes manifests (no Helm). Applied with `kubectl apply -f manifests/`.

### MySQL (`manifests/mysql.yaml`)

| Field | Value |
|-------|-------|
| Image | `mysql:8.0` |
| Database | `example_db` |
| Root password | `ExampleDev2024!` (via Secret `example-mysql-secret`) |
| Memory limit | 256 Mi |
| Storage | 5 Gi PVC at `/var/lib/mysql` |
| Service | ClusterIP, port 3306, name `example-mysql` |

### PostgreSQL (`manifests/postgres.yaml`)

| Field | Value |
|-------|-------|
| Image | `postgres:15` |
| Database | `example_db` |
| Password | `ExampleDev2024!` (via Secret `example-postgres-secret`) |
| Memory limit | 256 Mi |
| Storage | 5 Gi PVC at `/var/lib/postgresql/data` |
| Service | ClusterIP, port 5432, name `example-postgres` |

Both manifests include the Secret inline in the same file.

### dataspoke1-example/install.sh Steps

1. Source `../.env`
2. Ensure `$DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE` namespace exists
3. `kubectl apply -f ./manifests/`
4. Wait for MySQL: `kubectl rollout status deployment/example-mysql --timeout=3m`
5. Wait for PostgreSQL: `kubectl rollout status deployment/example-postgres --timeout=3m`
6. Print connection details for local use

---

## Resource Sizing

Cluster capacity: **6 CPU / 16 GB RAM / 150 GB storage**.
Target usage for `dev_env`: **≤ 50%** → 3 CPU / 8 GB RAM.

### Memory Budget (limits)

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

This leaves ~300 Mi headroom before the 8 Gi target, and the `dataspoke1` namespace has no workloads yet.

---

## Install & Uninstall Flow

### install.sh (top-level)

```
./install.sh
  ├── source .env
  ├── check kubectl, helm
  ├── kubectl config use-context $DATASPOKE_KUBE_CLUSTER
  ├── create namespaces: datahub1, dataspoke1, dataspoke1-example (if not exists)
  ├── call datahub/install.sh
  ├── call dataspoke-example/install.sh
  └── print summary + port-forward instructions
```

### uninstall.sh (top-level)

```
./uninstall.sh
  ├── source .env
  ├── prompt: "Remove all dev_env resources? [y/N]"
  ├── call dataspoke-example/uninstall.sh
  ├── call datahub/uninstall.sh
  └── prompt: "Delete namespaces (datahub1, dataspoke1, dataspoke1-example)? [y/N]"
```

### Shell Script Standards

- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail`
- Location: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- Helpers: `info()`, `warn()`, `error()` functions
- All mutating kubectl/helm operations are idempotent

---

## Open Questions

- [ ] Should Neo4j use a PVC in dev? Currently configured with `defaultStorageClass` + 10 Gi. For a completely ephemeral dev env, persistence could be disabled, but Neo4j's chart may require a volume.
- [ ] Should `dataspoke1-example` sources pre-populate sample data (seed SQL scripts) for realistic ingestion testing?
- [ ] As DataSpoke application code is written, what services (Qdrant, Temporal, Redis, PostgreSQL) should be added to the `dataspoke` namespace in `dev_env`? A `dataspoke/install.sh` sub-script will be needed.
- [ ] Should `dataspoke1-example` Kafka producers/consumers be added to simulate streaming data into DataHub via Kafka MCE topics?

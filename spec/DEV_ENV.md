# DEV_ENV — Local Development Environment

> **Version**: 0.3 | **Status**: Draft | **Date**: 2026-02-13

## Table of Contents
1. [Overview](#overview)
2. [Goals & Non-Goals](#goals--non-goals)
3. [Namespace Architecture](#namespace-architecture)
4. [Directory Structure](#directory-structure)
5. [Configuration](#configuration)
6. [DataHub Installation](#datahub-installation)
7. [dataspoke-example Installation](#dataspoke-example-installation)
8. [Resource Sizing](#resource-sizing)
9. [Install & Uninstall Flow](#install--uninstall-flow)
10. [Troubleshooting](#troubleshooting)
11. [Open Questions](#open-questions)
12. [References](#references)

---

## Overview

`dev_env/` provides a fully scripted local Kubernetes environment for developing and testing DataSpoke. It provisions three namespaces — `datahub-01`, `dataspoke-team1`, `dummy-data1` (defaults; see [Configuration](#configuration)) — mirroring the production separation of concerns described in `ARCHITECTURE.md`.

DataHub (the hub) is installed locally only for development and testing purposes. In production, DataHub is deployed separately and DataSpoke connects to it externally.

```
Local Kubernetes Cluster (minikube / docker-desktop)
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│  ┌─────────────────────┐   ┌──────────────────────────────┐  │
│  │  datahub-01         │   │  dummy-data1                 │  │
│  │                     │   │                              │  │
│  │  - GMS              │   │  - PostgreSQL (example src)  │  │
│  │  - Frontend         │◄──┤                              │  │
│  │  - MAE/MCE consumer │   │                              │  │
│  │  - Kafka + ZK       │   └──────────────────────────────┘  │
│  │  - Elasticsearch    │                                      │
│  │  - MySQL            │   ┌──────────────────────────────┐  │
│  │                     │   │  dataspoke-team1             │  │
│  └─────────────────────┘   │  (placeholder — empty)       │  │
│                             └──────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

---

## Goals & Non-Goals

### Goals
- Single command (`./install.sh`) to stand up a complete local dev environment
- Clean namespace separation matching the production topology
- DataHub with **Elasticsearch graph backend** for lineage support (Neo4j is not required)
- Example data source (PostgreSQL) in a dedicated namespace for testing DataHub ingestion workflows
- Idempotent installs — re-running `install.sh` is always safe
- Resource-constrained sizing that fits within ~57% of a typical local cluster (8 CPU / 14 GB RAM)

### Non-Goals
- Production deployment (use `helm-charts/dataspoke` for production)
- DataSpoke application services (installed separately when source code exists)
- External data source connectivity (example sources are in-cluster only)
- High availability or data persistence between dev environment resets

---

## Namespace Architecture

| Namespace | Purpose | Managed By |
|-----------|---------|------------|
| `datahub-01` | DataHub platform + all backing services | `datahub/install.sh` via Helm |
| `dataspoke-team1` | DataSpoke application (placeholder for now) | `dev_env/install.sh` (namespace only) |
| `dummy-data1` | Example PostgreSQL for ingestion testing | `dataspoke-example/install.sh` via kubectl |

> **Note**: The namespace names above are the **default values** shipped in `dev_env/.env`. All scripts read these names exclusively from environment variables — `$DATASPOKE_KUBE_DATAHUB_NAMESPACE`, `$DATASPOKE_KUBE_DATASPOKE_NAMESPACE`, and `$DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE` — and never hardcode them. You can rename the namespaces freely by editing `.env` before running `install.sh`. Namespace names used elsewhere in this document are the defaults and serve as illustrative examples only.
>
> **Naming convention**: `DATASPOKE_` prefixes all variables. `DATASPOKE_DEV_` marks variables that are local-development-only (not used in production configs). `KUBE` in the name indicates the variable relates to a Kubernetes resource or setting.

---

## Directory Structure

```
dev_env/
├── .env                                  # Cluster settings (edit before first use)
├── README.md                             # Quick-start guide
├── install.sh                            # Top-level: creates namespaces + calls sub-installers
├── uninstall.sh                          # Top-level: tears down all dev_env resources
├── datahub-port-forward.sh                # Port-forward to DataHub UI (localhost:9002)
│
├── datahub/
│   ├── install.sh                        # Installs DataHub via Helm
│   ├── uninstall.sh                      # Uninstalls DataHub Helm releases
│   ├── prerequisites-values.yaml         # Kafka, ZK, Elasticsearch, MySQL sizing
│   └── values.yaml                       # DataHub component sizing + service name overrides
│
└── dataspoke-example/
    ├── install.sh                        # Applies manifests and waits for readiness
    ├── uninstall.sh                      # Deletes manifests
    └── manifests/
        └── postgres.yaml                 # PostgreSQL 15 Deployment + Service + Secret + PVC
```

---

## Configuration

All scripts source `dev_env/.env`. This file is **not committed** (listed in `.gitignore`). Copy `dev_env/.env.example` to `dev_env/.env` and fill in your passwords before first use.

Variables:

```dotenv
# ==============================================================================
# DataSpoke Environment Variables
# ==============================================================================
# Naming convention:
#   DATASPOKE_          — shared across all environments
#   DATASPOKE_DEV_      — local development only
#   KUBE in name        — Kubernetes resource related
# ==============================================================================

# --- Kubernetes (shared) -----------------------------------------------------
DATASPOKE_KUBE_CLUSTER=minikube
DATASPOKE_KUBE_DATAHUB_NAMESPACE=datahub-01
DATASPOKE_KUBE_DATASPOKE_NAMESPACE=dataspoke-team1

# --- Kubernetes / Dev only ----------------------------------------------------
DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE=dummy-data1
DATASPOKE_DEV_KUBE_DATAHUB_PREREQUISITES_CHART_VERSION=0.2.1
DATASPOKE_DEV_KUBE_DATAHUB_CHART_VERSION=0.8.3
DATASPOKE_DEV_KUBE_DATAHUB_PORT_FORWARD_UI_PORT=9002
DATASPOKE_DEV_KUBE_DATAHUB_MYSQL_ROOT_PASSWORD=<16+ char password>
DATASPOKE_DEV_KUBE_DATAHUB_MYSQL_PASSWORD=<16+ char password>
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

### Why No Neo4j

The upstream DataHub Helm chart ships with **`neo4j.enabled: false`** and **`graph_service_impl: elasticsearch`** by default. Neo4j was previously required for lineage graph queries, but Elasticsearch now provides full graph backend support including multi-hop lineage traversal (`ElasticSearchGraphService.supportsMultiHop()` returns `true`).

Removing Neo4j from the dev environment:
- Saves **2 Gi RAM** (Neo4j Helm chart enforces a hard minimum of 2 Gi) plus 10 Gi PVC storage
- Eliminates a `neo4j-secrets` Secret and the associated `.env` variable
- Aligns with the upstream chart defaults — no overrides needed for graph configuration
- Has no functional impact on dev/test workflows; the ES graph backend has feature parity for all DataHub lineage operations

For production environments requiring heavy graph traversal at scale, Neo4j can be re-enabled. See the [DataHub migration guide](https://docs.datahub.com/docs/how/migrating-graph-service-implementation) for switching between backends.

### Kubernetes Secrets (created before Helm install)

| Secret Name | Namespace | Keys |
|-------------|-----------|------|
| `mysql-secrets` | `$DATASPOKE_KUBE_DATAHUB_NAMESPACE` | `mysql-root-password`, `mysql-password` |

Secrets are created idempotently using `--dry-run=client -o yaml | kubectl apply -f -`.

### prerequisites-values.yaml Components

| Component | Subchart | CPU Req / Limit | Mem Req / Limit | Notes |
|-----------|----------|-----------------|-----------------|-------|
| Kafka broker | `kafka` (bitnami) | 200m / 1000m | 256Mi / 512Mi | `broker.replicaCount: 1` |
| ZooKeeper | `kafka.zookeeper` (bitnami) | 50m / 200m | 128Mi / 256Mi | `replicaCount: 1` |
| Elasticsearch | `elasticsearch` | 200m / 1000m | 1536Mi / 2560Mi | `esJavaOpts: -Xmx512m -Xms512m` |
| MySQL | `mysql` (bitnami) | 100m / 500m | 256Mi / 768Mi | credentials via `auth.existingSecret: mysql-secrets`, persistence disabled |

Schema Registry is **not deployed** — DataHub v1.4.0 uses an internal schema registry (`type: INTERNAL`).

Neo4j is **disabled** (upstream default).

### Resource Rationale (prerequisites)

**Elasticsearch** is the most resource-sensitive prerequisite. The JVM heap (`-Xmx512m -Xms512m`) matches the upstream default. The standard rule is that JVM heap should be ~50% of container memory, with the remainder available for Lucene file cache and OS buffers. Testing showed that ES 7.17.3 OOM-kills at 2Gi during concurrent startup with other prerequisites — off-heap usage (plugin loading, Lucene segment cache, index recovery) spikes above 1.5Gi during initialization. A 2560Mi limit gives 512Mi heap + ~2Gi off-heap headroom, which is stable even under concurrent startup pressure. The upstream default of 1024Mi limit is insufficient for reliable operation. (Ref: [Elastic JVM heap sizing guide](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-jvm-heap-size.html))

**Kafka** at 512Mi limit is reduced from the previous 768Mi. The bitnami Kafka chart does not set any default resource limits. For a single-broker dev setup with low throughput, 512Mi is sufficient. The upstream datahub-prerequisites chart also sets no explicit Kafka resources.

**MySQL** at 768Mi limit. Testing showed that 512Mi causes OOM-kills during `mysql_upgrade`, which runs on every container restart when persistence is disabled. The `mysql_upgrade` process launches a background `mysqld` alongside the upgrade check, briefly doubling memory usage beyond 512Mi. 768Mi provides stable headroom for this startup pattern. Persistence is disabled since dev data is ephemeral.

**ZooKeeper** at 256Mi is unchanged — minimal footprint for single-node coordination.

### values.yaml Key Overrides

Because the prerequisites chart is installed as release name `datahub-prerequisites`, all internal service names get the `datahub-prerequisites-` prefix. The DataHub chart must be told to use these:

```yaml
global:
  sql.datasource.host: "datahub-prerequisites-mysql:3306"
  kafka.bootstrap.server: "datahub-prerequisites-kafka:9092"
  kafka.zookeeper.server: "datahub-prerequisites-zookeeper:2181"
  elasticsearch.host: "elasticsearch-master"
  graph_service_impl: elasticsearch    # upstream default, no Neo4j needed
```

DataHub component resources:

| Component | CPU Req / Limit | Mem Req / Limit |
|-----------|-----------------|-----------------|
| `datahub-gms` | 500m / 1500m | 768Mi / 1536Mi |
| `datahub-frontend` | 200m / 500m | 384Mi / 768Mi |
| `datahub-mae-consumer` | 100m / 500m | 256Mi / 512Mi |
| `datahub-mce-consumer` | 100m / 500m | 256Mi / 512Mi |
| `datahub-actions` | 50m / 200m | 128Mi / 256Mi |

### Resource Rationale (DataHub services)

**GMS** is the heaviest component — a Spring Boot JVM application that handles all metadata reads/writes. The upstream default is 1Gi request / 2Gi limit with `MaxRAMPercentage=75%` (giving ~1.5 Gi heap at 2Gi). For a dev cluster with small metadata, 1536Mi limit gives ~1.1 Gi heap — sufficient for ingestion testing. Going below 1Gi limit is risky due to JVM startup spikes and the `datahubSystemUpdate` job. (Ref: [DataHub OOM discussion, GitHub #11147](https://github.com/datahub-project/datahub/issues/11147))

**Frontend** at 768Mi is reduced from the upstream default of 1400Mi. The React+Play framework frontend is relatively lightweight for dev use with a single user. 768Mi provides adequate headroom.

**MAE/MCE consumers** at 512Mi are reduced from the upstream default of 1536Mi. These JVM consumers process metadata change events. At dev scale (low event volume), 512Mi is sufficient. The upstream values are sized for production throughput.

**Actions** at 256Mi is reduced from the upstream 512Mi. The Python-based actions framework has minimal memory needs for dev workloads.

### datahub/install.sh Steps

1. Source `../.env`
2. Verify `kubectl` and `helm` are installed
3. Switch to `$DATASPOKE_KUBE_CLUSTER` context
4. Add/update `datahub` Helm repo (`https://helm.datahubproject.io/`)
5. Ensure `$DATASPOKE_KUBE_DATAHUB_NAMESPACE` namespace exists
6. Create `mysql-secrets` (idempotent)
7. `helm upgrade --install datahub-prerequisites` with `prerequisites-values.yaml`, `--timeout 5m --wait`
8. `helm upgrade --install datahub` with `values.yaml`, `--timeout 10m --wait`
9. Print port-forward instructions (or run `./datahub-port-forward.sh`)

---

## dataspoke-example Installation

Plain Kubernetes manifests (no Helm). Applied with `kubectl apply -f manifests/`.

### PostgreSQL (`manifests/postgres.yaml`)

| Field | Value |
|-------|-------|
| Image | `postgres:15` |
| Database | `example_db` |
| Password | `ExampleDev2024!` (via Secret `example-postgres-secret`) |
| Memory limit | 256 Mi |
| Storage | 5 Gi PVC at `/var/lib/postgresql/data` |
| Service | ClusterIP, port 5432, name `example-postgres` |

The manifest includes the Secret inline in the same file.

### dataspoke-example/install.sh Steps

1. Source `../.env`
2. Ensure `$DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE` namespace exists
3. `kubectl apply -f ./manifests/`
4. Wait for PostgreSQL: `kubectl rollout status deployment/example-postgres --timeout=3m`
5. Print connection details for local use

---

## Resource Sizing

Cluster capacity: **8 CPU / 14 GB RAM / 150 GB storage**.
Target usage for `dev_env`: **~55%** -> ~7.8 GiB RAM, ~6.4 CPU limits.

### Memory Budget (limits)

> The Namespace column uses the default names from `dev_env/.env`. Actual values are sourced from environment variables at runtime — see [Namespace Architecture](#namespace-architecture).

| Component | Namespace | Mem Limit | vs Upstream Default | Notes |
|-----------|-----------|-----------|---------------------|-------|
| Elasticsearch | datahub-01 | 2560 Mi | 1024M (+150%) | 512m heap + off-heap for Lucene cache / index recovery; 2Gi OOM-killed during concurrent startup |
| Kafka (bitnami) | datahub-01 | 512 Mi | *(not set)* | Explicit limit to prevent unbounded growth |
| ZooKeeper (bitnami) | datahub-01 | 256 Mi | *(not set)* | Explicit limit |
| MySQL (bitnami) | datahub-01 | 768 Mi | *(not set)* | Explicit limit; 512Mi OOM-killed during `mysql_upgrade` on restart |
| datahub-gms | datahub-01 | 1536 Mi | 2Gi (-25%) | Sufficient for dev-scale metadata |
| datahub-frontend | datahub-01 | 768 Mi | 1400Mi (-45%) | Single-user dev access |
| datahub-mae-consumer | datahub-01 | 512 Mi | 1536Mi (-67%) | Low event volume in dev |
| datahub-mce-consumer | datahub-01 | 512 Mi | 1536Mi (-67%) | Low event volume in dev |
| datahub-actions | datahub-01 | 256 Mi | 512Mi (-50%) | Lightweight Python process |
| example-postgres | dummy-data1 | 256 Mi | — | Minimal example source |
| **Total** | | **~7.8 Gi** | | |

### Comparison with Previous Spec (v0.1)

| Change | v0.1 | v0.2 | v0.3 (current) |
|--------|------|------|----------------|
| Neo4j | 2048 Mi | 0 | 0 |
| Elasticsearch | 3072 Mi | 1536 Mi | 2560 Mi |
| MySQL (prereqs) | 768 Mi | 512 Mi | 768 Mi |
| Kafka | 768 Mi | 512 Mi | 512 Mi |
| GMS | 2048 Mi | 1536 Mi | 1536 Mi |
| example-mysql | — | 256 Mi | 0 (removed) |
| **Total** | **~10.8 Gi** | **~6.4 Gi** | **~7.8 Gi** |

The revised budget of **~7.8 Gi** targets ~55% of the 14 GB cluster, leaving ~4.7 GiB headroom for Kubernetes system components (kubelet, CoreDNS, kube-proxy), Helm setup/upgrade jobs (which can temporarily consume up to 2Gi for `datahubSystemUpdate`), and future DataSpoke sidecar services. The increase from v0.2 (~6.4 Gi) reflects field-tested limits: Elasticsearch and MySQL both OOM-killed at their previous limits during concurrent startup on a fresh cluster.

The DataHub documentation states a minimum of **2 CPU / 8 GB RAM** for running DataHub with all dependencies. Our budget fits within this envelope while adding explicit resource limits that the upstream chart often omits.

### CPU Budget (limits)

> Same note applies — namespace names are defaults from `.env`.

| Component | Namespace | CPU Limit |
|-----------|-----------|-----------|
| Elasticsearch | datahub-01 | 1000m |
| Kafka | datahub-01 | 1000m |
| ZooKeeper | datahub-01 | 200m |
| MySQL (prereqs) | datahub-01 | 500m |
| datahub-gms | datahub-01 | 1500m |
| datahub-frontend | datahub-01 | 500m |
| datahub-mae-consumer | datahub-01 | 500m |
| datahub-mce-consumer | datahub-01 | 500m |
| datahub-actions | datahub-01 | 200m |
| example-postgres | dummy-data1 | 500m |
| **Sum of limits** | | **6400m** |

CPU limits total 6.4 cores. Since pods rarely hit their limits simultaneously, actual CPU usage is well within the 8 CPU budget. The upstream DataHub chart does **not** set CPU limits for runtime components (only requests), but explicit limits are added here to prevent any single component from starving others on a constrained dev cluster.

---

## Install & Uninstall Flow

### install.sh (top-level)

```
./install.sh
  ├── source .env
  ├── check kubectl, helm
  ├── kubectl config use-context $DATASPOKE_KUBE_CLUSTER
  ├── create namespaces: $DATASPOKE_KUBE_DATAHUB_NAMESPACE, $DATASPOKE_KUBE_DATASPOKE_NAMESPACE, $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE (if not exists)
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
  └── prompt: "Delete namespaces ($DATASPOKE_KUBE_DATAHUB_NAMESPACE, $DATASPOKE_KUBE_DATASPOKE_NAMESPACE, $DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE)? [y/N]"
```

### Shell Script Standards

- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail`
- Location: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- Helpers: `info()`, `warn()`, `error()` — defined once in `dev_env/lib/helpers.sh`, sourced by all scripts
- All mutating kubectl/helm operations are idempotent

---

## Troubleshooting

### Elasticsearch OOM-killed during startup

**Symptom**: `elasticsearch-master-0` enters `OOMKilled` or `CrashLoopBackOff` shortly after startup.

**Cause**: ES off-heap usage (plugin loading, Lucene segment cache, index recovery) spikes above 2Gi during concurrent initialization with other prerequisites. The upstream default limit of 1024Mi is insufficient.

**Fix**: Already applied — `prerequisites-values.yaml` sets ES memory limit to 2560Mi. If you still see OOM-kills, ensure no other script or Helm override is reducing the limit.

---

### MySQL OOM-killed on restart

**Symptom**: `datahub-prerequisites-mysql-0` enters `OOMKilled` after the initial startup or after a pod restart.

**Cause**: With persistence disabled, MySQL runs `mysql_upgrade` on every container start. This process briefly launches a background `mysqld` alongside the upgrade check, temporarily doubling memory usage beyond 512Mi.

**Fix**: Already applied — `prerequisites-values.yaml` sets MySQL memory limit to 768Mi.

---

### Pod stuck in `Pending`

**Symptom**: A pod remains in `Pending` indefinitely; `kubectl describe pod <name> -n <ns>` shows `Insufficient memory` or `Insufficient cpu` under Events.

**Cause**: The cluster does not have enough free resources to schedule the pod. This often happens when other workloads are running on a shared laptop cluster (Docker Desktop, minikube).

**Fix**:
1. Check node allocatable resources: `kubectl describe node`
2. Stop other resource-heavy workloads or increase Docker Desktop memory allocation (Settings → Resources).
3. The full dev environment requires ~7.8 GiB memory limits and ~6.4 CPU limits — a 14 GB / 8 CPU cluster is the minimum.

---

### `datahub-system-update` job takes a very long time

**Symptom**: `datahub/install.sh` waits on the `datahub-system-update` job for 5–10 minutes.

**Cause**: This is expected on first install. The job bootstraps all DataHub metadata schemas and may pull large container images. It runs as a Helm pre-install hook and is the main reason `--wait` is not used (Helm's hook timeout would fire before the job completes).

**Fix**: Wait it out — the script polls every 10s and prints progress every 30s. If it exceeds 10 minutes, check logs: `kubectl logs -l job-name=datahub-system-update -n $DATASPOKE_KUBE_DATAHUB_NAMESPACE --tail=20`

---

### Port-forward "connection refused" or immediate disconnect

**Symptom**: Running `datahub-port-forward.sh` exits immediately or `http://localhost:9002` shows "connection refused".

**Cause**: The `datahub-frontend` pod is not yet `Ready`, or the pod name lookup returned empty.

**Fix**:
1. Verify the frontend pod is Running and Ready: `kubectl get pods -n $DATASPOKE_KUBE_DATAHUB_NAMESPACE -l app.kubernetes.io/name=datahub-frontend`
2. If it shows `0/1 Running`, GMS may still be starting — wait and retry.
3. Re-run `./datahub-port-forward.sh` once the pod is `1/1 Running`.

---

## Open Questions

- [ ] Should `dataspoke-example` sources pre-populate sample data (seed SQL scripts) for realistic ingestion testing?
- [ ] As DataSpoke application code is written, what services (Qdrant, Temporal, Redis, PostgreSQL) should be added to the `dataspoke` namespace in `dev_env`? A `dataspoke/install.sh` sub-script will be needed.
- [ ] Should `dataspoke-example` Kafka producers/consumers be added to simulate streaming data into DataHub via Kafka MCE topics?
- [ ] Should MAE/MCE consumer memory limits be further reduced (e.g., to 384Mi) to free more headroom? The upstream defaults of 1536Mi are sized for production throughput; monitoring actual dev usage would inform whether 512Mi is still too generous.

---

## References

- [DataHub — Deploying with Kubernetes](https://docs.datahub.com/docs/deploy/kubernetes) — official minimum requirements: 2 CPUs, 8 GB RAM, 2 GB swap
- [DataHub Helm chart defaults (datahub/values.yaml)](https://github.com/acryldata/datahub-helm/blob/master/charts/datahub/values.yaml) — upstream resource settings: GMS 2Gi limit, frontend 1400Mi, MAE/MCE 1536Mi each
- [DataHub prerequisites chart defaults (prerequisites/values.yaml)](https://github.com/acryldata/datahub-helm/blob/master/charts/prerequisites/values.yaml) — ES 1024M limit, Neo4j disabled, Kafka/ZK/MySQL unset
- [Migrating Graph Service Implementation](https://docs.datahub.com/docs/how/migrating-graph-service-implementation) — switching between Neo4j and ES graph backends
- [DataHub Performance Optimization (Acryl)](https://support.datahub.com/hc/en-us/articles/41912110701723-DataHub-Performance-Optimization) — production GMS recommendation: 4Gi-8Gi
- [DataHub GMS OOM discussion (GitHub #11147)](https://github.com/datahub-project/datahub/issues/11147) — memory requirements for GMS JVM
- [Elastic — JVM heap size on Kubernetes](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-jvm-heap-size.html) — heap should be ~50% of container memory
- [Minimal Elasticsearch Resources in Kubernetes](https://staffordwilliams.com/blog/2021/02/01/minimal-elasticsearch-resources-in-kubernetes/) — community benchmark: 512m heap is the practical minimum
- [Elastic Discuss — limit Elasticsearch to 512 MB](https://discuss.elastic.co/t/limit-elasticsearch-to-512-mb-on-kubernetes/234892) — Elastic engineer confirms 512MB heap is the minimum useful allocation

# DataSpoke Local Development Environment

This directory contains scripts and configuration to set up a complete local development environment for DataSpoke using a local Kubernetes cluster.

## Directory Structure

```
dev_env/
├── .env                   # Cluster configuration (edit before use)
├── README.md              # This file
└── datahub/               # DataHub installation scripts
    ├── install.sh         # Install DataHub via Helm
    ├── uninstall.sh       # Remove DataHub from the cluster
    ├── values.yaml        # DataHub Helm values (local dev tuning)
    └── prerequisites-values.yaml  # Kafka, Elasticsearch, MySQL values
```

## Prerequisites

Install the following tools before proceeding:

| Tool | Version | Install |
|------|---------|---------|
| `kubectl` | >= 1.25 | https://kubernetes.io/docs/tasks/tools/ |
| `helm` | >= 3.10 | https://helm.sh/docs/intro/install/ |
| Local Kubernetes cluster | — | Docker Desktop / kind / minikube |

## Configuration

All scripts read cluster settings from `.env` in this directory:

```dotenv
DATASPOKE_DEV_KUBE_CONTEXT=dockkube          # kubectl context name for your local cluster
DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE=datahub # Kubernetes namespace for DataHub
DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE=dataspoke # Kubernetes namespace for DataSpoke
```

Edit `.env` to match your local cluster before running any scripts.

To check your available kubectl contexts:

```bash
kubectl config get-contexts
```

---

## DataHub

[DataHub](https://datahubproject.io/) is an open-source metadata platform. The scripts in `datahub/` install DataHub and its backing services (Kafka, Elasticsearch, MySQL) into your local cluster using the [official DataHub Helm charts](https://helm.datahubproject.io/).

Pinned chart versions:

| Chart | Chart version | App version |
|-------|--------------|-------------|
| `datahub/datahub-prerequisites` | `0.2.1` | — |
| `datahub/datahub` | `0.8.3` | `v1.4.0` |

### Install

```bash
cd datahub
./install.sh
```

The script will:

1. Switch `kubectl` to the context defined in `.env` (`DATASPOKE_DEV_KUBE_CONTEXT`)
2. Add and update the `datahub` Helm repository
3. Create the target namespace (`DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE`) if it does not exist
4. Install **datahub-prerequisites** (Kafka + Zookeeper + Schema Registry + Elasticsearch + MySQL)
5. Install **datahub** (GMS, Frontend, MAE/MCE consumers, Actions)

Installation typically takes 5–10 minutes on first run while images are pulled.

### Access the DataHub UI

After installation, forward the frontend port to your local machine:

```bash
NAMESPACE=datahub   # or whatever is in your .env

kubectl port-forward \
  --namespace "$NAMESPACE" \
  $(kubectl get pods --namespace "$NAMESPACE" \
      -l 'app.kubernetes.io/name=datahub-frontend' \
      -o jsonpath='{.items[0].metadata.name}') \
  9002:9002
```

Then open [http://localhost:9002](http://localhost:9002) in your browser.

Default credentials:

| Field | Value |
|-------|-------|
| Username | `datahub` |
| Password | `datahub` |

### Verify the installation

```bash
# Check all pods are Running
kubectl get pods -n datahub

# Check Helm releases
helm list -n datahub
```

### Customise values

- `datahub/values.yaml` — tune DataHub component replicas and resource limits.
- `datahub/prerequisites-values.yaml` — tune Kafka, Elasticsearch, and MySQL settings.

Edit either file, then re-run `./install.sh` to apply changes (`helm upgrade` is idempotent).

### Uninstall

```bash
cd datahub
./uninstall.sh
```

The script will prompt for confirmation before removing Helm releases, and optionally delete the entire namespace.

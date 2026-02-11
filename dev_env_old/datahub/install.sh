#!/usr/bin/env bash
# install.sh — Install DataHub on a local Kubernetes cluster via Helm.
# Reads cluster configuration from ../.env
#
# Chart versions:
#   datahub-prerequisites : 0.2.1
#   datahub               : 0.8.3  (app v1.4.0)

DATAHUB_PREREQUISITES_CHART_VERSION="0.2.1"
DATAHUB_CHART_VERSION="0.8.3"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# ---------------------------------------------------------------------------
# Load environment variables
# ---------------------------------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found at $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck source=../.env
source "$ENV_FILE"
set +a

KUBE_CONTEXT="${DATASPOKE_DEV_KUBE_CONTEXT:?DATASPOKE_DEV_KUBE_CONTEXT is not set in .env}"
DATAHUB_NAMESPACE="${DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE:?DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE is not set in .env}"
MYSQL_ROOT_PASSWORD="${DATASPOKE_DEV_MYSQL_ROOT_PASSWORD:?DATASPOKE_DEV_MYSQL_ROOT_PASSWORD is not set in .env}"
MYSQL_PASSWORD="${DATASPOKE_DEV_MYSQL_PASSWORD:?DATASPOKE_DEV_MYSQL_PASSWORD is not set in .env}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

check_dependency() {
  command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed."
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
info "Checking dependencies..."
check_dependency kubectl
check_dependency helm

info "Switching to Kubernetes context: $KUBE_CONTEXT"
kubectl config use-context "$KUBE_CONTEXT" || error "Failed to switch to context '$KUBE_CONTEXT'. Is your cluster running?"

# ---------------------------------------------------------------------------
# Add / update Helm repositories
# ---------------------------------------------------------------------------
info "Adding DataHub Helm repository..."
helm repo add datahub https://helm.datahubproject.io/ 2>/dev/null || true

info "Updating Helm repositories..."
helm repo update

# ---------------------------------------------------------------------------
# Create namespace (idempotent)
# ---------------------------------------------------------------------------
info "Ensuring namespace '$DATAHUB_NAMESPACE' exists..."
kubectl get namespace "$DATAHUB_NAMESPACE" >/dev/null 2>&1 \
  || kubectl create namespace "$DATAHUB_NAMESPACE"

# ---------------------------------------------------------------------------
# Create mysql-secrets (required by datahub-prerequisites chart)
# ---------------------------------------------------------------------------
info "Creating 'mysql-secrets' Secret in namespace '$DATAHUB_NAMESPACE'..."
kubectl create secret generic mysql-secrets \
  --namespace "$DATAHUB_NAMESPACE" \
  --from-literal=mysql-root-password="$MYSQL_ROOT_PASSWORD" \
  --from-literal=mysql-password="$MYSQL_PASSWORD" \
  --save-config \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# Install prerequisites (Kafka, Elasticsearch, MySQL)
# ---------------------------------------------------------------------------
info "Installing DataHub prerequisites (Kafka, Elasticsearch, MySQL)..."
helm upgrade --install datahub-prerequisites datahub/datahub-prerequisites \
  --namespace "$DATAHUB_NAMESPACE" \
  --version "$DATAHUB_PREREQUISITES_CHART_VERSION" \
  --values "$SCRIPT_DIR/prerequisites-values.yaml" \
  --timeout 3m \
  --wait

# ---------------------------------------------------------------------------
# Install DataHub
# ---------------------------------------------------------------------------
info "Installing DataHub..."
helm upgrade --install datahub datahub/datahub \
  --namespace "$DATAHUB_NAMESPACE" \
  --version "$DATAHUB_CHART_VERSION" \
  --values "$SCRIPT_DIR/values.yaml" \
  --timeout 3m \
  --wait

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
info "DataHub installed successfully in namespace '$DATAHUB_NAMESPACE'."
info ""
info "To access the DataHub UI, run:"
info "  kubectl port-forward --namespace $DATAHUB_NAMESPACE \$(kubectl get pods --namespace $DATAHUB_NAMESPACE -l 'app.kubernetes.io/name=datahub-frontend' -o jsonpath='{.items[0].metadata.name}') 9002:9002"
info ""
info "Then open: http://localhost:9002  (default credentials: datahub / datahub)"

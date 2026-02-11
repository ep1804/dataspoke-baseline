#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
info()  { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Load configuration
# ---------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/../.env" ]]; then
  error ".env not found at $SCRIPT_DIR/../.env — run from dev_env/ and ensure .env exists."
fi
source "$SCRIPT_DIR/../.env"

echo ""
echo "=== Installing DataHub ==="
echo ""

# ---------------------------------------------------------------------------
# Verify required tools
# ---------------------------------------------------------------------------
info "Checking required tools..."
command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed or not in PATH."
command -v helm    >/dev/null 2>&1 || error "helm is not installed or not in PATH."
info "kubectl and helm are available."

# ---------------------------------------------------------------------------
# Switch Kubernetes context
# ---------------------------------------------------------------------------
info "Switching to Kubernetes context: ${DATASPOKE_KUBE_CLUSTER}"
kubectl config use-context "${DATASPOKE_KUBE_CLUSTER}"

# ---------------------------------------------------------------------------
# Add / update Helm repo
# ---------------------------------------------------------------------------
info "Adding/updating datahub Helm repository..."
if helm repo list 2>/dev/null | grep -q "^datahub"; then
  info "Helm repo 'datahub' already added — updating."
  helm repo update datahub
else
  helm repo add datahub https://helm.datahubproject.io/
  helm repo update datahub
fi

# ---------------------------------------------------------------------------
# Ensure namespace exists
# ---------------------------------------------------------------------------
if kubectl get namespace "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}" >/dev/null 2>&1; then
  info "Namespace '${DATASPOKE_KUBE_DATAHUB_NAMESPACE}' already exists."
else
  info "Creating namespace '${DATASPOKE_KUBE_DATAHUB_NAMESPACE}'..."
  kubectl create namespace "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}"
fi

# ---------------------------------------------------------------------------
# Create mysql-secrets (idempotent)
# ---------------------------------------------------------------------------
info "Creating mysql-secrets in namespace '${DATASPOKE_KUBE_DATAHUB_NAMESPACE}'..."
kubectl create secret generic mysql-secrets \
  --namespace "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}" \
  --from-literal=mysql-root-password="${DATASPOKE_MYSQL_ROOT_PASSWORD}" \
  --from-literal=mysql-password="${DATASPOKE_MYSQL_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# Create neo4j-secrets (idempotent)
# ---------------------------------------------------------------------------
info "Creating neo4j-secrets in namespace '${DATASPOKE_KUBE_DATAHUB_NAMESPACE}'..."
kubectl create secret generic neo4j-secrets \
  --namespace "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}" \
  --from-literal=neo4j-password="${DATASPOKE_NEO4J_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# Install datahub-prerequisites
# ---------------------------------------------------------------------------
info "Installing datahub-prerequisites (version 0.2.1)..."
helm upgrade --install datahub-prerequisites datahub/datahub-prerequisites \
  --version 0.2.1 \
  --namespace "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}" \
  --values "$SCRIPT_DIR/prerequisites-values.yaml" \
  --timeout 5m \
  --wait

# ---------------------------------------------------------------------------
# Install datahub
# ---------------------------------------------------------------------------
info "Installing datahub (version 0.8.3)..."
helm upgrade --install datahub datahub/datahub \
  --version 0.8.3 \
  --namespace "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}" \
  --values "$SCRIPT_DIR/values.yaml" \
  --timeout 5m \
  --wait

# ---------------------------------------------------------------------------
# Print access instructions
# ---------------------------------------------------------------------------
echo ""
info "DataHub installation complete."
echo ""
echo "Access the DataHub UI with:"
echo ""
echo "  kubectl port-forward \\"
echo "    --namespace ${DATASPOKE_KUBE_DATAHUB_NAMESPACE} \\"
echo "    \$(kubectl get pods -n ${DATASPOKE_KUBE_DATAHUB_NAMESPACE} \\"
echo "      -l 'app.kubernetes.io/name=datahub-frontend' \\"
echo "      -o jsonpath='{.items[0].metadata.name}') \\"
echo "    9002:9002"
echo ""
echo "  Open: http://localhost:9002"
echo "  Credentials: datahub / datahub"
echo ""

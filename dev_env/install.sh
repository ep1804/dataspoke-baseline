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
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  error ".env not found at $SCRIPT_DIR/.env — copy and edit it before running this script."
fi
source "$SCRIPT_DIR/.env"

echo ""
echo "=== Installing DataSpoke dev environment ==="
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
# Create namespaces (idempotent)
# ---------------------------------------------------------------------------
NAMESPACES=(
  "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}"
  "${DATASPOKE_KUBE_DATASPOKE_NAMESPACE}"
  "${DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE}"
)

for NS in "${NAMESPACES[@]}"; do
  if kubectl get namespace "${NS}" >/dev/null 2>&1; then
    info "Namespace '${NS}' already exists — skipping."
  else
    info "Creating namespace '${NS}'..."
    kubectl create namespace "${NS}"
  fi
done

# ---------------------------------------------------------------------------
# Install DataHub
# ---------------------------------------------------------------------------
info "Running datahub/install.sh..."
bash "$SCRIPT_DIR/datahub/install.sh"

# ---------------------------------------------------------------------------
# Install dataspoke1-example sources
# ---------------------------------------------------------------------------
info "Running dataspoke1-example/install.sh..."
bash "$SCRIPT_DIR/dataspoke1-example/install.sh"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Installation complete ==="
echo ""
echo "Namespaces:"
kubectl get namespaces "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}" \
  "${DATASPOKE_KUBE_DATASPOKE_NAMESPACE}" \
  "${DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE}" 2>/dev/null || true
echo ""
echo "DataHub UI port-forward:"
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
echo "Example sources port-forwards:"
echo ""
echo "  kubectl port-forward --namespace ${DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE} svc/example-mysql 3306:3306"
echo "  kubectl port-forward --namespace ${DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE} svc/example-postgres 5432:5432"
echo ""

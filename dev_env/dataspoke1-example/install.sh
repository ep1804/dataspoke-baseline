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
  error ".env not found at $SCRIPT_DIR/../.env"
fi
source "$SCRIPT_DIR/../.env"

echo ""
echo "=== Installing dataspoke1-example ==="
echo ""

NS="${DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE}"

# ---------------------------------------------------------------------------
# Ensure namespace exists
# ---------------------------------------------------------------------------
if kubectl get namespace "${NS}" >/dev/null 2>&1; then
  info "Namespace '${NS}' already exists."
else
  info "Creating namespace '${NS}'..."
  kubectl create namespace "${NS}"
fi

# ---------------------------------------------------------------------------
# Apply manifests
# ---------------------------------------------------------------------------
info "Applying manifests from $SCRIPT_DIR/manifests/..."
kubectl apply -f "$SCRIPT_DIR/manifests/" --namespace "${NS}"

# ---------------------------------------------------------------------------
# Wait for deployments to be ready
# ---------------------------------------------------------------------------
info "Waiting for MySQL deployment to be ready (timeout: 3m)..."
kubectl rollout status deployment/example-mysql \
  --namespace "${NS}" \
  --timeout=3m

info "Waiting for PostgreSQL deployment to be ready (timeout: 3m)..."
kubectl rollout status deployment/example-postgres \
  --namespace "${NS}" \
  --timeout=3m

# ---------------------------------------------------------------------------
# Print connection info
# ---------------------------------------------------------------------------
echo ""
info "dataspoke1-example installation complete."
echo ""
echo "Port-forward commands:"
echo ""
echo "  MySQL:"
echo "  kubectl port-forward --namespace ${NS} svc/example-mysql 3306:3306"
echo "  Connection: root / ExampleDev2024! — database: example_db"
echo ""
echo "  PostgreSQL:"
echo "  kubectl port-forward --namespace ${NS} svc/example-postgres 5432:5432"
echo "  Connection: postgres / ExampleDev2024! — database: example_db"
echo ""

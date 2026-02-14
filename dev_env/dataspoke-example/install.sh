#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------
# shellcheck source=../lib/helpers.sh
source "$SCRIPT_DIR/../lib/helpers.sh"

# ---------------------------------------------------------------------------
# Load configuration
# ---------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/../.env" ]]; then
  error ".env not found at $SCRIPT_DIR/../.env"
fi
source "$SCRIPT_DIR/../.env"

echo ""
echo "=== Installing dataspoke-example ==="
echo ""

NS="${DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE}"

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
info "Waiting for PostgreSQL deployment to be ready (timeout: 3m)..."
kubectl rollout status deployment/example-postgres \
  --namespace "${NS}" \
  --timeout=3m

# ---------------------------------------------------------------------------
# Print connection info
# ---------------------------------------------------------------------------
echo ""
info "dataspoke-example installation complete."
echo ""
echo "Port-forward command:"
echo ""
echo "  PostgreSQL:"
echo "  kubectl port-forward --namespace ${NS} svc/example-postgres 5432:5432"
echo "  Connection: postgres / ExampleDev2024! — database: example_db"
echo ""

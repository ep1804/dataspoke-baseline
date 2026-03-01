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
echo "=== Installing dev-env lock service ==="
echo ""

NS="${DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE}"
LOCK_PORT="${DATASPOKE_DEV_KUBE_DATASPOKE_PORT_FORWARD_DEV_ENV_LOCK_PORT:-9221}"

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
info "Applying lock service manifests to namespace '${NS}'..."
kubectl apply -f "$SCRIPT_DIR/manifests/" --namespace "${NS}"

# ---------------------------------------------------------------------------
# Wait for rollout
# ---------------------------------------------------------------------------
info "Waiting for dev-lock deployment to be ready (timeout: 2m)..."
kubectl rollout status deployment/dev-lock \
  --namespace "${NS}" \
  --timeout=2m

# ---------------------------------------------------------------------------
# Print access info
# ---------------------------------------------------------------------------
echo ""
info "Lock service installation complete."
echo ""
echo "Port-forward with:  ../lock-port-forward.sh"
echo ""
echo "  Lock API: localhost:${LOCK_PORT}   (-> dev-lock:8080)"
echo ""
echo "  GET    http://localhost:${LOCK_PORT}/lock              # status"
echo "  POST   http://localhost:${LOCK_PORT}/lock/acquire      # acquire"
echo "  POST   http://localhost:${LOCK_PORT}/lock/release      # release"
echo "  DELETE http://localhost:${LOCK_PORT}/lock              # force-release"
echo ""

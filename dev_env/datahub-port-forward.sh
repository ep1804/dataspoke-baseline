#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
info()  { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Load configuration
# ---------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  error ".env not found at $SCRIPT_DIR/.env — copy and edit it before running this script."
fi
source "$SCRIPT_DIR/.env"

NS="${DATASPOKE_KUBE_DATAHUB_NAMESPACE}"
PORT="${DATASPOKE_DEV_KUBE_DATAHUB_PORT_FORWARD_UI_PORT:-9002}"

# ---------------------------------------------------------------------------
# Switch context
# ---------------------------------------------------------------------------
kubectl config use-context "${DATASPOKE_KUBE_CLUSTER}" >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Find the frontend pod
# ---------------------------------------------------------------------------
POD=$(kubectl get pods -n "${NS}" \
  -l 'app.kubernetes.io/name=datahub-frontend' \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) \
  || error "No datahub-frontend pod found in namespace '${NS}'."

[[ -z "$POD" ]] && error "No datahub-frontend pod found in namespace '${NS}'."

# ---------------------------------------------------------------------------
# Port-forward
# ---------------------------------------------------------------------------
info "Forwarding ${NS}/${POD}:9002 → localhost:${PORT}"
echo ""
echo "  DataHub UI: http://localhost:${PORT}"
echo "  Credentials: datahub / datahub"
echo ""
echo "  Press Ctrl+C to stop."
echo ""

exec kubectl port-forward --namespace "${NS}" "${POD}" "${PORT}:9002"

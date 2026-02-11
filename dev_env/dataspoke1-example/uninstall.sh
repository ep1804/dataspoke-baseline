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
echo "=== Uninstalling dataspoke1-example ==="
echo ""

NS="${DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE}"

# ---------------------------------------------------------------------------
# Delete manifests
# ---------------------------------------------------------------------------
if kubectl get namespace "${NS}" >/dev/null 2>&1; then
  info "Deleting manifests from namespace '${NS}'..."
  kubectl delete -f "$SCRIPT_DIR/manifests/" --namespace "${NS}" --ignore-not-found=true
else
  warn "Namespace '${NS}' does not exist — nothing to delete."
fi

echo ""
info "dataspoke1-example resources removed."
echo ""

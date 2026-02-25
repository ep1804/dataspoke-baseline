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
echo "=== Uninstalling DataSpoke infrastructure ==="
echo ""

NS="${DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE}"

# ---------------------------------------------------------------------------
# Uninstall Helm release
# ---------------------------------------------------------------------------
if helm status dataspoke --namespace "${NS}" >/dev/null 2>&1; then
  info "Uninstalling Helm release 'dataspoke' from namespace '${NS}'..."
  helm uninstall dataspoke --namespace "${NS}"
else
  warn "Helm release 'dataspoke' not found in namespace '${NS}' — skipping."
fi

# ---------------------------------------------------------------------------
# Clean up secrets
# ---------------------------------------------------------------------------
for SECRET in dataspoke-postgres-secret dataspoke-redis-secret dataspoke-qdrant-secret; do
  if kubectl get secret "${SECRET}" -n "${NS}" >/dev/null 2>&1; then
    info "Deleting secret '${SECRET}'..."
    kubectl delete secret "${SECRET}" -n "${NS}"
  fi
done

echo ""
info "DataSpoke infrastructure removed."
echo ""

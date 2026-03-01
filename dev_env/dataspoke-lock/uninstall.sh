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
echo "=== Uninstalling dev-env lock service ==="
echo ""

NS="${DATASPOKE_DEV_KUBE_DATASPOKE_NAMESPACE}"

# ---------------------------------------------------------------------------
# Delete manifests (idempotent)
# ---------------------------------------------------------------------------
for RESOURCE in deployment/dev-lock service/dev-lock configmap/dev-lock-script; do
  if kubectl get "${RESOURCE}" -n "${NS}" >/dev/null 2>&1; then
    info "Deleting ${RESOURCE}..."
    kubectl delete "${RESOURCE}" -n "${NS}"
  else
    info "${RESOURCE} not found — skipping."
  fi
done

echo ""
info "Lock service removed."
echo ""

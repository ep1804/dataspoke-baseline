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
echo "=== Uninstalling DataHub ==="
echo ""

NS="${DATASPOKE_KUBE_DATAHUB_NAMESPACE}"

# ---------------------------------------------------------------------------
# Uninstall datahub
# ---------------------------------------------------------------------------
if helm status datahub --namespace "${NS}" >/dev/null 2>&1; then
  info "Uninstalling Helm release 'datahub' from namespace '${NS}'..."
  helm uninstall datahub --namespace "${NS}"
else
  warn "Helm release 'datahub' not found in namespace '${NS}' — skipping."
fi

# ---------------------------------------------------------------------------
# Uninstall datahub-prerequisites
# ---------------------------------------------------------------------------
if helm status datahub-prerequisites --namespace "${NS}" >/dev/null 2>&1; then
  info "Uninstalling Helm release 'datahub-prerequisites' from namespace '${NS}'..."
  helm uninstall datahub-prerequisites --namespace "${NS}"
else
  warn "Helm release 'datahub-prerequisites' not found in namespace '${NS}' — skipping."
fi

echo ""
info "DataHub Helm releases removed."
echo ""

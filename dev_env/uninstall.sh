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
  error ".env not found at $SCRIPT_DIR/.env"
fi
source "$SCRIPT_DIR/.env"

echo ""
echo "=== Uninstalling DataSpoke dev environment ==="
echo ""

# ---------------------------------------------------------------------------
# Confirm before proceeding
# ---------------------------------------------------------------------------
read -r -p "Remove all dev_env resources? [y/N] " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  info "Aborted — no changes made."
  exit 0
fi

echo ""

# ---------------------------------------------------------------------------
# Uninstall dataspoke1-example
# ---------------------------------------------------------------------------
if [[ -f "$SCRIPT_DIR/dataspoke1-example/uninstall.sh" ]]; then
  info "Running dataspoke1-example/uninstall.sh..."
  bash "$SCRIPT_DIR/dataspoke1-example/uninstall.sh"
else
  warn "dataspoke1-example/uninstall.sh not found — skipping."
fi

# ---------------------------------------------------------------------------
# Uninstall DataHub
# ---------------------------------------------------------------------------
if [[ -f "$SCRIPT_DIR/datahub/uninstall.sh" ]]; then
  info "Running datahub/uninstall.sh..."
  bash "$SCRIPT_DIR/datahub/uninstall.sh"
else
  warn "datahub/uninstall.sh not found — skipping."
fi

# ---------------------------------------------------------------------------
# Optionally delete namespaces
# ---------------------------------------------------------------------------
echo ""
NAMESPACES=(
  "${DATASPOKE_KUBE_DATAHUB_NAMESPACE}"
  "${DATASPOKE_KUBE_DATASPOKE_NAMESPACE}"
  "${DATASPOKE_KUBE_DATASPOKE_EXAMPLE_NAMESPACE}"
)

read -r -p "Delete namespaces (${NAMESPACES[*]})? [y/N] " CONFIRM_NS
if [[ "${CONFIRM_NS}" =~ ^[Yy]$ ]]; then
  for NS in "${NAMESPACES[@]}"; do
    if kubectl get namespace "${NS}" >/dev/null 2>&1; then
      info "Deleting namespace '${NS}'..."
      kubectl delete namespace "${NS}"
    else
      info "Namespace '${NS}' does not exist — skipping."
    fi
  done
  info "Namespaces deleted."
else
  info "Namespaces retained."
fi

echo ""
info "Uninstall complete."
echo ""

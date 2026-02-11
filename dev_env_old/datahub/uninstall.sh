#!/usr/bin/env bash
# uninstall.sh — Remove DataHub and its prerequisites from the local Kubernetes cluster.
# Reads cluster configuration from ../.env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# ---------------------------------------------------------------------------
# Load environment variables
# ---------------------------------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found at $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck source=../.env
source "$ENV_FILE"
set +a

KUBE_CONTEXT="${DATASPOKE_DEV_KUBE_CONTEXT:?DATASPOKE_DEV_KUBE_CONTEXT is not set in .env}"
DATAHUB_NAMESPACE="${DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE:?DATASPOKE_DEV_KUBE_DATAHUB_NAMESPACE is not set in .env}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

check_dependency() {
  command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed."
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
check_dependency kubectl
check_dependency helm

info "Switching to Kubernetes context: $KUBE_CONTEXT"
kubectl config use-context "$KUBE_CONTEXT" || error "Failed to switch to context '$KUBE_CONTEXT'."

# ---------------------------------------------------------------------------
# Confirmation prompt
# ---------------------------------------------------------------------------
read -r -p "This will uninstall DataHub from namespace '$DATAHUB_NAMESPACE'. Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
# Uninstall DataHub
# ---------------------------------------------------------------------------
if helm status datahub --namespace "$DATAHUB_NAMESPACE" >/dev/null 2>&1; then
  info "Uninstalling DataHub..."
  helm uninstall datahub --namespace "$DATAHUB_NAMESPACE"
else
  warn "Helm release 'datahub' not found in namespace '$DATAHUB_NAMESPACE'. Skipping."
fi

# ---------------------------------------------------------------------------
# Uninstall prerequisites
# ---------------------------------------------------------------------------
if helm status datahub-prerequisites --namespace "$DATAHUB_NAMESPACE" >/dev/null 2>&1; then
  info "Uninstalling DataHub prerequisites..."
  helm uninstall datahub-prerequisites --namespace "$DATAHUB_NAMESPACE"
else
  warn "Helm release 'datahub-prerequisites' not found in namespace '$DATAHUB_NAMESPACE'. Skipping."
fi

# ---------------------------------------------------------------------------
# Optionally delete the namespace
# ---------------------------------------------------------------------------
read -r -p "Delete namespace '$DATAHUB_NAMESPACE' as well? [y/N] " del_ns
if [[ "$del_ns" =~ ^[Yy]$ ]]; then
  info "Deleting namespace '$DATAHUB_NAMESPACE'..."
  kubectl delete namespace "$DATAHUB_NAMESPACE" --ignore-not-found
fi

info "Uninstall complete."

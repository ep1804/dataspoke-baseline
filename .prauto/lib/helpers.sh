# Shared shell helpers for prauto scripts.
# Source this file — do not execute directly.
# Usage: source "${SCRIPT_DIR}/lib/helpers.sh"

info()  { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

# Verify a command exists or exit with error.
ensure_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || error "'$cmd' is not installed or not in PATH."
}

# Load config.env and config.local.env from the prauto root.
# Usage: load_config "$PRAUTO_DIR"
load_config() {
  local prauto_dir="$1"

  if [[ ! -f "$prauto_dir/config.env" ]]; then
    error "config.env not found at $prauto_dir/config.env"
  fi
  # shellcheck source=../config.env
  source "$prauto_dir/config.env"

  if [[ ! -f "$prauto_dir/config.local.env" ]]; then
    error "config.local.env not found at $prauto_dir/config.local.env — copy config.local.env.example and edit it."
  fi
  # shellcheck source=../config.local.env
  source "$prauto_dir/config.local.env"
}

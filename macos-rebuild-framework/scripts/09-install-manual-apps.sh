#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_MANUAL_APPS; then
  log_info "Manual apps step skipped by profile"
  exit 0
fi

log_info "Installing vendor/manual applications (macOS)"

VENDOR_DIR="$ROOT_DIR/scripts/vendor"
[[ -d "$VENDOR_DIR" ]] || { log_info "No scripts/vendor directory"; exit 0; }

run_vendor_script() {
  local script_path="$1"
  [[ -f "$script_path" ]] || return 0
  run_cmd bash "$script_path"
}

# Run any install-*.sh in vendor (e.g. install-cursor.sh, install-docker-desktop.sh)
for script in "$VENDOR_DIR"/install-*.sh; do
  [[ -f "$script" ]] && run_vendor_script "$script"
done

log_info "Vendor/manual application stage completed"

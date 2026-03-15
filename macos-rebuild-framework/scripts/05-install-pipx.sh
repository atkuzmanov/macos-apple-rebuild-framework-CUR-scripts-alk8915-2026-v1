#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_PIPX; then
  log_info "pipx skipped by profile (INSTALL_PIPX=false)"
  exit 0
fi

# pipx is typically installed via brew (python + pipx) or pip
if ! command -v pipx >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    run_cmd brew install pipx
    run_cmd pipx ensurepath
  else
    log_warn "pipx not found; install with: brew install pipx && pipx ensurepath"
    exit 0
  fi
fi

manifest="$ROOT_DIR/manifests/pipx-packages.txt"
[[ -f "$manifest" ]] || { log_warn "No pipx-packages.txt; skipping"; exit 0; }

log_info "Installing pipx packages from $manifest"
while IFS= read -r app; do
  [[ -z "$app" || "$app" =~ ^# ]] && continue
  install_pipx_app "$app"
done < "$manifest"

log_info "pipx install complete"

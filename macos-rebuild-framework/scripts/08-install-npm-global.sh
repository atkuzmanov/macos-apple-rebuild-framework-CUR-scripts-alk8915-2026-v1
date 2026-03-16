#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_NPM_GLOBAL; then
  log_info "npm global packages skipped by profile (INSTALL_NPM_GLOBAL=false)"
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  log_warn "npm not found; install Node via brew install node"
  exit 0
fi

manifest="$ROOT_DIR/manifests/npm-global-packages.txt"
[[ -f "$manifest" ]] || { log_warn "No npm-global-packages.txt; skipping"; exit 0; }

log_info "Installing npm global packages from $manifest"
while IFS= read -r app; do
  [[ -z "$app" || "$app" =~ ^# ]] && continue
  install_npm_global "$app"
done < "$manifest"

log_info "npm global install complete"

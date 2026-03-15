#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_CARGO; then
  log_info "Cargo tools skipped by profile (INSTALL_CARGO=false)"
  exit 0
fi

if ! command -v cargo >/dev/null 2>&1; then
  log_info "Installing Rust/cargo via rustup"
  run_cmd curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck source=/dev/null
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
fi

manifest="$ROOT_DIR/manifests/cargo-packages.txt"
[[ -f "$manifest" ]] || { log_warn "No cargo-packages.txt; skipping"; exit 0; }

log_info "Installing cargo packages from $manifest"
while IFS= read -r app; do
  [[ -z "$app" || "$app" =~ ^# ]] && continue
  install_cargo_app "$app"
done < "$manifest"

log_info "Cargo install complete"

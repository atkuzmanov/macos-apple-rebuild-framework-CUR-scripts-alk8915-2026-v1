#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_BREW_CASKS; then
  log_info "Brew casks skipped by profile (INSTALL_BREW_CASKS=false)"
  exit 0
fi

# Ensure brew is on PATH
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

manifest="$ROOT_DIR/manifests/brew-casks.txt"
[[ -f "$manifest" ]] || { log_warn "No brew-casks.txt; skipping"; exit 0; }

log_info "Installing Homebrew casks from $manifest"
while IFS= read -r cask; do
  [[ -z "$cask" || "$cask" =~ ^# ]] && continue
  install_brew_cask "$cask"
done < "$manifest"

log_info "Brew casks install complete"

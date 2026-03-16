#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

# Ensure brew is on PATH
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

manifest="$ROOT_DIR/manifests/brew-packages.txt"
[[ -f "$manifest" ]] || die "Missing manifest: $manifest"

log_info "Installing Homebrew formulae from $manifest"
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
  install_brew_formula "$pkg"
done < "$manifest"

log_info "Brew formulae install complete"

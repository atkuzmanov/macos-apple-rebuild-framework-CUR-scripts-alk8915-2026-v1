#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_MAS_APPS; then
  log_info "Mac App Store apps skipped by profile (INSTALL_MAS_APPS=false)"
  exit 0
fi

[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

if ! command -v mas >/dev/null 2>&1; then
  log_info "Installing mas (Mac App Store CLI) via Homebrew"
  run_cmd brew install mas
fi

manifest="$ROOT_DIR/manifests/mas-apps.txt"
[[ -f "$manifest" ]] || { log_info "No mas-apps.txt; skipping"; exit 0; }

log_info "Installing Mac App Store apps from $manifest"
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  # First field is the app ID (numeric); trim whitespace (mas list can have leading spaces)
  id="$(echo "${line%% *}" | xargs)"
  if [[ -n "$id" && "$id" =~ ^[0-9]+$ ]]; then
    if mas list 2>/dev/null | grep -q "^$id "; then
      log_info "MAS app already installed: $id"
    else
      run_cmd mas install "$id" 2>/dev/null || log_warn "mas install $id failed (sign in to App Store?)"
    fi
  fi
done < "$manifest"

log_info "MAS apps step complete"

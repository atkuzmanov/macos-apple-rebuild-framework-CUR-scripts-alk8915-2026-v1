#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

manifest="$ROOT_DIR/manifests/brew-taps.txt"
[[ -f "$manifest" ]] || { log_info "No brew-taps.txt; skipping"; exit 0; }

log_info "Adding Homebrew taps from $manifest"
while IFS= read -r tap; do
  [[ -z "$tap" || "$tap" =~ ^# ]] && continue
  if brew tap | grep -qFx "$tap"; then
    log_info "Tap already added: $tap"
  else
    run_cmd brew tap "$tap"
  fi
done < "$manifest"

log_info "Brew taps step complete"

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

# Optional: if a Brewfile exists, run brew bundle. Coexists with manifest-based install.
# Place Brewfile in project root or in manifests/

[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

BREWFILE=""
for candidate in "$ROOT_DIR/Brewfile" "$ROOT_DIR/manifests/Brewfile"; do
  if [[ -f "$candidate" ]]; then
    BREWFILE="$candidate"
    break
  fi
done

if [[ -z "$BREWFILE" ]]; then
  log_info "No Brewfile found; skipping brew bundle (using manifests only)"
  exit 0
fi

log_info "Running brew bundle from $BREWFILE"
run_cmd brew bundle install --file="$BREWFILE" 2>/dev/null || log_warn "brew bundle had errors; check Brewfile and re-run if needed"
log_info "Brewfile step complete"

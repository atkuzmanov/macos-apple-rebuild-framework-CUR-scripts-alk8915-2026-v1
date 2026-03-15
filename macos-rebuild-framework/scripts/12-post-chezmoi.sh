#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature RUN_POST_CHEZMOI; then
  log_info "Post-chezmoi skipped by profile"
  exit 0
fi

# Default shell (e.g. zsh) — only suggest; actual chsh may need manual step
if [[ -n "${DEFAULT_SHELL:-}" ]] && [[ "$(basename "$SHELL")" != "$DEFAULT_SHELL" ]]; then
  log_info "Default shell is $SHELL; profile suggests DEFAULT_SHELL=$DEFAULT_SHELL"
  log_info "To change: chsh -s $(grep -E "/$DEFAULT_SHELL$" /etc/shells 2>/dev/null | head -1 || echo "/bin/$DEFAULT_SHELL")"
fi

log_info "Post-chezmoi step complete"

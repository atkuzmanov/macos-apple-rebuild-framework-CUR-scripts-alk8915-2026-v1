#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

log_info "Validating key commands"

required_cmds=(git curl jq)
[[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]] && required_cmds+=(brew)

if want_feature INSTALL_PIPX; then
  required_cmds+=(pipx)
fi

if want_feature ENABLE_DOCKER; then
  # Docker may be Docker Desktop (GUI) or colima; binary name can vary
  required_cmds+=(docker)
fi

missing=0
for cmd in "${required_cmds[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    log_info "OK: $cmd"
  else
    log_error "Missing command: $cmd"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  die "Validation failed"
fi

log_info "Validation passed"

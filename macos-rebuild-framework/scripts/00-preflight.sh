#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

log_info "Running preflight checks"
require_command bash
require_command grep
require_command awk
require_command tee

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This framework targets macOS (Darwin) only"
fi

# Prefer running as normal user; sudo used only where needed
if [[ "$EUID" -eq 0 ]] && [[ -z "${SUDO_USER:-}" ]]; then
  log_warn "Consider running as a normal user; sudo will be used only when required"
fi

log_info "OS: $(sw_vers -productName) $(sw_vers -productVersion)"
log_info "User: ${USER:-$(whoami)}"
log_info "Home: $HOME"
log_info "Profile: $PROFILE"

# Ensure we can run privileged commands when needed
if command -v sudo >/dev/null 2>&1; then
  run_cmd sudo -v 2>/dev/null || log_warn "sudo may prompt during install steps"
fi

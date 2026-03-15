#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

log_info "Preparing base system (macOS)"

# Ensure Xcode Command Line Tools are present (needed for git, make, etc.)
if ! command -v git >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
  log_info "Xcode Command Line Tools may be missing. Install with: xcode-select --install"
  if command -v xcode-select >/dev/null 2>&1; then
    run_cmd xcode-select --install 2>/dev/null || log_warn "Run 'xcode-select --install' manually if build tools are missing"
  fi
fi

# Accept Xcode license if present (non-interactive where possible)
if [[ -f /usr/bin/xcodebuild ]]; then
  run_cmd sudo xcodebuild -license accept 2>/dev/null || true
fi

log_info "System prep complete"

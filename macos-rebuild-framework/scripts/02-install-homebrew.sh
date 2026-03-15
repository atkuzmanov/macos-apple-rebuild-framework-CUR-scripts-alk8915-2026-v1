#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

log_info "Ensuring Homebrew is installed"

if command -v brew >/dev/null 2>&1; then
  log_info "Homebrew already installed at $(brew --prefix)"
  run_cmd brew update
  exit 0
fi

# Install Homebrew (non-interactive)
log_info "Installing Homebrew"
NONINTERACTIVE=1 run_cmd /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ensure brew is on PATH (Apple Silicon: /opt/homebrew/bin, Intel: /usr/local/bin)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="/opt/homebrew/bin:$PATH"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
  export PATH="/usr/local/bin:$PATH"
fi

if ! command -v brew >/dev/null 2>&1; then
  die "Homebrew install may have completed but brew is not in PATH. Add it and re-run."
fi

run_cmd brew update
log_info "Homebrew ready"

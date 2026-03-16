#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_CHEZMOI; then
  log_info "chezmoi installation skipped by profile"
  exit 0
fi

if command -v chezmoi >/dev/null 2>&1; then
  log_info "chezmoi already installed"
  exit 0
fi

# Install to a directory on PATH (Homebrew or ~/.local/bin)
if command -v brew >/dev/null 2>&1; then
  run_cmd brew install chezmoi
else
  run_shell 'sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"'
  log_info "chezmoi installed to ~/.local/bin (ensure it is on PATH)"
fi

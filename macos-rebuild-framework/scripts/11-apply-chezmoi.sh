#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature APPLY_CHEZMOI; then
  log_info "chezmoi apply skipped by profile"
  exit 0
fi

if ! command -v chezmoi >/dev/null 2>&1; then
  log_warn "chezmoi not found; skipping apply"
  exit 0
fi

if [[ -z "${CHEZMOI_REPO:-}" ]]; then
  log_info "CHEZMOI_REPO not set in profile; skipping chezmoi init/apply"
  exit 0
fi

if ! chezmoi data 2>/dev/null | grep -q .; then
  log_info "Initializing chezmoi from $CHEZMOI_REPO"
  run_cmd chezmoi init "$CHEZMOI_REPO"
fi

log_info "Applying chezmoi"
run_cmd chezmoi apply -v

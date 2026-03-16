#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_UV_TOOLS; then
  log_info "uv tools skipped by profile (INSTALL_UV_TOOLS=false)"
  exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    run_cmd brew install uv
  else
    log_warn "uv not found; install from https://github.com/astral-sh/uv or: pipx install uv"
    exit 0
  fi
fi

manifest="$ROOT_DIR/manifests/uv-tools.txt"
[[ -f "$manifest" ]] || { log_warn "No uv-tools.txt; skipping"; exit 0; }

log_info "Installing uv tools from $manifest"
while IFS= read -r app; do
  [[ -z "$app" || "$app" =~ ^# ]] && continue
  install_uv_tool "$app"
done < "$manifest"

log_info "uv tools install complete"

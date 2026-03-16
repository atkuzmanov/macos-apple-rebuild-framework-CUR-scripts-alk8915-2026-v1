#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if ! want_feature INSTALL_VSCODE_EXTENSIONS; then
  log_info "VS Code extensions skipped by profile (INSTALL_VSCODE_EXTENSIONS=false)"
  exit 0
fi

# Prefer 'code' (VS Code CLI); Cursor often ships as 'cursor' and may support --install-extension
for cli in code cursor; do
  if command -v "$cli" >/dev/null 2>&1; then
    CODECLI="$cli"
    break
  fi
done
[[ -z "${CODECLI:-}" ]] && { log_info "Neither 'code' nor 'cursor' in PATH; skipping VS Code extensions"; exit 0; }

manifest="$ROOT_DIR/manifests/vscode-extensions.txt"
[[ -f "$manifest" ]] || { log_info "No vscode-extensions.txt; skipping"; exit 0; }

log_info "Installing VS Code/Cursor extensions from $manifest (using $CODECLI)"
while IFS= read -r ext; do
  [[ -z "$ext" || "$ext" =~ ^# ]] && continue
  if "$CODECLI" --list-extensions 2>/dev/null | grep -Fxq "$ext"; then
    log_info "Extension already installed: $ext"
  else
    run_cmd "$CODECLI" --install-extension "$ext" 2>/dev/null || log_warn "Failed to install extension: $ext"
  fi
done < "$manifest"

log_info "VS Code extensions step complete"

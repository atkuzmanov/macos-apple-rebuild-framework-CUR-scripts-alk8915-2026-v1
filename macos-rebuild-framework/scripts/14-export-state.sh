#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export RUN_LOG="${RUN_LOG:-/dev/null}"
source "$ROOT_DIR/lib/common.sh"

if [[ -n "${RUN_EXPORTS:-}" ]] && ! want_feature RUN_EXPORTS; then
  log_info "State export skipped by profile (RUN_EXPORTS=false)"
  exit 0
fi

ensure_dir "$ROOT_DIR/state/exports"

# Ensure brew on PATH
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

log_info "Exporting package state (macOS)"

if command -v brew >/dev/null 2>&1; then
  brew list --formula | sort > "$ROOT_DIR/state/exports/brew-formula.txt"
  brew list --cask | sort > "$ROOT_DIR/state/exports/brew-casks.txt"
  brew tap | sort > "$ROOT_DIR/state/exports/brew-taps.txt"
  brew services list 2>/dev/null > "$ROOT_DIR/state/exports/brew-services.txt" || true
fi
mas list 2>/dev/null | sort > "$ROOT_DIR/state/exports/mas-list.txt" || true
for cli in code cursor; do
  if command -v "$cli" >/dev/null 2>&1; then
    $cli --list-extensions 2>/dev/null | sort > "$ROOT_DIR/state/exports/vscode-extensions.txt"
    break
  fi
done
pipx list --short 2>/dev/null | sort > "$ROOT_DIR/state/exports/pipx-packages.txt" || true
pipx list --json 2>/dev/null > "$ROOT_DIR/state/exports/pipx-list.json" || true
python3 -m pip freeze --user 2>/dev/null | sort > "$ROOT_DIR/state/exports/pip-user-packages.txt" || true
cargo install --list 2>/dev/null | awk -F' ' '/ v[0-9]/{print $1}' | sort -u > "$ROOT_DIR/state/exports/cargo-packages.txt" || true
uv tool list 2>/dev/null | awk '{print $1}' | sort -u > "$ROOT_DIR/state/exports/uv-tools.txt" || true
# Use directory listing instead of "npm list -g" (npm list can Abort trap:6 on macOS;
# also works when Node is broken e.g. icu4c upgrade). Try npm root first, fallback to common paths.
npm_root=""
if command -v npm >/dev/null 2>&1; then
  npm_root=$(npm root -g 2>/dev/null) || true
fi
[[ -z "$npm_root" || ! -d "$npm_root" ]] && for p in /usr/local/lib/node_modules /opt/homebrew/lib/node_modules /usr/local/Cellar/node/*/lib/node_modules "$HOME/.nvm/versions/node/"*/lib/node_modules; do
  [[ -d "$p" ]] && { npm_root="$p"; break; }
done
if [[ -n "$npm_root" && -d "$npm_root" ]]; then
  {
    for d in "$npm_root"/*; do
      [[ -d "$d" ]] || continue
      name=$(basename "$d")
      if [[ "$name" == @* ]]; then
        for p in "$d"/*; do [[ -d "$p" ]] && echo "${name}/$(basename "$p")"; done
      else
        echo "$name"
      fi
    done
  } | sort -u > "$ROOT_DIR/state/exports/npm-global-packages.txt"
fi

TIMESTAMP="$(date +%F-%H%M%S)"
MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo "unknown")"
cat > "$ROOT_DIR/state/exports/collection-info.txt" <<META
export_timestamp=$TIMESTAMP
macos_version=$MACOS_VERSION
hostname=$(hostname)
kernel=$(uname -r)
arch=$(uname -m)
META

# Copy to manifests/*-exported.txt for diff/review
cp "$ROOT_DIR/state/exports/brew-formula.txt" "$ROOT_DIR/manifests/brew-packages-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/brew-casks.txt" "$ROOT_DIR/manifests/brew-casks-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/brew-taps.txt" "$ROOT_DIR/manifests/brew-taps-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/mas-list.txt" "$ROOT_DIR/manifests/mas-apps-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/vscode-extensions.txt" "$ROOT_DIR/manifests/vscode-extensions-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/pipx-packages.txt" "$ROOT_DIR/manifests/pipx-packages-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/pip-user-packages.txt" "$ROOT_DIR/manifests/pip-user-packages-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/cargo-packages.txt" "$ROOT_DIR/manifests/cargo-packages-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/uv-tools.txt" "$ROOT_DIR/manifests/uv-tools-exported.txt" 2>/dev/null || true
cp "$ROOT_DIR/state/exports/npm-global-packages.txt" "$ROOT_DIR/manifests/npm-global-packages-exported.txt" 2>/dev/null || true

log_warn "Exports written to state/exports/ and manifests/*-exported.txt. Review diffs, then cp manifests/*-exported.txt to manifests/*.txt if satisfied, and commit."

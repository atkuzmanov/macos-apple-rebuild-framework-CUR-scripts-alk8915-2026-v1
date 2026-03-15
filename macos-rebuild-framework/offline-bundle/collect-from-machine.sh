#!/usr/bin/env bash
set -Eeuo pipefail

# Clone-this-machine (macOS): capture what's installed into a cache for offline install.
# Usage: ./collect-from-machine.sh [--lists-only] [output-dir]
# Default output: offline-bundle/clone-cache/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(cd "$SCRIPT_DIR" && pwd)"
ROOT_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"
LISTS_ONLY=0
CACHE_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lists-only) LISTS_ONLY=1; shift ;;
    -h|--help)    echo "Usage: $0 [--lists-only] [output-dir]"; exit 0 ;;
    *)            CACHE_ROOT="$1"; shift ;;
  esac
done
CACHE_ROOT="${CACHE_ROOT:-$BUNDLE_DIR/clone-cache}"

[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

BREW_DIR="$CACHE_ROOT/brew"
PIP_DIR="$CACHE_ROOT/pip"
PIPX_DIR="$CACHE_ROOT/pipx"
MANUAL_DIR="$CACHE_ROOT/vendor"
META_DIR="$CACHE_ROOT/meta"

if [[ -f "$ROOT_DIR/lib/common.sh" && -f "$ROOT_DIR/lib/logging.sh" ]]; then
  export RUN_LOG="${RUN_LOG:-/dev/null}"
  source "$ROOT_DIR/lib/common.sh"
  source "$ROOT_DIR/lib/logging.sh"
  log_info "Clone-from-machine (macOS): writing cache to $CACHE_ROOT"
else
  log_info() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
  log_warn() { printf '[%s] WARN: %s\n' "$(date '+%F %T')" "$*" >&2; }
fi

have() { command -v "$1" >/dev/null 2>&1; }
mkdir -p "$BREW_DIR" "$PIP_DIR/wheelhouse" "$PIPX_DIR/wheelhouse" "$MANUAL_DIR" "$META_DIR"

TIMESTAMP="$(date +%F-%H%M%S)"
MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo "unknown")"
cat > "$META_DIR/collection-info.txt" <<META
mode=clone-from-machine
lists_only=$LISTS_ONLY
collection_timestamp=$TIMESTAMP
macos_version=$MACOS_VERSION
hostname=$(hostname)
kernel=$(uname -r)
arch=$(uname -m)
META

# Homebrew: list formulae and casks; optionally copy cache
brew list --formula 2>/dev/null | sort > "$BREW_DIR/formula-list.txt" || true
brew list --cask 2>/dev/null | sort > "$BREW_DIR/cask-list.txt" || true
if [[ $LISTS_ONLY -eq 0 ]] && have brew; then
  log_info "Copying Homebrew cache (bottles)"
  HOMEBREW_CACHE="${HOMEBREW_CACHE:-$(brew --cache)}"
  [[ -d "$HOMEBREW_CACHE" ]] && cp -Rn "$HOMEBREW_CACHE"/* "$BREW_DIR/" 2>/dev/null || true
fi

# Pip user
if have python3 && python3 -m pip --version >/dev/null 2>&1; then
  python3 -m pip freeze --user > "$PIP_DIR/pip-user-freeze.txt" 2>/dev/null || true
  if [[ $LISTS_ONLY -eq 0 ]] && [[ -s "$PIP_DIR/pip-user-freeze.txt" ]]; then
    python3 -m pip download -r "$PIP_DIR/pip-user-freeze.txt" -d "$PIP_DIR/wheelhouse" 2>/dev/null || log_warn "Some pip wheels could not be downloaded"
  fi
fi

# Pipx
if have pipx; then
  pipx list --json > "$PIPX_DIR/pipx-list.json" 2>/dev/null || true
  if [[ -f "$PIPX_DIR/pipx-list.json" ]]; then
    python3 -c "
import json, sys
p = json.load(open('$PIPX_DIR/pipx-list.json'))
for name, m in sorted(p.get('venvs', {}).items()):
    spec = m.get('metadata', {}).get('main_package', {}).get('package_or_url') or name
    print(spec)
" 2>/dev/null > "$PIPX_DIR/pipx-specs.txt" || true
    if [[ $LISTS_ONLY -eq 0 ]] && [[ -s "$PIPX_DIR/pipx-specs.txt" ]]; then
      while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        python3 -m pip download -d "$PIPX_DIR/wheelhouse" "$spec" 2>/dev/null || true
      done < "$PIPX_DIR/pipx-specs.txt"
    fi
  fi
fi

# Cargo / uv / npm: lists only
cargo install --list 2>/dev/null | awk -F' ' '/ v[0-9]/{print $1}' | sort -u > "$META_DIR/cargo-packages.txt" || true
uv tool list 2>/dev/null | awk '{print $1}' | sort -u > "$META_DIR/uv-tools.txt" || true
npm list -g --depth=0 2>/dev/null | sed '1,1d' | sed 's/.* //' | cut -d@ -f1 | sort -u > "$META_DIR/npm-global-packages.txt" || true

# Vendor URLs
VENDOR_URLS="$ROOT_DIR/manifests/vendor-download-urls.txt"
if [[ $LISTS_ONLY -eq 0 ]] && [[ -f "$VENDOR_URLS" ]] && have curl; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"; line="$(echo "$line" | tr -s '\t ' ' ' | sed 's/^ *//;s/ *$//')"
    [[ -z "$line" ]] && continue
    url="${line%% *}"; rest="${line#* }"; rest="$(echo "$rest" | sed 's/^ *//;s/ *$//')"
    outname="${rest:-$(basename "${url%%\?*}")}"
    [[ -z "$outname" ]] && continue
    curl -L -f -s -S -o "$MANUAL_DIR/$outname" "$url" 2>/dev/null && log_info "Downloaded: $outname" || log_warn "Failed: $url"
  done < "$VENDOR_URLS"
fi

# Copy .dmg/.pkg from Downloads
if [[ $LISTS_ONLY -eq 0 ]]; then
  find "$HOME/Downloads" -maxdepth 1 -type f \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.zip' \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
    cp -n "$f" "$MANUAL_DIR/" 2>/dev/null || true
  done
  echo "Manual installers (.dmg, .pkg). See MANUAL-SOFTWARE-NOTES.txt." > "$MANUAL_DIR/README.txt"
  [[ -f "$MANUAL_DIR/MANUAL-SOFTWARE-NOTES.txt" ]] || echo "# Add notes: installer name, how to install" > "$MANUAL_DIR/MANUAL-SOFTWARE-NOTES.txt"
fi

log_info "Creating SHA256SUMS"
(cd "$CACHE_ROOT" && find . -type f ! -name 'SHA256SUMS' -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS) || true

if [[ $LISTS_ONLY -eq 1 ]]; then
  log_info "Lists only: written to $CACHE_ROOT"
else
  log_info "Clone cache created at: $CACHE_ROOT. Copy to target Mac and run: ./install-from-clone-cache.sh $CACHE_ROOT"
fi

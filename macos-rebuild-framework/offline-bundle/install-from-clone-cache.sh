#!/usr/bin/env bash
set -Eeuo pipefail

# Install from a clone cache produced by collect-from-machine.sh on macOS (no profile).
# Usage: ./install-from-clone-cache.sh [path-to-clone-cache]
# Default: same directory as this script, subdir clone-cache/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_ROOT="${1:-$SCRIPT_DIR/clone-cache}"
BREW_DIR="$CACHE_ROOT/brew"
PIP_DIR="$CACHE_ROOT/pip"
PIPX_DIR="$CACHE_ROOT/pipx"
MANUAL_DIR="$CACHE_ROOT/vendor"

[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

[[ -d "$CACHE_ROOT" ]] || { echo "Clone cache not found: $CACHE_ROOT" >&2; exit 1; }

if [[ -f "$CACHE_ROOT/SHA256SUMS" ]]; then
  log "Verifying checksums"
  (cd "$CACHE_ROOT" && shasum -a 256 -c SHA256SUMS) || log "WARN: checksum verification had errors; continuing."
fi

# Homebrew: use clone cache as HOMEBREW_CACHE and install from formula/cask lists
if have brew && [[ -d "$BREW_DIR" ]]; then
  log "Installing Homebrew formulae/casks from clone cache"
  export HOMEBREW_CACHE="$BREW_DIR"
  [[ -f "$BREW_DIR/formula-list.txt" ]] && while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    brew list --formula "$pkg" >/dev/null 2>&1 || brew install "$pkg"
  done < "$BREW_DIR/formula-list.txt"
  [[ -f "$BREW_DIR/cask-list.txt" ]] && while IFS= read -r cask; do
    [[ -z "$cask" ]] && continue
    brew list --cask "$cask" >/dev/null 2>&1 || brew install --cask "$cask"
  done < "$BREW_DIR/cask-list.txt"
  unset HOMEBREW_CACHE
fi

# Pip user from wheelhouse
if have python3 && [[ -d "$PIP_DIR/wheelhouse" && -f "$PIP_DIR/pip-user-freeze.txt" ]]; then
  log "Installing pip user packages from clone cache"
  python3 -m pip install --user --no-index --find-links "$PIP_DIR/wheelhouse" -r "$PIP_DIR/pip-user-freeze.txt" \
    || log "WARN: some pip packages could not be installed"
fi

# Pipx from wheelhouse
if have pipx && [[ -d "$PIPX_DIR/wheelhouse" && -f "$PIPX_DIR/pipx-specs.txt" ]]; then
  log "Installing pipx packages from clone cache"
  while IFS= read -r spec; do
    [[ -z "$spec" ]] && continue
    pipx install "$spec" --pip-args="--no-index --find-links $PIPX_DIR/wheelhouse" \
      || log "WARN: failed pipx: $spec"
  done < "$PIPX_DIR/pipx-specs.txt"
fi

if [[ -d "$MANUAL_DIR" ]]; then
  log "Manual installer directory: $MANUAL_DIR — install .dmg/.pkg manually as needed."
fi

log "Clone-cache installation pass completed."

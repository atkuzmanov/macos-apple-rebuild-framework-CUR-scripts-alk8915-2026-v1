#!/usr/bin/env bash
set -Eeuo pipefail

# Run when OFFLINE on macOS. Installs all packages from cache/ (populated by download-bundle.sh).
# Usage: ./install-from-bundle.sh --profile <macbook|mac-mini>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(cd "$SCRIPT_DIR" && pwd)"
ROOT_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"
CACHE_DIR="$BUNDLE_DIR/cache"

[[ -d "$CACHE_DIR" ]] || { echo "Error: cache/ not found. Run download-bundle.sh first when online."; exit 1; }

source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/logging.sh"

# Verify checksums (macOS uses shasum -a 256)
if [[ -f "$CACHE_DIR/SHA256SUMS" ]]; then
  (cd "$CACHE_DIR" && shasum -a 256 -c SHA256SUMS) || log_warn "Checksum verification had errors; continuing anyway."
fi

PROFILE=""
usage() {
  echo "Usage: $0 --profile <name>"
  echo "  Installs all software from cache/ (offline mode on macOS)."
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) log_error "Unknown: $1"; usage ;;
  esac
done

[[ -n "$PROFILE" ]] || usage
PROFILE_FILE="$ROOT_DIR/profiles/${PROFILE}.env"
[[ -f "$PROFILE_FILE" ]] || die "Profile not found: $PROFILE_FILE"
load_profile "$PROFILE_FILE"

# Ensure brew on PATH
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

log_info "Installing from offline bundle for profile: $PROFILE (macOS)"

# ---------------------------------------------------------------------------
# 1. Homebrew: use cached bottles (point HOMEBREW_CACHE at our cache)
# ---------------------------------------------------------------------------
if command -v brew >/dev/null 2>&1 && [[ -d "$CACHE_DIR/brew" ]]; then
  log_section "Homebrew: installing from cache"
  export HOMEBREW_CACHE="$CACHE_DIR/brew"
  if [[ -f "$ROOT_DIR/manifests/brew-packages.txt" ]]; then
    while IFS= read -r pkg; do
      [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
      brew list --formula "$pkg" >/dev/null 2>&1 || run_cmd brew install "$pkg"
    done < "$ROOT_DIR/manifests/brew-packages.txt"
  fi
  if want_feature INSTALL_BREW_CASKS && [[ -f "$ROOT_DIR/manifests/brew-casks.txt" ]]; then
    while IFS= read -r cask; do
      [[ -z "$cask" || "$cask" =~ ^# ]] && continue
      brew list --cask "$cask" >/dev/null 2>&1 || run_cmd brew install --cask "$cask"
    done < "$ROOT_DIR/manifests/brew-casks.txt"
  fi
  unset HOMEBREW_CACHE
fi

# ---------------------------------------------------------------------------
# 2. Pip user: install from wheelhouse
# ---------------------------------------------------------------------------
if [[ -d "$CACHE_DIR/pip/wheelhouse" && -f "$CACHE_DIR/pip/pip-user-freeze.txt" ]] && command -v python3 >/dev/null 2>&1; then
  log_section "Pip user: installing from cache"
  python3 -m pip install --user --no-index --find-links "$CACHE_DIR/pip/wheelhouse" -r "$CACHE_DIR/pip/pip-user-freeze.txt" \
    || log_warn "Some pip user packages could not be installed offline"
fi

# ---------------------------------------------------------------------------
# 3. Pipx: install from wheels
# ---------------------------------------------------------------------------
if want_feature INSTALL_PIPX && command -v pipx >/dev/null 2>&1 && [[ -f "$ROOT_DIR/manifests/pipx-packages.txt" ]]; then
  log_section "Pipx: installing from cache"
  while IFS= read -r app; do
    [[ -z "$app" || "$app" =~ ^# ]] && continue
    pipx list --short 2>/dev/null | grep -Fxq "$app" && continue
    whl="$(ls "$CACHE_DIR/pipx/"*"${app}"*.whl "$CACHE_DIR/pipx/${app}"*.whl 2>/dev/null | head -1)"
    [[ -n "$whl" && -f "$whl" ]] && run_cmd pipx install "$whl" || log_warn "No wheel for pipx: $app"
  done < "$ROOT_DIR/manifests/pipx-packages.txt"
fi

# ---------------------------------------------------------------------------
# 4. UV: install tools from wheels
# ---------------------------------------------------------------------------
if want_feature INSTALL_UV_TOOLS && command -v uv >/dev/null 2>&1 && [[ -f "$ROOT_DIR/manifests/uv-tools.txt" ]]; then
  log_section "UV: installing from cache"
  while IFS= read -r app; do
    [[ -z "$app" || "$app" =~ ^# ]] && continue
    uv tool list 2>/dev/null | awk '{print $1}' | grep -Fxq "$app" && continue
    whl="$(ls "$CACHE_DIR/uv/"*"${app}"*.whl "$CACHE_DIR/uv/${app}"*.whl 2>/dev/null | head -1)"
    [[ -n "$whl" && -f "$whl" ]] && run_cmd uv tool install "$whl" || log_warn "No wheel for uv: $app"
  done < "$ROOT_DIR/manifests/uv-tools.txt"
fi

# ---------------------------------------------------------------------------
# 5. NPM: install from packed tarballs
# ---------------------------------------------------------------------------
if want_feature INSTALL_NPM_GLOBAL && command -v npm >/dev/null 2>&1; then
  log_section "NPM: installing from cache"
  for tgz in "$CACHE_DIR/npm/"*.tgz; do
    [[ -f "$tgz" ]] && run_cmd npm install -g "$tgz"
  done
fi

# ---------------------------------------------------------------------------
# 6. Cargo: install from cached registry
# ---------------------------------------------------------------------------
if want_feature INSTALL_CARGO && command -v cargo >/dev/null 2>&1 && [[ -d "$CACHE_DIR/cargo/registry" ]]; then
  log_section "Cargo: installing from cached registry"
  export CARGO_HOME="$CACHE_DIR/cargo"
  while IFS= read -r app; do
    [[ -z "$app" || "$app" =~ ^# ]] && continue
    command -v "$app" >/dev/null 2>&1 || run_cmd cargo install "$app" --offline 2>/dev/null || log_warn "Cargo install failed (offline): $app"
  done < "$ROOT_DIR/manifests/cargo-packages.txt"
  unset CARGO_HOME
fi

# ---------------------------------------------------------------------------
# 7. Vendor: remind for .dmg/.pkg
# ---------------------------------------------------------------------------
if want_feature INSTALL_MANUAL_APPS && [[ -d "$CACHE_DIR/vendor" ]]; then
  log_section "Vendor: manual installers in $CACHE_DIR/vendor — install .dmg/.pkg manually as needed."
fi

log_section "Offline installation complete"

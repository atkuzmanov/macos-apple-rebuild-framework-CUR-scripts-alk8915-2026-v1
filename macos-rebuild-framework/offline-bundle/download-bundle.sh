#!/usr/bin/env bash
set -Eeuo pipefail

# Run when ONLINE. Downloads all packages from manifests into cache/ for offline use on macOS.
# Usage: ./download-bundle.sh --profile <macbook|mac-mini> [--output-dir <path>] [--cache-dir <path>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(cd "$SCRIPT_DIR" && pwd)"
ROOT_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"

source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/logging.sh"

# Ensure brew on PATH
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

PROFILE=""
OUTPUT_DIR=""
CACHE_DIR_PARAM=""
usage() {
  echo "Usage: $0 --profile <name> [--output-dir <path>] [--cache-dir <path>]"
  echo "       $0 --profile=<name> [--output-dir=<path>] [--cache-dir=<path>]"
  echo "  Downloads all software from manifests into cache/ for offline installation on macOS."
  echo "  --output-dir  Optional. Final destination for the bundle (default: offline-bundle/cache)."
  echo "  --cache-dir   Optional. Fast temp storage during downloads (e.g. SSD)."
  echo "                When set, downloads go here first, then are copied to --output-dir."
  echo "                Use with --output-dir for: fast cache + slow long-term storage."
  exit 1
}

resolve_path() {
  local p="$1"
  # Normalize backslash-escaped spaces to actual spaces (avoids creating dirs with literal \ in names)
  while [[ "$p" == *'\ '* ]]; do
    p="${p//\\ / }"
  done
  p="${p/#\~/$HOME}"
  [[ "$p" != /* ]] && p="$(pwd)/$p"
  echo "$p"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --profile)   PROFILE="${2:-}"; shift 2 ;;
    --output-dir=*) OUTPUT_DIR="${1#*=}"; shift ;;
    --output-dir)   OUTPUT_DIR="${2:-}"; shift 2 ;;
    --cache-dir=*) CACHE_DIR_PARAM="${1#*=}"; shift ;;
    --cache-dir)   CACHE_DIR_PARAM="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) log_error "Unknown: $1"; usage ;;
  esac
done

# OUTPUT_DIR = final destination (slow HDD for long-term storage)
if [[ -n "$OUTPUT_DIR" ]]; then
  CACHE_DIR="$(resolve_path "$OUTPUT_DIR")"
  log_info "Output directory (final): $CACHE_DIR"
else
  CACHE_DIR="$BUNDLE_DIR/cache"
fi

# WORK_DIR = where downloads happen (fast SSD if --cache-dir, else same as output)
if [[ -n "$CACHE_DIR_PARAM" ]]; then
  WORK_DIR="$(resolve_path "$CACHE_DIR_PARAM")"
  log_info "Cache directory (during download): $WORK_DIR"
  USE_SEPARATE_CACHE=1
else
  WORK_DIR="$CACHE_DIR"
  USE_SEPARATE_CACHE=0
fi

[[ -n "$PROFILE" ]] || usage
PROFILE_FILE="$ROOT_DIR/profiles/${PROFILE}.env"
[[ -f "$PROFILE_FILE" ]] || die "Profile not found: $PROFILE_FILE"
load_profile "$PROFILE_FILE"
log_info "Creating offline bundle for profile: $PROFILE (macOS)"

mkdir -p "$WORK_DIR"/{brew,pip,pipx,uv,npm,cargo,vendor,meta}

# Redirect all tool caches to WORK_DIR (fast drive when --cache-dir is set)
export HOMEBREW_CACHE="$WORK_DIR/brew"
export PIP_CACHE_DIR="$WORK_DIR/pip/.pip-cache"
export npm_config_cache="$WORK_DIR/npm/.npm-cache"
export CARGO_HOME="$WORK_DIR/cargo"
log_info "Tool caches redirected to $( ((USE_SEPARATE_CACHE)) && echo "cache dir" || echo "output dir")"

TIMESTAMP="$(date +%F-%H%M%S)"
MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo "unknown")"
cat > "$WORK_DIR/meta/collection-info.txt" <<META
profile=$PROFILE
collection_timestamp=$TIMESTAMP
macos_version=$MACOS_VERSION
hostname=$(hostname)
kernel=$(uname -r)
arch=$(uname -m)
META

# ---------------------------------------------------------------------------
# 1. Homebrew: fetch formulae and casks (bottles) into cache
# ---------------------------------------------------------------------------
if command -v brew >/dev/null 2>&1; then
  log_section "Homebrew: fetching formulae and casks"

  brew_pkgs=()
  [[ -f "$ROOT_DIR/manifests/brew-packages.txt" ]] && while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    brew_pkgs+=("$pkg")
  done < "$ROOT_DIR/manifests/brew-packages.txt"

  if ((${#brew_pkgs[@]} > 0)); then
    log_info "Fetching ${#brew_pkgs[@]} formulae"
    run_cmd brew fetch "${brew_pkgs[@]}" --force 2>/dev/null || true
  fi

  if want_feature INSTALL_BREW_CASKS && [[ -f "$ROOT_DIR/manifests/brew-casks.txt" ]]; then
    cask_list=()
    while IFS= read -r cask; do
      [[ -z "$cask" || "$cask" =~ ^# ]] && continue
      cask_list+=("$cask")
    done < "$ROOT_DIR/manifests/brew-casks.txt"
    if ((${#cask_list[@]} > 0)); then
      log_info "Fetching ${#cask_list[@]} casks"
      for c in "${cask_list[@]}"; do run_cmd brew fetch --cask "$c" 2>/dev/null || true; done
    fi
  fi

  # Save list of formulae/casks we expect (for install-from-bundle)
  brew list --formula 2>/dev/null | sort > "$WORK_DIR/brew/formula-list.txt" || true
  brew list --cask 2>/dev/null | sort > "$WORK_DIR/brew/cask-list.txt" || true
fi

# ---------------------------------------------------------------------------
# 2. Pip user: download from manifest into wheelhouse
# ---------------------------------------------------------------------------
if [[ -f "$ROOT_DIR/manifests/pip-user-packages.txt" ]] && command -v python3 >/dev/null 2>&1; then
  pip_user_list=()
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    pip_user_list+=("$pkg")
  done < "$ROOT_DIR/manifests/pip-user-packages.txt"
  if ((${#pip_user_list[@]} > 0)); then
    log_section "Pip user: downloading packages"
    printf '%s\n' "${pip_user_list[@]}" > "$WORK_DIR/pip/pip-user-freeze.txt"
    python3 -m pip download -r "$WORK_DIR/pip/pip-user-freeze.txt" -d "$WORK_DIR/pip/wheelhouse" \
      || log_warn "Some pip user wheels could not be downloaded"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Pipx: download wheels
# ---------------------------------------------------------------------------
if want_feature INSTALL_PIPX && [[ -f "$ROOT_DIR/manifests/pipx-packages.txt" ]]; then
  log_section "Pipx: downloading wheels"
  while IFS= read -r app; do
    [[ -z "$app" || "$app" =~ ^# ]] && continue
    pip download "$app" -d "$WORK_DIR/pipx" 2>/dev/null || log_warn "Pip download failed: $app"
  done < "$ROOT_DIR/manifests/pipx-packages.txt"
fi

# ---------------------------------------------------------------------------
# 4. UV: download tool wheels
# ---------------------------------------------------------------------------
if want_feature INSTALL_UV_TOOLS && command -v uv >/dev/null 2>&1 && [[ -f "$ROOT_DIR/manifests/uv-tools.txt" ]]; then
  log_section "UV: downloading tools"
  while IFS= read -r app; do
    [[ -z "$app" || "$app" =~ ^# ]] && continue
    pip download "$app" -d "$WORK_DIR/uv" 2>/dev/null || log_warn "UV/pip download failed: $app"
  done < "$ROOT_DIR/manifests/uv-tools.txt"
fi

# ---------------------------------------------------------------------------
# 5. NPM: pack global packages
# ---------------------------------------------------------------------------
if want_feature INSTALL_NPM_GLOBAL && command -v npm >/dev/null 2>&1 && [[ -f "$ROOT_DIR/manifests/npm-global-packages.txt" ]]; then
  log_section "NPM: packing packages"
  while IFS= read -r app; do
    [[ -z "$app" || "$app" =~ ^# ]] && continue
    (cd "$WORK_DIR/npm" && npm pack "$app" 2>/dev/null) || log_warn "NPM pack failed: $app"
  done < "$ROOT_DIR/manifests/npm-global-packages.txt"
fi

# ---------------------------------------------------------------------------
# 6. Cargo: pre-fetch and copy registry
# ---------------------------------------------------------------------------
if want_feature INSTALL_CARGO && command -v cargo >/dev/null 2>&1 && [[ -f "$ROOT_DIR/manifests/cargo-packages.txt" ]]; then
  log_section "Cargo: fetching crates"
  while IFS= read -r app; do
    [[ -z "$app" || "$app" =~ ^# ]] && continue
    cargo install "$app" 2>/dev/null || log_warn "Cargo install failed: $app"
  done < "$ROOT_DIR/manifests/cargo-packages.txt"
fi

# ---------------------------------------------------------------------------
# 7. Vendor: copy manual installers
# ---------------------------------------------------------------------------
if [[ -n "${OFFLINE_VENDOR_SOURCE_DIR:-}" && -d "$OFFLINE_VENDOR_SOURCE_DIR" ]]; then
  log_section "Vendor: copying from $OFFLINE_VENDOR_SOURCE_DIR"
  run_cmd cp -a "$OFFLINE_VENDOR_SOURCE_DIR"/* "$WORK_DIR/vendor/" 2>/dev/null || true
fi

cat > "$WORK_DIR/vendor/README.txt" <<'VENDORREADME'
Place manual installers here (.dmg, .pkg, .app from vendor sites).
See MANUAL-SOFTWARE-NOTES.txt for install steps.
VENDORREADME
[[ -f "$WORK_DIR/vendor/MANUAL-SOFTWARE-NOTES.txt" ]] || printf '%s\n' "# Add notes: installer name, how to install, license/post-install" > "$WORK_DIR/vendor/MANUAL-SOFTWARE-NOTES.txt"

# Checksums
log_section "Creating checksum manifest"
(cd "$WORK_DIR" && find . -type f ! -name 'SHA256SUMS' -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS) || true

# Copy from fast cache to output dir if using separate cache
if ((USE_SEPARATE_CACHE)); then
  log_section "Copying to output directory"
  log_info "Copying from $WORK_DIR to $CACHE_DIR"
  mkdir -p "$CACHE_DIR"
  run_cmd rsync -a --delete "$WORK_DIR/" "$CACHE_DIR/" 2>/dev/null || run_cmd cp -a "$WORK_DIR"/. "$CACHE_DIR/" 2>/dev/null || true
  log_info "Copy complete. You may remove the cache dir to free space: $WORK_DIR"
fi

log_section "Download complete"
log_info "Cache size: $(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)"
log_info "Copy the entire offline-bundle folder to external storage (USB/HDD)."
log_info "On target Mac, run: ./install-from-bundle.sh --profile $PROFILE"

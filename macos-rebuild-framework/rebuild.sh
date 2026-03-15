#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=lib/logging.sh
source "$ROOT_DIR/lib/logging.sh"

PROFILE=""
DRY_RUN=0
ONLY_STEP=""
declare -a SKIP_STEPS=()

usage() {
  cat <<USAGE
Usage: $0 --profile <name> [options]

Options:
  --profile <name>          Profile name from profiles/<name>.env
  --dry-run                  Print actions without executing them
  --only-step <script>       Run only one script from scripts/
  --skip-step <script>       Skip a script from scripts/ (repeatable)
  -h, --help                 Show this help
USAGE
}

require_arg() {
  local flag="$1"
  local value="${2:-}"
  [[ -n "$value" ]] || die "Missing value for $flag"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      require_arg "$1" "${2:-}"
      PROFILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --only-step)
      require_arg "$1" "${2:-}"
      ONLY_STEP="$2"
      shift 2
      ;;
    --skip-step)
      require_arg "$1" "${2:-}"
      SKIP_STEPS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$PROFILE" ]] || die "You must pass --profile <name>"

PROFILE_FILE="$ROOT_DIR/profiles/${PROFILE}.env"
[[ -f "$PROFILE_FILE" ]] || die "Profile file not found: $PROFILE_FILE"

export DRY_RUN
export PROFILE
export PROFILE_FILE

mkdir -p "$ROOT_DIR/logs" "$ROOT_DIR/state/exports"
TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
export RUN_LOG="$ROOT_DIR/logs/rebuild-${PROFILE}-${TIMESTAMP}.log"

load_profile "$PROFILE_FILE"
log_info "Loaded profile: $PROFILE"
log_info "Log file: $RUN_LOG"

STEPS=(
  "00-preflight.sh"
  "01-system-prep.sh"
  "02-install-homebrew.sh"
  "02b-install-brew-taps.sh"
  "02c-install-brewfile.sh"
  "03-install-brew-packages.sh"
  "04-install-brew-casks.sh"
  "04b-install-mas-apps.sh"
  "04c-install-vscode-extensions.sh"
  "05-install-pipx.sh"
  "06-install-cargo.sh"
  "07-install-uv-tools.sh"
  "08-install-npm-global.sh"
  "09-install-manual-apps.sh"
  "10-install-chezmoi.sh"
  "11-apply-chezmoi.sh"
  "12-post-chezmoi.sh"
  "13-validate.sh"
  "14-export-state.sh"
  "98-manual-checklist.sh"
)

is_skipped() {
  local step="$1"
  local item
  for item in "${SKIP_STEPS[@]:-}"; do
    [[ "$item" == "$step" ]] && return 0
  done
  return 1
}

step_exists() {
  local step="$1"
  [[ -f "$ROOT_DIR/scripts/$step" ]]
}

if [[ -n "$ONLY_STEP" ]]; then
  step_exists "$ONLY_STEP" || die "Only-step script not found: $ONLY_STEP"
fi

run_step() {
  local step="$1"
  local path="$ROOT_DIR/scripts/$step"

  step_exists "$step" || die "Missing step: $path"

  if [[ -n "$ONLY_STEP" && "$step" != "$ONLY_STEP" ]]; then
    return 0
  fi

  if is_skipped "$step"; then
    log_warn "Skipping step: $step"
    return 0
  fi

  log_section "Running $step"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "Dry run: would execute $path"
    return 0
  fi

  if ! bash "$path" 2>&1 | tee -a "$RUN_LOG"; then
    die "Step failed: $step"
  fi
}

for step in "${STEPS[@]}"; do
  run_step "$step"
done

log_section "Rebuild completed"

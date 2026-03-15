#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/logging.sh
source "$ROOT_DIR/lib/logging.sh"
# shellcheck source=lib/packages.sh
source "$ROOT_DIR/lib/packages.sh"

die() {
  log_error "$*"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

run_cmd() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Dry run: $*"
  else
    log_info "Running: $*"
    "$@"
  fi
}

run_shell() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Dry run: $*"
  else
    log_info "Running shell: $*"
    bash -lc "$*"
  fi
}

load_profile() {
  local file="$1"
  # shellcheck disable=SC1090
  source "$file"
}

ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || run_cmd mkdir -p "$dir"
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

file_has_line() {
  local line="$1"
  local file="$2"
  [[ -f "$file" ]] && grep -Fqx "$line" "$file"
}

append_line_if_missing() {
  local line="$1"
  local file="$2"
  ensure_dir "$(dirname "$file")"
  if file_has_line "$line" "$file"; then
    log_info "Line already present in $file: $line"
  else
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      log_info "Dry run: append to $file: $line"
    else
      printf '%s\n' "$line" >> "$file"
      log_info "Appended line to $file: $line"
    fi
  fi
}

want_feature() {
  local var_name="$1"
  local val="${!var_name:-false}"
  is_true "$val"
}

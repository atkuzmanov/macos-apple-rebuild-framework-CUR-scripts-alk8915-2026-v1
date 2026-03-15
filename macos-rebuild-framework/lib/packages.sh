#!/usr/bin/env bash

# Homebrew formulae
brew_formula_installed() {
  brew list --formula "$1" >/dev/null 2>&1
}

install_brew_formula() {
  local pkg="$1"
  if brew_formula_installed "$pkg"; then
    log_info "Homebrew formula already installed: $pkg"
  else
    run_cmd brew install "$pkg"
  fi
}

# Homebrew casks
brew_cask_installed() {
  brew list --cask "$1" >/dev/null 2>&1
}

install_brew_cask() {
  local cask="$1"
  if brew_cask_installed "$cask"; then
    log_info "Homebrew cask already installed: $cask"
  else
    run_cmd brew install --cask "$cask"
  fi
}

# pipx
pipx_app_installed() {
  pipx list --short 2>/dev/null | grep -Fxq "$1"
}

install_pipx_app() {
  local app="$1"
  if pipx_app_installed "$app"; then
    log_info "pipx app already installed: $app"
  else
    run_cmd pipx install "$app"
  fi
}

# cargo
cargo_app_installed() {
  command -v "$1" >/dev/null 2>&1
}

install_cargo_app() {
  local app="$1"
  if cargo_app_installed "$app"; then
    log_info "cargo app already present in PATH: $app"
  else
    run_cmd cargo install "$app"
  fi
}

# uv
uv_tool_installed() {
  uv tool list 2>/dev/null | awk '{print $1}' | grep -Fxq "$1"
}

install_uv_tool() {
  local app="$1"
  if uv_tool_installed "$app"; then
    log_info "uv tool already installed: $app"
  else
    run_cmd uv tool install "$app"
  fi
}

# npm global
npm_global_installed() {
  npm list -g --depth=0 2>/dev/null | grep -Fq " $1@"
}

install_npm_global() {
  local app="$1"
  if npm_global_installed "$app"; then
    log_info "npm global package already installed: $app"
  else
    run_cmd npm install -g "$app"
  fi
}

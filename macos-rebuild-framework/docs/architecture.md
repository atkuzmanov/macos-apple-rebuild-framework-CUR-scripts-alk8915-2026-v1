# Architecture (macOS Rebuild Framework)

This document explains the architecture of the macOS rebuild framework.

## Design Principles

- Idempotent scripts
- Clear responsibility boundaries
- Layered execution stages
- Profile-based configuration
- Minimal hidden logic

The framework is designed so that a Mac (e.g. MacBook Pro) can be rebuilt safely and repeatedly from manifests and optional offline bundles.

## Execution Flow

The rebuild process is orchestrated by `rebuild.sh` and runs scripts in order:

1. `00-preflight.sh` – sanity checks (macOS only, user, basic tools)
2. `01-system-prep.sh` – Xcode CLT, license
3. `02-install-homebrew.sh` – Homebrew install/update
4. `03-install-brew-packages.sh` – Homebrew formulae from manifest
5. `04-install-brew-casks.sh` – Homebrew casks (GUI apps) from manifest
6. `05-install-pipx.sh` – pipx tools
7. `06-install-cargo.sh` – Rust/cargo tools
8. `07-install-uv-tools.sh` – uv tools
9. `08-install-npm-global.sh` – npm global packages
10. `09-install-manual-apps.sh` – vendor/manual installers
11. `10-install-chezmoi.sh` – install chezmoi
12. `11-apply-chezmoi.sh` – apply dotfiles
13. `12-post-chezmoi.sh` – post configuration
14. `13-validate.sh` – validation checks
15. `14-export-state.sh` – export installed state to state/exports and manifests/*-exported.txt
16. `98-manual-checklist.sh` – manual checklist

## Responsibility Boundaries

### Rebuild Scripts

- Installing packages (Homebrew, pipx, cargo, uv, npm)
- Installing development tooling
- Running vendor installers

### Chezmoi

- Configuration files
- Shell setup
- Git configuration
- Editor and user-level preferences

### Profiles

Profiles (e.g. `macbook`, `mac-mini`) control which components are installed and which features are enabled (Docker, backup tools, GUI apps, etc.).

## State Export

`scripts/14-export-state.sh` exports the current machine state (brew list, pipx, cargo, uv, npm, pip --user) into `state/exports/` and copies exported lists to `manifests/*-exported.txt` so you can diff and update manifests.

## Offline Bundle

- **download-bundle.sh** – When online, downloads all manifest-based software into `offline-bundle/cache/`.
- **install-from-bundle.sh** – When offline, installs from that cache using the same profile.
- **collect-from-machine.sh** – Captures the current Mac’s installed set into `clone-cache/` (no manifests).
- **install-from-clone-cache.sh** – Installs from a clone cache on another Mac.

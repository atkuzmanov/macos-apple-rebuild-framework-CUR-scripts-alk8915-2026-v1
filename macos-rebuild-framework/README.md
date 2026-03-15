# macOS Rebuild Framework

A production-ready, idempotent rebuild framework for macOS machines (e.g. MacBook Pro, Mac mini).

Design rule:

- **Rebuild scripts own installation and orchestration**
- **chezmoi owns dotfiles and user configuration**

Chezmoi is a stage in the process, not the foundation.

## Offline / Air-Gapped Setup

To prepare for installations **without internet** (e.g. USB, external drive):

1. Run `./offline-bundle/download-bundle.sh --profile macbook` (while online)
2. Copy the entire `offline-bundle/` folder (including `cache/`) to external storage
3. On the target Mac: `./offline-bundle/install-from-bundle.sh --profile macbook`

See `offline-bundle/README.md` for details and the “clone this Mac” workflow.

## Directory Tree

```text
macos-rebuild-framework/
├── README.md
├── rebuild.sh
├── lib/
│   ├── common.sh
│   ├── logging.sh
│   └── packages.sh
├── manifests/
│   ├── brew-packages.txt
│   ├── brew-casks.txt
│   ├── pipx-packages.txt
│   ├── cargo-packages.txt
│   ├── uv-tools.txt
│   ├── npm-global-packages.txt
│   ├── pip-user-packages.txt
│   ├── manual-downloads.txt
│   └── vendor-download-urls.txt
├── profiles/
│   ├── macbook.env
│   └── mac-mini.env
├── offline-bundle/
│   ├── README.md
│   ├── download-bundle.sh
│   ├── install-from-bundle.sh
│   ├── collect-from-machine.sh
│   ├── install-from-clone-cache.sh
│   └── cache/                # Populated by download-bundle.sh
├── scripts/
│   ├── 00-preflight.sh
│   ├── 01-system-prep.sh
│   ├── 02-install-homebrew.sh
│   ├── 03-install-brew-packages.sh
│   ├── 04-install-brew-casks.sh
│   ├── 05-install-pipx.sh
│   ├── 06-install-cargo.sh
│   ├── 07-install-uv-tools.sh
│   ├── 08-install-npm-global.sh
│   ├── 09-install-manual-apps.sh
│   ├── 10-install-chezmoi.sh
│   ├── 11-apply-chezmoi.sh
│   ├── 12-post-chezmoi.sh
│   ├── 13-validate.sh
│   ├── 14-export-state.sh
│   ├── 98-manual-checklist.sh
│   └── vendor/               # Optional install-*.sh scripts
├── state/
│   └── exports/
└── logs/
```

## Intended Flow

1. Fresh or existing macOS install
2. Clone this repo (or copy the folder)
3. Run `./rebuild.sh --profile macbook`
4. Let the framework install Homebrew, packages, casks, and tools
5. Let the framework install and apply chezmoi (if `CHEZMOI_REPO` is set)
6. Review the manual checklist at the end

## Usage

```bash
chmod +x rebuild.sh
./rebuild.sh --profile macbook
```

Dry run:

```bash
./rebuild.sh --profile macbook --dry-run
```

Skip chezmoi:

```bash
./rebuild.sh --profile macbook --skip-step 10-install-chezmoi.sh --skip-step 11-apply-chezmoi.sh --skip-step 12-post-chezmoi.sh
```

Run only validation:

```bash
./rebuild.sh --profile macbook --only-step 13-validate.sh
```

## Important Notes

- **CHEZMOI_REPO:** Set in your profile (`profiles/<name>.env`) to your dotfiles repo URL. Leave empty to skip chezmoi.
- Manifests are a starting baseline; adjust to your needs and refresh from state export when desired.
- **State export:** Run `./scripts/14-export-state.sh` to update `state/exports/` and `manifests/*-exported.txt`. Review diffs, then copy to `manifests/*.txt` if satisfied.
- Manual and proprietary apps are tracked in `manifests/manual-downloads.txt` and installed via `scripts/vendor/` or manually.

## What Belongs Where

### This framework owns

- Homebrew formulae and casks
- pipx, cargo, uv, npm global installation
- Vendor/manual installers (scripts in `scripts/vendor/`)
- Orchestration and validation
- Machine profile logic

### Chezmoi owns

- Shell config, git config, SSH config
- Editor and terminal configuration
- User-level config files

### Manual steps

- macOS installation and disk setup
- App Store sign-in and licensed apps
- Browser and cloud sign-in
- Secrets and interactive auth

## Profile Strategy

Profiles live in `profiles/*.env`. Use them to toggle:

- GUI apps (brew casks)
- pipx, cargo, uv, npm
- Manual/vendor apps
- Chezmoi and dotfiles
- Features (Docker, backup tools, etc.)

## Refreshing Manifests from a Live Mac

```bash
./scripts/14-export-state.sh
```

Then diff `manifests/*-exported.txt` vs `manifests/*.txt`, copy over when satisfied, and commit.

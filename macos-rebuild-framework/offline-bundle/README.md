# Offline Bundle – Air-Gapped / No-Internet Setup (macOS)

This folder lets you **download all software** on a Mac with internet, store it locally, then **install everything from local storage** when you have no connectivity (new MacBook, USB, external drive, etc.).

## Workflows

### A) Manifest-based (profile + manifests)

1. **When you have internet:** Run `./download-bundle.sh --profile macbook` to download all packages from manifests into `cache/`.
2. **Copy `offline-bundle/`** (including `cache/`) to external storage (USB, HDD).
3. **On the target Mac (no internet):** Mount the storage, `cd` into `offline-bundle`, and run `./install-from-bundle.sh --profile macbook`.

### B) Clone this Mac (no profile)

Captures whatever is currently installed (Homebrew formulae/casks, pip --user, pipx) into a separate cache. Use when you want to replicate this Mac’s software set without maintaining manifests.

1. **On the source Mac (with internet):** Run `./collect-from-machine.sh`. This creates `clone-cache/` (or pass a path: `./collect-from-machine.sh /Volumes/USB/clone-cache`).  
   To **only export lists** (no downloads):  
   `./collect-from-machine.sh --lists-only [output-dir]`
2. **Copy `clone-cache/`** and `install-from-clone-cache.sh` to the target (or the whole `offline-bundle/` folder).
3. **On the target Mac (offline):** Run `./install-from-clone-cache.sh [path-to-clone-cache]`.

## Requirements

### For downloading (online)
- macOS with Homebrew (or install it during rebuild)
- Same macOS version as target (or compatible) for best bottle compatibility
- Package managers: brew, pip, pipx, cargo, uv, npm as needed by your manifests
- Internet connection

### For installing (offline)
- Fresh or existing macOS install (same major version as bundle recommended)
- User with admin rights (for brew, system installs)
- The bundle `cache/` directory populated by `download-bundle.sh`

## Directory layout (after download)

```
offline-bundle/
├── README.md
├── download-bundle.sh         # Run when online (manifest-based)
├── install-from-bundle.sh     # Run when offline (manifest-based)
├── collect-from-machine.sh    # Run when online (clone this Mac)
├── install-from-clone-cache.sh # Run when offline (from clone cache)
├── cache/                     # Manifest-based bundle output
│   ├── brew/                 # Homebrew bottles/cache
│   ├── pip/                  # pip --user wheelhouse + pip-user-freeze.txt
│   ├── pipx/, uv/, npm/, cargo/
│   ├── vendor/               # Manual .dmg, .pkg (README.txt, MANUAL-SOFTWARE-NOTES.txt)
│   ├── meta/                 # collection-info.txt
│   └── SHA256SUMS
└── clone-cache/              # Clone-from-machine output
```

## Vendor URL list

Add **direct download URLs** to **`manifests/vendor-download-urls.txt`**. When you run `collect-from-machine.sh`, each URL is downloaded into `cache/vendor/` (or clone-cache `vendor/`). One URL per line; optional second column is the filename to save as.

## Manual / vendor software

Place manually downloaded installers (`.dmg`, `.pkg`, `.app`) in a folder and either:

- Copy them into `offline-bundle/cache/vendor/` before running `install-from-bundle.sh`, or
- Set `OFFLINE_VENDOR_SOURCE_DIR` when downloading:

  ```bash
  OFFLINE_VENDOR_SOURCE_DIR="$HOME/Downloads/vendor" ./download-bundle.sh --profile macbook
  ```

## Storage size

Expect several GB depending on manifests (Homebrew bottles and casks are largest). Check `du -sh cache/` or `du -sh clone-cache/` before copying to removable media.

# Rebuild Procedure (macOS)

## Prerequisites

- macOS (Darwin)
- Optional: Xcode Command Line Tools (`xcode-select --install`)
- Network access (unless using offline bundle)

## Standard Rebuild (with internet)

1. Install macOS (or start from a clean system).
2. Clone or copy this framework onto the machine.
3. Create or edit a profile in `profiles/<name>.env` (e.g. `macbook.env`).
4. Run:
   ```bash
   chmod +x rebuild.sh
   ./rebuild.sh --profile macbook
   ```
5. Follow the manual checklist printed at the end (sign-in to App Store, browsers, etc.).

## Offline / Air-Gapped Rebuild

1. **On a Mac with internet:**  
   - Edit `manifests/` and `profiles/` as desired.  
   - Run: `./offline-bundle/download-bundle.sh --profile macbook`  
   - Copy the entire `macos-rebuild-framework` (including `offline-bundle/cache/`) to USB or external drive.

2. **On the target Mac (no network):**  
   - Copy the framework (and cache) onto the Mac.  
   - Run: `./offline-bundle/install-from-bundle.sh --profile macbook`  
   - Optionally run the full rebuild with `--skip-step` for steps that require network, or run only the steps you need.

## Refreshing Manifests from a Live Mac

After tuning a Mac to your liking:

```bash
./scripts/14-export-state.sh
```

Then review `manifests/*-exported.txt` vs `manifests/*.txt`. When satisfied, copy exported files over the manifest files and commit.

## Options

- `--dry-run` – Print what would run without executing.
- `--only-step <script>` – Run only one script (e.g. `14-export-state.sh`).
- `--skip-step <script>` – Skip a script (repeatable).

Example: skip chezmoi steps:

```bash
./rebuild.sh --profile macbook --skip-step 10-install-chezmoi.sh --skip-step 11-apply-chezmoi.sh --skip-step 12-post-chezmoi.sh
```

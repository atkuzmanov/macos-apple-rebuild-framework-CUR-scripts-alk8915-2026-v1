# Prior Mac-to-Mac Migration Folder (Reference)

The project may include a folder **`info-mng-mac-to-mac-migr-soft-lists-scripts-CURSOR-alk8915-2026`** from an earlier Mac-to-Mac migration approach. That folder contained:

- **mac-run-inventory-alk8915-2026-v1.sh** – wrapper to run an inventory script (the script itself lived in a parent directory).
- **mac-restore-from-inventory-alk8915-2026-v1.sh** – restore on the new Mac from an inventory folder (Brewfile + inventory.json).
- **mac-software-inventory-YYYY-MM-DD-HHMMSS/** – sample output: Brewfile, inventory.json, and many report files (brew formulae/casks, mas list, pip/npm/cargo, vscode extensions, system info, etc.).

Useful ideas from that approach have been incorporated into this framework:

| From prior folder | In this framework |
|-------------------|-------------------|
| Brewfile (taps, formulae, casks, mas, vscode) | Optional **Brewfile** support: place `Brewfile` in project root or `manifests/`; step `02c-install-brewfile.sh` runs `brew bundle`. Manifests (brew-packages.txt, brew-casks.txt, etc.) remain the primary source. |
| Mac App Store (mas) list + restore | **manifests/mas-apps.txt** + **04b-install-mas-apps.sh**; profile flag `INSTALL_MAS_APPS`. State export includes `mas list`. |
| VS Code extensions in inventory.json | **manifests/vscode-extensions.txt** + **04c-install-vscode-extensions.sh**; profile flag `INSTALL_VSCODE_EXTENSIONS`. State export includes `code --list-extensions`. |
| Brew taps list | **manifests/brew-taps.txt** + **02b-install-brew-taps.sh**; state export includes `brew tap`. |
| inventory.json (pip, npm, cargo, vscode, mas) | We use **separate manifest files** and **state/exports/** instead of a single JSON; same data, clearer structure and diff-friendly. |

Not carried over:

- **Login items** – inventory had `login_items.txt` (informational); restoring login items is environment-specific and not automated here.
- **Ruby gems / pyenv versions** – very environment-specific; we stick to brew, pip user, pipx, cargo, npm.
- **Single inventory script** – this framework uses the rebuild pipeline plus `14-export-state.sh` to refresh manifests from a live Mac.

You can keep or remove the prior folder; it is only reference. This framework is self-contained.

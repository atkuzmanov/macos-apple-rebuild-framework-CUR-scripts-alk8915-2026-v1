#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

cat <<'CHECKLIST' | tee -a "${RUN_LOG:-/dev/null}"

Manual checklist after rebuild (macOS):

1. Sign in to App Store and install any licensed apps.
2. Sign in to browsers, sync tools, and cloud apps.
3. Restore secrets that are intentionally not auto-provisioned.
4. If you changed default shell: log out and back in, or run chsh.
5. Open IDEs (Xcode, Cursor, etc.) once for first-run setup.
6. Open chezmoi and confirm expected managed files.
7. Review logs/ and state/exports/ before committing manifest changes.
8. For Docker: start Docker Desktop or colima if you use it.
9. Reboot once after a full rebuild on a new machine.

CHECKLIST

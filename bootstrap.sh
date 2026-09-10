#!/usr/bin/env bash
# macos-bootstrap — sync this tree, then exec forge.sh so modules load from the
# updated checkout.
#
#   ./bootstrap.sh              # sync, then run every module
#   ./bootstrap.sh packages git # sync, then selected modules
#   ./forge.sh                  # skip sync; run modules only
#
set -euo pipefail

MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")" && pwd)"
export MACOS_BOOTSTRAP_ROOT

# shellcheck source=lib/common.sh
source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"

# Peek only. forge.sh parses flags and module names.
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      exec "$MACOS_BOOTSTRAP_ROOT/forge.sh" --help
      ;;
    -y|--yes)
      ASSUME_YES=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
  esac
done
export DRY_RUN ASSUME_YES

macos_bootstrap_adopt_sudo_identity
macos_bootstrap_load_config

# shellcheck source=lib/sync.sh
source "$MACOS_BOOTSTRAP_ROOT/lib/sync.sh"

log_step "Sync"
macos_bootstrap_sync

exec "$MACOS_BOOTSTRAP_ROOT/forge.sh" "$@"

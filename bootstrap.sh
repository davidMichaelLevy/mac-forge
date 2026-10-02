#!/usr/bin/env bash
# macos-bootstrap — sync this tree, re-exec so this script is current, then
# exec the updated forge.sh.
#
#   ./bootstrap.sh              # sync, then run forge.sh
#   ./bootstrap.sh packages git # sync, then pass those names through to forge.sh
#
set -euo pipefail

MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")" && pwd)"
export MACOS_BOOTSTRAP_ROOT

# shellcheck source=lib/common.sh
source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
mac-forge bootstrap — sync this checkout, then exec the updated forge.sh

Usage:
  ./bootstrap.sh [options] [args...]

Options:
  -h, --help     Show this help, then forge.sh help (extra args are forwarded)
  --dry-run      Print commands without running them

SYNC_MAC_FORGE=false in config skips the git update. After sync, this script
re-execs itself so a just-pulled bootstrap.sh is what runs forge.sh.

Other arguments are passed through to forge.sh.
EOF
}

# Peek only. Remaining flags and module names are parsed later.
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      printf '\n'
      exec "$MACOS_BOOTSTRAP_ROOT/forge.sh" "$@"
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

if ! is_truthy "${MACOS_BOOTSTRAP_REEXEC:-}"; then
  export MACOS_BOOTSTRAP_REEXEC=1
  log_info "Re-executing bootstrap.sh to load the current script"
  exec "$MACOS_BOOTSTRAP_ROOT/bootstrap.sh" "$@"
fi

exec "$MACOS_BOOTSTRAP_ROOT/forge.sh" "$@"

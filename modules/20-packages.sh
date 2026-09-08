# shellcheck shell=bash
# packages — install formulae (and optionally casks/fonts) from the Brewfile.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${INSTALL_PACKAGES:-true}"; then
  log_warn "Skipping packages (INSTALL_PACKAGES is false)."
  return 0 2>/dev/null || exit 0
fi

BREWFILE="$MACOS_BOOTSTRAP_ROOT/config/Brewfile"
if [ ! -f "$BREWFILE" ]; then
  die "Missing Brewfile: $BREWFILE"
fi

eval_brew_shellenv
if ! command_exists brew && ! is_dry_run; then
  die "Homebrew is not available. Run the homebrew module first."
fi

BUNDLE_ARGS="--file=$BREWFILE --no-upgrade"
if ! is_truthy "${INSTALL_CASKS:-true}"; then
  log_info "INSTALL_CASKS is false — formulae only (skipping apps and fonts)."
  BUNDLE_ARGS="$BUNDLE_ARGS --formula"
fi

log_info "Installing from $BREWFILE"
# shellcheck disable=SC2086
run_user brew bundle $BUNDLE_ARGS
log_success "Brewfile applied"

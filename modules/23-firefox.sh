# shellcheck shell=bash
# firefox — allow Firefox Account sign-in and Sync.
# Firefox cannot finish FxA unattended; sign in once in the browser after this.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
  return 0 2>/dev/null || exit 0
fi

if ! is_macos && ! is_dry_run; then
  log_warn "Skipping firefox (not macOS)."
  return 0 2>/dev/null || exit 0
fi

FIREFOX_APP="/Applications/Firefox.app"

if [ ! -d "$FIREFOX_APP" ] && ! is_dry_run; then
  log_warn "Firefox is not installed; run ./bootstrap.sh packages first"
  return 0 2>/dev/null || exit 0
fi

# User-level plist survives Homebrew cask upgrades; writing inside .app does not.
FIREFOX_PLIST="${HOME}/Library/Preferences/org.mozilla.firefox"

firefox_account() {
  printf '%s' "${FIREFOX_SYNC_ACCOUNT:-}"
}

firefox_defaults() {
  run_user defaults write "$FIREFOX_PLIST" "$@"
}

firefox_enable_sync() {
  firefox_defaults EnterprisePoliciesEnabled -bool true
  firefox_defaults DisableFirefoxAccounts -bool false
  firefox_defaults DisableAccounts -bool false
  firefox_defaults Sync__Enabled -bool true
  firefox_defaults Sync__Locked -bool false
  firefox_defaults Sync__Addons -bool true
  firefox_defaults Sync__Addresses -bool true
  firefox_defaults Sync__Bookmarks -bool true
  firefox_defaults Sync__History -bool true
  firefox_defaults Sync__OpenTabs -bool true
  firefox_defaults Sync__Passwords -bool true
  firefox_defaults Sync__PaymentMethods -bool true
  firefox_defaults Sync__Settings -bool true
}

account="$(firefox_account)"
log_info "Firefox: Firefox Account sign-in and Sync"

if [ -z "$account" ]; then
  log_warn "FIREFOX_SYNC_ACCOUNT and USER_EMAIL are empty — enabling sync with no account hint"
else
  log_info "Firefox Account: $account"
fi

if is_dry_run; then
  firefox_enable_sync
  return 0 2>/dev/null || exit 0
fi

osascript -e 'tell application "Firefox" to quit' >/dev/null 2>&1 || true
killall Firefox >/dev/null 2>&1 || true

firefox_enable_sync

log_success "Firefox Sync is enabled${account:+ for $account}"
log_info "Open Firefox and sign in once to start sync (about:preferences#sync)."

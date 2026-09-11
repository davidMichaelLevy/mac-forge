# shellcheck shell=bash
# chrome — allow Google sign-in and sync, limited to one account.
# Chrome cannot finish OAuth unattended; sign in once in the browser after this.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${SETUP_CHROME:-true}"; then
  log_warn "Skipping chrome (SETUP_CHROME is false)."
  return 0 2>/dev/null || exit 0
fi

if ! is_macos && ! is_dry_run; then
  log_warn "Skipping chrome (not macOS)."
  return 0 2>/dev/null || exit 0
fi

CHROME_APP="/Applications/Google Chrome.app"

if [ ! -d "$CHROME_APP" ] && ! is_dry_run; then
  log_warn "Google Chrome is not installed; run ./bootstrap.sh packages first"
  return 0 2>/dev/null || exit 0
fi

chrome_account() {
  printf '%s' "${CHROME_GOOGLE_ACCOUNT:-}"
}

# RestrictSigninToPattern is a regular expression.
chrome_email_pattern() {
  printf '%s' "$1" | sed -E 's/[][\\.^$*+?(){}|]/\\&/g'
}

chrome_defaults() {
  run_user defaults write com.google.Chrome "$@"
}

account="$(chrome_account)"
log_info "Chrome: Google sign-in and sync"

if [ -z "$account" ]; then
  log_warn "CHROME_GOOGLE_ACCOUNT and USER_EMAIL are empty — enabling sync with no account restriction"
else
  log_info "Allowed Google account: $account"
fi

if is_dry_run; then
  chrome_defaults BrowserSignin -int 1
  chrome_defaults SyncDisabled -bool false
  if [ -n "$account" ]; then
    chrome_defaults RestrictSigninToPattern -string "^$(chrome_email_pattern "$account")\$"
  fi
  return 0 2>/dev/null || exit 0
fi

osascript -e 'tell application "Google Chrome" to quit' >/dev/null 2>&1 || true
killall "Google Chrome" >/dev/null 2>&1 || true

# 1 = enable browser sign-in (required for Chrome Sync). User completes OAuth in Chrome.
chrome_defaults BrowserSignin -int 1
chrome_defaults SyncDisabled -bool false
if [ -n "$account" ]; then
  chrome_defaults RestrictSigninToPattern -string "^$(chrome_email_pattern "$account")\$"
fi

log_success "Chrome will sign in and sync as ${account:-any Google account}"
log_info "Open Chrome and sign in once to start sync (chrome://settings/syncSetup)."

# shellcheck shell=bash
# macos — opinionated, reversible-enough defaults for a developer laptop.
# Close System Settings before running so it doesn't overwrite what we write.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${APPLY_MACOS_DEFAULTS:-true}"; then
  log_warn "Skipping macOS defaults (APPLY_MACOS_DEFAULTS is false)."
  return 0 2>/dev/null || exit 0
fi

if ! is_macos && ! is_dry_run; then
  log_warn "Skipping macOS defaults (not macOS)."
  return 0 2>/dev/null || exit 0
fi

defaults_write() {
  if is_dry_run; then
    log_dim "[dry-run] defaults write $*"
    return 0
  fi
  if ! defaults write "$@"; then
    log_warn "defaults write failed: $*"
  fi
}

quit_system_settings() {
  if is_dry_run; then
    return 0
  fi
  osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1 || true
  osascript -e 'tell application "System Preferences" to quit' >/dev/null 2>&1 || true
}

set_computer_name() {
  local name="$1"
  local local_name
  if [ -z "$name" ]; then
    return 0
  fi
  log_info "Computer name: $name"
  local_name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')"
  run sudo scutil --set ComputerName "$name"
  run sudo scutil --set HostName "$name"
  run sudo scutil --set LocalHostName "$local_name"
}

apply_general() {
  log_info "General UI"
  defaults_write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults_write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
  defaults_write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults_write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
  defaults_write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
  defaults_write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults_write NSGlobalDomain AppleScrollerPagingBehavior -int 1
  defaults_write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults_write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults_write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults_write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults_write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults_write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
}

apply_keyboard() {
  log_info "Keyboard"
  if is_truthy "${MACOS_KEY_REPEAT_FAST:-true}"; then
    # Disable press-and-hold so key repeat works in editors.
    defaults_write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    defaults_write NSGlobalDomain KeyRepeat -int 2
    defaults_write NSGlobalDomain InitialKeyRepeat -int 15
  fi
  # Full keyboard access (Tab through all controls).
  defaults_write NSGlobalDomain AppleKeyboardUIMode -int 3
}

apply_trackpad() {
  log_info "Trackpad & scroll"
  if is_truthy "${MACOS_TAP_TO_CLICK:-true}"; then
    defaults_write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults_write com.apple.AppleMultitouchTrackpad Clicking -bool true
    defaults_write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  fi
  # true = Apple "Natural" (content follows fingers). false = reversed / Windows-style.
  if is_truthy "${MACOS_NATURAL_SCROLL:-false}"; then
    defaults_write NSGlobalDomain com.apple.swipescrolldirection -bool true
  else
    defaults_write NSGlobalDomain com.apple.swipescrolldirection -bool false
  fi
}

apply_screenshots() {
  local dir="$HOME/Pictures/Screenshots"
  log_info "Screenshots → $dir"
  ensure_dir "$dir"
  defaults_write com.apple.screencapture location -string "$dir"
  defaults_write com.apple.screencapture type -string "png"
  defaults_write com.apple.screencapture disable-shadow -bool true
}

apply_finder() {
  log_info "Finder"
  if is_truthy "${MACOS_SHOW_HIDDEN_FILES:-true}"; then
    defaults_write com.apple.finder AppleShowAllFiles -bool true
  fi
  defaults_write com.apple.finder ShowPathbar -bool true
  defaults_write com.apple.finder ShowStatusBar -bool true
  defaults_write com.apple.finder _FXSortFoldersFirst -bool true
  defaults_write com.apple.finder FXDefaultSearchScope -string "SCcf"
  defaults_write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults_write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  defaults_write com.apple.finder NewWindowTarget -string "PfHm"
  defaults_write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
  defaults_write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults_write com.apple.desktopservices DSDontWriteUSBStores -bool true
  if ! is_dry_run; then
    chflags nohidden "$HOME/Library" 2>/dev/null || true
  fi
}

apply_dock() {
  log_info "Dock & Mission Control"
  defaults_write com.apple.dock tilesize -int 48
  defaults_write com.apple.dock minimize-to-application -bool true
  defaults_write com.apple.dock show-recents -bool false
  defaults_write com.apple.dock launchanim -bool false
  defaults_write com.apple.dock mru-spaces -bool false
  defaults_write com.apple.dock expose-group-apps -bool true
  if is_truthy "${MACOS_DOCK_AUTOHIDE:-true}"; then
    defaults_write com.apple.dock autohide -bool true
    defaults_write com.apple.dock autohide-delay -float 0
    defaults_write com.apple.dock autohide-time-modifier -float 0.35
  fi
}

apply_safari() {
  log_info "Safari (developer extras)"
  defaults_write com.apple.Safari ShowFullURLInSmartSearchField -bool true
  defaults_write com.apple.Safari IncludeDevelopMenu -bool true
  defaults_write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
  defaults_write com.apple.Safari.SandboxBroker ShowDevelopMenu -bool true
  defaults_write NSGlobalDomain WebKitDeveloperExtras -bool true
}

confirm_default_browser_dialog() {
  # macOS shows a "Use Firefox?" prompt; click it when Accessibility allows.
  osascript >/dev/null 2>&1 <<'APPLESCRIPT'
tell application "System Events"
  set endTime to (current date) + 8
  repeat until (current date) is greater than endTime
    tell process "CoreServicesUIAgent"
      if exists window 1 then
        repeat with b in buttons of window 1
          try
            if (name of b as text) contains "Use" then
              click b
              return
            end if
          end try
        end repeat
      end if
    end tell
    delay 0.15
  end repeat
end tell
APPLESCRIPT
}

register_browser_app() {
  local want="$1"
  local app=""
  local lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

  case "$want" in
    firefox) app="/Applications/Firefox.app" ;;
    chrome) app="/Applications/Google Chrome.app" ;;
    safari) app="/Applications/Safari.app" ;;
    brave|browser) app="/Applications/Brave Browser.app" ;;
  esac

  if [ -n "$app" ] && [ -d "$app" ] && [ -x "$lsregister" ]; then
    run_ok "$lsregister" -f "$app"
  fi
}

apply_default_browser() {
  local want current dialog_pid
  want="${MACOS_DEFAULT_BROWSER:-}"
  if [ -z "$want" ]; then
    return 0
  fi

  log_info "Default browser: $want"
  eval_brew_shellenv

  if is_dry_run; then
    log_dim "[dry-run] defaultbrowser $want"
    return 0
  fi

  if ! command_exists defaultbrowser; then
    log_warn "defaultbrowser not installed; run ./bootstrap.sh packages first"
    return 0
  fi

  register_browser_app "$want"

  current="$(defaultbrowser 2>/dev/null | awk '/^\*/ { print $2; exit }' || true)"
  if [ "$current" = "$want" ]; then
    log_success "$want is already the default HTTP handler"
    return 0
  fi

  confirm_default_browser_dialog &
  dialog_pid=$!
  if defaultbrowser "$want"; then
    wait "$dialog_pid" 2>/dev/null || true
    log_success "Default browser set to $want"
    log_dim "If macOS still shows a confirmation dialog, click Use \"$want\"."
  else
    kill "$dialog_pid" 2>/dev/null || true
    wait "$dialog_pid" 2>/dev/null || true
    log_warn "Could not set default browser to $want (install it, then re-run)."
  fi
}

apply_security() {
  log_info "Security"
  defaults_write com.apple.screensaver askForPassword -int 1
  defaults_write com.apple.screensaver askForPasswordDelay -int 0
  if is_dry_run; then
    log_dim "[dry-run] enable application firewall"
  else
    if [ -x /usr/libexec/ApplicationFirewall/socketfilterfw ]; then
      run_ok sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    fi
  fi
}

apply_apps() {
  log_info "Built-in apps"
  defaults_write com.apple.TextEdit RichText -int 0
  defaults_write com.apple.TextEdit PlainTextEncoding -int 4
  defaults_write com.apple.TextEdit PlainTextEncodingForWrite -int 4
  defaults_write com.apple.ActivityMonitor ShowCategory -int 0
  defaults_write com.apple.ActivityMonitor IconType -int 5
  defaults_write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  defaults_write com.apple.SoftwareUpdate AutomaticDownload -int 1
  defaults_write com.apple.commerce AutoUpdate -bool true
}

restart_ui() {
  if is_dry_run; then
    log_dim "[dry-run] killall Dock Finder SystemUIServer"
    return 0
  fi
  log_info "Restarting Dock, Finder, and SystemUIServer"
  killall Dock Finder SystemUIServer cfprefsd >/dev/null 2>&1 || true
}

quit_system_settings
macos_bootstrap_sudo_start

set_computer_name "${COMPUTER_NAME:-}"
apply_general
apply_keyboard
apply_trackpad
apply_screenshots
apply_finder
apply_dock
apply_safari
apply_default_browser
apply_security
apply_apps
restart_ui

log_success "macOS defaults applied (logout if anything looks stale)"

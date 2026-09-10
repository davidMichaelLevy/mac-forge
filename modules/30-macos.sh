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

set_machine_names() {
  local computer host local_name

  if ! is_truthy "${SET_MACHINE_NAMES:-true}"; then
    log_info "Leaving ComputerName, HostName, and LocalHostName unchanged"
    return 0
  fi

  macos_bootstrap_resolve_machine_names
  computer="${MACOS_RESOLVED_COMPUTER_NAME:-}"
  host="${MACOS_RESOLVED_HOST_NAME:-}"
  local_name="${MACOS_RESOLVED_LOCAL_HOST_NAME:-}"

  if [ -z "$computer" ] && [ -z "$host" ] && [ -z "$local_name" ]; then
    return 0
  fi

  if [ -n "$computer" ]; then
    log_info "ComputerName: $computer"
    run sudo scutil --set ComputerName "$computer"
  fi
  if [ -n "$host" ]; then
    log_info "HostName: $host"
    run sudo scutil --set HostName "$host"
  fi
  if [ -n "$local_name" ]; then
    log_info "LocalHostName: $local_name"
    run sudo scutil --set LocalHostName "$local_name"
  fi
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

apply_clock() {
  local clock="${MACOS_24_HOUR_CLOCK:-}"

  if [ -z "$clock" ]; then
    log_info "Clock: leave current"
    return 0
  fi

  if is_truthy "$clock"; then
    log_info "Clock: 24-hour"
    defaults_write NSGlobalDomain AppleICUForce24HourTime -bool true
    defaults_write com.apple.menuextra.clock Show24Hour -bool true
    defaults_write com.apple.menuextra.clock ShowAMPM -bool false
    if ! is_dry_run; then
      defaults delete NSGlobalDomain AppleICUForce12HourTime >/dev/null 2>&1 || true
      run_ok sudo defaults write /Library/Preferences/.GlobalPreferences.plist AppleICUForce24HourTime -bool true
    fi
    return 0
  fi

  if is_falsy "$clock"; then
    log_info "Clock: 12-hour"
    defaults_write NSGlobalDomain AppleICUForce12HourTime -bool true
    defaults_write com.apple.menuextra.clock Show24Hour -bool false
    defaults_write com.apple.menuextra.clock ShowAMPM -bool true
    if ! is_dry_run; then
      defaults delete NSGlobalDomain AppleICUForce24HourTime >/dev/null 2>&1 || true
      run_ok sudo defaults write /Library/Preferences/.GlobalPreferences.plist AppleICUForce24HourTime -bool false
    fi
    return 0
  fi

  log_warn "MACOS_24_HOUR_CLOCK=$clock (use true, false, or empty)"
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

apply_power() {
  local battery ac battery_msg ac_msg

  battery="${MACOS_DISPLAY_SLEEP_BATTERY:-10}"
  ac="${MACOS_DISPLAY_SLEEP_AC:-0}"
  if [ "$battery" = "0" ]; then
    battery_msg="never"
  else
    battery_msg="${battery} min"
  fi
  if [ "$ac" = "0" ]; then
    ac_msg="never"
  else
    ac_msg="${ac} min"
  fi

  log_info "Power: display sleep $battery_msg on battery, $ac_msg on AC"
  # 0 = never. On AC, also disable system sleep so the display cannot go dark
  # because the machine slept.
  run sudo pmset -b displaysleep "$battery"
  if [ "$ac" = "0" ]; then
    run sudo pmset -c displaysleep 0 sleep 0
  else
    run sudo pmset -c displaysleep "$ac"
  fi
}

apply_screensaver() {
  local want result label
  want="${MACOS_SCREENSAVER:-}"
  if [ -z "$want" ]; then
    return 0
  fi

  log_info "Screensaver: $want"
  if is_dry_run; then
    log_dim "[dry-run] set aerial screensaver to $want"
    return 0
  fi
  if ! command_exists python3; then
    log_warn "python3 not found; skip screensaver"
    return 0
  fi

  if result="$(run_user python3 "$MACOS_BOOTSTRAP_ROOT/lib/set-aerial-screensaver.py" "$want")"; then
    label="${result%%|*}"
    log_success "Screensaver set to ${label:-$want}"
    run_user killall WallpaperAgent >/dev/null 2>&1 || true
  else
    log_warn "Could not set screensaver to $want"
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

set_machine_names
apply_power
apply_screensaver
apply_general
apply_clock
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

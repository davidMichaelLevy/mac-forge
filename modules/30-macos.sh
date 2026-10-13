# shellcheck shell=bash
# macos — opinionated, reversible-enough defaults for a developer laptop.
# Close System Settings before running so it doesn't overwrite what we write.

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
  log_warn "Skipping macOS defaults (not macOS)."
  return 0 2>/dev/null || exit 0
fi

defaults_write() {
  if ! run_user defaults write "$@"; then
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
    log_info "Clock: 24-hour (menu bar, lock screen, screensaver)"
    defaults_write NSGlobalDomain AppleICUForce24HourTime -bool true
    defaults_write com.apple.menuextra.clock IsAnalog -bool false
    defaults_write com.apple.menuextra.clock Show24Hour -bool true
    defaults_write com.apple.menuextra.clock ShowAMPM -bool false
    if ! is_dry_run; then
      run_user defaults delete NSGlobalDomain AppleICUForce12HourTime >/dev/null 2>&1 || true
      sudo defaults delete /Library/Preferences/.GlobalPreferences.plist AppleICUForce12HourTime >/dev/null 2>&1 || true
      run_ok sudo defaults write /Library/Preferences/.GlobalPreferences.plist AppleICUForce24HourTime -bool true
      # Same large clock on screensaver, lock screen, and login window.
      if [ -x /usr/sbin/sysadminctl ]; then
        run_ok sudo /usr/sbin/sysadminctl -use12HourClockForLoginWindow off
      fi
    fi
    return 0
  fi

  if is_falsy "$clock"; then
    log_info "Clock: 12-hour (menu bar, lock screen, screensaver)"
    defaults_write NSGlobalDomain AppleICUForce12HourTime -bool true
    defaults_write com.apple.menuextra.clock IsAnalog -bool false
    defaults_write com.apple.menuextra.clock Show24Hour -bool false
    defaults_write com.apple.menuextra.clock ShowAMPM -bool true
    if ! is_dry_run; then
      run_user defaults delete NSGlobalDomain AppleICUForce24HourTime >/dev/null 2>&1 || true
      sudo defaults delete /Library/Preferences/.GlobalPreferences.plist AppleICUForce24HourTime >/dev/null 2>&1 || true
      run_ok sudo defaults write /Library/Preferences/.GlobalPreferences.plist AppleICUForce12HourTime -bool true
      if [ -x /usr/sbin/sysadminctl ]; then
        run_ok sudo /usr/sbin/sysadminctl -use12HourClockForLoginWindow on
      fi
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

icloud_desktop_documents_on() {
  # Desktop & Documents Folders is an Apple Account switch. Finder's
  # FXICloudDrive* keys are status bits and do not turn it off.
  if [ -L "$HOME/Desktop" ] || [ -L "$HOME/Documents" ]; then
    return 0
  fi
  if xattr -p com.apple.icloud.desktop "$HOME/Desktop" >/dev/null 2>&1 \
    || xattr -p com.apple.icloud.desktop "$HOME/Documents" >/dev/null 2>&1; then
    return 0
  fi
  if [ -L "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop" ] \
    || [ -L "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents" ]; then
    return 0
  fi
  return 1
}

apply_icloud_drive() {
  local want="${MACOS_ICLOUD_DRIVE:-}"
  local pane="x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?email/prefs/storage?root=APPLE_ACCOUNT&path=ICLOUD_SERVICE&dataclassId=com.apple.Dataclass.Ubiquity"

  if [ -z "$want" ]; then
    log_info "iCloud Drive: leave current"
    return 0
  fi

  if is_truthy "$want"; then
    log_info "iCloud Drive: leave enabled"
    return 0
  fi

  if ! is_falsy "$want"; then
    log_warn "MACOS_ICLOUD_DRIVE=$want (use true, false, or empty)"
    return 0
  fi

  log_info "iCloud Drive: off"
  if icloud_service_enabled MOBILE_DOCUMENTS; then
    run_user open "$pane"
    log_task "Turn off iCloud Drive (System Settings → Apple Account → iCloud), keep a local copy if asked, then re-run."
  else
    log_success "iCloud Drive already off"
  fi
  log_reminder "If Finder still lists iCloud Drive, untick it in Finder → Settings → Sidebar."
}

apply_icloud_file_sync() {
  local want="${MACOS_ICLOUD_FILE_SYNC:-}"
  local pane="x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?email/prefs/storage?root=APPLE_ACCOUNT&path=ICLOUD_SERVICE&dataclassId=com.apple.Dataclass.Ubiquity"

  if is_falsy "${MACOS_ICLOUD_DRIVE:-}"; then
    if is_truthy "$want"; then
      log_warn "MACOS_ICLOUD_FILE_SYNC=$want has no effect when MACOS_ICLOUD_DRIVE=false (Desktop & Documents sync needs iCloud Drive)"
    else
      log_dim "iCloud file sync: covered by MACOS_ICLOUD_DRIVE=false"
    fi
    return 0
  fi

  if [ -z "$want" ]; then
    log_info "iCloud file sync: leave current"
    return 0
  fi

  if is_truthy "$want"; then
    log_info "iCloud file sync: leave enabled"
    return 0
  fi

  if ! is_falsy "$want"; then
    log_warn "MACOS_ICLOUD_FILE_SYNC=$want (use true, false, or empty)"
    return 0
  fi

  log_info "iCloud file sync: off"
  if ! icloud_desktop_documents_on; then
    log_success "Desktop and Documents are already local"
    return 0
  fi

  run_user open "$pane"
  log_task "Turn off Desktop & Documents Folders in iCloud Drive, then re-run."
}

icloud_photos_is_on() {
  # Same idea as Desktop & Documents: only treat as on when something
  # says so. Turning the switch off often leaves these keys unset.
  local val domain
  for domain in com.apple.CloudPhotosConfiguration com.apple.photos; do
    val="$(defaults read "$domain" CPLEnableiCloudPhotoLibrary 2>/dev/null || true)"
    case "$val" in
      1|true|YES) return 0 ;;
    esac
  done
  return 1
}

apply_icloud_photos_sync() {
  local want="${MACOS_ICLOUD_PHOTOS_SYNC:-}"
  local pane="x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?email/prefs/storage?root=APPLE_ACCOUNT&path=ICLOUD_SERVICE&dataclassId=com.apple.Dataclass.CloudPhotos"

  if [ -z "$want" ]; then
    log_info "iCloud Photos: leave current"
    return 0
  fi

  if is_truthy "$want"; then
    log_info "iCloud Photos: leave enabled"
    return 0
  fi

  if ! is_falsy "$want"; then
    log_warn "MACOS_ICLOUD_PHOTOS_SYNC=$want (use true, false, or empty)"
    return 0
  fi

  log_info "iCloud Photos: off"
  if ! icloud_photos_is_on; then
    log_success "iCloud Photos already off"
    return 0
  fi

  run_user open "$pane"
  log_task "Turn off iCloud Photos (or Photos → Settings → iCloud), choose Download if you want a local library, then re-run."
}

icloud_service_enabled() {
  if ! command_exists python3; then
    return 1
  fi
  python3 "$MACOS_BOOTSTRAP_ROOT/lib/icloud-service-enabled.py" "$1" >/dev/null 2>&1
}

icloud_calendar_is_on() {
  icloud_service_enabled CALENDAR
}

apply_icloud_calendar_sync() {
  local want="${MACOS_ICLOUD_CALENDAR_SYNC:-}"
  local pane="x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?email/prefs/storage?root=APPLE_ACCOUNT&path=ICLOUD_SERVICE&dataclassId=com.apple.Dataclass.Calendars"

  if [ -z "$want" ]; then
    log_info "iCloud Calendar: leave current"
    return 0
  fi

  if is_truthy "$want"; then
    log_info "iCloud Calendar: leave enabled"
    return 0
  fi

  if ! is_falsy "$want"; then
    log_warn "MACOS_ICLOUD_CALENDAR_SYNC=$want (use true, false, or empty)"
    return 0
  fi

  log_info "iCloud Calendar: off"
  if ! icloud_calendar_is_on; then
    log_success "iCloud Calendar already off"
    return 0
  fi

  run_user open "$pane"
  log_task "Turn off Calendars in iCloud (System Settings → Apple Account → iCloud), then re-run."
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

displaylink_app_path() {
  local p
  for p in \
    "/Applications/DisplayLink Manager.app" \
    "/Applications/DisplayLink/DisplayLink Manager.app"; do
    if [ -d "$p" ]; then
      printf '%s' "$p"
      return 0
    fi
  done
  return 1
}

displaylink_screen_recording_state() {
  tcc_state kTCCServiceScreenCapture \
    com.displaylink.DisplayLinkUserAgent com.displaylink.DisplayLinkManager
}

apply_displaylink() {
  local app pane state
  pane="x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

  log_info "DisplayLink Manager"
  app="$(displaylink_app_path || true)"
  if [ -z "$app" ]; then
    if is_dry_run; then
      log_dim "[dry-run] install DisplayLink Manager from the Brewfile"
      return 0
    fi
    log_dim "DisplayLink Manager is not installed (run packages)"
    return 0
  fi

  if is_dry_run; then
    log_dim "[dry-run] launch DisplayLink Manager and check Screen Recording"
    return 0
  fi

  run_user open "$app" >/dev/null 2>&1 || true
  state="$(displaylink_screen_recording_state)"
  case "$state" in
    granted)
      log_success "Screen Recording already granted"
      ;;
    denied)
      run_user open "$pane"
      log_task "Grant Screen Recording to DisplayLink Manager, quit and reopen it, then re-run."
      ;;
    *)
      log_reminder "Grant Screen Recording to DisplayLink Manager (Privacy & Security) so DisplayLink displays work. Reboot once if they stay blank."
      ;;
  esac
}

apply_safari() {
  local key wrote=true
  log_info "Safari (developer extras)"
  if ! is_dry_run; then
    osascript -e 'tell application "Safari" to quit' >/dev/null 2>&1 || true
  fi
  # These domains are not in Safari's SIP-protected container.
  defaults_write com.apple.Safari.SandboxBroker ShowDevelopMenu -bool true
  defaults_write NSGlobalDomain WebKitDeveloperExtras -bool true

  # com.apple.Safari lives under Containers/ and fails without Full Disk Access.
  for key in ShowFullURLInSmartSearchField IncludeDevelopMenu WebKitDeveloperExtrasEnabledPreferenceKey; do
    if is_dry_run; then
      log_dim "[dry-run] defaults write com.apple.Safari $key -bool true"
      continue
    fi
    if ! run_user defaults write com.apple.Safari "$key" -bool true >/dev/null 2>&1; then
      wrote=false
    fi
  done
  if [ "$wrote" = false ]; then
    log_task "Grant this terminal Full Disk Access and re-run, or set Safari → Settings → Advanced → Show full website address."
  fi
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
    current="$(defaultbrowser 2>/dev/null | awk '/^\*/ { print $2; exit }' || true)"
    if [ "$current" = "$want" ]; then
      log_success "Default browser set to $want"
    else
      log_task "Click Use \"$want\" in the macOS confirmation dialog, then re-run."
    fi
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

  if result="$(run_user_capture python3 "$MACOS_BOOTSTRAP_ROOT/lib/set-aerial-screensaver.py" "$want")"; then
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
  if [ -x /usr/libexec/ApplicationFirewall/socketfilterfw ]; then
    run_ok sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
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
    log_dim "[dry-run] killall Dock Finder SystemUIServer ControlCenter"
    return 0
  fi
  log_info "Restarting Dock, Finder, SystemUIServer, and ControlCenter"
  killall Dock Finder SystemUIServer ControlCenter cfprefsd >/dev/null 2>&1 || true
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
apply_icloud_drive
apply_icloud_file_sync
apply_icloud_photos_sync
apply_icloud_calendar_sync
apply_dock
apply_safari
apply_default_browser
apply_displaylink
apply_security
apply_apps
restart_ui

log_success "macOS defaults applied (logout if anything looks stale)"

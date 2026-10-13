# shellcheck shell=bash
# preinstalled — remove the Apple apps in MACOS_REMOVE_APPS.
# Deletable apps in /Applications are uninstalled. Protected system apps
# cannot be deleted, so removal is best effort. Every listed app is unpinned
# from the Dock, and some get an extra step (preinstalled_best_effort).

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
  log_warn "Skipping preinstalled apps (not macOS)."
  return 0 2>/dev/null || exit 0
fi

preinstalled_names_equal() {
  local a="$1" b="$2"
  [ "$a" = "$b" ] && return 0
  [ "$a" = "${b#Apple }" ] && return 0
  [ "${a#Apple }" = "$b" ] && return 0
  return 1
}

preinstalled_should_remove() {
  local label="$1" name
  [ -n "$label" ] || return 1
  for name in "${MACOS_REMOVE_APPS[@]}"; do
    preinstalled_names_equal "$label" "$name" && return 0
  done
  return 1
}

preinstalled_is_apple_bundle() {
  local app="$1" id
  id="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  case "$id" in
    com.apple.*) return 0 ;;
    *) return 1 ;;
  esac
}

# SIP marks protected apps (Safari in /Applications, everything under
# /System/Applications) with the restricted flag; rm fails on them.
preinstalled_is_protected() {
  local app="$1"
  case "$app" in
    /System/*) return 0 ;;
  esac
  case "$(stat -f '%Sf' "$app" 2>/dev/null || true)" in
    *restricted*) return 0 ;;
  esac
  return 1
}

preinstalled_find_app() {
  local name="$1" dir candidate
  for dir in /Applications /System/Applications /System/Applications/Utilities; do
    for candidate in "$name" "${name#Apple }"; do
      if [ -d "$dir/${candidate}.app" ]; then
        printf '%s' "$dir/${candidate}.app"
        return 0
      fi
    done
  done
  return 1
}

uninstall_app() {
  local name="$1" app

  if ! app="$(preinstalled_find_app "$name")"; then
    log_success "$name not installed"
    return 0
  fi
  if ! preinstalled_is_apple_bundle "$app"; then
    log_warn "Skipping $app (not an Apple bundle)"
    return 0
  fi
  if preinstalled_is_protected "$app"; then
    log_dim "$name is protected by macOS; best effort only (Dock unpin)"
    return 0
  fi
  run sudo rm -rf "$app"
  if ! is_dry_run; then
    log_success "Uninstalled $name"
  fi
}

# Logic Pro and MainStage share these libraries, so keep them if either is installed.
remove_garageband_content() {
  local path
  if [ -d /Applications/GarageBand.app ] && ! is_dry_run; then
    return 0
  fi
  if [ -d "/Applications/Logic Pro.app" ] || [ -d "/Applications/Logic Pro X.app" ] \
    || [ -d /Applications/MainStage.app ]; then
    log_dim "Keeping GarageBand sound libraries (Logic Pro or MainStage uses them)"
    return 0
  fi
  for path in \
    "/Library/Application Support/GarageBand" \
    "/Library/Application Support/Logic" \
    "/Library/Audio/Apple Loops/Apple"; do
    if [ -e "$path" ]; then
      run sudo rm -rf "$path"
      if ! is_dry_run; then
        log_success "Removed $path"
      fi
    fi
  done
}

stop_photos_hotplug() {
  local val
  if ! is_dry_run; then
    val="$(run_user_capture defaults -currentHost read com.apple.ImageCapture disableHotPlug 2>/dev/null || true)"
    if [ "$val" = "1" ]; then
      log_success "Photos already stays closed when a device connects"
      return 0
    fi
  fi
  run_user defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
  if ! is_dry_run; then
    log_success "Photos will not open when an iPhone or camera connects"
  fi
}

# Per-app best effort beyond uninstall and Dock unpin. Safe to repeat.
preinstalled_best_effort() {
  case "${1#Apple }" in
    GarageBand) remove_garageband_content ;;
    Photos) stop_photos_hotplug ;;
  esac
}

dock_tile_label() {
  local plist="$1" i="$2" label url base
  label="$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:${i}:tile-data:file-label" "$plist" 2>/dev/null || true)"
  if [ -n "$label" ]; then
    printf '%s' "$label"
    return 0
  fi
  url="$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:${i}:tile-data:file-data:_CFURLString" "$plist" 2>/dev/null || true)"
  base="${url%/}"
  base="${base##*/}"
  base="${base%.app}"
  base="${base//%20/ }"
  printf '%s' "$base"
}

export_dock_plist() {
  local dest="$1"
  if running_via_sudo; then
    sudo -u "$SUDO_USER" -H defaults export com.apple.dock "$dest"
  else
    defaults export com.apple.dock "$dest"
  fi
}

import_dock_plist() {
  local src="$1"
  if running_via_sudo; then
    sudo -u "$SUDO_USER" -H defaults import com.apple.dock "$src"
  else
    defaults import com.apple.dock "$src"
  fi
}

unpin_preinstalled_from_dock() {
  local tmp count i label changed=0

  if is_dry_run; then
    log_dim "[dry-run] export Dock, delete listed tiles, import"
    return 0
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/mac-forge-dock.XXXXXX")"
  chmod a+rw "$tmp"

  if ! export_dock_plist "$tmp"; then
    log_warn "Could not read Dock preferences"
    rm -f "$tmp"
    return 0
  fi

  count=0
  while /usr/libexec/PlistBuddy -c "Print :persistent-apps:${count}" "$tmp" >/dev/null 2>&1; do
    count=$((count + 1))
  done

  i=$((count - 1))
  while [ "$i" -ge 0 ]; do
    label="$(dock_tile_label "$tmp" "$i")"
    if preinstalled_should_remove "$label"; then
      /usr/libexec/PlistBuddy -c "Delete :persistent-apps:${i}" "$tmp"
      log_success "Dock: removed $label"
      changed=1
    fi
    i=$((i - 1))
  done

  if [ "$changed" -eq 1 ]; then
    import_dock_plist "$tmp"
    killall Dock >/dev/null 2>&1 || true
  else
    log_success "Dock already has no listed Apple apps pinned"
  fi
  rm -f "$tmp"
}

if [ "${#MACOS_REMOVE_APPS[@]}" -eq 0 ]; then
  log_info "MACOS_REMOVE_APPS is empty — nothing to remove"
  return 0 2>/dev/null || exit 0
fi

macos_bootstrap_sudo_start

log_info "Removing listed Apple apps"
for name in "${MACOS_REMOVE_APPS[@]}"; do
  uninstall_app "$name"
  preinstalled_best_effort "$name"
done

log_info "Removing listed Apple apps from the Dock"
unpin_preinstalled_from_dock

log_success "Preinstalled apps handled"

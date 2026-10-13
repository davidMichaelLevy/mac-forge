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

# shellcheck source=../lib/preinstalled.sh
source "$MACOS_BOOTSTRAP_ROOT/lib/preinstalled.sh"

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

remove_garageband_content() {
  local path
  if [ -d /Applications/GarageBand.app ] && ! is_dry_run; then
    return 0
  fi
  if preinstalled_logic_installed; then
    log_dim "Keeping GarageBand sound libraries (Logic Pro or MainStage uses them)"
    return 0
  fi
  while IFS= read -r path; do
    if [ -e "$path" ]; then
      run sudo rm -rf "$path"
      if ! is_dry_run; then
        log_success "Removed $path"
      fi
    fi
  done < <(preinstalled_garageband_paths)
}

stop_photos_hotplug() {
  if ! is_dry_run && preinstalled_photos_hotplug_disabled; then
    log_success "Photos already stays closed when a device connects"
    return 0
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

  count="$(dock_tile_count "$tmp")"
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

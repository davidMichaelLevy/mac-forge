# shellcheck shell=bash
# preinstalled — uninstall optional Apple apps; unpin both lists from the Dock.
# MACOS_KEEP_APPS wins when the name is also on a remove list. A keep-only
# name (not on either remove list) is ignored and is not an error.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${REMOVE_PREINSTALLED_APPS:-false}"; then
  log_warn "Skipping preinstalled apps (REMOVE_PREINSTALLED_APPS is false)."
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

preinstalled_is_kept() {
  local label="$1" name
  [ -n "$label" ] || return 1
  if [ "${#MACOS_KEEP_APPS[@]}" -gt 0 ]; then
    for name in "${MACOS_KEEP_APPS[@]}"; do
      preinstalled_names_equal "$label" "$name" && return 0
    done
  fi
  return 1
}

preinstalled_in_list() {
  local label="$1" name
  [ -n "$label" ] || return 1
  if [ "${#MACOS_OPTIONAL_APPS[@]}" -gt 0 ]; then
    for name in "${MACOS_OPTIONAL_APPS[@]}"; do
      preinstalled_names_equal "$label" "$name" && return 0
    done
  fi
  if [ "${#MACOS_NONOPTIONAL_APPS[@]}" -gt 0 ]; then
    for name in "${MACOS_NONOPTIONAL_APPS[@]}"; do
      preinstalled_names_equal "$label" "$name" && return 0
    done
  fi
  return 1
}

# Uninstall/unpin only when the name is on a remove list and not kept.
# Keep-only names (keep list but neither remove list) are ignored.
preinstalled_should_remove() {
  local label="$1"
  preinstalled_in_list "$label" || return 1
  preinstalled_is_kept "$label" && return 1
  return 0
}

preinstalled_is_apple_bundle() {
  local app="$1" id
  id="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  case "$id" in
    com.apple.*) return 0 ;;
    *) return 1 ;;
  esac
}

uninstall_optional_app() {
  local name="$1" app="/Applications/${name}.app"

  if preinstalled_is_kept "$name"; then
    log_success "Keeping $name"
    return 0
  fi
  if [ ! -d "$app" ]; then
    log_success "$name not installed"
    return 0
  fi
  if ! preinstalled_is_apple_bundle "$app"; then
    log_warn "Skipping $app (not an Apple bundle)"
    return 0
  fi
  run sudo rm -rf "$app"
  log_success "Uninstalled $name"
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

  tmp="$(mktemp "${TMPDIR:-/tmp}/mac-forge-dock.XXXXXX")"
  chmod a+rw "$tmp"

  if is_dry_run; then
    log_dim "[dry-run] export Dock, delete listed tiles, import"
    rm -f "$tmp"
    return 0
  fi

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

macos_bootstrap_sudo_start

if [ "${#MACOS_OPTIONAL_APPS[@]}" -gt 0 ]; then
  log_info "Uninstalling optional Apple apps"
  for name in "${MACOS_OPTIONAL_APPS[@]}"; do
    uninstall_optional_app "$name"
  done
else
  log_warn "MACOS_OPTIONAL_APPS is empty — nothing to uninstall"
fi

log_info "Removing listed Apple apps from the Dock"
unpin_preinstalled_from_dock

log_success "Preinstalled apps handled"

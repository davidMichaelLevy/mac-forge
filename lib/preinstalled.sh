# shellcheck shell=bash
# preinstalled helpers — shared by modules/32-preinstalled.sh and forge doctor.
# Not a numbered module.

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
  for name in ${MACOS_REMOVE_APPS[@]+"${MACOS_REMOVE_APPS[@]}"}; do
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

# Logic Pro and MainStage share GarageBand's sound libraries.
preinstalled_logic_installed() {
  [ -d "/Applications/Logic Pro.app" ] || [ -d "/Applications/Logic Pro X.app" ] \
    || [ -d /Applications/MainStage.app ]
}

preinstalled_garageband_paths() {
  printf '%s\n' \
    "/Library/Application Support/GarageBand" \
    "/Library/Application Support/Logic" \
    "/Library/Audio/Apple Loops/Apple"
}

preinstalled_photos_hotplug_disabled() {
  [ "$(run_user_capture defaults -currentHost read com.apple.ImageCapture disableHotPlug 2>/dev/null || true)" = "1" ]
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

dock_tile_count() {
  local plist="$1" count=0
  while /usr/libexec/PlistBuddy -c "Print :persistent-apps:${count}" "$plist" >/dev/null 2>&1; do
    count=$((count + 1))
  done
  printf '%s' "$count"
}

# Print each pinned Dock app label, one per line. Fails if the Dock is unreadable.
preinstalled_dock_labels() {
  local tmp count i=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/mac-forge-dock.XXXXXX")"
  chmod a+rw "$tmp"
  if ! export_dock_plist "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  count="$(dock_tile_count "$tmp")"
  while [ "$i" -lt "$count" ]; do
    dock_tile_label "$tmp" "$i"
    printf '\n'
    i=$((i + 1))
  done
  rm -f "$tmp"
}

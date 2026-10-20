# shellcheck shell=bash
# packages — install formulae (and optionally casks/fonts) from the Brewfile.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
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
run_brew bundle $BUNDLE_ARGS
log_success "Brewfile applied"

# Exclusive cask sets: keep one member, uninstall the rest if present.
exclusive_choice_for_set() {
  local spec="$1" member chosen
  local rest="${spec}|"

  if [ "${#EXCLUSIVE_CASK_CHOICES[@]}" -gt 0 ]; then
    while [ -n "$rest" ]; do
      member="${rest%%|*}"
      rest="${rest#*|}"
      [ -n "$member" ] || continue
      for chosen in "${EXCLUSIVE_CASK_CHOICES[@]}"; do
        if [ "$member" = "$chosen" ]; then
          printf '%s' "$member"
          return 0
        fi
      done
    done
  fi

  printf '%s' "${spec%%|*}"
}

cask_is_installed() {
  run_user env PATH="$PATH" brew list --cask "$1" >/dev/null 2>&1
}

uninstall_exclusive_cask() {
  local token="$1"
  if is_dry_run; then
    log_dim "[dry-run] brew uninstall --cask $token"
    return 0
  fi
  if cask_is_installed "$token"; then
    run_brew uninstall --cask "$token"
    log_success "Uninstalled $token"
  fi
}

install_exclusive_cask() {
  local token="$1"
  if is_dry_run; then
    log_dim "[dry-run] brew install --cask $token"
    return 0
  fi
  if cask_is_installed "$token"; then
    log_success "$token already installed"
    return 0
  fi
  run_brew install --cask "$token"
  log_success "Installed $token"
}

apply_exclusive_cask_sets() {
  local spec chosen member rest

  if ! is_truthy "${INSTALL_CASKS:-true}"; then
    return 0
  fi
  if [ "${#EXCLUSIVE_CASK_SETS[@]}" -eq 0 ]; then
    return 0
  fi

  log_info "Applying exclusive cask sets"
  for spec in "${EXCLUSIVE_CASK_SETS[@]}"; do
    [ -n "$spec" ] || continue
    chosen="$(exclusive_choice_for_set "$spec")"
    log_info "Exclusive set: keep $chosen"
    rest="${spec}|"
    while [ -n "$rest" ]; do
      member="${rest%%|*}"
      rest="${rest#*|}"
      [ -n "$member" ] || continue
      if [ "$member" != "$chosen" ]; then
        uninstall_exclusive_cask "$member"
      fi
    done
    install_exclusive_cask "$chosen"
  done
}

apply_exclusive_cask_sets

# Uncommented `kind "token"` lines only (not `# cask "token"`).
# kind is ignored: brew, cask, mas, tap, or anything else. A tap path matches
# its final component (`nikitabobko/tap/aerospace` and `aerospace` are the same).
brewfile_lists() {
  local token="$1"
  local short="${token##*/}"
  local escaped_token escaped_short

  escaped_token="$(printf '%s' "$token" | sed -E 's/[][(){}.+*?^$|\\]/\\&/g')"
  escaped_short="$(printf '%s' "$short" | sed -E 's/[][(){}.+*?^$|\\]/\\&/g')"
  grep -Eq "^[[:space:]]*[A-Za-z][A-Za-z0-9_]*[[:space:]]+\"(${escaped_token}|[^\"]*/${escaped_short}|${escaped_short})\"([,[:space:]]|$)" "$BREWFILE"
}

remind_if_listed() {
  local token="$1"
  local msg="$2"

  brewfile_lists "$token" || return 0
  log_reminder "$msg"
}

# Chrome and Firefox have their own modules. DisplayLink is a macos task.
# Order: unlock accounts → sync → work identity → editors → chat → leisure.
remind_if_listed bitwarden "Open Bitwarden and sign in."
remind_if_listed crosspaste "Open CrossPaste and grant Accessibility (and any other prompts) so clipboard sync works."
remind_if_listed nikitabobko/tap/aerospace "Open AeroSpace and grant Accessibility so tiling works."
remind_if_listed dropbox "Open Dropbox and sign in."
remind_if_listed gh "Run gh auth login to sign GitHub CLI in."
remind_if_listed mas "Sign in to the Mac App Store (required before mas can install anything)."
remind_if_listed cursor "Open Cursor and sign in."
remind_if_listed claude "Open Claude and sign in."
remind_if_listed claude-code "Run claude to sign Anthropic Claude Code in."
remind_if_listed slack "Open Slack and sign in."
remind_if_listed signal "Open Signal and sign in."
remind_if_listed discord "Open Discord and sign in."
remind_if_listed zoom "Open Zoom and sign in."
remind_if_listed tidal "Open TIDAL and sign in."
remind_if_listed spotify "Open Spotify and sign in."
remind_if_listed Netflix "Open Netflix and sign in."
remind_if_listed steam "Open Steam and sign in."

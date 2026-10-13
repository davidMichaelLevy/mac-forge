# shellcheck shell=bash
# homebrew — install Homebrew if needed and export it for later modules.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
  return 0 2>/dev/null || exit 0
fi

eval_brew_shellenv

# Homebrew's installer calls execute_sudo(), which runs commands directly when
# euid is already 0. It also aborts in check_run_command_as_root. When this
# bootstrap was started with sudo, skip that one guard so the existing
# escalation is forwarded instead of dropped and re-prompted.
install_official_homebrew() {
  local installer prefix group

  installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if running_via_sudo; then
    installer="$(
      awk '
        /^check_run_command_as_root\(\)/ { print; print "  return 0"; next }
        { print }
      ' <<<"$installer"
    )"
    _run_with_child_logs bash env NONINTERACTIVE=1 /bin/bash -c "$installer"
    prefix=""
    if [ -x /opt/homebrew/bin/brew ]; then
      prefix="$(/opt/homebrew/bin/brew --prefix)"
    elif [ -x /usr/local/bin/brew ]; then
      prefix="$(/usr/local/bin/brew --prefix)"
    fi
    if [ -n "$prefix" ] && [ -d "$prefix" ]; then
      group="$(id -gn "$SUDO_USER" 2>/dev/null || echo staff)"
      run chown -R "${SUDO_USER}:${group}" "$prefix"
    fi
  else
    _run_with_child_logs bash /bin/bash -c "$installer"
  fi
}

if command_exists brew; then
  log_success "Homebrew already installed ($(brew --prefix))"
  log_info "Updating Homebrew"
  run_brew update --verbose
else
  log_info "Installing Homebrew (you may be prompted for your password)."
  if is_dry_run; then
    log_dim "[dry-run] Homebrew install script"
  else
    install_official_homebrew
  fi
  eval_brew_shellenv
  if ! is_dry_run && ! command_exists brew; then
    die "Homebrew installed but brew is not on PATH. Open a new terminal and re-run."
  fi
  log_success "Homebrew installed"
fi

if command_exists brew || is_dry_run; then
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_ENV_HINTS=1
fi

homebrew_autoupdate_status() {
  run_user_capture env PATH="$PATH" brew autoupdate status 2>/dev/null || true
}

homebrew_autoupdate_matches() {
  local status="$1"
  local greedy="$2"
  local interval="$3"

  printf '%s' "$status" | grep -q "installed and running" || return 1
  printf '%s' "$status" | grep -qF "$interval" || return 1
  printf '%s' "$status" | grep -q "Upgrade: formulae and casks" || return 1
  printf '%s' "$status" | grep -q "Cleanup: yes" || return 1
  printf '%s' "$status" | grep -q "AC power only: yes" || return 1
  if is_truthy "$greedy"; then
    printf '%s' "$status" | grep -q "Greedy cask upgrades: yes" || return 1
  else
    printf '%s' "$status" | grep -q "Greedy cask upgrades: yes" && return 1
  fi
  return 0
}

# The LaunchAgent has no terminal, so macOS checks App Management against the
# script and Homebrew's ruby when a cask upgrade replaces an app.
homebrew_autoupdate_app_management() {
  local pane script ruby_dir ruby_link ruby_real script_state ruby_state
  pane="x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles"
  script="$HOME/Library/Application Support/com.github.domt4.homebrew-autoupdate/brew_autoupdate"
  ruby_dir="${HOMEBREW_REPOSITORY:-$(brew --repository)}/Library/Homebrew/vendor/portable-ruby/current/bin"
  ruby_link="$ruby_dir/ruby"

  if [ ! -d "${HOMEBREW_PREFIX:-$(brew --prefix)}/Caskroom" ]; then
    return 0
  fi
  if [ ! -f "$script" ] || [ ! -x "$ruby_link" ]; then
    log_dim "App Management check skipped (autoupdate script or portable ruby not found)"
    return 0
  fi
  ruby_real="$(cd -P "$ruby_dir" && pwd)/ruby"

  script_state="$(tcc_state kTCCServiceSystemPolicyAppBundles "$script")"
  ruby_state="$(tcc_state kTCCServiceSystemPolicyAppBundles "$ruby_real" "$ruby_link")"

  if [ "$script_state" = granted ] && [ "$ruby_state" = granted ]; then
    log_success "App Management already allowed for scheduled cask upgrades"
    return 0
  fi
  if [ "$script_state" = unknown ] && [ "$ruby_state" = unknown ]; then
    log_reminder "Allow brew_autoupdate and ruby in Privacy & Security → App Management, or scheduled cask upgrades cannot replace apps."
    return 0
  fi
  run_user open "$pane"
  log_task "Allow brew_autoupdate and ruby in Privacy & Security → App Management (+, then Command-Shift-G for the paths below), then re-run."
  log_dim "$script"
  log_dim "$ruby_real"
}

apply_homebrew_autoupdate() {
  local want interval greedy status
  want="${HOMEBREW_AUTOUPDATE:-}"
  interval="${HOMEBREW_AUTOUPDATE_INTERVAL:-22:00}"
  greedy="${HOMEBREW_AUTOUPDATE_GREEDY:-false}"

  if [ -z "$want" ]; then
    log_info "Homebrew autoupdate: leave current"
    return 0
  fi

  if ! is_truthy "$want" && ! is_falsy "$want"; then
    log_warn "HOMEBREW_AUTOUPDATE=$want (use true, false, or empty)"
    return 0
  fi

  if is_dry_run; then
    if is_truthy "$want"; then
      log_dim "[dry-run] brew tap domt4/autoupdate && brew autoupdate start $interval --upgrade --cleanup --ac-only"
      log_dim "[dry-run] check App Management for brew_autoupdate and ruby"
    else
      log_dim "[dry-run] brew autoupdate stop"
    fi
    return 0
  fi

  if ! command_exists brew; then
    return 0
  fi

  if is_falsy "$want"; then
    if homebrew_autoupdate_status | grep -q "installed and running"; then
      run_brew autoupdate stop
      log_success "Homebrew autoupdate stopped"
    else
      log_info "Homebrew autoupdate already off"
    fi
    return 0
  fi

  log_info "Homebrew autoupdate: $interval"
  run_brew tap domt4/autoupdate
  if ! run_user env PATH="$PATH" brew trust --command domt4/autoupdate/autoupdate >/dev/null 2>&1; then
    log_dim "brew trust skipped (already trusted or older Homebrew)"
  fi

  status="$(homebrew_autoupdate_status)"
  if homebrew_autoupdate_matches "$status" "$greedy" "$interval"; then
    log_success "Homebrew autoupdate already scheduled"
  else
    run_user env PATH="$PATH" brew autoupdate delete >/dev/null 2>&1 || true
    if is_truthy "$greedy"; then
      run_brew autoupdate start "$interval" --upgrade --cleanup --ac-only --greedy
    else
      run_brew autoupdate start "$interval" --upgrade --cleanup --ac-only
    fi
    log_success "Homebrew autoupdate scheduled ($interval)"
  fi

  homebrew_autoupdate_app_management
}

apply_homebrew_autoupdate

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
    NONINTERACTIVE=1 /bin/bash -c "$installer"
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
    /bin/bash -c "$installer"
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
  run_user env PATH="$PATH" brew autoupdate status 2>/dev/null || true
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
    return 0
  fi

  run_user env PATH="$PATH" brew autoupdate delete >/dev/null 2>&1 || true
  if is_truthy "$greedy"; then
    run_brew autoupdate start "$interval" --upgrade --cleanup --ac-only --greedy
  else
    run_brew autoupdate start "$interval" --upgrade --cleanup --ac-only
  fi
  log_success "Homebrew autoupdate scheduled ($interval)"
}

apply_homebrew_autoupdate

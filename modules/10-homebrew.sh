# shellcheck shell=bash
# homebrew — install Homebrew if needed and export it for later modules.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
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

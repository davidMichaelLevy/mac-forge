# shellcheck shell=bash
# homebrew — install Homebrew if needed and export it for later modules.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

eval_brew_shellenv

if command_exists brew; then
  log_success "Homebrew already installed ($(brew --prefix))"
  log_info "Updating Homebrew"
  run_user brew update --quiet
else
  log_info "Installing Homebrew (you may be prompted for your password)."
  if is_dry_run; then
    log_dim "[dry-run] Homebrew install script"
  else
    run_user env NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

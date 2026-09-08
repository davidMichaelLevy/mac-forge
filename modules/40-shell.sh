# shellcheck shell=bash
# shell — keep zsh as the login shell (Catalina+ default, but verify).

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${SETUP_SHELL:-true}"; then
  log_warn "Skipping shell (SETUP_SHELL is false)."
  return 0 2>/dev/null || exit 0
fi

desired="/bin/zsh"
if [ ! -x "$desired" ]; then
  log_warn "Skipping shell ($desired not found)."
  return 0 2>/dev/null || exit 0
fi

current="${SHELL:-}"
if [ "$current" = "$desired" ]; then
  log_success "Login shell is already $desired"
else
  log_info "Setting login shell to $desired (was ${current:-unknown})"
  if command_exists dscl && is_macos; then
    run chsh -s "$desired"
  else
    run chsh -s "$desired"
  fi
  log_success "Login shell set to $desired"
fi

# Homebrew's bash is nicer for scripts; add it to /etc/shells if we installed it.
eval_brew_shellenv
brew_bash=""
if command_exists brew; then
  brew_bash="$(brew --prefix 2>/dev/null)/bin/bash"
fi
if [ -n "$brew_bash" ] && [ -x "$brew_bash" ] && is_macos; then
  if ! grep -qx "$brew_bash" /etc/shells 2>/dev/null; then
    log_info "Adding $brew_bash to /etc/shells"
    if is_dry_run; then
      log_dim "[dry-run] append $brew_bash to /etc/shells"
    else
      printf '%s\n' "$brew_bash" | run sudo tee -a /etc/shells >/dev/null
    fi
  else
    log_success "Homebrew bash already listed in /etc/shells"
  fi
fi

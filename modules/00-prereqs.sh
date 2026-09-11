# shellcheck shell=bash
# prereqs — Xcode Command Line Tools and Rosetta (Apple Silicon).

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
  return 0 2>/dev/null || exit 0
fi

wait_for_clt() {
  local tries=0
  while ! xcode-select -p >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -gt 90 ]; then
      die "Timed out waiting for Xcode Command Line Tools. Install them from the dialog and re-run."
    fi
    log_info "Waiting for Xcode Command Line Tools to finish installing…"
    sleep 20
  done
}

if ! is_macos; then
  log_warn "Skipping prereqs (not macOS)."
  return 0 2>/dev/null || exit 0
fi

if xcode-select -p >/dev/null 2>&1; then
  log_success "Xcode Command Line Tools already installed"
else
  log_info "Installing Xcode Command Line Tools (a system dialog may appear)."
  if is_dry_run; then
    log_dim "[dry-run] xcode-select --install"
  else
    xcode-select --install 2>/dev/null || true
    wait_for_clt
    log_success "Xcode Command Line Tools installed"
  fi
fi

if is_apple_silicon && is_truthy "${INSTALL_ROSETTA:-true}"; then
  if pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    log_success "Rosetta 2 already installed"
  else
    log_info "Installing Rosetta 2"
    run softwareupdate --install-rosetta --agree-to-license
    log_success "Rosetta 2 installed"
  fi
else
  log_info "Rosetta 2 not needed on this Mac"
fi

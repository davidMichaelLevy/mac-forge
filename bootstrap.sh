#!/usr/bin/env bash
# macos-bootstrap — turn a brand-new Mac into a known configuration.
#
#   ./bootstrap.sh              # run every module
#   ./bootstrap.sh packages git # run selected modules
#   ./bootstrap.sh --dry-run    # print what would happen
#   ./bootstrap.sh doctor       # report current machine state
#
set -euo pipefail

MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")" && pwd)"
export MACOS_BOOTSTRAP_ROOT

# shellcheck source=lib/common.sh
source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"

SKIP_OS_CHECK=false
LIST_ONLY=false
RUN_DOCTOR=false

usage() {
  cat <<'EOF'
macos-bootstrap — bootstrap a new Mac laptop

Usage:
  ./bootstrap.sh [options] [modules...]

Options:
  -h, --help         Show this help
  -y, --yes          Don't ask for confirmation
  --dry-run          Print commands without running them
  --list             List available modules and exit
  --skip-os-check    Allow running off macOS (for dry-run / CI)
  doctor             Report what's already installed and configured

Modules (all of them, in order, if you omit the list):
  prereqs     Xcode Command Line Tools, Rosetta
  homebrew    Install Homebrew and put it on PATH
  packages    Brewfile formulae, casks, and fonts
  python      Install CPython with pyenv (global plus extra versions)
  macos       Finder, Dock, keyboard, screenshots, and other defaults
  shell       Make sure zsh is the login shell
  git         Global identity and sane git defaults
  ssh         ed25519 key plus macOS keychain agent
  dotfiles    Symlink shell/editor config into $HOME

Edit config/config.sh (copy from config.example.sh) and config/Brewfile
before the first real run.

Examples:
  ./bootstrap.sh
  ./bootstrap.sh --dry-run
  ./bootstrap.sh -y packages git
  ./bootstrap.sh doctor
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --list)
      LIST_ONLY=true
      shift
      ;;
    --skip-os-check)
      SKIP_OS_CHECK=true
      shift
      ;;
    doctor|--doctor)
      RUN_DOCTOR=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1 (see --help)"
      ;;
    *)
      break
      ;;
  esac
done

export DRY_RUN ASSUME_YES

print_banner() {
  printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf '%s\n' "  macos-bootstrap"
  printf '%s\n' "  New Mac → known configuration"
  printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if is_dry_run; then
    log_warn "Dry run — no changes will be made."
  fi
}

print_module_list() {
  local path name
  printf 'Available modules:\n'
  for path in $(list_module_files); do
    name="$(module_name_from_path "$path")"
    printf '  %-12s %s\n' "$name" "$(basename "$path")"
  done
}

resolve_module_path() {
  local want="$1"
  local path name
  for path in $(list_module_files); do
    name="$(module_name_from_path "$path")"
    if [ "$name" = "$want" ] || [ "$(basename "$path" .sh)" = "$want" ]; then
      printf '%s' "$path"
      return 0
    fi
  done
  return 1
}

run_doctor() {
  local ok missing

  log_step "Doctor"
  printf '    OS:          %s %s\n' "$(uname -s)" "$(uname -m)"
  if is_macos; then
    printf '    Product:     %s %s (%s)\n' \
      "$(sw_vers -productName)" "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)"
  else
    log_warn "Not macOS — remaining checks are best-effort."
  fi

  printf '\n    Tooling\n'
  if is_macos && xcode-select -p >/dev/null 2>&1; then
    log_success "Xcode CLT   $(xcode-select -p)"
  else
    log_warn "Xcode CLT   not found"
  fi

  eval_brew_shellenv
  eval_pyenv

  for cmd in brew git gh nvim starship fnm uv pyenv pipenv rg fd fzf bat eza; do
    if command_exists "$cmd"; then
      ok="$(command -v "$cmd")"
      log_success "$(printf '%-11s %s' "$cmd" "$ok")"
    else
      log_warn "$(printf '%-11s missing' "$cmd")"
    fi
  done

  printf '\n    Python\n'
  if command_exists pyenv; then
    log_success "$(printf '%-11s %s' "pyenv" "$(pyenv version-name 2>/dev/null || echo '(no global)')")"
    if command_exists python; then
      log_success "$(printf '%-11s %s' "python" "$(python --version 2>&1) $(command -v python)")"
    else
      log_warn "$(printf '%-11s missing from shims (run ./bootstrap.sh python)' "python")"
    fi
    while IFS= read -r ver; do
      [ -n "$ver" ] || continue
      log_success "$(printf '%-11s %s' "installed" "$ver")"
    done < <(pyenv versions --bare 2>/dev/null || true)
  else
    log_warn "pyenv        missing"
  fi

  printf '\n    Identity\n'
  if command_exists git; then
    printf '    git user:    %s\n' "$(git config --global user.name 2>/dev/null || echo '(unset)')"
    printf '    git email:   %s\n' "$(git config --global user.email 2>/dev/null || echo '(unset)')"
  fi

  printf '\n    SSH\n'
  missing=1
  for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
    if [ -f "$key" ]; then
      log_success "key          $key"
      missing=0
    fi
  done
  if [ "$missing" -eq 1 ]; then
    log_warn "key          none found"
  fi
  if [ -f "$HOME/.ssh/config" ]; then
    log_success "config       $HOME/.ssh/config"
  else
    log_warn "config       missing"
  fi

  printf '\n    Dotfiles\n'
  for link in .zshrc .zprofile .gitignore_global .editorconfig; do
    if [ -L "$HOME/$link" ]; then
      log_success "$(printf '%-11s -> %s' "$link" "$(readlink "$HOME/$link")")"
    elif [ -e "$HOME/$link" ]; then
      log_warn "$(printf '%-11s exists (not a symlink)' "$link")"
    else
      log_warn "$(printf '%-11s missing' "$link")"
    fi
  done

  if is_macos && command_exists brew; then
    printf '\n    Brewfile\n'
    if brew bundle check --file="$MACOS_BOOTSTRAP_ROOT/config/Brewfile" >/dev/null 2>&1; then
      log_success "Brewfile     all listed packages present"
    else
      log_warn "Brewfile     some packages are missing (run ./bootstrap.sh packages)"
    fi
  fi

  printf '\n'
}

# --- doctor / list can run before config ---------------------------------

if [ "$LIST_ONLY" = true ]; then
  print_module_list
  exit 0
fi

macos_bootstrap_load_config

if [ "$RUN_DOCTOR" = true ]; then
  print_banner
  run_doctor
  exit 0
fi

MODULE_QUEUE=""
if [ $# -gt 0 ]; then
  while [ $# -gt 0 ]; do
    resolved="$(resolve_module_path "$1" || true)"
    if [ -z "$resolved" ]; then
      die "Unknown module: $1 (try --list)"
    fi
    MODULE_QUEUE="$MODULE_QUEUE $resolved"
    shift
  done
else
  for path in $(list_module_files); do
    MODULE_QUEUE="$MODULE_QUEUE $path"
  done
fi

if [ "$SKIP_OS_CHECK" != true ]; then
  require_macos
fi

print_banner
log_info "Root: $MACOS_BOOTSTRAP_ROOT"
if [ -n "${COMPUTER_NAME:-}" ]; then
  log_info "Computer name: $COMPUTER_NAME"
fi
if [ -n "${GIT_USER_NAME:-}" ]; then
  log_info "Git: $GIT_USER_NAME <$GIT_USER_EMAIL>"
fi

log_step "Plan"
for path in $MODULE_QUEUE; do
  log_info "$(module_name_from_path "$path")"
done

if ! confirm "Run these modules on this Mac?"; then
  log_warn "Aborted."
  exit 1
fi

FAILED=0
for path in $MODULE_QUEUE; do
  name="$(module_name_from_path "$path")"
  log_step "Module: $name"
  # shellcheck disable=SC1090
  if ! source "$path"; then
    log_error "Module $name failed"
    FAILED=1
  fi
done

macos_bootstrap_sudo_stop

log_step "Done"
if [ "$FAILED" -ne 0 ]; then
  die "One or more modules failed."
fi

if is_dry_run; then
  log_success "Dry run finished. Re-run without --dry-run to apply."
else
  log_success "Bootstrap finished."
  log_info "Open a new terminal so shell and PATH changes take effect."
  log_info "Some macOS defaults apply fully after logout or restart."
  if is_truthy "${SETUP_SSH:-true}" && [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    log_info "Add your SSH public key to GitHub if you have not already:"
    log_dim "https://github.com/settings/keys"
  fi
fi

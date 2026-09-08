# shellcheck shell=bash
# Shared helpers for macos-bootstrap. Sourced, not executed.

if [ -n "${MACOS_BOOTSTRAP_COMMON_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
MACOS_BOOTSTRAP_COMMON_LOADED=1

DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES="${ASSUME_YES:-false}"

# --- colors ---------------------------------------------------------------

_c_blue=""
_c_green=""
_c_yellow=""
_c_red=""
_c_dim=""
_c_bold=""
_c_reset=""

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  _ncolors="$(tput colors 2>/dev/null || echo 0)"
  if [ "${_ncolors:-0}" -ge 8 ]; then
    _c_blue="$(tput setaf 4)"
    _c_green="$(tput setaf 2)"
    _c_yellow="$(tput setaf 3)"
    _c_red="$(tput setaf 1)"
    _c_dim="$(tput dim)"
    _c_bold="$(tput bold)"
    _c_reset="$(tput sgr0)"
  fi
fi

log_step()    { printf '\n%s==>%s %s%s%s\n'  "$_c_blue" "$_c_reset" "$_c_bold" "$*" "$_c_reset"; }
log_info()    { printf '    %s\n' "$*"; }
log_success() { printf '    %s✓%s %s\n' "$_c_green" "$_c_reset" "$*"; }
log_warn()    { printf '    %s!%s %s\n' "$_c_yellow" "$_c_reset" "$*"; }
log_error()   { printf '    %s✗%s %s\n' "$_c_red" "$_c_reset" "$*" >&2; }
log_dim()     { printf '    %s%s%s\n' "$_c_dim" "$*" "$_c_reset"; }

die() {
  log_error "$*"
  exit 1
}

# --- predicates -----------------------------------------------------------

is_macos() {
  [ "$(uname -s)" = "Darwin" ]
}

is_apple_silicon() {
  [ "$(uname -m)" = "arm64" ]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_truthy() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

is_dry_run() {
  is_truthy "$DRY_RUN"
}

# --- config ---------------------------------------------------------------

macos_bootstrap_load_config() {
  local example="$MACOS_BOOTSTRAP_ROOT/config/config.example.sh"
  local local_cfg="$MACOS_BOOTSTRAP_ROOT/config/config.sh"

  if [ -f "$local_cfg" ]; then
    # shellcheck source=/dev/null
    source "$local_cfg"
  elif [ -f "$example" ]; then
    log_warn "No config/config.sh — using config.example.sh"
    log_dim "Copy it to config/config.sh and edit your name, email, and options."
    # shellcheck source=/dev/null
    source "$example"
  fi

  GIT_USER_NAME="${GIT_USER_NAME:-}"
  GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
  COMPUTER_NAME="${COMPUTER_NAME:-}"
  SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
  SSH_KEY_COMMENT="${SSH_KEY_COMMENT:-$GIT_USER_EMAIL}"

  INSTALL_ROSETTA="${INSTALL_ROSETTA:-true}"
  INSTALL_PACKAGES="${INSTALL_PACKAGES:-true}"
  INSTALL_CASKS="${INSTALL_CASKS:-true}"
  APPLY_MACOS_DEFAULTS="${APPLY_MACOS_DEFAULTS:-true}"
  SETUP_SHELL="${SETUP_SHELL:-true}"
  SETUP_GIT="${SETUP_GIT:-true}"
  SETUP_SSH="${SETUP_SSH:-true}"
  SETUP_PYTHON="${SETUP_PYTHON:-true}"
  LINK_DOTFILES="${LINK_DOTFILES:-true}"

  MACOS_DOCK_AUTOHIDE="${MACOS_DOCK_AUTOHIDE:-true}"
  MACOS_KEY_REPEAT_FAST="${MACOS_KEY_REPEAT_FAST:-true}"
  MACOS_SHOW_HIDDEN_FILES="${MACOS_SHOW_HIDDEN_FILES:-true}"
  MACOS_TAP_TO_CLICK="${MACOS_TAP_TO_CLICK:-true}"
  MACOS_NATURAL_SCROLL="${MACOS_NATURAL_SCROLL:-false}"
  # Empty means skip; unset defaults to firefox.
  MACOS_DEFAULT_BROWSER="${MACOS_DEFAULT_BROWSER-firefox}"
  # Empty means skip; unset defaults to the latest stable CPython 3.x.
  PYENV_PYTHON_VERSION="${PYENV_PYTHON_VERSION-latest}"
  PYENV_PYTHON_EXTRA_VERSIONS="${PYENV_PYTHON_EXTRA_VERSIONS-3.9 3.10 3.11 3.12 3.13 3.14}"
}

# --- run wrappers ---------------------------------------------------------

# Run a command, or print it during --dry-run.
run() {
  if is_dry_run; then
    log_dim "[dry-run] $*"
    return 0
  fi
  "$@"
}

# Like run, but swallow a non-zero exit and warn instead of aborting.
run_ok() {
  if is_dry_run; then
    log_dim "[dry-run] $*"
    return 0
  fi
  if ! "$@"; then
    log_warn "Command failed (continuing): $*"
    return 0
  fi
}

confirm() {
  local prompt="${1:-Continue?}"
  local reply

  if is_truthy "$ASSUME_YES"; then
    return 0
  fi
  if [ ! -t 0 ]; then
    die "Not a tty. Re-run with --yes to skip confirmation."
  fi

  printf '%s [%s/%s] ' "$prompt" "y" "N"
  read -r reply
  case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

require_macos() {
  if is_macos; then
    return 0
  fi
  die "This bootstrap is for macOS. Found $(uname -s)."
}

# Ensure pyenv shims are on PATH for this process.
eval_pyenv() {
  export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  eval_brew_shellenv
  if command_exists pyenv; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
  fi
}

# Ensure Homebrew is on PATH for the rest of this process (Apple Silicon + Intel).
eval_brew_shellenv() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_dir() {
  run mkdir -p "$1"
}

# Symlink src -> dst. Existing real files are backed up; matching links are left alone.
link_file() {
  local src="$1"
  local dst="$2"
  local dst_dir current bak

  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    die "Cannot link missing source: $src"
  fi

  dst_dir="$(dirname "$dst")"
  ensure_dir "$dst_dir"

  if [ -L "$dst" ]; then
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      log_success "Already linked $(basename "$dst")"
      return 0
    fi
    log_warn "Replacing symlink $dst"
    run rm "$dst"
  elif [ -e "$dst" ]; then
    bak="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    log_warn "Backing up existing $(basename "$dst") -> $bak"
    run mv "$dst" "$bak"
  fi

  run ln -s "$src" "$dst"
  log_success "Linked $dst"
}

# Keep sudo alive while a long module runs. Call macos_bootstrap_sudo_stop when done.
_SUDO_KEEPALIVE_PID=""

macos_bootstrap_sudo_start() {
  if is_dry_run; then
    return 0
  fi
  sudo -v
  (
    while true; do
      sudo -n true
      sleep 50
      kill -0 "$$" || exit
    done
  ) 2>/dev/null &
  _SUDO_KEEPALIVE_PID=$!
}

macos_bootstrap_sudo_stop() {
  if [ -n "${_SUDO_KEEPALIVE_PID:-}" ]; then
    kill "${_SUDO_KEEPALIVE_PID}" 2>/dev/null || true
    _SUDO_KEEPALIVE_PID=""
  fi
}

module_name_from_path() {
  local base
  base="$(basename "$1" .sh)"
  printf '%s' "$base" | sed 's/^[0-9][0-9]*-//'
}

list_module_files() {
  local f
  for f in "$MACOS_BOOTSTRAP_ROOT/modules/"*.sh; do
    [ -f "$f" ] || continue
    printf '%s\n' "$f"
  done | sort
}

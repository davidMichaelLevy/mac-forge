# shellcheck shell=bash
# python — install CPython with pyenv. One version is global; extras are available only.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
  return 0 2>/dev/null || exit 0
fi

want="${PYENV_PYTHON_VERSION:-}"
extras="${PYENV_PYTHON_EXTRA_VERSIONS:-}"
if [ -z "$want" ] && [ -z "$extras" ]; then
  log_info "No PYENV_PYTHON_VERSION or PYENV_PYTHON_EXTRA_VERSIONS — not installing Python."
  return 0 2>/dev/null || exit 0
fi

eval_brew_shellenv

if ! command_exists pyenv && ! is_dry_run; then
  die "pyenv is not on PATH. Run the packages module first."
fi

# Stable CPython only (skip 3.13.0a1, 3.13.0t, miniconda, …).
latest_cpython_matching() {
  local pattern="$1"
  pyenv install -l \
    | sed 's/^[[:space:]]*//' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | grep -E "$pattern" \
    | tail -1 || true
}

resolve_python_version() {
  local requested="$1"
  local escaped resolved

  case "$requested" in
    latest|3)
      latest_cpython_matching '^3\.'
      return
      ;;
  esac

  if pyenv install -l | sed 's/^[[:space:]]*//' | grep -qx "$requested"; then
    printf '%s' "$requested"
    return
  fi

  escaped="$(printf '%s' "$requested" | sed 's/\./\\./g')"
  resolved="$(latest_cpython_matching "^${escaped}(\.|$)")"
  printf '%s' "$resolved"
}

install_cpython() {
  local version="$1"

  if pyenv versions --bare 2>/dev/null | grep -qx "$version"; then
    log_success "Python $version already installed"
  else
    log_info "Installing Python $version via pyenv (compiles from source; may take a few minutes)"
    run_user pyenv install --skip-existing "$version"
  fi

  if [ -x "${PYENV_ROOT}/versions/${version}/bin/python" ]; then
    log_info "Upgrading pip, setuptools, and wheel for $version"
    run_user env PYENV_VERSION="$version" pyenv exec pip install --upgrade pip setuptools wheel
  fi
}

if is_dry_run; then
  log_dim "[dry-run] pyenv install --skip-existing (${want:-none}) && pyenv global"
  log_dim "[dry-run] extra CPythons (not global): ${extras:-none}"
  return 0 2>/dev/null || exit 0
fi

eval_pyenv

global_version=""
if [ -n "$want" ]; then
  global_version="$(resolve_python_version "$want")"
  if [ -z "$global_version" ]; then
    die "Could not resolve a CPython version from PYENV_PYTHON_VERSION=${want}"
  fi

  log_info "Global Python: $global_version (from PYENV_PYTHON_VERSION=${want})"
  install_cpython "$global_version"

  current="$(pyenv global 2>/dev/null | awk 'NR==1 { print; exit }' || true)"
  if [ "$current" = "$global_version" ]; then
    log_success "pyenv global is already $global_version"
  else
    run_user pyenv global "$global_version"
    run_user pyenv rehash
    log_success "pyenv global = $global_version"
  fi
fi

if [ -n "$extras" ]; then
  log_info "Extra CPythons (installed, not set as global): $extras"
  # shellcheck disable=SC2086
  for spec in $extras; do
    extra_version="$(resolve_python_version "$spec")"
    if [ -z "$extra_version" ]; then
      log_warn "Could not resolve extra CPython '${spec}' — skipping"
      continue
    fi
    if [ -n "$global_version" ] && [ "$extra_version" = "$global_version" ]; then
      log_dim "$extra_version is already the global interpreter"
      continue
    fi
    install_cpython "$extra_version"
  done
  run_user pyenv rehash
fi

eval_pyenv

if command_exists python; then
  log_success "$(python --version 2>&1) ($(pyenv which python 2>/dev/null || command -v python))"
fi

# shellcheck shell=bash
# java — install JDKs with SDKMAN. One version is the default; extras are available only.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
  return 0 2>/dev/null || exit 0
fi

want="${SDKMAN_JAVA_VERSION:-}"
extras="${SDKMAN_JAVA_EXTRA_VERSIONS:-}"
vendor="${SDKMAN_JAVA_VENDOR:-amzn}"
if [ -z "$want" ] && [ -z "$extras" ]; then
  log_info "No SDKMAN_JAVA_VERSION or SDKMAN_JAVA_EXTRA_VERSIONS — not installing Java."
  return 0 2>/dev/null || exit 0
fi

if is_dry_run; then
  log_dim "[dry-run] install SDKMAN if missing"
  log_dim "[dry-run] sdk install java (${want:-none}, vendor ${vendor}) && sdk default java"
  log_dim "[dry-run] extra JDKs (not default): ${extras:-none}"
  return 0 2>/dev/null || exit 0
fi

export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

# SDKMAN's installer refuses Bash older than 4. macOS /bin/bash is 3.2, so
# the installer and every `sdk` call run under zsh.
run_sdk() {
  # shellcheck disable=SC2016
  run_user zsh -c '
    export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    sdkman_auto_answer=true
    sdk "$@"
  ' run_sdk "$@"
}

install_sdkman() {
  local tmp

  if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
    log_success "SDKMAN already installed"
    return 0
  fi

  command_exists curl || die "curl is required to install SDKMAN."
  command_exists unzip || die "unzip is required to install SDKMAN."
  command_exists zsh || die "zsh is required to install SDKMAN."

  log_info "Installing SDKMAN"
  tmp="$(mktemp)"
  curl -fsSL -o "$tmp" "https://get.sdkman.io?ci=true&rcupdate=false"
  run_user zsh "$tmp"
  rm -f "$tmp"

  if [ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
    die "SDKMAN install did not produce $SDKMAN_DIR/bin/sdkman-init.sh"
  fi
  log_success "SDKMAN installed"
}

sdkman_platform() {
  local machine
  case "$(uname -m)" in
    arm64|aarch64) machine="arm64" ;;
    *) machine="x64" ;;
  esac
  printf '%s%s' "$(uname -s | tr '[:upper:]' '[:lower:]')" "$machine"
}

load_java_identifiers() {
  local url
  url="https://api.sdkman.io/2/candidates/java/$(sdkman_platform)/versions/all"
  JAVA_IDENTIFIERS="$(curl -fsSL --max-time 30 -A "SDKMAN/5.0" "$url" | tr ',' '\n' | sed '/^$/d')" || true
  if [ -z "$JAVA_IDENTIFIERS" ]; then
    die "Could not list Java versions from $url"
  fi
}

# Zero-padded components so string compare orders 8 < 11 < 21.
version_sort_key() {
  printf '%s\n' "$1" | tr '.+' '\n' | awk 'BEGIN { ORS = "" } { printf "%08d.", $1 + 0 }'
}

version_matches_spec() {
  local version="$1"
  local spec="$2"

  [ "$version" = "$spec" ] && return 0
  case "$version" in
    "$spec".*|"$spec"+*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_java_version() {
  local spec="$1"
  local id version key best best_key

  if printf '%s\n' "$JAVA_IDENTIFIERS" | grep -Fxq "$spec"; then
    printf '%s' "$spec"
    return 0
  fi

  best=""
  best_key=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case "$id" in
      *ea*|*-fx*|*.fx*) continue ;;
      *"-${vendor}") ;;
      *) continue ;;
    esac
    version="${id%-*}"
    if [ "$spec" != "latest" ]; then
      version_matches_spec "$version" "$spec" || continue
    fi
    key="$(version_sort_key "$version")"
    if [ -z "$best_key" ] || [ "$key" \> "$best_key" ]; then
      best="$id"
      best_key="$key"
    fi
  done <<EOF
$JAVA_IDENTIFIERS
EOF
  printf '%s' "$best"
}

java_current_identifier() {
  local link="${SDKMAN_DIR}/candidates/java/current"
  local target

  [ -L "$link" ] || return 1
  target="$(readlink "$link")"
  printf '%s' "${target##*/}"
}

install_java() {
  local version="$1"

  if [ -x "${SDKMAN_DIR}/candidates/java/${version}/bin/java" ]; then
    log_success "Java $version already installed"
    return 0
  fi

  log_info "Installing Java $version"
  run_sdk install java "$version"
}

install_sdkman
load_java_identifiers

previous="$(java_current_identifier || true)"
global_version=""

if [ -n "$want" ]; then
  global_version="$(resolve_java_version "$want")"
  if [ -z "$global_version" ]; then
    die "Could not resolve a ${vendor} JDK from SDKMAN_JAVA_VERSION=${want}"
  fi
  log_info "Default Java: $global_version (from SDKMAN_JAVA_VERSION=${want})"
fi

if [ -n "$extras" ]; then
  log_info "Extra JDKs (installed, not set as default): $extras"
  # shellcheck disable=SC2086
  for spec in $extras; do
    extra_version="$(resolve_java_version "$spec")"
    if [ -z "$extra_version" ]; then
      log_warn "Could not resolve extra JDK '${spec}' — skipping"
      continue
    fi
    if [ -n "$global_version" ] && [ "$extra_version" = "$global_version" ]; then
      log_dim "$extra_version is already the default JDK"
      continue
    fi
    install_java "$extra_version"
  done
fi

if [ -n "$global_version" ]; then
  install_java "$global_version"
  current="$(java_current_identifier || true)"
  if [ "$current" = "$global_version" ]; then
    log_success "SDKMAN default Java is already $global_version"
  else
    run_sdk default java "$global_version"
    log_success "SDKMAN default Java = $global_version"
  fi
elif [ -n "$previous" ]; then
  current="$(java_current_identifier || true)"
  if [ "$current" != "$previous" ]; then
    run_sdk default java "$previous"
  fi
fi

eval_sdkman

if command_exists java; then
  log_success "$(java -version 2>&1 | awk 'NR==1 { print; exit }') ($(command -v java))"
fi

#!/usr/bin/env bash
# Download mac-forge as a tarball and run bootstrap.sh so forge.sh can run.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh)
#
# Extra arguments are passed through to bootstrap.sh (and then forge.sh).
#
set -euo pipefail

# sudo sets euid 0; that is not a root login. Use the caller's home.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  USER="$SUDO_USER"
  LOGNAME="$SUDO_USER"
  HOME="$(eval "echo ~${SUDO_USER}")"
  export USER LOGNAME HOME
fi

REPO_SLUG="${MAC_FORGE_REPO:-davidMichaelLevy/mac-forge}"
REF="${MAC_FORGE_REF:-main}"
DEST="${MAC_FORGE_DIR:-$HOME/mac-forge}"
RUN=true
FORCE=false

usage() {
  cat <<EOF
mac-forge installer — download a tarball, then run bootstrap.sh so forge.sh can run

Usage:
  bash <(curl -fsSL https://raw.githubusercontent.com/${REPO_SLUG}/main/install.sh) [options] [args...]

Options:
  -h, --help     Show this help, then the next script's help (extra args are forwarded)
  --dir DIR      Download destination (default: \$HOME/mac-forge)
  --ref REF      Branch for the tarball (default: main)
  -f, --force    Overwrite existing files in the destination with the tarball
  --no-run       Download only; do not continue

Environment:
  MAC_FORGE_DIR    Same as --dir
  MAC_FORGE_REF    Same as --ref
  MAC_FORGE_REPO   GitHub owner/name (default: ${REPO_SLUG})

Other arguments are passed through to bootstrap.sh (and then forge.sh).
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '==> %s\n' "$*"
}

download_tarball() {
  local tmp src url
  url="https://github.com/${REPO_SLUG}/archive/refs/heads/${REF}.tar.gz"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/mac-forge.XXXXXX")"
  # shellcheck disable=SC2064
  trap 'rm -rf "'"$tmp"'"' EXIT

  info "Downloading ${REPO_SLUG}@${REF}"
  curl -fsSL "$url" | tar -xz -C "$tmp"

  src=""
  for d in "$tmp"/*; do
    if [ -d "$d" ]; then
      src="$d"
      break
    fi
  done
  [ -n "$src" ] || die "archive did not contain a mac-forge directory"

  mkdir -p "$DEST"
  cp -Rf "$src"/. "$DEST/"
  rm -rf "$tmp"
  trap - EXIT
}

dir_is_empty() {
  local path="$1"
  set -- "$path"/.[!.]* "$path"/..?* "$path"/*
  if [ ! -e "$1" ] && [ ! -e "$2" ] && [ ! -e "$3" ]; then
    return 0
  fi
  return 1
}

ensure_repo() {
  if [ -e "$DEST" ] && [ ! -d "$DEST" ]; then
    die "$DEST exists and is not a directory"
  fi

  if [ "$FORCE" = true ]; then
    download_tarball
    return
  fi

  if [ -f "$DEST/bootstrap.sh" ]; then
    return
  fi

  if [ -d "$DEST" ] && ! dir_is_empty "$DEST"; then
    die "$DEST exists and does not look like mac-forge (pass --dir or --force)"
  fi

  download_tarball
}

# If this was started via `curl | bash`, attach the terminal so bootstrap can prompt.
if [ ! -t 0 ]; then
  attach_tty() { exec </dev/tty; }
  attach_tty 2>/dev/null || true
  unset -f attach_tty
fi

SHOW_HELP=false
BOOTSTRAP_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    --dir)
      [ $# -ge 2 ] || die "--dir requires a path"
      DEST="$2"
      shift 2
      ;;
    --ref)
      [ $# -ge 2 ] || die "--ref requires a branch or tag"
      REF="$2"
      shift 2
      ;;
    --no-run)
      RUN=false
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    --)
      shift
      BOOTSTRAP_ARGS+=("$@")
      break
      ;;
    *)
      BOOTSTRAP_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  usage
  printf '\n'
  ensure_repo
  [ -x "$DEST/bootstrap.sh" ] || chmod +x "$DEST/bootstrap.sh"
  [ -f "$DEST/bootstrap.sh" ] || die "bootstrap.sh missing in $DEST"
  cd "$DEST"
  exec ./bootstrap.sh --help "${BOOTSTRAP_ARGS[@]+"${BOOTSTRAP_ARGS[@]}"}"
fi

ensure_repo

[ -x "$DEST/bootstrap.sh" ] || chmod +x "$DEST/bootstrap.sh"
[ -f "$DEST/bootstrap.sh" ] || die "bootstrap.sh missing in $DEST"

if [ "$RUN" != true ]; then
  info "Downloaded to $DEST (--no-run). Execute with:"
  printf '    %s\n' "$DEST/bootstrap.sh"
  exit 0
fi

export MAC_FORGE_REF="$REF"
export MAC_FORGE_REPO="$REPO_SLUG"
info "Running $DEST/bootstrap.sh ${BOOTSTRAP_ARGS[*]+"${BOOTSTRAP_ARGS[*]}"}"
cd "$DEST"
exec ./bootstrap.sh "${BOOTSTRAP_ARGS[@]+"${BOOTSTRAP_ARGS[@]}"}"

#!/usr/bin/env bash
# Download mac-forge and run bootstrap.sh.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh)
#
# Extra arguments are passed through to bootstrap.sh:
#   bash <(curl -fsSL .../install.sh) --dry-run
#   bash <(curl -fsSL .../install.sh) -y packages
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

usage() {
  cat <<EOF
mac-forge installer — download the repo and run bootstrap.sh

Usage:
  bash <(curl -fsSL https://raw.githubusercontent.com/${REPO_SLUG}/main/install.sh) [options] [bootstrap args...]

Options:
  -h, --help     Show this help
  --dir DIR      Clone/download destination (default: \$HOME/mac-forge)
  --ref REF      Git branch or ref (default: main)
  --no-run       Download only; do not execute bootstrap.sh

Environment:
  MAC_FORGE_DIR    Same as --dir
  MAC_FORGE_REF    Same as --ref
  MAC_FORGE_REPO   GitHub owner/name (default: ${REPO_SLUG})

Anything else is forwarded to bootstrap.sh (-y, --dry-run, doctor, module names).
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '==> %s\n' "$*"
}

# /usr/bin/git on a fresh Mac is an Xcode CLT stub; calling it pops a GUI dialog.
git_usable() {
  xcode-select -p >/dev/null 2>&1 || return 1
  command -v git >/dev/null 2>&1 || return 1
  git --version >/dev/null 2>&1
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
  cp -R "$src"/. "$DEST/"
  rm -rf "$tmp"
  trap - EXIT
}

update_git() {
  info "Updating git checkout in $DEST"
  git -C "$DEST" fetch --depth 1 origin "$REF"
  git -C "$DEST" checkout "$REF"
  git -C "$DEST" pull --ff-only origin "$REF"
}

clone_git() {
  local git_url="https://github.com/${REPO_SLUG}.git"
  info "Cloning ${git_url} (${REF})"
  git clone --depth 1 --branch "$REF" "$git_url" "$DEST"
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

  if [ -d "$DEST/.git" ] && git_usable; then
    update_git
    return
  fi

  if [ -d "$DEST" ] && [ ! -f "$DEST/bootstrap.sh" ] && ! dir_is_empty "$DEST"; then
    die "$DEST exists and does not look like mac-forge (pass --dir)"
  fi

  if git_usable && [ ! -d "$DEST" ]; then
    clone_git
  else
    download_tarball
  fi
}

# If this was started via `curl | bash`, attach the terminal so bootstrap can prompt.
if [ ! -t 0 ]; then
  attach_tty() { exec </dev/tty; }
  attach_tty 2>/dev/null || true
  unset -f attach_tty
fi

BOOTSTRAP_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
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

ensure_repo

[ -x "$DEST/bootstrap.sh" ] || chmod +x "$DEST/bootstrap.sh"
[ -f "$DEST/bootstrap.sh" ] || die "bootstrap.sh missing in $DEST"

if [ ! -f "$DEST/config/config.sh" ] && [ -f "$DEST/config/config.example.sh" ]; then
  cp "$DEST/config/config.example.sh" "$DEST/config/config.sh"
  info "Wrote $DEST/config/config.sh from the example (edit name, email, options)"
fi

if [ "$RUN" != true ]; then
  info "Downloaded to $DEST (--no-run). Execute with:"
  printf '    %s\n' "$DEST/bootstrap.sh"
  exit 0
fi

info "Running $DEST/bootstrap.sh ${BOOTSTRAP_ARGS[*]+"${BOOTSTRAP_ARGS[*]}"}"
cd "$DEST"
exec ./bootstrap.sh "${BOOTSTRAP_ARGS[@]+"${BOOTSTRAP_ARGS[@]}"}"

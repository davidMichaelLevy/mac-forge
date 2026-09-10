# shellcheck shell=bash
# sync — turn a tarball tree into a git checkout, then fast-forward to origin.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${SYNC_MAC_FORGE:-true}"; then
  log_warn "Skipping sync (SYNC_MAC_FORGE is false)."
  return 0 2>/dev/null || exit 0
fi

forge_git() {
  run_user env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
    git -C "$MACOS_BOOTSTRAP_ROOT" "$@"
}

git_usable_here() {
  if is_macos && ! xcode-select -p >/dev/null 2>&1; then
    return 1
  fi
  command_exists git || return 1
  git --version >/dev/null 2>&1
}

if ! git_usable_here; then
  log_warn "git is not usable yet (install Xcode CLT via prereqs)."
  return 0 2>/dev/null || exit 0
fi

ref="${MAC_FORGE_REF:-main}"
origin_url="https://github.com/${MAC_FORGE_REPO:-davidMichaelLevy/mac-forge}.git"

ensure_git_checkout() {
  if [ -d "$MACOS_BOOTSTRAP_ROOT/.git" ]; then
    return 0
  fi
  log_info "Initializing git in $MACOS_BOOTSTRAP_ROOT"
  forge_git init
  forge_git remote add origin "$origin_url"
}

if is_dry_run && [ ! -d "$MACOS_BOOTSTRAP_ROOT/.git" ]; then
  log_dim "[dry-run] git init && git remote add origin $origin_url"
  log_dim "[dry-run] git fetch origin $ref && git checkout -B $ref origin/$ref"
  return 0 2>/dev/null || exit 0
fi

ensure_git_checkout

if ! forge_git remote get-url origin >/dev/null 2>&1; then
  forge_git remote add origin "$origin_url"
fi

log_info "Syncing $MACOS_BOOTSTRAP_ROOT to origin/${ref}"

if is_dry_run; then
  forge_git fetch origin "$ref"
  forge_git checkout -B "$ref" "origin/${ref}"
  return 0 2>/dev/null || exit 0
fi

# A fresh `git init` over a tarball looks dirty (everything untracked) until
# the first checkout. Only refuse to sync an existing commit with local edits.
if forge_git rev-parse --verify HEAD >/dev/null 2>&1; then
  if [ -n "$(forge_git status --porcelain 2>/dev/null || true)" ]; then
    log_warn "Checkout has local changes; not syncing."
    return 0 2>/dev/null || exit 0
  fi
fi

forge_git fetch origin "$ref"
if ! forge_git checkout -B "$ref" "origin/${ref}"; then
  log_warn "Could not update onto origin/${ref}; leaving the checkout as-is."
  return 0 2>/dev/null || exit 0
fi
log_success "mac-forge is on origin/${ref}"

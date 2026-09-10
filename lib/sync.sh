# shellcheck shell=bash
# sync — turn a tarball tree into a git checkout, then fast-forward to origin.
# Sourced by bootstrap.sh. Not a numbered module.

macos_bootstrap_sync() {
  local ref origin_url

  if ! is_truthy "${SYNC_MAC_FORGE:-true}"; then
    log_warn "Skipping sync (SYNC_MAC_FORGE is false)."
    return 0
  fi

  if ! macos_bootstrap_git_usable; then
    log_warn "git is not usable yet (install Xcode CLT via prereqs)."
    return 0
  fi

  ref="${MAC_FORGE_REF:-main}"
  origin_url="https://github.com/${MAC_FORGE_REPO:-davidMichaelLevy/mac-forge}.git"

  if is_dry_run && [ ! -d "$MACOS_BOOTSTRAP_ROOT/.git" ]; then
    log_dim "[dry-run] git init && git remote add origin $origin_url"
    log_dim "[dry-run] git fetch origin $ref && git checkout -B $ref origin/$ref"
    return 0
  fi

  macos_bootstrap_ensure_git_checkout "$origin_url"

  if ! macos_bootstrap_forge_git remote get-url origin >/dev/null 2>&1; then
    macos_bootstrap_forge_git remote add origin "$origin_url"
  fi

  log_info "Syncing $MACOS_BOOTSTRAP_ROOT to origin/${ref}"

  if is_dry_run; then
    macos_bootstrap_forge_git fetch origin "$ref"
    macos_bootstrap_forge_git checkout -B "$ref" "origin/${ref}"
    return 0
  fi

  # A fresh `git init` over a tarball looks dirty (everything untracked) until
  # the first checkout. Only refuse to sync an existing commit with local edits.
  if macos_bootstrap_forge_git rev-parse --verify HEAD >/dev/null 2>&1; then
    if [ -n "$(macos_bootstrap_forge_git status --porcelain 2>/dev/null || true)" ]; then
      log_warn "Checkout has local changes; not syncing."
      return 0
    fi
  fi

  macos_bootstrap_forge_git fetch origin "$ref"
  macos_bootstrap_log_incoming_commits "$ref"
  if ! macos_bootstrap_forge_git checkout -B "$ref" "origin/${ref}"; then
    log_warn "Could not update onto origin/${ref}; leaving the checkout as-is."
    return 0
  fi
  log_success "mac-forge is on origin/${ref}"
}

# Commits on origin/$ref that HEAD does not have yet. First checkout: last 15.
macos_bootstrap_log_incoming_commits() {
  local ref="$1"
  local tip="origin/${ref}"
  local range

  if ! macos_bootstrap_forge_git rev-parse --verify "$tip" >/dev/null 2>&1; then
    return 0
  fi

  if macos_bootstrap_forge_git rev-parse --verify HEAD >/dev/null 2>&1; then
    range="HEAD..${tip}"
    if [ -z "$(macos_bootstrap_forge_git log --oneline "$range" 2>/dev/null || true)" ]; then
      log_info "Already up to date with ${tip}"
      return 0
    fi
    log_info "Incoming commits:"
    macos_bootstrap_forge_git -c core.pager=cat log --pretty=format:'    %h  %s%+b' "$range"
    printf '\n'
    return 0
  fi

  log_info "Incoming commits:"
  macos_bootstrap_forge_git -c core.pager=cat log --pretty=format:'    %h  %s%+b' -15 "$tip"
  printf '\n'
}

macos_bootstrap_forge_git() {
  run_user env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
    git -C "$MACOS_BOOTSTRAP_ROOT" "$@"
}

macos_bootstrap_git_usable() {
  if is_macos && ! xcode-select -p >/dev/null 2>&1; then
    return 1
  fi
  command_exists git || return 1
  git --version >/dev/null 2>&1
}

macos_bootstrap_ensure_git_checkout() {
  local origin_url="$1"

  if [ -d "$MACOS_BOOTSTRAP_ROOT/.git" ]; then
    return 0
  fi
  log_info "Initializing git in $MACOS_BOOTSTRAP_ROOT"
  macos_bootstrap_forge_git init
  macos_bootstrap_forge_git remote add origin "$origin_url"
}

# shellcheck shell=bash
# dotfiles — copy starter files into ~/.config/mac-forge/dotfiles.
# Shell files in $HOME source that store so installers can append without
# rewriting the managed copy. Other names stay as symlinks to the store.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
  return 0 2>/dev/null || exit 0
fi

DOT_REPO="$MACOS_BOOTSTRAP_ROOT/dotfiles"
DOT_STORE="${XDG_CONFIG_HOME:-$HOME/.config}/mac-forge/dotfiles"

stage_dotfile() {
  local name="$1"
  local repo="$DOT_REPO/$name"
  local stored="$DOT_STORE/$name"

  if [ ! -e "$repo" ] && [ ! -L "$repo" ]; then
    die "Cannot copy missing source: $repo"
  fi

  ensure_dir "$DOT_STORE"
  if is_dry_run; then
    log_dim "[dry-run] cp $repo $stored"
    return 0
  fi

  if [ -f "$stored" ] && cmp -s "$repo" "$stored"; then
    log_success "Already copied $name"
  else
    run_user cp "$repo" "$stored"
    log_success "Copied $name"
  fi
}

# Real file at dst that sources the store. Installer appends stay below the block.
ensure_source_wrapper() {
  local dst="$1"
  local name="$2"
  local begin="# >>> mac-forge >>>"
  local end="# <<< mac-forge <<<"
  local rel="mac-forge/dotfiles/${name}"
  local tmp block

  if is_dry_run; then
    log_dim "[dry-run] ensure $dst sources ${XDG_CONFIG_HOME:-$HOME/.config}/$rel"
    return 0
  fi

  block="${begin}
source \"\${XDG_CONFIG_HOME:-\$HOME/.config}/${rel}\"
${end}"

  if [ -L "$dst" ]; then
    log_warn "Replacing symlink $dst with a source wrapper"
    run_user rm "$dst"
  fi

  if [ -f "$dst" ] && grep -qF "$begin" "$dst" && grep -qF "$rel" "$dst"; then
    log_success "Already sourcing $name from $(basename "$dst")"
    return 0
  fi

  tmp="$(mktemp)"
  printf '%s\n' "$block" >"$tmp"
  if [ -f "$dst" ]; then
    printf '\n' >>"$tmp"
    cat "$dst" >>"$tmp"
    run_user cp "$tmp" "$dst"
    rm -f "$tmp"
    run_user chmod 644 "$dst"
    log_success "Prepended source wrapper to $dst"
    return 0
  fi

  if [ -e "$dst" ]; then
    rm -f "$tmp"
    die "Refusing to replace $dst (not a regular file)"
  fi

  run_user cp "$tmp" "$dst"
  rm -f "$tmp"
  run_user chmod 644 "$dst"
  log_success "Wrote source wrapper $dst"
}

publish_linked_dotfile() {
  local name="$1"
  local dst="$2"

  if is_dry_run; then
    stage_dotfile "$name"
    log_dim "[dry-run] ln -s $DOT_STORE/$name $dst"
    return 0
  fi
  stage_dotfile "$name"
  link_file "$DOT_STORE/$name" "$dst"
}

publish_shell_dotfile() {
  local name="$1"
  local dst="$2"

  stage_dotfile "$name"
  ensure_source_wrapper "$dst" "$name"
}

log_info "Dotfiles store: $DOT_STORE"

publish_shell_dotfile zshrc            "$HOME/.zshrc"
publish_shell_dotfile zprofile         "$HOME/.zprofile"
publish_linked_dotfile gitignore_global "$HOME/.gitignore_global"
publish_linked_dotfile editorconfig     "$HOME/.editorconfig"
publish_linked_dotfile hushlogin        "$HOME/.hushlogin"
publish_linked_dotfile starship.toml    "$HOME/.config/starship.toml"

log_success "Dotfiles published"
log_info "Existing non-wrapper files were backed up as *.bak.<timestamp> if they were replaced by a symlink."

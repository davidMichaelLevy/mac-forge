# shellcheck shell=bash
# dotfiles — copy starter files into $HOME, then symlink the usual names to those copies.
# The checkout is not the live target; deleting mac-forge must not break the shell.

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

publish_dotfile() {
  local name="$1"
  local dst="$2"
  local repo="$DOT_REPO/$name"
  local stored="$DOT_STORE/$name"

  if [ ! -e "$repo" ] && [ ! -L "$repo" ]; then
    die "Cannot copy missing source: $repo"
  fi

  ensure_dir "$DOT_STORE"
  if is_dry_run; then
    log_dim "[dry-run] cp $repo $stored"
    log_dim "[dry-run] ln -s $stored $dst"
    return 0
  fi

  if [ -f "$stored" ] && cmp -s "$repo" "$stored"; then
    log_success "Already copied $name"
  else
    run_user cp "$repo" "$stored"
    log_success "Copied $name"
  fi
  link_file "$stored" "$dst"
}

log_info "Dotfiles store: $DOT_STORE"

publish_dotfile zshrc            "$HOME/.zshrc"
publish_dotfile zprofile         "$HOME/.zprofile"
publish_dotfile gitignore_global "$HOME/.gitignore_global"
publish_dotfile editorconfig     "$HOME/.editorconfig"
publish_dotfile hushlogin        "$HOME/.hushlogin"
publish_dotfile starship.toml    "$HOME/.config/starship.toml"

log_success "Dotfiles linked"
log_info "Existing files were backed up as *.bak.<timestamp> if they weren't already our symlinks."

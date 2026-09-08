# shellcheck shell=bash
# dotfiles — symlink the repo's starter files into $HOME.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${LINK_DOTFILES:-true}"; then
  log_warn "Skipping dotfiles (LINK_DOTFILES is false)."
  return 0 2>/dev/null || exit 0
fi

DOT="$MACOS_BOOTSTRAP_ROOT/dotfiles"

link_file "$DOT/zshrc"             "$HOME/.zshrc"
link_file "$DOT/zprofile"          "$HOME/.zprofile"
link_file "$DOT/gitignore_global"  "$HOME/.gitignore_global"
link_file "$DOT/editorconfig"      "$HOME/.editorconfig"
link_file "$DOT/hushlogin"         "$HOME/.hushlogin"
link_file "$DOT/starship.toml"     "$HOME/.config/starship.toml"

log_success "Dotfiles linked"
log_info "Existing files were backed up as *.bak.<timestamp> if they weren't already our symlinks."

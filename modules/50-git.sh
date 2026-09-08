# shellcheck shell=bash
# git — identity, defaults, aliases. Skips identity fields that are empty.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! is_truthy "${SETUP_GIT:-true}"; then
  log_warn "Skipping git (SETUP_GIT is false)."
  return 0 2>/dev/null || exit 0
fi

if ! command_exists git && ! is_dry_run; then
  die "git is not on PATH. Run the packages module first."
fi

git_global() {
  run git config --global "$@"
}

if [ -n "${GIT_USER_NAME:-}" ]; then
  git_global user.name "$GIT_USER_NAME"
  log_success "user.name = $GIT_USER_NAME"
else
  log_warn "GIT_USER_NAME is empty — not changing user.name"
fi

if [ -n "${GIT_USER_EMAIL:-}" ]; then
  git_global user.email "$GIT_USER_EMAIL"
  log_success "user.email = $GIT_USER_EMAIL"
else
  log_warn "GIT_USER_EMAIL is empty — not changing user.email"
fi

log_info "Applying git defaults"
git_global init.defaultBranch main
git_global pull.rebase true
git_global fetch.prune true
git_global push.autoSetupRemote true
git_global rebase.autoStash true
git_global rerere.enabled true
git_global diff.algorithm histogram
git_global merge.conflictstyle zdiff3
git_global color.ui auto
git_global core.autocrlf input
git_global core.excludesfile "$HOME/.gitignore_global"

if command_exists nvim; then
  git_global core.editor nvim
elif command_exists vim; then
  git_global core.editor vim
fi

eval_brew_shellenv
if command_exists meld; then
  git_global diff.tool meld
  git_global difftool.prompt false
  git_global merge.tool meld
  git_global mergetool.prompt false
  git_global mergetool.keepBackup false
  log_success "diff/merge tool = meld"
else
  log_warn "meld not on PATH — skip git difftool (run ./bootstrap.sh packages)"
fi

# macOS keychain helper is built in.
if is_macos; then
  git_global credential.helper osxkeychain
fi

git_global alias.st "status -sb"
git_global alias.co checkout
git_global alias.br branch
git_global alias.ci commit
git_global alias.last "log -1 HEAD"
git_global alias.lg "log --oneline --decorate --graph --max-count=20"
git_global alias.unstage "reset HEAD --"

log_success "Git config written"

# shellcheck shell=bash
# ssh — generate a key if missing, wire macOS keychain, print the public key.

if [ -z "${MACOS_BOOTSTRAP_ROOT:-}" ]; then
  MACOS_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  # shellcheck source=../lib/common.sh
  source "$MACOS_BOOTSTRAP_ROOT/lib/common.sh"
  macos_bootstrap_load_config
fi

if ! module_is_enabled "${BASH_SOURCE[0]}"; then
  return 0 2>/dev/null || exit 0
fi

KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
KEY_PATH="$HOME/.ssh/id_${KEY_TYPE}"
PUB_PATH="${KEY_PATH}.pub"
COMMENT="${SSH_KEY_COMMENT:-$GIT_USER_EMAIL}"
MARKER="# macos-bootstrap"

ensure_dir "$HOME/.ssh"
if ! is_dry_run; then
  chmod 700 "$HOME/.ssh" 2>/dev/null || true
fi

if [ -f "$KEY_PATH" ]; then
  log_success "SSH key already exists: $KEY_PATH"
else
  log_info "Generating $KEY_TYPE key at $KEY_PATH"
  if [ -n "$COMMENT" ]; then
    run ssh-keygen -t "$KEY_TYPE" -f "$KEY_PATH" -C "$COMMENT" -N ""
  else
    run ssh-keygen -t "$KEY_TYPE" -f "$KEY_PATH" -C "macos-bootstrap" -N ""
  fi
  log_success "Created $KEY_PATH"
fi

if ! is_dry_run && [ -f "$KEY_PATH" ]; then
  chmod 600 "$KEY_PATH"
  [ -f "$PUB_PATH" ] && chmod 644 "$PUB_PATH"
fi

CONFIG="$HOME/.ssh/config"
if [ -f "$CONFIG" ] && grep -q "$MARKER" "$CONFIG" 2>/dev/null; then
  log_success "SSH config already includes bootstrap snippet"
else
  log_info "Writing macOS Keychain snippet to ~/.ssh/config"
  if is_dry_run; then
    log_dim "[dry-run] append UseKeychain block to $CONFIG"
  else
    if [ -f "$CONFIG" ]; then
      cp "$CONFIG" "${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    fi
    {
      printf '\n%s\n' "$MARKER"
      printf '%s\n' "Host *"
      printf '%s\n' "  AddKeysToAgent yes"
      printf '%s\n' "  UseKeychain yes"
      printf '%s\n' "  IdentityFile $KEY_PATH"
      printf '%s\n' "  IdentitiesOnly yes"
    } >>"$CONFIG"
    chmod 600 "$CONFIG"
  fi
  log_success "SSH config updated"
fi

if is_macos && [ -f "$KEY_PATH" ] && ! is_dry_run; then
  ssh-add --apple-use-keychain "$KEY_PATH" 2>/dev/null \
    || ssh-add -K "$KEY_PATH" 2>/dev/null \
    || ssh-add "$KEY_PATH" 2>/dev/null \
    || log_warn "Could not add key to agent (open a new terminal and run ssh-add)"
fi

if [ -f "$PUB_PATH" ]; then
  log_info "Public key (add this at https://github.com/settings/keys):"
  log_dim "$(cat "$PUB_PATH")"
elif is_dry_run; then
  log_dim "[dry-run] would print $PUB_PATH"
fi

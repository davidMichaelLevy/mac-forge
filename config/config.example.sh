# shellcheck shell=bash
# shellcheck disable=SC2034
# Copy this file to config.sh and edit. config.sh is gitignored.

# --- identity -------------------------------------------------------------

GIT_USER_NAME="David Levy"
GIT_USER_EMAIL="david.michael.levy@gmail.com"

# Optional. Sets ComputerName, HostName, and LocalHostName.
# Leave empty to leave the current name alone.
COMPUTER_NAME=""

# --- ssh ------------------------------------------------------------------

SSH_KEY_TYPE="ed25519"
# Defaults to GIT_USER_EMAIL when empty.
SSH_KEY_COMMENT=""

# --- modules (true/false) -------------------------------------------------

INSTALL_ROSETTA=true
INSTALL_PACKAGES=true
INSTALL_CASKS=true
APPLY_MACOS_DEFAULTS=true
SETUP_SHELL=true
SETUP_GIT=true
SETUP_SSH=true
LINK_DOTFILES=true

# --- macos defaults (used when APPLY_MACOS_DEFAULTS=true) -----------------

MACOS_DOCK_AUTOHIDE=true
MACOS_KEY_REPEAT_FAST=true
MACOS_SHOW_HIDDEN_FILES=true
MACOS_TAP_TO_CLICK=true
# HTTP/HTTPS handler (defaultbrowser name: firefox, chrome, safari).
# Leave empty to leave the current default alone.
MACOS_DEFAULT_BROWSER="firefox"

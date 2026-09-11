# shellcheck shell=bash
# shellcheck disable=SC2034
# Starter overlay. Copied to config.sh if that file is missing. config.sh is
# gitignored. Only keys you set here override config.defaults.sh.
# The merge is written to effective.config and sourced as the runtime config.

# --- identity -------------------------------------------------------------

USER_NAME="David Levy"
USER_EMAIL="david.michael.levy@gmail.com"

# Sharing display name (ComputerName). Empty = generated, e.g.
# dlevy-MacBook-Pro-16in-2024-X9K2 (login + model + screen + year + serial last 4).
# Spaces are replaced with hyphens. Ignored when SET_MACHINE_NAMES=false.
COMPUTER_NAME=""
# Optional. Overrides HostName only. Empty = ComputerName. Spaces become hyphens.
HOST_NAME=""
# Optional. Overrides LocalHostName (Bonjour). Empty = slug of ComputerName.
LOCAL_HOST_NAME=""
# false = leave ComputerName, HostName, and LocalHostName as they are.
SET_MACHINE_NAMES=true

# --- ssh ------------------------------------------------------------------

SSH_KEY_TYPE="ed25519"
# Empty = GIT_USER_EMAIL (which itself defaults to USER_EMAIL).
SSH_KEY_COMMENT=""

# --- modules (true/false) -------------------------------------------------
# MODULE_<name>_ENABLED from the filename (22-chrome.sh → MODULE_CHROME_ENABLED).
# Empty or unset = on; false = skip. Defaults live in config.defaults.sh.

# Off in config.defaults.sh (uninstalls optional Apple apps).
# MODULE_PREINSTALLED_ENABLED=true
# Fast-forward this checkout to origin before forge.sh runs
# (creates a git repo if install used a tarball).
SYNC_MAC_FORGE=true

# --- packages (used when MODULE_PACKAGES_ENABLED=true) --------------------

INSTALL_CASKS=true

# --- exclusive casks (used when INSTALL_CASKS=true) -----------------------

# docker-desktop vs orbstack: OrbStack is a lighter Docker Desktop replacement
# (same `docker` CLI). Free for personal use; company use needs a paid license.
EXCLUSIVE_CASK_CHOICES=(
  docker-desktop
)

# --- macos defaults (used when MODULE_MACOS_ENABLED=true) -----------------

# true = 24-hour, false = 12-hour, empty = leave the current clock.
MACOS_24_HOUR_CLOCK=true
# Apple "Natural" scrolling (content follows your fingers). false = reversed.
MACOS_NATURAL_SCROLL=false
# HTTP/HTTPS handler (defaultbrowser name: firefox, chrome, safari).
# Leave empty to leave the current default alone.
MACOS_DEFAULT_BROWSER="firefox"

# Keep these Apple apps if they are also on a remove list (optional or
# non-optional). Names match the .app bundle (no .app suffix).
MACOS_KEEP_APPS=(
)

# --- python (used when MODULE_PYTHON_ENABLED=true) ------------------------

# CPython to install with pyenv and set as `pyenv global`.
# Use "latest" (newest 3.x), a prefix like "3.13", or an exact "3.13.2".
# Leave empty to skip installing a global Python.
PYENV_PYTHON_VERSION="latest"

# Extra CPythons to install and leave available (pipenv, pyenv local, etc.).
# Space-separated prefixes or exact versions. Not set as global.
# Leave empty to install only the global version.
PYENV_PYTHON_EXTRA_VERSIONS="3.9 3.10 3.11 3.12 3.13 3.14"

# --- chrome (used when MODULE_CHROME_ENABLED=true) ------------------------

# Google account for Chrome sign-in and sync. Empty = USER_EMAIL.
CHROME_GOOGLE_ACCOUNT=""

# --- firefox (used when MODULE_FIREFOX_ENABLED=true) ----------------------

# Firefox Account for Sync. Empty = USER_EMAIL.
FIREFOX_SYNC_ACCOUNT=""

# --- git (used when MODULE_GIT_ENABLED=true) ------------------------------

# Empty = USER_NAME
GIT_USER_NAME=""
# Empty = USER_EMAIL
GIT_USER_EMAIL=""

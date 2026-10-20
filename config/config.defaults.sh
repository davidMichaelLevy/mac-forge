# shellcheck shell=bash
# shellcheck disable=SC2034
# Project defaults. Always loaded first. Do not edit for taste — override in
# config.sh (copied from config.example.sh).

# --- identity -------------------------------------------------------------

USER_NAME=""
USER_EMAIL=""

COMPUTER_NAME=""
HOST_NAME=""
LOCAL_HOST_NAME=""
SET_MACHINE_NAMES=true

# --- ssh ------------------------------------------------------------------

SSH_KEY_TYPE="ed25519"
SSH_KEY_COMMENT=""

# --- modules (true/false) -------------------------------------------------
# Kill switch is MODULE_<name>_ENABLED from the filename (22-chrome.sh →
# MODULE_CHROME_ENABLED). Empty or unset = on; false = skip.

MODULE_PREREQS_ENABLED=""
MODULE_HOMEBREW_ENABLED=""
MODULE_PACKAGES_ENABLED=""
MODULE_CHROME_ENABLED=""
MODULE_FIREFOX_ENABLED=""
MODULE_PYTHON_ENABLED=""
MODULE_JAVA_ENABLED=""
MODULE_MACOS_ENABLED=""
MODULE_PREINSTALLED_ENABLED=""
MODULE_SHELL_ENABLED=""
MODULE_GIT_ENABLED=""
MODULE_SSH_ENABLED=""
MODULE_DOTFILES_ENABLED=""

SYNC_MAC_FORGE=true
MAC_FORGE_REF="main"
MAC_FORGE_REPO="davidMichaelLevy/mac-forge"

# --- prereqs (used when MODULE_PREREQS_ENABLED=true) ----------------------

INSTALL_ROSETTA=true

# --- homebrew (used when MODULE_HOMEBREW_ENABLED=true) --------------------

# true = LaunchAgent runs brew upgrade on a schedule. false = stop it.
# empty = leave whatever is already configured.
# forge itself still uses brew bundle --no-upgrade.
HOMEBREW_AUTOUPDATE=true
# Duration (30m, 12h, 1d) or a daily clock time in 24-hour HH:MM (22:00 is 10pm).
HOMEBREW_AUTOUPDATE_INTERVAL=22:00
# true = also upgrade casks that update themselves (Chrome, Slack, …).
HOMEBREW_AUTOUPDATE_GREEDY=false

# --- packages (used when MODULE_PACKAGES_ENABLED=true) --------------------

INSTALL_CASKS=true

# --- exclusive casks (used when INSTALL_CASKS=true) -----------------------

EXCLUSIVE_CASK_SETS=(
  "docker-desktop|orbstack"
)
EXCLUSIVE_CASK_CHOICES=(
  docker-desktop
)

# --- macos defaults (used when MODULE_MACOS_ENABLED=true) -----------------

MACOS_DISPLAY_SLEEP_BATTERY=10
MACOS_DISPLAY_SLEEP_AC=0
MACOS_SCREENSAVER="Antarctica's Southern Lights"
MACOS_24_HOUR_CLOCK=true
MACOS_ICLOUD_DRIVE=false
MACOS_ICLOUD_FILE_SYNC=false
MACOS_ICLOUD_PHOTOS_SYNC=false
MACOS_ICLOUD_CALENDAR_SYNC=false
MACOS_DOCK_AUTOHIDE=true
MACOS_KEY_REPEAT_FAST=true
MACOS_SHOW_HIDDEN_FILES=true
MACOS_TAP_TO_CLICK=true
MACOS_NATURAL_SCROLL=false
MACOS_DEFAULT_BROWSER="firefox"

# --- preinstalled (used when MODULE_PREINSTALLED_ENABLED=true) ------------

# config.sh extends this with += and drops entries with config_list_remove.
MACOS_REMOVE_APPS=(
  GarageBand
  iMovie
  Photos
  Music
  TV
  News
  Freeform
  Maps
  FaceTime
  Messages
  Phone
  "iPhone Mirroring"
  "App Store"
  "Apple Games"
)

# --- python (used when MODULE_PYTHON_ENABLED=true) ------------------------

PYENV_PYTHON_VERSION="latest"
PYENV_PYTHON_EXTRA_VERSIONS="3.9 3.10 3.11 3.12 3.13 3.14"

# --- java (used when MODULE_JAVA_ENABLED=true) ----------------------------

# Amazon Corretto identifier suffix (amzn). A full identifier in the version
# list (21.0.0.0+35-tem) is installed as written.
SDKMAN_JAVA_VENDOR="amzn"
# Default JDK. "latest", a major like "21", or an exact SDKMAN identifier.
# 25 is the newest Java that AWS Lambda runs.
SDKMAN_JAVA_VERSION="25"
# Installed, not set as the default. 8, 11, 17, 21, and 25 are the Lambda
# runtimes. 26 and 27 are newer and are not Lambda runtimes.
SDKMAN_JAVA_EXTRA_VERSIONS="8 11 17 21 25 26 27"

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

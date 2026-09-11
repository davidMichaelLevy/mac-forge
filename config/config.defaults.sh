# shellcheck shell=bash
# shellcheck disable=SC2034
# Project defaults. Always loaded first. Do not edit for taste — override in
# config.sh (copied from config.example.sh).

# --- identity -------------------------------------------------------------

USER_NAME="David Levy"
USER_EMAIL="david.michael.levy@gmail.com"

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
MODULE_MACOS_ENABLED=""
MODULE_PREINSTALLED_ENABLED=false
MODULE_SHELL_ENABLED=""
MODULE_GIT_ENABLED=""
MODULE_SSH_ENABLED=""
MODULE_DOTFILES_ENABLED=""

SYNC_MAC_FORGE=true
MAC_FORGE_REF="main"
MAC_FORGE_REPO="davidMichaelLevy/mac-forge"

# --- prereqs (used when MODULE_PREREQS_ENABLED=true) ----------------------

INSTALL_ROSETTA=true

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
MACOS_DOCK_AUTOHIDE=true
MACOS_KEY_REPEAT_FAST=true
MACOS_SHOW_HIDDEN_FILES=true
MACOS_TAP_TO_CLICK=true
MACOS_NATURAL_SCROLL=false
MACOS_DEFAULT_BROWSER="firefox"

MACOS_OPTIONAL_APPS=(
  GarageBand
  iMovie
  Keynote
  Numbers
  Pages
)
MACOS_KEEP_APPS=(
)
MACOS_NONOPTIONAL_APPS=(
  "Activity Monitor"
  "AirPort Utility"
  "Apple Games"
  "App Store"
  Apps
  "Audio MIDI Setup"
  Automator
  "Bluetooth File Exchange"
  Books
  "Boot Camp Assistant"
  Calculator
  Calendar
  Chess
  Clock
  "ColorSync Utility"
  Console
  Contacts
  Dictionary
  "Digital Color Meter"
  "Directory Utility"
  "Disk Utility"
  "DVD Player"
  FaceTime
  "Find My"
  Finder
  "Font Book"
  Freeform
  Grapher
  Home
  "Image Capture"
  "Image Playground"
  "iPhone Mirroring"
  Journal
  Magnifier
  Mail
  Maps
  Messages
  "Migration Assistant"
  Music
  News
  Notes
  Passwords
  Phone
  "Photo Booth"
  Photos
  Podcasts
  Preview
  "Print Center"
  "QuickTime Player"
  Reminders
  Safari
  "Screen Sharing"
  Screenshot
  "Script Editor"
  Shortcuts
  Stickies
  Stocks
  "System Information"
  "System Settings"
  Terminal
  TextEdit
  Tips
  TV
  "Voice Memos"
  "VoiceOver Utility"
  Weather
)

# --- python (used when MODULE_PYTHON_ENABLED=true) ------------------------

PYENV_PYTHON_VERSION="latest"
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

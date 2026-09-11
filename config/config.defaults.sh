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

INSTALL_ROSETTA=true
INSTALL_PACKAGES=true
INSTALL_CASKS=true
APPLY_MACOS_DEFAULTS=true
SETUP_SHELL=true
SETUP_GIT=true
SETUP_SSH=true
SETUP_PYTHON=true
SETUP_CHROME=true
LINK_DOTFILES=true
SYNC_MAC_FORGE=true
REMOVE_PREINSTALLED_APPS=false

MAC_FORGE_REF="main"
MAC_FORGE_REPO="davidMichaelLevy/mac-forge"

# --- exclusive casks (used when INSTALL_CASKS=true) -----------------------

EXCLUSIVE_CASK_SETS=(
  "docker-desktop|orbstack"
)
EXCLUSIVE_CASK_CHOICES=(
  docker-desktop
)

# --- macos defaults (used when APPLY_MACOS_DEFAULTS=true) -----------------

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

# --- python (used when SETUP_PYTHON=true) ---------------------------------

PYENV_PYTHON_VERSION="latest"
PYENV_PYTHON_EXTRA_VERSIONS="3.9 3.10 3.11 3.12 3.13 3.14"

# --- chrome (used when SETUP_CHROME=true) ---------------------------------

# Google account for Chrome sign-in and sync. Empty = USER_EMAIL.
CHROME_GOOGLE_ACCOUNT=""

# --- git (used when SETUP_GIT=true) ---------------------------------------

# Empty = USER_NAME
GIT_USER_NAME=""
# Empty = USER_EMAIL
GIT_USER_EMAIL=""

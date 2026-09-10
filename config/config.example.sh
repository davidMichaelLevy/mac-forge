# shellcheck shell=bash
# shellcheck disable=SC2034
# Copy this file to config.sh and edit. config.sh is gitignored.

# --- identity -------------------------------------------------------------

GIT_USER_NAME="David Levy"
GIT_USER_EMAIL="david.michael.levy@gmail.com"

# Sharing display name (ComputerName). Empty = generated, e.g.
# dlevy-MacBook-Pro-16in-2024-X9K2 (login + About This Mac + serial last 4).
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
SETUP_PYTHON=true
LINK_DOTFILES=true
# Off until the preinstalled module is ready.
REMOVE_PREINSTALLED_APPS=false

# --- exclusive casks (used when INSTALL_CASKS=true) -----------------------

# Exclusive groups of Homebrew cask tokens (pipe-separated). Exactly one
# member is kept; the others are uninstalled if present. Put the token to
# keep in EXCLUSIVE_CASK_CHOICES. If a set has no matching choice, the first
# member is used.
#
# docker-desktop vs orbstack: OrbStack is a lighter Docker Desktop replacement
# (same `docker` CLI). Free for personal use; company use needs a paid license.
EXCLUSIVE_CASK_SETS=(
  "docker-desktop|orbstack"
)
EXCLUSIVE_CASK_CHOICES=(
  docker-desktop
)

# --- macos defaults (used when APPLY_MACOS_DEFAULTS=true) -----------------

MACOS_DOCK_AUTOHIDE=true
MACOS_KEY_REPEAT_FAST=true
MACOS_SHOW_HIDDEN_FILES=true
MACOS_TAP_TO_CLICK=true
# Apple "Natural" scrolling (content follows your fingers). false = reversed.
MACOS_NATURAL_SCROLL=false
# HTTP/HTTPS handler (defaultbrowser name: firefox, chrome, safari).
# Leave empty to leave the current default alone.
MACOS_DEFAULT_BROWSER="firefox"

# Apple apps that ship on a new Mac. Names match the .app bundle (no .app suffix).
# Optional: Data volume, /Applications, Finder will Move to Trash, App Store reinstall.
MACOS_OPTIONAL_APPS=(
  GarageBand
  iMovie
  Keynote
  Numbers
  Pages
)
# Keep: if a name is also in a remove list, do not uninstall it and do not
# unpin it from the Dock. Names that are only here (not on a remove list) are
# ignored; that is not an error.
MACOS_KEEP_APPS=(
)
# Non-optional: sealed system volume. Finder refuses delete; SIP / SSV protect them.
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

# CPython to install with pyenv and set as `pyenv global`.
# Use "latest" (newest 3.x), a prefix like "3.13", or an exact "3.13.2".
# Leave empty to skip installing a global Python.
PYENV_PYTHON_VERSION="latest"

# Extra CPythons to install and leave available (pipenv, pyenv local, etc.).
# Space-separated prefixes or exact versions. Not set as global.
# Leave empty to install only the global version.
PYENV_PYTHON_EXTRA_VERSIONS="3.9 3.10 3.11 3.12 3.13 3.14"

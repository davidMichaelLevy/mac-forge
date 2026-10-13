# shellcheck shell=bash
# shellcheck disable=SC2034
# Starter overlay. Copied to config.sh if that file is missing. config.sh is
# gitignored. Only keys you set here override config.defaults.sh.
# The merge is written to effective.config and sourced as the runtime config.

# --- identity -------------------------------------------------------------

# Set these in config.sh. Empty git/chrome/firefox keys follow these.
USER_NAME=""
USER_EMAIL=""

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

# Removes the apps in MACOS_REMOVE_APPS (uninstalls GarageBand and iMovie).
# MODULE_PREINSTALLED_ENABLED=false
# Fast-forward this checkout to origin before forge.sh runs
# (creates a git repo if install used a tarball).
SYNC_MAC_FORGE=true

# --- homebrew (used when MODULE_HOMEBREW_ENABLED=true) --------------------

# LaunchAgent via domt4/autoupdate. forge does not upgrade during a run.
# Interval is a duration (1d) or a daily clock time in 24-hour HH:MM (22:00 = 10pm).
HOMEBREW_AUTOUPDATE=true
HOMEBREW_AUTOUPDATE_INTERVAL=22:00
# HOMEBREW_AUTOUPDATE_GREEDY=true

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
# false = iCloud Drive off (also stops Desktop & Documents sync and removes it
# from Finder). There is no CLI; forge opens iCloud Drive settings while
# MobileMeAccounts still shows it enabled.
MACOS_ICLOUD_DRIVE=false
# Used only when iCloud Drive stays on: false = Desktop and Documents stay local.
# true / empty = leave iCloud file sync.
MACOS_ICLOUD_FILE_SYNC=false
# false = iCloud Photos off. There is no CLI; forge opens iCloud Photos
# settings if sync still looks on.
MACOS_ICLOUD_PHOTOS_SYNC=false
# false = iCloud Calendar off. There is no CLI; forge opens iCloud Calendar
# settings if MobileMeAccounts still shows Calendars enabled.
MACOS_ICLOUD_CALENDAR_SYNC=false
# Apple "Natural" scrolling (content follows your fingers). false = reversed.
MACOS_NATURAL_SCROLL=false
# HTTP/HTTPS handler (defaultbrowser name: firefox, chrome, safari).
# Leave empty to leave the current default alone.
MACOS_DEFAULT_BROWSER="firefox"

# --- preinstalled (used when MODULE_PREINSTALLED_ENABLED=true) ------------

# Apple apps to remove. Names match the .app bundle (no .app suffix).
# Apps in /Applications are uninstalled and unpinned from the Dock.
# System apps that macOS protects cannot be deleted, so they are only unpinned.
# += adds to the defaults in config.defaults.sh; uncomment the ones you want
# gone. To keep a default entry, see config_list_remove below the list.
MACOS_REMOVE_APPS+=(
  # Uninstalled (App Store apps in /Applications)
  # GarageBand
  # iMovie
  # Keynote
  # Numbers
  # Pages

  # Unpinned from the Dock only (protected system apps)
  # "Activity Monitor"
  # "AirPort Utility"
  # "Apple Games"
  # "App Store"
  # Apps
  # "Audio MIDI Setup"
  # Automator
  # "Bluetooth File Exchange"
  # Books
  # "Boot Camp Assistant"
  # Calculator
  # Calendar
  # Chess
  # Clock
  # "ColorSync Utility"
  # Console
  # Contacts
  # Dictionary
  # "Digital Color Meter"
  # "Directory Utility"
  # "Disk Utility"
  # "DVD Player"
  # FaceTime
  # "Find My"
  # Finder
  # "Font Book"
  # Freeform
  # Grapher
  # Home
  # "Image Capture"
  # "Image Playground"
  # "iPhone Mirroring"
  # Journal
  # Magnifier
  # Mail
  # Maps
  # Messages
  # "Migration Assistant"
  # Music
  # News
  # Notes
  # Passwords
  # Phone
  # "Photo Booth"
  # Photos
  # Podcasts
  # Preview
  # "Print Center"
  # "QuickTime Player"
  # Reminders
  # Safari
  # "Screen Sharing"
  # Screenshot
  # "Script Editor"
  # Shortcuts
  # Stickies
  # Stocks
  # "System Information"
  # "System Settings"
  # Terminal
  # TextEdit
  # Tips
  # TV
  # "Voice Memos"
  # "VoiceOver Utility"
  # Weather
)

# Keep apps that are on the default list (exact names, one or more per call):
# config_list_remove MACOS_REMOVE_APPS iMovie
# config_list_remove MACOS_REMOVE_APPS Messages Phone "iPhone Mirroring"
# Or replace the defaults entirely instead of adding to them:
# MACOS_REMOVE_APPS=(GarageBand iMovie)

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

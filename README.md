# macos-bootstrap

Shell scripts that take a brand-new Mac laptop to a known configuration: developer CLI tools, GUI apps, sane macOS defaults, git/SSH identity, and starter dotfiles.

The scripts are **idempotent**. You can re-run them after you change the Brewfile or config; they skip work that is already done.

## What you get

| Module | What it does |
| --- | --- |
| `prereqs` | Xcode Command Line Tools, Rosetta 2 on Apple Silicon |
| `homebrew` | Installs Homebrew if missing, then `brew update`; schedules `brew upgrade` via `domt4/autoupdate` (not during the forge run). Scheduled cask upgrades need App Management for Homebrew's `ruby`; forge opens that pane and logs a task until it is allowed. |
| `packages` | Installs everything in `config/Brewfile`, then exclusive cask sets (Docker Desktop or OrbStack) |
| `chrome` | Enable Chrome Google sign-in and sync, limited to `CHROME_GOOGLE_ACCOUNT` (empty = `USER_EMAIL`) |
| `firefox` | Enable Firefox Sync for `FIREFOX_SYNC_ACCOUNT` (empty = `USER_EMAIL`) |
| `python` | Installs CPython with pyenv (global + extra 3.x versions), upgrades pip |
| `macos` | Finder, Dock, keyboard, trackpad, screenshots, 24-hour clock, display sleep (10 min on battery, never on AC), Antarctica's Southern Lights screensaver, firewall, Safari develop menu, Firefox as default browser; ComputerName / HostName / LocalHostName |
| `preinstalled` | Removes the Apple apps in `MACOS_REMOVE_APPS` (defaults include GarageBand, iMovie, Photos, Music, TV and others; `config.example.sh` lists every Apple app, commented out, for `+=` additions). Deletable apps are uninstalled; protected system apps get a best effort instead. Every listed app is unpinned from the Dock; GarageBand's sound libraries are deleted and Photos stops opening when a device connects. |
| `shell` | Confirms **zsh** is the login shell; registers Homebrew bash in `/etc/shells` |
| `git` | `user.name` / `user.email` from `GIT_USER_NAME` / `GIT_USER_EMAIL` (empty = `USER_NAME` / `USER_EMAIL`), `main` as default branch, rebase-on-pull, Meld as diff/merge tool |
| `ssh` | `ed25519` key, macOS Keychain agent, prints the public key for GitHub |
| `dotfiles` | Copies starter files into `~/.config/mac-forge/dotfiles`. `~/.zshrc` and `~/.zprofile` are real files that source the store (installers can append). Other names are symlinks to the store. |

Default apps from the Brewfile include Ghostty, Kitty, iTerm2, AeroSpace, Rectangle, Raycast, CrossPaste, DisplayLink Manager, Claude, Cursor, PyCharm, VS Code, Meld, Firefox, Chrome, Brave, Tor Browser, Bitwarden, Signal, Slack, Discord, Zoom, Dropbox, IINA, TIDAL, Steam, Tappie, Stats, and Keka. Claude Code is installed as a cask. Docker Desktop or OrbStack is chosen with `EXCLUSIVE_CASK_CHOICES` in config (not both). DisplayLink Manager needs Screen Recording in System Settings before a DisplayLink dock will drive extra monitors.

## Requirements

- macOS 13 or later (Apple Silicon or Intel)
- An admin account (Homebrew and a few defaults need `sudo`)
- Network access for Homebrew and Xcode tools
- Full Disk Access for the terminal app you run forge from (recommended). macOS grants it per app, not per script. forge checks at the start of each run and logs a user task if it is missing; without it, permission checks fall back to reminders and Safari's protected settings are skipped.

## Quick start

On a new Mac:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh)
```

That downloads a tarball to `~/mac-forge` if needed and runs `bootstrap.sh`. Install never uses git; `bootstrap.sh` turns the tree into a checkout and fast-forwards it, re-execs itself so a just-pulled `bootstrap.sh` runs, then execs `forge.sh` so modules load from the updated tree. Pass-through examples:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh) --dry-run
bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh) --no-run
```

Non-interactive as root (fewer mid-run `sudo` prompts). Do not use `sudo bash <(…)`; that FD is closed (`Bad file descriptor`). Save the script, then run it:

```bash
curl -fsSL -o /tmp/mac-forge-install.sh https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh && sudo bash /tmp/mac-forge-install.sh -y
```

`-y` skips forge's confirm prompt. The installer still puts the tree under your home via `SUDO_USER`.

Or clone it yourself:

```bash
git clone https://github.com/davidMichaelLevy/mac-forge.git ~/mac-forge
cd ~/mac-forge
cp config/config.example.sh config/config.sh
# edit config/config.sh  — overrides only; defaults come from config.defaults.sh
# edit config/Brewfile   — formulae and casks
./bootstrap.sh --dry-run          # see the plan
./bootstrap.sh                    # apply it
./bootstrap.sh -q macos           # quieter child tools
./bootstrap.sh --verbose packages # loudest child tools
./bootstrap.sh doctor             # inspect the result
```

On a brand-new Mac you may be prompted to install Xcode Command Line Tools in a system dialog. Finish that, then re-run if the script was waiting on it.

Open a **new terminal** when it finishes so PATH, zsh, and Starship pick up the new files. A few macOS defaults only settle after logout.

## Customizing

Nothing in the scripts is meant to be edited for day-to-day taste. Change these instead:

1. **`config/config.sh`** — overlay on `config.defaults.sh` (identity including `USER_NAME` / `USER_EMAIL`, ComputerName, `MODULE_<name>_ENABLED` kill switches, Docker vs OrbStack, clock, scroll, browser, keep-apps, Python, Chrome, Firefox, Git). Missing keys keep the default. Start from `config.example.sh` (copied if `config.sh` is missing). The merge is written to `config/effective.config` and then sourced as the runtime config.
2. **`config/Brewfile`** — comment out casks you do not want; add taps, formulae, or `mas` App Store ids. Exclusive pairs (Docker vs OrbStack) are not listed here; they come from config.
3. **`dotfiles/`** — zsh, Starship, and the global gitignore. Re-run forge to copy them into `~/.config/mac-forge/dotfiles`. `~/.zshrc` / `~/.zprofile` source that store; other names are symlinks. The checkout is not the live target.
4. **`~/.zshrc.local`** — machine-only aliases and secrets. The managed zshrc sources it if present.

To run a subset:

```bash
./bootstrap.sh --list
./bootstrap.sh packages git
./bootstrap.sh -y macos
./forge.sh macos              # skip sync; apply modules only
```

Set `MODULE_<name>_ENABLED=false` to skip a module (`22-chrome.sh` → `MODULE_CHROME_ENABLED`). The plan still lists it; the module logs a skip after you confirm. Set `INSTALL_CASKS=false` to install CLI formulae only.

## Layout

```
install.sh            Download a tarball if needed and run bootstrap.sh
bootstrap.sh          Sync this checkout, re-exec so bootstrap.sh is current, then exec forge.sh
forge.sh              Apply modules (skip sync with this directly)
lib/common.sh         Logging, dry-run, config loader, symlink helper
lib/sync.sh           Git-init if needed, then fast-forward to origin
modules/              One numbered script per concern (sourced in order)
config/Brewfile       Homebrew bundle list
config/config.defaults.sh Project defaults (always loaded first)
config/config.example.sh  Starter overlay (copied to config.sh)
config/effective.config   Merged snapshot (generated, gitignored)
dotfiles/             Starter files; copied into ~/.config/mac-forge/dotfiles
scripts/check.sh      bash -n + shellcheck
```

## Safety

- **`--dry-run`** prints commands and writes nothing.
- **Verbosity** is pip-style and stacks: `-q` / `-qq` / `--quiet` (quietest), no flag (today's output), `-v` / `-vv` / `--verbose` (loudest). `--quiet` is `-qq`; `--verbose` is `-vv`. Extra stacks cap; `-q` and `-v` net. Forge's own logs stay; `-qq` hides child-tool output unless the command fails.
- A `~/.zshrc` or `~/.zprofile` that is still a symlink is replaced with a source wrapper. Other existing files that are not already links to the home store are moved aside as `*.bak.<timestamp>`. An existing real `~/.zshrc` without the wrapper gets the source block prepended so installer lines are kept.
- `~/.ssh/config` is appended with a marked block, not overwritten. An existing key is left alone.
- Git `user.name` / `user.email` are only written when `GIT_USER_NAME` / `GIT_USER_EMAIL` are set (they default to `USER_NAME` / `USER_EMAIL`).
- macOS defaults are not automatically reverted. Keep notes if you need to undo a setting.

## Check the scripts (any OS)

```bash
./scripts/check.sh
```

That syntax-checks every bash script and runs [shellcheck](https://www.shellcheck.net/) when it is installed. The bootstrap itself still refuses to apply changes off macOS unless you pass `--skip-os-check` (useful with `--dry-run`).

## After the first boot

1. Add the printed SSH public key at [github.com/settings/keys](https://github.com/settings/keys).
2. Sign in to Bitwarden, GitHub (`gh auth login`), and the App Store.
3. In Ghostty (or Terminal), confirm `echo $SHELL` is `/bin/zsh` and that `brew`, `rg`, and `starship` are on PATH.
4. Re-run `./bootstrap.sh doctor` whenever you want a checklist of what is still missing.

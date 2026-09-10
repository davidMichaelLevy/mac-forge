# macos-bootstrap

Shell scripts that take a brand-new Mac laptop to a known configuration: developer CLI tools, GUI apps, sane macOS defaults, git/SSH identity, and starter dotfiles.

The scripts are **idempotent**. You can re-run them after you change the Brewfile or config; they skip work that is already done.

## What you get

| Module | What it does |
| --- | --- |
| `prereqs` | Xcode Command Line Tools, Rosetta 2 on Apple Silicon |
| `sync` | Make this tree a git checkout if needed, then fast-forward to origin |
| `homebrew` | Installs Homebrew if missing, then `brew update` |
| `packages` | Installs everything in `config/Brewfile`, then exclusive cask sets (Docker Desktop or OrbStack) |
| `python` | Installs CPython with pyenv (global + extra 3.x versions), upgrades pip |
| `macos` | Finder, Dock, keyboard, trackpad, screenshots, display sleep (10 min on battery, never on AC), Antarctica's Southern Lights screensaver, firewall, Safari develop menu, Firefox as default browser; ComputerName / HostName / LocalHostName |
| `preinstalled` | Uninstall optional Apple apps; unpin required Apple apps from the Dock; `MACOS_KEEP_APPS` is left alone |
| `shell` | Confirms **zsh** is the login shell; registers Homebrew bash in `/etc/shells` |
| `git` | Name, email, `main` as default branch, rebase-on-pull, Meld as diff/merge tool |
| `ssh` | `ed25519` key, macOS Keychain agent, prints the public key for GitHub |
| `dotfiles` | Symlinks zsh, gitignore, EditorConfig, and Starship into `$HOME` |

Default apps from the Brewfile include Ghostty, Kitty, iTerm2, Rectangle, Raycast, Cursor, PyCharm, VS Code, Meld, Firefox, Chrome, Brave, Tor Browser, Bitwarden, Signal, Slack, IINA, TIDAL, Tappie, Stats, and Keka. Docker Desktop or OrbStack is chosen with `EXCLUSIVE_CASK_CHOICES` in config (not both).

## Requirements

- macOS 13 or later (Apple Silicon or Intel)
- An admin account (Homebrew and a few defaults need `sudo`)
- Network access for Homebrew and Xcode tools

## Quick start

On a new Mac:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh)
```

That downloads a tarball to `~/mac-forge` if needed and runs `bootstrap.sh`. Install never uses git; the `sync` module turns the tree into a checkout and fast-forwards it. Pass-through examples:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh) --dry-run
bash <(curl -fsSL https://raw.githubusercontent.com/davidMichaelLevy/mac-forge/main/install.sh) --no-run
```

Or clone it yourself:

```bash
git clone https://github.com/davidMichaelLevy/mac-forge.git ~/mac-forge
cd ~/mac-forge
cp config/config.example.sh config/config.sh
# edit config/config.sh  — name, email, HostName overrides, module toggles
# edit config/Brewfile   — formulae and casks
./bootstrap.sh --dry-run          # see the plan
./bootstrap.sh                    # apply it
./bootstrap.sh doctor             # inspect the result
```

On a brand-new Mac you may be prompted to install Xcode Command Line Tools in a system dialog. Finish that, then re-run if the script was waiting on it.

Open a **new terminal** when it finishes so PATH, zsh, and Starship pick up the new files. A few macOS defaults only settle after logout.

## Customizing

Nothing in the scripts is meant to be edited for day-to-day taste. Change these instead:

1. **`config/config.sh`** — identity, ComputerName (generated when empty, or `SET_MACHINE_NAMES=false` to leave names alone), HostName / LocalHostName overrides, which modules run, exclusive cask choices (Docker Desktop vs OrbStack), display sleep (battery vs AC), Aerial screensaver, Dock autohide, fast key repeat, hidden files, tap-to-click, scroll direction, default browser, optional/required/keep Apple app lists, Python version.
2. **`config/Brewfile`** — comment out casks you do not want; add taps, formulae, or `mas` App Store ids. Exclusive pairs (Docker vs OrbStack) are not listed here; they come from config.
3. **`dotfiles/`** — zsh, Starship, and the global gitignore. They are symlinked; edit them in this repo.
4. **`~/.zshrc.local`** — machine-only aliases and secrets. The linked `~/.zshrc` sources it if present.

To run a subset:

```bash
./bootstrap.sh --list
./bootstrap.sh packages git
./bootstrap.sh -y macos
```

Set `INSTALL_CASKS=false` in config to install CLI formulae only.

## Layout

```
install.sh            Download a tarball if needed and run bootstrap.sh
bootstrap.sh          Entry point
lib/common.sh         Logging, dry-run, config loader, symlink helper
modules/              One numbered script per concern (sourced in order)
config/Brewfile       Homebrew bundle list
config/config.example.sh
dotfiles/             Files linked into $HOME
scripts/check.sh      bash -n + shellcheck
```

## Safety

- **`--dry-run`** prints commands and writes nothing.
- Existing `~/.zshrc` (and other dotfiles) that are not already our symlinks are moved aside as `*.bak.<timestamp>`.
- `~/.ssh/config` is appended with a marked block, not overwritten. An existing key is left alone.
- Git identity is only written when `GIT_USER_NAME` / `GIT_USER_EMAIL` are set.
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

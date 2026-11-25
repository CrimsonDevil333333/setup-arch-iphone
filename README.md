# setup-arch-iphone

[![Validate](https://github.com/CrimsonDevil333333/setup-arch-iphone/actions/workflows/validate.yml/badge.svg)](https://github.com/CrimsonDevil333333/setup-arch-iphone/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

One-shot developer environment setup for **Arch Linux ARM** (tested on Swipterm / iPhone).

Clone:
```bash
git clone https://github.com/CrimsonDevil333333/setup-arch-iphone.git
cd setup-arch-iphone
sudo ./install.sh
```

## Quick start (without cloning)

```bash
curl -fsSL https://raw.githubusercontent.com/CrimsonDevil333333/setup-arch-iphone/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

## What it installs

- Developer toolchain: git, node/npm, python/pip, neovim, tmux, docker, podman, and more
- Shell: zsh + autosuggestions + syntax highlighting + starship prompt
- CLI goodies: fzf, ripgrep, fd, bat, eza, zoxide, tree, ncdu, duf, dust, procs, tldr, hyperfine, tokei, cloc, git-delta, xh, ...
- code-server (VS Code in browser) on port 8080
- Locale, hostname, SSH key, makepkg parallel builds
- Compact fastfetch config tuned for narrow phone screens

## Options

Run `./install.sh --help` for full list.

- `--dry-run` print actions without executing
- `--interactive` prompt before major steps
- `--update` show available updates and upgrade
- `--cleanup` clean caches/journals/temp/orphans
- `--update-code` update code-server
- `--validate` validate installation

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `GIT_NAME` | `Developer` | Git commit author name |
| `GIT_EMAIL` | `dev@arch.local` | Git commit author email |
| `HOSTNAME` | `devbox` | System hostname |
| `SWAP_SIZE` | `0` | Swap file size in GB (0 = disabled) |
| `CODE_SERVER_AUTH` | `none` | `none` or `password` |
| `INSTALL_CODE_SERVER` | `1` | Set to `0` to skip code-server |
| `CODE_SERVER_VERSION` | `latest` | code-server release tag |

Example:

```bash
sudo GIT_NAME="Jane Doe" GIT_EMAIL="jane@example.com" SWAP_SIZE=2 CODE_SERVER_AUTH=password ./install.sh
```

## After install

- Open a new shell to see the greeting.
- Type `tips` (or `help`) for shortcuts.
- code-server: `http://<device-ip>:8080`

## Files

- `configs/` - all dotfiles and service units copied during install
- `install.sh` - the one-shot installer
- `scripts/` - helper scripts (update, cleanup, code-server update)
- `.github/workflows/validate.yml` - CI validation

## Token storage (maintainers)

Store your GitHub token in `~/.config/github/token` (mode 600).
The shell config reads it into `GITHUB_TOKEN` automatically.
Never commit tokens to the repo.
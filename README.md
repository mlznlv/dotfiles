# dotfiles

Portable terminal UX for macOS and Linux.

The goal is simple: different machines may run different workloads, but the shell should feel familiar everywhere.

- Corporate MacBook Pro: local development workstation.
- Personal MacBook Air: lightweight client, primarily for remote development.
- Linux / Minisforum: remote development host.

`chezmoi` manages portable `$HOME` configuration. `mise` manages bootstrap dependencies. Shell configuration detects optional tools instead of assuming a machine role.

## Install

### 1. Prerequisites

A new machine needs Git, `curl`, and access to this repository.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

On macOS, make sure Git / Apple Command Line Tools are available.

### 2. Clone

```bash
mkdir -p ~/.local/share
git clone git@github.com:mlznlv/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
```

### 3. Bootstrap

Choose the install-time profile:

| Machine | Profile | Command |
|---|---|---|
| MacBook Air | `base` | `./bootstrap.sh base` |
| MacBook Pro | `local-dev` | `./bootstrap.sh local-dev` |
| Linux / Minisforum | `dev-host` | `./bootstrap.sh dev-host` |
| Minimal Linux host | `base` | `./bootstrap.sh base` |

`base` is the default:

```bash
./bootstrap.sh
```

Then start a fresh login shell:

```bash
exec zsh -l
```

## Verify

```bash
command -v zsh
command -v git
command -v fzf
command -v zoxide
command -v mise
chezmoi diff
```

On the local-development Mac also verify Docker and existing Node/Python workflows.

Interactively check:

- history;
- autocomplete and autosuggestions;
- syntax highlighting;
- `fzf`;
- `zoxide`;
- Git aliases;
- prompt behavior.

## Update an existing machine

```bash
cd ~/.local/share/chezmoi
git pull --ff-only
./bootstrap.sh <profile>
exec zsh -l
```

Examples:

```bash
# MacBook Air
./bootstrap.sh base

# MacBook Pro
./bootstrap.sh local-dev

# Minisforum
./bootstrap.sh dev-host
```

## Edit dotfiles

```bash
cd ~/.local/share/chezmoi

git status
git diff
chezmoi diff

# edit source files
chezmoi apply
exec zsh -l
```

The repository is the source of truth for portable configuration.

Machine-local exceptions that should not be shared belong in:

```text
~/.config/zsh/local.zsh
```

Never commit credentials, private keys, tokens, certificates, `.env` secrets, caches, or raw package-manager snapshots.

## Layout

```text
bootstrap.sh                 bootstrap entrypoint
mise.toml                    shared bootstrap resources
mise.macos.toml              macOS base packages
mise.macos-local-dev.toml    local-development additions
mise.linux.toml              Linux base packages
mise.linux-dev-host.toml     remote-development additions

dot_zprofile                 login-shell environment
dot_zshrc                    Zsh composition root

dot_config/zsh/
├── core.zsh                 history and shell options
├── paths.zsh                portable/capability-based PATH
├── completion.zsh           completion and autocomplete
├── tools.zsh                tool/runtime integrations
├── aliases.zsh              explicit aliases
├── prompt.zsh               prompt
└── interactive.zsh          autosuggestions and syntax highlighting
```

Keep the structure intentional:

- do not create empty platform/role placeholders;
- add abstractions only when there is actual divergent behavior;
- add only direct, intentionally used packages to `mise*.toml`;
- do not import the full output of `brew list` or another package-manager snapshot;
- missing optional software must not break shell startup.

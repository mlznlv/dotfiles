# dotfiles

Portable terminal UX for macOS and Linux, managed with `chezmoi` and bootstrapped with `mise`.

The goal is not to clone one machine onto every other machine. The goal is to keep the same shell muscle memory while allowing each host to run a different workload.

```text
                          shared terminal UX
                                 │
                   ┌─────────────┼─────────────┐
                   │             │             │
                   ▼             ▼             ▼
             MacBook Pro    MacBook Air    Linux dev host
                 macOS          macOS          Ubuntu
                   │             │             │
              local dev      remote-first    remote dev
```

## Quick start

### 1. Prerequisites

A new machine needs:

- Git;
- `curl`;
- access to this private GitHub repository.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

macOS: install/enable the Apple command-line developer tools so Git is available.

Homebrew is **not** a bootstrap prerequisite. `mise` owns declared `brew:` / `brew-cask:` packages.

### 2. Clone

Recommended checkout location:

```bash
mkdir -p ~/.local/share
git clone git@github.com:mlznlv/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
```

Another checkout location also works; `bootstrap.sh` uses its own directory as the chezmoi source.

### 3. Choose an install-time profile

Profiles control **what gets installed**. They are not persisted as shell identities.

| Machine / use case | Platform | Profile | Command |
|---|---|---|---|
| Personal MacBook Air / lightweight client | macOS | `base` | `./bootstrap.sh base` |
| Corporate MacBook Pro / local development | macOS | `local-dev` | `./bootstrap.sh local-dev` |
| Minisforum / Ubuntu remote development host | Linux | `dev-host` | `./bootstrap.sh dev-host` |
| Generic minimal Linux host | Linux | `base` | `./bootstrap.sh base` |

`base` is the default:

```bash
./bootstrap.sh
```

### 4. Bootstrap

```bash
./bootstrap.sh <profile>
```

Examples:

```bash
# Personal MacBook Air
./bootstrap.sh base

# Corporate MacBook Pro
./bootstrap.sh local-dev

# Ubuntu / Minisforum development host
./bootstrap.sh dev-host
```

The script:

1. detects macOS vs Linux;
2. validates the requested profile;
3. installs `mise` if necessary;
4. applies declarative `mise bootstrap` state;
5. installs `chezmoi` if necessary;
6. applies this repository as chezmoi source state.

Then start a fresh login shell:

```bash
exec zsh -l
```

Do not validate shell changes by repeatedly sourcing `.zshrc`; restart Zsh instead.

## First migration of the existing MacBook Pro

The old workstation is the reference implementation for the terminal UX. Migrate it conservatively before merging large shell changes.

### Preserve the existing Powerlevel10k appearance

The old `.zshrc` loaded `~/.p10k.zsh`, but that file has never been committed to this repository. The repository now preserves Powerlevel10k loading, but the exact visual configuration cannot be reproduced on another machine until the existing file is captured.

On the current MacBook Pro:

```bash
cd ~/.local/share/chezmoi
chezmoi add ~/.p10k.zsh

git status
git diff --cached -- dot_p10k.zsh
```

Review the generated source file before committing it. It must contain prompt configuration only, not secrets or machine-specific credentials.

Until `dot_p10k.zsh` is committed:

- the current Mac can continue using its existing local `~/.p10k.zsh`;
- a new machine will not invent or launch a new Powerlevel10k configuration automatically;
- exact prompt appearance is not yet reproducible.

### Workstation smoke test

Before merging shell/bootstrap changes, verify on the current MacBook Pro:

```bash
bash -n bootstrap.sh
./bootstrap.sh local-dev
exec zsh -l
```

Then check:

```bash
command -v git
command -v fzf
command -v zoxide
command -v mise
command -v docker
command -v node
command -v npm
command -v pyenv
command -v python

chezmoi diff
```

Interactively verify:

- the prompt looks the same;
- history is preserved and shared across tabs;
- autocomplete works;
- autosuggestions work;
- syntax highlighting works;
- `fzf` keybindings/integration work;
- `zoxide` navigation works;
- Docker CLI and Docker completion work;
- existing `nvm` projects still work;
- existing `pyenv` / virtualenv workflows still work;
- Git aliases used in daily work still exist.

If an old Oh My Zsh alias/function is actually used, restore that behavior explicitly instead of reintroducing the entire framework/plugin bundle.

## What was intentionally dropped from the old setup

The migration is not a byte-for-byte copy of the previous `.zshrc`.

Intentionally removed:

- Oh My Zsh framework and implicit plugin bundle;
- `Antigravity` PATH/configuration;
- old Obsidian CLI PATH/configuration;
- duplicated Docker completion initialization;
- global `DOCKER_BUILDKIT=1` and `COMPOSE_DOCKER_CLI_BUILD=1` exports;
- raw package-manager snapshots as desired state.

Old Oh My Zsh plugins such as `git`, `macos`, `docker`, `brew`, `nvm`, `npm`, `virtualenv`, and `qrcode` are **not** automatically recreated. Only behavior that is actually useful should be restored explicitly.

## Old `.zshrc` parity map

| Old behavior | New owner |
|---|---|
| Powerlevel10k instant prompt | `dot_zshrc` |
| Powerlevel10k theme/config loading | `~/.config/zsh/prompt.zsh` + managed `~/.p10k.zsh` |
| `~/.local/bin` PATH | `paths.zsh` |
| `~/.docker/bin` PATH | `paths.zsh`, capability-detected |
| `~/.pyenv/bin` PATH | `paths.zsh`, capability-detected |
| NVM | `tools.zsh`, migration compatibility |
| pyenv | `tools.zsh`, migration compatibility |
| Docker completion path | `completion.zsh` |
| history options | `core.zsh` |
| autocomplete | `completion.zsh` |
| autosuggestions | `plugins.zsh` |
| syntax highlighting | `plugins.zsh`, loaded last |
| fzf | `tools.zsh` with modern + legacy fallback |
| zoxide | `tools.zsh` |
| Homebrew shellenv | `platforms/macos.profile.zsh`, only when Homebrew exists |
| development runtime ownership | gradually moving to project-local `mise` |

## Updating an existing machine

```bash
cd ~/.local/share/chezmoi
git pull --ff-only
./bootstrap.sh <profile>
exec zsh -l
```

Examples:

```bash
# Air
./bootstrap.sh base

# Pro
./bootstrap.sh local-dev

# Minisforum
./bootstrap.sh dev-host
```

The bootstrap is intended to be repeatable and converge toward declared state.

Inspect dotfile changes before or after applying:

```bash
chezmoi diff
```

Inspect bootstrap state:

```bash
mise bootstrap status
mise bootstrap status --missing
```

## Editing dotfiles

With the recommended checkout location:

```bash
cd ~/.local/share/chezmoi
```

Typical workflow:

```bash
git status
git diff

# edit source files
chezmoi diff
chezmoi apply

exec zsh -l
```

Commit only portable desired state. Never commit credentials, private keys, tokens, certificates, `.env` secrets, caches, or accidental package snapshots.

## Architecture

There are two separate concerns.

### Runtime shell

```text
common UX
+ platform adaptation
+ capability detection
+ optional machine-local override
```

The runtime shell does not know whether a machine is a `workstation`, `client`, `server`, `work`, or `personal` machine.

`~/.zshrc` is a thin composition root:

```text
instant prompt
core.zsh
paths.zsh
platform.zsh
local.zsh       (optional, unmanaged)
completion.zsh
tools.zsh
aliases.zsh
prompt.zsh
plugins.zsh
```

Optional software is detected instead of assumed. Missing Docker, pyenv, nvm, fzf, zoxide, mise, or a prompt config must not make the shell unusable.

Platform-specific behavior lives under:

```text
~/.config/zsh/platforms/
├── macos.zsh
├── macos.profile.zsh
├── linux.zsh
└── linux.profile.zsh
```

### Provisioning

Provisioning is declarative and handled by `mise`:

```text
mise.toml                  shared bootstrap resources
mise.macos.toml            macOS base packages
mise.linux.toml            Linux base packages
mise.macos-local-dev.toml  local-development additions
mise.linux-dev-host.toml   remote-development-host additions
```

Current mapping:

```text
Corporate MacBook Pro
  macOS + local-dev

Personal MacBook Air
  macOS + base

Minisforum / Ubuntu
  Linux + dev-host
```

Profiles exist only at installation time.

## Ownership boundaries

### chezmoi owns portable `$HOME` state

Examples:

```text
.zshrc
.zprofile
.p10k.zsh              once captured from the current workstation
~/.config/zsh/**
future terminal/editor/multiplexer config
```

### mise owns bootstrap lifecycle

`mise` owns declared host packages and shared external repositories used by the terminal environment.

The repository should not maintain parallel handwritten Homebrew, APT, curl-installer, and Git-clone implementations for the same logical dependency.

### Projects own project runtime versions

Prefer project-owned version declarations such as:

```text
mise.toml
.nvmrc
.node-version
.python-version
```

Existing `nvm` and `pyenv` remain supported during migration. Do not remove them from the current workstation until affected projects have been verified under `mise`.

## Shared Zsh dependencies

Bootstrapped into:

```text
~/.local/share/zsh/plugins/
├── powerlevel10k
├── zsh-autocomplete
├── zsh-autosuggestions
└── zsh-syntax-highlighting
```

Important load-order rules:

- Docker completion directories are added to `fpath` before completion initialization;
- `zsh-autocomplete` initializes completion early;
- tool integrations load after completion initialization;
- `zsh-syntax-highlighting` remains the last late-loaded Zsh plugin.

## Machine-local overrides

Use:

```text
~/.config/zsh/local.zsh
```

for genuine per-machine exceptions that must not be shared.

Use this sparingly. A difference that is actually platform-wide or capability-wide belongs in shared configuration.

## UX invariant

These should remain familiar across local macOS and Linux-over-SSH sessions:

```text
Zsh behavior
prompt
history
completion
autocomplete
autosuggestions
syntax highlighting
fzf
zoxide
keybindings
Git workflow
navigation
```

Terminal rendering and remote shell behavior are separate layers:

```text
LOCAL CLIENT                      REMOTE HOST

terminal emulator / rendering     Zsh
font / keyboard / clipboard  SSH  prompt
                            ─────► fzf / zoxide
                                   tmux
                                   editor
                                   CLI tools
```

## Portability rules

1. Common config must not assume macOS, Homebrew, Apple Silicon, Docker Desktop, a username, or a machine purpose.
2. OS-specific behavior belongs in platform config or OS-specific `mise` files.
3. Optional software must be detected, not assumed.
4. Provisioning profiles select installed capabilities; they do not become runtime machine identities.
5. Secrets stay outside Git.
6. Desired state is curated; do not import everything that happened to be installed.
7. Do not rebuild framework magic unless a concrete missing behavior justifies it.

## Definition of success

The repository is successful when:

- the current MacBook Pro remains fully usable for local development;
- the Air can be bootstrapped as a lightweight client;
- Ubuntu/Minisforum can reproduce the same terminal UX over SSH;
- optional tools can appear/disappear without breaking shell startup;
- replacing a machine does not require reconstructing terminal behavior manually;
- package/runtime lifecycle does not grow into a custom configuration-management framework.

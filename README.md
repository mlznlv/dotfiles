# dotfiles

Portable terminal UX for macOS and Linux, managed with `chezmoi` and bootstrapped with `mise`.

The repository does **not** try to clone one machine onto every other machine. Its purpose is to preserve the same terminal muscle memory while allowing each host to run a different workload.

## Target topology

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
                  │             │             │
                  └──────── SSH ┴─────────────┘
```

The important invariant is:

> Different machines can have different software and responsibilities while the shell UX stays familiar.

## Architecture

There are two separate concerns.

### 1. Runtime shell configuration

The shell is composed from:

```text
common UX
+ platform adaptation
+ capability detection
+ optional machine-local overrides
```

It does not know whether a machine is a `workstation`, `client`, `server`, `work`, or `personal` machine.

`~/.zshrc` is intentionally a thin composition root:

```text
core.zsh
paths.zsh
platform.zsh
local.zsh       (optional, unmanaged)
tools.zsh
completion.zsh
aliases.zsh
plugins.zsh
```

Platform-specific behavior lives under:

```text
~/.config/zsh/platforms/
├── macos.zsh
├── macos.profile.zsh
├── linux.zsh
└── linux.profile.zsh
```

Optional integrations are capability-driven. For example, Docker-specific PATH/completion is enabled only when the corresponding Docker directories exist. Missing optional software must never break shell startup.

### 2. Machine provisioning

Provisioning is declarative and handled by `mise`.

```text
mise.toml                  shared bootstrap resources
mise.macos.toml            macOS base packages
mise.linux.toml            Linux base packages
mise.macos-local-dev.toml  optional local-dev capability set
mise.linux-dev-host.toml   optional remote-dev-host capability set
```

Profiles exist only at **installation time**. They are not persisted into the shell and do not affect runtime configuration logic.

## Current machine mapping

### Corporate MacBook Pro

```text
platform: macOS
profile:  local-dev
```

This is a full local development machine. Docker and other workstation applications may exist locally, but the shell discovers them by capability rather than by a persisted machine role.

Bootstrap:

```bash
./bootstrap.sh local-dev
```

### Personal MacBook Air

```text
platform: macOS
profile:  base
```

The Air is primarily a lightweight client for remote development but can gain additional local tooling later without changing the dotfiles architecture.

Bootstrap:

```bash
./bootstrap.sh base
```

### Linux / Minisforum development host

```text
platform: Linux
profile:  dev-host
```

The host provides remote compute, persistent terminal sessions, build tooling, containers, project runtimes, language servers, databases, and other development services as needed.

Bootstrap:

```bash
./bootstrap.sh dev-host
```

## Bootstrap flow

`bootstrap.sh` is deliberately small. It only:

1. detects macOS vs Linux;
2. selects the requested install-time capability profile;
3. ensures `mise` is available;
4. runs declarative `mise bootstrap` state;
5. ensures `chezmoi` is available;
6. applies the repository as chezmoi source state.

Conceptually:

```text
bootstrap.sh
    │
    ├── detect OS
    ├── select provisioning profile
    │
    ▼
  mise bootstrap
    │
    ├── system packages
    └── shared Zsh plugin repositories
    │
    ▼
  chezmoi apply
    │
    ▼
  consistent $HOME / terminal UX
```

Supported combinations:

```text
macOS  + base
macOS  + local-dev
Linux  + base
Linux  + dev-host
```

`base` is the default:

```bash
./bootstrap.sh
```

Prerequisites for the entrypoint are `curl` and a usable Git checkout of this repository.

## Ownership boundaries

### chezmoi owns `$HOME` state

Examples:

```text
.zshrc
.zprofile
~/.config/zsh/**
future Ghostty config
future tmux config
future Neovim config
future Git UX config
future SSH client config
```

Machine-local exceptions should live in unmanaged local files such as:

```text
~/.config/zsh/local.zsh
```

Secrets must not be committed to this repository.

### mise owns bootstrap lifecycle

`mise` owns declarative installation of host packages and shared external repositories used by the terminal environment.

The repository intentionally avoids maintaining separate handwritten `apt`, Homebrew, curl-installer, and Git-clone orchestration paths for the same logical environment.

### Projects own project runtime versions

Project-specific versions should normally live with the project, for example:

```text
mise.toml
.nvmrc
.node-version
.python-version
```

The dotfiles repository should not become a global snapshot of every runtime version ever installed on a machine.

## Development runtime migration

The existing workstation still supports `nvm` and `pyenv` when they are installed. This is intentional migration compatibility, not the target ownership model.

`mise` is activated last in the shell, so projects can adopt `mise` incrementally without requiring a big-bang migration of the current MacBook Pro.

Target direction:

```text
new/project-local runtime management -> mise
existing nvm/pyenv setup              -> supported during migration
```

Do not remove legacy runtime managers from the current workstation until the affected projects have been verified under `mise`.

## Zsh plugins

Shared plugins are bootstrapped into one canonical location:

```text
~/.local/share/zsh/plugins/
├── zsh-autocomplete
├── zsh-autosuggestions
└── zsh-syntax-highlighting
```

They are declared as `mise` bootstrap repositories rather than installed by custom shell code.

The shell loader remains defensive: a missing plugin does not make the shell unusable.

## UX invariant

The following should remain consistent across local macOS sessions and Linux-over-SSH sessions:

```text
Zsh behavior
history
completion
autocomplete
autosuggestions
syntax highlighting
fzf
zoxide
keybindings
Git aliases/workflow
navigation
prompt (when added)
tmux UX (when added)
Neovim UX (when added)
```

Terminal-emulator behavior and remote shell behavior are separate layers:

```text
LOCAL CLIENT                      REMOTE HOST

Ghostty / terminal rendering      Zsh
font / keyboard / clipboard  SSH  prompt
                           ─────► fzf / zoxide
                                  tmux
                                  nvim
                                  CLI tools
```

The core UX must therefore live primarily in portable shell/editor/multiplexer configuration, not only in a macOS terminal emulator.

## Portability rules

1. Common configuration must not assume macOS, Homebrew, Apple Silicon, Docker Desktop, a specific username, or a specific machine purpose.
2. OS-specific behavior belongs in platform files or OS-specific `mise` bootstrap config.
3. Optional software must be detected, not assumed.
4. Provisioning profiles select installed capabilities; they do not become runtime machine identities.
5. Secrets, credentials, SSH private keys, tokens, certificates, and private `.env` values stay outside Git.
6. Desired state should be curated. Do not turn package configuration into a dump of everything that happened to be installed.

## Definition of success

The repository is successful when:

- the current MacBook Pro remains fully usable for local development;
- a personal MacBook Air can be bootstrapped as a lightweight client without duplicating the full workstation;
- an Ubuntu development host can receive the same terminal UX predictably;
- optional tools can appear or disappear without breaking shell startup;
- moving between local and SSH sessions preserves muscle memory;
- replacing a machine does not require reconstructing terminal behavior manually;
- package/runtime lifecycle logic does not grow into a custom configuration-management framework.

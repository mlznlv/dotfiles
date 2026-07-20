# dotfiles

Portable terminal, shell, and development-environment configuration managed with `chezmoi` and Git.

Repository:

```text
```

## Goal

The goal of this repository is **not to clone one machine**.

The goal is to preserve a consistent terminal and shell UX across different machines and operating systems while allowing every machine to have its own role and tooling.

The environment consists of three main machine types:

```text
                         dotfiles
                            │
                   shared terminal UX
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
   MacBook Pro         MacBook Air       Linux Server
   workstation            client          remote dev
          │                 │                 │
   full local dev      lightweight       development
   environment          local setup       environment
                              │
                              └──── SSH ────►
```

The key principle is:

> Different machines. Different roles. Same core terminal UX.

---

## Machines

### MacBook Pro — workstation

The MacBook Pro is the primary local development workstation.

It can contain the full development stack:

* Docker
* Node.js / nvm
* Python / pyenv
* AWS CLI
* Kubernetes tooling
* local development services
* IDEs and editors
* workstation-specific applications
* other development tooling

The MacBook Pro is currently the source machine from which the existing environment is being reconstructed and cleaned up.

It should remain a fully functional workstation.

---

### MacBook Air — client

The MacBook Air is a lightweight mobile client.

Its main responsibilities are:

* Ghostty
* terminal UX
* SSH
* remote development
* browser
* productivity applications
* lightweight local tools when useful

It should **not** need to reproduce the complete MacBook Pro development environment.

Typical workflow:

```text
MacBook Air
    │
    ▼
Ghostty
    │
    ▼
local Zsh UX
    │
    ▼
SSH
    │
    ▼
Linux development server
    │
    ▼
same familiar Zsh UX
```

The Air should remain lightweight while still feeling familiar locally and remotely.

---

### Linux Server — remote development

Ubuntu or another Linux distribution acts as a remote development environment.

It may contain:

* Node.js
* Python
* compilers
* containers
* databases
* project runtimes
* language servers
* development services
* server-side CLI tooling

It must receive the portable shell UX without macOS-specific assumptions.

---

# UX invariant

The most important thing to preserve is **UX**, not identical installed software.

The following should behave consistently across supported machines:

```text
Zsh behavior
prompt
autocomplete
autosuggestions
syntax highlighting
history
fzf
zoxide
completion behavior
keybindings
Git workflow
common shell functions
navigation
```

Moving between:

```text
MacBook Pro
MacBook Air
Linux over SSH
```

should not feel like switching to three unrelated shell environments.

---

# Architecture

The target architecture separates:

1. shared UX;
2. operating-system-specific configuration;
3. machine-role-specific configuration.

Conceptually:

```text
common
├── shell behavior
├── prompt
├── history
├── completion
├── autocomplete
├── autosuggestions
├── syntax highlighting
├── fzf
├── zoxide
├── keybindings
├── common functions
└── common Git UX

macos
├── Homebrew integration
├── macOS-specific PATH
├── Ghostty
└── macOS-specific configuration

workstation
├── Docker
├── Node / nvm
├── Python / pyenv
├── AWS
├── Kubernetes
└── full development tooling

client
├── Ghostty
├── SSH
└── lightweight local tooling

linux
├── Linux package/bootstrap logic
├── Linux-specific PATH
└── remote development configuration
```

This is the target architecture.

The current repository is being migrated toward this model incrementally without breaking the working workstation.

---

# Core UX vs machine tooling

These are part of the shared UX:

```text
Zsh
prompt
history
autocomplete
autosuggestions
syntax highlighting
fzf
zoxide
keybindings
completion behavior
common functions
```

These are **not** universal UX:

```text
Docker Desktop
JetBrains Toolbox
Sublime Text
Homebrew
macOS application paths
AWS CLI
kubectl
local databases
workstation applications
```

Those belong to platform-specific or role-specific layers.

---

# Current repository

The repository currently contains approximately:

```text
.
├── .chezmoiignore
├── Brewfile.common
├── Brewfile.workstation
├── bootstrap.sh
├── README.md
├── dot_zprofile
├── dot_zshrc
└── dot_config
    └── zsh
        ├── aliases.zsh
        ├── completion.zsh
        ├── core.zsh
        ├── paths.zsh
        ├── plugins.zsh
        └── tools.zsh
```

This is not yet the final role/platform-aware structure.

It will be refactored gradually.

---

# Current Zsh configuration

## `core.zsh`

Core Zsh behavior.

Currently includes:

* history configuration
* core shell options

---

## `paths.zsh`

Optional PATH configuration.

Currently includes support for:

```text
~/.local/bin
~/.docker/bin
JetBrains Toolbox scripts
Sublime Text CLI
```

Paths are only added when they exist.

Some of these are macOS/workstation-specific and should eventually move out of the universal shell layer.

---

## `tools.zsh`

Tool initialization.

Currently includes:

* nvm
* pyenv
* fzf
* zoxide

Tool initialization should remain conditional so missing optional software does not break shell startup.

---

## `completion.zsh`

Additional completion configuration.

Docker completion is currently restored from:

```text
~/.docker/completions
```

---

## `plugins.zsh`

Currently loads:

```text
zsh-autocomplete
zsh-autosuggestions
zsh-syntax-highlighting
```

`zsh-syntax-highlighting` should remain loaded last.

---

## `aliases.zsh`

Contains a small explicit set of Git aliases added during migration.

The goal is **not** to recreate large Oh My Zsh alias collections.

New aliases should only be added deliberately when they provide clear value.

---

# Current shell stack

Currently used:

```text
Zsh
zsh-autocomplete
zsh-autosuggestions
zsh-syntax-highlighting
fzf
zoxide
```

A new prompt is still pending.

The prompt should be:

* visually useful;
* fast;
* portable;
* suitable for local sessions;
* suitable over SSH;
* independent of Oh My Zsh.

---

# Terminal emulator

Ghostty is planned as the main terminal emulator on macOS.

Important distinction:

```text
Ghostty != shell UX
```

Ghostty provides the local terminal interface.

The core UX must live primarily in the shell configuration so it survives SSH.

Example:

```text
MacBook Air
    │
    ▼
Ghostty
    │
    ▼
SSH
    │
    ▼
Linux
    │
    ▼
portable Zsh configuration
```

The remote environment should still provide the familiar prompt, completion, navigation, history behavior, and other shell UX.

---

# Oh My Zsh migration

Oh My Zsh has been removed.

The previous configuration used these plugins:

```text
git
macos
docker
brew
nvm
npm
virtualenv
qrcode
```

The objective is **not to rebuild Oh My Zsh manually**.

Instead:

* preserve useful UX;
* preserve required functionality;
* use explicit configuration;
* remove unnecessary framework magic;
* avoid restoring convenience features that are not actually needed.

---

## Functionality already restored

### Shell UX

Verified:

* Zsh
* autocomplete
* autosuggestions
* syntax highlighting
* fzf
* zoxide

### Node.js

Verified:

* nvm loads
* Node.js works
* npm works

### Python

Verified:

* pyenv works
* Python works
* pyenv virtualenv works
* virtual environments can be activated and deactivated

### Docker

Verified:

* Docker CLI works
* Docker completion works

Docker CLI currently resolves through:

```text
~/.docker/bin/docker
```

Docker completion is available through:

```text
~/.docker/completions
```

### Local CLI paths

Restored and verified where present:

```text
~/.local/bin
~/.docker/bin
JetBrains Toolbox scripts
Sublime Text CLI
```

The old Obsidian CLI path no longer exists and is not restored.

---

# Homebrew configuration

## `Brewfile.common`

Current macOS common packages include:

```text
chezmoi
fzf
gh
git
ripgrep
zoxide
zsh-autocomplete
zsh-autosuggestions
zsh-syntax-highlighting
```

Despite the name, `Brewfile.common` is still Homebrew-specific.

It is therefore not the final definition of the cross-platform common layer.

Linux will require its own installation mechanism while producing the same core UX.

---

## `Brewfile.workstation`

Current workstation-specific packages include:

```text
awscli
kubernetes-cli
pyenv
pyenv-virtualenv
```

This is a curated desired-state file.

It should not become a dump of everything that happens to be installed.

---

# Snapshot policy

A raw Homebrew snapshot from the original workstation is kept outside the Git repository:

```text
~/Brewfile.workstation.snapshot
```

It exists only as:

* migration reference;
* safety net;
* inventory of previously installed software.

It must not automatically become desired state.

The repository should answer:

> What should this machine have?

not:

> What happened to be installed at some point?

---

# Runtime versions

Dotfiles should generally install and configure runtime managers rather than snapshot every currently installed runtime version.

Examples:

```text
nvm
pyenv
```

Project-specific runtime versions should normally live with projects:

```text
.nvmrc
.node-version
.python-version
```

Exact global versions should only be pinned intentionally.

---

# Machine roles

The intended model combines **platform** and **role**.

## MacBook Pro

```text
platform = macOS
role     = workstation
```

Receives:

```text
common UX
+
macOS configuration
+
workstation configuration
```

---

## MacBook Air

```text
platform = macOS
role     = client
```

Receives:

```text
common UX
+
macOS configuration
+
client configuration
```

It should remain lightweight.

---

## Linux development server

```text
platform = Linux
role     = server
```

Receives:

```text
common UX
+
Linux configuration
+
server/development configuration
```

No macOS-specific assumptions should leak into this environment.

---

# Bootstrap model

The eventual bootstrap process should determine:

```text
What platform is this?
What role does this machine have?
```

Conceptually:

```text
bootstrap
    │
    ├── detect platform
    │     ├── macOS
    │     └── Linux
    │
    ├── install common UX dependencies
    │
    ├── apply platform configuration
    │
    └── apply role configuration
          ├── workstation
          ├── client
          └── server
```

The current `bootstrap.sh` is only an initial implementation.

It does not yet represent the final architecture.

---

# Portability rules

## Common means genuinely common

Common configuration must not assume:

```text
macOS
Homebrew
Apple Silicon
/opt/homebrew
a specific username
$HOME
Docker Desktop
JetBrains
Sublime Text
```

Platform-specific behavior must be conditional or separated.

---

## Optional software must stay optional

Missing optional applications must never break shell startup.

Prefer guarded initialization such as:

```zsh
command -v tool >/dev/null 2>&1
```

or:

```zsh
[[ -d "$SOME_PATH" ]]
```

---

## No secrets in Git

Never commit:

```text
SSH private keys
API tokens
cloud credentials
passwords
.env secrets
private certificates
```

Dotfiles may configure access to secrets, but the secrets themselves remain outside the repository.

---

# chezmoi

`chezmoi` manages the actual dotfiles.

Source directory:

```text
~/.local/share/chezmoi
```

Typical workflow:

```bash
chezmoi add ~/.zshrc
chezmoi add ~/.config/zsh/example.zsh
```

Review managed differences:

```bash
chezmoi diff
```

Repository workflow:

```bash
cd ~/.local/share/chezmoi

git status
git diff
```

Apply configuration:

```bash
chezmoi apply
```

---

# Migration strategy

The migration should happen conservatively.

## 1. Preserve the MacBook Pro UX

The current workstation is the working reference.

Before aggressively restructuring configuration:

* verify existing tools;
* restore lost functionality;
* avoid breaking the current environment.

---

## 2. Audit the old configuration

Determine what was actually useful from the previous setup.

Do not blindly restore everything from Oh My Zsh or old shell files.

---

## 3. Build the shared UX layer

Extract the parts that should behave the same on:

```text
MacBook Pro
MacBook Air
Linux
```

This includes primarily shell behavior and terminal UX.

---

## 4. Separate platform-specific configuration

Create clean separation between:

```text
common
macOS
Linux
```

macOS-specific paths must not leak into Linux configuration.

---

## 5. Separate machine roles

Create clean separation between:

```text
workstation
client
server
```

Different roles do not need identical software.

---

## 6. Configure the MacBook Air

The MacBook Air should become a lightweight remote-development client with:

```text
Ghostty
shared shell UX
SSH
remote development workflow
```

without duplicating the full workstation stack.

---

## 7. Configure Linux remote development

Linux should reproduce the shared shell UX while using its own package manager and server-specific tooling.

---

## 8. Test a clean bootstrap

The final proof is being able to configure a new or clean machine predictably from the repository.

---

# Current priorities

1. Preserve and audit the current MacBook Pro UX.
2. Add a good portable prompt.
3. Refactor shell configuration into common/platform/role layers.
4. Make bootstrap platform-aware.
5. Make bootstrap role-aware.
6. Add Ghostty configuration.
7. Build the MacBook Air client profile.
8. Add Linux support.
9. Test the same UX over SSH.
10. Test clean-machine installation.

---

# Definition of success

The project is successful when:

* the MacBook Pro remains a full development workstation;
* the MacBook Air remains lightweight;
* the MacBook Air works well as a remote-development client;
* Linux servers can be configured predictably;
* machine-specific software remains machine-specific;
* common shell configuration works across macOS and Linux;
* optional missing software never breaks shell startup;
* secrets remain outside Git;
* configuration is reproducible;
* moving between local and remote machines does not destroy the familiar terminal UX.

The central principle is:

> **Different machines. Different roles. Same core terminal UX.**

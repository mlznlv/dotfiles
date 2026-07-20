# dotfiles

Portable terminal UX for macOS and Linux.

The goal: different machines may run different workloads, but the terminal should feel familiar everywhere.

- MacBook Pro — local development.
- MacBook Air — lightweight client / remote development.
- Linux / Minisforum — remote development host.

`chezmoi` manages portable `$HOME` config. `mise` manages bootstrap dependencies and development runtimes.

## Install

Prerequisites: Git, `curl`, and access to this repository.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

Clone:

```bash
mkdir -p ~/.local/share
git clone git@github.com:mlznlv/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
```

Bootstrap:

| Machine | Command |
|---|---|
| MacBook Air | `./bootstrap.sh base` |
| MacBook Pro | `./bootstrap.sh local-dev` |
| Linux / Minisforum | `./bootstrap.sh dev-host` |

`base` is the default:

```bash
./bootstrap.sh
```

Restart the shell:

```bash
exec zsh -l
```

## Base stack

Keep the base small and intentional.

macOS:

```text
git
gh
jq
fzf
ripgrep
zoxide
```

Linux:

```text
zsh
git
curl
jq
fzf
ripgrep
zoxide
```

Additional workload-specific packages live in profile files:

- `mise.macos-local-dev.toml` — local development additions such as AWS/Kubernetes CLI tooling.
- `mise.linux-dev-host.toml` — remote development additions such as build tools and tmux.

Do not import a full `brew list`. Declare only direct tools you intentionally use; package-manager dependencies stay package-manager dependencies.

## Add or remove software

### System CLI or GUI app

Put machine-global software in `[bootstrap.packages]`.

Examples from the repository root:

```bash
# macOS base CLI
mise bootstrap packages use -e macos brew:<package>

# macOS local-development CLI
mise bootstrap packages use -e macos-local-dev brew:<package>

# macOS GUI app
mise bootstrap packages use -e macos brew-cask:<cask>

# Linux base package
mise bootstrap packages use -e linux apt:<package>

# Linux dev-host package
mise bootstrap packages use -e linux-dev-host apt:<package>
```

Then review the diff and run the matching bootstrap again.

To stop managing a package, remove its declaration from the corresponding `mise.*.toml` file.

Homebrew formula cleanup can be previewed and applied explicitly:

```bash
mise bootstrap packages prune --manager brew --dry-run
mise bootstrap packages prune --manager brew --yes
```

Do not run destructive prune commands blindly. Other system-package removal remains explicit/manual.

### Development runtime

Project runtimes belong to the project, not the machine profile.

Example:

```bash
cd ~/src/project
mise use node@lts
mise use python@latest
```

This writes project-local runtime state and lets `mise` switch versions automatically when entering the project.

### Node and NVM

NVM is **not installed on new machines**.

The current MacBook Pro still loads an existing `~/.nvm` installation for migration compatibility. New machines use `mise` as the Node version manager.

Global mise config enables `.nvmrc` support, so existing projects can keep their `.nvmrc` while Node is provided by `mise`.

When all current projects work through `mise`, the NVM compatibility block can be removed from `runtimes.zsh`.

## Zsh layout

```text
dot_config/zsh/
├── core.zsh         history and shell options
├── paths.zsh        PATH only
├── completion.zsh   completion/autocomplete subsystem; loads early
├── runtimes.zsh     nvm/pyenv compatibility + mise activation
├── aliases.zsh      explicit aliases
├── prompt.zsh       prompt
└── ux.zsh           fzf, zoxide, autosuggestions, syntax highlighting
```

The split is by responsibility:

- `completion.zsh` exists separately because Zsh completion must initialize before integrations that register completions.
- `runtimes.zsh` owns language/runtime version managers only.
- `ux.zsh` owns interactive terminal behavior.

Do not create empty platform/role placeholders. Add a new file only when a real domain has enough behavior to justify it.

## Update

```bash
cd ~/.local/share/chezmoi
git pull --ff-only
./bootstrap.sh <profile>
exec zsh -l
```

Check state:

```bash
chezmoi diff
mise bootstrap status --missing
```

## Edit dotfiles

```bash
cd ~/.local/share/chezmoi
git status
git diff

# edit source files
chezmoi diff
chezmoi apply
exec zsh -l
```

Machine-local exceptions belong in:

```text
~/.config/zsh/local.zsh
```

Never commit credentials, private keys, tokens, certificates, `.env` secrets, caches, or raw package-manager snapshots.

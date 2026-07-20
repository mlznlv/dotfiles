# dotfiles

Portable macOS shell and terminal configuration managed with [`chezmoi`](https://www.chezmoi.io/) and Git.

Repository:

```text
git@github.com:example-user/dotfiles.git
```

## Goals

* Reproducible shell environment across Macs.
* No Oh My Zsh dependency.
* Minimal, explicit configuration.
* Shared base configuration with optional machine-specific profiles.
* Safe migration between machines without copying accumulated local clutter.
* Keep secrets and machine-local data out of Git.

## Current stack

Shell:

```text
Zsh
```

Shell features:

```text
zsh-autocomplete
zsh-syntax-highlighting
fzf
zoxide
```

Dotfiles management:

```text
chezmoi
```

Package management:

```text
Homebrew
Homebrew Bundle
```

## Repository structure

```text
.
├── .chezmoiignore
├── Brewfile.common
├── bootstrap.sh
├── dot_config/
│   └── zsh/
│       ├── core.zsh
│       ├── plugins.zsh
│       └── tools.zsh
├── dot_zprofile
└── dot_zshrc
```

Managed files are applied as:

```text
dot_zshrc                       → ~/.zshrc
dot_zprofile                    → ~/.zprofile
dot_config/zsh/core.zsh         → ~/.config/zsh/core.zsh
dot_config/zsh/plugins.zsh      → ~/.config/zsh/plugins.zsh
dot_config/zsh/tools.zsh        → ~/.config/zsh/tools.zsh
```

## Configuration layout

### `~/.zshrc`

Minimal entry point.

Loads modular configuration from:

```text
~/.config/zsh/
```

### `core.zsh`

Core Zsh behavior:

* history
* history sharing
* duplicate handling
* shell-level defaults

### `tools.zsh`

Development/runtime tools currently configured locally, including support for:

```text
nvm
pyenv
fzf
zoxide
```

Not every tool referenced here is currently provisioned automatically on a new machine.

### `plugins.zsh`

Standalone Zsh plugins installed through Homebrew:

```text
zsh-autocomplete
zsh-syntax-highlighting
```

No Oh My Zsh is used.

### `~/.zprofile`

Login-shell initialization.

Currently responsible for portable Homebrew initialization on both:

```text
Apple Silicon: /opt/homebrew
Intel Mac:     /usr/local
```

## Common Homebrew dependencies

`Brewfile.common` contains only the minimal shared toolset:

```ruby
brew "chezmoi"
brew "fzf"
brew "gh"
brew "git"
brew "ripgrep"
brew "zoxide"
brew "zsh-autocomplete"
brew "zsh-syntax-highlighting"
```

The file intentionally does not contain a dump of every package installed on the current machine.

Machine-specific dependencies will be added explicitly when needed.

## Bootstrap

After the repository is initialized as the chezmoi source directory:

```bash
./bootstrap.sh
```

The script:

1. Reads `Brewfile.common`.
2. Installs missing Homebrew dependencies.
3. Applies managed dotfiles with `chezmoi apply`.

Current bootstrap assumes Homebrew is already installed.

## Working with chezmoi

Check managed files:

```bash
chezmoi managed
```

Preview changes before applying:

```bash
chezmoi diff
```

Apply repository state:

```bash
chezmoi apply
```

Add or update a managed file:

```bash
chezmoi add ~/.zshrc
```

After changing managed files directly, update the chezmoi source copy before committing.

## Git workflow

Source directory:

```text
~/.local/share/chezmoi
```

Typical workflow:

```bash
cd ~/.local/share/chezmoi

chezmoi diff

git status
git add .
git commit -m "Describe change"
git push
```

## Machine profiles

Planned model:

```text
common
├── workstation
└── client
```

### Common

Shared shell and terminal tooling for every Mac.

### Workstation

Developer workstation-specific tooling, potentially including:

```text
Node / nvm
Python / pyenv
Docker
Kubernetes tooling
AWS tooling
development applications
```

Only explicitly required dependencies should be added.

### Client

Lightweight configuration for machines primarily used as SSH clients.

Example:

```text
MacBook Air
→ Ghostty
→ Zsh
→ SSH
→ workstation
```

## Important design rules

Do not commit:

```text
SSH private keys
API tokens
credentials
.env files containing secrets
machine-specific secrets
temporary backups
raw Homebrew dumps
```

Do not use a full `brew bundle dump` result as the permanent source of truth.

Dependencies should be added deliberately.

Do not hardcode usernames such as:

```text
$HOME/...
```

Prefer:

```bash
$HOME
```

or XDG-compatible paths.

## Current migration status

Completed:

```text
✓ Oh My Zsh removed
✓ Clean modular Zsh configuration
✓ nvm still working on current workstation
✓ pyenv still working on current workstation
✓ Node still working
✓ Python still working
✓ zsh-autocomplete working
✓ zsh-syntax-highlighting configured
✓ fzf working
✓ zoxide working
✓ chezmoi repository created
✓ private GitHub repository configured
✓ common Homebrew dependencies defined
✓ bootstrap script created
```

Still to do:

```text
- Define workstation dependencies explicitly
- Reproduce nvm installation and Node version
- Reproduce pyenv and Python version
- Add Ghostty configuration
- Add prompt configuration
- Add aliases and Git helpers
- Define client profile
- Test clean-machine installation
- Test MacBook Air deployment
```

## Principle

The repository should describe the desired machine state.

It should not become an archive of everything that happened to accumulate on one Mac.

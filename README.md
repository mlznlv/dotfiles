# dotfiles

Portable terminal and development environment for macOS and Ubuntu/Debian.

```text
Homebrew  -> macOS packages/apps
mise      -> runtimes/versioned tools + Linux packages + managed repos
chezmoi   -> home/shell config
Starship  -> prompt
Ghostty   -> macOS terminal UI
Tailscale + OpenSSH + tmux -> remote development
```

## Quick start

### macOS

Install Apple Command Line Tools first:

```bash
xcode-select --install
```

Then:

```bash
mkdir -p ~/.local/share
git clone <repository-url> ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./bootstrap.sh local-dev
exec zsh -l
```

### Ubuntu/Debian dev host

```bash
sudo apt-get update
sudo apt-get install -y git curl

mkdir -p ~/.local/share
git clone <repository-url> ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./bootstrap.sh dev-host
exec zsh -l
```

## Profiles

| Profile | Platform | Purpose |
|---|---|---|
| `base` | macOS/Ubuntu/Debian | minimal shared terminal environment |
| `local-dev` | macOS | full local-development workstation |
| `remote-client` | macOS | lightweight remote-development client |
| `dev-host` | Ubuntu/Debian | remote development host |

A profile is always explicit; there is no implicit fallback.

Bootstrap/reconverge:

```bash
./bootstrap.sh <profile>
```

Routine update:

```bash
bash ./update.sh <profile>
exec zsh -l
```

## Daily commands

```bash
# Runtime/tool state
mise current
mise doctor

# Starship
prompt-preset
prompt-module status
prompt-module enable aws
prompt-module disable aws

# Remote dev: SSH + persistent tmux session
remote <user>@<host> [session]

# Verify chezmoi convergence
chezmoi diff
```

Default Starship preset: `plain-text-symbols`. Infrastructure/context modules are hidden by portable policy and can be enabled per machine with `prompt-module`.

## Documentation

- [Architecture and ownership](docs/architecture.md)
- [Shell, Starship, and Ghostty](docs/shell-and-terminal.md)
- [Runtimes and versioned tools with mise](docs/runtimes.md)
- [Remote development](docs/remote-development.md)
- [Updates, verification, and troubleshooting](docs/maintenance.md)

## Repository layout

```text
homebrew/     macOS Brewfiles
mise/         bootstrap/runtime/tool declarations
dot_config/   chezmoi-managed XDG config
docs/         operational documentation
bootstrap.sh  provisioning/convergence
update.sh     routine updates
```

## Privacy

Portable defaults belong in Git. Credentials, private keys, certificates, real hostnames/IPs, Tailscale identity, corporate/private registry configuration, and machine-specific identity stay local.

Common machine-local state:

```text
~/.config/zsh/local.zsh
~/.config/mise/conf.d/90-machine-local.toml
~/.config/starship/preset
~/.config/starship/modules
```

See [architecture.md](docs/architecture.md) before publishing an existing repository history.

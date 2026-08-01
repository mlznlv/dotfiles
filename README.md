# dotfiles

Portable terminal and development environment for macOS 13+ and Ubuntu/Debian.

## Quick start

### macOS 13+

```bash
xcode-select --install
mkdir -p ~/.local/share
git clone https://github.com/mlznlv/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./bootstrap.sh <profile>
exec zsh -l
```

| Profile | Purpose |
|---|---|
| `base` | minimal terminal environment |
| `local-dev` | local development workstation |
| `remote-client` | Mac client for remote development |

Continue with [Local development setup](docs/local-dev-setup.md) or [Remote client setup](docs/remote-client-setup.md).

### Ubuntu/Debian development host

```bash
sudo apt-get update
sudo apt-get install -y git curl
mkdir -p ~/.local/share
git clone https://github.com/mlznlv/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./bootstrap.sh dev-host
exec zsh -l
```

Profiles are explicit. `bootstrap.sh` and `update.sh` refuse to run without one.

## Update and verify

```bash
cd ~/.local/share/chezmoi
bash ./update.sh <profile>
./scripts/health-check.sh <profile>
```

## Useful commands

```bash
mise current
mise doctor
chezmoi diff
remote <user>@<host> [session]
```

## Documentation

- [Local development setup](docs/local-dev-setup.md)
- [Remote client setup](docs/remote-client-setup.md)
- [Remote development](docs/remote-development.md)
- [Updates and troubleshooting](docs/maintenance.md)
- [Architecture and ownership](docs/architecture.md)
- [Shell and terminal](docs/shell-and-terminal.md)
- [Runtimes and versioned tools](docs/runtimes.md)

## Repository layout

```text
homebrew/     macOS packages and applications
editor/       editor extension declarations
mise/         runtimes, tools, Linux packages, managed repositories
dot_config/   chezmoi-managed configuration
docs/         documentation
scripts/      checks, helpers, migrations
bootstrap.sh  first installation and convergence
update.sh     routine updates
```

## Privacy

Do not commit credentials, private keys, certificates, real hostnames/IPs, Tailscale identity, private registry configuration, or machine-specific identity.

Machine-local configuration belongs in:

```text
~/.config/zsh/local.zsh
~/.config/mise/conf.d/90-machine-local.toml
~/.config/starship/preset
~/.config/starship/modules
```

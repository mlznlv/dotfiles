# Local development setup

## Install

```bash
xcode-select --install
mkdir -p ~/.local/share
git clone https://github.com/mlznlv/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./bootstrap.sh local-dev
exec zsh -l
```

Open Docker Desktop and Tailscale once. Enable VS Code Settings Sync.

## Customize applications

Default: Docker Desktop and the repository `local-dev` Brewfile.

Replace the profile set:

```bash
DOTFILES_PROFILE_BREWFILE="$HOME/path/Brewfile" ./bootstrap.sh local-dev
```

Add applications to the default set:

```bash
DOTFILES_EXTRA_BREWFILE="$HOME/path/Brewfile.extra" ./bootstrap.sh local-dev
```

The replacement must still provide a Docker-compatible `docker` CLI for Dev Containers.

## Verify

```bash
./scripts/health-check.sh local-dev
```

Project runtimes and extensions belong in `.devcontainer`, `compose.yaml`, and project-level `mise.toml` files.

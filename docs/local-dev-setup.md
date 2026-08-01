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

Open OrbStack once, enable Tailscale, and enable VS Code Settings Sync.

## Verify

```bash
./scripts/health-check.sh local-dev
```

Project runtimes and extensions belong in `.devcontainer`, `compose.yaml`, and project-level `mise.toml` files.

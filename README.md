# dotfiles

Portable terminal UX for macOS and Linux.

The goal is simple: different machines may run different workloads, but the terminal should feel familiar everywhere.

- [chezmoi](https://www.chezmoi.io/) manages portable `$HOME` configuration.
- [mise](https://mise.jdx.dev/) manages bootstrap dependencies and development runtimes.
- [Tailscale](https://tailscale.com/) provides private remote network access.
- [OpenSSH](https://www.openssh.com/) + [tmux](https://github.com/tmux/tmux) provide persistent remote development sessions.

## Install

Prerequisites: [Git](https://git-scm.com/), [curl](https://curl.se/), and access to this repository.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

Clone:

```bash
mkdir -p ~/.local/share
git clone <repository-url> ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
```

Bootstrap a profile:

| Profile | Purpose | Command |
|---|---|---|
| `base` | minimal shared environment | `./bootstrap.sh base` |
| `remote-client` | macOS remote-development client | `./bootstrap.sh remote-client` |
| `local-dev` | macOS local-development workstation | `./bootstrap.sh local-dev` |
| `dev-host` | Linux remote-development host | `./bootstrap.sh dev-host` |

Restart the shell:

```bash
exec zsh -l
```

## Remote development

```text
remote client -> Tailscale -> SSH -> dev host -> tmux
```

No public IP, DDNS, or router port forwarding is required.

First-time setup:

1. Sign both machines into the same Tailscale network.
2. On the Linux host:

```bash
sudo tailscale up
```

3. Authorize the client's SSH public key for the Linux user.

With [MagicDNS](https://tailscale.com/kb/1081/magicdns) enabled:

```bash
remote <user>@<host>
```

A named tmux session is optional:

```bash
remote <user>@<host> backend
```

Detach without stopping work with `Ctrl-b d`. Run the same `remote` command later to reattach.

SSH keys, hostnames, IP addresses, Tailscale identity, and credentials are intentionally not stored in this repository.

## Stack

Base macOS:

- [Git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/) (`gh`)
- [jq](https://jqlang.org/)
- [fzf](https://github.com/junegunn/fzf)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [zoxide](https://github.com/ajeetdsouza/zoxide)

Base Linux:

- [Zsh](https://www.zsh.org/)
- [Git](https://git-scm.com/)
- [curl](https://curl.se/)
- [jq](https://jqlang.org/)
- [fzf](https://github.com/junegunn/fzf)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [zoxide](https://github.com/ajeetdsouza/zoxide)

Profiles add only workload-specific software:

- `mise.macos-remote-client.toml` — Tailscale client.
- `mise.macos-local-dev.toml` — local-development tooling.
- `mise.linux-dev-host.toml` — OpenSSH server, tmux, build tools, and Tailscale.

Do not import package-manager snapshots. Declare only direct tools that are intentionally part of the environment.

## Add or remove software

Machine-global software belongs in `[bootstrap.packages]`.

```bash
# macOS base CLI
mise bootstrap packages use -e macos brew:<package>

# macOS remote-client app
mise bootstrap packages use -e macos-remote-client brew-cask:<cask>

# macOS local-development CLI
mise bootstrap packages use -e macos-local-dev brew:<package>

# Linux base package
mise bootstrap packages use -e linux apt:<package>

# Linux dev-host package
mise bootstrap packages use -e linux-dev-host apt:<package>
```

To stop managing software, remove its declaration from the corresponding `mise.*.toml`. Operating-system package removal remains explicit.

Project runtimes belong to the project and are managed by mise:

```bash
cd ~/src/project
mise use node@lts
mise use python@latest
```

Existing `.nvmrc` and `.python-version` files are supported by the managed global mise config. Separate NVM and pyenv installations are not part of the target stack.

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

## Edit

```bash
cd ~/.local/share/chezmoi
git status
git diff

# edit source files
chezmoi diff
chezmoi apply
exec zsh -l
```

Machine-local exceptions belong in `~/.config/zsh/local.zsh`.

Never commit credentials, private keys, tokens, certificates, `.env` secrets, caches, host-specific network identity, or raw package-manager snapshots.

# dotfiles

Portable terminal UX for macOS and Linux.

The goal: different machines may run different workloads, but the terminal should feel familiar everywhere.

- MacBook Pro — local development.
- MacBook Air — lightweight remote-development client.
- Linux / Minisforum — remote development host.

`chezmoi` manages portable `$HOME` config. `mise` manages bootstrap dependencies and development runtimes. Tailscale provides private remote network access; SSH + tmux provide the persistent remote shell.

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
| MacBook Air | `./bootstrap.sh remote-client` |
| MacBook Pro | `./bootstrap.sh local-dev` |
| Linux / Minisforum | `./bootstrap.sh dev-host` |

`base` is the minimal default:

```bash
./bootstrap.sh
```

Restart the shell:

```bash
exec zsh -l
```

## Remote development

The remote path is:

```text
MacBook Air -> Tailscale -> SSH -> Minisforum -> tmux
```

No public IP, DDNS, or router port forwarding is required.

First-time setup:

1. On the Air, open Tailscale and sign in to the tailnet.
2. On the Minisforum, authenticate once:

```bash
sudo tailscale up
```

With MagicDNS enabled, connect by the server name:

```bash
remote <user>@<server-name>
```

Example:

```bash
remote emil@dev
```

`remote` runs SSH and creates or reattaches the `main` tmux session. A named session is optional:

```bash
remote emil@dev backend
```

Detach without stopping the remote work:

```text
Ctrl-b d
```

Run the same `remote ...` command later to reattach.

The repository does not hardcode hostnames, IP addresses, SSH keys, or Tailscale identity.

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

Profiles add only workload-specific software:

- `mise.macos-remote-client.toml` — Tailscale client.
- `mise.macos-local-dev.toml` — local-development tooling.
- `mise.linux-dev-host.toml` — SSH server, tmux, build tools, and Tailscale.

Do not import a full `brew list`. Declare only direct tools you intentionally use; package-manager dependencies stay package-manager dependencies.

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

Then review the diff and run the matching bootstrap again.

To stop managing a package, remove its declaration from the corresponding `mise.*.toml` file. Package removal from the operating system remains explicit.

Project runtimes belong to the project:

```bash
cd ~/src/project
mise use node@lts
mise use python@latest
```

## Zsh layout

```text
dot_config/zsh/
├── core.zsh         history and shell options
├── paths.zsh        PATH only
├── completion.zsh   completion/autocomplete; loads early
├── runtimes.zsh     runtime manager activation
├── remote.zsh       SSH + tmux remote entrypoint
├── aliases.zsh      explicit aliases
├── prompt.zsh       prompt
└── ux.zsh           fzf, zoxide, autosuggestions, syntax highlighting
```

Add a new file only when a real domain has enough behavior to justify it.

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

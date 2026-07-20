# dotfiles

Portable terminal UX for macOS and Linux.

The goal is simple: different machines may run different workloads, but the terminal should feel familiar everywhere.

- [chezmoi](https://www.chezmoi.io/) manages portable `$HOME` configuration.
- [mise](https://mise.jdx.dev/) manages bootstrap dependencies and development runtimes.
- [Tailscale](https://tailscale.com/) provides private remote network access.
- [OpenSSH](https://www.openssh.com/) + [tmux](https://github.com/tmux/tmux) provide persistent remote development sessions.

## Install

Prerequisites: [Git](https://git-scm.com/), [curl](https://curl.se/), and access to this repository.

macOS:

```bash
xcode-select --install
```

Complete the Command Line Tools installation before cloning the repository. [Homebrew](https://brew.sh/) is not a manual prerequisite: `bootstrap.sh` installs the real Homebrew CLI when it is missing. The first installation may request confirmation or administrator credentials.

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

On macOS the bootstrap order is Homebrew -> mise -> declared packages/tools -> chezmoi.

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

- [Homebrew](https://brew.sh/)
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

All mise source configuration lives under `mise/`:

- `mise/config.toml` — shared bootstrap state.
- `mise/config.macos.toml` / `mise/config.linux.toml` — platform base.
- `mise/config.macos-remote-client.toml` / `mise/config.macos-local-dev.toml` / `mise/config.linux-dev-host.toml` — profile additions.
- `mise/runtime.toml` — shared runtime settings projected to `~/.config/mise/config.toml` by chezmoi.
- `mise/runtime.macos-local-dev.toml` — default Node/Python toolset installed as a local-dev profile fragment under `~/.config/mise/conf.d/`.

Do not import package-manager snapshots. Declare only direct tools that are intentionally part of the environment.

## Add or remove software

Machine-global software belongs in `[bootstrap.packages]` under `mise/`.

```bash
# macOS base CLI
mise bootstrap packages use --path mise/config.macos.toml brew:<package>

# macOS remote-client app
mise bootstrap packages use --path mise/config.macos-remote-client.toml brew-cask:<cask>

# macOS local-development CLI
mise bootstrap packages use --path mise/config.macos-local-dev.toml brew:<package>

# Linux base package
mise bootstrap packages use --path mise/config.linux.toml apt:<package>

# Linux dev-host package
mise bootstrap packages use --path mise/config.linux-dev-host.toml apt:<package>
```

To stop managing software, remove its declaration from the corresponding `mise/config.*.toml`. Operating-system package removal remains explicit.

The `local-dev` profile provides usable defaults outside projects:

```toml
[tools]
node = "lts"
python = "3.14"
```

Project runtimes still belong to the project. Project-local mise config, `.nvmrc`, and `.python-version` override the defaults:

```bash
cd ~/src/project
mise install
mise current
```

Separate NVM and pyenv installations are not part of the target stack.

## Update

```bash
cd ~/.local/share/chezmoi
git pull --ff-only
./bootstrap.sh <profile>
exec zsh -l
```

## Smoke test

After bootstrap, verify the shell and managed state:

```bash
mise doctor
command -v brew mise git gh jq fzf rg zoxide
chezmoi diff
```

On `local-dev`, defaults should also work outside any project:

```bash
cd ~
node --version
npm --version
python --version
```

Then verify at least one real project for each runtime it uses:

```bash
cd <node-project-with-.nvmrc>
mise install
mise current
node --version

cd <python-project-with-.python-version>
mise install
mise current
python --version
```

Expected state: `mise doctor` reports no problems, default runtimes work on `local-dev`, project runtimes override them when configured, and `chezmoi diff` is empty or intentionally machine-local. The `local-dev` profile has been manually smoke-tested on macOS with this flow.

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

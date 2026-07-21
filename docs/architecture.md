# Architecture

## Ownership

Each domain has one owner:

```text
macOS packages/apps        -> native Homebrew + Brewfiles
Linux system packages      -> mise bootstrap.packages + apt
versioned runtimes/CLI     -> mise
home/shell config           -> chezmoi
prompt rendering            -> Starship
terminal UI on macOS        -> Ghostty
remote access               -> Tailscale + OpenSSH + tmux
```

Do not mix managers for the same filesystem prefix. `/opt/homebrew` belongs to native Homebrew; mise must not pour or link Homebrew bottles there.

Starship follows platform ownership: Homebrew installs it on macOS; the Linux platform mise layer installs and activates it as a versioned CLI tool.

## Profiles

| Profile | Platform | Purpose |
|---|---|---|
| `base` | macOS/Linux | minimal shared terminal environment |
| `local-dev` | macOS | full local-development workstation |
| `remote-client` | macOS | lightweight remote-development client |
| `dev-host` | Ubuntu/Debian | remote development host |

Profiles are always explicit:

```bash
./bootstrap.sh <profile>
bash ./update.sh <profile>
```

There is intentionally no implicit `base` fallback: forgetting a profile must not silently change machine capability state.

## Mise layering

Global mise fragments use numeric precedence:

```text
10-dotfiles-platform.toml   platform-wide tools, e.g. Starship on Linux
20-dotfiles-profile.toml    profile defaults, e.g. Node/Python on macOS local-dev
90-machine-local.toml       private machine constraints
project config              repository-specific requirements
```

The first two are projected by `bootstrap.sh`. `90-machine-local.toml` is never committed.

## Package declarations

macOS uses native Homebrew:

```text
homebrew/Brewfile
homebrew/Brewfile.local-dev
homebrew/Brewfile.remote-client
```

Bootstrap installs missing declarations with `brew bundle install --no-upgrade`; routine upgrades are handled by `update.sh`.

Ubuntu/Debian system packages are declared in:

```text
mise/config.linux.toml
mise/config.linux-dev-host.toml
```

## Portable vs machine-local state

Keep machine identity, credentials, private infrastructure, and machine-only constraints outside Git. Common local paths include:

```text
~/.config/zsh/local.zsh
~/.config/mise/conf.d/90-machine-local.toml
~/.config/starship/preset
~/.config/starship/modules
```

Never commit credentials, API tokens, private keys, certificates, private registry credentials, real hostnames/IPs, Tailscale identity, SSH targets, or machine-local Git identity/credential configuration.

A clean current tree does not sanitize old Git commits. Before publishing an existing private repository, inspect the full history; for strict redaction, publish a sanitized snapshot/clean history rather than relying on a squash merge alone.

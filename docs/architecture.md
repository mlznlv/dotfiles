# Architecture

## Ownership

Each domain has one owner:

```text
macOS packages/apps   -> native Homebrew + Brewfiles
Linux system packages -> mise bootstrap.packages + apt
Node/Python runtimes  -> mise
home/shell config      -> chezmoi
prompt                  -> Starship
terminal UI on macOS    -> Ghostty
remote access           -> Tailscale + OpenSSH + tmux
```

Do not mix managers for the same filesystem prefix. In particular, `/opt/homebrew` belongs to the native Homebrew installation; mise does not pour or link Homebrew bottles there.

## Profiles

| Profile | Platform | Purpose |
|---|---|---|
| `base` | macOS/Linux | minimal shared terminal environment |
| `local-dev` | macOS | full local-development workstation |
| `remote-client` | macOS | lightweight remote-development client |
| `dev-host` | Linux | remote development host |

Bootstrap is repeatable and converges the selected profile:

```bash
./bootstrap.sh <profile>
```

## Package declarations

macOS uses native Homebrew:

```text
homebrew/Brewfile
homebrew/Brewfile.local-dev
homebrew/Brewfile.remote-client
```

Bootstrap installs missing declarations with `brew bundle install --no-upgrade`. Routine upgrades are handled by `update.sh`.

Linux package declarations live in:

```text
mise/config.linux.toml
mise/config.linux-dev-host.toml
```

## Portable vs machine-local state

Portable policy belongs in the repository. Machine identity, credentials, private infrastructure, and machine-only constraints do not.

Keep these outside Git:

```text
~/.config/zsh/local.zsh
~/.config/mise/conf.d/90-machine-local.toml
~/.config/starship/preset
~/.config/starship/modules
```

Never commit credentials, API tokens, private keys, certificates, private registry credentials, real hostnames/IPs, Tailscale identity, SSH targets, or machine-local Git identity/credential configuration.

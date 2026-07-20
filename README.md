# dotfiles

Portable terminal and development environment for macOS and Linux.

The setup is split by ownership. Each layer has one job and one owner:

```text
macOS system packages/apps  -> real Homebrew + Brewfiles
Linux system packages       -> mise bootstrap.packages + apt
Node/Python runtimes        -> mise
shell/home configuration    -> chezmoi
remote access               -> Tailscale + OpenSSH + tmux
```

Do not mix package managers for the same filesystem prefix. In particular, `/opt/homebrew` is owned by the real Homebrew installation; mise is not used to pour or link Homebrew bottles there.

Core tools:

- [chezmoi](https://www.chezmoi.io/) — portable `$HOME` configuration.
- [mise](https://mise.jdx.dev/) — development runtimes, Linux bootstrap packages, and managed repositories.
- [Homebrew](https://brew.sh/) — macOS system packages and applications.
- [Tailscale](https://tailscale.com/) — private network access.
- [OpenSSH](https://www.openssh.com/) + [tmux](https://github.com/tmux/tmux) — persistent remote sessions.

## Quick start

### macOS prerequisite

```bash
xcode-select --install
```

Finish the Command Line Tools installation before continuing. Homebrew is not a manual prerequisite; `bootstrap.sh` installs the official Homebrew CLI when it is missing.

### Ubuntu/Debian prerequisite

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

### Clone

```bash
mkdir -p ~/.local/share
git clone <repository-url> ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
```

### Choose a profile

| Profile | Platform | Purpose | Command |
|---|---|---|---|
| `base` | macOS/Linux | minimal shared terminal environment | `./bootstrap.sh base` |
| `local-dev` | macOS | full local-development workstation | `./bootstrap.sh local-dev` |
| `remote-client` | macOS | lightweight remote-development client | `./bootstrap.sh remote-client` |
| `dev-host` | Linux | remote development host | `./bootstrap.sh dev-host` |

For a normal development Mac:

```bash
./bootstrap.sh local-dev
exec zsh -l
```

Bootstrap is intended to be repeatable. Running it again converges the machine instead of rebuilding everything from scratch.

## What bootstrap owns

### macOS: native Homebrew

macOS software is declared under `homebrew/`:

```text
homebrew/
├── Brewfile
├── Brewfile.local-dev
└── Brewfile.remote-client
```

`homebrew/Brewfile` contains shared macOS tools. Profile files add only what that profile needs.

Bootstrap uses the real `brew` command:

```text
brew bundle install --no-upgrade
```

This installs missing declarations without turning bootstrap into a general upgrade operation.

The mise `brew:` bootstrap backend is intentionally not used on macOS. Mise's built-in Homebrew manager can pour bottles directly into the canonical Homebrew prefix without invoking the real `brew` CLI. Mixing that ownership model with a real Homebrew installation can create link/ownership conflicts, especially around shared dependencies such as certificates.

### Linux: apt through mise

Linux package declarations remain under:

```text
mise/config.linux.toml
mise/config.linux-dev-host.toml
```

Mise applies these through its `apt:` bootstrap package backend.

### Zsh plugin repositories

Zsh plugins are managed as Git repositories by mise:

```text
zsh-autocomplete
zsh-autosuggestions
zsh-syntax-highlighting
```

They live under the mise data directory and are not duplicated as Homebrew formulae.

## Runtime model: Node and Python

Mise is the only runtime/version manager. NVM and pyenv are not part of the target stack.

### `local-dev` defaults

A full development Mac needs Node and Python even outside project directories for CLIs, MCP servers, scripts, and ad-hoc commands.

The portable `local-dev` default is:

```toml
[tools]
node = "lts"
python = "3.14"
```

It comes from:

```text
mise/runtime.macos-local-dev.toml
```

Bootstrap projects it to:

```text
~/.config/mise/conf.d/20-dotfiles-profile.toml
```

After bootstrap:

```bash
cd ~
mise current
node --version
npm --version
python --version
```

### Project-specific runtimes

Projects can override machine defaults with supported runtime configuration such as:

```text
mise.toml
.nvmrc
.python-version
```

Example:

```bash
cd <project>
mise install
mise current
node --version
python --version
```

`.nvmrc` is historically an NVM file. Mise reads it for compatibility; NVM itself is not required.

### `package.json.engines` is a compatibility contract

A project may contain:

```json
{
  "engines": {
    "node": ">=20 <=24",
    "npm": ">=10 <11"
  }
}
```

In this setup, `engines` does not automatically select a Node version.

A repository with no `.nvmrc`, `mise.toml`, or another runtime selector continues using the current global/machine default. Therefore:

```bash
mise install
```

can correctly say that all tools are installed while the active Node/npm combination is still outside the project's compatibility range.

For an unfamiliar project, verify:

```bash
mise current
node --version
npm --version
```

If `.npmrc` contains `engine-strict=true`, an incompatible runtime may cause installation to fail instead of only warning.

## Machine-local runtime overrides

Portable defaults should not be changed because one machine has special constraints.

A work laptop can keep a private machine override, for example:

```bash
mkdir -p ~/.config/mise/conf.d

cat > ~/.config/mise/conf.d/90-machine-local.toml <<'EOF'
[tools]
node = "22"
EOF

exec zsh -l
mise install
```

Precedence is conceptually:

```text
repository/profile default
        ↓
machine-local override
        ↓
project-specific runtime configuration
```

The numeric prefixes make ownership visible:

```text
20-dotfiles-profile.toml   managed by this repository
90-machine-local.toml      private machine-specific override
```

`90-machine-local.toml` must never be committed.

For a temporary one-shell override:

```bash
mise shell node@20
```

## Routine updates

Use the same profile that provisioned the machine.

For a `local-dev` Mac:

```bash
cd ~/.local/share/chezmoi
bash ./update.sh local-dev
exec zsh -l
```

Other examples:

```bash
bash ./update.sh remote-client
bash ./update.sh dev-host
```

`update.sh` performs:

```text
git pull --ff-only
        ↓
mise self-update when supported
        ↓
bootstrap latest declarations
        ↓
macOS: real Homebrew Brewfile upgrades
Linux: managed apt package upgrades
        ↓
update managed Git repositories
        ↓
upgrade managed runtimes within configured ranges
        ↓
mise doctor + package/dotfile convergence checks
```

Important behavior:

- it refuses to pull over local changes in the dotfiles repository;
- on macOS it uses the real Homebrew CLI and the committed Brewfiles;
- it does not invoke mise's built-in `brew:` package manager;
- it does not run blanket `brew autoremove` or destructive cleanup;
- it does not intentionally upgrade unrelated top-level Homebrew packages that are not declared in the Brewfiles;
- Homebrew may still update required transitive dependencies when needed;
- runtime upgrades stay within configured ranges unless the configuration itself changes;
- machine-local overrides remain outside Git and continue to take precedence.

Use `bootstrap.sh` for provisioning/convergence. Use `update.sh` for routine maintenance.

## First checks after bootstrap or update

```bash
mise doctor
mise current
chezmoi diff
```

On macOS:

```bash
brew bundle check --file=homebrew/Brewfile
```

On `local-dev` also verify:

```bash
cd ~
node --version
npm --version
python --version
```

Then test at least one real project:

```bash
cd <project>
mise install
mise current
node --version
python --version
```

## Troubleshooting

### `node` or `python` is not found on `local-dev`

```bash
type -a mise
mise doctor
mise current
```

Then reconverge:

```bash
cd ~/.local/share/chezmoi
./bootstrap.sh local-dev
exec zsh -l
```

### Wrong Node version inside a project

```bash
ls -la .nvmrc .python-version mise.toml .tool-versions 2>/dev/null
mise current
node --version
npm --version
```

`package.json.engines` alone does not cause this setup to switch Node versions.

Temporary override:

```bash
mise shell node@<version>
```

Persistent machine-only constraint:

```text
~/.config/mise/conf.d/90-machine-local.toml
```

### `mise doctor` says `shims_on_path: no`

This setup activates mise through:

```text
mise activate zsh
```

Shims do not need to be the primary activation mechanism.

Useful checks:

```bash
mise doctor
type -a mise
mise current
```

### Arrow Up shows a loading/history menu

Expected behavior:

```text
Up Arrow     -> previous command immediately
Down Arrow   -> next command immediately
Ctrl-R       -> interactive history search
```

The repository explicitly restores normal Up/Down bindings after loading `zsh-autocomplete`.

After updating:

```bash
exec zsh -l
```

### Homebrew ownership/link conflict

Do not delete or overwrite files in `/opt/homebrew` just to make an updater pass.

First verify which tool is attempting the change. This repository intentionally uses only the real Homebrew CLI for macOS package management.

Useful diagnostics:

```bash
command -v brew
brew --prefix
brew doctor
brew bundle check --file=homebrew/Brewfile
```

If a file is managed by corporate software, MDM, certificate tooling, or another local process, keep that machine-specific ownership outside this repository and resolve it before forcing links.

## Add or remove macOS software

Shared macOS CLI software belongs in:

```text
homebrew/Brewfile
```

`local-dev` additions belong in:

```text
homebrew/Brewfile.local-dev
```

`remote-client` additions belong in:

```text
homebrew/Brewfile.remote-client
```

Examples:

```ruby
brew "tool-name"
cask "application-name"
```

After editing:

```bash
./bootstrap.sh <profile>
```

Do not import a full machine snapshot as desired state. Declare only software intentionally managed by this repository.

## Add or remove Linux software

Linux system packages remain under mise:

```text
mise/config.linux.toml
mise/config.linux-dev-host.toml
```

Examples:

```bash
mise bootstrap packages use --path mise/config.linux.toml apt:<package>
mise bootstrap packages use --path mise/config.linux-dev-host.toml apt:<package>
```

Then rerun the relevant bootstrap.

## Repository layout

```text
homebrew/
├── Brewfile
├── Brewfile.local-dev
└── Brewfile.remote-client

mise/
├── config.toml
├── config.linux.toml
├── config.linux-dev-host.toml
├── runtime.toml
└── runtime.macos-local-dev.toml
```

Responsibilities:

- `homebrew/*` — real Homebrew declarations for macOS.
- `mise/config.toml` — shared mise bootstrap state such as managed repositories.
- `mise/config.linux*.toml` — Linux apt packages and Linux profile behavior.
- `mise/runtime.toml` — shared runtime settings projected to `~/.config/mise/config.toml`.
- `mise/runtime.macos-local-dev.toml` — default runtime toolset for a full development Mac.

## Shell layout

```text
~/.config/zsh/
├── aliases.zsh
├── completion.zsh
├── core.zsh
├── local.zsh
├── paths.zsh
├── prompt.zsh
├── remote.zsh
├── runtimes.zsh
└── ux.zsh
```

`~/.config/zsh/local.zsh` is reserved for machine-local shell configuration and is not part of portable source state.

## Remote development

Target topology:

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

Optional named tmux session:

```bash
remote <user>@<host> backend
```

Detach without stopping work:

```text
Ctrl-b d
```

SSH keys, hostnames, IP addresses, Tailscale identity, and credentials are intentionally not stored in this repository.

## Privacy and public-repository rules

Never commit:

- credentials, API tokens, private keys, certificates, or `.env` secrets;
- corporate/private registry credentials;
- private hostnames, IP addresses, Tailscale identities, or SSH targets specific to a real environment;
- machine-local Git identity/credential configuration;
- `~/.config/mise/conf.d/90-machine-local.toml` or equivalent machine constraints;
- raw package-manager snapshots, caches, or generated state.

Machine-local exceptions belong outside portable source, primarily in:

```text
~/.config/zsh/local.zsh
~/.config/mise/conf.d/90-machine-local.toml
```

The repository should describe reusable policy and defaults, not one person's current machine state.

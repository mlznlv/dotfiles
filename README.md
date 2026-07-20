# dotfiles

Portable terminal and development environment for macOS and Linux.

The configuration has three layers:

1. **Repository defaults** — portable shell UX, packages, and profile defaults.
2. **Machine profile** — `base`, `local-dev`, `remote-client`, or `dev-host`.
3. **Machine/project overrides** — private machine constraints and project runtime versions.

The repository should stay generic and safe to publish. Credentials, private hostnames, company-specific settings, network identity, and machine-only constraints stay outside Git.

Core tools:

- [chezmoi](https://www.chezmoi.io/) — portable `$HOME` configuration.
- [mise](https://mise.jdx.dev/) — bootstrap packages, repositories, and development runtimes.
- [Homebrew](https://brew.sh/) — macOS system packages.
- [Tailscale](https://tailscale.com/) — private remote network access.
- [OpenSSH](https://www.openssh.com/) + [tmux](https://github.com/tmux/tmux) — persistent remote development sessions.

## Quick start

### 1. Install prerequisites

macOS:

```bash
xcode-select --install
```

Finish the Command Line Tools installation before continuing. Homebrew is not a manual prerequisite; `bootstrap.sh` installs it when missing.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

### 2. Clone

```bash
mkdir -p ~/.local/share
git clone <repository-url> ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
```

### 3. Bootstrap the correct profile

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

Bootstrap is designed to be repeatable. Running it again converges the machine instead of reinstalling everything unnecessarily.

## What bootstrap manages

On macOS the high-level flow is:

```text
Homebrew -> mise -> declared packages/repos/runtimes -> chezmoi
```

It installs missing dependencies, applies the selected profile, installs Zsh plugin repositories, configures runtime defaults where applicable, and applies the chezmoi state.

Do not manually reproduce those steps unless debugging bootstrap itself.

## Runtime model: Node and Python

### `local-dev` has usable defaults

A full development Mac must be able to run CLIs, MCP servers, scripts, package managers, and ad-hoc commands outside project directories.

The portable `local-dev` defaults are:

```toml
[tools]
node = "lts"
python = "3.14"
```

They are defined in:

```text
mise/runtime.macos-local-dev.toml
```

and bootstrap installs them as:

```text
~/.config/mise/conf.d/20-dotfiles-profile.toml
```

After bootstrap this should work from `$HOME`:

```bash
cd ~
mise current
node --version
npm --version
python --version
```

### Project versions override defaults

Projects own their runtime requirements.

mise can use project configuration such as:

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

`.nvmrc` is historically an NVM file; mise reads it for compatibility. NVM itself is not required. pyenv is also not part of the target stack.

### `package.json.engines` is not a runtime selector

A project may contain:

```json
{
  "engines": {
    "node": ">=20 <=24",
    "npm": ">=10 <11"
  }
}
```

Treat this as a compatibility contract. In this setup it does not automatically switch the active Node version.

A project without `.nvmrc`, `mise.toml`, or another supported runtime selector keeps using the current global/machine default. Therefore `mise install` may report that everything is installed even when the active Node/npm combination is outside the project's `engines` range.

When entering an unfamiliar project, check:

```bash
mise current
node --version
npm --version
```

If `.npmrc` contains `engine-strict=true`, an incompatible runtime may cause installs to fail rather than only warn.

## Machine-local runtime overrides

Do not weaken portable repository defaults because one machine has special constraints.

For example, a work laptop may need Node 22 globally while a personal Mac should continue following `node = "lts"`.

Keep that constraint outside the repository:

```bash
mkdir -p ~/.config/mise/conf.d

cat > ~/.config/mise/conf.d/90-machine-local.toml <<'EOF'
[tools]
node = "22"
EOF

exec zsh -l
mise install
```

Verify:

```bash
cd ~
mise current
node --version
npm --version
python --version
```

Conceptual precedence:

```text
repository/profile default
        ↓
machine-local override
        ↓
project-specific runtime configuration
```

The numeric prefixes make the layers obvious:

```text
20-dotfiles-profile.toml   managed by this repository
90-machine-local.toml      private machine-specific override
```

`90-machine-local.toml` must remain local to that machine and must not be committed.

For a temporary one-shell override:

```bash
mise shell node@20
```

## Update an existing machine

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

`update.sh` performs the maintenance workflow in this order:

```text
git pull --ff-only
        ↓
mise self-update when supported
        ↓
bootstrap latest declarations
        ↓
upgrade managed system packages
        ↓
update managed Git repositories
        ↓
upgrade managed runtimes within configured ranges
        ↓
mise doctor + chezmoi convergence check
```

Important behavior:

- it refuses to pull over local changes in the dotfiles repository;
- it upgrades only system packages declared by the selected profile;
- it does **not** run a blanket `brew upgrade` for every Homebrew package on the machine;
- it does **not** run `brew autoremove` or broad destructive cleanup;
- runtime upgrades stay within configured ranges unless the configuration itself changes;
- machine-local overrides such as `node = "22"` remain local and continue to take precedence over portable defaults.

Use `bootstrap.sh` when provisioning/converging. Use `update.sh` for routine maintenance.

## First checks after bootstrap or update

```bash
mise doctor
mise current
command -v brew mise git gh jq fzf rg zoxide
chezmoi diff
```

Expected:

```text
mise doctor -> No problems found
chezmoi diff -> empty unless an intentional local difference exists
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

Do not assume a project's runtime from memory. Check its runtime files, CI configuration, Dockerfiles, and `package.json.engines` when relevant.

## Troubleshooting

### `node` or `python` is not found

```bash
type -a mise
mise doctor
mise current
```

On `local-dev`, Node and Python should normally exist even in `$HOME`.

Reapply the profile when necessary:

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

`package.json.engines` alone does not switch Node in this setup.

Temporary override:

```bash
mise shell node@<version>
```

Persistent machine-wide constraint:

```text
~/.config/mise/conf.d/90-machine-local.toml
```

A project requirement that should apply to every developer and CI environment belongs in that project and should be agreed with its maintainers.

### `mise doctor` says `shims_on_path: no`

This setup uses shell activation through `mise activate zsh`; shims do not need to be the primary activation mechanism.

The meaningful checks are:

```bash
mise doctor
type -a mise
mise current
```

### Up Arrow shows a loading/history UI

Expected behavior:

```text
Up Arrow     -> previous command immediately
Down Arrow   -> next command immediately
Ctrl-R       -> interactive history search
```

`zsh-autocomplete` can otherwise map arrow keys to its own menu. The repository restores normal Up/Down history navigation after loading the plugin.

After updating:

```bash
exec zsh -l
```

## Add or remove managed software

All mise source configuration lives under `mise/`:

```text
mise/
├── config.toml
├── config.macos.toml
├── config.macos-local-dev.toml
├── config.macos-remote-client.toml
├── config.linux.toml
├── config.linux-dev-host.toml
├── runtime.toml
└── runtime.macos-local-dev.toml
```

Add a macOS base CLI:

```bash
mise bootstrap packages use --path mise/config.macos.toml brew:<package>
```

Add a macOS `local-dev` CLI:

```bash
mise bootstrap packages use --path mise/config.macos-local-dev.toml brew:<package>
```

Add a macOS `remote-client` app:

```bash
mise bootstrap packages use --path mise/config.macos-remote-client.toml brew-cask:<cask>
```

Add Linux packages:

```bash
mise bootstrap packages use --path mise/config.linux.toml apt:<package>
mise bootstrap packages use --path mise/config.linux-dev-host.toml apt:<package>
```

Then rerun bootstrap for the relevant profile.

Removing a declaration stops future management of that package. Operating-system removal remains explicit; do not blindly run broad cleanup/autoremove commands.

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

`~/.config/zsh/local.zsh` is reserved for machine-local shell configuration and is not part of the portable source state.

## Remote development

Target topology:

```text
remote client -> Tailscale -> SSH -> dev host -> tmux
```

First-time setup:

1. Sign both machines into the same Tailscale network.
2. On the Linux host:

```bash
sudo tailscale up
```

3. Authorize the client's SSH public key for the Linux user.

With MagicDNS enabled:

```bash
remote <user>@<host>
```

Optional named tmux session:

```bash
remote <user>@<host> backend
```

Detach without stopping work with `Ctrl-b d`; run the same `remote` command later to reattach.

SSH keys, hostnames, IP addresses, Tailscale identity, and credentials are intentionally not stored in this repository.

## Privacy and public-repository rules

Never commit:

- credentials, API tokens, private keys, certificates, or `.env` secrets;
- corporate/private registry credentials;
- private hostnames, IP addresses, Tailscale identities, or real SSH topology;
- machine-local Git identity/credential configuration;
- `~/.config/mise/conf.d/90-machine-local.toml` or equivalent machine-specific constraints;
- raw Homebrew/apt package snapshots, caches, or generated state.

Machine-local exceptions belong outside the portable repository, primarily in:

```text
~/.config/zsh/local.zsh
~/.config/mise/conf.d/90-machine-local.toml
```

The repository should describe reusable policy and defaults, not one person's current machine state.

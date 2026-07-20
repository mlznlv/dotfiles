# dotfiles

Portable terminal and development environment for macOS and Linux.

The design is intentionally split into three layers:

1. **Repository defaults** — portable shell UX, packages, and profile defaults.
2. **Machine profile** — what kind of machine this is: `base`, `local-dev`, `remote-client`, or `dev-host`.
3. **Machine/project overrides** — private machine-specific constraints and project-specific runtime versions.

The repository should stay generic and safe to publish. Credentials, company-specific configuration, hostnames, private network identity, and machine-only runtime constraints stay outside Git.

Core tools:

- [chezmoi](https://www.chezmoi.io/) manages portable `$HOME` configuration.
- [mise](https://mise.jdx.dev/) manages bootstrap packages and development runtimes.
- [Homebrew](https://brew.sh/) provides macOS system packages.
- [Tailscale](https://tailscale.com/) provides private remote network access.
- [OpenSSH](https://www.openssh.com/) + [tmux](https://github.com/tmux/tmux) provide persistent remote development sessions.

## Quick start

### 1. Install prerequisites

macOS:

```bash
xcode-select --install
```

Finish the Command Line Tools installation before continuing. Homebrew is **not** a manual prerequisite: `bootstrap.sh` installs the real Homebrew CLI when it is missing.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

### 2. Clone the repository

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
| `remote-client` | macOS | lightweight client for remote development | `./bootstrap.sh remote-client` |
| `dev-host` | Linux | remote development host | `./bootstrap.sh dev-host` |

Then restart the login shell:

```bash
exec zsh -l
```

For a normal development Mac, use:

```bash
./bootstrap.sh local-dev
exec zsh -l
```

The bootstrap is intended to be repeatable. Running it again should converge the machine instead of reinstalling everything unnecessarily.

## What bootstrap does

On macOS the high-level order is:

```text
Homebrew -> mise -> declared packages/repos/runtimes -> chezmoi
```

The bootstrap:

- validates the platform/profile combination;
- installs Homebrew on macOS when missing;
- installs mise when missing;
- loads platform/profile-specific mise configuration;
- installs declared system packages and Zsh plugin repositories;
- installs profile runtime defaults where applicable;
- installs chezmoi when missing;
- applies the repository state to `$HOME`.

Do not manually reproduce these steps unless debugging bootstrap itself.

## Runtime model: Node and Python

This is the most important part of the setup.

### `local-dev` has usable global defaults

A full local-development Mac must be able to run CLIs, MCP servers, scripts, package managers, and ad-hoc commands even when the current directory is not a project.

The repository therefore provides these `local-dev` defaults:

```toml
[tools]
node = "lts"
python = "3.14"
```

They come from:

```text
mise/runtime.macos-local-dev.toml
```

and are installed by bootstrap as the managed profile fragment:

```text
~/.config/mise/conf.d/20-dotfiles-profile.toml
```

After `./bootstrap.sh local-dev`, this should work from `$HOME`:

```bash
cd ~
mise current
node --version
npm --version
python --version
```

### Project versions override global defaults

Projects own their runtime requirements.

Project-local mise configuration or supported version files override the global `local-dev` defaults. Existing repositories may use files such as:

```text
mise.toml
.nvmrc
.python-version
```

Example:

```bash
cd ~/src/project
mise install
mise current
node --version
python --version
```

A project with `.nvmrc` requesting Node 22 can use Node 22 while `$HOME` still uses the global `local-dev` Node LTS.

`.nvmrc` is historically an NVM file; mise reads it only for compatibility. NVM itself is not required.

Separate NVM and pyenv installations are **not** part of this stack.

### `package.json.engines` does not select the Node version here

This distinction is easy to miss.

A project may declare compatibility like:

```json
{
  "engines": {
    "node": ">=20 <=24",
    "npm": ">=10 <11"
  }
}
```

Treat `engines` as a **compatibility contract**, not as the runtime selector for this dotfiles setup.

If the repository has no project-specific runtime selector such as `.nvmrc` or `mise.toml`, mise keeps using the current global/machine default. Therefore:

```bash
mise install
```

may correctly print:

```text
mise all tools are installed
```

while the active global Node version still does not satisfy that project's `engines` range.

Always verify when entering an unfamiliar project:

```bash
mise current
node --version
npm --version
```

If the project has `engine-strict=true` in `.npmrc`, an incompatible runtime may turn an engine mismatch into an install failure instead of only a warning.

## Machine-local runtime overrides

Do **not** weaken repository defaults just because one machine has special compatibility constraints.

Example: a work laptop may need Node 22 globally because most work repositories accept Node 20–24 but require npm 10, while a personal development Mac should continue following the normal `node = "lts"` policy.

Keep that constraint outside this repository:

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

The intended precedence is conceptually:

```text
repository/profile default
        ↓
machine-local override
        ↓
project-specific runtime configuration
```

`90-machine-local.toml` is deliberately outside the chezmoi source tree. It must remain local to that machine and must not be copied into the public repository.

The numeric prefix is a naming convention that makes the layers obvious:

```text
20-dotfiles-profile.toml   managed by this repository
90-machine-local.toml      private machine-specific override
```

Use machine-local overrides for constraints such as:

- a work environment pinned to a supported Node line;
- private SDK/toolchain requirements;
- machine-specific paths or environment behavior that should not affect other computers.

Do not put credentials or tokens in mise config. Use the appropriate credential store or private local configuration instead.

## Temporary runtime override

For a one-off shell session, do not edit the repository or a project:

```bash
mise shell node@20
node --version
```

This is useful for testing an older project without changing persistent defaults.

## First checks after bootstrap

Run:

```bash
mise doctor
command -v brew mise git gh jq fzf rg zoxide
chezmoi diff
```

Expected:

```text
mise doctor -> No problems found
chezmoi diff -> empty, unless there is an intentional local difference
```

On `local-dev`, also verify global runtimes:

```bash
cd ~
mise current
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

Do not assume the project version from memory. Compare the active versions with the repository's runtime files, CI configuration, Dockerfiles, and `package.json.engines` when relevant.

## Troubleshooting runtimes

### `node` or `python` is not found

Check whether mise is active:

```bash
type -a mise
mise doctor
mise current
```

On `local-dev`, `node` and `python` should normally exist even in `$HOME`.

If they do not, rerun:

```bash
cd ~/.local/share/chezmoi
git pull --ff-only
./bootstrap.sh local-dev
exec zsh -l
```

### Wrong Node version inside a project

Check what the project actually declares:

```bash
ls -la .nvmrc .python-version mise.toml .tool-versions 2>/dev/null
mise current
node --version
npm --version
```

Important: `package.json.engines` alone does not cause this setup to switch Node versions.

For an immediate temporary fix:

```bash
mise shell node@<version>
```

For a persistent machine-wide compatibility constraint, use:

```text
~/.config/mise/conf.d/90-machine-local.toml
```

For a real project requirement that should apply to every developer and CI environment, the runtime selector belongs in the project itself and should be agreed with that project's maintainers.

### `mise doctor` says `shims_on_path: no`

This setup uses shell activation through `mise activate zsh`; shims do not need to be the primary activation mechanism.

The meaningful checks are:

```bash
mise doctor
type -a mise
mise current
```

### Arrow Up shows a completion/history loading UI

Expected terminal behavior in this repository is:

```text
Up Arrow     -> previous command immediately
Down Arrow   -> next command immediately
Ctrl-R       -> interactive history search
```

`zsh-autocomplete` can otherwise map arrow keys to its own menu. The repository explicitly restores normal Up/Down history navigation after loading the plugin.

After updating dotfiles, restart the shell:

```bash
exec zsh -l
```

If the problem persists, confirm the repository is current and reapply the profile:

```bash
cd ~/.local/share/chezmoi
git pull --ff-only
./bootstrap.sh <profile>
exec zsh -l
```

## Update an existing machine

Use the same profile that was used to provision the machine:

```bash
cd ~/.local/share/chezmoi
git pull --ff-only
./bootstrap.sh <profile>
exec zsh -l
```

Examples:

```bash
./bootstrap.sh local-dev
./bootstrap.sh remote-client
./bootstrap.sh dev-host
```

After a significant update:

```bash
mise doctor
mise current
chezmoi diff
```

## Add or remove software

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

Responsibilities:

- `mise/config.toml` — shared bootstrap state.
- `mise/config.macos.toml` / `mise/config.linux.toml` — platform base packages.
- `mise/config.macos-local-dev.toml` / `mise/config.macos-remote-client.toml` / `mise/config.linux-dev-host.toml` — profile additions.
- `mise/runtime.toml` — shared runtime settings projected to `~/.config/mise/config.toml` by chezmoi.
- `mise/runtime.macos-local-dev.toml` — default runtime toolset for a full local-development Mac.

Declare only software that is intentionally part of the managed environment. Do not import raw package-manager snapshots.

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

Removing a declaration stops future management of that package. Operating-system package removal is intentionally explicit; do not blindly run broad cleanup/autoremove commands after changing this repository.

## Shell layout

The managed Zsh configuration is intentionally small and domain-separated:

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

`~/.config/zsh/local.zsh` is reserved for machine-local shell configuration and is not part of the public source state.

Do not recreate legacy layers such as platform/role dispatch files unless there is a concrete need. Platform and capability differences belong primarily in bootstrap/mise profiles; shell configuration should stay portable.

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

A named tmux session is optional:

```bash
remote <user>@<host> backend
```

Detach without stopping work with:

```text
Ctrl-b d
```

Run the same `remote` command later to reattach.

SSH keys, hostnames, IP addresses, Tailscale identity, and credentials are intentionally not stored in this repository.

## Managed stack

Base macOS:

- Homebrew
- Git
- GitHub CLI (`gh`)
- jq
- fzf
- ripgrep
- zoxide

Base Linux:

- Zsh
- Git
- curl
- jq
- fzf
- ripgrep
- zoxide

Zsh plugins are managed as repositories by mise rather than duplicated Homebrew formulae:

- zsh-autocomplete
- zsh-autosuggestions
- zsh-syntax-highlighting

`local-dev` additionally provides development-oriented packages and global Node/Python defaults. `remote-client` and `dev-host` remain capability-specific rather than inheriting every workstation tool.

## Edit dotfiles

```bash
cd ~/.local/share/chezmoi
git status
git diff

# edit source files
chezmoi diff
chezmoi apply
exec zsh -l
```

Before committing, check that no machine-specific or private material entered the repository.

## Privacy and public-repository rules

Never commit:

- credentials, API tokens, private keys, certificates, or `.env` secrets;
- corporate/private registry credentials;
- private hostnames, IP addresses, Tailscale identities, or SSH target topology specific to a real environment;
- machine-local Git identity/credential configuration;
- `~/.config/mise/conf.d/90-machine-local.toml` or equivalent machine-specific runtime constraints;
- raw Homebrew/apt package snapshots, caches, or generated state.

Machine-local exceptions belong outside the portable repository, primarily in:

```text
~/.config/zsh/local.zsh
~/.config/mise/conf.d/90-machine-local.toml
```

The repository should describe **policy and reusable defaults**, not one person's current machine state.

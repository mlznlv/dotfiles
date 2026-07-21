# Runtimes and versioned tools

mise is the only runtime/version manager. NVM and pyenv are not part of the stack.

## Configuration layers

Bootstrap projects portable mise fragments into global `conf.d`:

```text
10-dotfiles-platform.toml   platform-wide versioned CLI tools
20-dotfiles-profile.toml    profile runtime defaults
90-machine-local.toml       private machine constraints
project config              repository-specific versions
```

On Linux, the platform layer provides Starship globally. On macOS, Starship is owned by Homebrew instead, so no duplicate mise installation is declared.

## local-dev defaults

A full development Mac has global defaults for CLIs, MCP servers, Docker-related scripts, and ad-hoc commands:

```toml
[tools]
node = "lts"
python = "3.14"
```

Check active runtimes:

```bash
mise current
node --version
npm --version
python --version
```

## Project overrides

Projects can select runtimes with supported files such as:

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
```

`.nvmrc` is read for compatibility; NVM itself is not required. `package.json.engines` is a compatibility contract, not an automatic runtime selector.

## Machine-local overrides

Machine-specific constraints belong only in:

```text
~/.config/mise/conf.d/90-machine-local.toml
```

Example:

```toml
[tools]
node = "22"
```

Temporary one-shell override:

```bash
mise shell node@20
```

## Diagnostics

```bash
mise config ls
mise current
mise doctor
ls -la .nvmrc .python-version mise.toml .tool-versions 2>/dev/null
```

`mise config ls` is the quickest way to verify which global, environment, and project files are actually active.

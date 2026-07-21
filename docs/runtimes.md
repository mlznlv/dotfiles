# Runtimes

mise is the only runtime/version manager. NVM and pyenv are not part of the target stack.

## local-dev defaults

A full development Mac has global defaults so CLIs, MCP servers, Docker-related scripts, and ad-hoc commands work outside project directories:

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

`.nvmrc` is read for compatibility; NVM itself is not required.

`package.json.engines` is treated as a compatibility contract, not as an automatic runtime selector.

## Machine-local overrides

Machine-specific constraints belong outside Git:

```text
~/.config/mise/conf.d/90-machine-local.toml
```

Example:

```toml
[tools]
node = "22"
```

Precedence:

```text
profile default -> machine-local override -> project config
```

Temporary one-shell override:

```bash
mise shell node@20
```

## Diagnostics

```bash
type -a mise
mise doctor
mise current
ls -la .nvmrc .python-version mise.toml .tool-versions 2>/dev/null
```

`mise doctor` may report `shims_on_path: no` when activation is handled by `mise activate zsh`; shims do not need to be the primary activation mechanism.

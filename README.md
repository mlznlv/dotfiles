# zshenv

**Declarative, safe, and portable Zsh configuration.**

`zshenv` turns a small YAML file into a predictable Zsh environment, without taking ownership of your personal shell code.

It is designed for developers who use multiple machines, keep an existing `.zshrc`, or want the same terminal behavior on macOS and Linux without adopting a shell framework or package manager.

> Development repository: the project will move to a dedicated public repository before the first release.

## Why zshenv

A typical `.zshrc` mixes defaults, personal aliases, tool hooks, prompt setup, machine-specific paths, and generated state in one executable file. That makes migration and reuse difficult.

`zshenv` separates those concerns:

```text
shell.yaml   defines composition
generated/   is managed and replaced atomically
custom/      belongs to the user and is never rewritten
~/.zshrc     is a stable loader
```

The result is explicit, reviewable, and reversible.

## Core guarantees

- Existing `.zshrc` files are never overwritten silently.
- Migration requires an explicit `--adopt` or `--replace` decision.
- Existing configuration is backed up before activation.
- Generated Zsh is validated before it becomes active.
- Only managed generated state is replaced.
- Custom files are never modified or deleted.
- Missing optional tools do not break shell startup.
- YAML paths cannot execute commands, expand variables, load URLs, or use globs.

## Requirements

For users:

```text
Zsh 5.8+
macOS or Linux
arm64 or amd64
one zshenv binary
```

Optional integrations activate only when installed: Starship, fzf, zoxide, mise, Docker, kubectl, tmux, and SSH.

For contributors: Go 1.23+.

## Install from source

```bash
git clone https://github.com/mlznlv/dotfiles.git
cd dotfiles
git switch feature/declarative-zsh

go build -trimpath -o zshenv .
install -m 0755 zshenv ~/.local/bin/zshenv
```

Initialize a clean machine:

```bash
zshenv init
exec zsh -l
```

When an unmanaged `~/.zshrc` exists, `init` reports likely conflicts and changes nothing:

```bash
zshenv init --adopt    # back up and keep loading the existing configuration
zshenv init --replace  # back up and activate only the managed configuration
```

Conflict detection is advisory. `zshenv` reports likely overlaps but does not rewrite or resolve user code.

## Configuration

The source of truth is:

```text
~/.config/zsh/shell.yaml
```

Default configuration:

```yaml
version: 1

shell:
  core: {}
  paths: {}
  completion: {}
  integrations: {}
  remote: {}
  aliases: {}
  prompt:
    engine: starship
  ux: {}
```

Each segment has four operations.

Use the built-in implementation:

```yaml
shell:
  aliases: {}
```

Replace it completely:

```yaml
shell:
  aliases:
    path: ~/.config/zsh/custom/aliases.zsh
```

Extend it with user-owned code:

```yaml
shell:
  aliases:
    extend:
      path: ~/.config/zsh/custom/aliases.zsh
```

Disable it:

```yaml
shell:
  aliases: false
```

Use a custom Starship configuration:

```yaml
shell:
  prompt:
    engine: starship
    path: ~/.config/starship/theme.toml
```

Accepted paths must be absolute or begin with `~/`. URLs, environment variables, command substitution, backticks, and glob syntax are rejected.

## Workflow

Edit YAML, inspect the result, validate it, then apply it:

```bash
zshenv diff
zshenv check
zshenv apply
exec zsh -l
```

Available commands:

```text
zshenv init [--adopt | --replace]
zshenv check
zshenv diff
zshenv apply
zshenv status
```

Use another configuration file:

```bash
zshenv --config /absolute/path/shell.yaml check
```

`apply` renders into a staging directory, validates every generated Zsh file, and atomically activates the new state. A failed render or validation leaves the current generated configuration intact.

## Built-in environment

The default configuration provides:

- history and safe Zsh options;
- user and Docker CLI paths;
- native completion and keybindings;
- Docker completion when available;
- optional fzf, zoxide, mise, autosuggestions, and syntax-highlighting hooks;
- shell and Git aliases;
- Starship with a native Zsh fallback;
- `remote <host> [session]` for SSH plus persistent tmux sessions.

The built-ins are defaults, not a framework. Any segment can be extended, replaced, or disabled.

## Scope

`zshenv` is a shell environment manager. It intentionally does not:

- install packages;
- manage operating-system configuration;
- replace a dotfiles manager;
- download or execute remote configuration;
- provide runtime plugins;
- automatically resolve conflicts in arbitrary Zsh code.

Use Homebrew, apt, mise, Ansible, chezmoi, or another appropriate tool for those responsibilities.

## Project status

The current target is `v0.1.0`:

- stabilize YAML v1;
- complete migration and failure-path tests;
- publish standalone macOS and Linux binaries;
- provide checksums and release notes;
- validate the workflow against real existing `.zshrc` configurations.

See [ROADMAP.md](ROADMAP.md) for planned work and explicit non-goals.

## Contributing

```bash
git clone https://github.com/mlznlv/dotfiles.git
cd dotfiles
git switch feature/declarative-zsh
make check
```

Contributions should preserve the ownership model, atomic activation, and YAML compatibility contract. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/architecture.md](docs/architecture.md).

## Security

`zshenv` modifies shell startup state, so filesystem ownership and failure behavior are part of the security model. Report vulnerabilities privately according to [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).

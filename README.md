# zshenv

Declarative Zsh configuration with safe migration of an existing `~/.zshrc`.

The current repository is a development location. The project will move to a dedicated public repository before its first release.

## Requirements

For users:

- Zsh 5.8 or newer;
- the `zshenv` binary;
- macOS or Linux on arm64 or amd64.

Starship, fzf, zoxide, mise, Docker, kubectl, tmux, and SSH are optional. Missing optional commands are skipped without breaking shell startup. A custom Starship configuration requires Starship.

For contributors: Go 1.23 or newer.

## Build and install

```bash
go build -trimpath -o zshenv .
install -m 0755 zshenv ~/.local/bin/zshenv
zshenv init
exec zsh -l
```

When an unmanaged `~/.zshrc` exists, `init` reports likely conflicts and changes nothing. Continue explicitly:

```bash
zshenv init --adopt    # back up and load the existing config
zshenv init --replace  # back up, then use only managed config
```

Conflicts are advisory and are never resolved automatically.

## Configuration

Edit `~/.config/zsh/shell.yaml`:

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

A missing segment or `{}` uses the built-in implementation.

Replace a segment:

```yaml
shell:
  aliases:
    path: ~/.config/zsh/custom/aliases.zsh
```

Extend a built-in segment:

```yaml
shell:
  aliases:
    extend:
      path: ~/.config/zsh/custom/aliases.zsh
```

Disable a segment:

```yaml
shell:
  remote: false
```

Use a custom Starship configuration:

```yaml
shell:
  prompt:
    engine: starship
    path: ~/.config/starship/theme.toml
```

Only absolute paths and paths beginning with `~/` are accepted. URLs, variables, command substitution, and glob syntax are rejected.

## Commands

```bash
zshenv check
zshenv diff
zshenv apply
zshenv status
```

`apply` renders and validates a staging directory, then atomically replaces only `~/.config/zsh/generated/`. Files under `custom/` and files referenced from YAML are never modified or deleted.

## Built-in coverage

- history and Zsh options;
- user and Docker CLI paths;
- native and Docker completion plus keybindings;
- optional tool integrations, including mise;
- `remote <host> [session]` for SSH plus tmux;
- shell and Git aliases;
- Starship with native Zsh fallback;
- fzf, zoxide, autosuggestions, and syntax highlighting.

## Development

```bash
go vet ./...
go test -race ./...
go build ./...
```

CI tests Linux and macOS, performs cross-builds for four release targets, and runs the repository secret scan. Tagged builds produce release archives and checksums. See `SECURITY.md` before reporting a vulnerability or suspected credential exposure.

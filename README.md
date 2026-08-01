# zshenv

Portable Zsh configuration with declarative composition and safe migration of an existing `~/.zshrc`.

## Requirements

Required:

- Zsh
- Git
- chezmoi
- Python 3 with PyYAML
- Starship for the default prompt

Optional integrations activate only when installed: `fzf`, `zoxide`, `mise`, Docker, kubectl, tmux, and SSH.

### macOS example

```bash
brew install zsh git chezmoi python pyyaml starship fzf zoxide mise tmux
```

### Ubuntu/Debian example

```bash
sudo apt-get update
sudo apt-get install -y zsh git python3 python3-yaml fzf tmux ripgrep
```

Install `chezmoi`, Starship, zoxide, and mise using their official instructions when distribution packages are unavailable or outdated.

## Install

```bash
git clone https://github.com/mlznlv/dotfiles.git ~/.local/share/zshenv
cd ~/.local/share/zshenv
python3 ./zshenv init
```

If an unmanaged `~/.zshrc` exists, `init` reports likely conflicts and changes nothing. Choose explicitly:

```bash
python3 ./zshenv init --adopt    # preserve and load the existing configuration
python3 ./zshenv init --replace  # preserve only a timestamped backup
```

Then restart the shell:

```bash
exec zsh -l
```

## Configuration

Edit:

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
  runtimes: {}
  remote: {}
  aliases: {}
  prompt:
    engine: starship
  ux: {}
```

A missing segment or `{}` uses the built-in configuration.

Replace a segment:

```yaml
shell:
  aliases:
    path: ~/.config/zsh/custom/aliases.zsh
```

Extend a segment after the built-in configuration:

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

Starship presets can generate that file, for example:

```bash
mkdir -p ~/.config/starship
starship preset pure-preset -o ~/.config/starship/theme.toml
```

## Commands

```bash
python3 ./zshenv check   # validate YAML, paths, dependencies, and Zsh syntax
python3 ./zshenv diff    # show generated changes
python3 ./zshenv apply   # atomically apply the YAML configuration
python3 ./zshenv status  # show active paths and managed state
```

`apply` replaces only `~/.config/zsh/generated/`. Files referenced by YAML and files under `~/.config/zsh/custom/` are never modified or deleted.

## Built-in coverage

The defaults preserve the current repository behavior:

- history and Zsh options;
- user and Docker paths;
- native completion, Docker completion, and keybindings;
- mise activation;
- `remote <host> [session]` for SSH plus tmux;
- shell and Git aliases;
- Starship prompt selection and module policy;
- fzf, zoxide, autosuggestions, and syntax highlighting.

Missing optional tools are skipped without breaking shell startup.

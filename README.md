# zshenv

Portable Zsh configuration with safe migration of an existing `~/.zshrc`.

## Requirements

Required: Zsh, Git, chezmoi, Python 3, PyYAML.

The default prompt uses Starship when available and falls back to native Zsh. Optional integrations activate only when their commands exist.

macOS example:

```bash
brew install zsh git chezmoi python pyyaml starship fzf zoxide tmux
```

Ubuntu/Debian example:

```bash
sudo apt-get update
sudo apt-get install -y zsh git python3 python3-yaml fzf tmux
```

Install missing tools using their official instructions. This repository does not install or update packages.

## Install

```bash
git clone https://github.com/mlznlv/dotfiles.git ~/.local/share/zshenv
cd ~/.local/share/zshenv
python3 ./zshenv init
exec zsh -l
```

When an unmanaged `~/.zshrc` exists, `init` reports likely conflicts and changes nothing. Continue explicitly:

```bash
python3 ./zshenv init --adopt    # back up and load the existing config
python3 ./zshenv init --replace  # back up, then use only managed config
```

Conflicts are reported, never resolved automatically.

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

A missing segment or `{}` uses the built-in configuration.

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

Use a custom Starship config:

```yaml
shell:
  prompt:
    engine: starship
    path: ~/.config/starship/theme.toml
```

Create one from an official preset:

```bash
mkdir -p ~/.config/starship
starship preset pure-preset -o ~/.config/starship/theme.toml
```

## Commands

```bash
python3 ./zshenv check
python3 ./zshenv diff
python3 ./zshenv apply
python3 ./zshenv status
```

`apply` atomically replaces only `~/.config/zsh/generated/`. Custom files and files referenced by YAML are never changed or deleted.

## Built-in coverage

Defaults preserve the current shell behavior:

- history and Zsh options;
- user and Docker paths;
- native and Docker completion plus keybindings;
- optional tool integrations, including mise;
- `remote <host> [session]` for SSH plus tmux;
- shell and Git aliases;
- Starship prompt policy with native fallback;
- fzf, zoxide, autosuggestions, and syntax highlighting.

Missing optional tools are skipped without breaking shell startup.

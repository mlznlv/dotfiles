# Shell and terminal

## Zsh UX

The interactive shell stack is:

```text
Zsh
├── native completion
├── fzf
├── zoxide
├── zsh-autosuggestions
├── zsh-syntax-highlighting
└── Starship
```

Expected keys:

```text
Up/Down   command history
Ctrl-R    fuzzy history
Ctrl-T    fuzzy file search
Alt-C     fuzzy directory search
Tab       completion
Shift-Tab previous completion item
```

`zsh-autocomplete`, Oh My Zsh, and Powerlevel10k are not part of the target stack.

## Starship presets

Default preset:

```text
plain-text-symbols
```

Show or change the selected preset:

```bash
prompt-preset
prompt-preset pure-preset
prompt-preset default
exec zsh -l
```

`plain-text` is accepted as an alias for `plain-text-symbols`.

Preset selection is machine-local:

```text
~/.config/starship/preset
```

## Starship modules

These modules default to disabled to avoid noisy or sensitive context in the prompt:

```text
package
aws
gcloud
```

Manage them per machine:

```bash
prompt-module status
prompt-module enable aws
prompt-module disable aws
prompt-module enable gcloud
prompt-module enable package
prompt-module reset
exec zsh -l
```

State is stored in:

```text
~/.config/starship/modules
```

## Ghostty

Ghostty is the macOS terminal UI layer. It owns terminal rendering, windows/tabs/splits, theme, spacing, cursor behavior, clipboard behavior, and terminal-level keybindings.

It does not own Zsh, Starship, mise, SSH, or tmux.

The macOS base Brewfile installs Ghostty. Chezmoi manages:

```text
~/.config/ghostty/config.ghostty
```

The committed configuration intentionally stays small:

- separate Catppuccin light/dark themes following system appearance;
- Ghostty's bundled default font;
- modest balanced window padding;
- a non-blinking block cursor outside shell-controlled contexts.

Tabs, splits, and most keybindings use Ghostty defaults. Automatic Zsh shell integration remains enabled.

Reload configuration on macOS:

```text
Cmd-Shift-,
```

Useful diagnostics:

```bash
ghostty +show-config
ghostty +show-config --default --docs
ghostty +list-themes
```

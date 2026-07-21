# Shell and terminal

## Zsh UX

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
Up/Down    command history
Ctrl-R     fuzzy history
Ctrl-T     fuzzy file search
Alt-C      fuzzy directory search
Tab        completion
Shift-Tab  previous completion item
```

The two Zsh plugin repositories are owned only by `mise bootstrap.repos`. Missing plugins produce a startup warning instead of silently changing shell behavior. `zsh-autocomplete`, Oh My Zsh, and Powerlevel10k are not part of the stack.

## Starship presets

Default preset:

```text
plain-text-symbols
```

Manage the machine-local selection:

```bash
prompt-preset
prompt-preset pure-preset
prompt-preset default
exec zsh -l
```

`plain-text` is an alias for `plain-text-symbols`. Selection is stored in `~/.config/starship/preset`; generated configs live under the Starship cache and are not committed.

If selected/default preset generation or Starship initialization fails, the shell falls back to a minimal native Zsh prompt rather than an uncontrolled Starship config.

## Starship modules

These modules default to disabled:

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

State is stored in `~/.config/starship/modules` and stays outside Git.

## Ghostty

Ghostty is the macOS terminal UI layer; Zsh/Starship/mise/SSH/tmux remain independent.

Chezmoi manages `~/.config/ghostty/config.ghostty` on macOS only. Portable defaults are intentionally small:

```text
dark theme   Catppuccin Mocha
light theme  Catppuccin Latte
font size    14.5 pt
padding      balanced, 8 x 6
cursor       non-blinking block
```

Font family, tabs, splits, and most keybindings use Ghostty defaults. Automatic Zsh shell integration remains enabled.

Useful commands:

```bash
ghostty +show-config
ghostty +list-themes
```

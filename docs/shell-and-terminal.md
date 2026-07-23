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

Zsh history is stored at `~/.zsh_history` with mode `0600`. Prefix a one-off command with a space to keep it out of history (`HIST_IGNORE_SPACE`). This is a convenience, not a substitute for proper secret handling.

## Vim

Vim is the lightweight terminal/SSH fallback editor and is installed explicitly on macOS and Ubuntu/Debian instead of relying on an OS-bundled version.

Chezmoi manages `~/.vimrc` with syntax highlighting, filetype plugins, and indentation enabled. The portable language set covers:

```text
Bash / sh
JavaScript
TypeScript / TSX
Python
```

No Vim plugin manager or IDE layer is part of the base environment.

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

## Starship context modules

Portable policy hides noisy or infrastructure-specific context regardless of the selected official preset:

```text
package
aws
gcloud
azure
kubernetes
openstack
docker_context
localip
nats
pulumi
terraform
netns
container
singularity
```

Enable only what is useful on a specific machine:

```bash
prompt-module status
prompt-module enable aws
prompt-module disable aws
prompt-module enable kubernetes
prompt-module reset
exec zsh -l
```

State is stored in `~/.config/starship/modules` and stays outside Git. Generated preset configs are validated by Starship before activation.

## Ghostty

Ghostty is the macOS terminal UI layer; Zsh/Starship/mise/SSH/tmux remain independent.

The `local-dev` and `remote-client` Brewfiles install Ghostty. The minimal macOS `base` profile remains CLI-only. Chezmoi manages `~/.config/ghostty/config.ghostty` on macOS so the same visual policy is ready whenever Ghostty is installed.

Portable defaults are intentionally small:

```text
dark theme   Catppuccin Mocha
light theme  Catppuccin Latte
font family  JetBrains Mono
font size    15.5 pt
padding      balanced, 8 x 6
cursor       non-blinking block
```

Ghostty's bundled JetBrains Mono is selected explicitly, so no separate font package is required. Tabs, splits, and most keybindings use Ghostty defaults. Automatic Zsh shell integration remains enabled.

Useful commands:

```bash
ghostty +show-config
ghostty +list-themes
```

# List modules

[Command guide](../README.md) / Modules / List

Discover modules available for the current machine or another supported target.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles module list [--platform macos|debian | --all]
~~~

| Option | Meaning |
| --- | --- |
| no option | Detect the current platform and show compatible modules |
| `--platform macos` | Show modules compatible with macOS |
| `--platform debian` | Show modules compatible with Debian-family Linux |
| `--all` | Show every module without platform filtering |

Do not combine `--platform` and `--all`.

## Examples

~~~console
./bin/dotfiles module list
./bin/dotfiles module list --platform debian
./bin/dotfiles module list --all
~~~

The production catalog prints the three released shell modules as tab-separated
rows in identifier order:

~~~text
prompt.starship    Starship    Cross-shell prompt renderer
shell.zsh          Zsh         Interactive Zsh shell experience
shell.zsh.autosuggestions    Zsh autosuggestions    Interactive command suggestions for Zsh
~~~

## Exit codes

- `0` — listing completed, including an empty result.
- `2` — the options are invalid.
- `3` — platform detection or catalog validation failed.
- `4` — chezmoi is unavailable.

Next: [inspect a module](show.md) or return to the
[command guide](../README.md).

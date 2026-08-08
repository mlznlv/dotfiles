# List profiles

[Command guide](../README.md) / Profiles / List

Discover curated profiles for the current machine or another supported target.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles profile list [--platform macos|debian | --all]
~~~

| Option | Meaning |
| --- | --- |
| no option | Detect the current platform and show compatible profiles |
| `--platform macos` | Show profiles compatible with macOS |
| `--platform debian` | Show profiles compatible with Debian-family Linux |
| `--all` | Show every profile without platform filtering |

Do not combine `--platform` and `--all`.

## Examples

~~~console
./bin/dotfiles profile list
./bin/dotfiles profile list --platform macos
./bin/dotfiles profile list --all
~~~

The production catalog is currently empty, so these commands succeed without
printing rows. A populated catalog prints tab-separated rows in identifier
order:

~~~text
shell.minimal    Minimal shell    Zsh, autosuggestions, and Starship
~~~

## Exit codes

- `0` — listing completed, including an empty result.
- `2` — the options are invalid.
- `3` — platform detection or catalog validation failed.
- `4` — chezmoi is unavailable.

Next: [inspect a profile](show.md) or return to the
[command guide](../README.md).

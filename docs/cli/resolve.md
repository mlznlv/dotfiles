# Resolve a composition

[Command guide](README.md) / Resolve

Preview the final module set for a profile or a custom selection.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles resolve --profile <profile-id> [--add <id,id>] [--platform macos|debian]
dotfiles resolve --modules <id,id> [--add <id,id>] [--platform macos|debian]
~~~

| Option | Meaning |
| --- | --- |
| `--profile <profile-id>` | Start from one curated profile |
| `--modules <id,id>` | Start from a comma-separated custom module set |
| `--add <id,id>` | Add modules to either base selection |
| `--platform <value>` | Override local detection with `macos` or `debian` |

Choose exactly one of `--profile` and `--modules`.

## Examples

Start from a profile:

~~~console
./bin/dotfiles resolve --profile shell.minimal --platform debian
~~~

Build a custom composition:

~~~console
./bin/dotfiles resolve \
    --modules shell.zsh.autosuggestions,prompt.starship \
    --platform macos
~~~

Add a module to a profile:

~~~console
./bin/dotfiles resolve \
    --profile shell.minimal \
    --add terminal.ghostty \
    --platform macos
~~~

These identifiers are planned and remain unavailable while the production
catalog is empty.

## What it returns

The command validates the catalog, expands dependencies, removes duplicates,
checks platform support, and rejects conflicts. Dependencies appear before the
modules that need them, one identifier per line:

~~~text
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

The result is deterministic for the same catalog and options. It is not saved,
and no provider or home-state operation runs.

## Common failures

- An unknown module or profile.
- A module that does not support the selected platform.
- Conflicting modules or two modules in one exclusive group.
- A missing dependency or dependency cycle.
- Both or neither base-selection options were supplied.

The command stops without printing a partial result.

## Exit codes

- `0` — the composition was resolved.
- `2` — the command syntax or base selection is invalid.
- `3` — platform, catalog, identifier, dependency, or conflict validation failed.
- `4` — chezmoi is unavailable.

See the [user guide](../user-guide/README.md) for the complete composition
workflow, or return to the [command guide](README.md).

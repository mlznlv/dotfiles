# Resolve a composition

[Command guide](README.md) / Resolve

Preview the final module set for an explicit or saved local selection.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles resolve [--profile <profile-id> | --modules <id,id>]
                 [--add <id,id>] [--platform macos|debian]
~~~

| Option | Meaning |
| --- | --- |
| `--profile <profile-id>` | Start from one curated profile |
| `--modules <id,id>` | Start from a comma-separated custom module set |
| `--add <id,id>` | Add modules to the explicit or loaded saved base for this invocation only |
| `--platform <value>` | Override local detection with `macos` or `debian` |

`--profile` and `--modules` are mutually exclusive. When either is supplied,
the explicit base and invocation `--add` are the complete intent and local
state is not opened or validated. When both are omitted, the command strictly
loads the standard schema-1 active selection. An invocation `--add` then
follows saved additions in memory and is not persisted.

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

The shell identifiers are released. `terminal.ghostty` remains a planned
example and is not available.

Use previously saved intent:

~~~console
./bin/dotfiles resolve --platform debian
~~~

## What it returns

The command validates the catalog, expands dependencies, removes duplicates,
checks platform support, and rejects conflicts. Dependencies appear before the
modules that need them, one identifier per line:

~~~text
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

The result is deterministic for the same catalog and effective intent. Saved
intent is freshly validated against the current catalog and platform. The
command does not rewrite state, and no provider, prerequisite presence check,
or home-state operation runs.

## Common failures

- An unknown module or profile.
- A module that does not support the selected platform.
- Conflicting modules or two modules in one exclusive group.
- A missing dependency or dependency cycle.
- Both explicit base options were supplied.
- No explicit base was supplied and local selection is missing, unsafe,
  non-canonical, malformed, or no longer valid for the current catalog and
  platform.

The command stops without printing a partial result.

## Exit codes

- `0` — the composition was resolved.
- `2` — the command syntax or base selection is invalid.
- `3` — local state, platform, catalog, identifier, dependency, or conflict validation failed.
- `4` — chezmoi is unavailable.

See [config inspect](config/inspect.md) for the effective intent around a fresh
resolution, the [user guide](../user-guide/README.md) for the complete
workflow, or return to the [command guide](README.md).

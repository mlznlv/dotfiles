# Inspect effective local selection

[Command guide](../README.md) / Config inspect

Show the exact invocation-effective selection intent and its freshly resolved
module order without checking software or managed home state.

Available · Read-only · Chezmoi required for catalog validation.

## Usage

~~~text
dotfiles config inspect [--profile <profile-id> | --modules <id,id>]
                        [--add <id,id>] [--platform macos|debian]
~~~

The options follow the same once-only parsing and precedence as `resolve`,
`prerequisite check`, `plan`, and `apply`, except that `--yes` is not accepted.
`--profile` and `--modules` are mutually exclusive. Without `--platform`, the
command detects macOS or supported Debian-family Linux.

## Precedence and output

An explicit profile or module base uses only invocation intent and never
derives, opens, validates, merges, locks, or rewrites local state. With no
explicit base, the command strictly loads the standard schema-1 selection. An
invocation `--add` then follows saved additions in memory for this inspection
only.

For a saved profile, successful output is exactly:

~~~text
Selection source: local
Base: shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship
~~~

An explicit base uses `Selection source: invocation`. A saved base plus a
non-empty invocation `--add` uses
`Selection source: local plus invocation additions`. The `Base:` line contains
only the profile identifier or original ordered module list. The additions
line contains the complete ordered effective additions or `none`. Resolved
identifiers appear once each in deterministic dependency order.

The summary is assembled only after syntax, platform, state when required,
catalog, identifiers, duplicates, dependencies, cycles, conflicts, exclusive
groups, platform support, and rendered-target ownership all validate. A
failure prints no partial summary.

## Effects and privacy

Inspect does not save or normalize intent, create state, inspect the writer
lock, check prerequisites or artifacts, discover applications, render, plan,
compare or apply home targets, create cache, invoke providers or installers,
use the network, or request privilege. It leaves selection bytes, identity,
mode, ownership, timestamps, and unrelated files unchanged.

Diagnostics use catalog identifiers and, when necessary, only the stable
`$XDG_CONFIG_HOME` or `$HOME/.config` origin token. They never print state
contents, raw private roots, usernames, hostnames, device identity, source or
target paths, private infrastructure, or secrets.

## Examples

Inspect saved intent:

~~~console
./bin/dotfiles config inspect --platform debian
~~~

Inspect an explicit composition without consulting saved state:

~~~console
./bin/dotfiles config inspect \
    --modules prompt.starship,shell.zsh \
    --add shell.zsh.autosuggestions \
    --platform macos
~~~

Temporarily add a module after saved additions:

~~~console
./bin/dotfiles config inspect --add prompt.starship --platform debian
~~~

## Exit codes

- `0` — inspection completed.
- `2` — command syntax, repetition, value, or option combination is invalid.
- `3` — platform, required local state, catalog, identifier, composition, or
  ownership validation failed, including observed state drift.
- `4` — the required parser, catalog component, or safe read capability is
  unavailable.
- `129`, `130`, `143` — HUP, INT, or TERM interruption.

Errors go to standard error. The complete successful summary goes to standard
output.

Next: [diagnose saved selection](doctor.md), [build a plan](../plan.md), or
return to the [command guide](../README.md).

[Command guide](../README.md) / Config set

# Save a local selection

Validate a profile or explicit module composition and save that exact intent
as the local active selection.

**Available · Mutates only CLI-owned local state · Chezmoi required for catalog validation**

## Usage

~~~text
dotfiles config set (--profile <profile-id> | --modules <id,id>)
                    [--add <id,id>] [--platform macos|debian]
~~~

Exactly one of `--profile` and `--modules` is required. `--add` preserves its
requested order. Without `--platform`, the command detects macOS or a supported
Debian-family Linux system.

There is no prompt, approval flag, destination override, repair, reset, or
apply option.

## Examples

Save the released minimal shell profile for Debian:

~~~console
$ ./bin/dotfiles config set --profile shell.minimal --platform debian
Proposed local selection:
Base: profile shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship
Local selection saved.
Managed home configuration: unchanged.
~~~

Save an ordered explicit composition:

~~~console
./bin/dotfiles config set \
    --modules prompt.starship,shell.zsh \
    --add shell.zsh.autosuggestions \
    --platform macos
~~~

The saved TOML contains the requested profile or modules and additions. It
does not contain dependency expansion, platform, prerequisite results, plans,
paths, timestamps, or machine identity.

## Local state and effects

The state file is exactly one of:

- `$XDG_CONFIG_HOME/dotfiles/active-selection.toml` when
  `XDG_CONFIG_HOME` is non-empty.
- `$HOME/.config/dotfiles/active-selection.toml` when `XDG_CONFIG_HOME` is
  unset or empty.

A non-empty invalid `XDG_CONFIG_HOME` fails closed; the command does not fall
back to HOME. The dedicated directory and state file use modes `0700` and
`0600`. Existing paths must be real, current-user-owned, outside the repository,
and free of unsafe links or permission bits.

The command validates the complete schema-1 catalog and resolved composition,
including dependencies, conflicts, platform support, exclusive groups, and
rendered-target ownership. It does not check prerequisites or artifacts,
render configuration, inspect managed targets, plan, apply, install software,
use the network, or invoke a provider.

If the existing canonical file already has identical bytes, the command
preserves its bytes and metadata and reports:

~~~text
Local selection unchanged.
Managed home configuration: unchanged.
~~~

## Recovery and concurrency

An existing unsafe, malformed, non-canonical, or catalog-invalid state file is
never overwritten, normalized, deleted, or chmodded. Preserve or move it aside,
or repair its path and permissions, before rerunning `config set`.

An adjacent directory lock serializes cooperating `config set` processes. A
second writer fails immediately. The command never steals or removes a stale
lock; first confirm no writer is active before removing that lock manually.

Writes use a private same-directory temporary file, data and directory flushes,
and one atomic rename. Pre-rename drift that is observed preserves the external
file. A failure after rename returns an uncertain result and tells you not to
rely on the selection. `config doctor` is planned and is not yet an available
command, so preserve the file and investigate its path and exact canonical
bytes before retrying.

The lock cannot serialize an editor or another non-cooperating process. A
portable rename is not compare-and-swap, so a non-cooperating write in the
final check-to-rename window may be displaced. The CLI still publishes one
complete canonical document; it never merges or publishes partial TOML.

## Exit codes

- `0` — the selection was saved or was already byte-identical.
- `2` — command syntax is invalid.
- `3` — the platform, catalog, composition, path, current state, lock, or
  observed pre-rename state is invalid.
- `4` — a required component or safe filesystem update is unavailable, or a
  post-rename result or durability operation cannot be confirmed.
- `129`, `130`, `143` — handled HUP, INT, or TERM interruption.

Errors go to standard error. Successful proposal and result output goes to
standard output and never includes raw configuration, home, source, or target
paths.

## Current limitation

Saved selection is not consumed by `resolve`, `prerequisite check`, `plan`, or
`apply` yet. Continue passing an explicit `--profile` or `--modules` base to
those commands. Interactive selection, saved-state consumption, inspect, and
doctor remain later [Phase 4](../../roadmap.md#phase-4-configuration-workflow)
increments.

Next: [resolve the same explicit composition](../resolve.md) or return to the
[command guide](../README.md).

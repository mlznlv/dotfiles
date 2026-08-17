# Choose a local selection interactively

[Command guide](../README.md) / Config interactive

List compatible released choices in a terminal, read one exact selection, and
save it only after confirmation when the local state differs.

Available · Requires terminal stdin · Mutates only confirmed CLI-owned local
state · Chezmoi required for catalog validation.

## Usage

~~~text
dotfiles config interactive [--platform macos|debian]
~~~

Only one optional `--platform` is accepted. Without it, the command detects
macOS or a supported Debian-family Linux system. `-h` and `--help` print the
general CLI help without starting the interaction.

Standard input must be a real terminal. Piped, redirected, or closed stdin is
rejected before catalog inventory, prompts, local-state access, locks, or
filesystem creation. Standard output may be redirected. The command does not
reopen `/dev/tty` or accept an answer from an environment variable.

## Interaction

For the released Debian shell profile, a session begins like this:

~~~console
$ ./bin/dotfiles config interactive --platform debian
Available profiles for debian:
  shell.minimal
Available modules for debian:
  prompt.starship
  shell.zsh
  shell.zsh.autosuggestions
Base type (profile or modules):
profile
Profile ID:
shell.minimal
Additional module IDs (comma-separated, empty for none):

Proposed local selection:
Base: profile shell.minimal
Additional modules: none
Resolved modules for debian:
  shell.zsh
  shell.zsh.autosuggestions
  prompt.starship
Save this local selection? Type yes to continue:
yes
Local selection saved.
Managed home configuration: unchanged.
~~~

Choose the exact base type `profile` or `modules`. A profile base then asks only
for `Profile ID:`. A module base instead asks only for `Module IDs (comma-separated):`.
The additions prompt is always shown; an empty line means no additions. Empty
inventory categories display `none` with two leading spaces.

Every line is literal. There are no defaults, numeric menu choices, trimming,
case folding, fuzzy matches, quoting, escape interpretation, shell evaluation,
or reprompt loop. Module lists use exact comma-separated identifiers and
preserve entered order. Invalid or incomplete input stops without mutation.

The command validates the same schema-1 intent, catalog, platform,
dependencies, conflicts, exclusive groups, duplicate rules, and rendered
target ownership as `config set`. Its proposal summary and canonical saved
bytes are shared with that command.

## Confirmation and no-change behavior

If valid current state already has byte-identical canonical intent, the command
does not ask for confirmation or replace the file:

~~~text
Local selection unchanged.
Managed home configuration: unchanged.
~~~

Otherwise, only the exact lowercase line `yes` authorizes saving. Every other
answer, including whitespace or case variations, an empty line, and EOF,
cancels successfully:

~~~text
Cancelled. Local selection was not changed.
Managed home configuration: unchanged.
~~~

Cancellation preserves existing state byte-for-byte, including its identity
and mode, and creates no standard configuration path when state is absent.
Unsafe, malformed, non-canonical, or catalog-invalid current state fails closed
before confirmation and is never overwritten.

After exact confirmation, the command calls the same state writer as `config set`.
That writer freshly validates state, acquires its adjacent lock, detects drift,
and publishes one canonical mode-`0600` document atomically. A concurrent writer
that already saved the same intent produces the unchanged result.

## Effects and safety

The state path, modes, recovery limits, and concurrency behavior are identical
to [config set](set.md). Interactive selection does not check prerequisites,
render, plan, apply, invoke providers or installers, use the network or
privilege, mutate managed home files, or remove omitted configuration.

Saved selection is still not consumed by `resolve`, `prerequisite check`,
`plan`, or `apply`. Continue providing those commands an explicit `--profile`
or `--modules` base. Inspect, doctor, saved-state consumption, and conditional
cache reset are not available.

## Exit codes

- `0` — selection saved, already unchanged, or cancelled.
- `2` — invalid command syntax, non-terminal stdin, or EOF before a complete
  proposal.
- `3` — invalid platform, catalog, entered selection, path, current state,
  lock, or observed pre-rename state.
- `4` — a required component or safe comparison/update is unavailable, or a
  post-rename result or durability operation cannot be confirmed.
- `129`, `130`, `143` — handled HUP, INT, or TERM interruption.

Errors go to standard error. Inventory, prompts, proposal, cancellation, and
successful results go to standard output. Output never includes local-state
contents, private roots, source or target paths, or machine identity.

Next: [use flag-based saving](set.md) or return to the
[command guide](../README.md).

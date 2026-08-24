# Check prerequisites

[Command guide](../README.md) / Prerequisite check

Resolve an explicit or saved composition and report whether its command and `share:`
artifact prerequisites are present. The check is read-only and never installs,
opens, or invokes a prerequisite.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles prerequisite check [--profile <profile-id> | --modules <id,id>]
                            [--add <id,id>] [--platform macos|debian]
~~~

The selection precedence, dependency expansion, invocation-only `--add`, and
platform detection match `dotfiles resolve`. An explicit base bypasses local
state. Without one, the command strictly loads and freshly validates saved
intent before observing current prerequisites.

~~~console
./bin/dotfiles prerequisite check --profile shell.minimal --platform debian
~~~

After saving that selection, the equivalent repeated check is:

~~~console
./bin/dotfiles prerequisite check --platform debian
~~~

## Results

Results follow resolved-module order, then command and artifact declaration
order:

~~~text
present: shell.zsh command zsh
missing: prompt.starship command starship — provide it outside this project
~~~

Artifact results are preceded by an ordered `roots:` line. Explicit roots from
`DOTFILES_SHARE_ROOTS` precede XDG, validated `$HOME/.local/share`, and generic
system roots. Invalid explicit roots fail the check; invalid ambient roots are
reported and ignored. Paths at or below HOME are printed with `$HOME`.

If the composition declares no supported prerequisites, the command prints
`No prerequisites declared.` An application prerequisite stops before any
command or artifact result because application checking is not implemented.

## Exit codes

- `0` — every selected prerequisite is present, or none is declared.
- `2` — invalid command syntax.
- `3` — missing/invalid local selection, invalid catalog/platform/root, or unsafe input.
- `4` — chezmoi/checker dependency unavailable, or an application prerequisite
  was selected.
- `5` — one or more command or artifact prerequisites are missing.

## Safety and recovery

Command discovery inspects executable-file metadata in absolute PATH entries.
Artifact discovery resolves paths and inspects metadata only. Neither check
opens content, executes software, reads shell profiles, queries providers or
the network, writes selection state, or changes the machine. Provide missing
software outside this project, correct invalid local input, and rerun the
observation. A missing saved selection requires `dotfiles config set` or an
explicit base.

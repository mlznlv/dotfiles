# Command guide

Use the CLI to inspect and validate the catalog, preview a module composition,
save local selection intent, or explicitly apply selected home configuration.
Only `apply` mutates managed home targets; `config set` and `config interactive`
change only the CLI-owned local selection file. No command installs software.

Run commands from the repository root with `./bin/dotfiles`.

> [!NOTE]
> The production catalog contains three shell modules and the `shell.minimal`
> profile. Command and artifact prerequisite checks are available; application
> checks remain deferred. Configuration planning and selected apply are
> available. Flag-based and terminal-only interactive local selection are
> available, but selection-consuming commands do not load saved state yet.

## Quick start

~~~console
$ ./bin/dotfiles help
$ ./bin/dotfiles version
dotfiles 0.1.0-dev
$ ./bin/dotfiles catalog validate
catalog valid: 3 modules, 1 profile
~~~

Catalog-backed commands, including planning, require
[chezmoi](https://www.chezmoi.io/). Help and version do not.

## Find the right command

| I want to... | Command | Reference |
| --- | --- | --- |
| See all commands | `dotfiles help` | [help](help.md) |
| Check the CLI version | `dotfiles version` | [version](version.md) |
| Check catalog integrity | `dotfiles catalog validate` | [catalog validate](catalog/validate.md) |
| Discover modules | `dotfiles module list` | [module list](module/list.md) |
| Inspect one module | `dotfiles module show <module-id>` | [module show](module/show.md) |
| Discover profiles | `dotfiles profile list` | [profile list](profile/list.md) |
| Inspect one profile | `dotfiles profile show <profile-id>` | [profile show](profile/show.md) |
| Preview a composition | `dotfiles resolve ...` | [resolve](resolve.md) |
| Save local selection intent | `dotfiles config set ...` | [config set](config/set.md) |
| Choose and save local selection interactively | `dotfiles config interactive ...` | [config interactive](config/interactive.md) |
| Check selected prerequisites | `dotfiles prerequisite check ...` | [prerequisite check](prerequisite/check.md) |
| Build a read-only configuration plan | `dotfiles plan ...` | [plan](plan.md) |
| Recompute, confirm, and apply selected configuration | `dotfiles apply ...` | [apply](apply.md) |

## Typical workflow

1. List available modules or profiles.
2. Inspect an identifier with `show`.
3. Preview the final dependency-expanded composition with `resolve`.
4. Optionally save the same explicit intent with `config set`, or choose it in
   a terminal with `config interactive`.
5. Check its declared command and artifact prerequisites.
6. Preview selected home-target changes with `plan`.
7. Apply the same explicit selection and review the freshly recomputed plan.

~~~console
./bin/dotfiles profile list
./bin/dotfiles profile show shell.minimal
./bin/dotfiles resolve --profile shell.minimal
./bin/dotfiles config set --profile shell.minimal
# Or: ./bin/dotfiles config interactive
./bin/dotfiles prerequisite check --profile shell.minimal
./bin/dotfiles plan --profile shell.minimal
./bin/dotfiles apply --profile shell.minimal
~~~

The example identifier above is released on macOS and Debian-family Linux.

## Save local selection

`config set` validates and saves one profile or ordered module composition as
the CLI-owned schema-1 active selection:

~~~console
./bin/dotfiles config set --profile shell.minimal --platform debian
~~~

For a guided terminal workflow, `config interactive` lists compatible released
identifiers, reads exact literal choices, prints the same proposal, and asks for
exact `yes` only when state differs:

~~~console
./bin/dotfiles config interactive --platform debian
~~~

Both commands change only the standard local selection file and necessary
owned configuration directories. They never check prerequisites, render,
plan, apply, or install software. See [config set](config/set.md) for the flag
form and [config interactive](config/interactive.md) for exact prompts,
cancellation, and terminal requirements.

Current selection-consuming commands still require an explicit `--profile` or
`--modules` base and do not read or combine with saved state. Consumption,
inspect, and doctor remain later focused increments in the
[Phase 4 roadmap](../roadmap.md#phase-4-configuration-workflow).

## Choose a platform

List and resolve commands detect the local platform by default. Use
`--platform` to preview another supported target:

~~~console
./bin/dotfiles module list --platform debian
./bin/dotfiles profile list --platform macos
~~~

Supported values are:

- `macos` for macOS.
- `debian` for Debian-family Linux, including Debian, Ubuntu, and Kali.

Use `--all` with a list command to disable platform filtering. Do not combine
`--all` and `--platform`.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success, including an empty list |
| `2` | Invalid command syntax |
| `3` | Invalid catalog, composition, platform, destination, prerequisite data, ownership, or comparison result |
| `4` | A required component or safe local-state update is unavailable, a post-rename result is uncertain, or application checking is required |
| `5` | A selected prerequisite is missing or a Chezmoi comparison failed |
| `6` | A selected target failed during Chezmoi apply or post-write verification |
| `129`, `130`, `143` | Handled HUP, INT, or TERM interruption |

Errors are written to standard error. Invalid syntax also suggests
`dotfiles help`.

## Common problems

### A list command omits an identifier

Use `--all` to determine whether an identifier exists but does not support the
selected platform.

### `chezmoi is required for catalog commands`

Install chezmoi, confirm `chezmoi --version` works, and retry. Help and version
remain available.

### A module or profile is unknown

Use `module list --all` or `profile list --all` to find released identifiers.
The shell identifiers documented in this guide are released.

### Local selection is unsafe or invalid

Preserve or move the abbreviated active-selection file aside, or repair its
path and permissions, before rerunning a config command. Neither command
repairs, normalizes, or deletes existing state. See [config set](config/set.md)
for lock and uncertain-write recovery.

### Interactive selection refuses input

Run `config interactive` with its standard input attached to a real terminal.
Pipes, redirected or closed stdin, environment answers, and `/dev/tty`
fallback are intentionally unsupported. Redirecting stdout is allowed.

### Planning reports a missing prerequisite

Provide the named command or artifact outside this project, then rerun the
same plan. The CLI will not select or invoke an installer for you.

### Planning rejects HOME or a selected target

Use a literal absolute HOME directory. Replace unsafe selected-path symlinks,
directories, or special files outside this CLI, then rerun the plan. The
planner does not repair or follow them.

### Apply stops after a partial result

The report identifies every changed target as completed, failed, or
unattempted. Completed targets are not rolled back. Correct the failure and
rerun `plan` or `apply`; the new invocation recomputes current state and omits
targets that already converged.

## Safety

The CLI reads catalog data, basic operating-system facts, PATH and artifact
metadata, selected destination targets, and the standard local selection path
only when a config command safely compares or updates it. It does not open or
invoke prerequisites, use the network, request elevated privileges, call
software providers, or display destination or state contents. Apply delegates
only confirmed, freshly verified selected files to Chezmoi and performs no
rollback or removal.

For an end-to-end introduction, read the [user guide](../user-guide/README.md).
Future commands are tracked in the [roadmap](../roadmap.md). Contributors adding
a command must follow the [command documentation guide](command-template.md).

# Command guide

Use the CLI to inspect and validate the catalog, preview a module composition,
or explicitly apply selected home configuration. Only `apply` mutates managed
home targets; no command installs software or saves a selection.

Run commands from the repository root with `./bin/dotfiles`.

> [!NOTE]
> The production catalog contains three shell modules and the `shell.minimal`
> profile. Command and artifact prerequisite checks are available; application
> checks remain deferred. Configuration planning and selected apply are
> available.

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
| Check selected prerequisites | `dotfiles prerequisite check ...` | [prerequisite check](prerequisite/check.md) |
| Build a read-only configuration plan | `dotfiles plan ...` | [plan](plan.md) |
| Recompute, confirm, and apply selected configuration | `dotfiles apply ...` | [apply](apply.md) |

## Typical workflow

1. List available modules or profiles.
2. Inspect an identifier with `show`.
3. Preview the final dependency-expanded composition with `resolve`.
4. Check its declared command and artifact prerequisites.
5. Preview selected home-target changes with `plan`.
6. Apply the same explicit selection and review the freshly recomputed plan.

~~~console
./bin/dotfiles profile list
./bin/dotfiles profile show shell.minimal
./bin/dotfiles resolve --profile shell.minimal
./bin/dotfiles prerequisite check --profile shell.minimal
./bin/dotfiles plan --profile shell.minimal
./bin/dotfiles apply --profile shell.minimal
~~~

The example identifier above is released on macOS and Debian-family Linux.

## Planned local selection workflow

Current selection-consuming commands still require an explicit `--profile` or
`--modules` base. [ADR 0011](../adr/0011-define-local-configuration-workflow.md)
defines later `config set`, `config interactive`, `config inspect`, and
`config doctor` commands for one local active selection. These commands are
not available, so they have no command-reference pages yet.

The planned save commands change only the CLI-owned selection file and never
plan or apply managed home configuration. Explicit selectors remain
independent of local state; omission of an explicit base would be the only way
a later consuming command loads the saved choice. Delivery is split into
focused increments in the
[Phase 4 roadmap](../roadmap.md#phase-4-configuration-workflow), beginning with
flag-based selection now that ADR 0011 is accepted.

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
| `4` | Chezmoi/checker dependency is unavailable, or application checking is required |
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
metadata, and selected destination targets. It does not open or invoke
prerequisites, use the network, request elevated privileges, call software
providers, or display destination contents. Apply delegates only confirmed,
freshly verified selected files to Chezmoi and performs no rollback or removal.

For an end-to-end introduction, read the [user guide](../user-guide/README.md).
Future commands are tracked in the [roadmap](../roadmap.md). Contributors adding
a command must follow the [command documentation guide](command-template.md).

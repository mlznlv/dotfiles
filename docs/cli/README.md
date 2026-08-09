# Command guide

Use the CLI to inspect and validate the catalog or preview a module composition.
Every command available today is read-only: nothing is installed, saved, or
applied.

Run commands from the repository root with `./bin/dotfiles`.

> [!NOTE]
> The production catalog contains three shell modules and the `shell.minimal`
> profile. Provider observation, plan, and apply are not available yet.

## Quick start

~~~console
$ ./bin/dotfiles help
$ ./bin/dotfiles version
dotfiles 0.1.0-dev
$ ./bin/dotfiles catalog validate
catalog valid: 3 modules, 1 profiles
~~~

Catalog commands require [chezmoi](https://www.chezmoi.io/). Help and version do
not.

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

## Planned Phase 3 commands

The following contracts are documented for implementation but are not
available in the current CLI:

| I will be able to... | Planned command | Contract |
| --- | --- | --- |
| Build a read-only provider and home-state plan | `dotfiles plan ...` | [plan](plan.md) |
| Recompute, confirm, and safely apply a plan | `dotfiles apply ...` | [apply](apply.md) |

Neither command may be presented as released until its implementation and tests
merge. Phase 3 will not support saved plans, replay, rollback, or removal.

## Typical workflow

1. List available modules or profiles.
2. Inspect an identifier with `show`.
3. Preview the final dependency-expanded composition with `resolve`.

~~~console
./bin/dotfiles profile list
./bin/dotfiles profile show shell.minimal
./bin/dotfiles resolve --profile shell.minimal
~~~

The example identifier above is released on macOS and Debian-family Linux.

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
| `3` | Unsupported platform, invalid catalog, or failed resolution |
| `4` | Chezmoi or an internal CLI file is unavailable |

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

## Safety

The current CLI reads versioned catalog data and basic operating-system facts.
It does not use the network, request elevated privileges, call providers, read
secrets, or change the machine.

For an end-to-end introduction, read the [user guide](../user-guide/README.md).
Future commands are tracked in the [roadmap](../roadmap.md). Contributors adding
a command must follow the [command documentation guide](command-template.md).

# Command guide

Use the CLI to inspect and validate the catalog or preview a module composition.
Every command available today is read-only: nothing is installed, saved, or
applied.

Run commands from the repository root with `./bin/dotfiles`.

> [!NOTE]
> The production catalog is empty until Phase 3. List commands therefore return
> no rows, and example module or profile identifiers are not available yet.

## Quick start

~~~console
$ ./bin/dotfiles help
$ ./bin/dotfiles version
dotfiles 0.1.0-dev
$ ./bin/dotfiles catalog validate
catalog valid: 0 modules, 0 profiles
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

## Typical workflow

1. List available modules or profiles.
2. Inspect an identifier with `show`.
3. Preview the final dependency-expanded composition with `resolve`.

~~~console
./bin/dotfiles profile list
./bin/dotfiles profile show shell.minimal
./bin/dotfiles resolve --profile shell.minimal
~~~

The example identifier above is planned and remains unavailable while the
production catalog is empty.

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

### A list command prints nothing

This is expected while the production catalog is empty. The command still exits
successfully.

### `chezmoi is required for catalog commands`

Install chezmoi, confirm `chezmoi --version` works, and retry. Help and version
remain available.

### A module or profile is unknown

Use `module list --all` or `profile list --all` to find released identifiers.
Identifiers shown as planned examples are not released yet.

## Safety

The current CLI reads versioned catalog data and basic operating-system facts.
It does not use the network, request elevated privileges, call providers, read
secrets, or change the machine.

For an end-to-end introduction, read the [user guide](../user-guide/README.md).
Future commands are tracked in the [roadmap](../roadmap.md). Contributors adding
a command must follow the [command documentation guide](command-template.md).

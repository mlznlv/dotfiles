# User guide

This guide shows the shortest path from cloning the repository to previewing a
dotfiles composition. For exact syntax, use the [command guide](../cli/README.md).

> [!IMPORTANT]
> The current release is read-only. It can inspect, validate, and resolve catalog
> data, but it cannot install packages, save a profile, or apply configuration.
>
> The production catalog is empty until Phase 3. List commands currently return
> no rows, and planned identifiers used in examples are not available yet.

## Before you start

You need:

- macOS or Debian-family Linux, including Debian, Ubuntu, or Kali.
- Bash.
- [Chezmoi](https://www.chezmoi.io/) for catalog commands.
- A local copy of this repository.

The CLI does not need root privileges or network access. Help and version work
without chezmoi.

~~~console
git clone https://github.com/mlznlv/dotfiles.git
cd dotfiles
./bin/dotfiles help
~~~

There is no installation or bootstrap command yet. Run the CLI directly from
the repository root.

## Five-minute check

Confirm the version and validate the catalog:

~~~console
$ ./bin/dotfiles version
dotfiles 0.1.0-dev
$ ./bin/dotfiles catalog validate
catalog valid: 0 modules, 0 profiles
~~~

The zero counts are expected in the current phase.

## Discover what is available

A **module** is one capability, such as a shell or prompt. A **profile** is a
named set of modules.

List entries compatible with the current machine:

~~~console
./bin/dotfiles module list
./bin/dotfiles profile list
~~~

List every entry without platform filtering:

~~~console
./bin/dotfiles module list --all
./bin/dotfiles profile list --all
~~~

Both commands currently succeed without output because the production catalogs
are empty. Once populated, each row contains an identifier, name, and summary.

Inspect one released identifier with `show`:

~~~console
./bin/dotfiles module show shell.zsh.autosuggestions
./bin/dotfiles profile show shell.minimal
~~~

These identifiers are planned examples. Today they return `unknown module` or
`unknown profile`. Use the list commands to discover identifiers that actually
exist in the current catalog.

## Preview a composition

The `resolve` command expands dependencies, removes duplicates, checks platform
support, and rejects conflicts. It prints one module identifier per line and
does not save or apply the result.

### Start from a profile

~~~console
$ ./bin/dotfiles resolve --profile shell.minimal --platform debian
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

### Build a custom composition

~~~console
./bin/dotfiles resolve \
    --modules shell.zsh.autosuggestions,prompt.starship \
    --platform macos
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

`shell.zsh` appears automatically because autosuggestions depends on it.

### Add modules to a base

Use `--add` with either a profile or a custom base:

~~~console
$ ./bin/dotfiles resolve \
    --profile shell.minimal \
    --add terminal.ghostty \
    --platform macos
~~~

The examples in this section demonstrate the implemented resolution contract.
They will become runnable when those catalog entries are released.

## Preview another platform

Without `--platform`, the CLI detects macOS or Debian-family Linux. Override it
when checking compatibility for another machine:

~~~console
./bin/dotfiles module list --platform debian
./bin/dotfiles profile list --platform macos
~~~

Accepted values are `macos` and `debian`. The `debian` value covers Debian,
Ubuntu, Kali, and other supported Debian-family distributions.

## Understand failures

The CLI stops without partial output when a composition is invalid. Common
causes include:

- An unknown module or profile identifier.
- A module that does not support the selected platform.
- Conflicting modules or two modules in one exclusive group.
- Missing dependencies or a dependency cycle.
- Invalid catalog data.

Invalid syntax points back to help:

~~~console
$ ./bin/dotfiles resolve
error: resolve requires --profile or --modules
Run dotfiles help for usage.
~~~

Exit codes are stable:

| Code | Meaning |
| --- | --- |
| `0` | Success, including an empty list |
| `2` | Invalid command syntax |
| `3` | Unsupported platform, invalid catalog, or failed resolution |
| `4` | Chezmoi or an internal CLI file is unavailable |

## Safety and current boundaries

Available commands do not:

- Install, remove, or upgrade packages.
- Write home configuration or save a composition.
- Invoke Homebrew, mise, or another provider.
- Apply chezmoi state.
- Read secrets or machine identity.
- Request elevated privileges.

Installation, saved profiles, planning, apply, rollback, sharing, and repair
commands remain planned. Follow their delivery in the [roadmap](../roadmap.md).

## Command reference

- [Command overview](../cli/README.md)
- [Help](../cli/help.md)
- [Version](../cli/version.md)
- [Catalog validation](../cli/catalog/validate.md)
- [List modules](../cli/module/list.md)
- [Inspect a module](../cli/module/show.md)
- [List profiles](../cli/profile/list.md)
- [Inspect a profile](../cli/profile/show.md)
- [Resolve a composition](../cli/resolve.md)

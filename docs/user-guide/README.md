# User guide

This guide shows the shortest path from cloning the repository to previewing a
dotfiles composition. For exact syntax, use the [command guide](../cli/README.md).

> [!IMPORTANT]
> The current release is read-only. It can inspect, validate, and resolve catalog
> data, check selected command/artifact prerequisites, and plan selected target
> changes, but it cannot install packages, save a profile, or apply
> configuration.
>
> The production catalog exposes the minimal shell composition. Prerequisite
> identifiers use schema 1. Command and artifact presence checks are available;
> application checks, managed home state, and apply remain unavailable.
> Future apply manages configuration only and never installs software.

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

There is no software installation or bootstrap command. Run the CLI directly
from the repository root.

## Five-minute check

Confirm the version and validate the catalog:

~~~console
$ ./bin/dotfiles version
dotfiles 0.1.0-dev
$ ./bin/dotfiles catalog validate
catalog valid: 3 modules, 1 profile
~~~

The counts represent the three released shell modules and one curated profile.

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

Each row contains an identifier, name, and summary.

Inspect one released identifier with `show`:

~~~console
./bin/dotfiles module show shell.zsh.autosuggestions
./bin/dotfiles profile show shell.minimal
~~~

These identifiers are released and can be inspected directly.

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

The shell examples in this section are runnable. `terminal.ghostty` remains
unreleased, so the optional-addition example is illustrative only.

## Preview another platform

Without `--platform`, the CLI detects macOS or Debian-family Linux. Override it
when checking compatibility for another machine:

~~~console
./bin/dotfiles module list --platform debian
./bin/dotfiles profile list --platform macos
~~~

Accepted values are `macos` and `debian`. The `debian` value covers Debian,
Ubuntu, Kali, and other supported Debian-family distributions.

## Check prerequisites

Check the resolved profile without installing or configuring anything:

~~~console
./bin/dotfiles prerequisite check --profile shell.minimal --platform debian
~~~

The command reports every declared command and artifact as `present` or
`missing`. Missing items must be provided outside this project. Artifact root
paths below HOME are abbreviated as `$HOME`; no provider is inferred.

## Plan selected configuration

Preview only targets owned by the resolved composition:

~~~console
$ ./bin/dotfiles plan --modules shell.zsh --platform debian
Prerequisites: satisfied
Plan: 1 configuration change for debian

1. create shell.zsh chezmoi:target:.zshrc
   source: home/dot_zshrc.tmpl
   network: no; privilege: none
~~~

Your result may say `update` or `No changes.` depending on the current selected
target. Planning writes nothing to HOME and never prints raw destination
contents. It requires a literal absolute HOME directory and fails closed on an
unsafe selected path or unexpected Chezmoi result.

## Understand failures

The CLI stops without partial output when a composition is invalid. Common
causes include:

- An unknown module or profile identifier.
- A module that does not support the selected platform.
- Conflicting modules or two modules in one exclusive group.
- Missing dependencies or a dependency cycle.
- Invalid catalog data.
- A missing selected prerequisite or unsafe destination target.
- A failed or malformed selected-target comparison.

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
| `3` | Invalid catalog, composition, platform, destination, prerequisite data, ownership, or comparison result |
| `4` | Chezmoi/checker dependency is unavailable, or application checking is required |
| `5` | A selected prerequisite is missing or a Chezmoi comparison failed |

## Safety and current boundaries

Available commands do not:

- Install, remove, or upgrade packages.
- Write home configuration or save a composition.
- Invoke Homebrew, mise, or another provider.
- Open or invoke declared prerequisites.
- Apply chezmoi state.
- Display destination contents or machine identity, or inspect unselected home
  targets.
- Request elevated privileges.

Saved profiles, apply, recovery, sharing, and repair commands remain planned.
Software installation is outside the product boundary. Follow delivery in the
[roadmap](../roadmap.md).

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
- [Check prerequisites](../cli/prerequisite/check.md)
- [Build a configuration plan](../cli/plan.md)

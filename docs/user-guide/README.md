# User guide

The shortest path from cloning the repository to previewing a composition. For
exact syntax, use the [command guide](../cli/README.md).

> [!IMPORTANT]
> The current release is read-only: it inspects, validates, and resolves catalog
> data, but installs nothing and applies nothing. The production catalog is empty
> until Phase 3, so list commands return no rows and the identifiers used in the
> examples below do not exist yet.

## Before you start

You need:

- macOS or Debian-family Linux, including Debian, Ubuntu, or Kali.
- Bash.
- [Chezmoi](https://www.chezmoi.io/) for catalog commands.
- A local copy of this repository.

The CLI needs no root privileges and no network access. Help and version work
without chezmoi.

~~~console
git clone https://github.com/mlznlv/dotfiles.git
cd dotfiles
./bin/dotfiles help
~~~

There is no bootstrap command yet. Run the CLI from the repository root.

## Five-minute check

~~~console
$ ./bin/dotfiles version
dotfiles 0.1.0-dev
$ ./bin/dotfiles catalog validate
catalog valid: 0 modules, 0 profiles
~~~

## Discover what is available

A **module** is one capability, such as a shell or a prompt. A **profile** is a
named set of modules.

~~~console
./bin/dotfiles module list          # compatible with this machine
./bin/dotfiles module list --all    # every entry, unfiltered
./bin/dotfiles profile list
~~~

Each row carries an identifier, name, and summary. Inspect one with `show`:

~~~console
./bin/dotfiles module show shell.zsh.autosuggestions
./bin/dotfiles profile show shell.minimal
~~~

Use the list commands to find identifiers that exist in the current catalog.

## Preview a composition

`resolve` expands dependencies, removes duplicates, checks platform support, and
rejects conflicts. It prints one identifier per line and saves nothing.

### Start from a profile

~~~console
$ ./bin/dotfiles resolve --profile shell.minimal --platform debian
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

### Build a custom composition

~~~console
$ ./bin/dotfiles resolve \
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

## Preview another platform

Without `--platform`, the CLI detects the local system. Override it to check
another target. Accepted values are `macos` and `debian`, where `debian` covers
Debian, Ubuntu, Kali, and other Debian-family distributions.

~~~console
./bin/dotfiles module list --platform debian
./bin/dotfiles profile list --platform macos
~~~

## Understand failures

The CLI stops without partial output when a composition is invalid. Common
causes are an unknown identifier, a module that does not support the selected
platform, conflicting modules or two modules in one exclusive group, a missing
dependency or a dependency cycle, and invalid catalog data.

Invalid syntax points back to help:

~~~console
$ ./bin/dotfiles resolve
error: resolve requires --profile or --modules
Run dotfiles help for usage.
~~~

Exit codes are stable and documented in the
[command guide](../cli/README.md#exit-codes).

## Safety and current boundaries

Available commands never install, remove, or upgrade packages, write home
configuration, save a composition, invoke Homebrew, mise, or another provider,
apply chezmoi state, read secrets or machine identity, or request elevated
privileges.

Installation, saved profiles, planning, apply, rollback, sharing, and repair
commands remain planned. Follow their delivery in the [roadmap](../roadmap.md).

## Command reference

Every released and planned command is listed in the
[command guide](../cli/README.md).

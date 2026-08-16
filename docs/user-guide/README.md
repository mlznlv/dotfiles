# User guide

This guide shows the shortest path from cloning the repository to previewing
and applying an explicit dotfiles composition. For exact syntax, use the
[command guide](../cli/README.md).

> [!IMPORTANT]
> The current release can inspect, validate, and resolve catalog data, check
> selected command/artifact prerequisites, plan selected target changes, and
> explicitly apply those selected home files through Chezmoi. It can also save
> local profile or module intent without applying it. It cannot install
> packages.
>
> The production catalog exposes the minimal shell composition. Prerequisite
> identifiers use schema 1. Command and artifact presence checks are available;
> application checks remain unavailable. Apply manages configuration only and
> never installs software.

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

## Apply selected configuration

Use the same explicit selection to recompute, review, confirm, and apply only
its changed targets:

~~~console
$ ./bin/dotfiles apply --modules shell.zsh --platform debian
Prerequisites: satisfied
Plan: 1 configuration change for debian

1. create shell.zsh chezmoi:target:.zshrc
   source: home/dot_zshrc.tmpl
   network: no; privilege: none

Software installation: none

Apply this configuration? Type yes to continue:
~~~

Type exactly `yes` to continue. Any other answer or EOF cancels without CLI
mutation. For redirected or automated input, use explicit `--yes`; the command
still prints and independently recomputes the complete current plan before
mutation.

Apply invokes Chezmoi once for each changed selected target, verifies the
written bytes, and stops at the first failure. A second identical apply prints
exactly `No changes.` without prompting. Omitted module files are not inspected,
reported, removed, or cleaned.

## Save local selection

Save the exact profile or ordered module intent without changing managed home
configuration:

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

The command saves only the profile or module choice and optional additions in
canonical schema-1 TOML. Saving never checks prerequisites, plans, applies,
installs, repairs, or changes managed home configuration. See
[config set](../cli/config/set.md) for explicit module syntax, local path rules,
recovery, and concurrency limits.

> [!WARNING]
> `resolve`, `prerequisite check`, `plan`, and `apply` do not consume saved
> selection yet. Continue passing `--profile` or `--modules` to those commands.
> Interactive selection, saved-state consumption, inspect, and doctor remain
> later [Phase 4](../roadmap.md#phase-4-configuration-workflow) increments.

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
- State or prerequisite drift after confirmation.
- A Chezmoi apply or post-target verification failure.

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
| `4` | A required component or safe local-state update is unavailable, a post-rename result is uncertain, or application checking is required |
| `5` | A selected prerequisite is missing or a Chezmoi comparison failed |
| `6` | Chezmoi apply or post-target verification failed after mutation began |
| `129`, `130`, `143` | Handled HUP, INT, or TERM interruption |

If apply reports a partial result, completed targets remain in place. Correct
the failed prerequisite or target and rerun `plan` or `apply`. The retry builds
a new plan from current state, skips already converged targets, and does not
roll back or replay the earlier plan.

## Safety and current boundaries

Available commands do not:

- Install, remove, or upgrade packages.
- Save a reusable plan or apply a saved selection implicitly.
- Invoke Homebrew, mise, or another provider.
- Open or invoke declared prerequisites.
- Display destination contents or machine identity, or inspect unselected home
  targets.
- Request elevated privileges.
- Remove, prune, clean, or roll back configuration.

Only `apply` writes managed home configuration, and only after printing and
recomputing the selected plan with exact intent. `config set` writes only the
CLI-owned active-selection file and necessary owned configuration directories.
Interactive selection, generalized recovery, sharing, and repair commands
remain planned. Software installation is outside the product boundary. Follow
delivery in the [roadmap](../roadmap.md).

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
- [Save local selection](../cli/config/set.md)
- [Check prerequisites](../cli/prerequisite/check.md)
- [Build a configuration plan](../cli/plan.md)
- [Apply selected configuration](../cli/apply.md)

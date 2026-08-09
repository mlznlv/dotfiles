# `dotfiles plan` (planned)

## Status

This command is not available in the current CLI. Its configuration-only
contract depends on owner acceptance of ADR 0007 and the schema migration.

## Synopsis

~~~text
dotfiles plan (--profile <profile-id> | --modules <id,id>)
              [--add <id,id>] [--platform macos|debian]
~~~

## Behavior

The command resolves the explicit composition, rejects rendered-target
collisions, and validates only the static prerequisites of selected modules.
It checks command and application presence without running a prerequisite. A
missing prerequisite names the module and identifier, tells the user to provide
the tool outside this project, and fails before creating a plan eligible for
apply.

After preconditions pass, the command asks chezmoi for diffs limited to the
selected module sources and prints one deterministic configuration plan. Every
step contains an ordinal, module, normalized `chezmoi:target` key, action, and
sanitized description. Steps sort by target and then module. `No changes.` is a
successful plan.

Planning never installs or updates software, invokes Homebrew or mise, calls an
operating-system package manager, executes a prerequisite, writes home state,
or saves a plan. Plans contain no secrets or machine identity.

## Examples

Configuration-only plan:

~~~console
$ dotfiles plan --modules prompt.starship --platform macos
Prerequisites: satisfied
Plan: 1 configuration change for macos

1. update prompt.starship chezmoi:target:.config/starship.toml
   source: home/dot_config/starship.toml
   network: no; privilege: none
~~~

This selection does not select Zsh or another shell.

Missing prerequisite:

~~~console
$ dotfiles plan --modules terminal.ghostty --platform macos
error: terminal.ghostty requires application com.mitchellh.ghostty on macos
Provide the application outside this project, then run the plan again.
No configuration changes were planned or applied.
~~~

Unsupported platform combinations and unsafe prerequisite data also fail
before chezmoi diffing. Repeated planning after convergence is explicit:

~~~console
$ dotfiles plan --profile shell.minimal
No changes.
~~~

## Exit codes

| Code | Planned meaning |
| --- | --- |
| `0` | Valid configuration plan, including `No changes.` |
| `2` | Invalid syntax |
| `3` | Invalid catalog, composition, platform, prerequisite data, or ownership |
| `4` | Required CLI foundation component unavailable |
| `5` | Prerequisite check or chezmoi diff failed; no actionable plan produced |

Errors go to standard error. No failure path mutates software or home state.

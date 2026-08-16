# Build a configuration plan

[Command guide](README.md) / Plan

Preview deterministic create or update effects for an explicit composition.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles plan (--profile <profile-id> | --modules <id,id>)
              [--add <id,id>] [--platform macos|debian]
~~~

Exactly one of `--profile` and `--modules` is required. `--add` uses the normal
resolver, including dependency expansion, conflicts, exclusive groups,
platform compatibility, and rendered-target ownership. Without `--platform`,
the shared platform detector selects macOS or Debian-family Linux.

## Behavior

Planning validates the complete catalog and selected prerequisites before
comparison. Command and artifact prerequisites are checked without invocation;
application prerequisites continue to fail closed. Missing prerequisites name
the module, kind, and identifier and must be provided outside this project.

The command freshly rebuilds the selected-source render context and rendered
targets. Autosuggestions revalidates its canonical contained artifact
immediately before comparison and requires the same candidate used by that
render. No context, rendered output, comparison result, cache, state, or plan is
retained.

Chezmoi compares only exact targets owned by the resolved modules. User
configuration, pagers, color, custom diffs, external refresh, interactivity,
and TTY behavior are disabled. Selected sources use no secret command
integration. The public result contains no raw diff, destination content, HOME
path, artifact root, or temporary path.

Changed steps sort by normalized target and module. An absent target is
`create`; a differing regular file is `update`; an unchanged target is omitted.
The planner never invents delete, remove, deactivate, install, repair, or
provider effects. If all selected targets match, it prints exactly
`No changes.`

A narrower selection remains narrow. Starship-only planning does not inspect
or report `.zshrc`. Selecting Zsh after a broader composition may report an
`.zshrc` update because the fresh render omits unselected activation, while
files owned by omitted modules remain unreported and untouched.

## Examples

One absent selected target:

~~~console
$ ./bin/dotfiles plan --modules prompt.starship --platform macos
Prerequisites: satisfied
Plan: 1 configuration change for macos

1. create prompt.starship chezmoi:target:.config/starship.toml
   source: home/dot_config/starship.toml
   network: no; privilege: none
~~~

Missing prerequisite:

~~~console
$ ./bin/dotfiles plan --modules prompt.starship --platform debian
error: module prompt.starship requires command starship on debian
Provide the missing prerequisites outside this project, then run dotfiles plan again.
~~~

Already converged:

~~~console
$ ./bin/dotfiles plan --profile shell.minimal
No changes.
~~~

Planning never installs or updates software, invokes a provider or declared
prerequisite, writes home state, or creates apply authority. Correct a missing
prerequisite or unsafe selected target and rerun the command.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Valid plan, including `No changes.` |
| `2` | Invalid command syntax |
| `3` | Invalid catalog, composition, platform, prerequisite data, ownership, destination, or unsafe comparison result |
| `4` | Required internal component or Chezmoi is unavailable |
| `5` | Selected prerequisite is missing or Chezmoi comparison failed; no actionable plan was produced |

Errors go to standard error. No failure path prints a partial actionable plan
or changes software or home state.

Next: [apply selected configuration](apply.md).

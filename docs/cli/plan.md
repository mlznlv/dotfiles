# `dotfiles plan` (planned)

## Status

This command is a Phase 3 contract. It is not available in the current CLI.

## Synopsis

~~~text
dotfiles plan (--profile <profile-id> | --module <module-id>...)
              [--add <module-id>...] [--platform macos|debian]
~~~

## Behavior

The command resolves the requested composition, selects static requests for the
target platform, rejects duplicate ownership, observes provider state without
mutation, and prints one deterministic plan. It never installs a provider,
updates metadata, downloads packages, writes home state, or saves a plan.
If Homebrew, mise, or chezmoi is required but unavailable, the command names the
missing prerequisite, discloses that separate provider installation is needed,
and fails without producing a plan eligible for apply.

Steps are grouped Homebrew, mise, then chezmoi and sorted by canonical ownership
key within each group. Every step shows its ordinal, declaring module, action,
resource key, network use, possible privilege prompt, and download integrity
owner. It also states whether the provider itself must be installed. Sensitive
provider values are redacted.

## Examples

Planned macOS output:

~~~console
$ dotfiles plan --profile shell.minimal --platform macos
Plan: 6 changes for macos

Homebrew
1. install shell.zsh homebrew:package:zsh
   network: yes; provider installation: no; privilege: possible Homebrew prompt; download: Homebrew-managed integrity
2. install shell.zsh.autosuggestions homebrew:package:zsh-autosuggestions
   network: yes; provider installation: no; privilege: possible Homebrew prompt; download: Homebrew-managed integrity
3. install prompt.starship homebrew:package:starship
   network: yes; provider installation: no; privilege: possible Homebrew prompt; download: Homebrew-managed integrity

chezmoi
4. update prompt.starship chezmoi:source:home/dot_config/starship.toml
   network: no; provider installation: no; privilege: none; download: none
5. update shell.zsh.autosuggestions chezmoi:source:home/dot_config/zsh/autosuggestions.zsh.tmpl
   network: no; provider installation: no; privilege: none; download: none
6. update shell.zsh chezmoi:source:home/dot_zshrc.tmpl
   network: no; provider installation: no; privilege: none; download: none
~~~

Planned Debian-family output uses mise as the package and tool owner:

~~~console
$ dotfiles plan --profile shell.minimal --platform debian
Plan: 6 changes for debian

mise
1. install shell.zsh mise:package:zsh
2. install shell.zsh.autosuggestions mise:package:zsh-autosuggestions
3. install prompt.starship mise:tool:starship
   network: yes; provider installation: no; privilege: possible package-manager prompt; download: mise-managed integrity

chezmoi
4. update prompt.starship chezmoi:source:home/dot_config/starship.toml
5. update shell.zsh.autosuggestions chezmoi:source:home/dot_config/zsh/autosuggestions.zsh.tmpl
6. update shell.zsh chezmoi:source:home/dot_zshrc.tmpl
~~~

Repeated planning after successful convergence is explicit:

~~~console
$ dotfiles plan --profile shell.minimal
No changes.
~~~

The compact Debian example omits repeated disclosure lines for readability;
the implemented command must print them for every step.

## Exit codes

| Code | Planned meaning |
| --- | --- |
| `0` | Valid plan, including `No changes.` |
| `2` | Invalid syntax |
| `3` | Invalid catalog, composition, platform, or ownership |
| `4` | Required CLI component or provider observer unavailable |
| `5` | Provider observation failed; no actionable plan produced |

Errors go to standard error. No failure path may mutate provider or home state.

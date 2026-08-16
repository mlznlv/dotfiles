# `dotfiles apply` (planned)

## Status

This command is not available in the current CLI. Its configuration-only
contract depends on accepted ADR 0010 and the released read-only renderer and
planner.

## Synopsis

~~~text
dotfiles apply (--profile <profile-id> | --modules <id,id>)
               [--add <id,id>] [--platform macos|debian] [--yes]
~~~

## Behavior

Apply recomputes resolution, rendered-target ownership, prerequisite checks,
the closed ephemeral render context, and the selected-source chezmoi diff
during one invocation. It cannot load or replay a saved plan or render result.
A missing prerequisite or invalid platform fails before mutation and tells the
user to provide the tool outside this project.

The complete configuration plan is printed before any change. With an
interactive terminal, the exact answer `yes` confirms. Any other answer, EOF,
or interruption cancels without invoking chezmoi apply. Non-interactive input
fails closed unless `--yes` is present; the flag does not hide the plan.

Chezmoi applies only source paths owned by the selected modules. Apply never
invokes Homebrew, mise, a package manager, an application installer, or a
prerequisite executable. It performs no software installation, upgrade,
uninstall, removal, prune, broad cleanup, or automatic rollback. A failure
reports completed, failed, and unattempted configuration targets. Retrying
recomputes state, and a second successful apply converges to `No changes.`

For the accepted shell contract, selecting `shell.zsh` permits convergence of
its owned `.zshrc`, including omission of integrations not in the current
resolved set. Files owned by omitted modules are not selected for apply and are
not removed. Omitting Zsh does not rewrite `.zshrc`. The temporary context is
removed on success, failure, cancellation, or interruption, and its raw
artifact path is never saved in a reusable plan or repository log.

## Examples

Interactive configuration apply:

~~~console
$ dotfiles apply --modules prompt.starship
Prerequisites: satisfied
Plan: 1 configuration change for macos
1. update prompt.starship chezmoi:target:.config/starship.toml
Software installation: none
Apply this configuration? Type yes to continue: yes
Apply complete: 1 completed, 0 failed, 0 unattempted
~~~

Missing prerequisite:

~~~console
$ dotfiles apply --modules editor.vscode --platform debian
error: editor.vscode requires command code on debian
Provide the command outside this project, then run apply again.
No configuration changes were applied.
~~~

Cancellation and non-interactive refusal remain explicit:

~~~console
$ dotfiles apply --modules prompt.starship
...
Apply this configuration? Type yes to continue: no
Cancelled. No changes were applied.

$ dotfiles apply --modules prompt.starship </dev/null
error: non-interactive apply requires --yes
~~~

No-change apply succeeds without prompting because there is nothing to mutate:

~~~console
$ dotfiles apply --profile shell.minimal
No changes.
~~~

## Exit codes

| Code | Planned meaning |
| --- | --- |
| `0` | Applied, cancelled before mutation, or already converged |
| `2` | Invalid syntax or non-interactive use without `--yes` |
| `3` | Invalid catalog, composition, platform, prerequisite data, or ownership |
| `4` | Required CLI foundation component unavailable |
| `5` | Prerequisite check or chezmoi diff failed before confirmation |
| `6` | Chezmoi apply failed; report identifies configuration target states |

# `dotfiles apply` (planned)

## Status

This command is a Phase 3 contract. It is not available in the current CLI.

## Synopsis

~~~text
dotfiles apply (--profile <profile-id> | --module <module-id>...)
               [--add <module-id>...] [--platform macos|debian] [--yes]
~~~

## Behavior

Apply recomputes a fresh plan from current observations during the invocation.
It cannot load or replay a saved plan. The complete plan, network and download
effects, integrity owner, and possible privilege prompts are printed before any
mutation.

With an interactive terminal, the exact answer `yes` confirms. Any other
answer, EOF, or interruption cancels successfully without invoking an apply
adapter. With non-interactive input, the command refuses before mutation unless
`--yes` is present. `--yes` is explicit acknowledgement and does not suppress
the plan or disclosures.

Steps run in displayed order. Apply stops at the first failure and reports each
step as completed, failed, or unattempted. It performs no rollback, removal,
uninstall, prune, or cleanup. Retrying recomputes state. Providers are expected
to be idempotent, so a second successful apply produces `No changes.`

## Examples

Interactive confirmation:

~~~console
$ dotfiles apply --profile shell.minimal
Plan: 6 changes for macos
...
Network access: required by Homebrew
Provider installation: not required
Privilege prompts: possible during Homebrew operations
Apply these changes? Type yes to continue: yes
Apply complete: 6 completed, 0 failed, 0 unattempted
~~~

Cancellation:

~~~console
$ dotfiles apply --profile shell.minimal
Plan: 6 changes for macos
...
Apply these changes? Type yes to continue: no
Cancelled. No changes were applied.
~~~

Non-interactive refusal:

~~~console
$ dotfiles apply --profile shell.minimal </dev/null
error: non-interactive apply requires --yes
~~~

Partial failure:

~~~text
Apply failed at step 2: mise:package:zsh-autosuggestions
completed: 1 (mise:package:zsh)
failed: 1 (mise:package:zsh-autosuggestions)
unattempted: 4
No rollback was attempted. Re-run apply to recompute current state.
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
| `3` | Invalid catalog, composition, platform, or ownership |
| `4` | Required CLI component or provider unavailable |
| `5` | Observation failed before confirmation |
| `6` | Apply failed; report identifies completed, failed, and unattempted steps |

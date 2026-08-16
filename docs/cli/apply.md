# Apply selected configuration

[Command guide](README.md) / Apply

Recompute, confirm, and converge an explicit selected configuration.

Available · Mutating · Chezmoi required · Software installation: none.

## Usage

~~~text
dotfiles apply (--profile <profile-id> | --modules <id,id>)
               [--add <id,id>] [--platform macos|debian] [--yes]
~~~

Selection and platform rules are identical to [`dotfiles plan`](plan.md).
`--yes` is an apply-only acknowledgement for the plan printed by the current
invocation. It does not suppress validation, recomputation, output, or failure
reporting. There is no `-y`, saved plan, saved selection, default profile, or
environment-based approval.

## Confirmation flow

Apply builds and prints the same complete privacy-safe plan as `dotfiles plan`.
When every selected target is already converged, it prints exactly
`No changes.` and exits without prompting or invoking Chezmoi apply.

For a changed plan, the command prints `Software installation: none`. Without
`--yes`, stdin must be an interactive terminal and the prompt is:

~~~text
Apply this configuration? Type yes to continue:
~~~

Only the exact line `yes` continues. Case changes, whitespace, other text, an
empty line, or EOF print `Cancelled. No changes were applied.` and exit 0.
Redirected or piped input requires `--yes` and otherwise exits 2 after showing
the complete plan.

After approval, apply independently rebuilds catalog resolution, ownership,
prerequisites, the canonical artifact fact, render context, rendered files, and
changed-target records from the original CLI input. The canonical records,
selection, context, artifact fact, and rendered bytes must match the displayed
plan's private snapshot exactly. Changed destination base bytes are also
snapshotted privately during both passes and must match. Drift fails before
Chezmoi mutation and asks the user to rerun the command.

## Mutation boundary

Chezmoi is invoked once per changed target in displayed order. Each invocation
receives one exact selected destination, the fresh closed render context, the
repository `home/` source, isolated cache and state, required parent-directory
scope, and directory/file entry types. User configuration, prompts, TTY
acquisition, pagers, color, progress, custom diffs, scripts, externals,
symlinks, secret integration, and recursion are excluded. `--force` is passed
only after CLI confirmation.

Immediately before each invocation, apply rechecks the target and existing
parents. An update target's bytes must still match its fresh post-confirmation
base snapshot. Autosuggestions also revalidates the same canonical contained
artifact immediately before applying the Zsh-owned `.zshrc`. After Chezmoi
succeeds, the target must be a regular non-symlink file whose bytes equal the
fresh render before it counts as completed.

Omitted modules are outside the command's scope. Starship-only apply never
inspects or changes `.zshrc`. A narrower Zsh selection may converge `.zshrc`
without optional activation, but it does not remove or rewrite configuration
files owned by omitted modules.

## Examples

Non-interactive selected apply:

~~~console
$ ./bin/dotfiles apply --modules prompt.starship --platform macos --yes
Prerequisites: satisfied
Plan: 1 configuration change for macos

1. create prompt.starship chezmoi:target:.config/starship.toml
   source: home/dot_config/starship.toml
   network: no; privilege: none

Software installation: none
Apply complete: 1 completed, 0 failed, 0 unattempted
~~~

Already converged:

~~~console
$ ./bin/dotfiles apply --modules prompt.starship --platform macos
No changes.
~~~

Cancellation:

~~~console
$ ./bin/dotfiles apply --modules prompt.starship
...
Apply this configuration? Type yes to continue:
Cancelled. No changes were applied.
~~~

## Failure and recovery

Apply stops at the first failed or unverified target. It reports every changed
target once as completed, failed, or unattempted in original plan order:

~~~text
Apply failed: 1 completed, 1 failed, 1 unattempted
completed: prompt.starship chezmoi:target:.config/starship.toml
failed: shell.zsh.autosuggestions chezmoi:target:.config/zsh/autosuggestions.zsh
unattempted: shell.zsh chezmoi:target:.zshrc
~~~

Completed targets are not rolled back. Correct the prerequisite, destination,
or external failure and run a new `dotfiles plan` or `dotfiles apply`
invocation. The new invocation recomputes current state, omits already
converged targets, and never replays the earlier plan. No removal, repair,
automatic retry, backup, or broad recovery action is performed.

All Chezmoi output, raw paths, destination base snapshots, rendered files, plan
authority, cache, state, and errors remain in mode-restricted temporary storage
and are removed on success, no-change, cancellation, failure, and handled
signals.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Applied successfully, cancelled before mutation, or already converged |
| `2` | Invalid syntax or non-interactive changes without `--yes` |
| `3` | Invalid catalog, composition, platform, prerequisite data, ownership, destination, unsafe target, malformed state, or confirmation-time drift |
| `4` | Required internal component or Chezmoi is unavailable |
| `5` | Selected prerequisite, artifact recheck, render, or comparison failed before mutation |
| `6` | Chezmoi apply or post-target verification failed after mutation began |
| `129`, `130`, `143` | Handled HUP, INT, or TERM interruption |

Errors go to standard error. Public output never includes raw destination
contents, diffs, HOME, temporary paths, artifact roots, usernames, or hostnames.

# Zsh autosuggestions

- Status: Available for discovery, resolution, prerequisite checking,
  internal read-only rendering, and configuration planning
- Category: shell
- Supported platforms: macOS and Debian-family Linux
- Documentation owner: repository maintainer

## Purpose and result

`shell.zsh.autosuggestions` declares interactive history-based suggestions for
Zsh. Current commands expose intent only; suggestions are not installed or
enabled.

## Dependencies and conflicts

The module depends on `shell.zsh`, has no declared conflicts, and has no
exclusive group.

## Prerequisites and managed configuration

The released schema-1 manifest declares `zsh` and the artifact locator
`share:zsh-autosuggestions/zsh-autosuggestions.zsh` on macOS and Debian.
`prerequisite check` locates the command without invocation and searches the
accepted provider-neutral share roots for a contained regular file using
metadata only. It never opens the artifact. No shell initialization file is
applied to the user's home.

Accepted ADR 0010 assigns this module only
`home/dot_config/zsh/autosuggestions.zsh`, rendered as
`.config/zsh/autosuggestions.zsh`; the Zsh module continues to own `.zshrc`.
The tool configuration intentionally retains portable upstream defaults. When
both dependency and module are resolved, the Zsh-owned template references the
fixed configuration target and safely sources only the fully resolved ADR
0008-validated artifact path. No fallback search, provider lookup, or fragment
glob exists. Rendering is isolated and does not open the artifact.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Read-only planning is available; apply remains unavailable. Verify dependency
expansion with:

~~~console
$ ./bin/dotfiles resolve --modules shell.zsh.autosuggestions --platform macos
shell.zsh
shell.zsh.autosuggestions
~~~

Check both prerequisites with:

~~~console
./bin/dotfiles prerequisite check --modules shell.zsh.autosuggestions --platform macos
./bin/dotfiles plan --modules shell.zsh.autosuggestions --platform macos
~~~

Planning freshly revalidates the same canonical contained artifact immediately
before comparing `.config/zsh/autosuggestions.zsh` and the dependency-owned
`.zshrc`. It reports only changed selected targets. The commands and internal
renderer are read-only and need no recovery. Planned startup-file recovery will
cover configuration only.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, command history, or machine identity.

## Tests and known limitations

Schema, dependency, ownership, discovery, profile resolution, and macOS/Ubuntu
CI plus isolated command, artifact, and containment tests cover this module.
Deterministic rendering, quoting, planning, artifact replacement, privacy, and
stale-state tests are also available. Home initialization and apply are
deferred.

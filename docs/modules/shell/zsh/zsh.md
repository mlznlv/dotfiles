# Zsh

- Status: Available for discovery, resolution, prerequisite checking,
  internal read-only rendering, configuration planning, and selected apply
- Category: shell
- Supported platforms: macOS and Debian-family Linux
- Documentation owner: repository maintainer

## Purpose and result

`shell.zsh` declares the primary interactive Zsh capability. Apply can converge
its selected `.zshrc`; no command installs Zsh or changes the active shell.

## Dependencies and conflicts

The module has no dependencies or declared conflicts and belongs to the
`shell.primary` exclusive group.

## Prerequisites and managed configuration

The schema-1 manifest declares `zsh` on macOS and Debian. `prerequisite check`
locates an external executable file through absolute PATH entries without
invoking it. This module alone declares `home/dot_zshrc.tmpl`, which normalizes
to `.zshrc`.

Accepted ADR 0010 makes this module the sole owner of `.zshrc` and all Zsh
startup activation syntax. Its template enumerates only integrations in
the resolved explicit composition—never glob a fragment directory. Starship
activation requires both selected modules; autosuggestions activation requires
its selected module and currently validated canonical artifact. Core output is
deliberately minimal and changes no login shell.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

The internal renderer exercises the source in isolated temporary output. Verify
metadata, preview the selected `.zshrc`, then apply the same explicit selection:

~~~console
./bin/dotfiles module show shell.zsh
./bin/dotfiles resolve --modules shell.zsh --platform debian
./bin/dotfiles prerequisite check --modules shell.zsh --platform debian
./bin/dotfiles plan --modules shell.zsh --platform debian
./bin/dotfiles apply --modules shell.zsh --platform debian
~~~

The plan reports create or update for `.zshrc`, or `No changes.` A narrower Zsh
selection may update `.zshrc` to omit unselected integrations but never reports
or removes their separately owned files. Apply recomputes the plan after
confirmation, verifies the resulting bytes, and never changes the login shell.
On failure, correct the reported target and retry; completed targets are not
rolled back.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Software installation
and login-shell changes are outside the product boundary.

## Tests and known limitations

Schema, ownership, exclusive-group, discovery, dependency resolution, profile
resolution, isolated command-presence tests, and macOS/Ubuntu CI cover this
module. Rendering, planning, and apply cover create, update, no-change, stale
optional state, exact confirmation, byte verification, idempotency, privacy,
and partial failure.

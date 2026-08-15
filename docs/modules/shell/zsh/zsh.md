# Zsh

- Status: Available for discovery, resolution, prerequisite checking, and
  internal read-only rendering
- Category: shell
- Supported platforms: macOS and Debian-family Linux
- Documentation owner: repository maintainer

## Purpose and result

`shell.zsh` declares the primary interactive Zsh capability. Current commands
expose its catalog intent but do not install Zsh or change the active shell.

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

Plan and apply are unavailable. The internal renderer exercises the source in
isolated test output only. Verify the released metadata with:

~~~console
./bin/dotfiles module show shell.zsh
./bin/dotfiles resolve --modules shell.zsh --platform debian
./bin/dotfiles prerequisite check --modules shell.zsh --platform debian
~~~

These read-only commands need no recovery. Planned apply will manage only
explicitly selected configuration and will not change the login shell.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Software installation
and login-shell changes are outside the product boundary.

## Tests and known limitations

Schema, ownership, exclusive-group, discovery, dependency resolution, profile
resolution, isolated command-presence tests, and macOS/Ubuntu CI cover this
module. Read-only `.zshrc` rendering is covered; home convergence,
configuration plan, and apply are deferred.

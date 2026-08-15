# Zsh

- Status: Available for discovery, resolution, prerequisite checking,
  internal read-only rendering, and configuration planning
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

Read-only planning is available; apply remains unavailable. The internal
renderer exercises the source in isolated temporary output. Verify metadata
and preview the selected `.zshrc` target with:

~~~console
./bin/dotfiles module show shell.zsh
./bin/dotfiles resolve --modules shell.zsh --platform debian
./bin/dotfiles prerequisite check --modules shell.zsh --platform debian
./bin/dotfiles plan --modules shell.zsh --platform debian
~~~

The plan reports create or update for `.zshrc`, or `No changes.` A narrower Zsh
selection may update `.zshrc` to omit unselected integrations but never reports
or removes their separately owned files. These read-only commands need no
recovery. Planned apply will manage only explicitly selected configuration and
will not change the login shell.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Software installation
and login-shell changes are outside the product boundary.

## Tests and known limitations

Schema, ownership, exclusive-group, discovery, dependency resolution, profile
resolution, isolated command-presence tests, and macOS/Ubuntu CI cover this
module. Read-only `.zshrc` rendering and planning cover create, update,
no-change, stale optional state, privacy, and zero HOME mutation. Home
convergence and apply are deferred.

# Zsh

- Status: Available for discovery and resolution
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

The released schema-3 manifest declares the static `zsh` command prerequisite
on macOS and Debian. Catalog validation checks only the identifier; prerequisite
presence checking is not available. No chezmoi source or startup file is
selected yet.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Plan and apply are unavailable. Verify the released metadata with:

~~~console
./bin/dotfiles module show shell.zsh
./bin/dotfiles resolve --modules shell.zsh --platform debian
~~~

These read-only commands need no recovery. Planned apply will manage only
explicitly selected configuration and will not change the login shell.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Software installation
and login-shell changes are outside the product boundary.

## Tests and known limitations

Schema, ownership, exclusive-group, discovery, dependency resolution, profile
resolution, and macOS/Ubuntu CI cover this module. Prerequisite presence checks,
`.zshrc`, configuration plan, and apply are deferred.

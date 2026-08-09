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

## Provider requests and managed home state

Homebrew owns `zsh` on macOS and mise owns `zsh` on Debian. No chezmoi sources,
startup files, or other managed home files are selected yet.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Plan and apply are unavailable. Verify the released metadata with:

~~~console
./bin/dotfiles module show shell.zsh
./bin/dotfiles resolve --modules shell.zsh --platform debian
~~~

These read-only commands need no recovery. Package, login-shell, and home-state
recovery will be documented when their mutation behavior is implemented.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Future installation
and login-shell changes remain outside this release.

## Tests and known limitations

Schema, ownership, exclusive-group, discovery, dependency resolution, profile
resolution, and macOS/Ubuntu CI cover this module. Installation, `.zshrc`, shell
selection, provider observation, plan, apply, and removal are deferred.

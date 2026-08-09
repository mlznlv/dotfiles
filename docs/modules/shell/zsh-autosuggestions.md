# Zsh autosuggestions

- Status: Available for discovery and resolution
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

## Current catalog and planned configuration

The released schema-2 manifest contains historical Homebrew and mise requests;
no command acts on them. The schema migration must define a portable, testable
presence prerequisite without inferring it from those package names. No chezmoi
source or shell initialization file is selected yet.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Plan and apply are unavailable. Verify dependency expansion with:

~~~console
$ ./bin/dotfiles resolve --modules shell.zsh.autosuggestions --platform macos
shell.zsh
shell.zsh.autosuggestions
~~~

The command is read-only and needs no recovery. Planned startup-file recovery
will cover configuration only.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, command history, or machine identity.

## Tests and known limitations

Schema, dependency, ownership, discovery, profile resolution, and macOS/Ubuntu
CI cover this module. Prerequisite migration, initialization, configuration
plan, and apply are deferred.

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

## Provider requests and managed home state

Homebrew owns `zsh-autosuggestions` on macOS and mise owns it on Debian. No
chezmoi sources or shell initialization files are selected yet.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Plan and apply are unavailable. Verify dependency expansion with:

~~~console
$ ./bin/dotfiles resolve --modules shell.zsh.autosuggestions --platform macos
shell.zsh
shell.zsh.autosuggestions
~~~

The command is read-only and needs no recovery. Installation and startup-file
recovery are deferred with their implementations.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, command history, or machine identity.

## Tests and known limitations

Schema, dependency, ownership, discovery, profile resolution, and macOS/Ubuntu
CI cover this module. Installation, initialization, configuration, provider
observation, plan, apply, and removal are deferred.

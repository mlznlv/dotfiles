# Minimal shell

- Status: Available for discovery and resolution
- Intended targets: minimal interactive shell environments
- Supported platforms: macOS and Debian-family Linux
- Documentation owner: repository maintainer

## Intent and expected result

`shell.minimal` is the first curated profile. It describes Zsh with interactive
autosuggestions and a Starship prompt without workstation or remote-access
capabilities. Current commands preview the composition; they do not create that
state on a machine.

## Requested modules

- `shell.zsh` provides the primary interactive shell.
- `shell.zsh.autosuggestions` provides command suggestions.
- `prompt.starship` provides an independent cross-shell prompt.

## Resolved dependencies

Autosuggestions depends on `shell.zsh`, which the profile already requests.
Starship has no shell dependency. The deterministic result is:

~~~text
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

## Optional additions and conflicts

Users may add any released platform-compatible module that does not conflict or
share `shell.primary` or `prompt.primary`. No optional production modules are
released yet. Workstation, remote-access, and security capabilities are outside
this profile.

## Selection and planning

Discovery and resolution are available:

~~~console
./bin/dotfiles profile show shell.minimal
./bin/dotfiles resolve --profile shell.minimal --platform debian
~~~

Provider observation and `dotfiles plan` are unavailable.

## Security, privacy, and connectivity

Released commands invoke no providers, network access, privilege escalation,
home-state writes, secrets, or machine identity. The catalog declares future
Homebrew and mise requests; their effects will be disclosed when planning is
implemented.

## Verification and recovery

Run `catalog validate`, `profile show`, and `resolve` for either supported
platform. These operations are read-only, so recovery consists of correcting
invalid catalog or selection input and retrying. No rollback or removal exists.

## Tests and known limitations

Production discovery, show, macOS and Debian resolution, dependency ordering,
provider non-invocation, and macOS/Ubuntu CI cover the profile. Package
installation, managed home state, provider observation, plan, apply, saving,
rollback, and removal are deferred.

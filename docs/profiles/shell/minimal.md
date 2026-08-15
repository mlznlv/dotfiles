# Minimal shell

- Status: Available for discovery, resolution, prerequisite checking, and
  internal read-only rendering
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
./bin/dotfiles prerequisite check --profile shell.minimal --platform debian
~~~

Command and artifact prerequisite checks are available. Application checks and
`dotfiles plan` are unavailable.

The internal ADR-0010 renderer selects exactly
`.zshrc`, `.config/zsh/autosuggestions.zsh`, and `.config/starship.toml`.
The Zsh-owned startup target activates autosuggestions from its validated
canonical artifact path and then Starship, without scanning stale fragments.
Rendering a smaller Zsh composition omits optional activation lines while
leaving old optional files untouched in isolated output. No public render
command, plan, apply, or home mutation is available.

## Security, privacy, and connectivity

Released commands invoke no providers, prerequisites, network access, privilege
escalation, or home-state writes. Presence checks inspect executable and
artifact metadata only and never install the named tools.

## Verification and recovery

Run `catalog validate`, `profile show`, and `resolve` for either supported
platform. These operations are read-only, so recovery consists of correcting
invalid catalog or selection input and retrying. No rollback or removal exists.

## Tests and known limitations

Production discovery, show, macOS and Debian resolution, dependency ordering,
provider/prerequisite non-invocation, isolated presence fixtures, and
macOS/Ubuntu CI cover the profile. The complete read-only target and activation
matrix is also tested on both platform inputs. Application checks, managed home
state, configuration plan, apply, saving, and recovery are deferred.

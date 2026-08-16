# Starship

- Status: Available for discovery, resolution, prerequisite checking,
  internal read-only rendering, and configuration planning
- Category: prompt
- Supported platforms: macOS and Debian-family Linux
- Documentation owner: repository maintainer

## Purpose and result

`prompt.starship` declares the cross-shell Starship prompt as an independent
prompt layer. Current commands expose its catalog intent but do not install or
configure Starship.

## Dependencies and conflicts

The module has no dependencies or declared conflicts and belongs to the
`prompt.primary` exclusive group. A profile may combine it with any compatible
shell module.

## Prerequisites and managed configuration

The schema-1 manifest declares `starship` on macOS and Debian.
`prerequisite check` locates an external executable file through absolute PATH
entries without invoking it. No managed file is applied to the user's home.

Accepted ADR 0010 assigns this module only
`home/dot_config/starship.toml`, rendered as `.config/starship.toml`. The
initial configuration disables the extra blank prompt line and otherwise uses
portable built-in modules. Starship remains selectable without Zsh and never
owns `.zshrc`.
When both modules are in one resolved explicit composition, the Zsh-owned
template emits exactly one static `starship init zsh` activation. The internal
renderer produces these targets only in isolated output.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Read-only planning is available; apply remains unavailable. Inspect metadata
and preview only the Starship-owned target with:

~~~console
./bin/dotfiles module show prompt.starship
./bin/dotfiles resolve --modules prompt.starship --platform debian
./bin/dotfiles prerequisite check --modules prompt.starship --platform debian
./bin/dotfiles plan --modules prompt.starship --platform debian
~~~

The plan can report create or update for `.config/starship.toml`, or
`No changes.` It never selects or inspects `.zshrc`. These commands and internal
rendering are read-only. Correct invalid input or prerequisites and rerun them;
configuration recovery is deferred with apply.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Software installation
is outside the product boundary.

## Tests and known limitations

Schema, current ownership, discovery, explicit resolution, profile resolution,
isolated command-presence tests, and macOS/Ubuntu CI cover this module. Isolated
Starship-only and Zsh-composed rendering and planning are covered, including
selected-path scope and zero HOME mutation. Managed home configuration and
apply are deferred.

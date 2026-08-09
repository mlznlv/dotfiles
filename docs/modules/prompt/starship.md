# Starship

- Status: Available for discovery and resolution
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

## Provider requests and managed home state

Homebrew owns the `starship` formula on macOS. Mise owns the `starship` tool on
Debian. No chezmoi sources or managed files are selected in this increment.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Plan and apply are unavailable. Verify metadata with:

~~~console
./bin/dotfiles module show prompt.starship
./bin/dotfiles resolve --modules prompt.starship --platform debian
~~~

These commands are read-only. They require no recovery; correct invalid catalog
data and rerun them. Package or configuration recovery is deferred with apply.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Future installation
may use the network and remains outside this release.

## Tests and known limitations

Schema, provider ownership, discovery, explicit resolution, profile resolution,
and macOS/Ubuntu CI cover this module. Installation, shell initialization,
managed configuration, provider observation, plan, apply, and removal are
deferred.

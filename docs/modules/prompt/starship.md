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

## Current catalog and planned configuration

The released schema-2 manifest contains historical Homebrew and mise requests;
no command acts on them. ADR 0007 requires migrating them to a static
`starship` command prerequisite. No chezmoi source or managed file is selected.

## Options

There are no module options or local defaults.

## Plan, apply, verification, and recovery

Plan and apply are unavailable. Verify metadata with:

~~~console
./bin/dotfiles module show prompt.starship
./bin/dotfiles resolve --modules prompt.starship --platform debian
~~~

These commands are read-only. They require no recovery; correct invalid catalog
data and rerun them. Configuration recovery is deferred with apply.

## Platform, security, and privacy notes

Only macOS and Debian-family Linux are supported. Discovery uses no network,
privilege, provider process, secret, or machine identity. Software installation
is outside the product boundary.

## Tests and known limitations

Schema, current ownership, discovery, explicit resolution, profile resolution,
and macOS/Ubuntu CI cover this module. Prerequisite migration, shell
initialization, managed configuration, plan, and apply are deferred.

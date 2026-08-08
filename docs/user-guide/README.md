# User guide

This guide documents every user-visible capability currently available on the
default branch.

> [!IMPORTANT]
> The current release is read-only. It can inspect, validate, and resolve catalog
> data, but it cannot install packages, write configuration, save selections, or
> apply home state.

## What works today

| Capability | Available | Changes the machine |
| --- | --- | --- |
| Show CLI help and version | Yes | No |
| Validate the catalog | Yes | No |
| List and inspect modules | Yes | No |
| List and inspect profiles | Yes | No |
| Resolve a profile | Yes | No |
| Resolve a custom module set | Yes | No |
| Add modules to a base composition | Yes | No |
| Install packages or applications | No | Not implemented |
| Save, import, or export profiles | No | Not implemented |
| Plan or apply configuration | No | Not implemented |

The production module and profile catalogs are empty until Phase 3. Discovery
commands therefore return no entries today, and lookup or resolution commands
reject example identifiers as unknown. Populated-catalog examples below show the
implemented output contract without claiming that those entries are released.

## Requirements

You need:

- A local copy of this repository.
- Bash to run the CLI.
- Chezmoi on PATH for catalog, module, profile, and resolve commands.
- macOS or Debian-family Linux for automatic platform detection.

Help and version do not require chezmoi. The CLI itself does not require root
privileges or make network requests. Follow the
[official chezmoi installation guide](https://www.chezmoi.io/install/) when the
dependency is not already available.

## Get the repository

~~~text
git clone https://github.com/mlznlv/dotfiles.git
cd dotfiles
~~~

The current CLI is run directly from the repository root:

~~~text
./bin/dotfiles help
~~~

There is no bootstrap or installation command in this release.

## Quick start

Check the CLI version:

~~~text
./bin/dotfiles version
dotfiles 0.1.0-dev
~~~

Review all available commands:

~~~text
./bin/dotfiles help
~~~

Validate the production catalog:

~~~text
./bin/dotfiles catalog validate
catalog valid: 0 modules, 0 profiles
~~~

List every released module and profile:

~~~text
./bin/dotfiles module list --all
./bin/dotfiles profile list --all
~~~

Both list commands succeed without output because the production catalogs are
currently empty.

## Command model

Every available command is read-only. Commands use three kinds of selection:

- A module is one selectable capability, identified by a dotted name such as
  shell.zsh.
- A profile is a named composition of module identifiers, such as
  shell.minimal.
- An explicit composition is a comma-separated module set supplied for one
  resolution without saving a profile.

Module and profile identifiers are stable catalog data. Users are not expected
to edit TOML to use the CLI.

## Platform selection

The values accepted by --platform are:

- macos
- debian

The debian value represents the supported Debian family, including Debian,
Ubuntu, and Kali.

Without --platform, list and resolve commands detect the platform:

- Darwin maps to macos.
- Linux maps to debian when /etc/os-release identifies a Debian-family system.
- Other operating systems fail as unsupported.

Use an explicit platform to preview compatibility for a different supported
target:

~~~text
./bin/dotfiles module list --platform debian
./bin/dotfiles profile list --platform macos
~~~

Use --all to disable platform filtering:

~~~text
./bin/dotfiles module list --all
./bin/dotfiles profile list --all
~~~

The --all and --platform flags cannot be combined.

## Show help

The help command prints the complete available command surface:

~~~text
./bin/dotfiles help
./bin/dotfiles --help
./bin/dotfiles -h
~~~

It reads no catalog or machine configuration and always remains safe to run.
See the [help command reference](../cli/help.md).

## Show the version

Use either supported form:

~~~text
./bin/dotfiles version
./bin/dotfiles --version
~~~

Current output:

~~~text
dotfiles 0.1.0-dev
~~~

See the [version command reference](../cli/version.md).

## Validate the catalog

Run validation before diagnosing discovery or resolution behavior:

~~~text
./bin/dotfiles catalog validate
~~~

Current output:

~~~text
catalog valid: 0 modules, 0 profiles
~~~

Validation checks:

- Manifest locations and one catalog table per file.
- TOML parsing and merged data through chezmoi.
- Schema versions and required fields.
- Module and profile identifiers.
- Documentation path conventions.
- Platforms, dependencies, conflicts, and exclusive groups.
- Unknown references and dependency cycles.

Validation never applies chezmoi state. See the
[catalog validation reference](../cli/catalog/validate.md).

## List modules

Detect the local platform and list compatible modules:

~~~text
./bin/dotfiles module list
~~~

Preview a supported platform explicitly:

~~~text
./bin/dotfiles module list --platform macos
./bin/dotfiles module list --platform debian
~~~

List all modules without filtering:

~~~text
./bin/dotfiles module list --all
~~~

The current catalog produces no output and exits successfully. In a populated
catalog, output is tab-separated and ordered by identifier:

~~~text
prompt.starship    Starship    Cross-shell prompt renderer
shell.zsh    Zsh    Interactive Zsh shell experience
shell.zsh.autosuggestions    Zsh autosuggestions    Interactive history suggestions
~~~

See the [module list reference](../cli/module/list.md).

## Inspect a module

Show one module by its dotted identifier:

~~~text
./bin/dotfiles module show shell.zsh.autosuggestions
~~~

Because Phase 2 has no production modules, the command currently reports:

~~~text
error: unknown module shell.zsh.autosuggestions
~~~

Once that planned entry is released, representative output is:

~~~text
id: shell.zsh.autosuggestions
name: Zsh autosuggestions
summary: Interactive history suggestions
platforms: macos,debian
depends: shell.zsh
conflicts: -
exclusive group: -
docs: docs/modules/shell/zsh-autosuggestions.md
~~~

The command displays direct metadata; it does not expand dependencies. See the
[module show reference](../cli/module/show.md).

## List profiles

Detect the local platform and list compatible profiles:

~~~text
./bin/dotfiles profile list
~~~

Preview one supported platform or list every profile:

~~~text
./bin/dotfiles profile list --platform macos
./bin/dotfiles profile list --platform debian
./bin/dotfiles profile list --all
~~~

The current catalog produces no output and exits successfully. A populated
catalog uses tab-separated output:

~~~text
shell.minimal    Minimal shell    Zsh, autosuggestions, and Starship
~~~

See the [profile list reference](../cli/profile/list.md).

## Inspect a profile

Show one profile and its requested modules:

~~~text
./bin/dotfiles profile show shell.minimal
~~~

The current empty catalog reports:

~~~text
error: unknown profile shell.minimal
~~~

Representative output after the planned profile is released:

~~~text
id: shell.minimal
name: Minimal shell
summary: Zsh, autosuggestions, and Starship
platforms: macos,debian
modules: shell.zsh,shell.zsh.autosuggestions,prompt.starship
docs: docs/profiles/shell/minimal.md
~~~

Use resolve when dependency expansion or platform validation is required. See
the [profile show reference](../cli/profile/show.md).

## Resolve a profile

Select exactly one profile and optionally override the platform:

~~~text
./bin/dotfiles resolve --profile shell.minimal --platform debian
~~~

The current empty catalog returns an unknown-profile error. With the planned
profile present, the deterministic result is one module per line:

~~~text
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

Dependencies appear before the modules that require them.

## Resolve a custom composition

Supply a comma-separated module set instead of a profile:

~~~text
./bin/dotfiles resolve \
  --modules shell.zsh.autosuggestions,prompt.starship \
  --platform macos
~~~

With those planned modules present, shell.zsh is included automatically because
shell.zsh.autosuggestions depends on it:

~~~text
shell.zsh
shell.zsh.autosuggestions
prompt.starship
~~~

The command does not save the custom composition.

## Add modules to a composition

Use --add with either a profile or an explicit base:

~~~text
./bin/dotfiles resolve \
  --profile shell.minimal \
  --add prompt.starship \
  --platform macos
~~~

~~~text
./bin/dotfiles resolve \
  --modules shell.zsh.autosuggestions \
  --add prompt.starship \
  --platform debian
~~~

Duplicate selections are de-duplicated. Dependencies still appear before their
dependents. See the [resolve reference](../cli/resolve.md).

## Resolution failures

Resolution rejects unsafe or impossible combinations before printing a result.

An unknown identifier:

~~~text
./bin/dotfiles resolve --modules shell.unknown --platform debian
error: unknown module shell.unknown
~~~

A module that does not support the selected platform:

~~~text
error: module terminal.ghostty does not support platform debian
~~~

Two modules in one exclusive group:

~~~text
error: modules terminal.ghostty and terminal.wezterm share exclusive group terminal.primary
~~~

A dependency cycle, missing dependency, invalid catalog, or conflict also exits
without a partial resolution.

## Usage errors

Invalid command syntax exits with status 2 and points to help:

~~~text
./bin/dotfiles resolve
error: resolve requires --profile or --modules
Run dotfiles help for usage.
~~~

Mutually exclusive base selections are rejected:

~~~text
./bin/dotfiles resolve \
  --profile shell.minimal \
  --modules shell.zsh
error: --profile and --modules are mutually exclusive
Run dotfiles help for usage.
~~~

## Exit statuses

| Status | Meaning |
| --- | --- |
| 0 | Success, including an empty list |
| 2 | Invalid command usage |
| 3 | Unsupported platform, invalid catalog, or failed resolution |
| 4 | Chezmoi or an internal implementation file is unavailable |

Inspect the status immediately after a command when scripting:

~~~text
./bin/dotfiles catalog validate
echo $?
~~~

No stable machine-readable format is promised beyond the documented line and
tab-separated outputs.

## Troubleshooting

### Chezmoi is required

~~~text
error: chezmoi is required for catalog commands
~~~

Install chezmoi, confirm chezmoi --version succeeds, and run the command again.
Help and version remain available without it.

### The module or profile list is empty

This is expected in Phase 2. The production catalog intentionally contains zero
modules and zero profiles.

### The operating system is unsupported

Pass --platform macos or --platform debian only when intentionally previewing a
supported target. Automatic detection supports macOS and Debian-family Linux.

### A module or profile is unknown

Use module list --all or profile list --all to discover released identifiers.
Planned identifiers in this guide remain unavailable until they enter the
production catalog.

### Catalog validation fails

Read the first error, correct the versioned catalog entry, and rerun:

~~~text
./bin/dotfiles catalog validate
~~~

Catalog maintenance details are in the [catalog contract](../catalog.md).

## Security and privacy

The available CLI:

- Does not install, remove, or upgrade packages.
- Does not write home configuration.
- Does not invoke Homebrew, mise, or a provider.
- Does not apply chezmoi state.
- Does not request elevated privileges.
- Does not read secrets, hostnames, usernames, or private infrastructure.
- Reads only versioned catalog data and factual operating-system information.

Do not put credentials, hostnames, private addresses, machine identity, or local
absolute paths in catalog or profile data. Report security issues according to
the [security policy](../../SECURITY.md).

## Not available yet

The following user workflows remain planned:

- Installing or bootstrapping the environment.
- Selecting and saving a default profile.
- Planning provider and home-state changes.
- Applying or rolling back configuration.
- Importing, exporting, or sharing custom profiles.
- Diagnostics and repair commands.
- Released production modules and profiles.

Track delivery order in the [roadmap](../roadmap.md). The CLI reference documents
only behavior that exists on the current default branch.

## Detailed command reference

- [help](../cli/help.md)
- [version](../cli/version.md)
- [catalog validate](../cli/catalog/validate.md)
- [module list](../cli/module/list.md)
- [module show](../cli/module/show.md)
- [profile list](../cli/profile/list.md)
- [profile show](../cli/profile/show.md)
- [resolve](../cli/resolve.md)

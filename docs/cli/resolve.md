# dotfiles resolve

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

Validate and expand a profile or explicit module composition for one platform.

## Usage

~~~text
dotfiles resolve --profile <profile-id> [--add <id,id>] [--platform macos|debian]
dotfiles resolve --modules <id,id> [--add <id,id>] [--platform macos|debian]
~~~

## Flags

- --profile selects one curated or saved catalog profile.
- --modules supplies an explicit comma-separated base composition.
- --add supplies optional additional module identifiers.
- --platform overrides factual local platform detection.
- --profile and --modules are mutually exclusive.

## Behavior

The command validates the full catalog, expands dependencies in lexical order,
de-duplicates modules, validates platform compatibility, and rejects conflicts
or exclusive-group collisions.

Output is deterministic for identical catalog and command inputs. Dependency
identifiers appear before the modules that require them.

The command does not save the composition, produce a provider plan, or apply
changes.

## Output

One resolved module identifier per line.

## Examples

Resolve one profile for Debian-family Linux:

~~~text
./bin/dotfiles resolve --profile shell.minimal --platform debian
~~~

Resolve an explicit custom set:

~~~text
./bin/dotfiles resolve \
  --modules shell.zsh.autosuggestions,prompt.starship \
  --platform macos
~~~

Add a module to a base composition:

~~~text
./bin/dotfiles resolve \
  --modules shell.zsh.autosuggestions \
  --add prompt.starship \
  --platform debian
~~~

The production catalog is empty in Phase 2, so these planned identifiers are
currently rejected as unknown. The [user guide](../user-guide/README.md) shows
representative successful output, dependency expansion, and failure examples.

## Exit statuses

- 0: The composition resolved successfully.
- 2: Required or mutually exclusive arguments were invalid.
- 3: Platform, catalog, identifier, dependency, or conflict validation failed.
- 4: Chezmoi is unavailable.

## Security and privacy

Resolution uses static repository data and factual platform information. It
does not inspect hostname, username, credentials, or provider state.

## Tests

CI covers curated and custom composition, additional modules, dependency order,
unknown identifiers, unsupported platforms, cycles, and exclusive groups.

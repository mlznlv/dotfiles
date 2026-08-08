# dotfiles catalog validate

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

Validate the complete module and profile catalog before discovery or
resolution.

## Usage

~~~text
dotfiles catalog validate
~~~

## Behavior

The command:

1. Verifies canonical category paths and one TOML table per manifest.
2. Uses chezmoi to parse and merge static catalog TOML.
3. Rejects unknown fields, schema mismatches, invalid identifiers, bad
   documentation paths, unknown references, incompatible platform claims, and
   dependency cycles.
4. Prints catalog counts on success.

The command does not apply chezmoi state or invoke providers.

## Output

~~~text
catalog valid: 0 modules, 0 profiles
~~~

The production catalog is empty until Phase 3.

## Exit statuses

- 0: The catalog is valid.
- 3: Catalog parsing or semantic validation failed.
- 4: Chezmoi or an internal implementation file is unavailable.

## Security and privacy

Catalog data is static and never evaluated as shell source. No network or
privileged operation is performed by the command.

## Tests

Fixtures cover valid catalogs, cycles, missing dependencies, unknown fields, and
category-path mismatches on macOS and Ubuntu.

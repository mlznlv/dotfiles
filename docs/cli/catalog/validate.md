# Validate the catalog

[Command guide](../README.md) / Catalog validation

Check every module and profile definition before discovery or resolution.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles catalog validate
~~~

## Example

~~~console
$ ./bin/dotfiles catalog validate
catalog valid: 0 modules, 0 profiles
~~~

The zero counts are expected until Phase 3.

Validation checks manifest paths, TOML structure, schema fields, identifiers,
documentation paths, platforms, dependencies, conflicts, profile references,
and dependency cycles. It never applies chezmoi state or calls a provider.

## Exit codes

- `0` — the catalog is valid.
- `3` — parsing or validation failed.
- `4` — chezmoi or an internal CLI file is unavailable.

If validation fails, fix the first reported error and run the command again.
Catalog maintainers can read the [catalog contract](../../catalog.md).

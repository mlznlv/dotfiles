# dotfiles module show

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

Inspect one module's resolution metadata.

## Usage

~~~text
dotfiles module show <module-id>
~~~

## Arguments

module-id is one stable dotted module identifier.

## Behavior

The complete catalog is validated before lookup. The command displays the
module name, summary, platforms, dependencies, conflicts, exclusive group, and
documentation path. It does not resolve dependencies or invoke a provider.

## Output

Human-readable labeled fields. Empty dependency, conflict, or group values are
shown as a hyphen.

## Examples

Inspect a planned module identifier:

~~~text
./bin/dotfiles module show shell.zsh.autosuggestions
~~~

The Phase 2 catalog is empty, so the current result is:

~~~text
error: unknown module shell.zsh.autosuggestions
~~~

Representative output after that entry is released is shown in the
[user guide](../../user-guide/README.md).

## Exit statuses

- 0: The module was displayed.
- 2: The identifier argument was missing or duplicated.
- 3: The identifier was unknown or the catalog was invalid.
- 4: Chezmoi is unavailable.

## Security and privacy

Only versioned static catalog data is displayed.

## Tests

CI covers known and unknown identifiers and dependency metadata.

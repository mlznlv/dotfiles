# dotfiles profile show

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

Inspect one profile and its explicitly requested modules.

## Usage

~~~text
dotfiles profile show <profile-id>
~~~

## Arguments

profile-id is one stable dotted profile identifier.

## Behavior

The complete catalog is validated before lookup. The command displays profile
metadata and the requested module list. Use dotfiles resolve to expand
dependencies for a target platform.

Importing, selecting, or applying a profile is not part of this command.

## Examples

Inspect the planned minimal shell profile:

~~~text
./bin/dotfiles profile show shell.minimal
~~~

The Phase 2 catalog is empty, so the current result is:

~~~text
error: unknown profile shell.minimal
~~~

Representative populated-catalog output is shown in the
[user guide](../../user-guide/README.md).

## Exit statuses

- 0: The profile was displayed.
- 2: The identifier argument was missing or duplicated.
- 3: The identifier was unknown or the catalog was invalid.
- 4: Chezmoi is unavailable.

## Security and privacy

Only versioned static catalog data is displayed.

## Tests

CI covers requested-module output and unknown profiles.

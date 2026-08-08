# dotfiles profile list

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

List profiles compatible with a platform or inspect every catalog entry.

## Usage

~~~text
dotfiles profile list
dotfiles profile list --platform macos
dotfiles profile list --platform debian
dotfiles profile list --all
~~~

## Flags

- --platform selects macos or debian instead of detecting the local platform.
- --all disables platform filtering.
- --platform and --all are mutually exclusive.

## Behavior

The complete catalog is validated first. Results are ordered lexically by
profile identifier. The current production catalog is empty.

## Output

Each result is tab-separated:

~~~text
identifier    name    summary
~~~

## Examples

List every released profile:

~~~text
./bin/dotfiles profile list --all
~~~

The current empty catalog exits successfully without output. Preview one
supported platform:

~~~text
./bin/dotfiles profile list --platform macos
~~~

Representative populated-catalog output is tab-separated:

~~~text
shell.minimal    Minimal shell    Zsh, autosuggestions, and Starship
~~~

See the [user guide](../../user-guide/README.md) for the complete discovery
workflow.

## Exit statuses

- 0: Listing completed, including an empty result.
- 2: Arguments were invalid.
- 3: Platform or catalog validation failed.
- 4: Chezmoi is unavailable.

## Security and privacy

The command reads only static catalog data and factual platform information.

## Tests

CI covers explicit platform filtering and profile discovery.

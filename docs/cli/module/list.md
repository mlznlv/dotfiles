# dotfiles module list

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

List modules compatible with a platform or inspect every catalog entry.

## Usage

~~~text
dotfiles module list
dotfiles module list --platform macos
dotfiles module list --platform debian
dotfiles module list --all
~~~

## Flags

- --platform selects macos or debian instead of detecting the local platform.
- --all disables platform filtering.
- --platform and --all are mutually exclusive.

## Behavior

The complete catalog is validated first. Without flags, macOS is detected from
Darwin. Linux is supported when /etc/os-release identifies a Debian-family
distribution.

Entries are printed in lexical identifier order. The current production catalog
is empty.

## Output

Each result is tab-separated:

~~~text
identifier    name    summary
~~~

## Examples

List every released module:

~~~text
./bin/dotfiles module list --all
~~~

The current empty catalog exits successfully without output. Preview a supported
platform explicitly:

~~~text
./bin/dotfiles module list --platform debian
~~~

Representative populated-catalog output is tab-separated:

~~~text
prompt.starship    Starship    Cross-shell prompt renderer
shell.zsh    Zsh    Interactive Zsh shell experience
~~~

See the [user guide](../../user-guide/README.md) for platform detection and
current release limitations.

## Exit statuses

- 0: Listing completed, including an empty result.
- 2: Arguments were invalid.
- 3: Platform or catalog validation failed.
- 4: Chezmoi is unavailable.

## Security and privacy

Platform detection reads only operating-system facts. It does not read a
hostname, username, or machine identity.

## Tests

CI covers explicit platform filtering, all-entry listing, and empty catalogs.

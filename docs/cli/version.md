# dotfiles version

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

Print the development version of the repository CLI.

## Usage

~~~text
dotfiles version
dotfiles --version
~~~

## Behavior

The command reads no catalog and does not require chezmoi. Until the first
release, the version carries a development suffix.

## Output

~~~text
dotfiles 0.1.0-dev
~~~

## Exit statuses

- 0: Version information was displayed.
- 2: Unexpected arguments were supplied.

## Security and privacy

The command emits no machine or repository identity.

## Tests

CI checks the exact version output on macOS and Ubuntu.

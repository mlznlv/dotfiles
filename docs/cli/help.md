# dotfiles help

- Status: Available
- Effect: Read-only
- Introduced in: Phase 2

## Purpose

Show the supported command surface and state that every currently available
command is read-only.

## Usage

~~~text
dotfiles help
dotfiles --help
dotfiles -h
~~~

## Behavior

The command reads no catalog or machine configuration and does not require
chezmoi.

## Output

Human-readable usage on standard output.

## Exit statuses

- 0: Help was displayed.
- 2: Unexpected arguments were supplied.

## Security and privacy

The command performs no network, file, provider, or privilege operation.

## Tests

CI checks the help contract on macOS and Ubuntu.

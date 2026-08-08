# Inspect a profile

[Command guide](../README.md) / Profiles / Show

Show one profile and the modules it explicitly requests.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles profile show <profile-id>
~~~

Get identifiers from `dotfiles profile list --all`. A profile identifier is a
stable dotted name such as `shell.minimal`.

## Example

~~~console
./bin/dotfiles profile show shell.minimal
~~~

The example identifier is planned and currently returns `unknown profile`. Once
released, output follows this format:

~~~text
id: shell.minimal
name: Minimal shell
summary: Zsh, autosuggestions, and Starship
platforms: macos,debian
modules: shell.zsh,shell.zsh.autosuggestions,prompt.starship
docs: docs/profiles/shell/minimal.md
~~~

This command shows only the modules requested by the profile. Use
[`resolve`](../resolve.md) to expand dependencies and check platform support.

## Exit codes

- `0` — the profile was displayed.
- `2` — exactly one identifier was not supplied.
- `3` — the identifier is unknown or the catalog is invalid.
- `4` — chezmoi is unavailable.

Back to [list profiles](list.md) or the [command guide](../README.md).

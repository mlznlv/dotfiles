# Inspect a module

[Command guide](../README.md) / Modules / Show

Show the metadata stored for one module identifier.

Available · Read-only · Chezmoi required.

## Usage

~~~text
dotfiles module show <module-id>
~~~

Get identifiers from `dotfiles module list --all`. A module identifier is a
stable dotted name such as `shell.zsh.autosuggestions`.

## Example

~~~console
./bin/dotfiles module show shell.zsh.autosuggestions
~~~

The example identifier is released. Output follows this format:

~~~text
id: shell.zsh.autosuggestions
name: Zsh autosuggestions
summary: Interactive command suggestions for Zsh
platforms: macos,debian
depends: shell.zsh
conflicts: -
exclusive group: -
docs: docs/modules/shell/zsh-autosuggestions.md
~~~

This command shows direct metadata. It does not expand dependencies, locate
prerequisites, or call a provider; use [`resolve`](../resolve.md) to preview the
final composition.

## Exit codes

- `0` — the module was displayed.
- `2` — exactly one identifier was not supplied.
- `3` — the identifier is unknown or the catalog is invalid.
- `4` — chezmoi is unavailable.

Back to [list modules](list.md) or the [command guide](../README.md).

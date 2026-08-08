# Show the version

[Command guide](README.md) / Version

Print the current CLI version.

Available · Read-only · Chezmoi not required.

## Usage

~~~text
dotfiles version
dotfiles --version
~~~

## Example

~~~console
$ ./bin/dotfiles version
dotfiles 0.1.0-dev
~~~

Both forms produce the same output. Development builds use the `-dev` suffix.
The command does not read the catalog or expose machine identity.

## Exit codes

- `0` — the version was printed.
- `2` — an unexpected argument was supplied.

Next: [validate the catalog](catalog/validate.md) or return to the
[command guide](README.md).

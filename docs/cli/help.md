# Show help

[Command guide](README.md) / Help

Print the complete command list and syntax summary.

Available · Read-only · Chezmoi not required.

## Usage

~~~text
dotfiles help
dotfiles --help
dotfiles -h
~~~

Run it from the repository root:

~~~console
./bin/dotfiles help
~~~

All three forms print the same human-readable output. The command does not read
the catalog or inspect the machine.

## Exit codes

- `0` — help was printed.
- `2` — an unexpected argument was supplied.

Next: [check the version](version.md) or return to the
[command guide](README.md).

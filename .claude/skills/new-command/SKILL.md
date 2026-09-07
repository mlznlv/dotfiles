---
name: new-command
description: Add a dotfiles CLI command with its help text, reference page, index entries, and tests.
argument-hint: "[command, e.g. status]"
allowed-tools: Read Write Edit Grep Glob Bash(./bin/dotfiles help *) Bash(./bin/dotfiles version *) Bash(bash scripts/check.sh *) Bash(bash scripts/check-maintainability.sh *)
---

# Add a CLI command

`CONTRIBUTING.md` requires five things of every command: built-in help, a
reference page, examples with exit codes, tests, and a clear statement of the
files and state it may change. Several live in files the command itself does not
touch.

## The help text is asserted byte for byte

`tests/maintainability/execution-and-portability.sh` holds the **entire expected
help output** as a literal and compares it with `check_equal 'help output remains
byte-for-byte stable'`. `tests/run.sh` separately asserts one of its closing
sentences.

So the usage block in the CLI, that literal, and the closing sentences describing
what mutates all change together. Miss the literal and the suite fails with a
message about help stability rather than about the new command, which is a slow
thing to diagnose. Update it in the same edit as the usage block.

If the command mutates anything, the closing sentences must say so, and
`docs/cli/README.md`'s safety wording must agree.

## Implement it

- `bin/dotfiles` is a thin bootstrap limited to **250 physical lines** and keeps
  only top-level dispatch. Command logic belongs in `lib/cli/`, beside
  `catalog.sh`, `selection.sh`, `config-commands.sh`, and
  `execution-commands.sh`.
- If a new `lib/cli/` module is needed, add it to the **fixed source list** in
  `lib/cli.sh`, in one-way dependency order, and update the manifest comment.
  Never add a glob, a directory scan, or a `PATH` lookup.
- Group subcommands the way `catalog`, `module`, `profile`, `config`, and
  `prerequisite` do rather than adding another top-level verb.
- Parse arguments in the established style: `usage_error` for bad syntax,
  `-h|--help` calling `usage`, and numeric return codes propagated by the
  caller. Shell runs under `set -u` and not `set -e`, so a function that swallows
  a non-zero return breaks the exit-code contract.
- Respect the 500-line limit on `lib/` files; split by responsibility rather
  than trimming diagnostics to fit.

## Use the established exit codes

Do not invent new ones. `0` success, `2` invalid syntax, `3` invalid selection or
catalog or composition data, `4` an unavailable component or uncertain result,
`5` a missing prerequisite or failed comparison, `6` an apply or verification
failure, and `129`, `130`, `143` for handled HUP, INT, and TERM.
`docs/cli/README.md` owns the table. Errors go to standard error, and a syntax
error also points at `dotfiles help`.

## Write the reference page

The path mirrors the command group: a top-level command is
`docs/cli/<command>.md`, a subcommand is `docs/cli/<group>/<subcommand>.md`, as
`config doctor` maps to `docs/cli/config/doctor.md`.

Follow the page order in `docs/cli/command-template.md`, and read an existing
page such as `docs/cli/plan.md` for the established voice. Work through the
template's review checklist before finishing.

## Update the index

`docs/cli/README.md` carries the command table and the exit-code table. Add the
command to the one matching its real status, and move a row between released and
planned only in the change that releases it.

## Add tests

Assert that the command appears in help, that each documented exit code is
produced by a real failure case including `2` for a syntax error, and that a
read-only command stays read-only. The suites assert that no provider, pager,
editor, external diff, network, or privilege helper is invoked; a command that
shells out to one will trip that check.

Test files are limited to 500 physical lines and decomposed suite runners to
150, so add cases to the right case file rather than growing a runner.

## Verify

```bash
./bin/dotfiles help
bash scripts/check-maintainability.sh
bash scripts/check.sh
```

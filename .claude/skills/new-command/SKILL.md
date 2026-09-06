---
name: new-command
description: Add a dotfiles CLI command with its help text, reference page, index entries, and tests.
argument-hint: "[command, e.g. plan]"
allowed-tools: Read Write Edit Grep Glob Bash(./bin/dotfiles *) Bash(bash scripts/check.sh *) Bash(bash tests/run.sh *)
---

# Add a CLI command

`CONTRIBUTING.md` requires five things of every command: built-in help, a
reference page, examples with exit codes, tests, and a clear statement of the
files and state it may change. They ship in one change, and two of them live in
files the command itself does not touch.

## Check the roadmap first

`dotfiles plan` and `dotfiles apply` are specified but not released; they belong
to Phase 3 increments 4 and 6, and each depends on the increments before it. If
the request is for a command whose contract has not been accepted, say so before
implementing. Documenting a planned command is always allowed; presenting it as
available is not.

## Implement in `bin/dotfiles`

- Add the invocation to the `usage()` heredoc. This is the built-in help, and it
  is the only place users see the command's syntax.
- Add a branch to the `case` in `main()`. Group subcommands the way `catalog`,
  `module`, and `profile` do rather than adding a second top-level verb.
- Parse arguments in a dedicated function that follows the existing style:
  `usage_error` for bad syntax, `-h|--help` calling `usage`, and numeric return
  codes propagated by the caller. The script runs under `set -u` and not
  `set -e`, so a function that swallows a non-zero return silently breaks the
  exit-code contract.

**If the command mutates anything,** the help text's closing line —
`All commands in this release are read-only.` — stops being true. It is asserted
in `tests/run.sh` by the `help is available` check, so the line, the assertion,
and the safety statements in `docs/cli/README.md` all change together.

## Use the established exit codes

Do not invent new ones:

| Code | Meaning |
| --- | --- |
| `0` | Success, including an empty result |
| `2` | Invalid command syntax |
| `3` | Unsupported platform, invalid catalog, or failed resolution |
| `4` | Chezmoi or an internal CLI file is unavailable |

Errors go to standard error. A syntax error also points at `dotfiles help`.

## Write the reference page

Path mirrors the command group. A top-level command is
`docs/cli/<command>.md`; a subcommand is `docs/cli/<group>/<subcommand>.md`,
as `catalog validate` maps to `docs/cli/catalog/validate.md`.

Follow the page order in `docs/cli/command-template.md` and read an existing
page such as `docs/cli/resolve.md` for the established voice. Begin with the
breadcrumb, a task-oriented title, one sentence of purpose, and the
availability line — `Available · Read-only · Chezmoi required.` — then usage,
options, examples, what it returns, common failures, and exit codes. Close with
links onward. Work through the template's review checklist before finishing.

## Update the index

`docs/cli/README.md` carries two tables. Add the command to the one that matches
its real status:

- **Find the right command** — released commands only.
- **Planned Phase 3 commands** — anything not yet implemented and tested.

Move a row between them in the change that releases the command, never earlier.

## Add tests

In `tests/run.sh`, using the existing `expect_exact` / `expect_contains` style:

- The command appears in help output.
- Each documented exit code is produced by a real failure case, including `2`
  for a syntax error.
- The command remains read-only, if it is. The runner puts failing `brew` and
  `mise` stubs first on `PATH` and asserts at the end that neither ran; a
  command that shells out to a provider will trip that check.

## Verify

```bash
bash scripts/check.sh
./bin/dotfiles help
```

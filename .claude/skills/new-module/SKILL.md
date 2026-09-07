---
name: new-module
description: Scaffold a catalog module or profile with its manifest, mirrored documentation page, and fixture coverage.
argument-hint: "[module-id, e.g. shell.zsh]"
allowed-tools: Read Write Edit Grep Glob Bash(./bin/dotfiles catalog *) Bash(./bin/dotfiles module *) Bash(./bin/dotfiles profile *) Bash(./bin/dotfiles resolve *) Bash(bash scripts/check.sh *)
---

# Add a module or profile

An identifier determines every path that follows it. Derive them mechanically:
`lib/cli/catalog.sh` and `lib/catalog/catalog-validation.awk` enforce the mapping
independently and reject a mismatch.

## Derive the paths

For identifier `<category>.<rest...>`:

- The first segment is the category directory, and must be one of the categories
  in `docs/repository-structure.md`. A new category needs an architecture review.
- Remaining segments join with `-` into one lowercase filename.
- Identifiers match `^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$`.

So `shell.zsh.autosuggestions` gives exactly:

```text
.chezmoidata/modules/shell/zsh-autosuggestions.toml
docs/modules/shell/zsh-autosuggestions.md
```

Profiles follow the same rule under `profiles/`. The manifest's `docs` field must
equal the derived path or validation fails.

## Write the manifest

One table per file, one line per field, no unknown or missing fields. The table
key must equal the `id`. Declare the full path explicitly — chezmoi merges
everything below `.chezmoidata` at one data root, so the directory gives no
namespace.

Required fields are `schema`, `id`, `name`, `summary`, `docs`, `platforms`, and
for modules `depends`, `conflicts`, and `exclusive_group`. Profiles take
`modules` instead of those three.

Two optional tables exist for modules, both **within schema 1**:

- `home.chezmoi.sources`
- `prerequisites.macos.commands`, `.applications`, `.artifacts`, and the same
  three under `prerequisites.debian`

A manifest may carry neither, either, or both, which is why the validator holds
four permitted key-list combinations rather than a second schema version. Read
`docs/catalog.md` for the field tables and value rules before choosing values.

Rules the resolver enforces: every platform a module claims must also be
supported by all of its dependencies; a profile may claim a platform only when
every module it lists supports it; dependencies must not cycle; a module cannot
both depend on and conflict with the same identifier.

## Write the documentation page

Start from `docs/modules/template.md` or `docs/profiles/template.md` and fill
every applicable section. Distinguish planned from released behavior, and do not
promise removal or rollback behavior that is not implemented.

## Add fixture and test coverage

Fixtures live at `tests/fixtures/<case>/catalog/` and are staged into temporary
sources by the runner. **Never create a directory named `.chezmoidata` under
`tests/`** — chezmoi discovers those recursively and would merge test data into
the production catalog.

Add resolution assertions in the existing style, plus a failure case if the
module introduces a new rejection path. Test files are limited to 500 physical
lines and decomposed suite runners to 150, so add cases to the right case file
rather than growing a runner.

## Verify

```bash
./bin/dotfiles catalog validate
./bin/dotfiles module show <module-id>
./bin/dotfiles resolve --modules <module-id> --platform macos
bash scripts/check.sh
```

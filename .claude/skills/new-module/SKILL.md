---
name: new-module
description: Scaffold a catalog module or profile with its manifest, mirrored documentation page, and fixture coverage.
argument-hint: "[module-id, e.g. shell.zsh]"
allowed-tools: Read Write Edit Grep Glob Bash(bash scripts/check.sh) Bash(./bin/dotfiles *)
---

# Add a module or profile

An identifier determines every path that follows it. Derive them mechanically
rather than choosing them, because both `bin/dotfiles` and `lib/catalog.awk`
enforce the mapping independently and reject a mismatch.

## Check the roadmap first

The production catalog is intentionally empty. Releasing production modules is
Phase 3 increment 2, which depends on the accepted execution contract in
ADR 0006 and the schema-2 section of `docs/catalog.md`. If the user is adding a
production module ahead of that increment, say so before scaffolding — then
proceed if they confirm. Fixture-only modules under `tests/fixtures/` carry no
such constraint.

## Derive the paths

For identifier `<category>.<rest...>`:

- First segment is the category directory, and it must be one of the categories
  listed in `docs/repository-structure.md`. A new category requires an
  architecture review.
- Remaining segments join with `-` to form one lowercase filename.
- Identifiers must match `^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$`.

So `shell.zsh.autosuggestions` gives exactly:

```text
.chezmoidata/modules/shell/zsh-autosuggestions.toml
docs/modules/shell/zsh-autosuggestions.md
```

Profiles follow the same rule under `profiles/`. The `docs` field in the
manifest must equal the derived documentation path or validation fails.

## Write the manifest

One table per file, one line per field, no unknown or missing fields. Schema 1
modules take exactly: `schema`, `id`, `name`, `summary`, `docs`, `platforms`,
`depends`, `conflicts`, `exclusive_group`. Profiles take the same minus the last
three, plus `modules`.

The table key must equal the `id`. Declare the full path explicitly — chezmoi
merges everything below `.chezmoidata` at one data root, so the directory gives
no namespace:

```toml
[dotfiles.modules."shell.zsh"]
schema = 1
id = "shell.zsh"
name = "Zsh"
summary = "Interactive Zsh shell experience"
docs = "docs/modules/shell/zsh.md"
platforms = ["macos", "debian"]
depends = []
conflicts = []
exclusive_group = "shell.primary"
```

Rules the resolver enforces: every platform a module claims must also be
supported by all of its dependencies; a profile may claim a platform only when
every module it lists supports it; dependencies must not cycle; a module cannot
both depend on and conflict with the same identifier.

Use `exclusive_group` when only one provider of a capability may be selected at
a time, such as one primary terminal.

## Write the documentation page

Start from `docs/modules/template.md` (or `docs/profiles/template.md`) and fill
every section that applies. Distinguish planned from released behavior
explicitly. Do not promise removal or rollback behavior that is not implemented.

## Add fixture and test coverage

Fixtures live at `tests/fixtures/<case>/catalog/` and are staged into temporary
sources by the runner. **Never create a directory named `.chezmoidata` under
`tests/`** — chezmoi discovers those recursively and would merge test data into
the production catalog; `scripts/check.sh` fails the build if one appears.

Add resolution assertions to `tests/run.sh` in the existing style, and a failure
case if the module introduces a new rejection path.

## Verify

```bash
bash scripts/check.sh
./bin/dotfiles module show <module-id>
./bin/dotfiles resolve --modules <module-id> --platform macos
```

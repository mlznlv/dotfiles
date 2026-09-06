---
name: catalog-field
description: Add, rename, or remove a catalog manifest field across all four places the record contract requires.
argument-hint: "[field name]"
allowed-tools: Read Edit Grep Bash(bash scripts/check.sh) Bash(bash tests/run.sh) Bash(./bin/dotfiles *)
---

# Change a catalog manifest field

The catalog flows through three stages, and the field list is encoded
positionally in each. A field added in one place and not the others fails in a
way the error message does not explain, so all four edits land together.

## The four places

Make every one of these edits, in this order:

1. **`bin/dotfiles`, `validate_manifest_shape`** — add the field name to the
   `allowed[...]` set for the right kind. Module-only fields go inside the
   `if (kind == "modules")` branch; profile-only fields go in the `else` branch.
   This check runs before chezmoi is invoked, so an unknown field fails here
   first with `unsupported field <name>`.

2. **`lib/catalog-records.tmpl`** — add the value to the `printf` for `M` or
   `P`. Use `default "-" ...` for anything optional, because the awk stage
   treats a bare `-` as an empty list. Field order in the `printf` is the wire
   format; append rather than insert unless you are renumbering deliberately.

3. **`lib/catalog.awk`, the `$1 == "M"` or `$1 == "P"` rule** — raise the `NF`
   check by one and assign the new positional field to its array. `NF` is 12 for
   modules and 10 for profiles before any change.

4. **`lib/catalog.awk`, the `BEGIN` block** — add the field name to
   `expected_module_keys` or `expected_profile_keys`. **These strings must stay
   in comma-separated alphabetical order**, because they are compared against
   chezmoi's `keys | sortAlpha | join ","` output as a single string. An
   out-of-order entry fails every manifest with a confusing "fields must be"
   error.

Then add the semantic rules for the field in `validate_catalog()` — identifier
grammar, platform constraints, cross-references — next to the checks for
comparable fields.

## Also required

- **`docs/catalog.md`** — update the schema field table. If the field belongs to
  a new schema version, note which version accepts it; fields from a later
  schema must fail validation in an earlier one.
- **`tests/fixtures/`** — update the `valid` fixture so the field is exercised,
  and add or adjust a failure fixture that rejects a bad value. Fixtures live
  under `tests/fixtures/<case>/catalog/`, never in a directory named
  `.chezmoidata`.
- **`tests/run.sh`** — add assertions for both the accepting and rejecting
  cases. Match the existing `expect_exact` / `expect_contains` style and the
  exit codes: `3` for validation failure.
- **`docs/modules/README.md` or `docs/profiles/README.md`** — update the
  manifest contract if the field is user-facing.

## Verify

Run `bash scripts/check.sh`. A field-list mismatch shows up as
`module <id> fields must be <list>` — that means places 2 and 4 disagree.

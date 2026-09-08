---
name: catalog-field
description: Add, rename, or remove a catalog manifest field across every place the record contract requires.
argument-hint: "[field name]"
allowed-tools: Read Write Edit Grep Glob Bash(./bin/dotfiles catalog *) Bash(bash scripts/check.sh *) Bash(bash scripts/check-maintainability.sh *)
---

# Change a catalog manifest field

The catalog crosses a shell validator, a chezmoi template, and five AWK modules.
The field list is encoded positionally in the record stream and compared as a
single sorted comma-joined string, so a field added in one place and not the
others fails with a message that does not explain the cause.

A module record is currently **19 tab-separated fields**; a profile record is
**10**.

## The places that must change together

1. **`lib/cli/catalog.sh`, `validate_manifest_shape`** — add the field to the
   `allowed[...]` set for the right kind. Module-only fields go inside the
   `if (kind == "modules")` branch. **Dotted keys are handled separately**: the
   `prerequisites.<platform>.<kind>` and `home.chezmoi.sources` keys are matched
   by an explicit condition rather than through `allowed[...]`, so a new dotted
   key must be added to that condition instead. This runs before chezmoi is
   invoked, so an unknown field fails here first.

2. **`lib/catalog-records.tmpl`** — add the value to the `printf` for `M` or `P`.
   Use `default "-" ...` for anything optional; the AWK stage reads a bare `-` as
   an empty list. Field order is the wire format, so append rather than insert.

3. **`lib/catalog.awk`, the `$1 == "M"` or `$1 == "P"` rule** — raise the `NF`
   check and assign the new positional field to its array.

4. **`lib/catalog.awk`, the `BEGIN` block** — this is the step most easily
   half-done. A module's permitted key list is not one string but **four**:
   `expected_module_keys`, `expected_module_keys_home`,
   `expected_module_keys_prerequisites`, and `expected_module_keys_full`. They
   exist because `home` and `prerequisites` are optional tables *within schema
   1*, so a manifest may legitimately carry any of four combinations. A new
   always-present field must be added to all four; a new optional table doubles
   them. Every list stays in comma-separated alphabetical order, because it is
   compared against chezmoi's `keys | sortAlpha | join ","` output.

5. **`lib/catalog/catalog-validation.awk`** — the four-way comparison that
   accepts a module only when its key list equals one of those variants must
   name every variant. Add the field's semantic rules here too, beside the
   checks for comparable fields, using the helpers in
   `lib/catalog/value-validation.awk`.

## Watch the line budgets

`lib/` files are limited to 500 physical lines. Check the headroom before adding
to a module and split by responsibility rather than trimming comments or
diagnostics to fit. Run `bash scripts/check-maintainability.sh`, which takes
about a second.

## Also required

- **`docs/catalog.md`** — update the schema field table.
- **`tests/fixtures/`** — exercise the field in the valid fixture and add a
  failure fixture that rejects a bad value. Fixtures live under
  `tests/fixtures/<case>/catalog/`, never in a directory named `.chezmoidata`.
- **`tests/run.sh`** and its case files — assert both the accepting and
  rejecting paths, matching the existing `expect_exact` / `expect_contains`
  style and the documented exit codes.
- **`docs/modules/README.md`** or **`docs/profiles/README.md`** — update the
  manifest contract if the field is user-facing.

## Verify

`bash tests/run.sh` is about 8 seconds and covers the catalog directly. Run the
full `bash scripts/check.sh` before proposing the change as finished.

A key-list mismatch appears as `module <id> contains unsupported fields or
tables`, which means places 2, 4, and 5 disagree.

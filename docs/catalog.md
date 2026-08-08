# Catalog

The catalog is the read-only source of module and profile metadata. Phase 2
implements catalog loading, validation, discovery, and resolution. The
production catalog is intentionally empty until the minimal shell modules arrive
in Phase 3.

## Representation

Chezmoi reads every TOML file below .chezmoidata and merges its contents at the
root of one data dictionary. Directory names do not create namespaces.
Therefore, every manifest uses an explicit dotfiles namespace.

~~~toml
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
~~~

The catalog root establishes empty maps so a repository with no released
modules remains valid.

~~~toml
[dotfiles]
schema = 1

[dotfiles.modules]

[dotfiles.profiles]
~~~

## Layout

Manifests remain grouped by category even though their TOML tables provide the
data namespace.

~~~text
.chezmoidata/
├── catalog.toml
├── modules/
│   ├── shell/
│   │   ├── zsh.toml
│   │   └── zsh-autosuggestions.toml
│   └── prompt/
│       └── starship.toml
└── profiles/
    └── shell/
        └── minimal.toml
~~~

The identifier determines the only valid path. For example:

- shell.zsh maps to .chezmoidata/modules/shell/zsh.toml.
- shell.zsh.autosuggestions maps to
  .chezmoidata/modules/shell/zsh-autosuggestions.toml.
- shell.minimal maps to .chezmoidata/profiles/shell/minimal.toml.

## Schema 1 module fields

| Field | Type | Rule |
| --- | --- | --- |
| schema | Integer | Must equal 1 |
| id | String | Must equal the TOML table key |
| name | String | Required display name |
| summary | String | Required one-line purpose |
| docs | String | Must mirror the identifier below docs/modules |
| platforms | String array | Non-empty subset of macos and debian |
| depends | String array | Existing module identifiers, with no cycles |
| conflicts | String array | Existing module identifiers |
| exclusive_group | String | Empty or a dotted group identifier |

Schema 1 contains resolution metadata only. Provider requests and home-state
selection arrive with the Phase 3 vertical slice and require a documented
schema extension.

## Schema 1 profile fields

| Field | Type | Rule |
| --- | --- | --- |
| schema | Integer | Must equal 1 |
| id | String | Must equal the TOML table key |
| name | String | Required display name |
| summary | String | Required one-line intent |
| docs | String | Must mirror the identifier below docs/profiles |
| platforms | String array | Non-empty subset of macos and debian |
| modules | String array | Non-empty list of existing modules |

A profile can claim a platform only when all requested modules support that
platform.

## Strict TOML subset

Each manifest contains exactly one catalog table. Fields and arrays stay on one
line, and unknown or missing fields fail validation. Catalog content is treated
only as static data and is never evaluated as shell code.

## Resolution

Resolution is deterministic:

1. Validate the complete catalog.
2. Select one profile or an explicit module list.
3. Add explicitly requested additional modules.
4. Expand dependencies in lexical order.
5. De-duplicate modules while preserving dependency-before-dependent order.
6. Reject unsupported platforms, conflicts, and exclusive-group collisions.
7. Print one resolved module identifier per line.

Resolution is read-only and does not invoke a provider or alter chezmoi state.

## Fixtures

Catalog definitions below tests/fixtures/<case>/catalog exist only to test
behavior. They are deliberately stored outside a directory named .chezmoidata
because chezmoi recursively discovers those directories. The test runner copies
each definition into an isolated temporary source before invoking the CLI.

Fixture entries are not product modules or curated profiles and must never
appear in the production catalog.

## Validation

Run:

~~~text
./bin/dotfiles catalog validate
bash scripts/check.sh
~~~

The full check requires chezmoi. CI installs an exact tagged chezmoi release
with its published checksum verification and runs the suite on macOS and Ubuntu.

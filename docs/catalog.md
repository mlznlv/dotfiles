# Catalog

The catalog is the read-only source of module and profile metadata. The root,
modules, and profiles use one strict pre-release schema: schema 1. Validation,
discovery, ownership checks, and deterministic resolution are available.

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
docs = "docs/modules/shell/zsh/zsh.md"
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
│   │   └── zsh/
│   │       ├── zsh.toml
│   │       └── autosuggestions.toml
│   └── prompt/
│       └── starship.toml
└── profiles/
    └── shell/
        └── minimal.toml
~~~

The identifier determines the only valid path. For example:

- shell.zsh maps to .chezmoidata/modules/shell/zsh/zsh.toml.
- shell.zsh.autosuggestions maps to
  .chezmoidata/modules/shell/zsh/autosuggestions.toml.
- The same identifiers map to docs/modules/shell/zsh/zsh.md and
  docs/modules/shell/zsh/autosuggestions.md.
- shell.minimal maps to .chezmoidata/profiles/shell/minimal.toml.

The `shell.zsh` namespace mapping is intrinsic to its identifier and applies
even when no descendant module is present. Adding or removing another catalog
entry never changes the valid path of an existing manifest or page.

## Module schema versions

Schema 1 is the only pre-release contract for the catalog, modules, and
profiles. The unreleased schema-2 and schema-3 integration iterations are not
compatibility contracts. [ADR 0009](adr/0009-define-pre-release-schema-versioning.md)
defines this versioning rule. Schema 2 may be introduced only after a stable
schema-1 release and an accepted incompatible-change and migration decision.

### Schema 1 module fields

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
| prerequisites.macos.commands | String array | Optional unique executable names; module must support macOS |
| prerequisites.macos.applications | String array | Optional unique application identifiers; module must support macOS |
| prerequisites.macos.artifacts | String array | Optional unique safe artifact locators; module must support macOS |
| prerequisites.debian.commands | String array | Optional unique executable names; module must support Debian |
| prerequisites.debian.applications | String array | Optional unique application identifiers; module must support Debian |
| prerequisites.debian.artifacts | String array | Optional unique safe artifact locators; module must support Debian |
| home.chezmoi.sources | String array | Optional unique safe source paths below `home/` |

Schema 1 retains ADR 0007's configuration-only behavior. Provider requests are
not valid fields. Optional prerequisite and chezmoi arrays default to empty.

| Field | Type | Default | Validation |
| --- | --- | --- | --- |
| `prerequisites.macos.commands` | String array | `[]` | Unique executable names; module must support `macos` |
| `prerequisites.macos.applications` | String array | `[]` | Unique stable application identifiers; module must support `macos` |
| `prerequisites.macos.artifacts` | String array | `[]` | Unique safe artifact locators; module must support `macos` |
| `prerequisites.debian.commands` | String array | `[]` | Unique executable names; module must support `debian` |
| `prerequisites.debian.applications` | String array | `[]` | Unique stable application identifiers; module must support `debian` |
| `prerequisites.debian.artifacts` | String array | `[]` | Unique safe artifact locators; module must support `debian` |
| `home.chezmoi.sources` | String array | `[]` | Existing safe source-path and rendered-target rules |

Command names must match `^[A-Za-z0-9][A-Za-z0-9._+-]*$`; they contain no path
separator and are located without running them. Application identifiers must
match `^[A-Za-z0-9][A-Za-z0-9._-]*$` and are passed only to a generic platform
presence check. Artifact locators have the form `<root>:<relative-path>`.
Schema 1 accepts the `share` root.
[ADR 0008](adr/0008-define-portable-share-artifact-discovery.md) defines its
deterministic lookup order: explicit local roots, valid `XDG_DATA_HOME` or a
validated `$HOME/.local/share` fallback, valid `XDG_DATA_DIRS`,
`/usr/local/share`, then `/usr/share`. The contract requires strict root
validation, resolved-path containment, metadata-only checks, and private
disclosure without provider inference. Presence validation is not implemented;
the current command only validates the static locator.

All forms reject whitespace, arguments, shell metacharacters, URLs, hooks,
executable payloads, package-manager instructions, provider data, and
credentials. Artifact relative paths additionally reject absolute paths, empty,
`.` and `..` segments, globs, variables, tildes, and control characters.
Unknown tables, fields, prerequisite kinds, roots, and platform names fail
validation.

The production declarations are:

~~~toml
# Zsh configuration
prerequisites.macos.commands = ["zsh"]
prerequisites.debian.commands = ["zsh"]
home.chezmoi.sources = []

# Zsh autosuggestions configuration; the module also depends on shell.zsh
prerequisites.macos.commands = ["zsh"]
prerequisites.macos.artifacts = ["share:zsh-autosuggestions/zsh-autosuggestions.zsh"]
prerequisites.debian.commands = ["zsh"]
prerequisites.debian.artifacts = ["share:zsh-autosuggestions/zsh-autosuggestions.zsh"]
home.chezmoi.sources = []

# Starship remains independent from every shell
prerequisites.macos.commands = ["starship"]
prerequisites.debian.commands = ["starship"]
home.chezmoi.sources = []

~~~

These arrays are validated as static data only. Presence checking is the next
Phase 3 increment and is not available. No prerequisite is an ownership key,
and no profile may declare prerequisites.

## Ownership validation

After module resolution, each selected chezmoi source is reduced to one
canonical key:

| Request | Canonical key |
| --- | --- |
| Chezmoi rendered target | `chezmoi:target:<normalized-home-relative-target>` |

Chezmoi paths use `/` separators. A target is derived by removing `home/`,
removing the final `.tmpl` suffix, and translating a leading `dot_` in every
path segment to `.`. The result must be a non-empty relative target path. For
example, both `home/dot_zshrc` and `home/dot_zshrc.tmpl` normalize to `.zshrc`
and therefore collide. Any repeated key across the resolved modules is a
duplicate ownership error, even when the declarations are identical. The error
names the key, source path, and every declaring module. This check completes
before prerequisite checks, planning, or mutation.

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

Catalog definitions below `tests/fixtures/<case>/catalog` exist only to test
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

Tests cover schema-1 valid, empty, and omitted prerequisite arrays; unsupported
schema numbers; unsafe identifiers and artifact locators; forbidden provider
fields; platform mismatches; recursive discovery; duplicate values; and
rendered-target collisions. Trap executables verify that validation and
resolution invoke no provider, installer, command prerequisite, or artifact.

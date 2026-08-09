# Catalog

The catalog is the read-only source of module and profile metadata. Schema 1,
schema 2 compatibility, and schema 3 validation, discovery, ownership checks,
and resolution are available. The production catalog uses schema 3 for the
minimal shell composition.

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
- shell.minimal maps to .chezmoidata/profiles/shell/minimal.toml.

## Module schema versions

Schema 1 remains the Phase 2 resolution contract. Schema 2 remains
compatibility-only for external and historical read-only catalogs and is never
reinterpreted. Schema 3 is the released production contract. A manifest must
use one supported integer schema version; fields from another schema fail
validation.

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

Schema 1 contains resolution metadata only.

### Schema 2 compatibility fields

Schema 2 changes only module manifests. It remains accepted for read-only
validation and resolution compatibility, but no production module uses it.
Profiles remain schema 1 because they compose module identifiers.

| Field | Type | Default | Validation and platform rule |
| --- | --- | --- | --- |
| schema | Integer | None | Required and must equal 2 |
| providers.macos.homebrew.packages | String array | `[]` | Unique Homebrew formula names; allowed only when `platforms` contains `macos` |
| providers.debian.mise.packages | String array | `[]` | Unique mise package identifiers; allowed only when `platforms` contains `debian` |
| providers.debian.mise.tools | String array | `[]` | Unique mise tool identifiers; allowed only when `platforms` contains `debian` |
| home.chezmoi.sources | String array | `[]` | Unique regular-file source paths below `home/`; selected on every supported platform |

All schema-1 fields are still required. Optional schema-2 tables may be omitted;
their request arrays then default to empty. Present arrays may also be empty.
Unknown tables, providers, kinds, fields, or platform names fail validation.

Package and tool identifiers must match `^[a-z0-9][a-z0-9@+._-]*$` and must not
contain whitespace, shell metacharacters, flags, versions expressed as command
arguments, URLs, or executable text. A chezmoi source is a slash-separated,
repository-relative path beginning with `home/`; it must not be absolute,
contain `.` or `..` segments, end in `/`, or name anything outside the planned
chezmoi source tree. It must name a regular file in the repository. Phase 3
allows only the `dot_` prefix at the start of a path segment and the `.tmpl`
suffix on the final segment. Directory entries, special entries, and all other
chezmoi attributes and target types, including `exact_`, `modify_`, `remove_`,
`run_`, and `symlink_`, fail validation. Values are data passed to the owning
adapter, never shell source or command text.

Explicit platform sections are required. A macOS request is never inferred on
Debian and a Debian request is never inferred on macOS. Homebrew is the only
macOS package owner. Mise is the only Debian-family package, tool, and managed
repository owner. Chezmoi is the only home-file and template owner.

### Historical schema-2 shell examples

These examples record the pre-migration declarations. They are not production
manifests and are never interpreted as prerequisites.

~~~toml
[dotfiles.modules."shell.zsh"]
schema = 2
id = "shell.zsh"
name = "Zsh"
summary = "Interactive Zsh shell experience"
docs = "docs/modules/shell/zsh.md"
platforms = ["macos", "debian"]
depends = []
conflicts = []
exclusive_group = "shell.primary"
providers.macos.homebrew.packages = ["zsh"]
providers.debian.mise.packages = ["zsh"]
home.chezmoi.sources = []

[dotfiles.modules."shell.zsh.autosuggestions"]
schema = 2
id = "shell.zsh.autosuggestions"
name = "Zsh autosuggestions"
summary = "Interactive command suggestions for Zsh"
docs = "docs/modules/shell/zsh-autosuggestions.md"
platforms = ["macos", "debian"]
depends = ["shell.zsh"]
conflicts = []
exclusive_group = ""
providers.macos.homebrew.packages = ["zsh-autosuggestions"]
providers.debian.mise.packages = ["zsh-autosuggestions"]
home.chezmoi.sources = []

[dotfiles.modules."prompt.starship"]
schema = 2
id = "prompt.starship"
name = "Starship"
summary = "Cross-shell prompt rendering"
docs = "docs/modules/prompt/starship.md"
platforms = ["macos", "debian"]
depends = []
conflicts = []
exclusive_group = "prompt.primary"
providers.macos.homebrew.packages = ["starship"]
providers.debian.mise.tools = ["starship"]
home.chezmoi.sources = []
~~~

Schema-2 compatibility validation preserves these field meanings. No released
command observes or invokes a provider, installs packages, or writes home state.

### Schema 3 module fields

[ADR 0007](adr/0007-define-configuration-only-modules.md) defines released
module schema 3. It keeps every schema-1 field and
`home.chezmoi.sources`, removes every `providers` field, and adds optional
prerequisite arrays.

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
Schema 3 accepts the `share` root, which searches `/opt/homebrew/share` and
`/usr/local/share` on macOS and `/usr/share` and `/usr/local/share` on Debian.
The exact path must be a regular file. Symlinks must resolve to a regular file
below `/opt/homebrew` or `/usr/local` on macOS, or `/usr` or `/usr/local` on
Debian. Broken or escaping links fail; the checker never opens or executes the
file.

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

### Schema-2 migration result

The migration must not silently reinterpret provider request fields.

| Historical schema-2 data | Released schema-3 treatment |
| --- | --- |
| Homebrew package arrays | Remove; add platform command or application prerequisites only where presence is required |
| Mise package and tool arrays | Remove; add platform command prerequisites only where presence is required |
| `home.chezmoi.sources` | Retain under the new schema and validate rendered targets unchanged |
| Zsh requests | Replace with the `zsh` command prerequisite on both platforms |
| Zsh autosuggestions requests | Replace with the `zsh` command and `share:zsh-autosuggestions/zsh-autosuggestions.zsh` artifact prerequisites on both platforms |
| Starship requests | Replace with the `starship` command prerequisite on both platforms |
| Provider collision fixtures | Replace with unsafe-prerequisite and rendered-target collision coverage |

Schema-2 provider fields are forbidden in schema 3. Schema 2 remains accepted
only for read-only validation, discovery, and resolution compatibility. Future
configuration commands must reject unconverted schema-2 provider requests
explicitly rather than reinterpret them.

## Ownership validation

After module resolution and target-platform selection, each request is reduced
to one canonical key:

| Request | Canonical key |
| --- | --- |
| Homebrew formula | `homebrew:package:<formula-name>` |
| Mise Debian package | `mise:package:<package-name>` |
| Mise tool | `mise:tool:<tool-name>` |
| Chezmoi rendered target | `chezmoi:target:<normalized-home-relative-target>` |

Provider, kind, and identifiers are already canonical lowercase data; chezmoi
paths use `/` separators. A chezmoi target is derived by removing `home/`,
removing the final `.tmpl` suffix, and translating a leading `dot_` in every
path segment to `.`. The result must be a non-empty relative target path. For
example, both `home/dot_zshrc` and `home/dot_zshrc.tmpl` normalize to `.zshrc`
and therefore collide. Any repeated key across the resolved modules is a
duplicate ownership error, even when the declarations are identical. The error
names the key, source path, and every declaring module. This check completes
before provider observation, planning, or mutation.

For schema 3, only the normalized chezmoi target key remains. Its ownership
record names the declaring module, and any duplicate across the resolved
composition fails before prerequisite checks, planning, or apply. Compatibility
schema-2 catalogs retain their historical provider ownership checks.

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

Tests cover schema 1 and schema 2 compatibility; schema 3 valid, empty, and
omitted prerequisite arrays; unsafe identifiers and artifact locators; mixed
provider fields; platform mismatches; recursive discovery; duplicate values;
and rendered-target collisions. Trap executables verify that validation and
resolution invoke no provider, installer, command prerequisite, or artifact.

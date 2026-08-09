# Catalog

The catalog is the read-only source of module and profile metadata. Schema 1
and schema 2 validation, discovery, ownership checks, and resolution are
available. The production catalog contains the minimal shell composition.

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

## Module schema versions

Schema 1 remains the released Phase 2 resolution contract. It accepts exactly
the fields below and implies no provider or home-state requests. Schema 2 is the
released Phase 3 catalog contract. It requires all schema-1 fields and permits the
additional fields defined below. A manifest must use one supported integer
schema version; fields from a later schema fail validation in an earlier one.

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

### Schema 2 module fields

Schema 2 changes only module manifests. Profiles remain schema 1 because they
compose module identifiers and do not own resources.

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

### Released shell modules

These examples mirror the production manifests. Home-state source arrays remain
empty until the later chezmoi shell-state increment.

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

These declarations establish ownership intent. No released command observes or
invokes a provider, installs packages, or writes home state.

### Proposed configuration-only replacement

[ADR 0007](adr/0007-define-configuration-only-modules.md) proposes a new module
schema version. It is not released and does not change how the current CLI
validates schema 2. The focused migration after ADR acceptance will choose the
version number, implement validation, and update production entries.

The planned replacement keeps every schema-1 field and
`home.chezmoi.sources`, removes every `providers` field, and adds these optional
arrays:

| Field | Type | Default | Planned validation |
| --- | --- | --- | --- |
| `prerequisites.macos.commands` | String array | `[]` | Unique executable names; module must support `macos` |
| `prerequisites.macos.applications` | String array | `[]` | Unique stable application identifiers; module must support `macos` |
| `prerequisites.debian.commands` | String array | `[]` | Unique executable names; module must support `debian` |
| `prerequisites.debian.applications` | String array | `[]` | Unique stable application identifiers; module must support `debian` |
| `home.chezmoi.sources` | String array | `[]` | Existing safe source-path and rendered-target rules |

Command names must match `^[A-Za-z0-9][A-Za-z0-9._+-]*$`; they contain no path
separator and are located without running them. Application identifiers must
match `^[A-Za-z0-9][A-Za-z0-9._-]*$` and are passed only to a generic platform
presence check. Both forms reject whitespace, arguments, shell metacharacters,
URLs, hooks, scripts, package-manager instructions, provider data, and
credentials. Unknown tables, fields, prerequisite kinds, and platform names
fail validation.

Planned examples show optionality; they are not production manifests:

~~~toml
# Zsh configuration
prerequisites.macos.commands = ["zsh"]
prerequisites.debian.commands = ["zsh"]
home.chezmoi.sources = ["home/dot_zshrc.tmpl"]

# Zsh autosuggestions configuration; the module also depends on shell.zsh
prerequisites.macos.commands = ["zsh"]
prerequisites.debian.commands = ["zsh"]
home.chezmoi.sources = ["home/dot_config/zsh/autosuggestions.zsh.tmpl"]

# Starship remains independent from every shell
prerequisites.macos.commands = ["starship"]
prerequisites.debian.commands = ["starship"]
home.chezmoi.sources = ["home/dot_config/starship.toml"]

# Future Ghostty configuration
prerequisites.macos.applications = ["com.mitchellh.ghostty"]
home.chezmoi.sources = ["home/dot_config/ghostty/config"]

# Future VS Code configuration
prerequisites.macos.applications = ["com.microsoft.VSCode"]
prerequisites.debian.commands = ["code"]
home.chezmoi.sources = ["home/dot_config/Code/User/settings.json"]
~~~

Presence is a precondition, not desired software state. A missing value names
the module and identifier and fails before a configuration plan or apply. No
prerequisite is an ownership key, and no profile may declare prerequisites.

### Planned schema-2 migration

The migration must not silently reinterpret provider request fields.

| Current schema-2 data | Planned treatment |
| --- | --- |
| Homebrew package arrays | Remove; add platform command or application prerequisites only where presence is required |
| Mise package and tool arrays | Remove; add platform command prerequisites only where presence is required |
| `home.chezmoi.sources` | Retain under the new schema and validate rendered targets unchanged |
| Zsh requests | Replace with the `zsh` command prerequisite on both platforms |
| Zsh autosuggestions requests | Determine a portable, testable presence identifier during migration; do not infer one from package names |
| Starship requests | Replace with the `starship` command prerequisite on both platforms |
| Provider collision fixtures | Replace with unsafe-prerequisite and rendered-target collision coverage |

On ADR acceptance, schema-2 provider fields are deprecated for new catalog
work. The focused migration adds the replacement schema and converts production
modules and fixtures atomically. Until converted, discovery and resolution may
continue using schema 2, but planned configuration commands must fail with an
explicit migration-required error. A later cleanup may remove schema-2 support
after no production entry uses it.

## Released schema-2 ownership validation

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

Under the proposed contract, only the normalized chezmoi target key remains.
Its ownership record names the declaring module, and any duplicate across the
resolved composition fails before prerequisite checks, planning, or apply.

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

Schema-2 implementation tests cover valid schema-1 and schema-2
manifests, unknown fields and providers, incompatible platform sections,
duplicate ownership keys including distinct sources that normalize to one
chezmoi target, directory selections, forbidden chezmoi attributes, and values
resembling executable shell text.

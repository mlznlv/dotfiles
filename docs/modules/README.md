# Modules

Modules are the smallest documented, selectable units of capability. This page
defines their planned contract. No modules are implemented in the architecture
foundation.

## Categories

Initial categories are:

| Category | Purpose |
| --- | --- |
| shell | Interactive shells and shell extensions |
| prompt | Prompt renderers and prompt configuration |
| terminal | Terminal applications and interfaces |
| multiplexer | Persistent terminal sessions |
| cli | General command-line utilities |
| vcs | Version-control tools and configuration |
| editor | Editors and editor integration |
| remote | Remote access clients and services |
| network | Private networking and network utilities |
| runtime | Language runtimes and versioned development tools |
| container | Container clients and engines |
| operations | Host inspection and operational tooling |
| security | Defensive and security-lab tooling |

The category is organizational and forms the first segment of the module
identifier. It does not select modules automatically.

## Catalog layout

Manifests are grouped by category.

~~~text
.chezmoidata/modules/
├── shell/
│   ├── zsh.toml
│   └── zsh-autosuggestions.toml
└── prompt/
    └── starship.toml
~~~

The planned initial modules are:

- shell.zsh
- shell.zsh.autosuggestions, depending on shell.zsh
- prompt.starship

These identifiers and relationships are design targets for the minimal shell
vertical slice, not released functionality.

## Manifest contract

A future module manifest will declare, at minimum:

- Schema version and stable identifier.
- Human-readable name, summary, and documentation path.
- Supported platform families and optional constraints.
- Dependencies, conflicts, and optional exclusive group.
- Provider requests with one owner per resource.
- Chezmoi data used to select home source state.
- Options with types, defaults, validation, and privacy classification.

A conceptual manifest looks like this:

~~~toml
schema = 1
id = "shell.zsh"
name = "Zsh"
summary = "Interactive Zsh shell experience"
docs = "docs/modules/shell/zsh.md"
platforms = ["macos", "debian"]
depends = []
conflicts = []
~~~

The schema introduced by implementation work may refine field names. Its tests
and documentation become authoritative when merged.

## Module boundaries

A module represents user-visible capability, not every file or package needed
to provide it. Provider requests remain implementation details shown in plans.

Use a profile when the only purpose is to group selectable modules. Do not
create a grouping module with no capability of its own.

A module must not:

- Select itself from a hostname, username, or hidden machine rule.
- Own resources assigned to another provider.
- Include secrets, tokens, private keys, or machine identity.
- Run imported or catalog-supplied executable text.
- Remove unmanaged resources.
- Duplicate configuration already owned by another module.

## Documentation requirement

Every module is introduced or changed with a matching page below this
directory. The page must include:

- Purpose and user-visible result.
- Dependencies, conflicts, and exclusive group.
- Supported and unsupported platforms.
- Provider requests and files managed.
- Options, defaults, and privacy notes.
- Plan, apply, verification, rollback, and known limitations.
- Test coverage and examples.

Start from [the module documentation template](template.md).

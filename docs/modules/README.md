# Modules

Modules are the smallest documented, selectable units of capability. This page
defines their contract. The production catalog releases three shell modules.
Catalog entries below tests/fixtures are test data, not product modules.

Under the configuration-only contract accepted in ADR 0007, a module is one
optional, tool-specific configuration capability. The core selects none by
default: Zsh, Starship, Ghostty, VS Code, tmux, and every other tool require an
explicit module selection.

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

The released initial modules are:

- shell.zsh
- shell.zsh.autosuggestions, depending on shell.zsh
- prompt.starship

Their metadata and dependencies are available for discovery and resolution.

## Manifest contract

Schema 1 declares resolution metadata:

- Schema version and stable identifier.
- Human-readable name, summary, and documentation path.
- Supported platform families.
- Dependencies, conflicts, and optional exclusive group.

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

Schema 2 adds provider requests and chezmoi source selection. Released modules
contain package intent but no managed home sources yet. See the
[catalog contract](../catalog.md).

ADR 0007 replaces provider requests in schema 3 with static platform command,
application, or artifact prerequisites plus chezmoi source selections. Schema 3
is planned, not implemented; production manifests remain unchanged until the
focused migration.

## Module boundaries

A module represents one user-visible configuration capability, not software
installation. A selected module may verify that its tool already exists, but it
never installs, updates, or removes that tool.

Dependencies express configuration requirements only. `prompt.starship` does
not depend on `shell.zsh`; future `terminal.ghostty` and `editor.vscode` modules
must not select a shell, prompt, multiplexer, terminal, or editor implicitly.
Platform-specific prerequisites and templates stay inside the selected module.

Use a profile when the only purpose is to group selectable modules. Do not
create a grouping module with no capability of its own.

A module must not:

- Select itself from a hostname, username, or hidden machine rule.
- Install or update packages, runtimes, providers, or applications.
- Encode commands, arguments, URLs, hooks, scripts, or credentials as
  prerequisites.
- Own a rendered target assigned to another module.
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
- Static prerequisites and chezmoi-managed rendered targets.
- Options, defaults, and privacy notes.
- Configuration plan, apply, verification, rollback, and known limitations.
- Test coverage and examples.

Start from [the module documentation template](template.md).

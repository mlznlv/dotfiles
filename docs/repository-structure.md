# Repository structure

## Current Phase 2 layout

The repository contains a read-only catalog and resolver. It does not contain
production modules, provider adapters, package requests, managed home files, or
apply behavior.

~~~text
.
├── .chezmoidata/
│   └── catalog.toml
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── documentation.yml
│   │   └── secret-scan.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── dependabot.yml
├── bin/
│   └── dotfiles
├── docs/
│   ├── adr/
│   ├── cli/
│   ├── modules/
│   ├── profiles/
│   ├── architecture.md
│   ├── catalog.md
│   ├── repository-structure.md
│   └── roadmap.md
├── lib/
│   ├── catalog-records.tmpl
│   └── catalog.awk
├── scripts/
│   └── check.sh
├── tests/
│   ├── fixtures/
│   │   └── <case>/catalog/
│   └── run.sh
└── public repository files
~~~

Fixture modules and profiles exist only below `tests/fixtures/<case>/catalog`.
The test runner stages them in isolated temporary chezmoi sources, so fixtures
cannot merge into production catalog data. They are not production entries.

## Planned Phase 3 additions

The next phase adds the first production catalog entries and their chezmoi home
state.

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

The home-state layout will be fixed by the Phase 3 pull request and recorded in
an ADR if it differs from chezmoi conventions.

## Naming rules

- Module identifiers use dotted category names, such as shell.zsh.
- The first identifier segment equals the category directory.
- Remaining identifier segments map to one lowercase kebab-case filename.
- Profile identifiers follow the same category-first rule.
- A manifest's identifier must equal its TOML table key.
- Flat module and profile manifest directories are not allowed.
- Documentation mirrors catalog paths.
- CLI command documentation mirrors command groups below docs/cli.
- Shell files and commands use portable, descriptive names.

For example, shell.zsh.autosuggestions maps to:

~~~text
.chezmoidata/modules/shell/zsh-autosuggestions.toml
docs/modules/shell/zsh-autosuggestions.md
~~~

## Category boundaries

Initial module categories are shell, prompt, terminal, multiplexer, cli, vcs,
editor, remote, network, runtime, container, operations, and security. New
categories require an architecture review to avoid overlapping ownership.

Profiles are grouped by user intent, such as shell, personal, development, and
homelab. A category is not an implicit profile and does not select every module
inside it.

## Change contracts

A pull request that adds or changes a module must include its manifest,
documentation, validation fixtures, and relevant tests. The equivalent rule
applies to profiles and CLI commands.

Generated files must identify their source and must not be edited by hand.
Secrets, hostnames, usernames, private addresses, and absolute personal paths
must not be committed.

# Repository structure

## Foundation pull request

The first pull request intentionally contains documentation and repository
governance only.

~~~text
.
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── workflows/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── dependabot.yml
├── docs/
│   ├── adr/
│   ├── cli/
│   ├── modules/
│   ├── profiles/
│   ├── architecture.md
│   ├── repository-structure.md
│   └── roadmap.md
├── .editorconfig
├── .gitignore
├── .markdownlint-cli2.yaml
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── SECURITY.md
~~~

No placeholder directories are committed. A directory appears when its first
real artifact is introduced.

## Planned implementation layout

The layout below is a design target, not current functionality.

~~~text
.
├── .chezmoidata/
│   ├── modules/
│   │   ├── shell/
│   │   │   ├── zsh.toml
│   │   │   └── zsh-autosuggestions.toml
│   │   └── prompt/
│   │       └── starship.toml
│   └── profiles/
│       ├── shell/
│       │   └── minimal.toml
│       ├── personal/
│       ├── development/
│       └── homelab/
├── home/
│   └── chezmoi source state
├── bin/
│   └── dotfiles
├── lib/
│   └── CLI implementation libraries
├── scripts/
│   └── repository validation
├── tests/
│   ├── fixtures/
│   ├── integration/
│   └── unit/
└── docs/
    ├── modules/
    │   ├── shell/
    │   └── prompt/
    ├── profiles/
    └── cli/
~~~

The exact chezmoi source directory will be chosen when the vertical slice is
implemented and recorded in an ADR if it differs from chezmoi conventions.

## Naming rules

- Module identifiers use dotted category names, such as shell.zsh.
- The first identifier segment equals the category directory.
- Manifest filenames use lowercase kebab-case.
- Profile identifiers follow the same category-first rule.
- A manifest's identifier is authoritative; its path must agree with it.
- Flat module and profile manifest directories are not allowed.
- Documentation mirrors catalog paths. For example, shell.zsh is documented at
  docs/modules/shell/zsh.md.
- CLI command documentation mirrors command groups below docs/cli.
- Shell files and commands use portable, descriptive names.

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

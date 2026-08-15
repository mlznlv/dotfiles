# Repository structure

## Current layout

The repository contains a read-only schema-1 catalog, resolver, and shell
prerequisite checker with three production modules and one profile. It contains
no provider adapters, managed home files, planning, or apply behavior.

~~~text
.
├── .chezmoidata/
│   ├── catalog.toml
│   ├── modules/{shell,prompt}/
│   └── profiles/shell/
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
│   ├── modules/{shell/zsh,prompt}/
│   ├── profiles/
│   ├── user-guide/
│   ├── architecture.md
│   ├── catalog.md
│   ├── repository-structure.md
│   └── roadmap.md
├── lib/
│   ├── catalog-records.tmpl
│   ├── catalog.awk
│   └── prerequisite-check.sh
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

## Branch responsibilities

| Branch | Responsibility | Normal changes |
| --- | --- | --- |
| `master` | Stable and released state | Explicit owner-reviewed promotion from `next` only |
| `next` | Active integration state | Focused implementation and maintenance pull requests |
| `legacy` | Read-only recovery snapshot | None; never a pull-request target |

Work branches start from the latest `next` and target `next`. Integrating an
increment does not promote it to `master`; promotion is a separate release
pull request and decision.

## GitHub labels

The repository keeps only labels with a demonstrated current consumer:

| Label | Consumer |
| --- | --- |
| `dependencies` | Dependabot applies it to dependency update pull requests |
| `github_actions` | Dependabot applies it to GitHub Actions update pull requests configured by `.github/dependabot.yml` |

Dependabot PRs 9–11 demonstrate both labels in active use. The issue forms do
not assign labels, no workflow or ownership rule consumes the default issue
taxonomy, and there are no issues requiring manual triage. Labels must not be
added or retained without a current form, workflow, automation, ownership,
release, reporting, or active triage consumer.

## Phase 3 layout

Phase 3 is split into focused increments. The following target layout is
proposed by ADR 0010 and remains unimplemented until that ADR is accepted.
Schema 1 catalog paths and read-only command/artifact presence checks are
released; application checks, home state, and planning remain later increments.

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
home/
├── dot_config/
│   ├── starship.toml
│   └── zsh/
│       └── autosuggestions.zsh
└── dot_zshrc.tmpl
lib/
├── prerequisite-check.sh
└── plan.sh
tests/
└── fixtures/
    └── phase3/
        ├── catalog/
        ├── prerequisites/
        ├── rendered/
        └── plans/
~~~

`lib/prerequisite-check.sh` contains released, read-only command and artifact
presence checks. Applications currently fail closed. It never runs a
prerequisite or installer. Planned `lib/plan.sh` will construct stable
chezmoi-only configuration plans; CLI dispatch remains in `bin/dotfiles`. No
Homebrew, mise, package-manager, or application-provider adapter is planned.

`home/` is the proposed chezmoi source root. `shell.zsh` alone owns
`home/dot_zshrc.tmpl`; autosuggestions and Starship own their distinct tool
configuration sources. Schema-1 module data will select paths below `home/`,
but will contain no file bodies or executable selection logic. Chezmoi remains
the sole engine for rendered home targets.

No composition file is planned. Future plan/apply invocations will pass a
mode-`0600` temporary override-data file to chezmoi and remove it before return;
that local ephemeral file is not part of repository layout or saved state.

Phase 3 fixtures remain non-production data. `catalog/` covers schema and
rendered-target ownership, `prerequisites/` contains sanitized presence facts,
`rendered/` contains expected chezmoi output, and `plans/` contains deterministic
configuration-only output for macOS, Debian, no-change, cancellation,
non-interactive refusal, and failure cases. Fixtures must not inspect real
software or use machine identity.

## Naming rules

- Module identifiers use dotted category names, such as shell.zsh.
- The first identifier segment equals the category directory.
- Schema 1 defines `shell.zsh` as an explicit namespace root. Its own manifest
  repeats `zsh` as the filename; descendants use their remaining identifier as
  the filename. This mapping applies independently of which modules exist.
- New schema-1 namespace roots require an explicit contract change.
- Modules outside an explicit namespace remain below their category directory.
- Profile identifiers follow the same category-first rule.
- A manifest's identifier must equal its TOML table key.
- Duplicate flattened compatibility manifests are not allowed.
- Module documentation mirrors the same identifier hierarchy as its manifest.
- CLI command documentation mirrors command groups below docs/cli.
- Shell files and commands use portable, descriptive names.

For example, shell.zsh.autosuggestions maps to:

~~~text
.chezmoidata/modules/shell/zsh/autosuggestions.toml
docs/modules/shell/zsh/autosuggestions.md
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

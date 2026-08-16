# Repository structure

## Current layout

The repository contains a read-only schema-1 catalog, resolver, shell
prerequisite checker, isolated selected-source renderer, and deterministic
configuration planner with three production modules and one profile. It
contains no provider adapters, apply behavior, or managed-home mutation.

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
├── home/
│   ├── .chezmoitemplates/
│   │   └── zsh-quote-literal
│   ├── dot_config/{starship.toml,zsh/autosuggestions.zsh}
│   └── dot_zshrc.tmpl
├── lib/
│   ├── catalog-records.tmpl
│   ├── catalog.awk
│   ├── plan.sh
│   ├── prerequisite-check.sh
│   └── render.sh
├── scripts/
│   └── check.sh
├── tests/
│   ├── fixtures/
│   │   └── <case>/catalog/
│   ├── helpers/
│   │   ├── chezmoi-plan-probe.sh
│   │   └── chezmoi-render-probe.sh
│   ├── plan.sh
│   ├── render.sh
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
defined by accepted ADR 0010 and is implemented for isolated read-only shell
rendering and selected-target planning. Application checks, managed home state,
and apply remain later increments.

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
├── .chezmoitemplates/
│   └── zsh-quote-literal
├── dot_config/
│   ├── starship.toml
│   └── zsh/
│       └── autosuggestions.zsh
└── dot_zshrc.tmpl
lib/
├── plan.sh
├── prerequisite-check.sh
└── render.sh
tests/
├── helpers/
│   ├── chezmoi-plan-probe.sh
│   └── chezmoi-render-probe.sh
├── plan.sh
└── render.sh
~~~

`lib/prerequisite-check.sh` contains released, read-only command and artifact
presence checks. Applications currently fail closed. It never runs a
prerequisite or installer. `lib/render.sh` builds the closed temporary context
and asks chezmoi to render only selected targets into an isolated non-home
directory. `lib/plan.sh` validates HOME and selected target paths, revalidates
the current artifact fact, captures scoped Chezmoi status privately, and
constructs stable create/update plans. CLI dispatch remains in `bin/dotfiles`.
No Homebrew, mise, package-manager, or application-provider adapter is planned.

`home/` is the chezmoi source root. `shell.zsh` alone owns
`home/dot_zshrc.tmpl`; autosuggestions and Starship own their distinct tool
configuration sources. Schema-1 module data selects paths below `home/`, but
contains no file bodies or executable selection logic. Chezmoi remains
the sole engine for rendered home targets.

No composition file exists. The internal renderer passes a mode-`0600`
temporary override-data file to chezmoi and removes its private directory on
every exit path; that local ephemeral file is not part of repository layout or
saved state. Every plan invocation rebuilds it, and future apply invocations
will do the same rather than reuse a render result or saved plan.

Phase 3 fixtures remain non-production data. The render and plan suites create
isolated catalog facts, prerequisite roots, HOME and output trees, and probe
commands at runtime; none are saved as machine state or committed with local
paths. Planning fixtures cover deterministic configuration-only output,
no-change, selected scope, cancellation, unsafe paths, privacy, cleanup, and
failure cases. Apply-specific confirmation and mutation fixtures remain later.

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

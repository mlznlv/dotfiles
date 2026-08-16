# Repository structure

## Current layout

The repository contains a schema-1 catalog, resolver, shell prerequisite
checker, isolated selected-source renderer, deterministic configuration
planner, and safe selected-target apply path with three production modules and
one profile. It contains no software-provider adapters or saved local state.

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
│   ├── apply.sh
│   ├── plan.sh
│   ├── prerequisite-check.sh
│   └── render.sh
├── scripts/
│   └── check.sh
├── tests/
│   ├── fixtures/
│   │   └── <case>/catalog/
│   ├── helpers/
│   │   ├── chezmoi-{apply,plan,render}-probe.sh
│   │   ├── apply-confirmation-hook.sh
│   │   └── pty-confirm.py
│   ├── apply.sh
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

Phase 3 is split into focused increments. The following layout implements the
accepted ADR-0010 shell sources, read-only rendering, selected-target planning,
and safe apply. Application checks and saved local selection remain later
increments.

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
├── apply.sh
├── plan.sh
├── prerequisite-check.sh
└── render.sh
tests/
├── helpers/
│   ├── chezmoi-{apply,plan,render}-probe.sh
│   ├── apply-confirmation-hook.sh
│   └── pty-confirm.py
├── apply.sh
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
`lib/apply.sh` privately snapshots the displayed canonical plan, recomputes it
after exact confirmation, delegates one changed target at a time to Chezmoi,
and verifies each resulting file before reporting completion.
No Homebrew, mise, package-manager, or application-provider adapter is planned.

`home/` is the chezmoi source root. `shell.zsh` alone owns
`home/dot_zshrc.tmpl`; autosuggestions and Starship own their distinct tool
configuration sources. Schema-1 module data selects paths below `home/`, but
contains no file bodies or executable selection logic. Chezmoi remains
the sole engine for rendered home targets.

No composition file exists. The internal renderer passes a mode-`0600`
temporary override-data file to chezmoi and removes its private directory on
every exit path; that local ephemeral file is not part of repository layout or
saved state. Every plan and apply pass rebuilds it; apply compares two
invocation-local passes and never reuses a render result or saved plan.

Phase 3 fixtures remain non-production data. The render, plan, and apply suites
create isolated catalog facts, prerequisite roots, HOME and output trees, and
probe commands at runtime; none are saved as machine state or committed with
local paths. Apply fixtures cover PTY confirmation, fresh-plan drift, exact
target mutation, verification, idempotency, partial failure, signals, privacy,
and cleanup on macOS and Debian inputs.

## Planned Phase 4 local state

[ADR 0011](adr/0011-define-local-configuration-workflow.md) is Accepted but
does not change the current repository layout or released CLI. When
implemented, one CLI-owned active-selection file will live outside both the
repository and managed HOME sources:

~~~text
$XDG_CONFIG_HOME/
└── dotfiles/
    └── active-selection.toml

$HOME/.config/
└── dotfiles/
    └── active-selection.toml
~~~

The HOME form is a fallback only when `XDG_CONFIG_HOME` is unset or empty. The
dedicated directory and file are planned with modes `0700` and `0600`, strict
ownership and no-symlink validation, an adjacent writer lock, and atomic
same-directory replacement. The file contains canonical schema-1 selection
intent only. It is not repository data, `.chezmoidata`, a file below `home/`,
a Chezmoi general configuration file, or a managed home target.

The accepted decision reserves `$XDG_CACHE_HOME/dotfiles/generated/`, with a
validated `$HOME/.cache/dotfiles/generated/` fallback, only if a future
implementation proves a persistent generated-cache need. No cache directory or
reset command is part of the current or first planned implementation increment.

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

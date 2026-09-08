# Repository structure

## Current layout

The repository contains a schema-1 catalog, resolver, shell prerequisite
checker, isolated selected-source renderer, deterministic configuration
planner, and safe selected-target apply path with three production modules and
one profile. It also contains flag-based and terminal-only interactive local
selection plus strict saved-selection consumption over one shared state
library, effective-selection inspection, and narrow local-selection diagnosis.
It contains no software-provider adapters; the saved state itself lives
outside the repository and managed home sources.

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
│   │   └── config/{doctor,inspect,interactive,set}.md
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
│   ├── catalog/
│   │   ├── common.awk
│   │   ├── value-validation.awk
│   │   ├── catalog-validation.awk
│   │   ├── resolution.awk
│   │   └── output.awk
│   ├── apply.sh
│   ├── cli.sh
│   ├── cli/
│   │   ├── common.sh
│   │   ├── catalog.sh
│   │   ├── selection.sh
│   │   ├── config-commands.sh
│   │   └── execution-commands.sh
│   ├── config-state.sh
│   ├── config-state/
│   │   ├── schema.sh
│   │   ├── storage.sh
│   │   ├── reader.sh
│   │   ├── lock.sh
│   │   └── writer.sh
│   ├── plan.sh
│   ├── prerequisite-check.sh
│   └── render.sh
├── scripts/
│   ├── check-maintainability.sh
│   ├── maintainability/
│   │   ├── common.sh
│   │   ├── file-sizes.sh
│   │   ├── production-shell.sh
│   │   └── test-shell.sh
│   └── check.sh
├── tests/
│   ├── fixtures/
│   │   └── <case>/catalog/
│   ├── helpers/
│   │   ├── chezmoi-{apply,plan,render}-probe.sh
│   │   ├── apply-confirmation-hook.sh
│   │   ├── interactive-state-hook.sh
│   │   ├── pty-confirm.py
│   │   └── pty-interactive.py
│   ├── apply.sh
│   ├── apply/
│   │   ├── support.sh
│   │   ├── syntax-and-confirmation.sh
│   │   ├── convergence-and-scope.sh
│   │   ├── recomputation-and-failures.sh
│   │   └── signals-privacy-and-cleanup.sh
│   ├── config-consumption.sh
│   ├── config-consumption/
│   │   ├── support.sh
│   │   ├── syntax-and-precedence.sh
│   │   ├── equivalence-and-apply.sh
│   │   ├── state-safety.sh
│   │   └── reader-drift-and-privacy.sh
│   ├── config-inspection.sh
│   ├── config-inspection/
│   │   ├── support.sh
│   │   ├── syntax-and-output.sh
│   │   ├── composition-and-precedence.sh
│   │   ├── path-and-state-safety.sh
│   │   └── descriptors-drift-and-privacy.sh
│   ├── config-interactive.sh
│   ├── config-interactive/
│   │   ├── support.sh
│   │   ├── syntax-and-terminal.sh
│   │   ├── input-validation.sh
│   │   ├── confirmation-and-state.sh
│   │   └── signals-and-privacy.sh
│   ├── config-state.sh
│   ├── config-state/
│   │   ├── support.sh
│   │   ├── cli-and-persistence.sh
│   │   ├── path-and-state-validation.sh
│   │   ├── writer-failures-and-drift.sh
│   │   └── concurrency-signals-and-privacy.sh
│   ├── maintainability.sh
│   ├── maintainability/
│   │   ├── support.sh
│   │   ├── file-size-policy.sh
│   │   ├── test-layout.sh
│   │   ├── production-layout.sh
│   │   └── execution-and-portability.sh
│   ├── plan.sh
│   ├── render.sh
│   └── run.sh
└── public repository files
~~~

Fixture modules and profiles exist only below `tests/fixtures/<case>/catalog`.
The test runner stages them in isolated temporary chezmoi sources, so fixtures
cannot merge into production catalog data. They are not production entries.

## Production shell layering

`bin/dotfiles` is a thin compatibility entrypoint. It resolves the physical
repository location, defines the fixed component paths, loads `lib/cli.sh`,
and owns only `main` and its direct-execution guard. `lib/cli.sh` sources one
fixed list in this dependency order, with no glob or runtime discovery:

1. `lib/cli/common.sh` — help, usage errors, platform handling, and required
   internal-component loading.
2. `lib/cli/catalog.sh` — catalog layout validation, record extraction,
   resolver invocation, listing, and showing.
3. `lib/cli/selection.sh` — consuming-option parsing, saved-versus-explicit
   precedence, and inspection presentation.
4. `lib/cli/config-commands.sh` — set, interactive, inspect, doctor, proposal,
   inventory, and local-state command adapters.
5. `lib/cli/execution-commands.sh` — resolve, prerequisite, plan, and apply
   command adapters.

`lib/config-state.sh` remains the stable cross-library import path. It is a
compatibility facade that sources one fixed list in this dependency order:

1. `lib/config-state/schema.sh` — schema-1 identifiers, intent validation,
   canonical serialization, and parsing.
2. `lib/config-state/storage.sh` — portable stat operations, path and root
   safety, diagnostics, required tools, and private hook dispatch.
3. `lib/config-state/reader.sh` — descriptor-preserving repeated reads,
   canonical saved-state validation, and strict loading.
4. `lib/config-state/lock.sh` — durability flushes, exact lock identity,
   signals, release, and owned cleanup.
5. `lib/config-state/writer.sh` — private files and snapshots, comparison,
   atomic publication, result reporting, and public writer wrappers.

Leaves never source their facade or siblings. Both facades resolve their own
physical location, quote every fixed source path, and work independently of
the caller's current directory. Existing callers continue to source
`bin/dotfiles` or `lib/config-state.sh`; the decomposition changes no public
command, output, state, or cross-library function name.

The catalog engine is one fixed POSIX AWK unit loaded in dependency order:
`common.awk`, `value-validation.awk`, `catalog-validation.awk`,
`resolution.awk`, `output.awk`, then `catalog.awk`. The five leaves own only
functions. The stable `lib/catalog.awk` entry owns schema constants, record
patterns, final action dispatch, and status handling. `lib/cli/catalog.sh`
passes each quoted path through an explicit `awk -f`; no leaf loads another.

`scripts/check-maintainability.sh` is a thin sourceable facade over a fixed
order: `common.sh`, `file-sizes.sh`, `production-shell.sh`, then
`test-shell.sh`. Common code owns paths, physical line counts, modes, and
diagnostics; the other leaves own source-size policy, production-shell
architecture, and test-shell architecture respectively. Leaves contain only
functions and never load their facade or siblings.

The size guard recursively covers every regular maintained file below
`.chezmoidata/`, `.github/workflows/`, `bin/`, `home/`, `lib/`, `scripts/`,
and `tests/`, regardless of extension. The general maximum is 500 physical
lines; `bin/dotfiles` remains at 250, while decomposed stable test runners and
both maintainability entrypoints remain at 150. Narrative documentation,
accepted ADRs, licenses, governance files, and generated lock/vendor artifacts
are excluded by semantic category rather than an allowlist. NUL bytes and
physical lines longer than 1,000 bytes are rejected as binary or minification
bypasses.

`tests/maintainability.sh` is a thin runner over suite-local support and four
fixed case leaves covering the file-size policy, test layout, production
layout, and execution/portability. It covers exact manifests, source safety,
missing-component failure, direct execution, arbitrary working directories,
and copied repository paths containing spaces and shell metacharacters.

## Behavioral test layering

The stable behavioral entrypoints remain `tests/config-state.sh`,
`tests/config-interactive.sh`, `tests/config-consumption.sh`,
`tests/config-inspection.sh`, and `tests/apply.sh`. Each is a small runner that
resolves its physical path, declares its complete ordered suite manifest,
loads suite-local support, allocates its private root, immediately installs
cleanup, explicitly initializes the remaining fixtures, owns the final summary,
and sources four cohesive cases in the documented order.

- `config-state/` covers CLI persistence, state/path safety, writer drift, and
  concurrency, signals, and privacy.
- `config-interactive/` covers terminal syntax, literal input, confirmed state,
  and signals and privacy.
- `config-consumption/` covers syntax/precedence, explicit/saved equivalence,
  state safety, and verified-reader drift and privacy.
- `config-inspection/` covers exact output, composition, state safety, and
  descriptor/read drift and privacy.
- `apply/` covers syntax/confirmation, convergence/scope, recomputation and
  partial failure, and signals, privacy, and cleanup.

Within each matching directory, `support.sh` owns only that suite's assertion,
fixture, command, snapshot, root-allocation, and failure-hook helpers. It is
silent and side-effect free until explicitly called. The other four leaves
retain the runner's original assertion order in one shared shell: their
filenames state their single case responsibility. Leaves are internal and
non-executable; cases define no functions, do not source siblings or runners,
and are never executed directly.

Every maintained test file below `tests/` has a 500-physical-line limit, and
decomposed runners have a 150-line limit. The maintainability guard compares
each runner manifest and source order with the complete recursive leaf set,
rejects unsafe or dynamic edges, case-owned or duplicate functions, modes,
syntax, late cleanup protection, and support-time effects, and proves
interruption cleanup plus copied-path/arbitrary-working-directory output
equivalence.
`scripts/check.sh` syntax-checks all test shells recursively but runs only the
stable top-level entrypoints.

## Branch responsibilities

| Branch | Responsibility | Normal changes |
| --- | --- | --- |
| `master` | Active, stable, and only integration state | Focused, owner-reviewed implementation and maintenance pull requests |
| `legacy` | Read-only recovery snapshot | None; never a pull-request target |

Work branches start from the latest `master` and target `master`, use the
`agent/<description>` form, and are deleted after merge. Each pull request is
integrated by the repository owner's explicit review and approval.

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
and safe apply. Application checks remain a later increment; flag-based and
interactive local selection are implemented in Phase 4.

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
and verifies each resulting file before reporting completion. Saved-intent
apply also compares the exact state identity, bytes, and effective selection
across its two independently loaded passes.
No Homebrew, mise, package-manager, or application-provider adapter is planned.

`home/` is the chezmoi source root. `shell.zsh` alone owns
`home/dot_zshrc.tmpl`; autosuggestions and Starship own their distinct tool
configuration sources. Schema-1 module data selects paths below `home/`, but
contains no file bodies or executable selection logic. Chezmoi remains
the sole engine for rendered home targets.

No composition file exists inside the repository or managed home sources. The
internal renderer passes a mode-`0600` temporary override-data file to chezmoi
and removes its private directory on every exit path; that local ephemeral file
is distinct from saved selection. Every plan and apply pass rebuilds it; apply
compares two invocation-local passes and never reuses a render result or saved
plan.

Phase 3 fixtures remain non-production data. The render, plan, and apply suites
create isolated catalog facts, prerequisite roots, HOME and output trees, and
probe commands at runtime; none are saved as machine state or committed with
local paths. Apply fixtures cover PTY confirmation, fresh-plan drift, exact
target mutation, verification, idempotency, partial failure, signals, privacy,
and cleanup on macOS and Debian inputs.

## Implemented Phase 4 local selection

[ADR 0011](adr/0011-define-local-configuration-workflow.md) is Accepted, and
the `lib/config-state.sh` compatibility facade plus its fixed state modules,
`dotfiles config set`, and `dotfiles config interactive` implement the saving
lifecycle. The same facade provides the strict read-only consumer API. One
CLI-owned active-selection file lives outside both the repository and managed
HOME sources:

~~~text
$XDG_CONFIG_HOME/
└── dotfiles/
    └── active-selection.toml

$HOME/.config/
└── dotfiles/
    └── active-selection.toml
~~~

The HOME form is a fallback only when `XDG_CONFIG_HOME` is unset or empty. The
dedicated directory and file use modes `0700` and `0600`, strict ownership and
no-symlink validation, an adjacent transient writer lock, and atomic
same-directory replacement. The file contains canonical schema-1 selection
intent only. It is not repository data, `.chezmoidata`, a file below `home/`,
a Chezmoi general configuration file, or a managed home target.

`tests/config-state.sh` uses only the library's private root parameter and
isolated temporary trees for lifecycle tests. It covers canonical output,
strict current-state rejection, macOS and Debian resolution, modes, path and
link safety, lock contention, drift, injected durability failures, signals,
privacy, non-invocation, and zero managed-home mutation. The private seam is
not a CLI flag or environment-selected production destination.

`tests/config-interactive.sh` drives real terminal stdin through
`tests/helpers/pty-interactive.py`. It covers deterministic macOS and Debian
inventory, literal prompt input, exact confirmation and cancellation, shared
proposal and canonical bytes, no-change comparison, signals, privacy,
non-invocation, and zero managed-home mutation. The focused state hook proves
that the writer freshly validates after confirmation and remains unreachable
from the public CLI.

`lib/cli/selection.sh` owns one effective-selection adapter for `resolve`,
`prerequisite check`, `plan`, `apply`, and `config inspect`. Explicit bases
bypass the state component. Omitted bases use the state reader, which creates
no state-side object and verifies the regular-file identity, repeated bytes,
canonical schema, and current catalog meaning. `config doctor` always uses
that reader for narrow standard-state health. `tests/config-consumption.sh` covers syntax,
precedence, macOS and Debian inputs, XDG/HOME roots, state safety and drift,
explicit bypass with the state component absent, output equivalence,
invocation-only additions, and apply confirmation-time reloading.
`tests/config-inspection.sh` covers exact inspect and doctor output, strict
scope, path/type/link/mode safety, catalog invalidity, descriptor and drift
behavior, privacy, lock preservation, and zero mutation. These commands
complete Phase 4.

The accepted decision reserves `$XDG_CACHE_HOME/dotfiles/generated/`, with a
validated `$HOME/.cache/dotfiles/generated/` fallback, only if a future
implementation proves a persistent generated-cache need. No cache directory or
reset command is part of the current implementation.

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

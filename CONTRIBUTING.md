# Contributing

Contributions that improve portability, safety, documentation, or a clearly scoped capability are welcome.

Follow the roadmap in dependency order. Do not implement work before its architecture and acceptance criteria are agreed.

## Branches

- `master` is the stable, released branch. It receives changes only through a
  separate promotion pull request from `next` that the repository owner has
  explicitly reviewed and approved.
- `next` is the active integration branch. Create implementation branches from
  its latest commit and target their pull requests to `next`.
- `legacy` is a read-only recovery snapshot. Never modify it or target it with
  pull requests.

The legacy branch may be removed after the new implementation has passed its
recovery window and no rollback need remains.

## Workflow

1. Read the [architecture](docs/architecture.md) and relevant [ADRs](docs/adr/README.md).
2. Open an issue for material design changes or new module categories.
3. Update `next`, then create a focused branch from its latest commit.
4. Keep the pull request limited to one roadmap outcome and target it to
   `next`.
5. Update documentation and tests in the same pull request as behavior.
6. Use clear, English commit messages.
7. Run the repository checks.
8. Complete the pull request checklist.

Ordinary implementation and maintenance work never targets `master`. Promotion
from `next` to `master` is a separate release decision, remains unmerged until
the repository owner explicitly approves it, and must not include new work that
has not already integrated through `next`.

Merge an approved promotion pull request with a merge commit so `master`
preserves the exact integrated commits from `next`. Never squash-merge or rebase
a promotion. Afterward, verify that the promoted `next` commit is an ancestor of
`master`; do not merge `master` back into `next` or reset `next`. Development
continues from the existing `next` history, and its later commits form the next
promotion.

Catalog and CLI changes require chezmoi. Validate them with:

~~~text
bash scripts/check.sh
~~~

Use conventional commit prefixes where practical, such as docs, feat, fix, test, and chore.

## Architecture changes

A durable or cross-cutting decision requires an ADR. Copy the [ADR template](docs/adr/0000-template.md), choose the next number, and explain the context, decision, consequences, and alternatives.

Do not silently reverse an accepted ADR. Add a new ADR that supersedes it.

## Modules

A module contribution must include:

- A category-correct, stable dotted ID.
- A manifest in the matching category directory.
- Documentation mirroring the manifest path.
- Explicit platforms, dependencies, conflicts, and ownership.
- Tests for resolution, planning, application, and verification as applicable.
- Security, privacy, and removal behavior.

Read the [module contract](docs/modules/README.md) before proposing a module.

## Profiles

A profile contribution must include its explicit module composition, purpose, supported targets, security boundary, and documentation. A profile groups capabilities; it must not contain installation logic.

Read the [profile contract](docs/profiles/README.md).

## CLI commands

Every command must ship with:

- Built-in help.
- A command reference page.
- Examples and exit codes.
- Tests for read-only or mutating behavior.
- A clear statement of files and state it may change.

Read the [CLI contract](docs/cli/README.md).

## Maintained source structure

Every regular maintained file below `.chezmoidata/`, `.github/workflows/`,
`bin/`, `home/`, `lib/`, `scripts/`, and `tests/` is limited to 500 physical
lines, including comments, blank lines, and an unterminated final line.
`bin/dotfiles` is limited to 250 lines. Decomposed stable test runners plus
`scripts/check-maintainability.sh` and `tests/maintainability.sh` are limited
to 150 lines. The rule is independent of extension, rejects NUL bytes, and
rejects physical lines longer than 1,000 bytes so binary or minified
representations cannot evade reviewable module boundaries.

Narrative documentation, accepted ADRs, licenses, governance files, and
machine-generated lock or vendor artifacts are outside this automated rule by
semantic category. This is not a per-file allowlist. Split a responsibility
into a narrow module before it approaches its limit; never meet a budget by
combining statements, deleting useful diagnostics or comments, weakening
error handling, renaming an extension, or generating maintained source.

## Production shell structure

Keep production Bash cohesive and reviewable. Split by one-owner
responsibility before growth reaches the standing maintained-source limit.

CLI and config-state facades use documented, explicit, fixed source lists in
one-way dependency order. Do not add globs, directory scans, PATH or
current-working-directory lookup, environment-selected modules, dynamic
evaluation, autoloading, or circular source edges. Each production function
has one owner, source-only libraries are non-executable and silent when
sourced, and `bin/dotfiles` remains executable with a direct-execution guard.

Run both the focused architecture guard and the complete regression suite:

~~~text
bash scripts/check-maintainability.sh
bash scripts/check.sh
~~~

## Test shell structure

Every maintained test file below `tests/`, recursively, is limited to 500
physical lines. A decomposed stable top-level suite runner is additionally
limited to 150 physical lines. Split an oversized suite into one
non-executable, source-safe `support.sh` and cohesive non-executable case
files; keep the existing top-level runner path as the only public entrypoint.

Each runner records one fixed ordered manifest and uses explicit, quoted
sources resolved from its physical path. Support loads first, performs no work
when merely sourced, and exposes explicit root allocation and initialization.
The runner allocates its private root, immediately installs its cleanup trap,
initializes the remaining fixtures, and then sources cases in manifest order in
one shell. It also owns the final summary. Cases execute assertions in that
order; they do not source files, install traps, define helpers, finalize, or exit.

When adding a case, add its path once to the runner manifest and fixed source
list. Do not use globs, scans, dynamic or environment-selected loading, sibling
sources, or direct fragment execution. `scripts/check.sh` syntax-checks every
test shell recursively but executes only stable top-level runners.

## Security and privacy

Never commit credentials, private keys, certificates, real hostnames, IP addresses, Tailscale identity, private registry configuration, or machine-specific identity.

Report vulnerabilities according to [SECURITY.md](SECURITY.md), not through a public issue.

## Scope discipline

Keep the project minimal:

- One owner per capability.
- No destructive cleanup.
- No hidden profiles or machine-name conditions.
- No unsupported compatibility layers.
- No unrelated refactors in feature pull requests.

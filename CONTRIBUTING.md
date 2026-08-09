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

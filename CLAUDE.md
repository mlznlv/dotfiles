# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Branch policy comes first

`master` is the active, stable, and only integration branch. Create every branch
from its latest commit and target every pull request at `master`.

Task branches use the `agent/<description>` form and are deleted after merge.
`legacy` is a read-only recovery snapshot that is never modified or targeted.
There is no separate integration branch: a change is integrated when its pull
request merges into `master`, after the repository owner's explicit review.

`CONTRIBUTING.md` is canonical, and `scripts/check-branch-policy.sh` enforces
that its wording stays intact and fails closed if an active `next` policy, a
non-`master` target, or a `legacy` trigger is reintroduced.

## What this repository is

A modular, configuration-only dotfiles system. It composes and renders
configuration; **it does not install software**. A module may declare a static
prerequisite, which the CLI reports as missing rather than installing.

Chezmoi owns managed-home rendering, comparison, and apply. Zsh owns shell
experience, Starship owns the prompt, and Ghostty, editors, tmux, OpenSSH, and
Tailscale are optional configuration modules rather than installation
requirements. One owner per capability.

The catalog is **schema edition 1** and stays there until the first release.
`home` and `prerequisites` are optional tables within that edition, not a later
schema.

The production catalog in `.chezmoidata/catalog.toml` is **empty by design**.
`module list` printing nothing and exiting `0` is correct, not a bug.

## Commands

~~~bash
bash scripts/check.sh                  # full gate, about 5 minutes
bash scripts/check-maintainability.sh  # structural guard, about 1 second
bash scripts/check-branch-policy.sh    # branch contract, instant
bash tests/branch-policy.sh            # branch policy and Claude allowlist
./bin/dotfiles help                    # command surface
~~~

The full gate runs syntax checks, both guards, a CLI smoke test, then ten
suites. Run a single suite directly while iterating — `bash tests/run.sh` is
about 8 seconds, `bash tests/maintainability.sh` about 140. Reach for
`scripts/check.sh` before proposing a change as finished, not after every edit.

Catalog commands need `chezmoi` on `PATH`; `help` and `version` do not.
`DOTFILES_SOURCE_DIR` and `DOTFILES_CHEZMOI_BIN` exist for testing.

## Architecture

`bin/dotfiles` is a 128-line bootstrap that resolves the repository root and
loads `lib/cli.sh`, which is a facade over `lib/cli/`. Execution concerns live
in `lib/plan.sh`, `lib/render.sh`, `lib/apply.sh`, and
`lib/prerequisite-check.sh`; local selection state lives behind
`lib/config-state.sh` and `lib/config-state/`.

Facades use **documented, explicit, fixed source lists** in one-way dependency
order, with a manifest comment naming each component. Never introduce a glob, a
directory scan, or a `PATH` lookup to load a module.

### The catalog pipeline

Chezmoi is used only as a TOML parser here. The CLI never runs `chezmoi apply`.

1. **`lib/cli/catalog.sh`** validates manifest shape and layout before chezmoi is
   invoked, so a malformed manifest fails without templating.
2. **`lib/catalog-records.tmpl`** has chezmoi render the merged data into a
   tab-separated record stream: `C` for the root, `M` per module, `P` per
   profile. Absent list values become `-`.
3. **`lib/catalog.awk`** holds the record rules and the action dispatch;
   `lib/catalog/` holds the rest — `common.awk`, `value-validation.awk`,
   `catalog-validation.awk`, `resolution.awk`, and `output.awk`.

### The record contract

A module record is **19 tab-separated fields**; a profile record is 10. Changing
a manifest field means changing all of these together, and the field list is
compared as one sorted comma-joined string:

- the allowed field names in `lib/cli/catalog.sh`
- the `printf` in `lib/catalog-records.tmpl`
- the `NF` check and positional indices in `lib/catalog.awk`
- the **four** key-list variants in `lib/catalog.awk`'s `BEGIN` block —
  `expected_module_keys` and its `_home`, `_prerequisites`, and `_full` forms
- the four-way comparison in `lib/catalog/catalog-validation.awk` that accepts a
  module only when its key list equals exactly one of those variants

`home` and `prerequisites` are optional tables **within schema 1**, which is why
there are four permitted combinations rather than a second schema version.

## Maintained source limits

Every maintained file below `.chezmoidata/`, `.github/workflows/`, `bin/`,
`home/`, `lib/`, `scripts/`, and `tests/` is limited to **500 physical lines**.
`bin/dotfiles` is limited to **250**. `scripts/check-maintainability.sh`,
`tests/maintainability.sh`, and decomposed top-level test runners are limited to
**150**. Files may contain no NUL bytes and no physical line over 1,000 bytes,
so a minified or binary form cannot evade a reviewable module boundary.

Narrative documentation, accepted ADRs, licenses, governance files, and
generated lock or vendor artifacts are outside the rule by semantic category —
this is not a per-file allowlist.

Split a responsibility into a narrow module before it approaches its limit.
Never meet a budget by combining statements, deleting diagnostics or comments,
weakening error handling, renaming an extension, or generating source.
`lib/apply.sh` is currently at 488 of 500.

`CONTRIBUTING.md` and `docs/repository-structure.md` are canonical for these
rules; read them before restructuring anything.

## Catalog invariants

- Chezmoi merges every file below `.chezmoidata` into one data root, so
  **directory names are not namespaces**. Each manifest declares its full path
  explicitly, as `[dotfiles.modules."shell.zsh"]`, and holds exactly one table.
- The identifier determines the only valid paths, enforced independently by
  `lib/cli/catalog.sh` and `lib/catalog/catalog-validation.awk`:
  `shell.zsh.autosuggestions` maps to
  `.chezmoidata/modules/shell/zsh-autosuggestions.toml` and
  `docs/modules/shell/zsh-autosuggestions.md`.
- **Fixtures must never live in a directory named `.chezmoidata`.** Chezmoi
  discovers those recursively and would merge test data into the production
  catalog.
- Catalog content is static data and is never evaluated as shell code.

## Contracts to preserve

- **Determinism.** Identical inputs produce identical ordered output.
  Dependencies expand in lexical order, dependency before dependent, and sorting
  uses `LC_ALL=C`.
- **Exit codes** run `0` through `6`, plus `129`, `130`, and `143` for handled
  HUP, INT, and TERM. `0` is success including an empty result and `2` is
  invalid syntax; the rest separate invalid data, an unavailable component, a
  missing prerequisite, and an apply failure. `docs/cli/README.md` owns the
  table. Errors go to stderr.
- **Read-only commands stay read-only.** `resolve`, `plan`, `prerequisite
  check`, `config inspect`, and `config doctor` must not mutate. Suites assert
  that no provider, pager, editor, network, or privilege helper is invoked.
- Shell runs under `set -u` and not `set -e`. Functions return numeric status
  and callers propagate it explicitly.

## Working in this repository

- Follow `docs/roadmap.md` in dependency order. `docs/architecture.md` and
  `docs/adr/` are normative; a durable or cross-cutting decision needs a new ADR
  (copy `docs/adr/0000-template.md`). Never silently reverse an accepted ADR —
  supersede it.
- Documentation, fixtures, and tests ship in the same change as the behavior.
- Distinguish planned from released behavior.
- One owner per capability (ADR 0004): Homebrew owns macOS packages, mise owns
  Debian packages and tools, chezmoi owns home files.
- Never commit hostnames, IP addresses, usernames, Tailscale identity, private
  registry configuration, absolute personal paths, or secrets. Gitleaks runs on
  every push and pull request. Note that `user.email` may be unset locally, in
  which case git derives `user@hostname` and records the machine name.

## Tooling in this repository

`.claude/` is committed. Four slash commands cover the multi-file contracts that
are easy to half-complete: `/new-adr`, `/new-module`, `/new-command`, and
`/catalog-field`. The `contribution-check` agent audits a change against
`CONTRIBUTING.md` before commit.

A `PostToolUse` hook runs the two fast guards after Write and Edit changes below
the governed roots, reporting without blocking. It deliberately does not run the
full gate, which is far too slow for an edit-time check. It does not see a file
rewritten through Bash.

Permissions allow only the read-only command surface. `apply`, `config set`, and
`config interactive` are denied, as are direct `chezmoi`, `brew`, and `mise`
calls — the CLI still reaches chezmoi, because it runs as a subprocess and
permission rules apply only to the command Claude invokes. Denying `chezmoi`
wholesale is necessary rather than tidy: `chezmoi execute-template` evaluates the
`output` template function and therefore runs arbitrary commands. To apply real
home configuration deliberately, opt in through `.claude/settings.local.json`,
which is not committed.

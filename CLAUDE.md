# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A modular dotfiles system for macOS and Debian-family Linux, built on chezmoi. Only the
Phase 2 read-only core exists: a catalog, a validator, and a deterministic resolver. Nothing
installs, plans, or applies yet.

The production catalog in `.chezmoidata/catalog.toml` is **intentionally empty** (empty
`[dotfiles.modules]` and `[dotfiles.profiles]` tables). `module list` and `profile list`
printing nothing and exiting `0` is correct behavior, not a bug. Real modules arrive in
Phase 3.

## Commands

~~~bash
bash scripts/check.sh   # full gate — identical to CI
bash tests/run.sh       # the 25-assertion suite alone
./bin/dotfiles help     # command surface
~~~

`scripts/check.sh` guards against nested `.chezmoidata` under `tests/`, runs `bash -n` over
`bin/dotfiles`, `scripts/check.sh`, and `tests/run.sh`, smoke-runs `help`/`version`/`catalog
validate`, then runs the suite.

Catalog commands require `chezmoi` on `PATH`; `help` and `version` do not. Two environment
variables exist for testing: `DOTFILES_SOURCE_DIR` (catalog root, defaults to the repo) and
`DOTFILES_CHEZMOI_BIN`.

### Running one test case

`tests/run.sh` has no filter flag. Fixtures live at `tests/fixtures/<case>/catalog/` and must
be staged into a directory literally named `.chezmoidata` before the CLI can read them —
pointing `DOTFILES_SOURCE_DIR` at the fixture directory itself will not work:

~~~bash
stage=$(mktemp -d) && mkdir -p "$stage/.chezmoidata" &&
  cp -R tests/fixtures/valid/catalog/. "$stage/.chezmoidata/" &&
  DOTFILES_SOURCE_DIR="$stage" ./bin/dotfiles resolve --profile shell.minimal --platform debian
~~~

Markdown is linted with `markdownlint-cli2` (config in `.markdownlint-cli2.yaml`) and links
are checked with lychee; both run only in CI via `.github/workflows/documentation.yml`.

## Architecture: the catalog pipeline

Every catalog command is one pass through three stages. Chezmoi is used purely as a TOML
parser via `execute-template` — the CLI never runs `chezmoi apply` or touches chezmoi state.

1. **`bin/dotfiles`** — argument parsing, platform detection, and two *pre-parse* checks
   written as inline awk: `validate_manifest_shape` enforces the strict one-line TOML subset
   and the per-kind field allow-list, and `validate_manifest_layout` enforces that a
   manifest's identifier matches its file path. These run before chezmoi is invoked, so a
   malformed manifest fails without templating.
2. **`lib/catalog-records.tmpl`** — chezmoi renders the merged `.dotfiles` data into a
   tab-separated record stream: `C` for the root (3 fields), `M` per module (12), `P` per
   profile (10). Absent list values are emitted as `-`.
3. **`lib/catalog.awk`** — all semantic work: identifier grammar, field-set equality, docs
   path derivation, platform checks, dependency/conflict/exclusive-group rules, cycle
   detection, and the resolver. `validate_catalog()` runs for *every* action, so a broken
   catalog fails `resolve` and `show` too, not just `validate`.

**Adding or renaming a manifest field is a four-place edit.** The record stream is positional
and its field lists are compared as one sorted comma-joined string, so all four must agree:

- the `allowed[...]` set in `validate_manifest_shape` (`bin/dotfiles`)
- the `printf` in `lib/catalog-records.tmpl`
- the `NF` check and field indices in the `$1 == "M"` / `$1 == "P"` rules (`lib/catalog.awk`)
- `expected_module_keys` / `expected_profile_keys` in the awk `BEGIN` block

## Catalog invariants

- Chezmoi merges every file below `.chezmoidata` into one data root, so **directory names are
  not namespaces**. Each manifest must declare its full path explicitly, as
  `[dotfiles.modules."shell.zsh"]`, and must contain exactly one such table.
- The identifier determines the only valid paths, and both are enforced (layout in
  `bin/dotfiles`, docs path in `lib/catalog.awk`): `shell.zsh.autosuggestions` →
  `.chezmoidata/modules/shell/zsh-autosuggestions.toml` and
  `docs/modules/shell/zsh-autosuggestions.md`. First segment = category directory; remaining
  segments join with `-` into the filename.
- **Fixtures must never live in a directory named `.chezmoidata`.** Chezmoi discovers those
  recursively and would merge test data into the production catalog; that is why fixtures use
  a `catalog/` directory and are staged into temporary sources. `scripts/check.sh` fails the
  build if one appears under `tests/`.
- Catalog content is static data and is never evaluated as shell code.

## Contracts to preserve

- **Read-only.** No network, no provider calls, no elevated privilege. `tests/run.sh` puts
  failing `brew` and `mise` stubs first on `PATH` and fails the run if either is invoked.
- **Deterministic.** Identical inputs must produce identical ordered output. Dependencies
  expand in lexical order, dependency before dependent, de-duplicated; sorting uses `LC_ALL=C`.
- **Exit codes:** `0` success (including an empty list), `2` invalid syntax, `3` unsupported
  platform / invalid catalog / failed resolution, `4` chezmoi or an internal CLI file missing.
  Errors go to stderr.
- `bin/dotfiles` runs under `set -u` only, not `set -e`. Functions return numeric status and
  callers propagate it explicitly — keep that convention rather than introducing `set -e`.

## Working in this repository

- Follow `docs/roadmap.md` in dependency order and do not implement ahead of an accepted
  contract. Phase 3 is next; its normative contract is ADR 0006 plus the schema-2 section of
  `docs/catalog.md`, and it is split into six sequential increments, one PR each.
- `docs/architecture.md` and `docs/adr/` are normative. A durable or cross-cutting decision
  needs a new ADR (copy `docs/adr/0000-template.md`, take the next number). Never silently
  reverse an accepted ADR — supersede it with a new one.
- Documentation, fixtures, and tests ship in the same PR as the behavior they describe. Every
  module, profile, and CLI command needs a doc page mirroring its catalog or command path.
- Documentation must distinguish planned from released behavior. Do not describe `plan`,
  `apply`, or any Phase 3 command as available.
- One owner per capability (ADR 0004): Homebrew owns macOS packages, mise owns Debian
  packages/tools/runtimes, chezmoi owns home files. Provider overlap is a validation error;
  adding a provider or moving ownership requires an ADR.
- Branch from `master`. `legacy` is a read-only snapshot of the previous implementation —
  never target it. Use conventional commit prefixes (`docs`, `feat`, `fix`, `test`, `chore`).
- Never commit hostnames, IP addresses, usernames, Tailscale identity, private registry
  configuration, absolute personal paths, or secrets. Gitleaks runs on every push
  and pull request.

## Tooling in this repository

`.claude/` is committed. Three slash commands cover the multi-file contracts that
are easy to half-complete: `/new-adr`, `/new-module`, and `/catalog-field`. The
`contribution-check` agent audits a change against `CONTRIBUTING.md` before commit.

A `PostToolUse` hook re-runs `scripts/check.sh` after edits below `bin`, `lib`,
`scripts`, `tests`, and `.chezmoidata`. `brew`, `mise`, and the mutating `chezmoi`
subcommands are denied — run them from your own shell if you need them.

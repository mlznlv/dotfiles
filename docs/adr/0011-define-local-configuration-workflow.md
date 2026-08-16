# ADR 0011: Define the local configuration workflow

- Status: Proposed
- Date: 2026-08-16
- Supersedes: None
- Superseded by: None

## Context

Phase 3 requires one explicit profile or module base on every resolution,
prerequisite, plan, and apply invocation. That contract is safe and complete,
but normal repeated use needs one durable local choice without turning a saved
choice into home-mutation approval.

The repository has no accepted contract for the file, schema, precedence,
write lifecycle, inspection, diagnosis, or cache-reset boundary of such local
state. Implementing those details inside separate commands would risk hidden
selection, a second home-state engine, machine identity in saved data,
accidental apply, unsafe replacement, or deletion of authoritative choices as
generated cache.

Phase 5 portable saved and shared profiles are a separate capability. This
decision concerns only one user's active selection for one checkout workflow.

## Decision

### Purpose, authority, and ownership

The project will have one **local active selection**. It records the explicit
composition the user wants selection-consuming commands to use when an
invocation omits a profile or module base.

The local active selection is not a plan, rendered output, exported profile,
software inventory, prerequisite result, machine record, or apply
authorization. It contains user intent only. Every consumer resolves that
intent against the current catalog and current invocation platform.

The repository CLI owns local-selection path validation, schema validation,
canonical serialization, locking, atomic updates, and diagnostics. Chezmoi
remains the sole owner of managed home rendering, comparison, and application.
The local file never becomes a second home-state database and is never passed
to Chezmoi as its general user configuration.

Authoritative local selection is distinct from disposable generated cache.
Neither generated data nor a lock or temporary file can supply selection,
render, plan, or apply authority.

### Storage location

The exact file is `dotfiles/active-selection.toml` below one standard
configuration root:

1. Use a non-empty `XDG_CONFIG_HOME` exactly as supplied.
2. When `XDG_CONFIG_HOME` is unset or empty, use `$HOME/.config`.

The resulting public locations are therefore represented as:

~~~text
$XDG_CONFIG_HOME/dotfiles/active-selection.toml
$HOME/.config/dotfiles/active-selection.toml
~~~

A non-empty `XDG_CONFIG_HOME` must be a literal, lexically clean absolute path.
It does not fall back when it is relative, malformed, unsafe, or a symlink.
The HOME fallback requires the same valid, literal, canonical HOME contract as
planning. Empty segments, `.` or `..`, control characters, newline, carriage
return, NUL, tilde, variables, globs, and shell expansion are forbidden.

The selected configuration root, every existing component from that root to
the file, and the immediate `dotfiles` directory must resolve without a
symlink. Existing components must be real directories owned by the current
user. The chosen root must be outside the repository. The CLI refuses an
unresolved root, unsafe existing component, ownership mismatch, or path inside
the worktree.

When the standard root is absent, a configuration write may create it only as
one missing child of an existing validated real parent. It does not recursively
invent an unresolved directory chain. A standard root created by the CLI and
the dedicated `dotfiles` directory use mode `0700`; the file uses mode `0600`.
An existing dedicated directory or file with any group or other permission bit
is unsafe and is refused with permission-repair guidance; the CLI does not
silently change existing permissions. Read-only commands do not require the
root to be writable. Mutating configuration commands fail before changing the
file when the validated directory is not writable.

The path is outside the repository and must never be committed. It is not
`.chezmoidata`, a catalog manifest, a repository profile, a render-context
file, a file below `home/`, Chezmoi's user configuration, or a selected managed
home target.

Tests inject a temporary configuration root only through a private internal
library parameter. The public CLI exposes no destination flag, environment
override, or arbitrary state path.

### Schema-1 active selection

The local document uses schema 1. Exactly one of these canonical TOML shapes is
valid:

~~~toml
schema = 1

[selection]
profile = "shell.minimal"
additional_modules = []
~~~

~~~toml
schema = 1

[selection]
modules = ["shell.zsh", "prompt.starship"]
additional_modules = ["shell.zsh.autosuggestions"]
~~~

The root contains only integer `schema` and table `selection`. The selection
table contains exactly one base: string `profile`, or non-empty string array
`modules`. It always contains the `additional_modules` string array, which may
be empty. Unknown fields, tables, types, schema values, duplicate TOML keys,
and a document containing both or neither base are invalid.

Every identifier uses the released catalog identifier grammar. Exact duplicate
identifiers within a list or explicitly repeated across `modules` and
`additional_modules` are invalid. Dependency or curated-profile overlap is
resolved once by the existing resolver and is not a duplicate-input error.
Unknown identifiers, dependency cycles, conflicts, exclusive-group conflicts,
and unsupported platform combinations fail before a write or use.

The ordered base and additional arrays preserve user intent. The canonical
writer emits the root key, one blank line, the selection header, the base, then
`additional_modules`, with one final newline and the escaping required for
validated TOML strings. A reader strictly parses, validates, reserializes, and
requires byte equality with that canonical form. Comments and alternative
field order are therefore not valid CLI-owned state.

Only the requested profile or ordered explicit module identifiers and ordered
additional identifiers are saved. Resolved dependencies are never saved.
Fresh catalog resolution supplies them on every write validation and consuming
invocation.

The document never stores platform, detected operating-system facts,
prerequisite results, application state, artifact paths, rendered bytes,
destination facts, plan records, confirmation, timestamps, repository commits,
usernames, hostnames, device identifiers, private infrastructure, arbitrary
paths, executable content, commands, hooks, provider requests, or installation
instructions.

Catalog, module, profile, render-context, and local-selection schemas all
remain at version 1. ADR 0009 remains binding: an unreleased design iteration
does not create schema 2 or a compatibility branch.

### Selection authority and precedence

Local selection is an input convenience, never implicit apply intent. The
planned selection-consuming commands are `resolve`, `prerequisite check`,
`plan`, and `apply`.

Their precedence is exact:

1. If an invocation supplies `--profile` or `--modules`, use only that
   invocation-local base and its invocation-local `--add`. Do not read, merge,
   validate, or rewrite local selection.
2. If no explicit base is supplied, load and validate local selection. Its
   saved base and saved additions become the invocation intent.
3. An invocation-local `--add` without an explicit base appends to the loaded
   local additions for that invocation only. It never rewrites the file.
4. `--platform` is always a current invocation fact. It is detected or
   supplied exactly as today and is never persisted.

Repeated options and explicit profile/module combinations remain usage errors.
The combined saved and invocation-local additional list uses the same
duplicate, resolver, ordering, dependency, conflict, ownership, and platform
validation as explicit Phase 3 selection.

A missing local file when no explicit base was supplied fails closed with
status 3 and guidance to run `dotfiles config set` or pass an explicit base. An
unsafe, non-canonical, malformed, unknown-schema, corrupt, or catalog-invalid
local file also fails with status 3. No failure selects a default or
hostname-derived profile, guesses modules, falls back to stale generated data,
or applies anything.

Local selection never replaces Phase 3 validation. Resolve still resolves the
current catalog. Prerequisite check still observes current declared
prerequisites. Plan and apply still rebuild ownership, prerequisite, artifact,
render, target, and comparison facts. Apply still prints a fresh complete plan,
requires exact intent, recomputes after confirmation, compares destination base
state, and verifies each changed target.

### Configuration command surface

The planned public configuration commands are:

~~~text
dotfiles config set (--profile <profile-id> | --modules <id,id>)
                    [--add <id,id>] [--platform macos|debian]
dotfiles config interactive [--platform macos|debian]
dotfiles config inspect [--profile <profile-id> | --modules <id,id>]
                        [--add <id,id>] [--platform macos|debian]
dotfiles config doctor [--platform macos|debian]
~~~

These commands are Proposed and unavailable until their focused implementation
increments ship. They introduce no `-y`, destination flag, default profile,
environment approval, hostname mapping, fuzzy identifier, shell evaluation,
or hidden module.

All commands use deterministic platform detection when `--platform` is
omitted. Repeated options, missing values, unknown flags, and incompatible
selectors are usage errors.

#### Flag-based configuration

`dotfiles config set` treats its explicit flags as the complete requested
intent. It validates schema values, current catalog, platform compatibility,
dependencies, conflicts, and rendered-target ownership before acquiring the
write lock or changing state. It does not check software prerequisites because
the saved choice may remain valid while external software is temporarily
absent.

The command prints this stable summary before its result:

~~~text
Proposed local selection:
Base: profile <profile-id>
Additional modules: <comma-separated-identifiers|none>
Resolved modules for <platform>:
  <module-id>
~~~

The base line uses `Base: modules <comma-separated-identifiers>` for an
explicit module base. Resolved modules appear one per indented line in existing
resolver order.

Flags are already explicit write intent, so `config set` does not prompt. A
successful replacement ends with:

~~~text
Local selection saved.
Managed home configuration: unchanged.
~~~

If the validated canonical bytes equal the current valid file, no replacement
occurs and the ending is:

~~~text
Local selection unchanged.
Managed home configuration: unchanged.
~~~

#### Interactive configuration

`dotfiles config interactive` requires an actual stdin terminal. It refuses
piped or redirected input with status 2 and never accepts environment or stdout
terminal state as approval.

The command lists only released profiles and modules compatible with the
current invocation platform, in existing deterministic catalog order. It then
prints this exact inventory shape:

~~~text
Available profiles for <platform>:
  <profile-id>
Available modules for <platform>:
  <module-id>
~~~

Each identifier appears on one indented line. An empty category prints the
indented token `none`. The command then uses these exact line prompts without
defaults:

~~~text
Base type (profile or modules):
Profile ID:
Module IDs (comma-separated):
Additional module IDs (comma-separated, empty for none):
~~~

Only the prompt matching the selected base type is used. Input is read
literally. Base type accepts only `profile` or `modules`, and selection input
must contain exact identifiers. Numbers, prefixes, fuzzy matches, case folding,
quoting, escapes, and shell syntax have no special meaning.

After complete validation, interactive mode prints the same proposed intent
and resolved composition as `config set`. If it differs from current state, it
prints:

~~~text
Save this local selection? Type yes to continue:
~~~

Only the exact line `yes` replaces local state. Any other line, an empty line,
or EOF prints the following and exits 0:

~~~text
Cancelled. Local selection was not changed.
Managed home configuration: unchanged.
~~~

If the proposal already equals current canonical state, it prints the
unchanged ending and does not prompt. HUP, INT, and TERM preserve conventional
statuses 129, 130, and 143.

#### Configuration exit and effect contract

Configuration commands use these stable status classes:

| Code | Meaning |
| --- | --- |
| `0` | Saved, unchanged, cancelled, inspected, or healthy |
| `2` | Invalid command syntax or interactive use without terminal stdin |
| `3` | Invalid platform, catalog, composition, path safety, local schema, canonical state, or concurrent-state drift |
| `4` | Required parser/internal component or safe filesystem update is unavailable |
| `129`, `130`, `143` | Handled HUP, INT, or TERM interruption |

Errors go to stderr. Summaries and successful results go to stdout. No
configuration command renders, plans, compares, or applies managed home state;
invokes a Chezmoi render/apply operation, provider, installer, prerequisite
executable, artifact, network service, pager, editor, or privilege helper; or
performs software or managed-target mutation.

Changing local selection changes only the active-selection file. It never
cleans, deactivates, removes, scans, or describes targets owned by omitted
modules. Users run `plan` or `apply` separately. A saved selection does not
confirm a future apply, and `apply` retains its exact `yes` or `--yes` contract.

### Inspect and doctor boundaries

`dotfiles config inspect` is strictly read-only. Without an explicit base it
loads local selection; with `--profile` or `--modules` it ignores and does not
read local state. `--add` follows the same precedence rules as consuming
commands, so it may augment either an explicit base or the loaded local base
for this inspection only.

Inspect prints only:

~~~text
Selection source: <local|invocation|local plus invocation additions>
Base: <profile-or-ordered-module-identifiers>
Additional modules: <comma-separated-identifiers|none>
Resolved modules for <platform>:
  <module-id>
~~~

It validates and freshly resolves the intent but checks no prerequisites,
artifacts, render context, plan, HOME target, or cache. Explicit inspection
never saves the inspected selection.

`dotfiles config doctor` is also strictly read-only. It checks only whether the
standard root can be derived safely, the dedicated directory and file have safe
ownership, type, containment, and permissions, the TOML is canonical schema 1,
and the saved intent resolves for the current invocation platform. A healthy
result is:

~~~text
Local selection file: healthy
Schema: 1
Composition for <platform>: valid
~~~

Doctor does not check current prerequisites, artifact candidates, rendered
content, destination files, plan state, cache performance, software providers,
or unrelated HOME entries. It never repairs, rewrites, applies, installs,
downloads, or searches the network.

Inspect and doctor sanitize every diagnostic. They use catalog identifiers and
the stable `$XDG_CONFIG_HOME` or `$HOME/.config` origin token when location is
necessary. They never print file contents, a raw private root, username,
hostname, device identity, private infrastructure, secret, or unrelated path.

### Safe file lifecycle and recovery

Configuration writers use a mode-`0700` lock directory named
`active-selection.lock` beside the file. Atomic lock-directory creation is the
single-writer gate. A second writer does not wait, merge, or steal the lock; it
fails deterministically with status 3. Handled exits remove only the lock they
created. A stale lock is diagnosed but never deleted automatically. Recovery
requires the user to confirm no writer exists before removing the abbreviated
standard-root lock directory.

After locking, the writer revalidates the parent and existing destination. It
privately snapshots the prior regular file or its absence. It writes the
complete validated canonical document to a mode-`0600` unpredictable temporary
file in the same validated directory, flushes file data, and rechecks parent
containment, types, ownership, permissions, and the byte-identical prior state.
Any concurrent destination replacement or edit aborts the operation.

Only then may one atomic same-directory rename replace the destination. The
critical rename and directory flush defer handled-signal reporting so a signal
cannot produce a partial document or an ambiguous half-commit. Temporary files
and the owned lock are removed on success and every handled pre-commit failure.
No code follows a destination or parent symlink, writes through an unsafe type,
or silently merges concurrent selections.

Parse, schema, catalog, composition, cancellation, pre-rename interruption,
temporary-write, flush, containment, concurrency, and rename failures preserve
the prior file byte-for-byte. If the atomic rename completed but the directory
flush cannot be confirmed, the command reports an uncertain status 4 and tells
the user to run `config doctor`; the destination is still always one complete
canonical document, never partial TOML.

A missing local selection is recovered by an explicit `config set` or
interactive choice. A malformed or unsafe existing file is never overwritten,
deleted, reset, or guessed by a configuration command. The diagnostic names
its abbreviated standard-root token and instructs the user to move it aside
for preservation, repair permissions or path types as appropriate, then run an
explicit configuration command. Doctor validates the result; it does not
perform recovery.

### Disposable generated cache and reset

Phase 4 currently has no persistent generated-cache consumer. This decision
does not create cache merely to satisfy a roadmap noun and does not release a
reset command.

If a later Phase 4 increment proves a real acceleration need, its only reserved
namespace is `dotfiles/generated` below a validated standard cache root:

~~~text
$XDG_CACHE_HOME/dotfiles/generated/
$HOME/.cache/dotfiles/generated/
~~~

The non-empty `XDG_CACHE_HOME` and HOME fallback follow the same literal-root,
ownership, containment, and no-symlink rules as configuration state. Cache is
rebuildable acceleration only. It never stores or supplies selection, catalog,
render, plan, apply, confirmation, prerequisite, artifact, or destination
authority.

Only after a named consumer and known-entry allowlist exist may a separate PR
implement `dotfiles config cache reset`. Reset must validate the root and every
entry, refuse symlinks, unknown entries, unsafe types, unresolved or broad
roots, and containment escapes, and remove known entries one at a time. It may
remove the empty `generated` directory it owns; it may not recursively delete
the standard cache root or the broader `dotfiles` namespace.

Reset can never remove or modify active selection, its lock recovery evidence,
catalog data, repository sources, Chezmoi user configuration or persistent
state, managed HOME targets, exported profiles, imported data, unrelated
caches, or any path outside the validated generated namespace. If no cache
consumer is introduced, the reset increment remains deferred indefinitely.

## Implementation-ready test contract

Later implementation increments use isolated temporary configuration roots
through the private test seam and prove on macOS and Debian platform inputs
without relying on real host identity that:

- profile and explicit-module schema-1 selections round-trip to exact canonical
  bytes;
- unknown fields, malformed TOML, invalid identifiers, duplicate explicit
  intent, empty module bases, conflicts, cycles, unsupported platforms, and
  catalog drift fail before writes or use;
- saved intent retains user order, contains no expanded dependencies, and is
  resolved fresh against the current catalog;
- explicit selection has deterministic precedence and never reads or rewrites
  local state;
- invocation `--add` augments only its selected explicit or local base and does
  not persist;
- missing, unsafe, corrupt, non-canonical, or invalid local state never chooses
  a default or applies anything;
- flag-based and interactive configuration produce byte-identical canonical
  state for the same intent;
- interactive mode rejects non-TTY input and every non-exact confirmation;
- cancellation and no-change preserve the prior file byte-for-byte;
- new directory and file modes are `0700` and `0600`, and unsafe permissions,
  ownership, symlink swaps, wrong path types, containment escapes, repository
  paths, and unresolved roots fail closed;
- locking, concurrent replacement, failed writes, failed flushes, rename
  failures, and handled signals never leave partial state or overwrite a newer
  selection;
- local state contains no platform, private path, artifact result, rendered
  data, destination fact, secret, username, hostname, timestamp, commit, or
  machine identity;
- configuration invokes no Chezmoi mutation, provider, installer,
  prerequisite, artifact, network, privilege, pager, or editor behavior;
- inspect and doctor are byte-for-byte non-mutating, freshly resolve catalog
  intent, and keep diagnostics privacy-safe;
- doctor remains separate from prerequisite and home-plan health;
- consuming plan and apply still perform fresh prerequisite, artifact, render,
  destination-base, target, confirmation, and post-write verification;
- temporary documents and owned locks are removed on every handled path;
- an introduced cache remains non-authoritative and rebuildable; and
- any future reset cannot reach selection state, repository data, Chezmoi user
  state, managed HOME targets, exports, or unrelated files.

## Consequences

- Repeated commands can use one transparent local intent without hiding a
  default or weakening explicit selectors.
- Saving choices and changing HOME remain separate, reviewable operations.
- Local schema and path safety add implementation and recovery work before
  selection consumption can ship.
- Strict canonical state and fail-closed concurrency make drift observable at
  the cost of refusing manual in-place TOML customization.
- Phase 5 can define portable saved/shared profiles without reusing this
  machine-local active-selection lifecycle.
- Generated cache and reset remain absent until measured need justifies them.

## Alternatives considered

- **Use Chezmoi's general configuration file:** convenient for templates, but
  couples selection to ordinary Chezmoi behavior and weakens CLI ownership.
- **Store selection in the repository or `.chezmoidata`:** easy to inspect, but
  commits machine-local choice and mixes authority with catalogs.
- **Store resolved dependencies:** makes later commands faster, but becomes
  stale catalog-derived authority and loses user intent.
- **Merge saved and explicit bases:** flexible, but makes explicit invocations
  depend on hidden local state.
- **Choose `shell.minimal` when state is missing:** convenient, but creates an
  implicit default and hidden apply scope.
- **Apply immediately after configuration:** short workflow, but treats a saved
  choice as home-mutation approval.
- **Permit direct non-canonical edits:** familiar TOML workflow, but expands
  parsing and concurrency states for a CLI-owned file.
- **Create a cache and reset command now:** follows the old roadmap wording,
  but adds deletion surface without a real consumer.

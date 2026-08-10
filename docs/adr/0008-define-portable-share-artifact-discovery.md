# ADR 0008: Define portable share artifact discovery

- Status: Proposed
- Date: 2026-08-09
- Supersedes: ADR 0007 (artifact discovery, if accepted)
- Superseded by: None

## Context

Schema 1 uses `share:<relative-path>` as provider-neutral evidence that a
selected tool's shared artifact exists. ADR 0007 assigns that root only fixed
Homebrew, `/usr/local`, and FHS prefixes. That lookup rejects valid user-chosen
installations from XDG data roots, MacPorts, Nix, plugin managers, and other
safe prefixes. Encoding a short provider list beneath a generic root would
retain installation-policy coupling in the core.

The catalog migration validates locators as inert strings. Presence validation
is a later increment and must not ship until the portable lookup contract is
accepted.

## Decision

If accepted, this ADR replaces only ADR 0007's fixed `share` search roots and
symlink boundaries. The schema-1 locator syntax and validation rules remain
unchanged.

### Root sources and order

The future presence checker constructs an ordered root list from:

1. `DOTFILES_SHARE_ROOTS`, when set, as a colon-separated list of explicit
   absolute roots in user-provided order.
2. `XDG_DATA_HOME` when it is an absolute path, otherwise
   `${HOME}/.local/share`.
3. Every absolute entry in `XDG_DATA_DIRS`, or the platform defaults when that
   variable is unset.
4. Platform compatibility roots, in this order:
   - macOS: `/opt/local/share`, `/opt/homebrew/share`, `/usr/local/share`,
     `/usr/share`
   - Debian: `/usr/local/share`, `/usr/share`
5. Nix profile roots that already exist: `${HOME}/.nix-profile/share` and
   `/run/current-system/sw/share`.

Explicit roots extend the standard roots; they do not replace them. The checker
removes later duplicates after lexical normalization, preserving first-seen
order. It never consults a package manager, registry, network service, shell
profile, or executable to discover roots.

### Root and candidate safety

Every configured root must be absolute and contain no empty, `.` or `..`
segment, control character, newline, or carriage return. An invalid explicit
root fails closed with an actionable error; an invalid ambient XDG entry is
reported and ignored. Relative catalog paths continue to use the strict
schema-1 validation rules.

For each root, the checker joins the validated relative path, resolves symlinks,
and succeeds only when the result is a regular file contained by that root's
resolved directory. Broken links and targets escaping the candidate root fail.
It checks metadata only and never opens, reads, sources, or executes the file.

### Disclosure and privacy

Presence output identifies the module, locator, and ordered root origins it
checked. It displays an explicit override path because the user supplied it for
that invocation. Default output abbreviates paths below the current home as
`$HOME`; it does not persist roots, usernames, hostnames, or machine identity in
plans, logs, or catalog data.

`DOTFILES_SHARE_ROOTS` is a local lookup preference only. It cannot appear in a
module or profile, select modules, alter ownership, or imply a provider or
installation action.

## Consequences

- Schema 1 remains provider- and tool-neutral while supporting user-local,
  XDG, MacPorts, Nix, Homebrew, and FHS installations.
- Users can disclose a safe custom prefix without changing the repository.
- Lookup order is deterministic and testable without inspecting package tools.
- Presence validation remains blocked until this decision is accepted and its
  root parsing, containment, disclosure, and non-invocation behavior are tested.

## Alternatives considered

- **Keep fixed prefixes:** simple, but rejects legitimate installations and
  encodes provider assumptions.
- **Search the whole filesystem:** provider-neutral, but slow,
  non-deterministic, privacy-invasive, and unsafe.
- **Ask package managers:** discovers some installations but violates the
  configuration-only boundary and excludes unmanaged tools.
- **Store absolute paths in manifests:** deterministic but not portable and
  risks committing machine identity.

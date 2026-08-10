# ADR 0008: Define portable share artifact discovery

- Status: Proposed
- Date: 2026-08-09
- Supersedes: ADR 0007 (fixed artifact roots and symlink boundaries only, if accepted)
- Superseded by: None

## Context

Schema 1 uses `share:<relative-path>` as provider-neutral evidence that a
selected tool's shared artifact exists. ADR 0007 fixes lookup to a short list
of installation prefixes. Encoding software-provider paths beneath a generic
root still couples the core to installation choices that remain outside the
product boundary.

Users may install software anywhere and expose an additional share root
explicitly. The repository needs only a deterministic, generic, read-only
presence check. Catalog validation currently treats artifact locators as inert
strings; presence checking is not implemented and remains blocked until this
decision is accepted.

## Decision

If accepted, this ADR replaces only ADR 0007's fixed artifact-root list and the
associated fixed-prefix symlink boundary. It does not change the
`share:<relative-path>` syntax, schema-1 static-data validation, missing-
prerequisite behavior, configuration-only boundary, or prohibition on opening,
reading, sourcing, parsing, or executing artifacts.

### Root sources and deterministic order

The future checker constructs one ordered root list:

1. Explicit local roots from `DOTFILES_SHARE_ROOTS`, in user-provided order.
2. Valid `XDG_DATA_HOME`; otherwise `$HOME/.local/share` when `HOME` is valid.
3. Valid `XDG_DATA_DIRS` entries, in declared order.
4. `/usr/local/share`.
5. `/usr/share`.

On the supported macOS and Debian platforms, `:` is the path-list separator.
`DOTFILES_SHARE_ROOTS` and `XDG_DATA_DIRS` are split on `:` without escaping or
expansion. A root containing `:` therefore cannot be represented and is
invalid. Empty explicit-list entries, including a leading, trailing, repeated,
or wholly empty separator, invalidate the entire explicit override and fail
the complete prerequisite check. Empty ambient XDG entries are reported and
ignored; they never mean the current directory.

Each syntactically valid root is lexically normalized before de-duplication:
repeated `/` separators are collapsed and trailing `/` separators are removed
except for `/` itself. Later equal roots are removed while the first occurrence
keeps its position. Normalization does not resolve symlinks or access the
filesystem; filesystem resolution occurs only when testing candidates.

Explicit roots extend the generic roots. They cannot select modules, change
ownership, or encode installation intent. No package manager, application,
plugin manager, registry, executable, shell profile, network service, or other
provider contributes roots. A user may expose any chosen installation prefix
only through the same generic explicit override; the core never infers why the
path exists.

### Root validation

Every root must be a non-empty absolute path. After its leading `/`, it must
contain no empty, `.` or `..` segment, path-list separator, ASCII control
character, newline, carriage return, or NUL. Values are used literally: no
tilde, variable, command, glob, or shell expansion occurs.

`XDG_DATA_HOME` is one root, not a path list. When absent or invalid, the
checker reports the fallback decision and derives `$HOME/.local/share` only if
`HOME` passes the same absolute-path validation. A missing or invalid `HOME` is
reported and produces no user-data fallback. `XDG_DATA_DIRS` contributes only
its valid non-empty entries; every invalid or empty entry is identified by
origin and position, reported, and ignored.

An invalid `DOTFILES_SHARE_ROOTS` value fails closed with an actionable error
that identifies the entry and rule. An explicit root that cannot be resolved
also fails the complete prerequisite check. An ambient XDG or generic system
root that does not exist or cannot be resolved is reported and skipped. No
invalid value silently becomes `.`, `$PWD`, or another inferred directory.

### Candidate containment and type

The checker receives only a relative artifact path already validated by
schema 1. For each root in order, it resolves the root directory, joins the
validated relative path, and resolves the complete candidate, including every
symlink.
Containment is path-component aware: the resolved candidate must equal a child
of the resolved root, not merely share its string prefix.

Presence succeeds only when the resolved candidate is a regular file contained
by that resolved root. A missing path, directory, device, FIFO, socket, broken
symlink, symlink loop, or symlink escaping the root fails for that root. A
symlink resolving to a regular file inside the same resolved root succeeds.
The checker inspects filesystem metadata only and never opens, reads, hashes,
sources, parses, maps, or executes artifact content.

### Disclosure and privacy

A future result names the selected module and `share:` locator, then identifies
root origins and deterministic order without claiming an installation
provider. An explicit override path may be displayed for that invocation
because the user supplied it. Any displayed path equal to `HOME` or below it is
rendered with `$HOME`; no username-bearing home prefix is shown.

Roots, usernames, hostnames, and machine identity are not persisted in catalog
data, modules, profiles, plans, repository logs, or exported compositions.
`DOTFILES_SHARE_ROOTS` is local lookup input only and is not a schema field.

## Implementation-ready test contract

The prerequisite-validation increment must prove:

- explicit roots precede XDG and generic system roots;
- duplicate roots retain only their first position;
- valid `XDG_DATA_HOME` and ordered `XDG_DATA_DIRS` roots work;
- `$HOME/.local/share` is used only when `XDG_DATA_HOME` is absent or invalid
  and `HOME` is valid;
- `/usr/local/share` precedes `/usr/share`;
- an arbitrary user-chosen installation root works only when explicitly added,
  and no provider-specific root is inferred;
- invalid explicit roots fail the complete check with actionable errors;
- invalid ambient XDG entries are disclosed and ignored;
- relative or malformed `HOME` produces no derived root;
- empty path-list entries never mean the current directory;
- schema-1 traversal and malformed-locator rejection remains unchanged;
- a regular file inside a root succeeds;
- missing files, directories, devices, FIFOs, sockets, broken links, and
  escaping links fail;
- an internal symlink to a regular file succeeds;
- artifact contents are never opened or executed;
- package managers, application managers, plugin managers, registries,
  executables, shell profiles, and the network are never queried; and
- output uses `$HOME` abbreviation and contains no hostname or username.

## Consequences

- Artifact discovery is deterministic and independent of software providers.
- XDG and generic Unix data locations work automatically; every other location
  uses one explicit local override mechanism.
- Invalid explicit input fails closed, while invalid ambient input is visible
  and safely ignored.
- Presence validation remains blocked until this proposal is owner-reviewed,
  accepted, and implemented with the complete test contract above.

## Alternatives considered

- **Build in common provider prefixes:** convenient for some installations but
  violates tool neutrality and becomes an incomplete provider registry.
- **Search the whole filesystem:** provider-neutral but slow,
  non-deterministic, privacy-invasive, and unsafe.
- **Ask package managers or registries:** discovers some installations but
  violates the configuration-only boundary and excludes unmanaged tools.
- **Store absolute roots in modules or profiles:** deterministic but not
  portable and risks committing machine identity.

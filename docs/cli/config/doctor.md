# Diagnose local selection health

[Command guide](../README.md) / Config doctor

Validate only the standard local selection storage, canonical schema-1
document, and fresh current-platform composition.

Available · Read-only · Chezmoi required for catalog validation.

## Usage

~~~text
dotfiles config doctor [--platform macos|debian]
~~~

Only one optional `--platform` is accepted. Without it, the command detects
macOS or supported Debian-family Linux. Selectors, additions, `--yes`,
destination or state-path overrides, repair/reset options, positional
arguments, repeated options, and unknown flags are invalid syntax.

## Healthy result

A healthy standard selection prints exactly:

~~~text
Local selection file: healthy
Schema: 1
Composition for debian: valid
~~~

The final platform matches the current invocation. No healthy line is printed
until all checks succeed.

Doctor always diagnoses the standard active-selection file. It validates safe
standard-root derivation; root and dedicated-directory containment, ownership,
real type, access, and permissions; state-file ownership, regular type, link
count, and mode; repeated stable reads; canonical schema-1 bytes and intent;
and fresh catalog resolution for the invocation platform. It ignores and
preserves the adjacent writer lock.

## Recovery

A missing root, directory, or state file is unhealthy. Create a new selection
with [`config set`](set.md) or [`config interactive`](interactive.md). An
unsafe, malformed, non-canonical, unknown-schema, corrupt, or catalog-invalid
file is never repaired or rewritten. Preserve or move it aside, repair unsafe
path types or permissions outside this command, save an explicit selection,
then rerun doctor.

Doctor reports only the narrow selection failure. It does not report root
writability, writer-lock age or ownership, prerequisites, artifacts,
applications, rendered content, Chezmoi status, managed HOME, plan/apply
readiness, repository health, network health, or cache performance.

## Effects and privacy

Doctor does not create, repair, normalize, chmod, chown, migrate, reset,
delete, lock, unlock, wait, render, compare, plan, apply, download, install, or
invoke a declared tool. It leaves state bytes, identity, mode, ownership,
modification time, the root tree, the writer lock, unrelated entries, caches,
and managed home data unchanged. Reading may update access time according to
the host filesystem's mount policy.

Diagnostics use catalog identifiers and only the stable `$XDG_CONFIG_HOME` or
`$HOME/.config` origin token when a location is necessary. They never print
file contents, raw private roots, usernames, hostnames, device or inode
identity, private infrastructure, secrets, or unrelated paths.

## Exit codes

- `0` — the standard local selection is healthy for the invocation platform.
- `2` — command syntax is invalid.
- `3` — platform, path, ownership, type, link, mode, canonical state, schema,
  catalog, composition, or observed read-drift validation failed; this includes
  missing local state.
- `4` — the required parser, catalog component, or safe read capability is
  unavailable.
- `129`, `130`, `143` — HUP, INT, or TERM interruption.

Errors go to standard error. Only the complete healthy summary goes to
standard output.

Next: [inspect effective intent](inspect.md), [save with flags](set.md), or
return to the [command guide](../README.md).

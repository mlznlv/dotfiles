# Profiles

Profiles are transparent, named compositions of module identifiers. This page
defines their contract. The production catalog remains empty until Phase 3, and
entries below `tests/fixtures` are test data, not curated profiles.

## Composition types

- **Curated profile:** reviewed in the repository for a documented user intent.
- **Saved custom profile:** captured from a user's explicit composition.
- **Explicit module set:** composed for one operation without first saving it.
- **Additional modules:** explicit additions to a base composition.

Profiles use composition, not inheritance. They contain no executable code and
do not silently select another profile based on a machine name.

## Planned layout

Profiles are grouped by intent, under `shell`, `personal`, `development`, and
`homelab`. The [catalog contract](../catalog.md) owns the path and naming rules.

The first planned profile is `shell.minimal`, containing `shell.zsh`,
`shell.zsh.autosuggestions`, and `prompt.starship`. Later curated profiles can
represent a personal MacBook Air, a developer Mac Pro workstation, a
Debian-family remote development guest, a general homelab server, and narrow
security-lab and hypervisor-host targets. These are explicit choices, not
automatic experience levels.

## Resolution

A profile records requested module identifiers. The resolver expands
dependencies, validates compatibility and conflicts, and shows the ordered
resolved set. Saving can record both the requested set and resolver metadata,
but requested identifiers remain the portable source of intent.

Unknown, unavailable, or incompatible modules must produce an actionable error.
Importing or selecting a profile never applies system changes.

## Save and share

The planned CLI will support local and repository scopes:

- Local profiles are private to the machine and live outside version control.
- Repository profiles are intentionally reviewed, documented, and shareable.
- Export produces a portable, versioned data file.
- Import validates data and stores it without executing or applying it.

Exports must exclude usernames, hostnames, private addresses, local absolute
paths, secrets, tokens, and provider credentials.

## Documentation requirement

Every curated profile is introduced or changed with a matching page below this
directory, covering each applicable section of
[the profile documentation template](template.md).

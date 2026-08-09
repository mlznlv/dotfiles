# Profiles

Profiles are transparent, named compositions of module identifiers. This page
defines their contract. The production catalog releases `shell.minimal`.
Catalog entries below tests/fixtures are test data, not curated profiles.

## Composition types

- **Curated profile:** reviewed in the repository for a documented user intent.
- **Saved custom profile:** captured from a user's explicit composition.
- **Explicit module set:** composed for one operation without first saving it.
- **Additional modules:** explicit additions to a base composition.

Profiles use composition, not inheritance. They contain no executable code and
do not silently select another profile based on a machine name.

Profiles contain only explicit module identifiers. They never contain software
installation behavior, prerequisite declarations, provider choices, or hidden
platform defaults. Selecting a platform does not select a profile or tool.

## Layout

Profiles are grouped by intent.

~~~text
.chezmoidata/profiles/
├── shell/
│   └── minimal.toml
├── personal/
├── development/
└── homelab/
~~~

The first released profile is shell.minimal, containing shell.zsh,
shell.zsh.autosuggestions, and prompt.starship.

Later curated profiles can represent:

- A personal MacBook Air used for browsing, routines, and homelab access.
- A developer Mac Pro workstation.
- A Debian-family remote development guest.
- A general homelab server.
- Narrow security-lab and hypervisor-host targets.

These are explicit choices, not automatic experience levels.

See the [catalog contract](../catalog.md) for the strict TOML schema and path rules.

## Resolution

A profile records requested module identifiers. The resolver expands
dependencies, validates compatibility and conflicts, and shows the ordered
resolved set. Saving can record both the requested set and resolver metadata,
but requested identifiers remain the portable source of intent.

Unknown, unavailable, or incompatible modules must produce an actionable error.
Importing or selecting a profile never applies system changes.

The resolved set contains exactly the requested identifiers plus dependencies
declared by those modules. For example, a profile may visibly request Zsh,
autosuggestions, and Starship; Starship remains independent of Zsh, and a
future Ghostty or VS Code module appears only when listed explicitly.

## Save and share

The planned CLI will support local and repository scopes:

- Local profiles are private to the machine and live outside version control.
- Repository profiles are intentionally reviewed, documented, and shareable.
- Export produces a portable, versioned data file.
- Import validates data and stores it without executing or applying it.

Exports must exclude usernames, hostnames, private addresses, local absolute
paths, secrets, tokens, prerequisite overrides, and provider credentials.

## Documentation requirement

Every curated profile is introduced or changed with a matching page below this
directory. The page must include:

- Intent and intended audience.
- Requested modules and why each is included.
- Resolved dependencies.
- Supported platforms and expected target types.
- Optional additions and known conflicts.
- Security, privacy, resource, and connectivity effects.
- Example selection, plan, verification, and limitations.
- Test coverage.

Start from [the profile documentation template](template.md).

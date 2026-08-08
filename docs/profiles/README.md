# Profiles

Profiles are transparent, named compositions of module identifiers. This page
defines their planned contract. No profiles are implemented in the architecture
foundation.

## Composition types

- **Curated profile:** reviewed in the repository for a documented user intent.
- **Saved custom profile:** captured from a user's explicit composition.
- **Explicit module set:** composed for one operation without first saving it.
- **Additional modules:** explicit additions to a base composition.

Profiles use composition, not inheritance. They contain no executable code and
do not silently select another profile based on a machine name.

## Planned layout

Profiles are grouped by intent.

~~~text
.chezmoidata/profiles/
├── shell/
│   └── minimal.toml
├── personal/
├── development/
└── homelab/
~~~

The first planned profile is shell.minimal, containing shell.zsh,
shell.zsh.autosuggestions, and prompt.starship.

Later curated profiles can represent:

- A personal MacBook Air used for browsing, routines, and homelab access.
- A developer Mac Pro workstation.
- A Debian-family remote development guest.
- A general homelab server.
- Narrow security-lab and hypervisor-host targets.

These are explicit choices, not automatic experience levels.

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

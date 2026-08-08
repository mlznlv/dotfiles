# ADR 0002: Use modules and profiles for composition

- Status: Accepted
- Date: 2026-08-07
- Supersedes: None
- Superseded by: None

## Context

The same repository must support a personal MacBook Air, a developer Mac Pro,
and multiple Debian-family homelab targets. A monolithic configuration would
either install too much everywhere or accumulate implicit machine conditions.

Users also need to compose a small setup, such as Zsh, autosuggestions, and
Starship, and later save and share it.

## Decision

Define a **module** as the smallest documented, selectable unit of capability.
A module declares its identifier, compatibility, dependencies, conflicts,
exclusive group, provider requests, and chezmoi data.

Define a **profile** as a named, curated list of module identifiers and
documented intent. Profiles use composition, not inheritance. Dependency-only
grouping belongs in a profile rather than a synthetic module.

Allow one curated profile, a saved custom profile, or an explicit module set as
the base composition. Allow explicitly selected additional modules when they do
not conflict.

Resolve dependencies deterministically, reject cycles and conflicts before
planning, and show the complete resolved set to the user.

## Consequences

- Configuration can be reused across roles without copy-and-paste.
- Small and custom setups remain first-class.
- Every module and profile requires documentation, validation, and tests.
- Catalog evolution needs schema versions and compatibility rules.
- Too many tiny modules could make discovery difficult, so modules must
  represent meaningful user capabilities.
- Profiles remain transparent because they contain identifiers rather than
  hidden behavior.

## Alternatives considered

- **One configuration per machine:** simple initially, but duplicates shared
  settings and exposes machine identity.
- **Role inheritance:** concise for related roles, but resolution becomes
  implicit and fragile.
- **Tags only:** flexible, but tags do not express dependencies, conflicts, or a
  reviewed user intent.
- **One module per tool:** predictable, but sometimes splits a single capability
  across meaningless implementation details.

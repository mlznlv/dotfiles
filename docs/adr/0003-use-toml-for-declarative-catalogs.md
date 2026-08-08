# ADR 0003: Use TOML for declarative catalogs

- Status: Accepted
- Date: 2026-08-07
- Supersedes: None
- Superseded by: None

## Context

Module and profile catalogs need a stable, reviewable data format. The format
must express identifiers, arrays, platform constraints, dependencies, provider
requests, and options without becoming an executable extension language.

YAML is concise but has a broad and sometimes surprising type system. Supporting
both YAML and TOML would add parsing, validation, documentation, and migration
paths without adding user value.

Users should not need to understand the storage format for normal setup.

## Decision

Use TOML as the only versioned format for module and repository profile
catalogs. Store manifests in category directories below the chezmoi data tree.

Use chezmoi's local configuration for machine-local choices. Expose supported
configuration operations through the dotfiles CLI so normal users do not edit
TOML.

Version catalog schemas explicitly. Reject unknown required schema versions and
unknown fields where silent acceptance could hide a mistake.

Do not treat catalog values as shell source or evaluate catalog text.

## Consequences

- Catalog reviews have one syntax and one validation path.
- TOML maps well to typed scalars, arrays, and tables.
- Users receive CLI validation and help instead of storage-format instructions.
- Maintainers must keep manifests declarative and avoid encoding complex logic
  in nested tables.
- Local configuration and repository catalogs can both use TOML while remaining
  separate in scope and lifecycle.
- Sharing needs a documented, versioned data representation.

## Alternatives considered

- **YAML:** widely used and readable, but implicit types and multiple equivalent
  representations make strict validation harder.
- **JSON:** unambiguous and easy to parse, but less comfortable for maintained
  catalogs and does not support comments.
- **YAML and TOML:** flexible for contributors, but doubles surface area and
  creates avoidable inconsistency.
- **Shell files:** easy for the planned CLI to source, but executable input is
  unsafe and difficult to validate.

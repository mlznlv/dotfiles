# ADR 0009: Define pre-release schema versioning

- Status: Proposed
- Date: 2026-08-10
- Supersedes: ADR 0007 (schema numbering and compatibility only, if accepted)
- Superseded by: None

## Context

The catalog is still pre-release. `next` is the integration branch, and no
stable release from the current product line has established an external
catalog compatibility boundary. Internal design iterations nevertheless became
module schemas 1, 2, and 3. Supporting those unreleased iterations adds parser
branches, provider fields, fixtures, migration language, and inconsistent
module/profile versions without protecting a real released consumer.

A schema number represents an external compatibility boundary, not the count of
internal design iterations.

## Decision

Until the first stable catalog release, the root catalog, every module, and
every profile use schema 1. Schema 1 contains the current configuration-only
module contract: metadata, platforms, dependencies, conflicts, exclusive
groups, static platform prerequisites, and selected chezmoi sources. Provider
requests are not part of the contract.

The implementation accepts only schema 1. It contains no compatibility branch
for the unreleased provider-based schema-2 iteration or the unreleased
configuration-only schema-3 iteration. Fixtures are named for behavior rather
than discarded internal version numbers.

Schema 2 may be introduced only after schema 1 has shipped from the stable
branch and a later incompatible change has an accepted ADR that defines its
compatibility and migration boundary. Compatible additions do not increment
the schema automatically.

This decision supersedes only ADR 0007's schema-3 numbering and schema-2
compatibility clauses. ADR 0007's substantive decisions remain binding:
configuration-only modules, static prerequisites, tool neutrality, chezmoi
ownership, strict safety validation, explicit selection, and no software
installation.

ADR 0008 remains Proposed. Its portable artifact-discovery design is rebased
from schema 3 to schema 1 by this change, but is not accepted automatically.

## Consequences

- Catalog, module, and profile manifests use one consistent schema number.
- Provider extraction, validation, ownership, and compatibility code is
  removed before it becomes a released maintenance obligation.
- The hierarchical `shell.zsh` manifest and documentation layout remains the
  schema-1 path contract.
- The next Phase 3 increment remains read-only prerequisite presence
  validation; this decision adds no presence behavior.
- Accepting this ADR before merge is required because it changes an accepted
  clause of ADR 0007.

## Alternatives considered

- **Keep schemas 1, 2, and 3:** preserves unreleased iterations but creates
  maintenance cost without a compatibility consumer.
- **Rename only production manifests:** leaves dead extraction, validation,
  fixtures, and documentation behind.
- **Start at schema 3 for the first stable release:** technically possible, but
  misleading because versions 1 and 2 were never stable contracts.

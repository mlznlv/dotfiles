# Architecture decision records

Architecture decision records explain choices that constrain future work. They
are immutable after acceptance except for factual corrections. A later decision
supersedes an earlier one instead of rewriting history.

## Status values

- **Proposed:** under review and not binding.
- **Accepted:** binding for new work.
- **Superseded:** replaced by a newer ADR.
- **Rejected:** considered and not selected.

## Index

| ADR | Status | Decision |
| --- | --- | --- |
| [0001](0001-use-chezmoi-as-the-foundation.md) | Accepted | Use chezmoi as the foundation |
| [0002](0002-use-modules-and-profiles-for-composition.md) | Accepted | Use modules and profiles for composition |
| [0003](0003-use-toml-for-declarative-catalogs.md) | Accepted | Use TOML for declarative catalogs |
| [0004](0004-enforce-single-provider-ownership.md) | Accepted | Enforce single-provider ownership |
| [0005](0005-provide-a-thin-dotfiles-cli.md) | Accepted | Provide a thin dotfiles CLI |
| [0006](0006-define-phase-3-execution-contract.md) | Accepted | Define the Phase 3 execution contract |
| [0007](0007-define-configuration-only-modules.md) | Accepted | Define configuration-only modules |
| [0008](0008-define-portable-share-artifact-discovery.md) | Accepted | Define portable share artifact discovery |
| [0009](0009-define-pre-release-schema-versioning.md) | Accepted | Define pre-release schema versioning |
| [0010](0010-define-selection-aware-shell-rendering.md) | Accepted | Define selection-aware shell rendering |

ADR 0007 partially supersedes ADRs 0004 and 0006. Their unaffected safety
decisions and immutable historical text remain accepted.

ADR 0008 replaces ADR 0007's fixed artifact roots with explicit, XDG,
HOME-derived, and generic system data roots. Command and artifact presence
checking is implemented.

ADR 0009 supersedes only ADR 0007's schema-numbering and compatibility clauses.
Its substantive configuration-only decisions remain accepted.

ADR 0010 defines an ephemeral render context, exact shell-target ownership,
and selection-aware activation for the later managed-shell implementation.

Copy [the template](0000-template.md) when proposing a new decision. Use the next
four-digit sequence number and a lowercase kebab-case filename.

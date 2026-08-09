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
| [0006](0006-define-phase-3-execution-contract.md) | Proposed | Define the Phase 3 execution contract |

Copy [the template](0000-template.md) when proposing a new decision. Use the next
four-digit sequence number and a lowercase kebab-case filename.

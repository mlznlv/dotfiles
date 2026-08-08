# CLI

The planned dotfiles command is the user interface for discovery, composition,
configuration, planning, application, diagnosis, and profile sharing. It is not
implemented in the architecture foundation.

## Design rules

- Normal users do not edit catalog TOML.
- Read-only discovery and planning are available before mutation.
- Changing configuration never applies it.
- Applying is explicit and uses provider-native previews where possible.
- Interactive prompts have documented non-interactive behavior.
- Errors are actionable and distinguish invalid input from provider failure.
- Imported profile data is validated and never evaluated as code.
- Human output is clear; machine-readable output is versioned when introduced.

## Planned command surface

| Command | Effect | Earliest phase |
| --- | --- | --- |
| dotfiles help | Read-only help and discovery | 2 |
| dotfiles version | Read-only version information | 2 |
| dotfiles module list | List compatible or all modules | 2 |
| dotfiles module show | Inspect one module | 2 |
| dotfiles profile list | List curated and saved profiles | 2 |
| dotfiles profile show | Inspect requested and resolved modules | 2 |
| dotfiles resolve | Validate and display a composition | 2 |
| dotfiles plan | Preview provider and home-state changes | 3 |
| dotfiles apply | Apply an already validated composition | 3 |
| dotfiles config init | Create local choices without applying | 4 |
| dotfiles config show | Inspect sanitized local choices | 4 |
| dotfiles config set | Change local choices without applying | 4 |
| dotfiles doctor | Diagnose platform and provider readiness | 4 |
| dotfiles profile save | Save a custom composition | 5 |
| dotfiles profile export | Export portable profile data | 5 |
| dotfiles profile import | Validate and store profile data | 5 |

Names are design targets and may change in the implementation pull request with
an ADR update when the change affects architecture.

## Command contract

Every command or subcommand must ship with:

- A dedicated page below docs/cli.
- Purpose, syntax, arguments, flags, defaults, and examples.
- Whether it is read-only or mutating.
- Preconditions, provider effects, and network or privilege requirements.
- Interactive and non-interactive behavior.
- Exit statuses and stable machine-output behavior, if any.
- Security and privacy notes.
- Unit or integration tests and help-output coverage.

Use [the command documentation template](command-template.md).

## Safety model

Plan is read-only. Apply must use the same validated composition and must make
drift visible if the target changes between planning and application. Dangerous
connectivity or privilege changes require an additional explicit
acknowledgement.

The initial implementation does not provide destructive cleanup. A future
removal or prune command requires its own ADR, recovery behavior, and tests.

# CLI

The dotfiles command currently provides read-only discovery, validation, and
resolution. Installation, configuration mutation, provider planning, and apply
behavior are not implemented.

## Requirements

Help and version work without dependencies. Catalog commands require chezmoi,
which is the accepted home-state foundation and TOML loader.

## Design rules

- Normal users do not edit catalog TOML.
- Every available command is read-only.
- Platform detection uses only factual operating-system information.
- Errors distinguish usage, invalid catalog data, and missing dependencies.
- Catalog data is never evaluated as shell code.
- Output is deterministic for identical inputs.
- No command invokes a package or home-state provider.

## Available command surface

| Command | Effect | Documentation |
| --- | --- | --- |
| dotfiles help | Show usage | [help](help.md) |
| dotfiles version | Show development version | [version](version.md) |
| dotfiles catalog validate | Validate all catalog data | [catalog validate](catalog/validate.md) |
| dotfiles module list | List compatible or all modules | [module list](module/list.md) |
| dotfiles module show | Inspect one module | [module show](module/show.md) |
| dotfiles profile list | List compatible or all profiles | [profile list](profile/list.md) |
| dotfiles profile show | Inspect one profile | [profile show](profile/show.md) |
| dotfiles resolve | Expand and validate a composition | [resolve](resolve.md) |

The production module and profile catalogs are empty until Phase 3.

## Exit statuses

- 0: Success.
- 2: Invalid command usage.
- 3: Unsupported platform, invalid catalog, or failed resolution.
- 4: Required dependency or internal implementation file unavailable.

## Future command surface

Configuration, planning, applying, diagnostics, and profile-sharing commands
remain planned in the [roadmap](../roadmap.md). Changing configuration will not
apply it, and applying will remain explicit.

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

The available CLI reads static repository data and operating-system facts only.
It does not write configuration, save state, access secrets, invoke providers,
or modify the target.

A future removal or prune command requires its own ADR, recovery behavior, and
tests.

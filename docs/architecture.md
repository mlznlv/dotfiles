# Architecture

## Purpose and status

This document defines the target architecture. The read-only catalog,
discovery commands, and deterministic resolver are released. Configuration
planning, prerequisite validation, managed home state, and apply are planned.

[ADR 0007](adr/0007-define-configuration-only-modules.md) defines the
configuration-only direction. Schema 3 and the migrated production catalog are
released. Schema 2 remains compatibility-only historical input, and no command
interprets its provider fields as prerequisites.

## Product boundary

The target product manages explicitly selected home configuration. It does not
install, update, remove, or bootstrap shells, prompts, terminals, editors,
multiplexers, remote-access tools, runtimes, packages, package managers, or
applications.

Chezmoi is the sole rendering, diff, and application engine for managed home
configuration. The repository CLI provides tool-neutral discovery,
composition, validation, prerequisite checking, planning, and explicit apply.
It does not maintain a second state engine or invoke software installers. This
boundary reproduces repository-managed configuration, not the externally
assembled software baseline of a complete developer environment.

## System model

~~~text
target = platform facts + explicit composition + explicit additional modules
composition = curated profile | saved custom profile | explicit module set
~~~

~~~mermaid
flowchart LR
    A["Explicit CLI intent"] --> D["Deterministic resolver"]
    B["Platform facts"] --> D
    C["Module and profile catalogs"] --> D
    D --> E["Rendered-target ownership validation"]
    E --> F["Read-only prerequisite validation"]
    F --> G["Chezmoi configuration diff"]
    G --> H["User review and explicit intent"]
    H --> I["Chezmoi apply for selected sources"]
    F -->|"missing"| J["Actionable error; no mutation"]
~~~

## Neutral core

The core knows these generic concepts:

- **Platform:** detected operating-system facts used only for compatibility and
  module-declared platform data.
- **Module:** one optional, documented configuration capability.
- **Profile:** a transparent list of module identifiers.
- **Prerequisite:** a static command, application, or artifact identifier
  checked without execution.
- **Rendered target:** a home-relative file path produced by a selected chezmoi
  source.
- **Plan:** an ordered, read-only description of configuration diffs.

The core has no mandatory shell, prompt, terminal, editor, multiplexer,
remote-access client, IDE, package manager, or application. It contains generic
validation for identifiers and presence checks, not application-specific
selection or installation logic.

Catalogs are TOML. Chezmoi merges files below `.chezmoidata` into one data root,
so manifests use explicit `dotfiles.modules` and `dotfiles.profiles`
namespaces. The CLI asks chezmoi to parse TOML and then performs strict semantic
validation and deterministic resolution without applying home state.

## Optional configuration modules

Tool behavior exists only in explicitly selected modules. Dependencies express
configuration coupling, never a convenient software bundle.

| Module | What selection means | What it does not select |
| --- | --- | --- |
| `shell.zsh` | Manage selected Zsh configuration after verifying Zsh | Starship, a terminal, an editor, or Zsh installation |
| `shell.zsh.autosuggestions` | Manage the extension configuration; explicitly depends on `shell.zsh` | A package provider or unrelated shell tools |
| `prompt.starship` | Manage Starship configuration after verifying Starship | Zsh or any other shell |
| `terminal.ghostty` (future) | Manage selected Ghostty configuration after verifying Ghostty | Zsh, Starship, tmux, or VS Code |
| `editor.vscode` (future) | Manage selected VS Code configuration after verifying VS Code | A terminal, shell, prompt, or extensions not explicitly modeled |
| `multiplexer.tmux` (future) | Manage selected tmux configuration after verifying tmux | A terminal, shell, or remote-access client |

Selecting no modules produces no tool prerequisites and no managed targets.
Profiles contain only visible module identifiers; resolver output shows every
explicit dependency before planning.

## Prerequisite validation

The replacement for provider-install requests is static, platform-specific
prerequisite data. Command names are checked for presence without running them.
Application identifiers use a generic platform presence interface. Artifact
locators use a validated root and relative path and are checked for regular-file
presence without opening, reading, sourcing, or executing the file. Values
cannot contain arguments, unsafe paths, URLs, shell syntax, hooks, executable
payloads, provider instructions, or credentials.

Schema 3 defines `share:<relative-path>` artifact locators. Relative paths
reject empty, `.` and `..` segments, globs, variables, tildes, control
characters, and shell metacharacters. [ADR 0008](adr/0008-define-portable-share-artifact-discovery.md)
proposes deterministic XDG, user-override, platform, and Nix search roots with
strict containment and disclosure rules. Presence validation must not be
implemented until that provider-neutral discovery contract is accepted.

Prerequisite validation is part of both plan and apply preconditions. A missing
tool produces an error naming the module, platform, prerequisite kind, and
identifier, with guidance to provide it outside this project. No chezmoi diff
eligible for apply is produced, and no configuration changes occur.

The initial platform identifiers remain `macos` and `debian`. Modules declare
support and per-platform prerequisites explicitly. A future platform extends
the platform registry and generic checks; it does not make any application part
of the core. Platform detection never infers intent from a hostname, username,
or machine identity.

## Configuration ownership

Chezmoi owns all managed home files and templates. Within the catalog, one
selected module owns each normalized rendered target. The canonical key is:

~~~text
chezmoi:target:<normalized-home-relative-target>
~~~

Normalization removes the source-root prefix and template suffix and translates
supported chezmoi attributes. The ownership record also names the declaring
module. Repeated keys fail deterministically before prerequisite validation,
planning, or apply, even when their source paths or intended content differ.

## Planned configuration flow

The flow below depends on the schema migration. It is not available in the
current CLI.

1. Resolve the explicit composition for the detected or requested platform.
2. Validate static catalog data, platform compatibility, and dependencies.
3. Normalize rendered targets and reject ownership collisions.
4. Check only prerequisites declared by selected modules, without executing
   them.
5. Ask chezmoi for diffs limited to the selected source paths.
6. Print a stable plan ordered by rendered target and module.
7. On explicit apply intent, recompute all preconditions and the diff, then ask
   chezmoi to apply only those selected paths.

A plan step contains an ordinal, module identifier, canonical target, action,
and sanitized description. Every effect is a chezmoi-managed configuration
effect. There are no package, provider-installation, download, or package-manager
steps. A completely empty diff prints `No changes.`

Apply requires the exact interactive answer `yes`, or explicit `--yes` for
non-interactive input. Any missing prerequisite, invalid catalog, collision,
unsupported platform, or diff failure stops before mutation. Apply performs no
automatic rollback, removal, prune, uninstall, or broad cleanup. Repeated apply
must converge idempotently.

## State, safety, and privacy

The target system derives state from versioned catalogs and chezmoi source
state, local chezmoi configuration, generic prerequisite presence, and chezmoi
diffs. It has no custom state database. Disposable generated caches must not
become authority.

- Catalog and imported profile data are static and never evaluated as code.
- Plans and logs exclude secrets, usernames, hostnames, private addresses, and
  machine identity.
- Unsupported module/platform combinations fail before configuration changes.
- Missing tools fail closed and never trigger installation.
- Commands display intended configuration changes before mutation.
- Managed state is additive or convergent and never destructively cleans
  unrelated files.

## Documentation contract

Every module, profile, and CLI command is documented with its implementation.
Documentation distinguishes released behavior from proposed and planned
behavior. Architecture decisions are recorded in [ADRs](adr/README.md), layout
in [repository structure](repository-structure.md), and delivery order in the
[roadmap](roadmap.md).

## Decisions

- [ADR 0001: Use chezmoi as the foundation](adr/0001-use-chezmoi-as-the-foundation.md)
- [ADR 0002: Use modules and profiles for composition](adr/0002-use-modules-and-profiles-for-composition.md)
- [ADR 0003: Use TOML for declarative catalogs](adr/0003-use-toml-for-declarative-catalogs.md)
- [ADR 0004: Enforce single-provider ownership](adr/0004-enforce-single-provider-ownership.md)
- [ADR 0005: Provide a thin dotfiles CLI](adr/0005-provide-a-thin-dotfiles-cli.md)
- [ADR 0006: Define the Phase 3 execution contract](adr/0006-define-phase-3-execution-contract.md)
- [ADR 0007: Define configuration-only modules](adr/0007-define-configuration-only-modules.md)

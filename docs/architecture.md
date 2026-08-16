# Architecture

## Purpose and status

This document defines the target architecture. The read-only catalog,
discovery commands, resolver, command/artifact prerequisite checks, and
isolated selected-source renderer and planner are released. Safe selected
configuration apply is also released. Application checks and saved local
selection remain planned.

[ADR 0007](adr/0007-define-configuration-only-modules.md) defines the
configuration-only direction. [ADR 0009](adr/0009-define-pre-release-schema-versioning.md)
defines one strict pre-release schema for the root, modules, and profiles.
Provider requests and unreleased schema compatibility are not part of the
active contract.

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
    F --> R["Ephemeral selected-source rendering"]
    R --> G["Chezmoi configuration diff"]
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
- **Render context:** closed, invocation-local selection facts passed to
  chezmoi and removed before return.
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

Schema 1 defines `share:<relative-path>` artifact locators. Relative paths
reject empty, `.` and `..` segments, globs, variables, tildes, control
characters, and shell metacharacters. [ADR 0008](adr/0008-define-portable-share-artifact-discovery.md)
defines deterministic explicit, XDG, validated HOME-derived, and generic
system data roots with strict containment and disclosure rules. It performs no
provider, registry, executable, shell-profile, or network discovery. The
released checker implements this contract for selected artifact prerequisites.

The released prerequisite command, renderer, planner, and apply path check only
resolved selected modules for the target platform. External commands are
located through absolute PATH entries; applications fail closed until their
platform semantics are accepted. Prerequisite validation is a plan and apply
precondition. A missing tool produces an error naming the module, prerequisite
kind, and identifier, with guidance to provide it outside this project. No
actionable plan or configuration mutation is produced.

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

## Read-only shell rendering boundary

[ADR 0010](adr/0010-define-selection-aware-shell-rendering.md) defines the
accepted rendering contract. The repository implements it as an internal,
read-only adapter; there is no public render command and no home mutation.

A render invocation translates its explicit composition into a
closed, temporary chezmoi override-data file containing only the platform,
ordered resolved module identifiers, selected source identifiers, and the
validated canonical autosuggestions artifact path required by the Zsh template.
The file is mode `0600`, removed on every exit path, and never saved as profile,
catalog, plan, or authorization state.

The accepted ownership boundary is exact:

| Module | Rendered target | Activation responsibility |
| --- | --- | --- |
| `shell.zsh` | `.zshrc` | All Zsh startup and optional integration activation |
| `shell.zsh.autosuggestions` | `.config/zsh/autosuggestions.zsh` | Autosuggestions tool configuration only |
| `prompt.starship` | `.config/starship.toml` | Shell-independent Starship configuration only |

The Zsh-owned template compares only known validated module identifiers and
never globs integration files. Autosuggestions uses only the current, fully
resolved ADR 0008-contained artifact. Starship Zsh activation appears only when
both Zsh and Starship are in the resolved explicit composition. Omitting Zsh
renders no `.zshrc`; a narrower Zsh render contains no stale optional
activation and deletes no other output.

The adapter stages only selected targets in an isolated caller-owned temporary
directory by asking chezmoi to render each validated source mapping. Static
files remain byte-identical. The result is planner input, not reusable
authority, and is never applied to a home directory.

## Configuration planning and apply flow

Steps 1–5 below are implemented by the internal renderer, steps 6–7 by the
planner, and step 8 by the released apply path.

1. Resolve the explicit composition for the detected or requested platform.
2. Validate static catalog data, platform compatibility, and dependencies.
3. Normalize rendered targets and reject ownership collisions.
4. Check only prerequisites declared by selected modules, without executing
   them.
5. Build the sanitized ephemeral render context.
6. Ask chezmoi for status limited to exact selected target paths, with private
   invocation state and user customization disabled.
7. Print a stable, path-sanitized plan ordered by rendered target and module.
8. On explicit apply intent, recompute all preconditions and the diff, then ask
   chezmoi to apply only those selected paths.

A plan step contains an ordinal, module identifier, canonical target, action,
and validated source identifier. Every effect is a chezmoi-managed
configuration effect. There are no package, provider-installation, download,
or package-manager steps. A completely empty selected-target comparison prints
`No changes.`

Planning accepts only the current invocation's literal, canonical HOME. It
rejects unsafe selected target types and path links, captures raw Chezmoi
status privately, and assembles public output only after every status record
maps to one selected owner. Unexpected, duplicate, out-of-order, deletion, or
unselected records fail without partial plan output. The autosuggestions
artifact is revalidated immediately before comparison and must resolve to the
same canonical contained regular file used by the fresh render.

Apply requires the exact interactive answer `yes`, or explicit `--yes` for
non-interactive input. It first prints the complete current plan, then rebuilds
every catalog, prerequisite, artifact, context, render, and comparison fact
after confirmation. Canonical records, selected-source mappings, context,
artifact identity, and rendered bytes must match the privately retained first
pass before mutation begins.

Chezmoi applies one changed selected target at a time in plan order with user
configuration, custom tools, prompts, externals, scripts, recursion, and
unselected targets excluded. Apply rechecks destination safety immediately
before each invocation and verifies the resulting regular file byte-for-byte
against the fresh render before counting it completed. Autosuggestions is
revalidated again immediately before the Zsh-owned `.zshrc` target. The first
failure stops later invocations and reports completed, failed, and unattempted
targets without rollback. Repeated apply converges idempotently.

## State, safety, and privacy

The target system derives state from versioned catalogs and chezmoi source
state, generic prerequisite presence, and current selected destination state.
The planner disables local chezmoi configuration and custom diff behavior. It
has no custom state database. Disposable generated caches must not become
authority.

- Catalog and imported profile data are static and never evaluated as code.
- Render data is closed, ephemeral, sanitized, and never authority.
- Raw comparison output, cache, and persistent state remain mode-restricted and
  are removed before the planner returns.
- Displayed-plan authority, apply output, fresh render data, cache, and state
  remain mode-restricted and are removed on success, cancellation, failure, and
  handled signals.
- Plans and logs exclude secrets, usernames, hostnames, private addresses, and
  machine identity.
- Unsupported module/platform combinations fail before configuration changes.
- Missing tools fail closed and never trigger installation.
- Commands display intended configuration changes before mutation.
- Apply recomputes that intent after confirmation and delegates only exact
  changed selected targets to Chezmoi.
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

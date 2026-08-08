# Architecture

## Purpose

This document defines the target architecture for the new dotfiles system. It is
normative for implementation work. The repository is currently in an
architecture-only phase; none of the planned commands or modules is available
yet.

## System model

A target installation is resolved from detected platform facts, one profile or
a custom composition, and optional additional modules.

~~~text
target = platform + composition + additional modules
composition = curated profile | saved custom profile | explicit module set
~~~

The resolver produces a deterministic desired state. Providers compare that
state with the machine and propose a plan. Applying a plan must be explicit,
repeatable, and safe.

~~~mermaid
flowchart LR
    A["CLI intent"] --> B["Platform detection"]
    C["Module catalog"] --> D["Resolver"]
    E["Profile catalog"] --> D
    B --> D
    A --> D
    D --> F["Desired state"]
    F --> G["Provider plans"]
    G --> H["User review"]
    H --> I["Safe apply"]
    I --> J["Actual state"]
~~~

## Core concepts

- **Target**: the machine and user account being configured.
- **Platform**: detected operating-system facts used for compatibility checks.
- **Module**: the smallest documented, selectable unit of capability.
- **Profile**: a named, curated composition of module identifiers.
- **Custom profile**: a user-saved composition that can be exported and shared.
- **Provider**: the single owner that converges one kind of resource.
- **Plan**: an ordered description of proposed, non-applied changes.
- **Desired state**: the resolved configuration requested by the user.
- **Actual state**: the machine state observed by providers.

A profile is composition, not inheritance. A module can declare dependencies,
conflicts, supported platforms, and an exclusive group. Dependency expansion
must be deterministic. A conflict or unsupported selection must fail before
changes begin.

## Foundation

Chezmoi owns home-directory configuration and supplies templating, diffing, and
application semantics. A thin repository CLI will provide discovery,
composition, validation, planning, and orchestration. It will not replace
chezmoi or maintain a second copy of chezmoi state.

Catalogs are stored as TOML for maintainers. Users interact through the CLI and
are not required to edit TOML.

## Provider ownership

Each capability has exactly one owner.

| Capability | Owner |
| --- | --- |
| macOS packages and applications | Homebrew |
| runtimes and versioned developer tools | mise |
| Linux packages requested by modules | mise |
| managed external repositories | mise |
| home-directory files and templates | chezmoi |
| interactive shell experience | Zsh |
| prompt rendering | Starship |
| macOS terminal interface | Ghostty |
| persistent terminal sessions | tmux |
| secure shell access | OpenSSH |
| private network reachability | Tailscale |

A module can request resources from several providers, but it cannot introduce
a competing owner. Provider overlap is a validation error.

## Terminal stack

Terminal, multiplexer, shell, and prompt are separate layers.

~~~text
Ghostty or another terminal
  -> tmux when selected
    -> Zsh
      -> Starship prompt
        -> shell extensions such as autosuggestions
~~~

This separation lets a remote Debian host use Zsh and Starship without
installing a macOS terminal application.

## Platform scope

The initial platform families are:

- macOS on personal and developer workstations.
- Debian-family Linux on Ubuntu, Kali, and similar homelab guests.

Proxmox infrastructure management is outside this repository. A Proxmox host
can later be treated only as a carefully scoped Debian-family target.

Platform detection is factual. It must not infer personal identity, host
identity, or a hidden profile.

## State and convergence

The system must derive state from three sources:

1. Versioned repository catalogs and chezmoi source state.
2. Local chezmoi configuration for user choices and machine-local facts.
3. Provider observations of the current machine.

There is no custom state database in the initial design. Generated cache data
must be disposable.

Planning is read-only. Applying requires an explicit command. Repeated apply
operations must converge without duplicating content or reinstalling resources
unnecessarily. The initial product does not remove unmanaged files, packages,
accounts, or services.

## Security and privacy boundaries

- Secrets, tokens, private keys, and machine identity never enter the catalog.
- Local answers are stored only in chezmoi's local configuration when needed.
- Imported profiles contain declarative module identifiers and options, never
  executable code.
- Remote downloads require an owning provider and integrity controls.
- Commands must show intended changes before mutation and avoid broad cleanup.
- Public examples use fictional values and sanitized machine names.

## Documentation contract

Architecture decisions are recorded in [ADRs](adr/README.md). Repository layout
is defined in [repository structure](repository-structure.md). Delivery order
and acceptance criteria are defined in the [roadmap](roadmap.md).

Every module, profile, and CLI command must be documented in the same pull
request that introduces or changes it. Documentation must clearly distinguish
planned behavior from released behavior.

## Accepted decisions

- [ADR 0001: Use chezmoi as the foundation](adr/0001-use-chezmoi-as-the-foundation.md)
- [ADR 0002: Use modules and profiles for composition](adr/0002-use-modules-and-profiles-for-composition.md)
- [ADR 0003: Use TOML for declarative catalogs](adr/0003-use-toml-for-declarative-catalogs.md)
- [ADR 0004: Enforce single-provider ownership](adr/0004-enforce-single-provider-ownership.md)
- [ADR 0005: Provide a thin dotfiles CLI](adr/0005-provide-a-thin-dotfiles-cli.md)

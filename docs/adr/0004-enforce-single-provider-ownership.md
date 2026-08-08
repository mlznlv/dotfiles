# ADR 0004: Enforce single-provider ownership

- Status: Accepted
- Date: 2026-08-07
- Supersedes: None
- Superseded by: None

## Context

A composed environment can involve packages, runtimes, applications, home
files, shells, prompts, terminals, remote access, and networking. If two tools
manage the same resource, convergence becomes order-dependent and removal or
upgrade behavior becomes unsafe.

The repository needs clear boundaries that remain consistent across modules and
profiles.

## Decision

Assign exactly one owner to each capability:

| Capability | Owner |
| --- | --- |
| macOS packages and applications | Homebrew |
| runtimes, versioned tools, Linux tool packages, and managed repositories | mise |
| home-directory files and templates | chezmoi |
| shell experience | Zsh |
| prompt | Starship |
| macOS terminal interface | Ghostty |
| persistent terminal sessions | tmux |
| secure shell access | OpenSSH |
| private network reachability | Tailscale |

Catalog validation must reject duplicate or competing requests for the same
resource. Modules describe desired capabilities; provider adapters translate
those requests and must not assume ownership outside this table.

Adding a provider or changing ownership requires a new ADR and a migration
plan.

## Consequences

- Plans are explainable and repeated application can converge predictably.
- Modules can be combined without relying on provider execution order.
- Contributors must classify every managed resource.
- A tool that could manage several resource types may be intentionally limited.
- Cross-platform differences stay inside an owner's adapter instead of
  producing overlapping owners.
- Migration between owners requires explicit transition handling.

## Alternatives considered

- **Prefer one provider by execution order:** simple, but hides conflicts and
  makes outcomes order-dependent.
- **Allow profiles to choose providers:** flexible, but fragments support and
  multiplies test combinations.
- **Let each module decide:** locally convenient, but composition would create
  duplicate package and file ownership.
- **Use one universal configuration manager:** reduces adapters but poorly fits
  the native strengths and user expectations of all supported platforms.

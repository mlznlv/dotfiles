# Roadmap

This roadmap describes delivery order, not calendar commitments. Each phase
must remain small enough for review and must meet its acceptance criteria
before dependent work begins.

## Phase 1: Architecture foundation

**Status:** Complete.

**Objective:** replace the legacy implementation with a clean, documented
foundation.

**Deliverables:**

- Architecture, repository structure, accepted ADRs, and phased roadmap.
- MIT license and public contribution, security, and conduct policies.
- Documentation templates for modules, profiles, and CLI commands.
- Issue and pull-request templates.
- Automated Markdown, link, and secret validation.

**Acceptance criteria:**

- The pull request contains no executable dotfiles implementation.
- The legacy tree is absent from the replacement branch.
- Documentation consistently describes planned behavior as planned.
- Documentation and secret-scanning checks pass.

**Non-goals:** installation, catalog parsing, provider integration, or home
configuration.

## Phase 2: Catalog and resolver

**Status:** Verified.

**Objective:** implement a read-only core that discovers and resolves catalog
entries.

**Deliverables:**

- Thin Bash CLI skeleton.
- TOML module and profile schemas with validation.
- Platform detection for macOS and Debian-family Linux.
- Deterministic dependency, conflict, and exclusive-group resolution.
- Commands for help, module listing, profile listing, and resolution previews.
- Unit and fixture tests plus command documentation.

**Acceptance criteria:**

- Identical inputs produce identical ordered results.
- Invalid identifiers, cycles, conflicts, and unsupported platforms fail with
  actionable messages.
- All commands are read-only.
- No provider is invoked.

**Non-goals:** installation or configuration changes.

**Depends on:** phase 1.

## Phase 3: Minimal shell vertical slice

**Status:** Catalog composition implemented; provider observation next.

**Objective:** prove end-to-end planning and safe application with a small,
useful composition.

**Implementation increments:**

1. **Execution contract:** accept ADR 0006 and specify schema 2, ownership,
   provider boundaries, plan ordering, apply safety, paths, and command
   contracts. Documentation only. Depends on Phase 2.
2. **Shell catalog composition (complete):** release modules shell.zsh,
   shell.zsh.autosuggestions, and prompt.starship plus profile shell.minimal
   under the accepted schema, with validation and resolution fixtures. Depends
   on the accepted execution contract.
   Before the next product increment, formalize `next` as the integration
   branch and retain `master` as the stable branch.
3. **Provider observation adapters:** add read-only Homebrew, mise, and chezmoi
   observations and normalized fixture coverage for macOS and Debian. Depends
   on the shell catalog composition.
4. **Deterministic planning:** implement `dotfiles plan`, ownership collision
   checks, stable plan construction, disclosures, no-change behavior, and
   failure tests. Depends on provider observation adapters.
5. **Chezmoi shell state:** add the selected Zsh, autosuggestions, and Starship
   source files and rendering tests without adding apply orchestration. Depends
   on deterministic planning.
6. **Safe application:** implement `dotfiles apply`, interactive and
   non-interactive intent checks, ordered provider execution, stop-on-failure
   reporting, and idempotency tests. Depends on all earlier Phase 3 increments.

Each increment is one focused pull request and updates its command, module, or
profile documentation in the same change. Implementation increments branch from
and integrate into `next`. Promotion from `next` to stable `master` is a
separate, explicitly owner-reviewed release decision, not an implementation
increment. Saved plans, rollback, and removal remain outside every increment.

**Acceptance criteria:**

- A clean supported target can preview and apply the profile.
- Zsh, autosuggestions, and Starship work after a new shell starts.
- A second apply is idempotent.
- No unrelated files or packages are removed.

**Non-goals:** workstation applications, remote access, or broad package sets.

**Depends on:** phase 2.

## Phase 4: Configuration workflow

**Status:** Planned.

**Objective:** make normal setup possible without editing TOML.

**Deliverables:**

- Interactive and flag-based configuration commands.
- Local chezmoi configuration schema and validation.
- Inspect and doctor commands.
- Clear separation between changing choices and applying them.
- Migration-free reset of generated cache data.

**Acceptance criteria:**

- A user can select a profile and optional modules entirely through the CLI.
- Configuration changes never apply system changes implicitly.
- Local settings contain no secrets or repository-visible machine identity.
- Invalid combinations are rejected before apply.

**Depends on:** phase 3.

## Phase 5: Saved and shared profiles

**Status:** Planned.

**Objective:** let users preserve and share custom compositions safely.

**Deliverables:**

- Save, export, import, and inspect profile commands.
- Local and repository profile scopes.
- Portable serialization with schema versioning.
- Validation that imported profiles contain data, not executable code.

**Acceptance criteria:**

- A custom composition round-trips without semantic changes.
- Exported profiles contain no local paths, secrets, or machine identity.
- Import never applies changes.
- Missing or incompatible modules produce actionable errors.

**Depends on:** phase 4.

## Phase 6: Personal and developer workstations

**Status:** Planned.

**Objective:** support the personal MacBook Air and developer Mac Pro roles
through explicit profiles.

**Deliverables:**

- Personal-client and developer-workstation profiles.
- Curated CLI, version-control, editor, terminal, and runtime modules.
- Homebrew, mise, chezmoi, Ghostty, and tmux integration within their ownership
  boundaries.
- Role-specific documentation and platform tests.

**Acceptance criteria:**

- Profiles share modules without duplicated configuration.
- Personal and developer choices remain explicit and inspectable.
- Provider ownership validation prevents duplicate resource management.
- Apply remains idempotent on supported macOS targets.

**Depends on:** phase 5.

## Phase 7: Remote development hosts

**Status:** Planned.

**Objective:** support Ubuntu, Kali, and other Debian-family homelab guests.

**Deliverables:**

- Remote developer and general server profiles.
- OpenSSH, Tailscale, tmux, shell, operations, and container modules.
- Headless and remote-session validation.
- Debian-family compatibility matrix.

**Acceptance criteria:**

- Remote profiles do not request macOS-only resources.
- Kali-specific differences are explicit rather than inferred from a hostname.
- Remote access changes are planned safely and cannot lock out an active user
  without an explicit acknowledgement.
- Repeated apply converges.

**Depends on:** phases 5 and 6.

## Phase 8: Security and hypervisor roles

**Status:** Planned.

**Objective:** add narrowly scoped hardened and Proxmox-host compositions.

**Deliverables:**

- Security-lab and hypervisor-host profiles.
- Security, network, and operations modules with explicit risk notes.
- Guardrails for privileged and connectivity-affecting changes.
- Recovery documentation.

**Acceptance criteria:**

- Proxmox infrastructure, guests, storage, and cluster lifecycle remain outside
  scope.
- Privileged changes require an explicit preview and acknowledgement.
- Recovery paths are tested and documented.
- No profile weakens a target by default.

**Depends on:** phase 7.

## Phase 9: Hardening and release

**Status:** Planned.

**Objective:** prepare the integrated implementation for explicit promotion to
`master` and a stable public release.

Development continues to integrate through `next`. Stable releases reach
`master` only through separate promotion pull requests. The `legacy` branch
remains only as a read-only recovery snapshot.

**Deliverables:**

- End-to-end clean-machine tests and upgrade tests.
- Versioning, changelog, release, and support policies.
- Bootstrap integrity and failure-recovery tests.
- Release-readiness checklist and legacy-branch removal decision.

**Acceptance criteria:**

- Supported targets pass installation and idempotency tests.
- Security and privacy review has no unresolved high-risk findings.
- Documentation matches the released CLI.
- A production release and legacy-branch removal each require an explicit
  maintainer decision.

**Depends on:** all previous phases.

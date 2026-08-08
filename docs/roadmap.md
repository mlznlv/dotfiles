# Roadmap

This roadmap describes delivery order, not calendar commitments. Each phase
must remain small enough for review and must meet its acceptance criteria
before dependent work begins.

## Phase 1: Architecture foundation

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

**Objective:** prove end-to-end planning and safe application with a small,
useful composition.

**Deliverables:**

- Modules shell.zsh, shell.zsh.autosuggestions, and prompt.starship.
- Curated profile shell.minimal.
- Chezmoi source files and provider requests required by those modules.
- Plan and apply commands with confirmation and non-interactive safeguards.
- macOS and Debian-family test coverage.
- Module, profile, and command documentation.

**Acceptance criteria:**

- A clean supported target can preview and apply the profile.
- Zsh, autosuggestions, and Starship work after a new shell starts.
- A second apply is idempotent.
- No unrelated files or packages are removed.

**Non-goals:** workstation applications, remote access, or broad package sets.

**Depends on:** phase 2.

## Phase 4: Configuration workflow

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

## Phase 9: Hardening, release, and cutover

**Objective:** prepare a stable public release and controlled replacement of the
legacy default branch.

**Deliverables:**

- End-to-end clean-machine tests and upgrade tests.
- Versioning, changelog, release, and support policies.
- Bootstrap integrity and failure-recovery tests.
- Cutover checklist for merging next into the default branch.

**Acceptance criteria:**

- Supported targets pass installation and idempotency tests.
- Security and privacy review has no unresolved high-risk findings.
- Documentation matches the released CLI.
- The default branch changes only after an explicit maintainer decision.

**Depends on:** all previous phases.

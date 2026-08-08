# ADR 0001: Use chezmoi as the foundation

- Status: Accepted
- Date: 2026-08-07
- Supersedes: None
- Superseded by: None

## Context

The project needs reproducible home configuration across macOS and
Debian-family Linux. It also needs templates, platform conditionals, previews,
safe application, and a mature path for managing dotfiles. Building all of
these capabilities would create a large custom maintenance and security burden.

The project still needs a higher-level composition model for modules, profiles,
package ownership, and a user-friendly CLI.

## Decision

Use chezmoi as the foundation and sole owner of home-directory files and
templates.

Add a thin project CLI that resolves modules and profiles, validates intent, and
orchestrates provider plans. The CLI delegates home-state diff and application
to chezmoi. It must not implement a parallel home-file engine or custom state
database.

Keep catalogs compatible with chezmoi data and templates where practical.

## Consequences

- The project inherits mature cross-platform templating and application
  behavior.
- Users can inspect chezmoi diffs and use familiar recovery mechanisms.
- Chezmoi becomes a required foundation dependency.
- The project must document the boundary between the CLI and chezmoi.
- Module abstractions must compile into provider requests and chezmoi data
  without hiding actual changes.
- Some desired behavior may require adapting to chezmoi conventions.

## Alternatives considered

- **Custom Go application:** strong distribution and typing, but duplicates
  solved dotfile behavior and expands the first release substantially.
- **Dotdrop or yadm:** capable dotfile managers, but chezmoi better matches the
  desired templating, local data, diff, and apply workflow.
- **Home Manager or Nix:** powerful declarative systems, but would impose a
  larger ecosystem and migration on both macOS and Debian-family targets.
- **Ansible:** appropriate for infrastructure orchestration, but heavier than
  needed for user home state and overlaps with the provider model.

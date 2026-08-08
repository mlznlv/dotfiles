# ADR 0005: Provide a thin dotfiles CLI

- Status: Accepted
- Date: 2026-08-07
- Supersedes: None
- Superseded by: None

## Context

Users need to discover modules, select or compose profiles, configure a target,
preview changes, apply changes, diagnose problems, and save or share a custom
composition. Requiring direct TOML and chezmoi configuration edits would expose
implementation details and provide inconsistent validation.

A custom compiled application would increase bootstrapping, packaging, and
maintenance work before the model is proven.

## Decision

Provide a thin command named dotfiles, initially implemented in portable Bash.

The CLI owns user interaction, catalog discovery, composition, validation, and
provider orchestration. Chezmoi and other providers continue to own their
specific state and operations.

Every mutating command must have a documented read-only preview or clearly show
its intended effect. Changing configuration must not apply it. Imported data
must be validated and must never be executed.

Each command must ship with help text, command documentation, tests, defined
exit behavior, and non-interactive behavior where relevant.

Reconsider a compiled implementation only after measured complexity,
performance, portability, or distribution constraints justify another ADR.

## Consequences

- The initial CLI is easy to inspect and bootstrap on supported systems.
- Users get one coherent interface without learning catalog storage.
- Bash portability and error handling require strict conventions and tests.
- The CLI must remain an orchestrator rather than grow replacement provider
  logic.
- Machine-readable output may require a small, documented compatibility layer.
- A later language migration is possible because behavior is defined by command
  contracts.

## Alternatives considered

- **No CLI:** minimal code, but pushes schema knowledge and unsafe manual steps
  onto users.
- **Go CLI immediately:** excellent distribution and structure, but premature
  before command behavior and composition rules stabilize.
- **Python CLI:** expressive, but introduces interpreter and environment
  bootstrapping questions.
- **Direct chezmoi commands only:** useful as an escape hatch, but does not model
  modules, profiles, or provider ownership.

# 0006: Keep a minimal shell extension boundary

## Status

Accepted

## Context

The first release supports Zsh only. Lifecycle concerns such as configuration loading, staging, atomic activation, diffing, backups, and status reporting are reusable. Rendering, validation, loader paths, conflict detection, and defaults are shell-specific.

Introducing a complete multi-shell framework before a second implementation would add abstractions with no validated consumer.

## Decision

Define one small internal `shellDefinition` boundary for shell metadata:

- shell name;
- segment names;
- optional commands;
- loader file;
- configuration directory;
- generated file extension.

Zsh remains the only registered implementation. The existing lifecycle consumes segment and dependency metadata from this definition.

Do not add dynamic plugins, public provider APIs, or generic render/migration interfaces yet. When a second shell is implemented, extract renderer, validator, loader builder, and conflict detector behind interfaces using both implementations as evidence for the contract.

## Consequences

- Zsh remains the only supported shell.
- Shell-specific metadata has one explicit owner.
- Adding another shell does not require redesigning configuration lifecycle or filesystem safety.
- Some Zsh-specific rendering and migration code remains in the current package until a second implementation justifies extraction.
- The project avoids speculative generalization and runtime plugin complexity.

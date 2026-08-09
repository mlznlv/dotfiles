# Module category.identifier

- Status: Planned
- Category: category
- Supported platforms: list
- Documentation owner: maintainer or team

## Purpose

Describe the user-visible capability and why it belongs in one module.

## Result

Describe the expected state after a successful apply.

## Dependencies and conflicts

List required module identifiers, conflicts, and the exclusive group, if any.

## Prerequisites

List static platform command or application identifiers. Confirm that no value
contains executable or installation instructions.

## Managed home state

List files or templates selected through chezmoi.

## Options

Document each option, type, default, validation, privacy classification, and
whether changing it requires apply.

## Plan and apply

Explain preview behavior, mutation behavior, confirmations, and idempotency.

## Verification

Give safe steps to verify the capability.

## Rollback and recovery

Explain how to recover from failure. Do not promise removal behavior that is not
implemented.

## Platform notes

Describe supported-platform differences and explicitly unsupported targets.

## Security and privacy

Describe prerequisite checks, privileges, network access, and sensitive local
configuration data. Configuration apply must not download or install software.

## Tests

List schema, resolver, unit, integration, and platform coverage.

## Examples

Show sanitized CLI usage and expected outcomes.

## Known limitations

List boundaries and deferred work.

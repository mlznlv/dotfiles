# Pull request

## Summary

Describe the user-visible outcome and why this change is needed.

## Scope

List the included work and explicit non-goals.

## Branch contract

- [ ] This implementation pull request targets `next`, not `master` or
      `legacy`.
- [ ] The branch started from the latest `next` relevant to this work.

## Architecture and ownership

- Relevant ADRs:
- Managed resources and their single owners:
- Supported platforms:
- Dependencies, conflicts, or exclusive groups:

## Safety and privacy

Describe privileges, network access, local data, rollback, and any connectivity
risk. Confirm that examples and fixtures contain no secrets or machine identity.

## Validation

List the checks and platforms used to validate the change.

## Documentation contract

- [ ] Architecture or behavior changes include an ADR when needed.
- [ ] The roadmap is updated when delivery scope or order changes.
- [ ] Every changed module has matching documentation and tests.
- [ ] Every changed profile has matching documentation and tests.
- [ ] Every changed CLI command has matching documentation, help, and tests.
- [ ] Provider ownership remains unique.
- [ ] Documentation links and repository checks pass.
- [ ] No secrets, credentials, private addresses, hostnames, usernames, or
      personal absolute paths are committed.
- [ ] No destructive cleanup is introduced without an accepted ADR and recovery
      design.

## Follow-up work

List intentionally deferred work.

# Contributing

## Development

Requirements: Go 1.23+, Zsh 5.8+, Git.

```bash
go vet ./...
go test -race ./...
go build ./...
```

Keep the YAML contract backward-compatible within `version: 1`. Breaking configuration changes require a new schema version and an explicit migration path.

Contributions should include tests for success and failure paths. File-system changes must preserve user-owned files and retain the previous generated state when validation fails.

Do not commit real hostnames, usernames, email addresses, access tokens, shell history, private paths, or company-specific configuration. Use synthetic fixtures.

Keep optional integrations guarded by command availability. Do not add package installation or remote code execution to the core tool.

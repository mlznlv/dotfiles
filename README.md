# dotfiles

A modular, reproducible, and security-conscious developer environment for macOS and Debian-family Linux.

> [!IMPORTANT]
> The read-only schema-2 shell catalog and resolver are available. Managed
> configuration and apply behavior are not implemented yet.

## Start here

The [user guide](docs/user-guide/README.md) provides the shortest setup and
composition workflow. Use the [command guide](docs/cli/README.md) for exact
syntax and examples.

## Goals

- Compose machines from independently selectable modules.
- Provide curated profiles without preventing custom compositions.
- Keep one owner for every rendered configuration target.
- Make every change inspectable, repeatable, and safe to reapply.
- Keep secrets, machine identity, and private infrastructure outside Git.

## Target platforms

The planned targets are:

- macOS
- Debian-family Linux, including Debian, Ubuntu, and Kali
- A narrowly scoped Proxmox host role in a later roadmap phase

Support will be introduced incrementally and documented per module.

## Architecture

The system will combine platform facts with an explicit module composition.
Each tool configuration is optional, and chezmoi will remain the only managed
home-configuration engine. The proposed direction verifies that selected tools
already exist but never installs or updates software.

Read the [architecture](docs/architecture.md) and
[architecture decisions](docs/adr/README.md) for the normative design and
proposals under review.

## Read-only commands

With chezmoi available, users and contributors can inspect and resolve the shell catalog:

~~~text
./bin/dotfiles help
./bin/dotfiles catalog validate
./bin/dotfiles module list --all
./bin/dotfiles profile list --all
./bin/dotfiles resolve --profile shell.minimal --platform debian
~~~

These commands do not install packages, change configuration, call providers, or
apply home state.

## Documentation

- [User guide](docs/user-guide/README.md)
- [Architecture](docs/architecture.md)
- [Catalog](docs/catalog.md)
- [Roadmap](docs/roadmap.md)
- [Repository structure](docs/repository-structure.md)
- [Modules](docs/modules/README.md)
- [Profiles](docs/profiles/README.md)
- [Command guide](docs/cli/README.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## Project status

The architecture foundation, schema-2 validation, and first shell composition
are established. The solution remains read-only. Proposed ADR 0007 defines a
configuration-only, tool-neutral direction; owner acceptance and a focused
schema migration are the next blockers in the [roadmap](docs/roadmap.md).

Development integrates through `next`; `master` remains the stable branch until
an explicitly reviewed promotion. See [Contributing](CONTRIBUTING.md) for the
branch workflow.

## License

Licensed under the [MIT License](LICENSE).

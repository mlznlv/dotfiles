# dotfiles

A modular, reproducible, and security-conscious configuration layer for macOS
and Debian-family Linux.

> [!IMPORTANT]
> The read-only schema-1 shell catalog and resolver are available. Managed
> configuration and apply behavior are not implemented yet.

## Start here

The [user guide](docs/user-guide/README.md) provides the shortest setup and
composition workflow. Use the [command guide](docs/cli/README.md) for exact
syntax and examples.

## Goals

- Compose managed configuration from independently selectable modules.
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
Each tool configuration is optional, and chezmoi remains the only managed
home-configuration engine. Selected modules verify that their tools already
exist but never install or update software. The repository reproduces managed
configuration, not the external software baseline of a complete environment.

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

The architecture foundation, schema-1 validation, and migrated shell
composition are established. The solution remains read-only. Generic,
read-only prerequisite presence validation is the next increment in the
[roadmap](docs/roadmap.md).

Development integrates through `next`; `master` remains the stable branch until
an explicitly reviewed promotion. See [Contributing](CONTRIBUTING.md) for the
branch workflow.

## License

Licensed under the [MIT License](LICENSE).

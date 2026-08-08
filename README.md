# dotfiles

A modular, reproducible, and security-conscious developer environment for macOS and Debian-family Linux.

> [!IMPORTANT]
> The Phase 2 read-only catalog and resolver are available. Installation and apply behavior are not implemented yet.

## Goals

- Compose machines from independently selectable modules.
- Provide curated profiles without preventing custom compositions.
- Keep one authoritative provider for every capability.
- Make every change inspectable, repeatable, and safe to reapply.
- Keep secrets, machine identity, and private infrastructure outside Git.

## Target platforms

The planned targets are:

- macOS
- Debian-family Linux, including Debian, Ubuntu, and Kali
- A narrowly scoped Proxmox host role in a later roadmap phase

Support will be introduced incrementally and documented per module.

## Architecture

The system will combine an automatically detected platform with a curated, saved, or explicit module composition and optional additional modules. Chezmoi will manage home configuration, while Homebrew and mise will retain explicit package and runtime ownership.

Read the [architecture](docs/architecture.md) and accepted [architecture decisions](docs/adr/README.md) for the normative design.

## Read-only commands

With chezmoi available, repository contributors can inspect the empty production
catalog and the command surface:

~~~text
./bin/dotfiles help
./bin/dotfiles catalog validate
./bin/dotfiles module list --all
./bin/dotfiles profile list --all
~~~

These commands do not install packages, change configuration, call providers, or
apply home state.

## Documentation

- [Architecture](docs/architecture.md)
- [Catalog](docs/catalog.md)
- [Roadmap](docs/roadmap.md)
- [Repository structure](docs/repository-structure.md)
- [Modules](docs/modules/README.md)
- [Profiles](docs/profiles/README.md)
- [CLI](docs/cli/README.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## Project status

The architecture foundation and read-only catalog resolver are established. The production catalog is empty, and the solution remains non-installable. The next milestone is the minimal shell vertical slice described in the [roadmap](docs/roadmap.md).

## License

Licensed under the [MIT License](LICENSE).

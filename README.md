# dotfiles

A modular, reproducible, and security-conscious developer environment for macOS and Debian-family Linux.

> [!IMPORTANT]
> This repository is in its architecture phase. The new solution is not installable yet.

## Goals

- Compose machines from independently selectable modules.
- Provide curated profiles without preventing custom compositions.
- Keep one authoritative provider for every capability.
- Make every change inspectable, repeatable, and safe to reapply.
- Keep secrets, machine identity, and private infrastructure outside Git.

## Target platforms

The planned targets are:

- macOS
- Debian-family Linux, including Debian, Ubuntu, Kali, and Proxmox

Support will be introduced incrementally and documented per module.

## Architecture

The system will combine an automatically detected platform with either a curated profile or an exact custom module composition. Chezmoi will manage home configuration, while Homebrew and mise will retain explicit package and runtime ownership.

Read the [architecture](docs/architecture.md) and accepted [architecture decisions](docs/adr/README.md) for the normative design.

## Documentation

- [Architecture](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Repository structure](docs/repository-structure.md)
- [Modules](docs/modules/README.md)
- [Profiles](docs/profiles/README.md)
- [CLI](docs/cli/README.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## Project status

Implementation begins after the architecture foundation is accepted. The [roadmap](docs/roadmap.md) divides the work into reviewable pull requests, starting with a read-only catalog and resolver.

## License

Licensed under the [MIT License](LICENSE).

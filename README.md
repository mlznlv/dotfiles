# dotfiles

A modular, reproducible, and security-conscious configuration layer for macOS
and Debian-family Linux.

> [!IMPORTANT]
> The read-only schema-1 shell catalog, resolver, command/artifact prerequisite
> checks, isolated selected-source renderer, and configuration plan are
> available. Safe selected configuration apply and both flag-based and
> terminal-only interactive local selection are also available. No public
> render command or software installation behavior exists.

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

## Commands

With chezmoi available, users and contributors can inspect and resolve the shell catalog:

~~~text
./bin/dotfiles help
./bin/dotfiles catalog validate
./bin/dotfiles module list --all
./bin/dotfiles profile list --all
./bin/dotfiles resolve --profile shell.minimal --platform debian
./bin/dotfiles config set --profile shell.minimal --platform debian
./bin/dotfiles config interactive --platform debian
./bin/dotfiles prerequisite check --profile shell.minimal --platform debian
./bin/dotfiles plan --profile shell.minimal --platform debian
./bin/dotfiles apply --profile shell.minimal --platform debian
~~~

Discovery, resolution, prerequisite checking, and planning are read-only.
Planning compares only selected targets and does not print their contents.
`config set` and `config interactive` change only the CLI-owned local
active-selection file; existing selection-consuming commands do not load it
yet. Interactive saving requires terminal stdin and exact `yes` confirmation
when the proposed state differs.
`apply` prints and recomputes the complete plan, requires exact interactive
`yes` or `--yes`, and changes only verified selected home targets through
Chezmoi. No command installs packages or calls software providers.

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

The architecture foundation and minimal schema-1 shell vertical slice are
complete: explicit composition, prerequisites, isolated rendering,
deterministic planning, safe idempotent selected apply, and flag-based and
terminal-only interactive local selection are established. Application checks,
saved-selection consumption, broader modules, and stable promotion remain later
[roadmap](docs/roadmap.md) increments.

Development integrates through `next`; `master` remains the stable branch until
an explicitly reviewed promotion. See [Contributing](CONTRIBUTING.md) for the
branch workflow.

## License

Licensed under the [MIT License](LICENSE).

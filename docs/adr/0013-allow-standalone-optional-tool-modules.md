# ADR 0013: Allow standalone optional tool modules

- Status: Accepted
- Date: 2026-09-08
- Supersedes: None
- Superseded by: None
- Amends: ADR 0010

## Context

ADR 0010 fixed the rendering and Zsh-activation contract for the original
three-module shell slice: `shell.zsh`, `shell.zsh.autosuggestions`, and
`prompt.starship`. The implementation now provides the schema-1 catalog,
resolver, prerequisite checks, selected-source renderer, planner, and explicit
apply flow needed by another independently selectable configuration module.

The roadmap nevertheless places saved and shared profile portability in Phase
5 and broader workstation profiles in Phase 6. Treating those profile phases
as prerequisites for every new module would couple an independent
configuration file to unrelated profile work. It would also obscure how a
tool that owns its configuration but supports Zsh activation composes without
competing for `.zshrc`.

Atuin and mise are the first planned modules that need this extension. Both
have useful global configuration independent of Zsh, while their optional
interactive integration belongs in the Zsh-owned startup template. Their
runtime state is also substantially more sensitive and mutable than the two
static files this repository may manage.

## Decision

### Amendment scope

This ADR amends ADR 0010 without replacing it. ADR 0010's original shell slice,
render context, target mappings, selection matrix, and historical activation
order remain binding for the released modules. This decision extends those
rules to later standalone optional tool modules and fixes the contracts for
the planned `cli.atuin` and `runtime.mise` modules.

A standalone tool module may ship before Phase 5 when it uses the existing
schema-1 catalog, prerequisite, resolver, renderer, planner, and apply
contracts. It must not introduce a profile, state format, schema edition,
provider, installer, or new command merely to be independently selectable.

The following composition rules apply:

- The module has no dependency on `shell.zsh` merely because it supports Zsh
  integration.
- The tool module owns only its tool-specific configuration target.
- `shell.zsh` remains the sole owner of `.zshrc` and all activation syntax.
- Zsh activation appears only when `shell.zsh` and the relevant tool module
  are both in the resolved composition.
- Selecting the tool without Zsh manages only the tool configuration target
  and never creates, changes, or claims `.zshrc`.
- Selecting Zsh without the tool omits its activation. Applying a narrower Zsh
  composition removes an omitted tool's activation from `.zshrc` without
  deleting its configuration file or runtime-owned state.
- Repeated identifiers resolve once, every normalized target has one owner,
  and identical inputs produce byte-identical output.
- Unknown module identifiers never generate activation syntax.

Repository commands validate static prerequisites without executing the
selected tool. They never install software, contact a network service, invoke
a provider, or mutate tool runtime state. A user's later interactive shell may
run the fixed activation emitted by the Zsh-owned template; that shell runtime
behavior is not a repository-command effect.

### Planned Atuin module

The accepted implementation contract is exact:

| Field | Value |
| --- | --- |
| Identifier | `cli.atuin` |
| Manifest | `.chezmoidata/modules/cli/atuin.toml` |
| Documentation | `docs/modules/cli/atuin.md` |
| Chezmoi source | `home/dot_config/atuin/config.toml` |
| Managed target | `.config/atuin/config.toml` |
| Platforms | `macos`, `debian` |
| Command prerequisite | `atuin` on both platforms |
| Dependencies | None |
| Conflicts | None |
| Exclusive group | None |

The managed file contains exactly these privacy-first settings:

~~~toml
auto_sync = false
update_check = false
~~~

When `shell.zsh` and `cli.atuin` are both selected, the Zsh-owned template
emits exactly one activation:

~~~zsh
eval "$(atuin init zsh --disable-up-arrow --disable-ai)"
~~~

This keeps Atuin's conventional Ctrl-R binding while disabling its Up-arrow
and AI bindings. No other Atuin activation or binding syntax is managed.

Atuin owns its history, database, encryption key, account, session,
synchronization, cache, and all other runtime state. Repository commands never
read, copy, render, print, migrate, delete, or commit that state. No server
address, username, email, token, key, session, hostname, history data, or
machine identity may enter the repository. Beyond the exact
`auto_sync = false` privacy switch, no synchronization configuration may enter
the repository.

The contract follows Atuin's documented
[configuration path and settings](https://docs.atuin.sh/main/configuration/config/)
and [Zsh initialization flags](https://docs.atuin.sh/main/reference/init/).

### Planned mise module

The accepted implementation contract is exact:

| Field | Value |
| --- | --- |
| Identifier | `runtime.mise` |
| Manifest | `.chezmoidata/modules/runtime/mise.toml` |
| Documentation | `docs/modules/runtime/mise.md` |
| Chezmoi source | `home/dot_config/mise/config.toml` |
| Managed target | `.config/mise/config.toml` |
| Platforms | `macos`, `debian` |
| Command prerequisite | `mise` on both platforms |
| Dependencies | None |
| Conflicts | None |
| Exclusive group | None |

The managed file contains one table and exactly two settings:

~~~toml
[settings]
auto_install = false
auto_update = false
~~~

It contains no `[tools]`, environment, task, plugin, repository, bootstrap,
provider, package, service, dotfile, or shell-activation declaration.

When `shell.zsh` and `runtime.mise` are both selected, the Zsh-owned template
emits exactly one activation:

~~~zsh
eval "$(mise activate zsh)"
~~~

mise owns installed tools, plugins, downloads, caches, trust records,
lockfiles, credentials, and all other runtime state. Repository commands never
invoke mise, install tools, update mise, execute tasks, load project
environments, contact registries, or bootstrap resources.

The contract follows mise's documented
[global configuration path](https://mise.jdx.dev/configuration.html),
[settings](https://mise.jdx.dev/configuration/settings.html), and
[Zsh activation](https://mise.jdx.dev/cli/activate.html).

### Zsh activation order

The complete deterministic Zsh activation order becomes:

1. Zsh-owned core startup configuration.
2. Zsh autosuggestions configuration and validated artifact, when selected.
3. Atuin activation, when `shell.zsh` and `cli.atuin` are both selected.
4. mise activation, when `shell.zsh` and `runtime.mise` are both selected.
5. Starship activation, when `shell.zsh` and `prompt.starship` are both
   selected.

Each activation occurs at most once. Tool modules do not append to or
independently manage `.zshrc`, and the template does not scan or evaluate
catalog-supplied activation text.

### Deselecting a standalone tool

Selecting `cli.atuin` or `runtime.mise` alone selects exactly its configuration
target. An existing `.zshrc` is outside that apply and remains untouched.

When a composition that includes Zsh and either tool is narrowed while
retaining `shell.zsh`, the freshly rendered `.zshrc` omits the deselected
activation. The tool's existing configuration file and runtime-owned state
remain untouched. When `shell.zsh` itself is omitted, no module owns `.zshrc`
for that invocation, so repository commands neither rewrite it nor claim to
deactivate an existing integration. Removal and runtime cleanup remain
non-goals.

`shell.minimal` remains exactly `shell.zsh`,
`shell.zsh.autosuggestions`, and `prompt.starship`. Neither planned tool is
added to that or any other profile implicitly.

### Implementation test contract

Each later module implementation pull request must use isolated macOS and
Debian fixtures to prove that:

- its schema-1 manifest uses the accepted identifier, direct category path,
  documentation path, platform list, empty relationship fields, command
  prerequisite, and single Chezmoi source;
- its managed file is byte-identical to the exact accepted content and owns
  only the accepted target;
- selecting the tool alone renders and plans only its configuration target,
  leaves an existing `.zshrc` byte-identical, and does not select Zsh;
- selecting the tool with Zsh emits its exact Zsh-owned activation once;
- selecting Zsh without the tool omits that activation;
- repeated selection produces one resolved identifier, target, and activation;
- a mixed composition preserves the complete documented activation order;
- a narrower Zsh composition removes deselected activation while preserving
  existing tool configuration and simulated runtime state;
- `shell.minimal` resolution, targets, bytes, and activation remain unchanged;
- unknown modules and catalog data cannot emit activation or shell syntax;
- missing prerequisites fail before rendering, planning eligible for apply, or
  mutation, without running `atuin` or `mise`;
- rendering, planning, and apply invoke no tool, provider, installer, package
  manager, registry, or network probe; and
- fixtures, logs, plans, and diagnostics contain no history, credentials,
  account data, machine identity, runtime state, or local absolute path.

This ADR adds no manifest, managed source, template condition, fixture, test,
command, schema, or runtime behavior. Those changes belong to separate,
owner-reviewed implementation pull requests, one module per pull request.

### Roadmap relationship

This accepted gate permits standalone schema-1 configuration modules to ship
independently before Phase 5. It does not start or complete Phase 5 saved and
shared profile portability, does not start or complete Phase 6 workstation
profiles and broader curated compositions, and does not allow a profile to
bypass its declared dependencies.

## Consequences

- Small independent configuration capabilities no longer wait for unrelated
  profile serialization or workstation-composition work.
- Tool configuration and shell activation retain distinct owners.
- Atuin and mise have exact, privacy-preserving implementation boundaries
  before their manifests or managed files exist.
- The Zsh template will gain additional fixed identifier checks only in the
  corresponding implementation pull requests.
- Users remain responsible for installing, updating, and operating both tools
  and for all tool-owned runtime state.

## Alternatives considered

- **Wait for Phase 5 or Phase 6:** preserves strict phase order but couples
  independent configuration files to profile features they do not need.
- **Make each tool depend on Zsh:** simplifies activation tests but prevents
  shell-independent configuration and violates explicit composition.
- **Let tool modules own startup fragments:** decentralizes integration but
  competes with Zsh ownership and risks activating stale filesystem residue.
- **Add the tools to `shell.minimal`:** makes adoption implicit and changes an
  established profile rather than preserving optional selection.
- **Manage runtime state:** might reproduce more behavior, but would expose
  sensitive, mutable, machine-specific data and violate the configuration-only
  boundary.

# ADR 0007: Define configuration-only modules

- Status: Accepted
- Date: 2026-08-09
- Supersedes: ADR 0004 (part), ADR 0006 (part)
- Superseded by: ADR 0008 (artifact roots and symlink boundaries only); ADR 0009 (schema numbering and compatibility only)

## Context

The released resolver composes explicit modules deterministically, but schema 2
also encodes Homebrew and mise package requests. ADR 0004 assigns package and
tool owners, and ADR 0006 plans provider observation and package convergence.
Those decisions make software installation part of the product even though no
released command performs it.

The product direction is narrower: manage configuration for tools a user has
already chosen and installed. The core must remain neutral about shells,
prompts, terminals, editors, multiplexers, remote-access tools, package
managers, and applications.

## Decision

This ADR defines the contract for the schema and catalog migration that must
precede further Phase 3 implementation.

### Product boundary

The repository discovers, validates, resolves, plans, and explicitly applies
selected home configuration. Software installation, provider bootstrap,
package or runtime convergence, upgrades, uninstall, and application removal
are outside scope. Documentation may name an external prerequisite, but the CLI
and catalog must not encode or execute instructions to install it.

Chezmoi remains the only engine that renders, diffs, and applies managed home
configuration. No module or profile invokes Homebrew, mise, an operating-system
package manager, an application installer, or a downloaded setup script.

### Modules and profiles

A module is one meaningful, optional, tool-specific configuration capability.
Examples include `shell.zsh`, `shell.zsh.autosuggestions`, `prompt.starship`,
`terminal.ghostty`, and `editor.vscode`. Selecting no modules creates no tool
prerequisites and no managed targets. A platform never implies a module.

Dependencies are explicit configuration dependencies only. For example,
`shell.zsh.autosuggestions` may depend on `shell.zsh`, while
`prompt.starship`, `terminal.ghostty`, and `editor.vscode` remain independently
selectable. Profiles remain transparent lists of module identifiers. They
contain no prerequisite, installation, or application logic.

### Static prerequisites

A module may declare platform-specific arrays of required command names,
application identifiers, and artifact locators. They are static data used only
for read-only presence checks. Values are single identifiers, not commands:
arguments, whitespace, shell syntax, URLs, hooks, executable payloads, package
names tied to an installation provider, credentials, and registry data are
forbidden.

The replacement is schema 3 rather than a changed interpretation of schema 2.
Its additional fields are:

~~~toml
prerequisites.macos.commands = ["zsh"]
prerequisites.macos.applications = []
prerequisites.macos.artifacts = []
prerequisites.debian.commands = ["zsh"]
prerequisites.debian.applications = []
prerequisites.debian.artifacts = []
home.chezmoi.sources = ["home/dot_zshrc.tmpl"]
~~~

Command checks use an exact executable name and do not run the executable.
Application checks use a stable platform application identifier through a
generic presence-check interface.

An artifact locator has the form `<root>:<relative-path>`. Schema 3 defines the
generic `share` root. On macOS it searches `/opt/homebrew/share` and
`/usr/local/share`; on Debian it searches `/usr/share` and `/usr/local/share`,
in that order. Presence succeeds when the exact relative path is a regular file
under any root. A symlink is accepted only when its fully resolved target is a
regular file below `/opt/homebrew` or `/usr/local` on macOS, or below `/usr` or
`/usr/local` on Debian. Broken links and targets outside those roots fail. The
checker does not open, read, source, or execute the file.
The relative path must use `/`, remain non-empty, and contain no empty, `.`, or
`..` segment, glob, variable, tilde, control character, or shell metacharacter.
Absolute paths and unknown roots fail catalog validation. A locator may name an
externally installed script file as evidence; the ban on scripts prohibits
catalog-supplied executable payloads or instructions, not a presence-only file
identifier.

Adding a future platform extends the platform registry and generic command,
application, and artifact-root checks; it does not add application-specific
logic to the core.

### Validation, planning, and apply

Prerequisite validation is a precondition of both plan and apply. Plan resolves
the selected modules, validates platform compatibility and rendered-target
ownership, checks prerequisites without executing them, then asks chezmoi for a
configuration diff. A missing prerequisite names the module and identifier,
states that the user must provide it outside this project, and produces no plan
eligible for apply. A later diagnostic command may reuse the same check, but is
not required by this decision.

Each normalized rendered home target has exactly one owning module. The
canonical key remains `chezmoi:target:<home-relative-target>`, and the ownership
record includes the declaring module. Any repeated target across selected
modules fails deterministically before prerequisite checks, planning, or apply.

Apply recomputes prerequisites and the chezmoi diff in the same invocation,
displays every configuration effect, and requires explicit intent. It applies
only the selected source files through chezmoi. It is additive or convergent,
idempotent, and non-destructive: no removal, prune, uninstall, broad cleanup, or
implicit software installation is allowed. A failure produces no automatic
rollback.

### Platform neutrality

The supported platform identifiers remain `macos` and `debian`. Modules declare
their supported platforms, platform-specific prerequisites, and selected source
state. Unsupported combinations fail before any configuration change. Platform
detection provides facts only and never derives selection from a hostname,
username, machine identity, or hidden profile.

### Schema-2 migration

Schema 2 remains historical released input until a focused migration implements
schema 3. This ADR deprecates its Homebrew and mise fields immediately for new
manifests; it does not reinterpret them.

The migration must atomically add the new schema validator, convert the three
production modules and relevant fixtures, and produce an explicit
`schema 2 provider requests require migration` error if configuration planning
or apply encounters an unconverted schema-2 module. Read-only discovery and
resolution compatibility may remain temporarily. A later focused cleanup may
remove schema-2 provider fields after no production entry uses them.

| Current declaration | Planned migration |
| --- | --- |
| `providers.macos.homebrew.packages = ["zsh"]` | `prerequisites.macos.commands = ["zsh"]` |
| `providers.debian.mise.packages = ["zsh"]` | `prerequisites.debian.commands = ["zsh"]` |
| Homebrew/mise `zsh-autosuggestions` request | `share:zsh-autosuggestions/zsh-autosuggestions.zsh` artifact prerequisite on both platforms; no provider retained |
| Homebrew/mise `starship` request | Platform command prerequisite `starship`; no provider retained |
| `home.chezmoi.sources` | Retained with rendered-target ownership validation |
| Schema-2 provider collision fixtures | Replaced by prerequisite-safety and rendered-target collision fixtures |

## Supersession

This ADR supersedes only these clauses:

| Earlier ADR | Superseded clauses | Clauses that remain binding |
| --- | --- | --- |
| ADR 0004 | In **Decision**, every ownership-table row except “home-directory files and templates”; the sentence assigning provider adapters to translate requests; and package/provider scope in **Consequences** | Chezmoi ownership of home files; reject duplicate or competing rendered-target ownership; require a new ADR and migration when ownership changes |
| ADR 0006 | In **Decision**, schema-2 Homebrew/mise fields; the first three canonical keys; provider observation; provider-ordered steps; provider mutation; package/network/download/privilege disclosures; and the missing-provider paragraph. In the decision table, **Requests**, the provider portion of **Plan order**, **Effects**, and **Provider bootstrap** | Static non-executable catalog data; chezmoi source and target normalization; collision checks before effects; deterministic, read-only planning; fresh explicit apply and confirmation; stop and report on failure; idempotency; no rollback, removal, prune, uninstall, or cleanup; privacy and machine-identity exclusions |

ADRs 0001, 0002, 0003, and 0005 remain binding, narrowed to configuration-only
orchestration where their historical text mentions providers or packages.

## Testable consequences

- No selection means no prerequisite checks and no managed targets.
- Selecting Starship does not select a shell.
- Selecting Ghostty does not select Zsh, Starship, tmux, or VS Code.
- Selecting VS Code does not select a terminal or shell.
- Profiles resolve exactly their identifiers plus explicit dependencies.
- Present prerequisites allow configuration planning to continue.
- Missing prerequisites fail before a configuration plan or mutation.
- Prerequisite data containing arguments, URLs, unsafe artifact paths, or shell
  syntax fails validation.
- Two modules that render one target fail deterministically.
- Unsupported module/platform pairs fail before changes.
- Plans contain only chezmoi-managed configuration effects.
- Apply never invokes a package manager or installer and converges idempotently.
- Schema-2 provider fields are migrated explicitly, never reinterpreted.

## Consequences

- Users keep responsibility for installing and updating their chosen tools.
- The repository converges a reproducible configuration layer, not a complete
  developer environment or its externally installed software baseline.
- Modules are portable configuration units rather than software bundles.
- The core needs generic, read-only prerequisite checks but no package-provider
  adapters.
- Existing schema-2 production data requires a focused migration before Phase 3
  configuration planning begins.
- Tool-specific templates may still vary by platform without making a tool
  mandatory.

## Alternatives considered

- **Keep package convergence:** convenient bootstrap, but forces provider and
  ownership policy into a configuration product.
- **Offer installation as an optional module feature:** appears flexible, but
  makes module effects inconsistent and reintroduces provider coupling.
- **Store installation commands as prerequisites:** compact, but creates a
  generic command-execution and supply-chain boundary.
- **Infer prerequisites from source templates:** avoids fields, but hides module
  requirements and makes failures late and platform-dependent.
- **Reuse schema 2 with new meanings:** fewer versions, but silently changes
  released data and makes compatibility unsafe.

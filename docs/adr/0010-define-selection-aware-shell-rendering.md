# ADR 0010: Define selection-aware shell rendering

- Status: Proposed
- Date: 2026-08-15
- Supersedes: None
- Superseded by: None

## Context

The released schema-1 catalog can resolve an explicit composition and check its
command and `share:` prerequisites without mutation. Production modules still
select no chezmoi sources. Before adding shell templates, the repository needs
one contract connecting transient CLI selection to chezmoi rendering.

Without that boundary, templates could read hidden machine state, optional
modules could compete for `.zshrc`, stale fragments could remain active, or an
unchecked external script could be sourced. Saved local selection does not
exist until Phase 4, and the initial non-destructive product cannot remove
targets merely because their owners are omitted from a later selection.

## Decision

### Ephemeral composition input

A future `plan` or `apply` invocation accepts exactly the existing selection
flags: one of `--profile` and `--modules`, optional `--add`, and optional
`--platform`. The CLI validates the complete catalog, resolves dependencies,
checks target ownership and selected prerequisites, and constructs one render
context for that invocation.

The context is serialized as a mode-`0600` temporary data file and passed to
chezmoi with `--override-data-file`. It is removed on success, failure,
cancellation, or interruption. It is never merged into catalog TOML, chezmoi's
normal local configuration, an exported profile, a reusable plan, or another
state database. Plan and apply independently recompute it from current inputs.

The closed context contains only:

- context schema `1`;
- the target platform, exactly `macos` or `debian`;
- resolved module identifiers in resolver order;
- selected chezmoi source identifiers in deterministic target order; and
- for `shell.zsh.autosuggestions` only, the absolute artifact path returned by
  the successful ADR 0008 check for its declared `share:` locator.

Command/application names, commands, hooks, executable template data, secrets,
usernames, hostnames, private infrastructure, arbitrary catalog strings, and
unvalidated paths are not render data. Command presence remains a precondition,
not a template value. Each module and source identifier must equal a validated
catalog value from the selected resolved set; templates compare only fixed
known identifiers.

### Sources, targets, and ownership

The shell slice has exactly these planned source-to-target mappings:

| Owning module | Chezmoi source | Rendered target | Canonical key |
| --- | --- | --- | --- |
| `shell.zsh` | `home/dot_zshrc.tmpl` | `.zshrc` | `chezmoi:target:.zshrc` |
| `shell.zsh.autosuggestions` | `home/dot_config/zsh/autosuggestions.zsh` | `.config/zsh/autosuggestions.zsh` | `chezmoi:target:.config/zsh/autosuggestions.zsh` |
| `prompt.starship` | `home/dot_config/starship.toml` | `.config/starship.toml` | `chezmoi:target:.config/starship.toml` |

There is no generated composition target, fragment index, or selection file.
Only the owning module declares each source. Chezmoi remains the home-file
engine; module ownership identifies which selected capability is responsible
for the target.

### Zsh integration boundary

`shell.zsh` is the sole owner of `.zshrc` and every startup activation line in
it. The template receives the resolved module list and emits integrations only
for fixed compatible identifiers present in that list. It never scans, globs,
or automatically sources a directory.

The planned deterministic activation order is:

1. Zsh-owned core startup configuration.
2. When `shell.zsh.autosuggestions` is selected, its fixed configuration target
   and then its validated artifact.
3. When `prompt.starship` is also selected, exactly one static Zsh-owned
   `starship init zsh` activation.

Optional modules do not append to or independently manage `.zshrc`.
`shell.zsh.autosuggestions` owns only its tool configuration target.
`prompt.starship` owns only Starship configuration. The hard-coded Starship Zsh
activation syntax belongs to the Zsh template and is absent unless both module
identifiers are in the resolved composition. Selecting Starship alone never
selects Zsh and never creates or mutates `.zshrc`.

### Autosuggestions artifact and quoting

Autosuggestions keeps its explicit dependency on `shell.zsh`. Before rendering,
the checker must resolve the declared locator through ADR 0008, prove that it is
a regular file contained by its resolved root, and return that exact path as an
ephemeral fact. Rendering has no fallback search and never asks a provider,
registry, package manager, network service, or shell startup file for another
path.

The Zsh template can use only that validated path. It emits a static `source --`
line using a repository-owned quoting helper, never string concatenation from
catalog text. A path equal to or below HOME is rendered as a double-quoted
`$HOME` prefix plus a single-quoted, validated relative suffix. Other paths are
single-quoted with every literal single quote encoded by the standard shell
`'\''` sequence. Newline, carriage return, NUL, and control characters are
rejected before the context is built.

The raw path is local to the temporary context and the local rendered `.zshrc`.
It is not committed, exported, cached, or retained as plan authority. Plan and
log disclosure uses `$HOME` for HOME-contained paths, generic system paths as
written, and an origin token such as `DOTFILES_SHARE_ROOTS[1]/<relative-path>`
or `XDG_DATA_DIRS[2]/<relative-path>` for other local roots. A displayed diff
must apply the same sanitization and must not expose a username, hostname, or
private root. Apply recomputes the raw path instead of consuming a redacted or
saved result.

The future implementation must recheck the artifact immediately before
chezmoi diff and again before apply rendering. Successful earlier observation
is not authorization to source a replaced, escaped, or non-regular path.

### Stale files and deselection

`.zshrc` enumerates integrations from the current resolved set only. When a
future apply includes `shell.zsh`, a smaller composition converges the
Zsh-owned target and therefore removes activation lines for omitted optional
modules. It does not delete their existing configuration files. Those files
remain inactive from this `.zshrc` because it does not glob or source them.

Omitting `shell.zsh` selects no owner for `.zshrc`; plan and apply must not
rewrite, remove, or claim to deactivate an existing file. Similarly, omitting
Starship does not remove `.config/starship.toml`, and its possible use by an
unmanaged shell is outside this composition. Selecting no modules produces no
source targets, no mutation, and no cleanup. Removal, pruning, and broad
deactivation remain explicit non-goals.

### Rendering, plan, and apply separation

Rendering and fixture tests are read-only. A future plan recomputes selection,
ownership, prerequisites, context, and selected-source chezmoi diffs, then
prints sanitized effects. It passes only selected source identifiers to
chezmoi. A future apply repeats every precondition and render step, displays the
fresh plan, obtains explicit confirmation, and delegates only the selected
targets to chezmoi.

No rendered output, temporary context, prerequisite result, or displayed plan
is a reusable authorization token. Chezmoi is the only component allowed to
change managed home targets, and it is invoked only by the future apply path.

## Selection matrix

The behavior is identical on macOS and Debian; only the platform-specific
prerequisite arrays differ.

| Explicit composition | Selected source targets | `.zshrc` activation | Prerequisites consumed | Stale-file behavior | Future apply mutation |
| --- | --- | --- | --- | --- | --- |
| `shell.zsh` | `.zshrc` | Core Zsh only | `shell.zsh`: `zsh` command | Optional config files are not referenced | May converge `.zshrc` only |
| `prompt.starship` | `.config/starship.toml` | Not selected; untouched | `prompt.starship`: `starship` command | Existing `.zshrc` is outside this apply | May converge Starship config only |
| `shell.zsh,prompt.starship` | `.zshrc`, `.config/starship.toml` | Core Zsh, then exactly one Starship activation | Zsh and Starship command declarations | Autosuggestions config is not referenced | May converge both selected targets |
| `shell.zsh.autosuggestions` | `.zshrc`, `.config/zsh/autosuggestions.zsh` | Core Zsh, fixed autosuggestions config, then validated artifact | Zsh command declarations for dependency and module; module artifact | Starship config is not referenced | May converge both selected targets |
| `shell.minimal` | All three targets | Core Zsh, autosuggestions config and artifact, then one Starship activation | All selected module command/artifact declarations | Unknown fragments are never scanned | May converge all three targets |
| `shell.zsh` after `shell.minimal` | `.zshrc` | Re-rendered as core Zsh only | `shell.zsh`: `zsh` command | Old autosuggestions/Starship files remain, but this `.zshrc` activates neither | May converge `.zshrc`; no deletion |
| No modules | None | Not selected; untouched | None | Every existing file remains outside the invocation | No mutation or cleanup |

Profile selection, direct modules, and `--add` all use the same resolved-set
rules. The table introduces no implicit module: only the declared
autosuggestions-to-Zsh dependency expands selection.

## Implementation-ready test contract

The managed-shell implementation must prove, with isolated macOS and Debian
fixtures rather than real host identity or tools, that:

- identical selections and facts produce byte-identical rendered files;
- dependency-expanded order creates no duplicate source or activation;
- Zsh-only output contains no Starship or autosuggestions activation;
- Starship-only selection neither creates nor mutates `.zshrc`;
- Zsh plus Starship renders exactly one Zsh-owned Starship activation;
- autosuggestions renders one fixed configuration reference and one safely
  quoted source of the currently validated contained artifact, with no fallback;
- `shell.minimal` renders exactly the three mapped targets in the documented
  activation order;
- re-rendering Zsh with a smaller composition omits deselected integrations
  even when their old configuration files remain;
- no selection produces no managed targets;
- every target maps to one owner and duplicate canonical keys fail;
- malicious identifiers, paths, context fields, prerequisite output, quotes,
  or control characters cannot inject template or shell syntax;
- raw HOME, usernames, hostnames, and non-generic local roots do not appear in
  plan output, logs, snapshots, or fixtures;
- a replaced, broken, non-regular, looping, or escaping artifact fails before
  diff and before apply;
- rendering never invokes a provider, installer, package manager, registry,
  network service, prerequisite command, or unchecked artifact;
- fixture rendering writes no home file, uses no network or privilege, and
  removes its temporary context on every exit path; and
- plan and apply independently rebuild the context and never load a saved
  render result.

## Consequences

- The later managed-file task has exact sources, targets, ownership keys,
  template inputs, activation order, privacy rules, and expected combinations.
- Zsh remains the only startup-syntax owner while optional tool configuration
  remains independently owned.
- A narrower selected Zsh composition can deactivate integrations by
  converging `.zshrc` without destructive file cleanup.
- Local artifact paths require careful ephemeral handling and sanitized plan
  presentation.
- Omitting a target owner deliberately leaves prior state untouched.

## Alternatives considered

- **Persist selected modules in chezmoi configuration:** simplifies templates
  but introduces Phase 4 saved-selection state early and makes direct CLI input
  differ from applied intent.
- **Let modules append startup fragments:** distributes implementation, but
  creates competing Zsh syntax ownership and makes stale files active through
  directory scanning.
- **Glob an integrations directory:** concise, but silently activates stale or
  unknown files and makes filesystem residue part of selection.
- **Let each integration own `.zshrc`:** violates canonical target ownership
  and makes composition order-dependent.
- **Copy or vendor the external autosuggestions artifact:** avoids a local path
  but reads and persists third-party executable content and changes the
  configuration-only prerequisite boundary.
- **Search again during shell startup:** avoids rendering a path but duplicates
  ADR 0008 in startup code and can source a different, unchecked artifact after
  plan/apply.
- **Delete targets for omitted modules:** produces a clean machine but turns
  omission into destructive intent and conflicts with the initial apply
  contract.

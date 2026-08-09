# ADR 0006: Define the Phase 3 execution contract

- Status: Proposed
- Date: 2026-08-09
- Supersedes: None
- Superseded by: None

## Context

Phase 2 resolves schema-1 modules but deliberately has no package, home-state,
plan, or apply model. The first shell composition needs one durable boundary
between static catalog intent, provider observation, a reviewable plan, and
explicit mutation. Deferring that boundary to module implementation would make
provider ownership, ordering, and failure semantics accidental.

## Decision

Phase 3 introduces module schema 2. Schema 1 remains valid and keeps exactly its
Phase 2 fields; it implies no provider or home-state requests. Schema 2 adds
platform-specific `homebrew` and `mise` request arrays and a platform-neutral
`chezmoi` source-state array. Catalog data remains static TOML and accepts no
commands, arguments, hooks, URLs, or executable snippets.

Each request produces a canonical ownership key:

~~~text
homebrew:package:<formula-name>
mise:package:<package-name>
mise:tool:<tool-name>
chezmoi:target:<home-relative-target-path>
~~~

Provider and kind names are lowercase literals. Resource identifiers use the
provider's normalized catalog identifier. A selected chezmoi source is reduced
to the home-relative target it renders: remove the leading `home/`, remove a
final `.tmpl`, and translate a leading `dot_` in every path segment to `.`.
Phase 3 permits only regular files and file templates using that `dot_`
attribute; directories and every other chezmoi prefix, suffix, target type, and
special entry are rejected. The normalized slash-separated target must remain
relative and non-empty. Two requests with the same target key are an error even
when their source paths differ. Ownership is checked after resolution and
platform selection but before provider observation.

Planning is read-only. The CLI resolves modules, validates ownership, asks only
the selected providers to observe current state, and creates steps containing a
stable ordinal, module, provider, ownership key, action, description, and
network and privilege disclosures. Steps sort by provider order `homebrew`,
`mise`, `chezmoi`, then ownership key, then module identifier. Phase 3 actions
are additive or convergent only. An empty plan prints an explicit no-change
result and succeeds. Validation or observation failure produces no actionable
plan.

Apply recomputes a plan during the same invocation and never saves, loads, or
replays one. It displays the complete plan and disclosures before asking for
confirmation. Interactive apply accepts an explicit `yes`; any other answer,
end of input, or interruption cancels without mutation. Non-interactive use is
refused unless `--yes` is present. `--yes` acknowledges the displayed contract;
it does not suppress plan output.

Apply executes steps in plan order and stops at the first failure. It reports
completed, failed, and unattempted steps and performs no automatic rollback.
Providers must converge idempotently: after a successful apply, recomputing the
same intent should produce no changes. Phase 3 never removes, prunes,
uninstalls, or cleans resources.

The plan marks every step that may use the network, install a provider,
download content, or prompt for privilege. A remote download names its owner
and integrity mechanism. Plans and logs exclude secrets and machine identity;
future sensitive provider values must be redacted.

Phase 3 does not bootstrap Homebrew, mise, or chezmoi. A missing required
provider is a precondition failure: output names it, states that provider
installation would be required outside this invocation, and produces no plan
eligible for apply. Every actionable Phase 3 step therefore reports provider
installation as `no`; the field is retained so that the safety claim is
explicit and a later bootstrap decision cannot silently add that effect.

## Decision table

| Decision | Alternatives | Selected option |
| --- | --- | --- |
| Catalog version | Extend schema 1; introduce schema 2 | Schema 2; schema 1 remains unchanged |
| Requests | Commands; generic operations; provider-owned static data | Provider-owned static data in explicit platform sections |
| Home state | Implicit paths; executable selectors; static source paths | Static sources with deterministic target normalization |
| Ownership identity | Module plus source; provider resource key | Canonical provider, kind, and normalized rendered-target key |
| Plan order | Discovery order; dependency order; stable provider/key order | Homebrew, mise, chezmoi; then key and module |
| Apply lifetime | Saved/replayable artifact; fresh plan | Recompute and apply in one invocation |
| Confirmation | Prompt only; implicit CI approval; prompt or `--yes` | Explicit `yes`, or explicit `--yes` non-interactively |
| Failure | Continue; rollback; stop and report | Stop, report three states, no rollback |
| Removal | Reconcile including removal; additive convergence | No removal, prune, uninstall, or cleanup |
| Effects | Provider documentation only; per-plan disclosure | Disclose network, downloads, integrity, and privilege before mutation |
| Provider bootstrap | Install implicitly; fail as a named precondition | Fail and disclose; no Phase 3 provider installation |

## Consequences

- Module authors can express the minimal shell requirements without embedding
  execution logic.
- Determinism and duplicate ownership are testable before any provider runs.
- The CLI remains an orchestrator; providers retain observation and mutation.
- Schema-1 fixtures and manifests do not acquire new implicit behavior.
- Applying can leave partial additive state, but the report and a subsequent
  idempotent retry provide a safe recovery path.
- Saved plans, rollback, removal, and generalized provider options require
  later decisions.

## Alternatives considered

- **Extend schema 1:** fewer version numbers, but silently changes an accepted
  contract and makes old manifests acquire new semantics.
- **Generic command arrays:** flexible, but bypass provider ownership and turn
  trusted catalog data into executable content.
- **Allow duplicate identical requests:** convenient composition, but obscures
  which module owns lifecycle and weakens ADR 0004.
- **Persist plans:** supports delayed approval, but requires freshness,
  tamper-resistance, serialization, and compatibility rules outside Phase 3.
- **Automatic rollback:** appears atomic, but provider operations are not
  reliably reversible and rollback could remove user-owned state.

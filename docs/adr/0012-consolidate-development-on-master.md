# ADR 0012: Consolidate development on master

- Status: Accepted
- Date: 2026-09-08
- Supersedes: None
- Superseded by: None

## Context

The repository ran a two-branch model. `next` was the active integration branch,
`master` was the stable released branch, and work reached `master` only through
an owner-approved promotion pull request. `legacy` was, and remains, a read-only
recovery snapshot.

That model assumed a release cadence the project does not yet have. No release
has been cut, `master` served no consumer, and the promotion step deferred
integration rather than protecting anything. Meanwhile the two branches diverged:
`next` accumulated 56 commits absent from `master`, and `master` accumulated
three of its own, so neither could fast-forward into the other.

The split also produced concrete failures. GitHub reports `master` as the
repository's default branch, which contradicted the documented policy, and work
was branched from and merged into `master` on that basis. Correcting it required
a revert of an already-merged change. Two authoritative sources disagreeing about
where work belongs is a defect in the process, not in the people following it.

A durable, cross-cutting decision of this kind requires a record, because future
contributors and agents will otherwise reconstruct the reasoning from the code
and reach a different conclusion.

## Decision

`master` is the active, stable, and only integration branch.

Every task branch starts from the latest `master`. Every implementation,
maintenance, documentation, dependency, and release pull request targets
`master` and is integrated by the repository owner's explicit review and
approval. Task branches use the `agent/<description>` form and are deleted after
merge.

`next` is retired. It must not be reintroduced as a base, a pull-request target,
a workflow trigger, a Dependabot target, or a documented fallback.

`legacy` remains a read-only recovery snapshot. It is never modified, merged,
rebased, used as a base, or targeted.

Automation enforces this. `scripts/check-branch-policy.sh` fails closed when an
active `next` policy, a non-`master` target, or a `legacy` trigger is
reintroduced, and `tests/branch-policy.sh` verifies both the policy and the
guard's failure modes.

## Consequences

Integration is immediate: a change is integrated when its pull request merges,
so there is one place to look for current state. The default-branch setting and
the documented policy now agree, removing the contradiction that caused work to
be misdirected.

Review pressure moves onto individual pull requests. Without a staging branch,
each change must be small enough to review and green before it merges, and a
regression on `master` is visible to anyone cloning the repository.

Release tagging, when the project reaches it, will identify a commit on `master`
rather than a promotion merge. Phase 9 is adjusted accordingly and no longer
describes promotion as a release step.

The histories of both former branches are preserved. The transition was made
with an explicit non-fast-forward merge, so the last reviewed `next` commit and
the independent `master` commits are ancestors of the resulting `master`. No
history was reset, rebased, force-pushed, or discarded.

Records written while the two-branch model was in force keep their original
wording, because their accuracy depends on the branch model of their date. ADR
0009 in particular records `next` as the integration branch at its decision date
and is not superseded by this decision; its schema conclusion is unaffected.

## Alternatives considered

- **Keep the two-branch model and merge `master` into `next`.** This resolves
  the divergence but preserves the split that caused it, and it leaves the
  default-branch setting still contradicting the policy.
- **Keep the model and reset `next` onto `master`.** Fast to perform, but it
  discards reviewed history, which is the outcome the transition most needed to
  avoid.
- **Retire `master` and make `next` the default branch instead.** Consolidates
  equally well, but it renames the branch every clone, fork, and external link
  already tracks, for no benefit over consolidating on `master`.
- **Adopt release branches cut from `master` per release.** A reasonable future
  step once releases exist. Adopting it now would add a second long-lived branch
  to serve a cadence the project has not yet reached, recreating the problem this
  decision removes.

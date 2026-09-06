---
name: new-adr
description: Draft a new architecture decision record, numbered correctly and linked from both index sites.
argument-hint: "[decision title]"
allowed-tools: Read Write Edit Grep Glob Bash(ls docs/adr*) Bash(git log *)
---

# Add an architecture decision record

Durable or cross-cutting decisions in this repository are recorded as ADRs. An
accepted ADR is immutable except for factual corrections, and it is never
silently reversed — a later ADR supersedes it.

## Steps

1. **Confirm an ADR is warranted.** ADRs are for durable, cross-cutting
   decisions: a new provider, a change of ownership, a schema contract, a change
   to the CLI's boundary. A bug fix or a single module is not an ADR. If the
   change reverses an accepted decision, this ADR supersedes that one rather
   than editing it.

2. **Pick the number.** List `docs/adr/` and take the next four-digit sequence
   after the highest existing one. Numbers are never reused.

3. **Name the file** `docs/adr/<NNNN>-<lowercase-kebab-title>.md`. The slug
   should read as the decision, not the topic — `enforce-single-provider-ownership`,
   not `providers`.

4. **Copy `docs/adr/0000-template.md`** and fill every section. Keep the header
   list intact: Status, Date, Supersedes, Superseded by. Use `Proposed` unless
   the user says the decision is already agreed. Date is today, `YYYY-MM-DD`.
   - **Context:** the forces requiring a durable decision, not the solution.
   - **Decision:** direct, testable language. State what is now binding.
   - **Consequences:** both positive and negative, including what contributors
     must now do differently.
   - **Alternatives considered:** credible options with the reason each lost.
     Write these fairly; a straw man weakens the record.

5. **Update both index sites.** This is the step most often missed:
   - `docs/adr/README.md` — add a row to the index table.
   - `docs/architecture.md` — add a bullet to the "Accepted decisions" list at
     the end, but only when the status is Accepted.

6. **If the ADR supersedes another,** set `Supersedes:` here, set
   `Superseded by:` on the older ADR, and change the older ADR's status to
   `Superseded` in its header and in the `docs/adr/README.md` table.

7. **Run `bash scripts/check.sh`** and confirm it passes.

## Constraints

- Write in the same voice as the existing ADRs: short declarative sentences,
  no marketing language, no hedging about future work.
- Do not describe planned behavior as released.
- Never include hostnames, usernames, IP addresses, or machine identity.

# C8 source-repair pilot

Date: 2026-09-06. Status: authorized local source delivery; compatibility decision recorded
in `28b0792`. Installed acceptance remains separately authorized work.

## Objective and outcome

Deliver the independently reviewed exact `.DS_Store` discovery repair, affected
versioned contract and shipped reference, focused regression evidence, scoped
local commits and a concrete installation handoff. This source checkpoint does
not complete the broader C8 freshness feature or installed acceptance.

The owner submitted the [kickoff](../2026-09-06-operating-baseline/c8-pilot-kickoff.md)
in the new orchestrator task. The handoff baseline is
`69d62b00de429eadc55041bbedc34c26b749b09f` on
`codex/full-product-architecture-plan`, following approved operating baseline
`44dc75b1cf63837e22e5cf18773178576d55c618`. The architect's committed compatibility
section must be available in the delivery worker baseline before implementation.

## Scope and exclusions

Exclude only exact `.DS_Store` ordinary regular files from managed-document
discovery, after obtaining file type without following symlinks. Apply the same
rule at the immediately affected index-write stability boundary. Root and nested
metadata must leave document inventory and catalog digest unchanged across reads.
Preserve existing conservative concurrent-change detection and all real-document
checks. Reject same-named directories/symlinks and catalog entries, other prohibited
paths, unregistered documents, unsafe roots and evidence use of excluded metadata.

Update only the shared reader/contract, affected existing tests, managed-documentation
design, shipped catalog reference and directly affected documentation. Do not
change `.gitignore`, delete metadata, introduce blanket hidden-file exclusions,
implement freshness/lifecycle/recovery/hooks work, or add dependencies/frameworks.
No SQLite writes, owner data/state mutation, binding/catalog acceptance, audit
reconstruction, installation, launch, push, PR, merge, publication or rule changes.

## Dependencies and future consumers

Use [ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md), the
[managed-documentation contract](../../../design/managed-repository-documentation-contract.md)
and the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Accepted identity, custody and explicit acceptance rules remain controlling; the
plan's other proposed decisions are not approved by this pilot.

Current consumers are the app catalog reader, generated indexes, bundled checker,
catalog acceptance and managed evidence resolution. Future consumers include C8
freshness, C9 evidence, C12 health/recovery, C10/C11 portability, P15/P16 traceability
and revisions, and P17 revision/build evidence. Metadata is never an artifact or
accepted evidence. Preserve repository/artifact IDs, catalog format and digest
meaning; no persistence migration or implicit acceptance follows this rule. Old
installed validators remain restrictive until an explicitly authorized upgrade.
The architect's C8 compatibility section selects
`RepositoryDocumentContract.discoveryExclusionVersion = 1`; schema v1, guidance v2
and catalog digest encoding remain unchanged.

## Assignment and ownership

- Orchestrator: Astra Medium, sole progress/catalog/index writer in the existing
  handoff worktree; coordinates commits and task archival, no product code or subagents.
- Chief architect: Astra High, isolated worktree, owns the C8 compatibility section
  in the existing managed-documentation design and scoped local commit. Bounded
  whole-product alignment; not an extra approval layer.
- Delivery owner: Terra Medium, fresh isolated worktree from the committed brief
  and architecture result; owns C8 implementation, existing tests, affected design/
  shipped reference, required corrections, local source commits and integration.
  Do not write progress/catalog/index metadata; report requested changes to the
  orchestrator. A source staging build is permitted; installed/owner state is not.
- Independent reviewer: fresh Sol High task on the candidate, with original outcome
  and future dependencies. Cover reader correctness, contract and filesystem safety
  together; no writer ownership, extra reviewers, worker goals or review chains.

The default escalation ceiling is Astra High for a named unresolved problem.
Extra High/Max require specific owner authorization; Ultra is prohibited. Actual
model/effort settings are set at dispatch. Delivery subagents are optional only
for concrete justified work with explicit settings and disjoint ownership.

## Risks, checks and acceptance

Material risks are bypassing filesystem safety, accepting excluded metadata as an
artifact, divergent app/checker rules, index-write failure, and falsely claiming
installed acceptance. Use test-first changes in existing repository suites:
`RepositoryDocumentCatalogTests`, `RepositoryDocumentIndexTests` and directly
relevant documentation-tool/evidence tests. Select only additional suites justified
by an affected boundary; no new harness or full product test campaign.

Required regressions cover docs-root and nested regular metadata; creation,
modification and removal between reads with equal inventory/digest; same-named
symlinks and directories; explicitly catalogued metadata; ordinary unregistered
files; existing prohibited paths and containment; and index check/write agreement.
Keep index stability conservative for unsafe entries and real-document changes.
Build the app and bundled checker from the same candidate and exercise existing
repository-native checks, including the original canonical metadata failure using
read-only validation. Never use the owner store as a fixture.

Source acceptance requires direct passing checks, affected documentation consistency,
one independent review with no unresolved Required findings, scoped local commits,
repository-persisted results, stopped child processes and prompt archival of
completed bounded tasks. Classify findings Required, Optional or Out of scope;
only Required defects block and repeat only affected checks/review.

## Delivery endpoint and installation handoff

Delivery returns the exact candidate revision, changed behavior/docs, test commands
and results, staged candidate location or reproducible staging command, and exact
remaining installation action. Keep useful results in this brief and the existing
progress ledger. Build/log/worktree scratch is temporary; durable content must be
tracked and present in the repository before completion. List remaining temporary
files; obtain authorization before deletion.

The orchestrator goal ends at the reviewed local source checkpoint and concrete
installation handoff. Record installed acceptance as outstanding: owner-authorized
replacement of the exact installed app, installed reader/bundled-checker agreement
on the actual repository with metadata present, and supported application readback.
Missing binding/pending catalog acceptance or reset recovery remains separately
reported work, never an implicit side effect of installation or this goal.

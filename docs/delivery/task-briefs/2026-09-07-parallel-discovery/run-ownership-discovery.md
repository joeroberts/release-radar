# Discover role execution and Run Guard boundary

## Assignment brief — 2026-09-07

Status: authorized bounded discovery; findings pending. This artifact records a
proposal, not accepted architecture or implementation.

Treat role execution and Run Guard as one coupled I7/I8, RM11/#3 discovery: whether and how Release Radar should own first-party runs, with one run owner, separate execution/delivery state, real attribution and review independence, capabilities, cancellation/recovery, isolation and compatibility/distribution implications. Return concrete pursue/no-go choices and the smallest complete product boundary preserving the full outcomes if pursued.

Use primary sources and bounded relevant local capability inspection. Preserve app-owned delivery and repository authority, registration/request isolation, retained history and one run owner. No general executor, marketplace, public SDK, second delivery database or product implementation. Account for C5–C7 lifecycle/recovery and I1 observer boundaries without treating observation as execution authority.

Follow [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and the
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Retain all 40 capabilities and accepted versus proposed distinctions. RDS appearance
is unchanged. This discovery does not reopen completed lifecycle work or gate C4.

Model/effort: gpt-6-astra / high; ceiling: Astra High; Ultra prohibited. Assigned baseline is
`c4ddffb` plus the committed discovery briefs/catalog preparation on
`codex/recovery-orchestration`; the dispatch supplies its exact revision. Use a fresh
worktree and named `codex/discovery-run-ownership` branch with upstream. Own only this
artifact. The orchestrator owns progress, shared plan/catalog/index integration.
Do not overwrite another worker's files or edit the canonical checkout.

Verification: cite current primary sources supporting conclusions; distinguish
verified local capability, documentary evidence, hypothesis and unavailable proof.
Use only bounded isolated tests justified by the question. Report compatibility,
privacy/recovery risks and any material unresolved owner choice with recommendation.
One fresh independent substantive reviewer covers actual proposal risks; only
Required findings block. No review-of-review or implementation approval implied.

Endpoint: coherent findings in this artifact, scoped commit, branch push and PR
against `codex/release-radar-mvp`. Each merge needs owner approval. No installation,
owner/application-state mutation, cloud provisioning, active configuration change or
production implementation. List retained temporary files; do not delete unrelated
files. Report exact commit, checks, limitations and stopped processes to the
orchestrator before archival.

## Findings

Pending investigation.

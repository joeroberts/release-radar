# Outcome 3: runtime enforcement architecture assessment

## Outcome and authority

The owner approved starting Outcome 3 on September 14, following the proposal to
resolve the implementation boundary through a fresh chief-architect assessment.
Produce one concrete, complete native-desktop implementation proposal, or identify
the exact missing supported desktop controls and the alternative environment that
could enforce them. This assessment does not authorize runtime implementation.
The full outcome is applicable current context, deliberate historical retrieval,
restricted delivery and independent review, and integration to the authorized endpoint.

## Scope and constraints

Cover the supported RR-to-existing-desktop/local App Server connection; permissions
bound before the first model turn and preserved on follow-ups; shell and non-shell
capabilities; immutable current inputs and review candidates with separate writable
outputs; project onboarding/profile ownership, updates, conflicts and recovery;
and representative macOS build, review and integration. Keep coordinator access
separate. Identify existing controls, RR implementation, missing desktop controls,
and acceptance scenarios that must succeed or be denied. Explain exactly where
hooks help and where coverage must come from a different supported boundary.

Retain native desktop tasks, local App Server and profiles as the owner-selected
direction. A separate worker client is an alternative requiring a new decision.
Accepted ADRs remain unchanged; identify any new architectural decisions needed.
V1 adoption and Outcome 2 are complete; do not reopen them or confuse instructions
with runtime enforcement. Use current owning designs and prior findings; retrieve
only named historical evidence needed to resolve a specific fact.

Read-only inspection of relevant installed desktop/backend metadata, supported
interfaces, local source and official documentation is authorized. Do not launch
new servers, execute restriction probes, inspect secrets, change Codex configuration,
permissions, tools, plugins or app state, mutate SQLite, install, publish, delete,
or perform product implementation. Retain all existing fixtures and unrelated work.
The uncommitted broad September 13 proposal is excluded and is not an approved plan.

## Assignment and source basis

Coordinator owns scope, ledger, kickoff catalog metadata and final integration.
A fresh chief-architect task (Astra/high, ceiling Astra/high) owns the assessment
in docs/design/outcome3-runtime-enforcement-assessment.md and its catalog/index
registration in its fresh worktree. A fresh independent reviewer (Astra/high,
ceiling Astra/high) reviews that exact candidate for architecture, authorization
and recovery correctness. Do not reuse archived tasks or spawn subagents.
Start from the committed kickoff revision supplied at dispatch. Use
shared-execution/1; record exact task root, source basis and installed compatibility.

Controlling sources: docs/delivery/progress.md;
docs/design/shared-execution-integration-v1-design.md;
docs/delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md,
especially the runtime feasibility and rules/hooks sections; accepted ADR-001,
ADR-002, ADR-006 and ADR-007, only as relevant. Prior pilot evidence is at
docs/delivery/evidence/2026-09-13-current-document-workspace-pilot.md and is
historical evidence, not new authority.

## Verification and endpoint

Ground each consequential capability claim in inspected source/interface or
current official documentation, distinguish supported contracts from observations
and unknowns, and record concrete acceptance tests without claiming they ran.
Use installed ReleaseRadarDocumentationTool check/diagnose for documentation,
git diff --check, and direct ADR/config preservation checks appropriate to changes.
One independent review; only Required findings block. No review of review.
Deliver a scoped local candidate, integrate the reviewed proposal and concise ledger
result, and archive completed peers. The assessment remains proposed; obtain owner
approval of the concrete implementation/configuration or architectural alternative
before execution. No push, PR, remote merge, release or application mutation.

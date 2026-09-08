# Phase 3B — Bounded evidence preview

## Objective and outcome

Complete C9 with usable authorized evidence previews, preserving managed identity,
legacy-path distinction and lifecycle/authority presentation. Consume the Phase 3A
shared observation and same-folder recovery so displayed bytes cannot remain falsely
current after edits, access loss, relocation or registration/service replacement.

This brief is prepared under the owner's complete Phase 3 authorization. Implementation
waits for reviewed, owner-approved merged Phase 3A and a dispatched exact committed
baseline containing this brief. It does not open Phase 4.

## Scope and dependencies

Follow the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
[managed-documentation contract](../../../design/managed-repository-documentation-contract.md),
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md), and the
[Phase 3A brief](../2026-09-07-phase3a-freshness/phase3a-freshness-brief.md).

Existing resolver and accepted binding remain authoritative for managed repositoryID/
artifactID. A resolved path is only a current location. Legacy filePath evidence remains
explicitly legacy and receives fresh authorization and availability checks. Reuse existing
bounded no-follow reader and root rules; do not create a competing custody system or
persist preview bytes as evidence authority. No schema migration is expected.

The present repository corpus is primarily Markdown and PNG, with text/JSON/diff and
HTML/SVG sources. Provide readable bounded UTF-8 text previews (including Markdown and
source formats) and bounded raster-image previews. HTML/SVG remain inert source text,
with no scripts, web views, remote resource loading or command execution. Other binary
formats receive an explicit unsupported-format result, preserving identity and status.
Use existing reader size limits or stricter preview limits; document the exact byte,
text and decoded-image limits chosen by implementation. Never silently present truncated
or partial content as the complete artifact.

## Acceptance and material risks

- Evidence detail offers an actual readable preview, retains locator identity, current
  path when authorized, lifecycle and authority, and distinguishes checking, available,
  missing, stale, rejected, inaccessible, unsupported and oversized content.
- Resolve managed content using the exact current accepted binding and artifact ID.
  Pending/unaccepted, mismatched, invalid, unsafe or checksum-failing content fails closed.
  A previously successful digest does not certify unchanged mutable document bytes.
- Keep security scope open through bounded no-follow byte access. Reject symlinks,
  traversal, root escape, non-regular input, malformed/oversized payloads and unsafe
  changes during the read. Bound decoded image dimensions/resources before display.
- Fence results by the shared observation plus selected evidence, registration and root
  identity. Withdraw stale displayed success/content on invalidation; do not publish late
  results after selection, root, registration or service changes. Opening and refreshing
  previews never repair, accept, audit observation or mutate persisted delivery state.
- Preserve repositoryID/artifactID through accepted relocation and existing archive/
  restore/recovery behavior. Historical evidence may be available but never becomes
  controlling merely through preview. Future portability/publication remain consumers
  of these custody rules; no export/import or companion implementation is included.
- Connect access errors to Phase 3A's direct audited same-folder recovery; preserve saved
  identities and accepted catalog. After success, display any remaining validation or
  pending acceptance problem. Keep actual relocation separate. Handle cancel/denial,
  missing files, unavailable store and retries with accessible guidance.
- Use supplied RDS appearance. Verify compact/wide detail, readable scrolling, keyboard
  focus, selection, accessibility and error/retry behavior against relevant approved
  visual references. Do not hide identity/status when the content cannot be previewed.

## Verification and isolation

Use repository-native test-first coverage for text/image success and limits; managed vs
legacy authorization; invalid/pending/missing/restored evidence; unsafe path/file types;
content changes during read; late selection/observation results; relocation and lifecycle
identity preservation; access loss/recovery; and zero preview side effects. Test the
shared-observation integration, not only a standalone decoder.

Use only synthetic app-owned stores and inert credentials/services. Reverify the supported
XCTest isolation path before launching test runners or apps. Native permission checks
require a signed synthetic host, actual entitlement readback without broad filesystem
exceptions, and numeric-PID UI targeting. Reuse applicable successful Phase 3A native
recovery evidence where the identical behavior is unchanged; new boundaries need their
own direct evidence. Broad XCTest access is not evidence of shipping permissions.

No installation, owner-data operation, application binding/catalog acceptance, plugin/
cloud mutation, real notification, additional entitlement change, credential/owner-state
repair or cleanup. Preserve the prior launch/credential incidents as unresolved separate
work. Never dump secrets or use normal app-path launches. Agents never edit SQLite.

## Assignment and delivery endpoint

Fresh Terra Medium delivery task and worktree; escalate a named difficult authorization,
byte-read or stale-result issue to Sol High, with Astra High ceiling. Ultra prohibited.
One writer owns necessary preview source, consumers, focused tests, affected product docs,
this brief and canonical evidence. Orchestrator owns progress/catalog/index integration.
One fresh independent Sol High reviewer covers code, security and UX/QA for this candidate;
only Required findings block. No separate review matrix or review of reviews.

Complete direct verification, scoped commit, pushed branch and PR to
`codex/release-radar-mvp`. Each merge requires owner approval. Report precise behavior,
limits, checks, remaining risks, canonical artifacts and temporary files/processes.
Preserve outputs; cleanup remains separately authorized. Completion of 3B still requires
Phase 3 documentation closeout and the approved Git endpoint.

## Delivered preview boundary clarification

The implementation uses a 1 MiB preview-byte limit, 131,072 displayed text
characters, 4,096 pixels per raster dimension and 16,000,000 decoded raster
pixels. Text truncation is explicitly labelled. Legacy paths resolve only within
an existing saved primary or worktree authorization for the same project; a
relative locator uses the established primary root, while an absolute locator
must be contained by one exact saved root. No filename search or new file grant
is introduced. Outside-root paths remain preserved but inaccessible. Lost
primary access uses Phase 3A same-folder recovery; lost worktree access uses the
existing exact-worktree reconnect journey.

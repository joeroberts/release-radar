# MDCP M5 Brief: Freeze the Guidance-v2 Compatibility Candidate

**Status:** Proposed and unopened. M4 acceptance, M1 owner approval, and
separate M5 authorization are required before work.

## Objective and user-visible outcome

Make managed documentation guidance v2 current in one exact application and
bundled-plugin candidate while this repository's catalogued documents still
use their legacy physical paths, then freeze every shared contract as
`MDCP-COMPAT-1` without installing the candidate or mutating live repositories.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/design/release-radar-codex-plugin-lifecycle-design.md`
- `docs/architecture/ADR-002-codex-plugin-lifecycle.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- `docs/architecture/ADR-007-proportional-delivery-validation.md`
- Accepted M2-M4 artifacts

## Scope

In scope:

- guidance current version 2 and exact managed block;
- exact v2 agent rules for catalog-first/index-first discovery, same-change
  catalog/index/reference/checksum maintenance, active-only progress, archival
  closeout, `docs/superpowers/` prohibition, managed evidence/catalog-acceptance
  workflow, and validation/readback before completion;
- v1-to-v2 observation/upgrade state and v2 managed-unavailable failures;
- bundled skill, onboarding/setup/repair prompts, presentation, plugin package
  version/digest/fixtures, importer agreement, and exact contract tests;
- frozen public command/query/evidence/root-bound accepted-catalog binding and
  transition/root-rebind/tool schemas and overlapping tests;
- one exact attributable candidate identity and `MDCP-COMPAT-1` gate record.

Out of scope:

- live plugin/app installation, repository guidance change, owner storage
  migration, evidence inventory/adoption, document moves, Task 4B, Issue #1,
  guidance v3, or unrelated product behavior.

## Dependencies and release gate

- M2-M4 completed and accepted.
- Complete shared-contract surface identified before RED.
- Separate owner authorization for M5.

## Anticipated files

- Core documentation/guidance contract and `ProjectGuidanceInspection.swift`
- `ProjectOnboarding.swift`, owner-facing onboarding/guidance presentation, and
  exact prompt definitions
- Bundled `ReleaseRadar` plugin skill/manifest and exact lifecycle fixtures
- `RekonArtifactImporter.swift` only for already-approved managed-v2 behavior
- Focused guidance, plugin, onboarding, importer, projection, bridge/tool schema,
  and compatibility tests, including a real-tree conformance test in the normal
  repository test/check workflow

No new managed-document behavior may be introduced outside approved M2-M3.

## Data, security, and privacy

Behavior and failure tests use synthetic roots/state. The ordinary-workflow
conformance test reads the actual repository without mutation. v2 requires an
authorized valid catalog and matching durable root-bound accepted project
snapshot for managed operations; only binding may establish an initially
missing binding and only catalog acceptance may advance it. Missing/malformed/
unsupported/unsafe/unaccepted catalogs, missing or mismatched bindings/roots,
and same-root repository-identity or digest replacement fail without
repository, audit, receipt, notification, or delivery mutation. This slice does
not install or launch owner software.

## Test-first strategy

RED/GREEN covers exact v2 block parsing; audited handoff semantics; exact v1 as
outdated/upgradeable rather than malformed; missing/malformed/unsupported v2
catalog recovery; v3 refusal; bundled skill/Core/prompt exact agreement;
deterministic package digest/inventory; legacy v1 regression; staged-catalog
read-only behavior; managed-v2 importer/evidence behavior; exact repository
root-bound accepted-snapshot activation/transition and public tool-schema
inventory; managed-operation accepted-digest enforcement; same-root unaccepted
catalog replacement; multiple/stale root behavior; and ordinary-workflow
failure for a missing, corrupt, unsafe, or stale real-tree catalog/index under
the v2 candidate.

## Happy and non-happy behavior

- Candidate v2 plus valid catalog v1 is managed-current after audited handoff.
- Existing v1 remains supported and receives truthful upgrade guidance.
- Bad v2 catalog leaves guidance inspectable but managed operations closed.
- No evidence is adopted and no document path changes.

## Acceptance criteria

- Every shared surface is complete, tested, frozen, and independently accepted.
- Candidate identity, source/test inventory, plugin version/digest, and exact
  tool schemas are recorded.
- The schema and tool freeze includes root-bound accepted-snapshot persistence,
  typed audited activation/catalog acceptance, exact replay/rollback/relaunch,
  and exact root/repository ID/version/digest checks on every managed read,
  mutation, import, and root rebind.
- M4 repository paths remain unchanged.
- `MDCP-COMPAT-1` is declared only with required findings at zero and a clean
  exact checkpoint.
- Task 4B becomes only eligible for refresh/authorization; it does not open.

## Reviews and completion evidence

Required risk-triggered reviews: Code Review, QA, UX, and Architecture. TPM
participates only if sequencing or dependencies materially change. Planning is
not an approval role. Delivery Management records concise compatibility-test,
candidate, plugin, and frozen-contract evidence plus residual risks and next
eligible work; it is not an approval. Completion does not authorize M6 or Task
4B.

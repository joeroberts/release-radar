# C4 managed roots and C12 recovery

## Objective and scope
Deliver safe primary repository relocation and explicit worktree authorization management using the existing app-owned services. Preserve project, artifact and history identities, accepted catalog custody and repository files. Existing bound root is the primary root; before binding, preserve the existing first saved root. Expose that choice honestly rather than introduce a competing root authority. Add explicit worktree grant, reconnect and authorization removal; selecting a new primary location remains accepted-catalog relocation.

Exclude C5 archive/restore, C6 tracking removal, C7 backup/reset, broader C8 watching, real owner data, installation, helpers and unrelated transport repairs.

## Dependencies and compatibility
Baseline fetched origin/codex/release-radar-mvp `80521d6f081dbcb1e8ad6f6611322d23ce306db4`, plus parent status-only `b2425c1` integrated as `9d08db4`. Follow [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md), [ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and accepted D1/D2/D8 and C4/C12 in the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md). Future archive/removal/import consumers retain domain identity independently of registration and folder capabilities. No schema migration planned; preserve existing bound-root precedence and legacy compatibility. New preparations and receipts carry registration scope. Relocation recovery tokens advance to v2; v1 tokens lack registration ownership and fail closed rather than certify a replaced registration. Existing receipts and history are retained.

## Implementation and acceptance
- Retain exact accepted repository ID/version/digest validation and transactional relocation; support an already authorized worktree as the confirmed destination without granting a second project.
- Show primary root, separate worktrees and exact destinations before confirmation. Worktree grants require fresh explicit authorization and matching reciprocal Git-worktree metadata under the exact primary and candidate grants; metadata paths alone grant no capability.
- Reconnect only the selected saved worktree. Revoke only a non-primary root and its bookmark, preserving repository files, evidence identities and history.
- Scope previews and readback to registration and root snapshots. Replaced registration, late results, cancellation, wrong repository, permission loss and transactional failure preserve original associations. Exact receipt recovery must not certify a replaced registration.
- Report access health per saved root with check time and useful exact-target actions. Readback failure remains visible after a successful mutation.
- Use pinned RDS public components (`6d1fb9d341850ee1d13ba9391fada072534eb684`) for changed UI, including panels and separators.

## Risks and direct verification
Material risks are root authorization, stale requests, transactional failure and misleading UI recovery. Use test-first focused XCTest coverage for registration replacement, root roles, grants/reconnect/revoke, destination promotion, wrong catalog/permissions and rollback. Preserve existing relocation/lifecycle tests. Compare synthetic running compact/wide UI with approved settings and compatible recovery composition; exercise keyboard and nonhappy paths. Run native documentation check. Existing transport bridge acceptance is environmental; do not enable the owner's bridge or claim a fully green broad suite.

## Assignment and delivery
Delivery owner: this task, sole writer of worktree `039a`, branch `codex/c4-root-management`. Own relocation/root services, affected recovery/health UI and focused tests, this brief/catalog/index metadata. Parent exclusively owns progress.md after its integrated status update. Delivery explicitly configured to Sol High by coordinating task on 2026-09-07 for root authorization, registration and data-preservation risk. Runtime settings remain unexposed locally. Escalation ceiling remains Astra High; no Ultra.

Before PR, parent commissions one fresh independent candidate reviewer covering code, UX, authorization and transaction risks. Only required findings block. Authorized endpoint: verified scoped commits, push this branch and PR against codex/release-radar-mvp. Merge needs owner approval. No installation, owner-state mutations, real relocation or destructive actions. Synthetic temporary outputs are separate from repository deliverables. Catalog application acceptance remains separately authorized; never claim managed-current synchronization from repository checks alone.

## Sandbox-compatible worktree validation

The synthetic Git setup exposed that `/usr/bin/git` invokes xcrun, which cannot run inside App Sandbox. Existing discovery uses the same executable by source inspection; no product grant success or failure was inferred from that setup failure. A bounded chief-architecture consultation confirmed the C4-local correction: unchanged explicit-path RepositoryDocumentReader I/O validates .git, commondir and reciprocal gitdir links with primary and candidate scopes held. It compares common-directory identity, rejects unsafe relative normalization and revalidates at confirm. Documentation discovery policy and unrelated onboarding discovery are unchanged.

Normal main-primary/linked-candidate and linked-primary/main-candidate layouts are supported. If both roots need common metadata in a third ungranted location, the action fails distinctly with recovery guidance. No new metadata-root authorization, metadata repair, helper or Git binary workaround is introduced. Exact reconnect does not gain a Git/catalog requirement. Git-generated absolute and relative linkage metadata is persisted in the test fixtures; fixture generation occurred outside the sandbox, and the production predicate executes inside the sandboxed test host. Format references: [Git repository layout](https://git-scm.com/docs/gitrepository-layout) and [Git worktrees](https://git-scm.com/docs/git-worktree).

## Direct evidence

Native XCTest-host windows at 620 and 1100 points verified primary/worktree labels, exact paths, unavailable access, confirmation and cancellation. Native Escape canceled each worktree preview without mutation. Reconnect recovered the exact synthetic worktree; revoke retained its folder. Relocation, receipt recovery and read-only maintenance retained existing rendering checks. Captures use synthetic app-owned temporary roots only:

- [Relocation compact](../../evidence/c4-relocation-compact.png) and [wide](../../evidence/c4-relocation-wide.png).
- [Worktree recovery compact](../../evidence/c4-worktree-recovery-compact.png) and [wide](../../evidence/c4-worktree-recovery-wide.png).

Compared against approved settings.png composition: dark RDS panels, clear primary/secondary hierarchy, shared panel boundaries and separators, readable wrapped paths and distinct recoverable warnings. No dedicated root-manager mockup exists; these controls extend the existing recovery composition using the pinned RDS implementation. No installed-owner-app or real folder-picker authorization claim is made.

Direct checks: 66 current named XCTest checks passed across the focused runs. Coverage includes RepositoryRootRelocationTests, ProjectRootManagementTests, ManagedEvidenceRenderingTests, DocumentationMaintenanceTests, OnboardingAcceptanceTests, the four affected AppRoute health cases and the native ProjectHealth recovery action case. The final metadata correction was checked with the full root-management suite and the corrected Git-generated absolute/relative fixture case. No remaining failure exists in these selected current tests. Repository documentation check and git diff --check passed; the four repository screenshot copies were read back and verified.

Initial registration and promotion regressions failed for the expected behavior before correction. The broad affected run had one AX helper failure: its label fallback selected the wrong button; the bounded fallback correction and both actual health actions passed. A synthetic Git setup failure exposed the unsupported shim dependency, which C4 no longer uses; the later absolute-link fixture normalization correction preserved Git-generated metadata in the sandbox. Existing transport acceptance remains outside this task and no fully green broad-suite claim is made.

Independent combined review approved candidate `1801ded6ece1af31681463859b8376546db925a0` with no Required or Optional findings. The reviewer passed 31 focused tests, including fresh native 620/1100-point rendering, accessibility, Escape cancellation and the Health action, plus documentation and diff checks. Review processes stopped and the parent archived the review task.

XCTest injects a read-only `/` entitlement. Synthetic checks establish containment predicates and denied-bookmark handling; real NSOpenPanel grants under shipping entitlements remain unverified. No application catalog acceptance or owner-state synchronization is claimed; repository documentation validation is separate.

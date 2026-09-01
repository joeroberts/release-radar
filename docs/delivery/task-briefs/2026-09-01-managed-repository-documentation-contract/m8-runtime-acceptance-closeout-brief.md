# MDCP M8 Brief: Runtime Acceptance and Closeout

**Status:** Proposed and unopened. M7 acceptance and separate authorization for
catalog-acceptance mutation, tests, app launch/readback, owner-state access,
and closeout are required.

## Objective and user-visible outcome

Prove the repaired repository and frozen Release Radar contract agree after the
document cutover, including relaunch and root relocation, then close MDCP with
no unrelated delivery-state change and one truthful next-work decision.
Mutation-capable clients remain quiesced from M7 until controlled readback
succeeds and the owner explicitly releases live use.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- Exact `MDCP-COMPAT-1` candidate
- Accepted M6 owner-state baseline and M7 repository checkpoint

## Scope

In scope:

- fresh focused repository and application verification;
- exact typed, audited, idempotent acceptance of the M7 candidate from the
  stored prior accepted snapshot while all ordinary writers remain quiesced;
- controlled read-only app readback/relaunch for managed and legacy evidence
  while mutation-capable clients remain quiesced;
- authorized disposable or owner-approved root-relocation proof;
- accessibility and screenshot comparison for current, historical, and failure
  evidence states;
- before/after unrelated-state comparison, final diff, catalog/index/checksum/
  active-link checks, and durable terminal ledger entry.

Out of scope:

- new product behavior, frozen-contract corrections without reopening their
  owning slice, optional refactors, Task 4B implementation, Issue #1, guidance
  v3, direct SQLite access, or extra cleanup.

## Dependencies and release gate

- M7 independently accepted and repository check mode clean.
- The M7 continued-quiescence handoff is intact; any resumed writer requires
  recovery and a fresh M7 release token before M8 proceeds.
- Exact owner authorization for live app/state operations.
- `MDCP-COMPAT-1` remains valid; otherwise stop and reopen the affected prior
  slice before any Task 4B activity.

## Anticipated files/state

- No production source change.
- Coordinator-owned terminal `docs/delivery/progress.md` entry and only the
  index/checksum regeneration strictly required by that closeout.
- No owner-state mutation except the explicitly authorized accepted-catalog
  transition and an explicitly authorized reversible root-relocation proof
  using the accepted M3C operation. Neither may change evidence identity or
  delivery state.

## Security and privacy

Use supported application readback and approved recovery boundaries only.
Redact owner paths/bookmark bytes/content from durable evidence. Verify app,
helper, plugin, signing, and process identity before live operations. Restore
the approved root state if the test uses a reversible relocation.
Do not enable ordinary mutation-capable clients during verification. A failed
or uncertain pre-acceptance validation keeps them quiesced and enters the
phase-specific owner-authorized M7 recovery route. A failed or uncertain
post-acceptance readback preserves the new accepted repository state under
quiescence and never invokes old-state restoration or silently releases live
use.

Catalog acceptance must name the bound root, repository ID, prior accepted
version/digest, M7 candidate version/digest, and request ID. Before commit it
revalidates the stored canonical prior snapshot and current candidate through
the M2 transition validator. Failure leaves the old snapshot accepted, so the
M7 old/new recovery choice remains available. Once acceptance commits, any
later failure keeps the new repository state and writers quiesced; rolling the
accepted snapshot backward is prohibited unless a separately designed and
authorized valid transition exists.

If acceptance returns `outcomeUnknown`, do not change repository state or pick
a recovery branch. Keep writers quiesced, replay the exact original request and
receipt, and use supported binding readback to establish authoritatively whether
the prior or candidate digest is accepted. Only that result selects the valid
pre- or post-acceptance recovery phase.

## Verification matrix

- M2 repository tool check against the real tree and deterministic no-diff
  render.
- Freshly execute the already accepted GREEN catalog-transition tests for exact
  success, illegal/stale refusal, rollback, replay/outcome-unknown recovery,
  receipt/audit redaction, and relaunch persistence; inspect the attributable
  M3B/M5 RED/GREEN evidence. Missing coverage stops M8, reopens the owning
  M3B/M5 slice, and requires a replacement `MDCP-COMPAT-1`.
- Fresh targeted XCTest for catalog/tool, guidance/plugin, store migration,
  inventory/bridge, importer, onboarding/root, projection/presentation, and
  relevant app routes.
- Relaunch readback of managed current/completed/superseded/archived/missing
  evidence and arbitrary legacy evidence.
- Durable repository-binding readback plus rejection of a missing, mismatched,
  or same-root-replaced catalog identity across resolution, inventory, managed
  creation/adoption, importer, and root rebind.
- Root-relocation stability and exact AGENTS handoff behavior.
- Runtime accessibility and screenshot inspection against the approved
  phase-board/needs-review design language.
- Active reference/path literal scan proving no obsolete dependency.
- Before/after semantic state comparison and final Git diff review.
- Explicit owner decision releasing live use only after the post-cutover
  readback and all terminal checks succeed.

## Failure behavior

A frozen-contract failure stops closeout and Task 4B, reopens only the owning
M2/M3/M5 slice, and requires affected-role acceptance plus replacement of
`MDCP-COMPAT-1`. A repository-only M7 defect discovered before catalog
acceptance returns to the phase-specific M7 recovery choice: old restore then
fresh inventory, or continuously-quiesced new forward completion directly to
acceptance. An unknown acceptance outcome stays quiesced and resolves through
exact replay plus supported binding readback before either branch is legal.
After acceptance commits, preserve the new accepted/repository state under
quiescence; the old restoration branch is no longer legal.

A repository-only M7 defect found after acceptance opens a separately
authorized forward correction from the new accepted snapshot: derive and
validate a corrected pending candidate, apply it through the bounded M7
repository workflow, then accept that next transition and repeat M8 readback.
Reopen M2/M3/M5 and replace `MDCP-COMPAT-1` only when the defect is actually in
the frozen application/tool/test contract. Do not patch around failures in M8
or weaken tests.

## Acceptance criteria

- Catalog, indexes, lifecycle, authority, links, checksums, repository paths,
  application resolution, and UI/readback all agree.
- The exact M7 candidate became the accepted bound-root catalog through the
  frozen typed transition and survives replay/relaunch.
- Managed evidence survives file and authorized root moves without identity
  rewrite.
- Legacy evidence remains compatible and distinct.
- No active `docs/superpowers/` dependency or duplicated guidance/path contract
  remains.
- No unrelated delivery state changed.
- Mutation-capable clients remained quiesced until successful readback and an
  explicit owner release decision.
- `progress.md` names terminal status and the next eligible separately
  authorized work without reopening it.

## Reviews and completion evidence

Required terminal reviews: QA, Architecture, Security/Privacy, TPM, Delivery
Management, Planning, and Code Review for any closeout diff. Record exact test
commands/counts, repository checks, candidate/runtime identity, readback and
relaunch evidence, screenshot/accessibility result, semantic comparison, final
diff, residual risks, and next eligible Task 4B refresh or Issue #1 sequencing
decision. Completion is a stop condition.

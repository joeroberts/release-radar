# MDCP M7 Brief: Catalog-Driven Repository Cutover

**Status:** Owner-authorized cutover applied and independently accepted.
The exact six moves and reviewed documentation delta are deployed in both
roots. Native repository checks pass. M7 delivery and M8 acceptance/readback
remain the next operations under the approved exact package.

## Objective and user-visible outcome

Move this repository's durable documents into the approved canonical structure,
update each catalog path once, regenerate complete indexes, compact active
delivery context, preserve historical narrative, and remove active
`docs/superpowers/` dependencies without rewriting managed evidence rows.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- `docs/architecture/ADR-007-proportional-delivery-validation.md`
- Accepted M4 catalog and M6 managed-evidence readback
- Root `AGENTS.md` and `docs/delivery/progress.md`

## Scope

In scope:

- current designs in `docs/design/`, plans in `docs/delivery/plans/`, briefs in
  `docs/delivery/task-briefs/`, evidence in `docs/delivery/evidence/`, and
  completed/superseded/history in `docs/delivery/archive/`;
- catalog path/lifecycle/authority/supersession changes in the same Git change
  as moves;
- generated root/local indexes, active links, applicable checksums, archive
  migration map, and explicit leaf declarations;
- active-only `docs/delivery/progress.md` with detailed closed history archived;
- only repository-specific operating rules outside the exact managed
  `AGENTS.md` block; reusable rules remain owned by guidance v2;
- removal of the obsolete directory only after every active dependency is gone.

Out of scope:

- application source/schema/contract changes, evidence row path repair, owner
  storage mutation, historical narrative mass rewrite, Task 4B, Issue #1, or
  deletion before value/classification is preserved.

## Dependencies and release gate

- M6 exact managed adoption and readback accepted.
- Supported readback records the old root-bound accepted catalog version/digest;
  M7 may prepare but cannot accept the new candidate in application state.
- Before M7 opens, the coordinator prepares the exact final move map, obtains
  separate owner authorization for a live read-only preflight outside this
  repository-change slice, quiesces the app and every mutation-capable client
  or helper, and leaves only the authenticated read-only M3B query path for one
  authoritative inventory against that frozen map. Close the query path after
  it returns and keep all writers quiesced through M7. The move-map/inventory
  digests and quiescence proof form the release token; a changed map or resumed
  writer invalidates it and requires a newly authorized preflight.
- Every evidence row targeting a moved file is already managed; otherwise that
  file is removed from the move set pending separately authorized exact legacy
  relocation before a new inventory token is issued.
- An exact clean pre-M7 Git checkpoint is recorded, and the complete old and
  proposed new catalog/tree candidates both pass the M2 current/transition
  validator before the first move. The old candidate digest equals the app's
  accepted digest and the new candidate digest is recorded as pending.
- No active implementation depends on old paths.
- Owner decisions resolve every remaining authority/classification conflict.
- M2 tool check passes against the complete proposed old/new catalogs before
  applying moves.

## Anticipated repository inventory

- Add canonical `docs/README.md`, local indexes, and `docs/delivery/plans/` as
  established by the accepted M4 catalog.
- Move current/superseded/completed files from `docs/superpowers/` to cataloged
  destinations.
- Update `docs/catalog.json`, active references, checksum manifests,
  `docs/delivery/archive/README.md`, `docs/delivery/progress.md`, and governing
  repository instructions outside the managed block.
- Preserve the exact Release Radar-managed block through its supported v2
  workflow; do not edit it incidentally.

## Data, security, and privacy

The release preflight is a separately authorized read-only owner-state action;
it is not performed by this slice and mutates no owner data. This slice changes
repository files only. It does not launch the app, access owner data, or mutate
evidence. Use no-follow checks for move targets and never delete until the
catalog/index/reference/evidence postconditions prove the old path unnecessary.
Preserve historical content and the Issue #2 attribution record.

A failed/uncertain preflight, changed map, or paused/aborted cutover invalidates
the M7 continuation token. Preserve the partial repository state, keep writers
quiesced, and request explicit owner recovery authorization. Recovery is
phase-specific:

- Restore the exact old accepted candidate, prove it validator-clean, then run
  a separately authorized fresh inventory for a new token before retrying M7
  or resuming old-state live use.
- Forward-complete the exact new pending candidate only when writer quiescence
  was never lost. Prove it validator-clean, remain quiesced, and proceed
  directly to separately authorized M8 catalog acceptance; do not require or
  permit managed inventory while the app still accepts the old digest.
- If any writer resumes or evidence-state quiescence is uncertain, prohibit
  forward completion. Restore/validate the old candidate and obtain a fresh
  inventory/token.

Never inventory a partial, invalid, or unaccepted tree as authoritative, and
never use a stale token or inferred recovery.

## Check-first strategy

Prepare an exact old/new catalog pair and relocation map. The pre-move tool must
validate legal transitions and expected path changes. After moves, run catalog
check, deterministic second-render comparison, active-link validation,
checksums, controller uniqueness, parent/leaf coverage, and an active-reference
scan for `docs/superpowers/`. Use the frozen resolver with synthetic/offline
fixtures to prove new-path resolution; live owner application readback is M8.

## Happy and non-happy behavior

- One catalog path change accompanies each physical move.
- Successful M7 keeps mutation-capable clients quiesced; it cannot release live
  use before M8's typed catalog acceptance, controlled post-cutover readback,
  and explicit owner decision.
- Historical narrative retains old wording; archive indexes explain old paths.
- `progress.md` retains only current authorization/gate, active artifacts,
  current evidence/risks/decisions, and next eligible work.
- Any unresolved reference, checksum, authority, evidence, or application
  resolution mismatch blocks deletion and closeout.

## Acceptance criteria

- New agents find all controlling artifacts from `docs/README.md` without broad
  search.
- No active dependency uses `docs/superpowers/` and the directory is not
  recreated.
- Frozen-contract resolution proves managed IDs survive moves without row
  rewrite; typed acceptance and live readback remain M8 gates.
- Application state still accepts the exact old catalog digest; the exact new
  candidate digest is pending M8 and no managed operation may consume it.
- The exact move-map/inventory release token remained valid and app/helper
  writers remained quiesced for the complete repository cutover.
- Pause, abort, and recovery evidence proves a stale token cannot authorize
  repository movement or renewed live use.
- Recovery evidence identifies the old-restore or new-forward trust phase;
  inventory occurs only on the restored accepted old state, never the pending
  new state.
- Exact pre-M7 checkpoint identity and old/new validator results make rollback
  or forward-completion bounded and attributable.
- Archive is explicitly historical/non-authoritative with an old/new map.
- Held Issue #2 bytes are not rewritten absent a separately necessary,
  specifically authorized change; accepted baseline/unknown authorship remains
  recorded.
- Final diff contains documentation/governance changes only.

## Reviews and completion evidence

Required risk-triggered reviews: one Documentation reviewer, the repository
validator, and application-readback QA. TPM participates only if sequencing or
dependencies materially change. Planning is not an approval role. Delivery
Management records concise authorization, quiescence, transition, validation,
recovery, and readback evidence plus residual risks and next eligible work; it
is not an approval. Completion does not authorize M8.

## Exact 2026-09-02 cutover candidate

The six existing artifact IDs and basenames are preserved:

| Existing path | Destination |
| --- | --- |
| `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` | `docs/delivery/archive/2026-08-23-release-radar-mvp.md` |
| `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` | `docs/delivery/archive/2026-08-25-release-radar-remediation.md` |
| `docs/superpowers/plans/2026-08-27-codex-plugin-lifecycle.md` | `docs/delivery/archive/2026-08-27-codex-plugin-lifecycle.md` |
| `docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md` | `docs/delivery/archive/2026-08-29-release-radar-active-phase-selection.md` |
| `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md` | `docs/delivery/plans/2026-08-29-delivery-goals-roadmap-readiness.md` |
| `docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md` | `docs/design/2026-08-29-delivery-goals-roadmap-readiness-design.md` |

The existing progress ID/path remains current; its closed contents through M6B
are preserved under `docs/delivery/archive/2026-09-02-progress-through-mdcp-m6b.md`.
The new `delivery.plans` collection is a leaf enumerated by the delivery index.
Four indexes are regenerated. No other completed brief is relocated.
Historical plan bytes and the three held Issue #2 artifacts remain unchanged.
The superseded plans keep that lifecycle in the archive; completed plans become
archived through the frozen validator's accepted transition.

Targeted reference updates affect ADR-004, the active-phase design, the
Delivery Goals presentation design, the project-planning proposal, the ticket
Tasks design, and the relocated current RR-R10 plan. In root `AGENTS.md`, only
the obsolete MVP controlling-plan reference is replaced with the current
RR-R10 implementation-plan reference. The exact managed block and all other
operating instructions are preserved. The archive README records the move map
and accurately limits its existing checksum manifest to the accepted set.

The native frozen validator accepts both complete trees and their transition:
prior catalog `3872999314072d41cb7d0ce213e953d11c5c0e8d817d7ac60ad98736dad27a9a`,
pending candidate `5310c3fbc02ff0485857f0affff7322e5bb5b95c8b3978e1b5974293fcdb920d`,
version 1 with 194 artifacts. Native check passes and a second index write
changes zero files. This is preparation evidence, not live deployment or
catalog acceptance.

The protected companion holds the concrete owner-target deployment/recovery
package and the separate exact M8 acceptance request. Development remains on
`codex/managed-documentation-contract-planning`; deploying the reviewed
repository-file delta to the bound checkout does not change that checkout's
branch or discard its preserved M6A guidance/ledger state. Only the exact
reviewed delta may replace that state after explicit approval. Preserve the
old owner repository candidate and database-set baseline before deployment.

M7's live preflight verifies the exact M6B inventory and that the only evidence
row targeting a moved file is already managed. Keep all ordinary writers
closed through cutover; close the authenticated query client after preflight.
After deployment, check the candidate tree without querying managed inventory
against the pending digest. M8 then uses the exact typed catalog acceptance,
replays it unchanged, and verifies read-only relaunch and unrelated-state
preservation. Before acceptance, a failed cutover uses the already specified
old-restore or continuously-quiesced forward route; after acceptance, preserve
the new state and use an authorized forward correction only. Ordinary live use
still needs the owner's final release decision after successful verification.

Actual preflight: the owner confirmed an intervening normal app launch. Fresh
complete inventory preserved all M6B evidence, binding, roots, delivery records
and prior audit/receipt identities; only plugin lifecycle state and one audit
changed. Preserve that owner state as the current baseline. Independent
Security review accepted this bounded recovery. Old repository and current
store recovery copies were verified before cutover; ordinary writers and the
query client then remained quiesced. No old-state restoration was needed.

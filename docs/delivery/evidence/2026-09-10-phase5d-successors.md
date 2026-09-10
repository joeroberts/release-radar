# Phase 5D successors and carry-forward evidence

- Date: 2026-09-10
- Branch: `codex/phase5d-successors`
- Baseline: `19306fbaa14d7c9db467e8503df211a71651f502`
- Controlling brief:
  [`phase5d-successors-brief.md`](../task-briefs/2026-09-10-phase5d-successors/phase5d-successors-brief.md)
- Scope: local source, synthetic stores, native XCTest hosts, canonical evidence,
  and local commits only. No push, pull request, merge, installation, owner
  application data, binding/catalog acceptance, notification, or external
  service mutation was authorized or performed.

## Delivered behavior

Phase 5D adds explicit retirement and successor lineage while retaining the
original ticket as read-only history. Replacement and split proposals create
new successor tickets and pending tasks atomically, preserve the original task,
evidence, references, review history, completion history, and activity context,
and keep retired originals off active boards.

Delivery Goal obligations are now explicit and may be carried to one or more
descendants or deliberately dropped with a reason. Coverage participates in
plan readiness, Delivery Goal acceptance, and ticket/phase dependency gates.
Invalid or ambiguous carry graphs, cycles, duplicate descendants, cross-project
descendants, unresolved retired dependencies, and mutations against retired
tickets fail before partial state or audit writes.

The Project Plan shows retirement disposition, rationale, successor lineage,
retained detail, and obligation coverage. Back/Forward history recognizes
retained tickets as valid Activity context. Retired and unassigned ticket rows
have stable scroll anchors so restored ticket focus is brought back into the
viewport at wide and compact widths.

Schema version 22 persists retirements, successor links, obligation snapshots,
lineage, and drops. Project removal snapshots and application backup/recovery
retain that state, and recovery reconciles older backups without inventing
lineage.

## Direct verification

All commands used the repository Xcode project and scheme, a sanitized isolated
home and temporary root under `/private/tmp/release-radar-phase5d-writer`, code
signing disabled, serial test execution, and fresh result bundles.

- Proposal reconciliation and migration: launch 17 passed 2/2.
- Initial Phase 5D focused batch: launch 18 passed 26/31. Its five failures were
  fixture expectation defects; launch 19 reran those exact cases and passed 5/5.
- Native retained-original rendering and accessibility: launch 22 passed 1/1.
  Launch 23 passed 1/1 and produced the three selected visual attachments below.
- History recovery: external launch 24 passed its host assertions but exposed an
  erroneous Activity recovery state. Launch 25 reproduced that defect with two
  expected failing assertions; after the bounded `AppModel` correction, launch
  26 passed 1/1.
- Required store and policy gaps: launch 27 passed 4/4, covering atomic
  replacement/split application, invalid carry graphs, dependency retargeting
  and opening, phase dependency coverage, retained-writer guards, and source
  plan refinalization.
- Launch 28 stopped at a missing synthetic registration and provided no product
  evidence. Launches 29 and 30 found the Approve AX node but did not invoke a
  decision; external launch 31 established that the visible enabled action was
  correctly rejecting a stale proposal. Launch 32 confirmed the same condition.
  Complete comparison of all 26 canonical planning-baseline categories showed
  exactly one changed fact: `projects.first_dashboard_opened` changed from `0`
  to `1` because the fixture navigated to Project Plan after saving. The fixture
  now performs that ordinary navigation before proposal creation; production
  stale rejection is unchanged.
- External launch 33 exercised actual native Approve and Apply, then opened the
  successor and retained original. It reproduced the compact restoration defect:
  after actual Activity and Back, model selection and retained detail survived,
  but the Project Plan remained at the top and the retired row was absent from
  the AX viewport. The host failed only that direct assertion.
- After adding stable ticket scroll anchors, external launch 34 passed 1/1 with
  no failures or skips (`104.728` seconds; suite `104.730` seconds). Actual
  Approve persisted one owner decision without applying the proposal. A fresh
  `AppModel` over the same synthetic store—not a process restart—loaded the
  approved version, and actual Apply created the successor/retirement package.
  At compact width, actual Activity and Back required no subsequent manual
  scroll or focus action: the Plan returned at scrollbar value
  `0.4367816091954023`, the complete `ROAD-1` retained row was visible with its
  focus ring, AX focused identifier `retired-ticket-ROAD-1`, retained task detail
  remained visible, and no navigation recovery warning appeared.
- After removing the temporary marker hold, launch 35 exercised the complete
  self-contained native regression path without CUA or markers and passed 1/1
  with no failures or skips (`5.379` seconds; suite `5.381` seconds). This
  verifies that the durable test itself performs native AX Approve and Apply,
  fresh same-store restoration, successor/original navigation, and the direct
  compact Back focus assertion.

Launch 34 result bundle:
`/private/tmp/release-radar-phase5d-writer/34-native-successor-external-green.xcresult`.
It contains no screenshot attachment; the corrected compact state was inspected
live through external CUA and then verified by host assertions. No rerun was
performed solely to manufacture an attachment.

Marker-free regression result bundle:
`/private/tmp/release-radar-phase5d-writer/35-native-successor-automated-green.xcresult`.

## Independent-review corrections

A fresh independent Astra High review of the integrated candidate identified six
required correctness and presentation gaps. The bounded correction preserves
the approved Phase 5D scope and changes these behaviors:

- recovery now rotates proposal authority without deleting live retirement,
  successor, obligation, carry, or drop facts from the restored project;
- an Accepted ticket counts as delivered only for its exact current Delivery
  Goal assignment, so a later reassignment cannot retroactively satisfy the
  abandoned goal;
- superseded unresolved obligations and every nonretired unfinished ticket,
  including unassigned work, remain phase prerequisites, while a completed
  legacy phase with no Delivery Goals is not blocked merely by the empty goal
  set;
- carry/drop admission rejects Accepted ticket or goal scope, carry descendants
  must be current nonterminal obligations, and every replacement/split carry
  names all and only the retirement's required successors;
- saved proposal previews freeze the original placement and obligation scope and
  identify each carry destination ticket, goal, and phase; and
- retained rows show their frozen last phase and lane at wide and compact widths.

Correction verification used the same isolated, no-signing XCTest environment:

- Launch 36 stopped at a Swift 6 test-fixture Sendable compile error and supplied
  no behavioral evidence. Launch 37 then established the intended RED state:
  three tests failed because detached Accepted scope was still delivered,
  terminal obligation changes were admitted, and an incomplete split carry was
  admitted.
- Launch 38 passed six of seven focused cases: exact coverage, terminal and split
  admission, complete split application plus exact saved preview, older-backup
  restoration with live retired projection/write rejection, and
  superseded/unassigned/legacy phase prerequisites. Its remaining case stopped
  on a fixture audit-event identity collision. Launch 39 confirmed the store
  authorizer rejected a direct fixture audit insert. The fixture was corrected
  to use a second ordinary audited `DeliveryStore` transaction; no production
  authorization behavior changed.
- Launch 40 passed the corrected reassignment journey 1/1. It exercised an actual
  Backlog reassignment followed by normal ticket transitions to Accepted and
  verified the abandoned goal remained uncovered while the exact current goal
  became delivered and acceptance-eligible.
- Launch 41 passed both native journeys 2/2 (`8.507` seconds; suite `8.509`
  seconds). After scrolling the native approval sheet, its accessibility tree
  exposed the frozen `phase-roadmap Backlog` source placement,
  `Roadmap backlog one.` scope, and exact
  `ROAD-1-NEXT`/`road-goal-1`/`phase-roadmap` destination before the actual AX
  Approve action. Actual Apply, successor/original navigation, retained detail,
  and compact Activity/Back focus also passed. The separately captured retained
  row visibly includes `Last placement: phase-roadmap · Backlog` at both wide
  and compact widths.
- Launch 42 passed 3/3 directly affected compatibility cases: partial split
  coverage remains unresolved until every exact current child is delivered,
  a complete carried successor still permits source-plan refinalization and
  dependent work, and the combined replacement/move/reassignment/supersession
  package remains atomic under the tightened Backlog admission rule.
- The same reviewer recheck then identified four remaining interactions inside
  the existing findings: empty or dropped-only phase prerequisites lacked a
  delivered-outcome requirement, detached historical debt became impossible to
  reconcile after acceptance elsewhere, debt-free superseded goals blocked
  readiness, and persisted carry lineage bypassed a later split's exact-successor
  rule. Launch 43 stopped at a test-helper proposal-ID type mismatch and supplied
  no behavioral evidence. After correcting only that fixture signature, launch
  44 reached all three intended RED journeys and failed on each reported policy
  behavior.
- Launch 45 passed the three corrected journeys 3/3. It rejected empty and
  dropped-only prerequisites while allowing a genuinely delivered legacy phase;
  ignored a superseded goal with no obligations; completed actual approved move,
  reassignment, destination finalization, and ticket acceptance before applying
  both explicit drop and carry reconciliations in separate fixtures; and rejected
  a later incompatible split after an actual earlier approved carry with no new
  proposal or audit write.
- Launch 46 passed 4/4 affected compatibility cases: exact-current Accepted
  obligation guards, a valid complete split, carried-source refinalization and
  dependent work, and the atomic replacement/move/reassignment/carry/
  supersession package. No native or recovery rerun was needed because these
  bounded corrections changed only planning policies and their store tests.

Correction result bundles are retained at:

- `/private/tmp/release-radar-phase5d-writer/37-required-coverage-red.xcresult`
- `/private/tmp/release-radar-phase5d-writer/38-required-store-green.xcresult`
- `/private/tmp/release-radar-phase5d-writer/40-reassignment-green.xcresult`
- `/private/tmp/release-radar-phase5d-writer/41-native-preview-corrections.xcresult`
- `/private/tmp/release-radar-phase5d-writer/42-coverage-compatibility.xcresult`
- `/private/tmp/release-radar-phase5d-writer/44-remaining-obligation-red.xcresult`
- `/private/tmp/release-radar-phase5d-writer/45-remaining-obligation-green.xcresult`
- `/private/tmp/release-radar-phase5d-writer/46-obligation-compatibility.xcresult`

## Visual evidence

The canonical captures were refreshed from launch 41 and show the corrected
retained-original presentation at wide and compact sizes:

- [Wide retained-original row](2026-09-10-phase5d-successors-wide-row.png)
- [Wide retained task and evidence detail](2026-09-10-phase5d-successors-wide-detail.png)
- [Compact retained-original row](2026-09-10-phase5d-successors-compact-row.png)

They were compared with the approved `phase_board.png`, `goals.png`,
`goals_compact.png`, `activity.png`, and history mockups. The implementation
retains the dark Rekon surface, typography, spacing, status color, card, and
responsive stacked-inspector vocabulary. The Phase 5D-specific retired-original
and obligation-coverage content is a necessary extension of those references;
it does not change their navigation hierarchy or active-board treatment.

The wide and compact row captures visibly include the frozen last placement.
The compact capture proves responsive retained-row rendering; launch 41 also
reran the automatic Activity/Back restoration assertion without manual scroll
or focus recovery.

## External-controller deviation

During launch 34, external app selection unintentionally started a plain
DerivedData Release Radar process (`41579`) before the exact XCTest host was
selected. It displayed a schema-19 mismatch, received no clicks, and was
terminated with `SIGTERM`. No successful data load or mutation was established,
so zero incidental startup effects are not claimed. The exact XCTest host was
PID `41580`; the installed owner application remained PID `60590` and was not
controlled or terminated.

## Temporary-output status

No temporary output or marker was deleted. Result bundles, synthetic stores,
attachments, marker files, isolated home/tmp directories, and the launch 34
and launch 41 attachment-export manifests remain under
`/private/tmp/release-radar-phase5d-writer/`. The three selected screenshots
above are the canonical repository copies; temporary originals are retained.

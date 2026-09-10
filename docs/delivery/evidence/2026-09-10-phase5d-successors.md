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

## Visual evidence

The launch 23 native captures show the retained-original presentation at wide
and compact sizes:

- [Wide retained-original row](2026-09-10-phase5d-successors-wide-row.png)
- [Wide retained task and evidence detail](2026-09-10-phase5d-successors-wide-detail.png)
- [Compact retained-original row](2026-09-10-phase5d-successors-compact-row.png)

They were compared with the approved `phase_board.png`, `goals.png`,
`goals_compact.png`, `activity.png`, and history mockups. The implementation
retains the dark Rekon surface, typography, spacing, status color, card, and
responsive stacked-inspector vocabulary. The Phase 5D-specific retired-original
and obligation-coverage content is a necessary extension of those references;
it does not change their navigation hierarchy or active-board treatment.

The compact capture proves responsive retained-row rendering, not launch 34's
corrected automatic scroll. The latter is intentionally recorded only by the
external observation and passing host assertions above.

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
attachment-export manifest remain under
`/private/tmp/release-radar-phase5d-writer/`. The three selected screenshots
above are the canonical repository copies; temporary originals are retained.

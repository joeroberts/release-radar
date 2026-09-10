# Phase 6A truthful event-time History evidence

- Date: 2026-09-10
- Branch: `codex/phase6a-history`
- Baseline: `6bcd31ed4a6fcc9b9c88c1e074e5f24a93787e7f`
- Controlling brief:
  [`phase6a-history-brief.md`](../task-briefs/2026-09-10-phase6a-history/phase6a-history-brief.md)
- Scope: local source, synthetic stores, isolated native XCTest hosts, canonical
  evidence and local commits. No push, pull request, merge, installation,
  owner-application data, catalog acceptance, owner bridge, notification,
  credential or external-service mutation was authorized or performed.

## Delivered behavior

Store schema 24 records event-time audit facts atomically with each authoritative
delivery transaction: exact project and registration, available ticket and phase
identity/name, lane or transition values, outcome, request generation, provenance,
occurrence time and recording time. Transaction rollback removes both the state
change and event. Pre-schema-24 audit rows remain explicitly unknown rather than
being reconstructed from current delivery state.

The project History projection uses stable project/registration/source identities
for audit, retained history, latest persisted observations, notification delivery,
reviews and completions. Occurrence, observation and recording times remain
separate where meaningful. Deterministic newest-first ordering and All, Audit,
Observations, Notifications, Reviews and Completions filters preserve unrelated
events. Empty History, no matches, failed reads and incomplete observation sources
remain distinguishable. Reading or filtering History does not mutate delivery
state, acceptance or attention.

Removal, re-add and full backup recovery retain the original event identity and
facts without transferring authority to the replacement registration. Exact
ticket and nonactive-phase navigation uses shared typed navigation history. Back
restores the selected event, filter, bounded viewport and actual keyboard or
accessibility focus. Removed-project History keeps its own mutable browsing state
while exposing no action that can reopen or mutate the removed registration.
Missing targets, including legacy audit rows without recorded identity, present an
accessible recovery state instead of substituting a current ticket or registration.

The visible Activity route is now History while the existing internal route and
file names remain for compatibility. The wide surface presents a timeline beside
event detail; compact mode stacks a full-width timeline and detail. Contextual Help
explains provenance, the three time meanings, unknown legacy facts, current context,
attention versus acceptance and copied-not-dispatched actions without claiming a
future observer or service.

## Direct verification

Every final build/test run used `ReleaseRadar.xcodeproj`, scheme `ReleaseRadar`,
serial macOS execution, signing disabled and a sanitized environment rooted at
`/private/tmp/release-radar-phase6a.eJzQ2M`.

- `history-final-focused-3.xcresult` passed 20/20 final focused persistence,
  projection, navigation, removal/re-add, recovery, notification, route-rendering
  and historical migration tests.
- `history-native-5.xcresult` passed its isolated native host test 1/1 in 87.158
  seconds. External CUA attached only to the app under the matching DerivedData
  product at verified host PID 90021 and the unique window titled
  `Phase 6A History — isolated native interaction 01a08be3-v3`.
- The native journey reached the first and last timeline events, every relevant
  filter and selected detail with keyboard/accessibility navigation at wide and
  compact widths. It opened the exact nonactive `RR9-HISTORY` phase, returned to
  the exact Audit filter and `phase6a-native-history-target` event, exercised Help,
  and repeated exact ticket navigation and Back restoration. The installed owner
  application remained PID 60590 and was never selected, controlled, terminated
  or connected to.
- Historical schema migration fixtures for versions 15, 16 and 20 passed after
  their test-only downgrade support learned to remove schema-22 through schema-24
  objects before declaring the older version. No accepted historical definition
  was rewritten.
- The preceding broader `history-final-focused-2.xcresult` exposed one additional
  version-18 fixture mismatch: its current-writer seed contained schema-24 facts
  that could not have existed in the simulated version-18 database. The fixture
  now clears those facts before its pre-migration snapshot; the direct correction
  passed 1/1 in `history-v18-green.xcresult` and is included in the final 20/20.
  That broader run also selected an unrelated Task 11A notification test whose
  four assertions fail at an unchanged Phase Plan readiness prerequisite before
  reaching its notification/replay checks. No planning repair was made. The five
  notification invariants selected by the Phase 6A scope pass in the final run.
- `git diff --check` passed before candidate preparation.

Independent review identified seven required corrections. The correction preserves
schema-24 audit facts during older-backup recovery, keeps removed History controls
interactive, qualifies retained runtime identities by thread and goal, restores
the exact History viewport and detail focus, renders the complete recorded detail,
merges retained lifecycle metadata into the original audit event, and leaves
unrecorded observation times unknown.

- `history-review-corrections-final.xcresult` passed 10/10 affected projection,
  migration, lifecycle-removal, project-removal, recovery and navigation tests.
- `history-native-correction-10.xcresult` passed its corrected isolated native host
  journey 1/1 in 190.886 seconds. External CUA attached only to the matching
  DerivedData app at host PID 95442 and the window titled
  `Phase 6A History — isolated native interaction correction-root-v10`.
- At wide and compact widths, the corrected native journey scrolled to the exact
  event, selected it, displayed all four recorded-detail lines, opened its
  nonactive ticket and returned through Back with the exact Audit filter, selected
  identity, viewport and `history-open-entity` accessibility focus. It then removed
  the synthetic project, changed the removed History filter, selected different
  rows at both widths, restored the full detail and verified that no Open action
  existed. The installed owner application remained PID 60590 and was never
  selected or controlled.

## Native visual evidence

![Wide History timeline and event detail](2026-09-10-phase6a-history-wide.png)

![Compact History timeline and stacked detail](2026-09-10-phase6a-history-compact.png)

Both repository images are unchanged copies of attachments from the passing
native-5 result bundle and were inspected at their original resolutions. Comparison
with `history.png` and `history_compact.png` confirmed the dark Rekon palette,
source chips, timeline rhythm, wide list/detail relationship and compact stacking.

The implementation intentionally uses the established detailed inspector rather
than the mockup's flatter grouped cards, so exact provenance, times, recorded facts,
recovery and navigation remain together. Sidebar compaction is an explicit app
control and was exercised directly. Observation availability reports the actual
implemented source as unavailable/incomplete where appropriate; it does not repeat
aspirational mockup freshness copy.

## Boundaries and limitations

The observation source still represents the latest persisted snapshot, not an
invented immutable observation-change timeline. Actor and thread attribution is
labelled by provenance and is not promoted to verified independent review. The
native journey exercised reload and retained-store recovery tests exercised store
reopen; a full owner-app process restart was neither performed nor claimed.

The current portable archive v1 is unchanged. Future complete portable formats
must represent supported History facts and provenance or reject unsupported export.

## Temporary-output status

No cleanup was authorized or performed. Result bundles, logs, isolated home/tmp,
DerivedData, marker outputs, attachment exports and synthetic stores remain under
`/private/tmp/release-radar-phase6a.eJzQ2M` and
`/private/tmp/release-radar-phase6a-attachments.iOBzDG`. The two PNGs above are
the verified canonical repository copies.

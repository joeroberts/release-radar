# Release Radar Delivery Goals Phase Board contract

- Status: Owner-confirmed direction; implementation pending
- Date: 2026-08-29
- Governing specification:
  `docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md`

## Visual baseline

Keep the five-lane layout, spacing, color, card-density behavior, and selected
ticket inspector established by `docs/design/mockups/phase_board.png`. Use
`docs/design/mockups/goals.png` and `docs/design/mockups/goal_to_work_flow.png`
only for goal/work navigation vocabulary. Their observed-goal content is not
the Delivery Goal data model.

## Wide board

```text
release_radar
Established product roadmap

Viewed phase  [Established product roadmap ▾]   Active phase  Post-MVP remediation
Plan          Ready · revision 3 · 11/11 covered · 0 unassigned
Delivery Goal [All goals ▾]  [Show unassigned]   Card density [Full outcomes ▾]

┌────────────┬─────────────┬──────────────┬────────────┬────────────┐
│ Backlog 8  │ In progress │ Needs review │ Blocked 3  │ Accepted 0 │
│ RR-RM1     │ 0           │ 0            │ RR-RM5     │            │
│ RR-RM2     │             │              │ RR-RM6     │            │
│ ...        │             │              │ RR-RM7     │            │
└────────────┴─────────────┴──────────────┴────────────┴────────────┘

Selected ticket: RR-RM5
Delivery Goal     RR-DG2 · Portable project continuity · Planned
Codex execution   No linked Codex execution goal
Requires / Unlocks / Owner attention / Evidence / Audit / Notifications
```

## Interaction contract

- `Viewed phase` changes only the local board view. It never calls the
  active-phase mutation.
- The persisted active phase is always named next to the viewed-phase control.
- Existing authorized active-phase selection remains a separate `Make active
  phase` action and retains ADR-003 confirmation, audit, replay, and recovery.
- Plan state, revision, coverage, and unassigned counts update coherently with
  the viewed phase.
- Delivery Goal filtering hides nonmatching cards without moving them between
  lanes or changing persisted state.
- `Show unassigned` is available in Draft and Legacy-unassessed plans and
  truthfully returns zero only after an authoritative load.
- Finalizing a phase with zero upcoming tickets is invalid. A previously Ready
  phase that reaches zero upcoming because all assigned tickets became
  Accepted remains valid and displays `Ready · delivery complete · 0 upcoming
  · 0 unassigned` instead of a misleading initial-readiness claim.
- Draft and Legacy-unassessed plans show an inline warning that Backlog and
  Blocked tickets cannot start until coverage is finalized. Already
  grandfathered In progress and Needs review tickets are labelled as legacy
  continuation, not as covered.
- Selecting a card retains its current lane/card behavior and opens the
  inspector. No direct delivery editing controls are added.
- Awaiting Delivery Goal acceptance appears in the existing Needs Review
  inbox. Its explicit Accept action is owner-app-only; the Phase Board remains
  read-only and external agent tools cannot assert owner acceptance.

## Goal language

- App-owned planning records are always labelled `Delivery Goal`.
- Runtime observations and exact ticket/runtime links are always labelled
  `Codex execution goal`.
- The generic inspector heading `GOAL CONTEXT` is replaced by the two explicit
  sections when either type of context is shown.
- Delivery Goal lifecycle words are Draft, Planned, Active, Awaiting
  acceptance, Accepted, and Superseded.
- Codex goal status retains its own observed/last-known/stale/unavailable
  vocabulary and timestamp.

## Compact and accessible behavior

- At compact widths, goal and plan controls may wrap below the phase heading;
  they must not collapse into an unlabeled icon or hide the active/viewed
  distinction.
- Compact cards retain the approved ticket-ID and constraint-count density.
  Goal membership remains available in the inspector and filter summary.
- Keyboard order is Viewed phase, Make active phase when applicable, plan
  summary, Delivery Goal filter, Unassigned filter, density, lanes, inspector.
- VoiceOver labels include the viewed phase, whether it is active, plan state,
  revision, covered/eligible count, unassigned count, and whether a filter is
  applied.
- Focus remains on a selected ticket when filters still include it; otherwise
  focus moves to the filter summary and announces that the prior selection is
  outside the current filter.

## Failure and recovery states

- Store unavailable: replace plan and board content with the existing
  actionable store-recovery state; do not show cached readiness as current.
- Refresh failure after a successful plan mutation: state that the plan was
  saved and a refresh is needed; do not invite duplicate submission.
- Revision conflict: show the current revision and reload action while
  preserving the owner's unsubmitted view state where safe.
- Observation unavailable: Delivery Goal content remains visible; only Codex
  execution context becomes unavailable or stale.
- No goals in Legacy/Draft: show `No Delivery Goals recorded` and the exact
  unassigned upcoming-ticket count.

## Visual acceptance

The running signed application must be compared with the approved Phase Board
reference at relevant wide and compact window sizes. Acceptance requires the
same five-lane hierarchy and design language, explicit active/viewed separation,
truthful plan and coverage states, unambiguous goal labels, complete keyboard
and VoiceOver behavior, and no regression to card density or inspector access.

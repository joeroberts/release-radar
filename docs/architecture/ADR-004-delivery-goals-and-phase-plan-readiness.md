# ADR-004: Delivery Goals and phase-plan readiness

- Status: Accepted and owner-confirmed; implementation pending
- Date: 2026-08-29

## Context

Release Radar can persist phases, five-lane tickets, dependencies, blockers,
and exact links to observed Codex goals, but it has no app-owned representation
of the complete outcomes that organize a phase. A phase can therefore contain
upcoming tickets without proving that every ticket is represented exactly once
under a complete owner-approved outcome. The Established product roadmap
exposes this gap: its 11 upcoming tickets exist, but their six approved outcome
groups are not first-class Release Radar records.

Observed Codex goals cannot fill this role. They are execution observations
owned by an external runtime, may be stale or unavailable, and already have a
separate exact-link contract under ADR-001.

## Decision

Release Radar will add app-owned, phase-scoped Delivery Goals and a distinct
phase-plan readiness record in additive store schema version 11.

- One Delivery Goal may own many tickets.
- One ticket may belong to at most one Delivery Goal.
- A Draft or Legacy-unassessed phase may have unassigned tickets.
- A Ready phase requires every non-Accepted ticket to belong to exactly one
  non-superseded, complete, actionable Delivery Goal.
- Readiness is structural; it is not a lane, dependency state, blocker state,
  or observed runtime status.
- Any structural edit invalidates Ready and increments the phase-plan revision.
  Ordinary delivery progress does not.
- Every ticket writer uses the same store-owned enforcement path. New and
  moved tickets enter Backlog; Backlog and Blocked cannot bypass the Ready and
  exact-assignment gate to start work.
- Migration creates Legacy-unassessed phase plans and never infers Delivery
  Goals from tickets, prose, dependencies, audit, or Codex observations.
- Existing In progress and Needs review tickets receive a narrow one-time
  continuation exception. Existing Blocked tickets do not. Accepted legacy
  tickets remain historical without invented goals.
- The continuation flag is written only by the v11 migration. Importer,
  sample, and debug paths cannot grant it. Import creates every ticket in
  Backlog and records any non-Backlog source lane as an import-review fact;
  sample and debug capture data establish a valid plan before governed lane
  transitions.
- Accepted tickets are terminal and are never reopened. Rejected acceptance or
  later defects create new Backlog tickets governed by the current phase plan.
- Plan edits use bounded, optimistic-concurrency, idempotent typed commands;
  finalization is a separate atomic validation command.
- Lifecycle commands validate `phaseID` and the expected structural revision
  without incrementing it. Draft promotion, first-work activation, and
  supersession stay coupled to their authoritative plan/ticket transactions.
  Delivery Goal acceptance is accepted only from the existing owner-app
  dispatcher origin and never from MCP caller data.
- One phase-plan audit remains authoritative for a bounded revision. A
  relational assignment-event link attributes that same audit and revision to
  every affected ticket rather than emitting independent or duplicate audits.
- Existing `observed_goals` and `ticket_goal_links` retain their current
  meaning. UI and audit language explicitly distinguish **Delivery Goal** from
  **Codex execution goal**.
- Portable archive v1 cannot represent Delivery Goals. Import produces
  Legacy-unassessed plans; export fails rather than silently omitting any v11
  goal structure. A portable archive v2 requires separate approval.

The complete state, mutation, migration, repair, UI, error, and verification
contract is defined by
`docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md`.

## Phase and goal states

Phase plans use `legacy_unassessed`, `draft`, and `ready`. Delivery Goals use
`draft`, `planned`, `active`, `awaiting_acceptance`, `accepted`, and
`superseded`. Accepted and Superseded goals are terminal. Only app-owned formal
commands change these states; observed Codex state cannot do so.

## Installed-state repair

The v11 delivery includes one audited, replay-safe bootstrap for `RR-R10` in
Post-MVP reported-defect remediation and one exact repair of `RR-ROADMAP` into
the six owner-approved Delivery Goals. Accepted RR-R1 through RR-R9 history is
not assigned retroactively. The repair must preserve all existing ticket
outcomes, lanes, dependencies, blockers, active-phase selection, observed goals,
and ticket/Codex-goal links.

## Consequences

- The app can distinguish a structurally complete phase plan from work merely
  being present on a board.
- Upcoming work cannot start through an ungoverned writer path.
- Owners can browse another phase without changing the active execution phase.
- Goal language becomes unambiguous in Phase Board and inspector surfaces.
- Structural edits may intentionally return a live phase to Draft; already
  active post-v11 work may continue, while Backlog work waits for re-finalization.
- Existing phases initially show Legacy unassessed rather than fabricated
  completeness.
- Finalization rejects an initially empty phase. A valid Ready phase remains
  Ready when ordinary delivery progress later leaves it with zero upcoming
  tickets, and the UI identifies that as completed delivery.
- Archive v1 export becomes unavailable for projects containing Delivery Goals
  until a separately approved archive v2 exists.

## Rejected alternatives

- Reusing observed Codex goals as delivery-plan authority.
- Treating ticket dependencies, phase presence, or Markdown as proof of a
  complete outcome structure.
- Adding a Ready lane or deriving lane transitions automatically.
- Enforcing readiness only in the MCP bridge while leaving store, importer, or
  owner paths able to bypass it.
- Guessing goal assignments during migration.
- Silently dropping Delivery Goals from portable archive v1.
- Combining plan revision and finalization into an omission-sensitive bulk
  replacement command.

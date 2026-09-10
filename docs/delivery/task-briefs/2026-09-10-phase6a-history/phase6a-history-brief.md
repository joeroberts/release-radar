# Phase 6A: truthful event-time History

Status: controlling brief; independent planning review passed at `22126cf` with
no Required findings. Local implementation is authorized.

## Objective and outcome

Deliver the Phase 6 History journey: immutable event-time facts and provenance,
filterable/readable event detail and exact retained-entity navigation, with honest
unknown/error states and unchanged attention/acceptance authority. Implement the
first slice of the [Phase 6 plan](../../plans/2026-09-10-phase6-outcomes-tasks-history.md),
not merely a label change from Activity.

## Scope and exclusions

- Capture event-time project/registration/entity, available lane/phase and
  transition facts in the authoritative transaction. Preserve occurrence and
  observation/recording times separately where meaningful. Use stable source IDs
  and distinguish local audit, retained/imported history, observations and
  notification delivery; no asserted attribution becomes verified independence.
- Existing rows without historical facts stay unknown. Never infer past state
  from current tickets or parse human reason text into authoritative transitions.
  Current context may appear only explicitly labeled. Latest observation snapshots
  are not an invented immutable timeline; capture new observations consistently
  without fabricating earlier changes.
- Extend existing Activity projection/view into one History surface with source
  filters, deterministic ordering, useful exact event detail, and explicit empty,
  filter-zero, failed/incomplete and unavailable source states. Preserve unrelated
  events and retained project identity after archive/removal/re-add.
- Navigate to existing entities through the shared typed history. Back/Forward
  restores exact event selection/filter/scroll/focus; stale or inaccessible
  targets explain recovery instead of redirecting into replacement registrations.
- Add accessible contextual History Help through a reusable ordinary Help route
  or component, explaining provenance, unknown facts, current context, attention
  versus acceptance, and copied-not-dispatched actions where present. Later
  slices extend this same Help surface.
- Preserve current meaningful-event eligibility, durable deduplication and
  unknown-send handling. Browser/filter/history refresh and replay/import/restore
  cannot manufacture new acceptance or notifications. No unlinked-goal attention
  rule is selected. Any necessary fix stays within these concrete invariants.
- Extend existing removal/backup recovery for new facts atomically, preserving
  legacy unknown fields and newer retained history. No Phase 7 exporter/importer,
  new task engine, live observer, notification service calls or owner state.

## Dependencies and source boundaries

Baseline is committed Phase 6 controlling-doc handoff descending from
`e5372d170d9202d207922fe51f38bcf0827a2967`; dispatch names the exact handoff commit.
Read [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md),
[product design](../../../design/agent-driven-delivery-dashboard-design.md) and
the Phase 6 plan. `history.png` and `history_compact.png` under
`docs/design/mockups/` define the visual reference; source freshness remains
unavailable/stale until a real supported source exists regardless of mockup copy.

Current source starts in `ReleaseRadar/Activity/ProjectActivityProjection.swift`
and `ActivityView.swift`, `ReleaseRadar/Navigation/AppRoute.swift` and
`NavigationHistory.swift`, `ReleaseRadar/App/AppModel.swift`, and
`ReleaseRadarCore/Store/DeliveryStore.swift` / `StoreMigrations.swift`.
Trace existing command/audit writes and source records before editing. Reuse
`ProjectLifecycle.swift` retained data and `ApplicationBackup.swift` recovery.
Do not create a second event bus, reconciliation database or generic framework.

Future Goals, evidence, adoption and search consume stable event identity and
typed navigation; provide those contracts with the delivered History consumer.
Additive persistence must survive current backup/removal recovery. Future portable
formats must represent the records or reject unsupported content; no new format
work belongs here. Preserve five lanes, acceptance, exact replay and existing
schema fixtures without rewriting accepted historical definitions.

## Direct verification and acceptance

Use existing XCTest fixtures and test-first changes. Focused checks must prove:

1. A recorded event keeps its actual facts after later lane/phase/name changes;
   pre-migration events remain unknown where facts were never recorded.
2. New source records have stable identity, real times and provenance; duplicate
   observations/exact command replay do not duplicate effects. Transaction failure
   rolls back both state and event facts; cross-project reads stay scoped. Notification send
   outcomes remain independent, including unknown results.
3. Archive, removal/re-add and backup restoration retain exact historical
   identity/facts and reject redirection to a new registration. New persistence
   survives store reopen. No history read changes lane, goal/task state, active
   phase, acceptance or attention counts.
4. Source/filter ordering, truly empty/filter-zero/error and unavailable
   observation states are distinguishable. Failed reads cannot look complete.
5. Native keyboard/AX at wide and compact widths reaches first/last events,
   filters and detail, opens a nonactive-phase entity, and returns to the exact
   History context. Missing targets recover with accessible focus. Compare
   screenshots with both History references and record necessary deviations.
6. History Help explains implemented controls and recovery; no future capability
   is presented as available. Relevant existing projection/navigation/attention
   tests remain valid, or changed expectations explicitly reflect event-time facts.

Use `ReleaseRadar.xcodeproj`, scheme `ReleaseRadar`, serial macOS XCTest with
targeted `-only-testing` selectors established from current tests. Inspect the
existing inert synthetic host setup before launch; sanitized `env -i`, known
necessary signing/package variables only, unique retained result path. The
orchestrator grants an exclusive native-host reservation. Verify the running
synthetic host PID and unique window before external CUA attaches. Never select
or launch a plain DerivedData app or installed owner application. Report baseline
failures separately; no unrelated repair. No direct owner SQLite or credentials.

## Assignment, review and endpoint

Delivery owner: fresh Sol High task, ceiling Astra High, because this slice spans
event capture, retention/recovery and native navigation. Dispatch supplies actual
task ID, exact baseline and branch. Writer owns source/tests, affected design/ADR
content and `docs/delivery/evidence/2026-09-10-phase6a-history.md` plus necessary
screenshots. Orchestrator exclusively owns progress/catalog/generated indexes;
coordinate new artifact metadata before the final candidate. No other product
writer is released concurrently.

One fresh independent Astra High peer reviews the specified candidate for
event/persistence authority, recovery and native UX/QA. It may not be the author.
Only Required findings block; same reviewer handles bounded corrections. No
review-of-review or extra role gates. Record concise source/check/native evidence
and limitations, not transcripts. Commit the scoped local source/docs after direct
verification, obtain independent review, make required corrections and preserve
the final endpoint. Return commit, changed behavior, checks, retained temporary
paths and confirmation that task-owned processes stopped.

Local source/tests/affected documents and commits are authorized. Push/PR,
merge, installation, owner-app/catalog operations, credentials, notifications,
external security scans, consumer changes, configuration/instructions and cleanup
are not. Publication will be requested for a concrete reviewed endpoint; it does
not block authorized source work. No installation/owner-acceptance claim.

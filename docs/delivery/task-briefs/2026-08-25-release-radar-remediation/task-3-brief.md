### Task 3: Persist explicit ticket-to-goal identity and improve authoritative ticket outcomes

**Objective / user outcome:** A ticket displays and alerts against the specific goal the owner approved, never whichever goal happened to be newest on its thread. The existing authoritative ticket `outcome` becomes the meaningful TL;DR shown on cards; legacy thread links remain readable without guessing a goal.

**Controlling references:** Design spec “State ownership,” “Agent tool contract,” and “Phase board”; ADR-001 typed mutation bridge/observed-state boundary.

**In scope:** A minimal additive schema migration from v7 to v8, explicit ticket-goal links, compatible legacy handling, typed command validation/audit scopes, projection/activity/notification content sourced from the approved goal, and descriptive outcomes for newly created sample data. **Out of scope:** a second TL;DR field, rewriting persisted owner outcomes, live Codex attachment, automatic semantic matching, selecting the newest goal, bulk relinking arbitrary owner data, or manual ticket editing UI.

**Dependencies / release gate:** The MVP is accepted; RR-R3 is serialized after the currently released writer by owner-priority sequencing, not by an RR-R2 technical dependency. Architect, QA, Security/Privacy, TPM, and Delivery Manager must approve the migration and approval semantics before a fresh Implementer begins.

**Files:**

- Modify: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarCore/Notifications/MeaningfulDeliveryEvent.swift`
- Modify: `ReleaseRadar/Projects/DashboardSampleData.swift`
- Modify: `ReleaseRadar/Projects/DashboardProjection.swift`
- Modify: `ReleaseRadar/Activity/ProjectActivityProjection.swift`
- Modify: `ReleaseRadar/Projects/TicketDetailView.swift`
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/DashboardProjectionTests.swift`
- Modify: `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- Modify: `docs/architecture/ADR-001-release-radar-boundaries.md`

**Interfaces:** Add a unique `(project_id, id, thread_id)` parent key for `observed_goals`, then add `ticket_goal_links(id, project_id, ticket_id, thread_id, goal_id)` with `UNIQUE(project_id, ticket_id)`, `UNIQUE(project_id, goal_id)`, a composite foreign key from `(project_id, ticket_id, thread_id)` to the existing unique key on `thread_links`, and a composite foreign key from `(project_id, goal_id, thread_id)` to `observed_goals`. Add `AgentCommand.linkGoal(id:ticketID:goalID:)`, which requires the goal's thread to match an existing `thread_links` row for that ticket, rejects project-local cross-ticket goal reuse, and writes one audit event; keep existing `upsertTicket(... outcome: ...)` as the only ticket-content command and preserve `linkThread` for thread attribution. Backfill only when a ticket has exactly one linked thread, that thread has exactly one project-local goal, and that goal is a candidate for exactly one ticket project-wide. Improve outcomes only in `DashboardSampleData` for fresh isolated seeds; never rewrite persisted owner content in migration.

**Data / security / privacy:** The app remains sole database writer. Goal IDs are observed data and must be verified against the project before linking; cross-project/missing links roll back. No inference, runtime observation, or projection can create/change a ticket-goal link or delivery lane.

- [ ] **Step 1: Write RED migration/bridge/projection tests.** In `StoreAcceptanceTests`, seed v7 data with one exactly-unambiguous ticket/thread/goal mapping, one ticket with multiple linked threads, one linked thread with multiple goals, and one goal whose thread is linked to multiple tickets; assert v8 backfills only the unambiguous one-to-one identity and retains all records/snapshot behavior without changing ticket outcomes. Verify the schema manifest and `foreign_key_check` require both exact composite relationships plus project-local ticket and goal uniqueness, and that a later goal upsert which reassigns the linked goal to a different thread rejects and rolls back without changing the prior observed goal or link. In `AgentBridgeAcceptanceTests`, assert owner-approved `linkGoal` persists its record and audit scope only when its goal belongs to the ticket's linked thread; missing/cross-project/wrong-thread goals and project-local cross-ticket goal reuse leave ticket/link/audit/replay unchanged. In `DashboardProjectionTests` and `NotificationAcceptanceTests`, link two goals to one thread, approve the older one, then observe a newer goal: detail/activity/blocked alert must still use only the approved goal. Separately assert newly seeded card outcomes are descriptive and remain editable through the existing `upsertTicket` path.

- [ ] **Step 2: Run RED.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests -only-testing:ReleaseRadarTests/DashboardProjectionTests -only-testing:ReleaseRadarTests/NotificationAcceptanceTests`

  Expected: FAIL because the store is v7, projections choose newest `observed_goals` by thread, and the bridge has no explicit goal-link command.

- [ ] **Step 3: Implement the additive contract.** Add the v8 migration, required unique parent key, exact composite foreign keys, and schema manifest/foreign-key expectations; do not alter historic thread links or owner ticket content. Validate and transact `linkGoal` through `AgentCommandDispatcher`, including the matching linked-thread requirement, request replay, envelope validation, result/audit scope, and tests. Change ticket detail/activity/runtime joins and goal-blocked event lookup to join `ticket_goal_links` by exact project/thread/goal identity. Keep `tickets.outcome` as the sole concise card/detail description and improve only fresh `DashboardSampleData` seed copy.

  Before changing the schema or bridge, amend ADR-001 to record that a ticket's approved goal is an explicit project/ticket/thread/goal identity, that the goal must belong to the ticket's already-linked thread, and that ambiguous legacy thread data remains unlinked rather than being resolved by recency.

- [ ] **Step 4: Run GREEN and migration checks.** Re-run the focused command. Build an isolated legacy-v7 fixture twice to prove migration is idempotent, `foreign_key_check` remains clean, and multi-goal legacy threads show “No linked goal” rather than silently changing identity. Inspect ticket detail, Activity, and Notifications for the approved identity/content.

**Failure behavior:** Unknown/missing/cross-project goal IDs, malformed content, and migration validation failures reject the command or open the existing typed unavailable/recovery state with no partial write. Legacy ambiguity stays explicitly unavailable; it is not resolved by time ordering.

**Activity / audit evidence:** `linkGoal` and the existing `upsertTicket` command have structured ticket-scope audits with normal asserted/verified thread attribution when present. Activity explains the specific approved goal and updated outcome without leaking raw unbounded input.

**Acceptance criteria:** No projection/notification selects a newest goal merely because it shares a thread; one approved identity survives updates/relaunch; legacy unambiguous data migrates compatibly while ambiguity fails closed; meaningful ticket outcomes remain editable through the existing audited `upsertTicket` command and untouched shipped sample copy becomes descriptive.

**Required independent reviews:** Code Reviewer, QA migration/behavior verifier, Architect, Security/Privacy verifier, TPM, Delivery Manager.

**Progress-ledger evidence:** RR-R3 design/ADR decision (if required), migration version and snapshot evidence, RED/GREEN results, identity/rollback/legacy proof, visual inspection, reviewer results, and RR-R4 release decision.


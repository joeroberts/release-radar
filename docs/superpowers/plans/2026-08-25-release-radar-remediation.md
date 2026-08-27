# Release Radar Remediation Implementation Plan

> **Historical plan with a superseded execution state.** RR-R1 through RR-R6
> and the Task 7A/7B implementation have completed engineering delivery. The
> later populated-schema SQLite-23 repair, Release staging/install evidence, and
> current owner-validation gate in `docs/delivery/progress.md` supersede this
> plan's unchecked boxes, its earlier Task 7A authorizer prohibition, and its
> earlier handoff sequence. Do not replay these tasks. No separate product
> writer is currently authorized.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the approved onboarding, authorization recovery, ticket/goal identity, notification-rule, dashboard-density, production-icon, empty-workspace routing, and local Release-handoff gaps without changing Release Radar’s local-first boundaries.

**Architecture:** Keep the app as the sole SQLite writer. Folder authorization remains represented by security-scoped bookmarks and is re-established by an explicit owner action; typed commands remain the only agent mutation path. Ticket-to-goal links become explicit persisted identities, notification-rule decisions are persisted and consulted at the event-creation boundary, and project-scoped navigation is admitted only for a project present in the loaded dashboard.

**Tech Stack:** Swift 6, SwiftUI, macOS 14+, XCTest, system SQLite3, AppKit `NSOpenPanel`, security-scoped bookmarks, Xcode asset catalogs, and the existing signed Xcode project.

**Spec:** `docs/design/agent-driven-delivery-dashboard-design.md`; `docs/architecture/ADR-001-release-radar-boundaries.md`

## Global Constraints

- Product presentation remains **Release Radar By Rekon Labs**; application name remains **Release Radar**.
- Preserve the signed sandboxed macOS 14+ app, bundle identifier `com.rekonlabs.ReleaseRadar`, local Application Support database, and app-only SQLite authority.
- Do not add dependencies, a custom test harness, a cloud service, a repository-backed manifest, or owner-facing manual delivery-transition controls.
- Keep exactly five persisted lanes; dependencies and observed Codex state remain derived display context and never transition a lane implicitly.
- Treat stored folder paths as untrusted until the associated security-scoped bookmark is successfully resolved and accessed. Failed, stale, missing, or mismatched authorization must fail closed and retain history.
- Do not inspect, reset, delete, or mutate an owner database while implementing or validating these slices. Use temporary test databases and isolated capture data only.
- The approved visual references are `docs/design/mockups/onboarding_state.png`, `docs/design/mockups/dependencies.png`, `docs/design/mockups/phase_board.png`, and `docs/design/mockups/settings.png`; inspect the relevant running surface at wide and compact window sizes before accepting UI work.
- The V1 raster drafts under `docs/brand/` are references only. Recreate the selected icon deterministically; do not ship the generated raster directly or redesign the approved direction without owner review.
- Serialize all write tasks. RR-R1, RR-R2, RR-R3, RR-R5, and RR-R6 have no technical dependency on one another beyond the accepted MVP and the currently released writer; they execute in the listed order only as owner-priority sequencing. RR-R4 follows RR-R3 so its v9 notification storage and behavior are built after the v8 exact-goal contract. RR-R7 follows the accepted RR-R1–RR-R6 remediation because its handoff must contain that verified combined result. Before each task, the TPM and Delivery Manager release it; after each task, a fresh Code Reviewer, QA verifier, Architect, and (for authorization, persisted state, bridge, notification, or signing work) Security/Privacy verifier record their independent result in `docs/delivery/progress.md`.

## Affected-file map

- `ReleaseRadar/Projects/OnboardingView.swift` and `ReleaseRadar/Projects/ProjectsView.swift` — add and route a cancellable add-project sheet plus already-onboarded-folder handling.
- `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`, `ReleaseRadarCore/Onboarding/ProjectBookmarkStore.swift`, `ReleaseRadar/App/AppModel.swift`, `ReleaseRadar/Review/NeedsReviewView.swift`, and `ReleaseRadar/Shared/FailureStateView.swift` — validate/recover project-folder authorization before an owner review decision.
- `ReleaseRadarCore/Store/StoreMigrations.swift`, `ReleaseRadarCore/AgentBridge/AgentCommand.swift`, `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`, `ReleaseRadarCore/Notifications/MeaningfulDeliveryEvent.swift`, `ReleaseRadar/Projects/DashboardSampleData.swift`, `ReleaseRadar/Projects/DashboardProjection.swift`, `ReleaseRadar/Activity/ProjectActivityProjection.swift`, and `ReleaseRadar/Projects/TicketDetailView.swift` — persist explicit goal identity and refresh meaningful ticket outcomes through the existing authoritative command/store/projection path.
- `ReleaseRadarCore/Notifications/AlertRules.swift` (new), `ReleaseRadarCore/Store/StoreMigrations.swift`, `ReleaseRadarCore/Notifications/MeaningfulDeliveryEvent.swift`, `ReleaseRadar/App/AppModel.swift`, `ReleaseRadar/Notifications/SettingsModels.swift`, and `ReleaseRadar/Notifications/SettingsView.swift` — persist and apply alert rules.
- `ReleaseRadar/Dependencies/DependencyGraphLayout.swift`, `ReleaseRadar/Dependencies/DependencyGraphView.swift`, `ReleaseRadar/Projects/PhaseBoardView.swift`, and `ReleaseRadar/Projects/TicketCardView.swift` — selected-path graph and density controls.
- `docs/brand/release-radar-icon-v1.svg`, `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/Contents.json`, and its generated PNG representations (new), plus `ReleaseRadar.xcodeproj/project.pbxproj` — deterministic production AppIcon source, catalog, and target wiring.
- `ReleaseRadar/App/AppModel.swift`, `ReleaseRadar/Navigation/SidebarView.swift`, and `ReleaseRadarTests/AppRouteTests.swift` — reject nonexistent project routes before consequential recording, hide project navigation for an empty dashboard, and cover the reported foreign-key failure. The signed Release product is generated at `/Applications/ReleaseRadar.app`; it is a handoff artifact, not repository source.
- Existing focused tests only: `ReleaseRadarTests/OnboardingAcceptanceTests.swift`, `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`, `ReleaseRadarTests/DashboardProjectionTests.swift`, `ReleaseRadarTests/NotificationAcceptanceTests.swift`, `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`, `ReleaseRadarTests/StoreAcceptanceTests.swift`, and `ReleaseRadarTests/AppRouteTests.swift`. Running-app acceptance uses Computer Use against an alternate Debug bundle identifier and isolated container rather than creating a new UI-test harness.

---

### Task 1: Make Add Project cancellable, reset-safe, and useful for an already active folder

**Objective / user outcome:** From Projects, the owner can visibly close or cancel Add Project without retaining the prior folder/preview/error state. Selecting a folder already represented by a completed active project gives a direct Open Project action instead of creating duplicate onboarding state.

**Controlling references:** Design spec “Onboarding” and “Dashboard model”; ADR-001 local folder authority; `docs/design/mockups/onboarding_state.png` for visible recovery/action language.

**In scope:** Sheet cancel/close affordances with stable accessibility identifiers; resetting every `OnboardingView` transient field on cancel/dismiss; distinction between pending and completed project roots in `OnboardingPreview`; a direct existing-project navigation callback. **Out of scope:** deleting a project, changing phases/tickets, altering worktree discovery, parsing Markdown as delivery authority, creating a repository-backed dashboard manifest, inventing a default phase, or adding a manual delivery editor.

**Dependencies / release gate:** None beyond the accepted MVP. TPM and Delivery Manager release RR-R1 only after this brief is independently approved; no downstream task has a technical dependency on RR-R1.

**Files:**

- Modify: `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- Modify: `ReleaseRadar/Projects/OnboardingView.swift`
- Modify: `ReleaseRadar/Projects/ProjectsView.swift`
- Modify: `ReleaseRadarTests/OnboardingAcceptanceTests.swift`

**Interfaces:** Extend `OnboardingPreview` with `completedProjectID: ProjectID?`, mutually exclusive with `pendingProjectID`. A completed identity requires exactly one canonical-root owner, no open onboarding marker, and at least one persisted phase. A root-owning project without a phase is pending/incomplete, never completed. Add `onCancel` and `onOpenExisting(ProjectID)` closures to `OnboardingView`; `ProjectsView` owns sheet dismissal and passes its existing `openProject` callback. Do not change the importer, `ProjectOnboarding.finish(_:)`, `SidebarView`, agent commands, or source project files.

**Data / security / privacy:** This only reads existing local project-root state. Never create, update, or delete a bookmark/project when the owner cancels; canonical-root comparison remains the duplicate boundary.

- [ ] **Step 1: Write RED acceptance tests.** In `OnboardingAcceptanceTests`, prepare and finish a fixture project, then inspect its canonical/symlinked root and assert `completedProjectID` is that project while `pendingProjectID` is nil and no second project/root/bookmark row exists. Assert a root-owning project with no phase is not completed. The production change these tests catch is duplicate/restarted onboarding for a completed root or premature completion for a markerless no-phase root.

- [ ] **Step 2: Run the focused RED tests.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests`

  Expected: FAIL because completed roots are indistinguishable from new roots and the sheet has no cancel/reset controls.

- [ ] **Step 3: Implement the smallest complete behavior.** Have `FolderProjectOnboarding.inspect(folder:)` look up the canonical root and return completed versus pending identity without writing. Add a reset method that clears `preview`, project identity/name, task exclusions, import choice, first-phase state, status, failure, and working state before invoking `onCancel`. Render one prominent, keyboard-reachable Cancel action in the sheet; disable it only while an operation is active. For a completed identity, render “Open existing project”, invoke `onOpenExisting`, dismiss the sheet, and do not offer prepare/finish. Wire both callbacks through `ProjectsView` to its existing `openProject` callback and sheet state.

- [ ] **Step 4: Run GREEN and inspect the flow.** Re-run the focused test command. Build and launch an alternate Debug bundle identifier with `--rr10-capture --rr10-empty-store` so it uses an isolated empty app container; record zero initial project/root/bookmark counts, then use Computer Use to verify `onboarding-cancel` is visible/keyboard reachable, dismisses the sheet, and reopening starts clean. In that isolated container, complete onboarding through the real flow for a disposable project folder containing the already supported JSON fixture; verify the preview offers import and Finish creates one project. Choose the same folder again, assert `onboarding-open-existing` is visible and keyboard reachable, activate it, and verify the sheet closes onto that project's Overview/Board with unchanged one-project/root/bookmark counts. Do not create a UI-test target or grant the isolated app access to an owner folder.

**Failure behavior:** Cancel is a no-op on durable state. A non-existent folder, root owned by another project, or unavailable folder remains the existing actionable failure. A completed project is never silently prepared again.

**Activity / audit evidence:** Cancel creates no durable mutation. Open Existing deliberately uses the established `AppModel.openProject(_:)` route, so the first dashboard open may set `first_dashboard_opened` and create its existing project-scoped audit; this preserves notification gating and is not a delivery-state transition. The ledger records the exact test result, UI capture/accessibility evidence, unchanged project/root/bookmark counts, the bounded first-open audit if it occurs, and that no database deletion occurred.

**Acceptance criteria:** Cancel/close is visible and accessible in Add Project; reopening is clean; finished projects can be opened from the selected active folder without duplicates; pending onboarding still resumes and first-phase gates are unchanged.

**Required independent reviews:** Code Reviewer, QA visual/accessibility verifier, Architect, TPM, Delivery Manager; Security/Privacy verifier confirms Cancel has no durable mutation, healthy bookmarks remain unchanged, stale-bookmark fail-closed behavior is preserved, and Open Existing performs at most the established bounded first-dashboard-open audit without changing delivery state.

**Progress-ledger evidence:** RR-R1 status/gate, test command/result, selected-root/duplicate regression evidence, full/compact UI evidence, reviewer decisions, security result, risks, and RR-R2 as next eligible task.

### Resolved product decision: initialize tracking when no usable structure exists

**Verified conflict:** Release Radar itself has no pre-existing supported dashboard JSON, and the current “Ask agent to define first phase” action only persists a request marker; the accepted live-Codex feasibility result provides no supported outbound agent invocation. The controlling design simultaneously forbids the app from inventing a default phase, exposing owner phase editing, parsing Markdown as canonical state, or creating a repository-backed dashboard manifest.

**Owner decision — 2026-08-25:** Use **Initialize Project Tracking** and a
truthful owner-mediated handoff through the existing inbound typed bridge. The
app saves a resumable pending project, displays a path-free Codex prompt, and
provides an icon-only overlapping-squares copy control labelled **Copy Codex
prompt** with visible and accessibility-announced confirmation. The app does
not launch, contact, paste into, or submit to Codex. Portable Import remains
hidden, arbitrary Markdown remains non-authoritative, and the future Help
section is deferred.

**Exact prompt:** “Define the current Release Radar tracking state for this
project. Through Release Radar's existing typed inbound bridge, create or
update the active phase and the work currently in scope. Record truthful
ticket outcomes, lanes, dependencies, blockers, evidence, and Codex links only
when known. Do not create or edit repository dashboard files, do not infer
canonical state from arbitrary Markdown, and send uncertain items to Needs
Review instead of guessing.”

**Release gate:** Do not hide the conflict behind a fabricated phase, owner
phase editor, outbound controller, or new repository authority. The two
test-first slices below must pass their independent plan and completion gates
before RR-R7 packaging resumes.

**Evidence:** Record the owner decision, exact prompt, live failure, absence of
an authoritative portable archive, request-marker-only source path, clipboard
privacy result, and prohibited alternatives in `docs/delivery/progress.md`.

### Task 2: Recover folder authorization before resolving or dismissing review

**Objective / user outcome:** If the saved folder bookmark is stale, missing, or denied, Needs Review stops before Resolve/Dismiss and presents Locate/Reauthorize. The owner can select the same project root to replace the bookmark and retry; mismatched folders and failed scope access remain blocked.

**Controlling references:** Design spec “Failure behavior” and “Onboarding”; `docs/design/mockups/onboarding_state.png`; ADR-001 sandbox and sole-writer boundaries; `AGENTS.md` Security and Privacy Verification requirements.

**In scope:** An owner-only recovery action for the selected project root, bookmark replacement in one transaction, first-root association for a legacy project that has no persisted root/bookmark, scope validation around the owner decision, failure presentation/copy, and refresh after success. **Out of scope:** broad filesystem access, automatic bookmark repair, replacing a nonempty project with a different root, changing agent authorization, or bypassing `AgentCommandDispatcher`.

**Dependencies / release gate:** The MVP is accepted; RR-R2 is serialized after the currently released writer by owner-priority sequencing, not by an RR-R1 technical dependency. TPM/Delivery Manager release it only after the security/privacy reviewer accepts the proposed bookmark lifecycle.

**Files:**

- Modify: `ReleaseRadarCore/Onboarding/ProjectBookmarkStore.swift`
- Modify: `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadar/Review/NeedsReviewView.swift`
- Modify: `ReleaseRadar/Shared/FailureStateView.swift`
- Modify: `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`
- Modify: `docs/architecture/ADR-001-release-radar-boundaries.md`

**Interfaces:** Add a narrowly scoped `FolderProjectOnboarding.withAuthorizedProject(projectID:_:)` operation that resolves only persisted bookmarks for that project, starts scope access for the duration of the supplied owner-decision closure, and returns a verified `AuthorizedProject`. Add two explicit mutations: `reauthorizeProjectRoot(_:for:)` replaces only the same canonical persisted root; `associateFirstProjectRoot(_:for:)` is offered only when both roots and bookmarks are absent, requires explicit owner confirmation naming the project, rejects any globally owned root, and records a distinct bounded audit reason. Inject this onboarding authorization collaborator into `AppModel` for tests. Expose the corresponding recovery action from `NeedsReviewView`.

**Data / security / privacy:** Bookmark data is local sensitive authorization material. Never expose it in UI/logs/audits. Mark stale/denied records stale; preserve all review/audit history. The typed owner command executes only inside successful scope access, with only matching authorized roots in the registry.

- [ ] **Step 1: Write RED tests.** Extend `OnboardingAcceptanceTests` with stale, resolver-failure, denied-scope, mismatched-folder, and rootless-legacy cases: each failed attempt must leave the review item open and create no review-decision audit; selecting the matching root resets only that bookmark’s stale flag, while a rootless project may associate only one currently unowned canonical root. Add an `AppRouteTests` app-model acceptance test that calls Resolve on a stale or rootless fixture and asserts the `review-locate-authorization` failure/action is shown, then reauthorizes and confirms the same decision reaches `AgentCommandDispatcher` once.

- [ ] **Step 2: Run RED.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests`

  Expected: FAIL because `performReviewDecision` currently trusts `project_roots` paths and has no bookmark gate or recovery action.

- [ ] **Step 3: Implement the fail-closed recovery path.** Resolve stored bookmarks, reject stale/denied/missing ones before dispatcher construction, and retain scope until the command reply is known. In `AppModel`, convert these typed authorization failures into a recovery presentation rather than a generic internal error. For an existing root, `NeedsReviewView` offers Locate/Reauthorize and rejects every different canonical root. For a rootless legacy project, it instead offers Associate project folder, shows a confirmation naming the target project, and accepts only a globally unowned root. On success, reload the project/review/activity projections and allow the owner to retry explicitly; do not auto-resolve/dismiss.

  Before changing the authorization implementation, amend ADR-001 to record that an owner-triggered review mutation requires a currently resolved security-scoped bookmark; reauthorizing the same persisted root and explicitly associating the first root for a rootless legacy project are separate owner actions with separate audits.

- [ ] **Step 4: Run GREEN and recovery inspection.** Re-run the focused tests, then use an isolated app folder to verify Resolve/Dismiss is disabled during recovery, failure copy explains the next action, the chooser cannot authorize a different project, and successful reauthorization permits a subsequent explicit decision.

**Failure behavior:** Any failure leaves the review item open and no partial audit/event/command row. Stale or denied bookmarks are marked stale; malformed/foreign selection never overwrites stored authorization. Security scope is stopped on every exit path.

**Activity / audit evidence:** The final Resolve/Dismiss retains the normal typed audit. Reauthorization records a bounded owner audit reason without paths/bookmark bytes; unsuccessful attempts do not claim a decision occurred.

**Acceptance criteria:** Review actions cannot proceed on missing/stale/denied authorization; Locate/Reauthorize is actionable and correctly scoped; recovery preserves fail-closed behavior and existing history; successful owner reauthorization followed by retry completes once.

**Required independent reviews:** Code Reviewer, QA recovery/accessibility verifier, Architect, Security/Privacy verifier, TPM, Delivery Manager.

**Progress-ledger evidence:** RR-R2 gate, RED/GREEN commands, stale/denied/mismatch/no-partial-write evidence, isolated recovery capture, audit evidence, reviewers/security result, and RR-R3 release decision.

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

### Task 4: Make alert rules persisted controls that suppress event creation

**Objective / user outcome:** Settings contains real alert toggles. Their values survive relaunch, and turning a rule off prevents the corresponding notification event from being created—not merely sent—while other rules and dashboard use continue to work.

**Controlling references:** Design spec “Notification policy”; ADR-001 Keychain/app-owned notification boundary.

**In scope:** Four persisted owner-facing rule groups matching Settings: blocked linked goals; agent completion and review requests; Needs Review entry; and paused goals. The first three default on and paused goals default off. Settings bindings, authoritative event-creation guards, the paused/blocked occurrence lifecycle, and scoped load/update failure and relaunch behavior are included. **Out of scope:** Pushover credential changes, scheduled notifications, per-device sync, new provider behavior, changing fingerprints for already-supported enabled events, retroactively creating events after a rule is enabled, or adding any `AgentCommand`/external-agent mutation for owner alert settings.

**Dependencies / release gate:** RR-R3 accepted. TPM/Delivery Manager release RR-R4 after Architect and Security/Privacy agreement that rules are local app settings and event creation is the enforcement point.

**Files:**

- Create: `ReleaseRadarCore/Notifications/AlertRules.swift`
- Modify: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Modify: `ReleaseRadarCore/Notifications/MeaningfulDeliveryEvent.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadar/Notifications/SettingsModels.swift`
- Modify: `ReleaseRadar/Notifications/SettingsView.swift`
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`

**Interfaces:** Add a four-case, closed `AlertRuleKind` with exact raw values `blockedLinkedGoals = "blocked_linked_goals"`, `agentCompletionAndReview = "agent_completion_and_review"`, `needsReviewEntry = "needs_review_entry"`, and `pausedGoals = "paused_goals"`. Back it with an `AlertRuleStore` and additive v9 table whose authoritative shape is `alert_rules(kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('blocked_linked_goals', 'agent_completion_and_review', 'needs_review_entry', 'paused_goals')), is_enabled INTEGER NOT NULL CHECK (is_enabled IN (0, 1)))`; extend current-schema validation to recognize those constraints. The authoritative loader must return a snapshot only when it reads the exact four-kind set once each with valid Boolean values; it must reject missing, unknown, duplicate, or invalid values rather than synthesizing defaults outside migration. Migration seeds exactly `[blockedLinkedGoals: true, agentCompletionAndReview: true, needsReviewEntry: true, pausedGoals: false]` transactionally.

The event-to-rule mapping is exhaustive over all six `MeaningfulDeliveryEventKind` cases: `goalBlocked -> blockedLinkedGoals`; `agentCompleted -> agentCompletionAndReview`; `reviewRequested -> agentCompletionAndReview`; `ticketNeedsReview -> needsReviewEntry`; `importNeedsReview -> needsReviewEntry`; and new bounded `goalPaused -> pausedGoals`. The mapping has no fallback/default branch that could silently admit a later event kind. `MeaningfulDeliveryEvent.enqueue` queries the applicable rule before any occurrence or event write. A disabled rule returns intentional suppression without throwing, so the enclosing delivery/import/observation mutation and its existing audit commit while no notification occurrence, event, transport attempt, or `.notification` Activity item exists. Existing non-notification delivery/audit Activity remains authoritative.

`AppModel` exposes an optional last-successfully-loaded rule snapshot, a scoped alert-rules failure state, one in-flight update state, `loadAlertRules()`, and async `setAlertRule(_:enabled:)`. Settings reads Toggle values only from the successfully loaded/persisted snapshot; it does not optimistically change them. Load failure shows an actionable retry state instead of guessed defaults. Update failure retains the last authoritative value, exposes the failure/retry state, and does not leave a false saved indication. Disable the four controls while the single app-owned update is in flight. `AlertRuleStore` is invoked directly by the owner app through `DeliveryStore`; `AgentCommand`, its dispatcher, and the external bridge remain unchanged and cannot mutate alert rules.

**Data / security / privacy:** Rules are local preferences, not agent-provided data and not secrets. Every actual successful owner change is one app-owned transaction with exactly one global audit: actor `release-radar-owner`, no thread (`thread_id NULL`, `thread_attribution = none`), no project/entity scope (`project_id`, `entity_type`, and `entity_id` all NULL), and the bounded exact reason `Set global alert rule <persisted-kind> enabled|disabled`, where both substitutions come only from the closed enum and Boolean. A failed update or a no-op request creates no audit. Disabled rules must not leave occurrence activation, event, transport attempt, or raw notification content behind, and the global audit must not appear in any project-scoped Activity projection.

- [ ] **Step 1: Write RED storage, enforcement, and model tests.** In `StoreAcceptanceTests`, migrate a v8 fixture and assert the exact four v9 rows/defaults survive reopening; assert the table schema rejects an unknown kind and non-Boolean values; assert the authoritative loader rejects a missing/unknown/malformed set instead of filling it; and assert an actual change creates the one exact unscoped audit contract above while failed/no-op updates create none. In `NotificationAcceptanceTests`, cover all six event kinds and their exact rule mapping through their normal production triggers. For every disabled mapping, assert the underlying ticket/review/completion/import/goal observation plus its existing audit commits, while matching `notification_occurrences`, `notification_events`, dispatch attempts, and `.notification` Activity items remain absent; re-enable the rule and assert only the next real transition creates one event with the existing enabled-event fingerprint/deduplication behavior. In `AppRouteTests`, assert initial load uses the persisted values; successful Toggle changes survive a recreated model/store; a load failure shows retry with no guessed Toggle state; and a write failure retains the prior authoritative Toggle value, shows failure, and never reports it saved.

  Exercise paused/blocked state reciprocally for the same linked goal: blocked deactivates the paused occurrence before attempting the blocked enqueue; paused deactivates the blocked occurrence before attempting the paused enqueue; every other runtime state deactivates both. Prove `blocked -> paused -> blocked` creates the next blocked generation even when paused alerts are disabled, and with paused alerts enabled leaves only the current state active. Toggling a rule alone does not create, activate, deactivate, or replay occurrences.

- [ ] **Step 2: Run RED.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/NotificationAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests`

  Expected: FAIL because alert rules are static text, the store has no constrained v9 rule authority, `enqueue` always creates enabled-event records, and paused runtime state has no reciprocal occurrence lifecycle.

- [ ] **Step 3: Implement storage-first enforcement.** Add the constrained v9 migration/default rows, exact-kind loader, schema validation, and direct owner-only `AlertRuleStore` update/audit path without changing `AgentCommand` or its dispatcher. Add the exhaustive six-event mapping and check it at the start of `MeaningfulDeliveryEvent.enqueue`. Keep disabled suppression non-throwing so the surrounding authoritative mutation commits, but continue to surface actual store/schema errors rather than treating them as disabled. Add `goalPaused`, implement blocked/paused reciprocal deactivation before enqueue, and deactivate both occurrences for all other goal states; deactivation must run regardless of whether either rule is enabled.

  Load rules into `AppModel` as a scoped settings concern that cannot fail the rest of dashboard loading. Replace Settings labels with four accessible toggles with stable identifiers (`alert-blocked-goals`, `alert-agent-completion-review`, `alert-needs-review`, and `alert-paused-goals`), bind them only to the last successful persisted snapshot, serialize writes, and expose an actionable `alert-rules-failure`/`alert-rules-retry` state. Preserve the existing after-first-dashboard-open guard and paused-goal default-off behavior.

- [ ] **Step 4: Run GREEN and relaunch inspection.** Re-run focused tests. In an alternate-bundle isolated app session, verify all four accessibility identifiers expose their persisted enabled state, controls serialize updates, a successful toggle survives quit/relaunch, and a forced update failure leaves the displayed state unchanged with actionable recovery. Trigger a disabled fixture transition and verify the delivery change remains visible in its authoritative surface/ordinary audit while Notifications and notification Activity gain nothing; re-enable and verify only the next real occurrence is visible once. Do not launch the owner bundle or access the owner database.

**Failure behavior:** If rule storage cannot load, show actionable local-settings recovery and no guessed/interactive rule state; the rest of the dashboard remains usable. If an update fails, keep the last successfully loaded value visible, show retry, and create neither update audit nor notification-side mutation. Do not treat missing, extra, unknown, or malformed rows as disabled after a recognized migration; seed defaults only in the v9 migration. Intentional disabled-rule suppression is not an error and must not roll back the underlying delivery mutation.

**Activity / audit evidence:** Persist the exact bounded unscoped owner-settings audit above for each actual successful global rule change; do not invent a project scope or bridge request. Disabled triggers have no notification event/activity item by design, while their existing underlying delivery/audit evidence remains; the ledger records this as intentional suppression, not delivery failure.

**Acceptance criteria:** Toggles are interactive, accessible, authoritative, and persisted across relaunch; scoped failures never display a false setting or block the dashboard; the exact four-row schema/loader fails closed; all six meaningful event kinds have the explicit mapping above; disabled rules suppress before occurrence/event creation without rolling back delivery; only actual owner changes create the exact unscoped audit; no external/agent command can change a rule; enabled rules preserve fingerprint/deduplication/re-entry behavior; paused goals remain off by default; and blocked/paused transitions maintain reciprocal occurrence state.

**Required independent reviews:** Code Reviewer, QA persistence/UI verifier, Architect, Security/Privacy verifier, TPM, Delivery Manager.

**Progress-ledger evidence:** RR-R4 constrained migration/default/loader evidence; exhaustive six-event mapping and reciprocal blocked/paused proof; authoritative Toggle/relaunch/failure evidence; RED/GREEN results; suppressed-notification versus committed-delivery proof; exact global audit and unchanged agent bridge evidence; visual/accessibility capture; reviewer/security result; and RR-R5 release decision.

### Task 5: Match the selected-path Dependencies view and give the phase board an explicit density control

**Objective / user outcome:** Dependencies emphasizes only the selected ticket’s direct/indirect path in a readable left-to-right workspace with clear grouping, legend, blocking path, and inspector. The phase board offers an explicit density choice matching the approved Compact density language while retaining automatic compact-width safety.

**Controlling references:** `docs/design/mockups/dependencies.png`, `docs/design/mockups/phase_board.png`, and design spec “Phase board” acceptance criterion 3.

**In scope:** Deterministic selected-path layout/projection presentation, group headers/count/legend, selected/blocked visual states and inspector organization; a local view density selector (`Full outcomes`/`Compact density`) that cooperates with width-based compact cards; responsive tests and visual QA. **Out of scope:** graph mutation, a sixth lane, automatic delivery transitions, persistence of a new global preference, new card fields, or mockup-test infrastructure.

**Dependencies / release gate:** No technical dependency on RR-R1 through RR-R4; it is serialized after them by owner-priority sequencing. TPM/Delivery Manager release RR-R5 after design/QA confirm the visual acceptance checklist and target widths.

**Files:**

- Modify: `ReleaseRadar/Dependencies/DependencyGraphLayout.swift`
- Modify: `ReleaseRadar/Dependencies/DependencyGraphView.swift`
- Modify: `ReleaseRadar/Projects/PhaseBoardView.swift`
- Modify: `ReleaseRadar/Projects/TicketCardView.swift`
- Modify: `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/DashboardProjectionTests.swift`

**Interfaces:** Keep `DependencyGraphProjection` read-only. Make `DependencyGraphLayout.makeLayout(graph:size:)` lay out only selected direct/indirect predecessors and direct unlocks in stable columns, exposing column labels/frames as needed by the view. Add a view-local `BoardDensity` (`fullOutcomes`, `compact`) and calculate an effective presentation that uses compact whenever width cannot sustain full cards.

**Data / security / privacy:** Read-only projection/UI work; no SQLite schema, bridge, bookmark, credential, or lane mutation.

- [ ] **Step 1: Write RED layout tests.** In `ReviewAndGraphAcceptanceTests`, seed a selected ticket with direct/indirect prerequisites, an unrelated graph branch, blocked edge, and unlocks; assert stable column membership/order, no unrelated node/connector, and selected-path/blocked connector metadata. In `DashboardProjectionTests`, assert explicit compact selection hides outcomes while full selection shows them at adequate width and forced narrow width remains compact. The production changes these tests catch are unrelated graph branches leaking into the selected-path workspace and explicit density being ignored when width permits.

- [ ] **Step 2: Confirm the RED artifact assertion.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests -only-testing:ReleaseRadarTests/DashboardProjectionTests`

  Expected: FAIL because Dependencies currently lays out all phase nodes in a generic grid and Phase Board exposes only an automatic presentation badge.

- [ ] **Step 3: Implement the smallest responsive layout.** Render the dependency workspace like the reference: path count/legend above the graph, Foundations → accepted/predecessor work → Selected ticket → Unlocks-next columns, dashed column separators, directional arrow connectors, and a right inspector with direct/indirect/unlocks cards. Keep scrollable canvas bounds and accessible text equivalents. Replace the phase-board badge with an accessible menu/picker for Full outcomes and Compact density; selected density drives cards when width permits, while narrow widths force compact without clipping lane labels, counts, or signals.

- [ ] **Step 4: Run GREEN and visual comparison.** Re-run focused tests. Capture the selected-path Dependencies view and board at reference-like wide size and compact width, compare side-by-side with both approved PNGs, and check keyboard selection, VoiceOver labels, five lanes, long outcomes, and horizontal/vertical recovery when space is constrained.

**Failure behavior:** If a selected ticket has no usable path, retain the existing explicit unavailable/empty inspector state; never substitute unrelated graph nodes. At narrow widths cards collapse to IDs/counts rather than overlap or truncate actionable controls.

**Activity / audit evidence:** None—the controls are read-only presentation choices. Ledger visual evidence must distinguish approved design deviations, if any, from source-only checks.

**Acceptance criteria:** Dependencies visibly matches the selected-path hierarchy and inspector intent of `dependencies.png`; unrelated nodes are absent; blocked paths are distinguishable; Phase Board has clear density UX matching `phase_board.png`; full and compact remain responsive and accessible with all five lanes.

**Required independent reviews:** Code Reviewer, QA visual/responsive/accessibility verifier, Architect, TPM, Delivery Manager. Security review is not required unless implementation expands data access.

**Progress-ledger evidence:** RR-R5 RED/GREEN commands, exact capture dimensions and screenshots, design comparison/approved deviations, accessibility evidence, reviewer outcomes, and RR-R6 release decision.

### Task 6: Ship a deterministic production macOS AppIcon in the approved V1 direction

**Objective / user outcome:** Release Radar has a production AppIcon that carries the approved graphite-navy segmented-orbit/five-tile V1 direction and remains legible in Finder, Dock, and small system sizes.

**Controlling references:** `docs/brand/README.md`, `docs/brand/release-radar-icon-v1.png`, and the MVP plan’s product identity/signing constraints.

**In scope:** Deterministic recreation of the approved icon, complete macOS AppIcon representations, catalog metadata, target build setting, asset compilation, signed-app visual verification, and the smallest Debug-only capture isolation needed to prevent owner Pushover Keychain reads or pending-notification dispatch during live QA. **Out of scope:** changing the wordmark/lockup, replacing the approved direction, shipping the generated reference PNG, a new typeface, notarization/distribution, entitlement changes, production/default startup changes, Keychain/notification protocol refactors, or generalized capture infrastructure.

**Dependencies / release gate:** No technical dependency on RR-R1 through RR-R5; it is sequenced last to prioritize functional recovery. The V1 direction is already owner-approved in `docs/brand/README.md`; TPM/Delivery Manager may release RR-R6 after the preceding serialized writer finishes.

**Files:**

- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `docs/brand/release-radar-icon-v1.svg`
- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`
- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png`
- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-64.png`
- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png`
- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png`
- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png`
- Create: `ReleaseRadar/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Modify: `ReleaseRadar.xcodeproj/project.pbxproj`
- Modify: `ReleaseRadar/App/ReleaseRadarApp.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`

**Interfaces:** Set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` for Debug and Release app-target configurations. The catalog supplies macOS idiom/scale declarations matching Xcode’s required 16, 32, 64, 128, 256, 512, and 1024-pixel representations. Add one `AppLaunchConfiguration.externalServicesSuppressed(arguments:isDebugBuild:)` predicate that is true only for a Debug build containing `--rr10-capture`; use the same predicate for the existing AppDelegate capture guard and pass its result into `AppModel(externalServicesSuppressed:)`, defaulting to `false`. In `loadDashboard`, skip only `loadPushoverConfiguration()` and `notificationCoordinator.dispatchPending()` when true. Production, tests without explicit capture injection, and ordinary Debug launches retain existing behavior.

**Data / security / privacy:** Preserve sandbox, hardened runtime, signing identity, and every existing entitlement. Security re-review established that an alternate macOS application identifier does not isolate traditional Keychain items when the query omits a data-protection access group. Therefore live capture must prevent the Pushover lookup and pending dispatch by the narrow Debug-only predicate above; an alternate bundle identifier and empty isolated notification database remain additional owner-data boundaries, not the Keychain control.

- [ ] **Step 1: Record RED artifact and capture-isolation evidence.** Run a clean Debug build before catalog wiring and verify the built Info.plist/Resources contain no AppIcon metadata or compiled icon. In `AppRouteTests`, add one compact launch-policy matrix proving external services are suppressed for Debug + `--rr10-capture` only and false for normal Debug and all non-Debug arguments. Using the existing concrete notification coordinator and store fixtures, queue one notification, call `loadDashboard()` with suppression enabled, and assert its attempt state/count remain untouched; do not introduce a Keychain/coordinator protocol or spy solely for this task.

- [ ] **Step 2: Run RED.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/AppRouteTests && xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build`

  Expected: The new capture-policy/coordinator assertions fail because `AppModel` has no suppression input, and the build itself may succeed while Info.plist/Resources still fail the AppIcon assertion.

- [ ] **Step 3: Create/wire the asset and narrow Debug capture boundary.** Recreate the approved icon as deterministic SVG geometry (deep graphite-navy field; segmented orbit; five work tiles; indigo inactive tiles; one cyan tile with restrained violet-to-cyan scan), export the listed lossless PNG sizes with bundled/local rendering tools, author every required macOS 1x/2x entry in `Contents.json`, and set the two target configurations’ app-icon build setting. Add the single launch predicate/model Boolean above and guard only Pushover configuration loading plus pending dispatch. Do not copy `release-radar-icon-v1.png` into the catalog, alter Info.plist identity text, generalize collaborators, or suppress ordinary startup.

- [ ] **Step 4: Test, build, sign, and inspect.** Re-run `AppRouteTests` and the clean build. Verify the produced app has AppIcon metadata, use `assetutil --info` plus image dimensions to confirm every required macOS representation compiled, and run the repository's strict codesign command. Before live QA, use an alternate signed bundle and verify its isolated notification database has no pending events; launch with existing `--rr10-capture --rr10-empty-store`, confirm the Debug-only external-service suppression is active, and inspect Finder/Dock/About plus 16, 32, 64, 128, 256, 512, and 1024-pixel exports. Do not rely on the alternate application identifier as Keychain isolation.

**Failure behavior:** An incomplete/malformed catalog fails the build rather than silently falling back to a generic icon. If small-size legibility fails owner/design review, revise deterministic geometry before shipping; do not substitute the generated draft.

**Activity / audit evidence:** None. The ledger records asset source/provenance as deterministic recreation, the exact build/codesign result, and size/visual inspection against the approved direction.

**Acceptance criteria:** The signed app uses `AppIcon`; all required macOS sizes compile; Finder, Dock, and About present the approved V1 direction legibly; no generated draft is shipped; signing/entitlements remain unchanged; Debug capture alone suppresses Pushover configuration reads and pending dispatch; and every normal/production path preserves existing external-service behavior.

**Required independent reviews:** Code Reviewer, QA visual verifier against the already owner-approved V1 direction, Architect, Security/Privacy signing verifier, TPM, and Delivery Manager.

**Progress-ledger evidence:** RR-R6 status/gate, resource RED/GREEN/build and codesign outputs, asset size/provenance/visual evidence against the owner-approved direction, reviewer/security outcomes, residual distribution limitation, and milestone completion.

### Task 7A: Diagnose initialization persistence and make partial outcomes truthful

**Objective / user outcome:** Initialize Project Tracking saves one local,
resumable pending project and folder authorization without modifying repository
files. Pre-commit failures say nothing was saved. A recognized-seed failure
after the base commit says tracking was initialized but seed application is
incomplete. The reported SQLite authorization failure is changed only after
the exact statement and caller are reproduced in isolated current source.

**Dependencies / release gate:** Close or explicitly accept the remaining
Attach live-observation gap. Planning is complete; Architect and TPM are
Conditional GO. Fresh QA/test, Delivery Manager, and Security/Privacy plan
approval remain required before a writer is released. The first implementation
action is a hard reproduction gate: capture the exact SQL, caller, and SQLite
authorizer action/arguments for error 23. Non-reproduction is recorded only as
non-reproduction; it is not a bundle-mismatch claim without separate bundle
provenance. Do not relax the `audit_events` authorizer.

**Files:** Modify `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift` and
`ReleaseRadarTests/OnboardingAcceptanceTests.swift`. Modify the demonstrated
failing caller only if the reproduction identifies it. `SQLiteConnection.swift`
is not an anticipated edit.

**Interfaces and persistence:** Keep `prepare(_:) -> ProjectID`
source-compatible or add the smallest typed equivalent that distinguishes
`seedApplicationFailedAfterSave(ProjectID)` around only the second-transaction
`RekonArtifactImporter.apply` call. Base bookmark creation and the base
project/root/bookmark/exclusion/pending transaction retain atomic rollback and
their single prepare audit. Resume uses the persisted pending identity without
calling `prepare` again. Initialize creates no `onboarding_phase_request`, no
“Request agent-defined first phase” audit, no command request, and no
notification.

- [ ] **Step 1: Reproduce before changing policy.** In a temporary store and
  disposable `release_radar` folder, exercise fresh, pending, pending-with-
  phase-request, and pending-with-project-scoped-audit states. Capture the
  exact SQL/caller and authorizer arguments when `SQLITE_AUTH` occurs. If
  current source does not reproduce, record that and make no store-policy
  change.
- [ ] **Step 2: Write RED acceptance tests.** Prove initialization creates one
  project, root, non-stale bookmark, pending marker, and prepare audit; creates
  zero phase-request markers/audits, phases, command requests, and
  notifications; preserves a repository sentinel/listing; and resumes after
  relaunch. Force recognized-seed revalidation failure after the base commit
  and require typed saved-incomplete state with zero partial imported rows or
  importer audit. Prove a pre-commit failure leaves all relevant counts
  unchanged. Add the exact SQLite regression only if Step 1 reproduces it.
- [ ] **Step 3: Run RED.** Run all `OnboardingAcceptanceTests` in a fresh
  DerivedData path and retain the failures for the new contracts.
- [ ] **Step 4: Implement the minimum service correction.** Add only the typed
  post-base failure boundary and any statement-specific caller correction
  proven by Step 1. Do not change Attach, schema, importer scope, historical
  markers, or transaction-authorizer policy.
- [ ] **Step 5: Run GREEN and immediate integration.** Re-run all
  `OnboardingAcceptanceTests`; run `StoreAcceptanceTests` only if a separately
  approved store-boundary change became necessary.

**Acceptance / evidence:** Nothing-saved versus saved-incomplete is
deterministic; pending authorization and the prepare audit survive relaunch;
repository contents are unchanged; no automatic agent/request side effect
exists; the exact error-23 reproduction or non-reproduction is recorded; and
Attach persistence tests remain green. Record commands, row/audit deltas,
sentinel proof, bundle provenance if known, and independent review decisions
in the progress ledger.

### Task 7B: Present Initialize Project Tracking and the copyable Codex handoff

**Objective / user outcome:** Add Project first offers **Initialize Project
Tracking** and **Attach Folder to Existing Project**. Initialize has an explicit
preview/confirmation boundary, truthful saved/waiting/resume behavior, the
approved Codex prompt, and an accessible copy button. Portable Import and Help
are absent.

**Dependencies / release gate:** Task 7A must be accepted. A fresh sole writer
is released only after Architect, TPM, QA/test, Delivery Manager, and
Security/Privacy approve this brief.

**Files:** Modify `ReleaseRadar/Projects/OnboardingView.swift` and the
superseded owner-facing first-phase copy in
`ReleaseRadar/Shared/FailureStateView.swift`; test in
`ReleaseRadarTests/AppRouteTests.swift` and the immediate onboarding integration
tests. Do not change
`associateFirstProjectRoot`, Attach callbacks, schema, importer, or bridge.

**UI and clipboard contract:** Use a small local landing/initialize/attach
state. Folder selection remains preview-only. Confirmation names the project
and folder and says local initialization does not modify repository files.
After save, show the exact prompt above and explain that the owner must paste it
into a Codex task rooted at the folder. The icon-only `square.on.square` control
has accessibility label **Copy Codex prompt** and stable identifier
`onboarding-copy-codex-prompt`. Copy only the exact prompt—never the path,
bookmark, project contents, or secrets—and disclose that it remains on the
clipboard until replaced. Show and announce **Codex prompt copied** only after
a successful write; show and announce failure otherwise. No automatic launch,
paste, submission, bridge request, audit, or notification occurs.

**Clipboard test seam:** Keep one small local prompt-handoff value/result in
`OnboardingView.swift` and inject only a `(String) -> Bool` pasteboard writer,
defaulting to `NSPasteboard.general`. The production view and tests use the
same exact immutable prompt constant. A success test binds the writer to an
`NSPasteboard(name:)` value unique to that test and reads the string back; a
failure test injects a writer returning `false`. The returned presentation
state supplies the visible/accessibility success or failure announcement and
clears any stale prior result before each attempt. This is a local test seam,
not a clipboard framework, global service, or new dependency.

- [ ] **Step 1: Write RED presentation, persistence, and clipboard tests.** In
  `AppRouteTests`, require the landing to expose exactly **Initialize Project
  Tracking** and **Attach Folder to Existing Project**, with Import Existing
  Project and Help absent; require confirmation to name the project and folder
  and say local initialization does not modify repository files; require the
  exact design prompt byte-for-byte on a uniquely named pasteboard; require
  visible/accessibility **Codex prompt copied** only after successful writing;
  and force failed writing to expose/announce failure with no success state.
  In onboarding acceptance coverage, prove preview and pre-confirmation
  cancellation paths leave project/root/bookmark/review-marker/audit counts and
  the repository sentinel unchanged; normal saved state and
  `seedApplicationFailedAfterSave` both resume the same pending identity and
  handoff without a duplicate prepare or partial import; **Check Tracking
  Status** creates no request/audit; **Finish Initialization** remains disabled
  until the persisted phase check succeeds and then completes through the
  existing `finish` recheck. Keep all Attach persistence/rollback regressions
  green. Actual Back/Cancel/Escape/red-close interaction remains part of the
  isolated live acceptance matrix because no UI-test target is authorized.
- [ ] **Step 2: Run RED.** Run `OnboardingAcceptanceTests` and `AppRouteTests`
  in a fresh DerivedData path.
- [ ] **Step 3: Implement the minimum UI state and copy affordance.** Replace
  owner-facing “first phase” and false “Ask agent” language with **Initialize
  Project Tracking**, **Check Tracking Status**, and **Finish Initialization**.
  Preserve internal phase gating and Attach transaction/recovery semantics.
- [ ] **Step 4: Run GREEN, full suite, and configured build.** Re-run the two
  focused suites, then the current full suite and a clean build. Do not add a
  UI-test target or clipboard framework.
- [ ] **Step 5: Verify the isolated running app.** With a new alternate Debug
  bundle/container and disposable folder, inspect accessibility and screenshots
  at approximately 760×520, 900×650, and wide. Verify landing hierarchy,
  Back/Cancel/Escape/red-close no-write behavior, confirmation, saved/resumed
  state, exact clipboard contents/disclosure/announcement, no raw SQLite or
  automatic submission, unchanged repository contents, and unchanged Attach
  behavior. Record any Computer Use limitation rather than inferring success.

**Acceptance / evidence:** The two workflows are explicit; initialization's
durable boundary and recovery state are truthful; the copy affordance is
icon-only, accessible, exact, confirmed, path-free, and local; completion still
requires persisted tracking state; Attach remains unchanged; and the focused,
full, build, responsive, accessibility, persistence, audit, and privacy checks
are recorded in the existing progress ledger.

**Required independent post-implementation reviews:** Code Reviewer, QA/test,
Architect, Security/Privacy, TPM, and Delivery Manager. The Implementer may not
perform or substitute for any of these roles, and Task 7B is not accepted until
all six decisions and their evidence are durable in the existing progress
ledger.

### Task 7: Keep empty workspaces usable and hand off the verified Release app

**Objective / user outcome:** Opening Release Radar with no real projects keeps the owner on the usable Projects/onboarding surface. The sidebar does not offer fabricated project routes, selecting or programmatically requesting a nonexistent project cannot create an audit or surface `SQLite error 19: FOREIGN KEY constraint failed`, and the verified combined remediation is handed off as a Release-configuration app at `/Applications/ReleaseRadar.app` rather than as a Debug or temporary QA artifact.

**Controlling references:** Design spec “Onboarding”, “Dashboard model”, and “Failure behavior”; ADR-001 app-only database authority, signing, and local Application Support boundary; `docs/design/mockups/onboarding_state.png`, whose project-specific sidebar group is conditional on a real project and whose failure language forbids silent recovery; accepted RR-R1–RR-R6 remediation in this plan.

**In scope:** Guarding project-scoped `AppRoute` navigation against the projects in the successfully loaded `DashboardProjection`; rendering the current-project sidebar heading/routes only when `AppModel.currentProject` exists; preserving the Projects/onboarding surface for an empty store; one lowest-layer app-model regression; a clean Release build; strict signature, identity, entitlement, icon, and configuration inspection; and a single stable local handoff copy. **Out of scope:** schema or data migration, repairing or reading owner database contents, changing `MeaningfulDeliveryEventRecorder` transaction semantics, deleting the Desktop QA app, renaming product/bundle identity, adding a UI-test target or packaging script, installing for another user, notarization, Developer ID distribution, App Store packaging, auto-update, or unrelated navigation refactoring.

**Dependencies / release gate:** RR-R1–RR-R6 implementation and their targeted/full verification are accepted in the current combined working tree. Planning, Architect, TPM, QA, and Delivery Manager must independently approve this brief; TPM and Delivery Manager may then release RR-R7 as the only writer. The handoff build is eligible only after the focused regression is GREEN, independent code/QA review accepts the source change, and the normal Release configuration builds cleanly.

**Affected subsystem and files:**

- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadar/Navigation/SidebarView.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`
- Generate/handoff, do not commit: `/Applications/ReleaseRadar.app`

**Interfaces:** Keep `AppRoute`, `DashboardProjection`, and `MeaningfulDeliveryEventRecorder.markDashboardOpened(projectID:)` unchanged. In `AppModel.navigate(to:)`, when `route.projectID` is non-nil, first require an exact ID match in `dashboard?.projects`; if absent, set `selection = .projects` and return before calling `markDashboardOpened`. Do not set `dashboardError` for that rejected local route and do not synthesize `DashboardSampleData.projectID`. `SidebarView` renders the divider, current-project label, and `AppRoute.projectRoutes(for:)` group only inside `if let currentProject = model.currentProject`; the primary Projects, Needs Review, Notifications, and Settings routes remain present. `currentProjectID` remains source-compatible for existing project-backed consumers; this task does not generalize it to an optional or rewrite downstream views.

**Data, security, and privacy:** The rejected route is read-only and produces no audit because no consequential project dashboard was opened. A valid real-project route retains the existing single owner audit and first-dashboard-open behavior. Tests and live empty-state QA use temporary/isolated databases only. Do not inspect, reset, delete, migrate manually, or write the owner's Application Support database. Preserve bundle identifier `com.rekonlabs.ReleaseRadar`, App Sandbox, Hardened Runtime, signing identity, entitlements, Keychain behavior, and the RR-R6 Debug-only capture boundary. Both the staged and installed Release artifacts must omit the Debug-only effective entitlement `com.apple.security.get-task-allow`. The Release artifact is Apple Development-signed for this Mac; no notarization or broader distribution claim is permitted.

**Test fixture and strategy:** Use the existing `AppRouteTests` temporary-directory/`DeliveryStore` pattern; no new harness. Construct the empty-store model exactly as `AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)`. After `loadDashboard()`, assert zero projected projects and `currentProject == nil`, capture `SELECT COUNT(*) FROM audit_events`, call `navigate(to: .projectOverview(DashboardSampleData.projectID))`, then assert `selection == .projects`, `dashboardError == nil`, and the audit count is unchanged. This reproduces the exact old failure because the pre-fix code attempts an audit whose `project_id` foreign key does not exist. Strengthen the existing happy-path `testDirectProjectRoutePersistsDashboardOpenBeforeNotificationEligibility` by constructing its model with `externalServicesSuppressed: true`, calling `loadDashboard()` before navigation, and asserting exactly one audit matching actor `release-radar-owner`, reason `Open project dashboard`, and project `project-direct`, while preserving its existing first-dashboard-open and notification assertions.

- [ ] **Step 1: Write the focused RED regression and deterministic happy-path control.** Add `testEmptyDashboardRejectsFabricatedProjectNavigationWithoutAuditOrGlobalError()` to `ReleaseRadarTests/AppRouteTests.swift` with `AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)` and the exact assertions above. Do not seed a project and do not weaken SQLite foreign keys. In existing `testDirectProjectRoutePersistsDashboardOpenBeforeNotificationEligibility`, set `externalServicesSuppressed: true`, call `loadDashboard()` before `navigate(to:)`, and add the exact-one owner/dashboard-open audit assertion without removing its first-open, notification-event, or selected-route assertions.

- [ ] **Step 2: Run RED and retain the failure evidence.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/ReleaseRadar-RR7-Tests -only-testing:ReleaseRadarTests/AppRouteTests/testEmptyDashboardRejectsFabricatedProjectNavigationWithoutAuditOrGlobalError`

  Expected before implementation: FAIL because navigation attempts `Open project dashboard` against nonexistent `DashboardSampleData.projectID`, leaves the route unusable, and surfaces SQLite foreign-key error 19.

- [ ] **Step 3: Implement the minimum route and sidebar guards.** Add the exact loaded-project membership check at the start of `AppModel.navigate(to:)`. Wrap only the current-project divider/heading/project-route group in `SidebarView` with the existing `currentProject` projection. Do not change database code, event recorder behavior, route enums, onboarding semantics, or unrelated error presentation.

- [ ] **Step 4: Run GREEN and the immediate integration tests.** Re-run the exact focused test, then all `AppRouteTests`. Verify the new regression passes and the strengthened direct-route control loads the real project, records exactly one `release-radar-owner` / `Open project dashboard` audit, sets `first_dashboard_opened = 1`, creates the existing eligible notification, and selects the requested phase board.

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/ReleaseRadar-RR7-Tests -only-testing:ReleaseRadarTests/AppRouteTests`

- [ ] **Step 5: Verify the running empty state against the mockup.** Build and launch the existing alternate Debug capture with `--rr10-capture --rr10-empty-store` and an isolated container. Through Computer Use, confirm the accessibility state and screenshot show the Projects/onboarding surface, no current-project heading or Overview/Phase Board/Dependencies/Activity group, and no `failure-delivery-data`/SQLite error after primary-route use and window resizing. Compare directly with `onboarding_state.png`; do not mutate or delete owner or prior QA data.

- [ ] **Step 6: Build and hand off the proper Release artifact.** Build from the fresh DerivedData directory below and treat only `/tmp/ReleaseRadar-RR7-Release/Build/Products/Release/ReleaseRadar.app` as the staging source; do not select another DerivedData, Desktop, Debug, or previously built app. Verify that exact staging bundle first with `codesign --verify --deep --strict --verbose=2`, `codesign -d --entitlements :-`, and Info.plist inspection. Require product `ReleaseRadar.app`, bundle identifier `com.rekonlabs.ReleaseRadar`, AppIcon metadata, App Sandbox/Hardened Runtime/signing preserved, no `.RR6QA`/Debug identity, and no effective `com.apple.security.get-task-allow` entitlement. Only after those checks pass, copy that exact staging bundle to `/Applications/ReleaseRadar.app`. Before replacement, resolve that exact destination; do not delete or alter any other app copy. Repeat the same strict signature, effective-entitlement, and Info.plist checks against the installed `/Applications/ReleaseRadar.app`, including omission of `com.apple.security.get-task-allow`. Do not launch the Release artifact against owner data merely to manufacture QA evidence; report its exact clickable path and that it is a local Apple Development build, not notarized for third-party distribution.

  Build: `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Release -derivedDataPath /tmp/ReleaseRadar-RR7-Release build`

**Happy path:** With a real projected project, its project routes render and selection still calls the existing recorder before navigation. With no projects, Projects/onboarding remains interactive and project-scoped routes are absent. The final app is the Release configuration at the one documented handoff path.

**Failure behavior:** A stale or programmatic project route that is absent from the loaded dashboard falls back to Projects without a database write or global data-unavailable error. A genuine recorder/database error for a valid project still uses the existing truthful `dashboardError` surface. Any Release build, signature, entitlement, identity, or icon check failure blocks handoff and leaves the last known artifact untouched; it must not be relabeled as a Release deliverable.

**Activity / audit evidence:** Rejected nonexistent routes create zero audit rows and zero notification events. Valid real-project navigation preserves the existing `release-radar-owner` / `Open project dashboard` audit. Building/copying the app creates no delivery audit; the progress ledger records build and handoff evidence.

**Acceptance criteria:** The exact empty-store regression is GREEN with external services deterministically suppressed; no fabricated project group appears in live empty-state accessibility/screenshot evidence; no foreign-key/global delivery-data error is produced by nonexistent navigation; loaded valid-project navigation records exactly one owner/dashboard-open audit while preserving first-open and notification behavior; focused tests and the current full suite pass; both exact staging `/tmp/ReleaseRadar-RR7-Release/Build/Products/Release/ReleaseRadar.app` and installed `/Applications/ReleaseRadar.app` pass strict verification with the production bundle identity/icon, preserved Release entitlements, and no effective `com.apple.security.get-task-allow`; the user is not directed to a Desktop QA or DerivedData Debug app.

**Required independent reviews:** Code Reviewer for the bounded source/test diff; QA for RED/GREEN plus live accessibility/screenshot and handoff-bundle checks; Architect for unchanged persistence/route boundaries; TPM and Delivery Manager for dependency/scope gate and ledger closure. Security/Privacy independently verifies the final signing/entitlement/bundle boundary because the deliverable is an owner-facing signed app; no broader security scan is required.

**Progress-ledger evidence:** RR-R7 gate and role decisions; exact RED/GREEN commands/results; rejected-route before/after audit counts and valid-route exact-one owner audit; isolated live empty-state accessibility/screenshot evidence against `onboarding_state.png`; full-suite result; Release build command/result; exact staging and installed absolute paths; bundle ID, configuration, icon, strict codesign, effective entitlements including absent `com.apple.security.get-task-allow`, and Hardened Runtime evidence for both artifacts; explicit non-notarization limitation; reviewer outcomes; and closure with no next remediation task opened implicitly.

## Plan self-review

- **Coverage:** RR-R1 addresses add/cancel/reset/existing active folder; RR-R2 folder recovery and fail-closed review decisions; RR-R3 specific ticket-goal identity plus authoritative outcome/TLDR updates; RR-R4 persisted event-suppressing alert rules; RR-R5 selected-path Dependencies and Phase Board density; RR-R6 the production AppIcon; Tasks 7A/7B resolve structure-less initialization with statement-specific persistence diagnosis and a truthful copyable Codex handoff; RR-R7 retains empty-workspace route safety and the owner-usable Release handoff.
- **Compatibility:** The only schema changes are additive v8 (ticket-goal links) and v9 (alert rules). Existing ticket outcome storage, thread links, notification fingerprint semantics for enabled rules, five-lane state, and sandbox/signing boundaries remain intact.
- **Verification:** Every behavior task begins with focused RED tests, runs the same focused tests GREEN, and uses repository-native Xcode commands. UI work additionally requires running-app visual/accessibility comparison; no custom harness or unrelated suite is introduced.

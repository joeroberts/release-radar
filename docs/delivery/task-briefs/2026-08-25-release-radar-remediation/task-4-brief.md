### Task 4: Make alert rules persisted controls that suppress event creation

**Objective / user outcome:** Settings contains real alert toggles. Their values survive relaunch, and turning a rule off prevents the corresponding notification event from being created—not merely sent—while other rules and dashboard use continue to work.

**Controlling references:** `docs/design/agent-driven-delivery-dashboard-design.md` “Notification policy”; `docs/architecture/ADR-001-release-radar-boundaries.md` Keychain/app-owned notification boundary; `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` Task 4.

**In scope:** Four persisted owner-facing rule groups matching Settings: blocked linked goals; agent completion and review requests; Needs Review entry; and paused goals. The first three default on and paused goals default off. Settings bindings, authoritative event-creation guards, the paused/blocked occurrence lifecycle, and scoped load/update failure and relaunch behavior are included. **Out of scope:** Pushover credential changes, scheduled notifications, per-device sync, new provider behavior, changing fingerprints for already-supported enabled events, retroactively creating events after a rule is enabled, or adding any `AgentCommand`/external-agent mutation for owner alert settings.

**Dependencies / release gate:** RR-R3 accepted. TPM/Delivery Manager release RR-R4 only after Architect, QA, and Security/Privacy accept this corrected brief. Work remains serialized with other writers.

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

**Interfaces:** Add a four-case, closed `AlertRuleKind` with exact raw values `blockedLinkedGoals = "blocked_linked_goals"`, `agentCompletionAndReview = "agent_completion_and_review"`, `needsReviewEntry = "needs_review_entry"`, and `pausedGoals = "paused_goals"`. Back it with an `AlertRuleStore` and additive v9 table whose authoritative shape is `alert_rules(kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('blocked_linked_goals', 'agent_completion_and_review', 'needs_review_entry', 'paused_goals')), is_enabled INTEGER NOT NULL CHECK (is_enabled IN (0, 1)))`; extend current-schema validation to recognize those constraints. The authoritative loader returns a snapshot only for the exact four-kind set once each with valid Boolean values and rejects missing, unknown, duplicate, or invalid values rather than synthesizing defaults outside migration. Migration seeds exactly `[blockedLinkedGoals: true, agentCompletionAndReview: true, needsReviewEntry: true, pausedGoals: false]` transactionally.

The event mapping is exhaustive over all six `MeaningfulDeliveryEventKind` cases:

- `goalBlocked -> blockedLinkedGoals`
- `agentCompleted -> agentCompletionAndReview`
- `reviewRequested -> agentCompletionAndReview`
- `ticketNeedsReview -> needsReviewEntry`
- `importNeedsReview -> needsReviewEntry`
- `goalPaused -> pausedGoals`

The mapping has no fallback/default branch. `MeaningfulDeliveryEvent.enqueue` checks the mapped rule before occurrence/event writes. Disabled returns intentional suppression without throwing: the enclosing delivery/import/observation mutation and its existing audit commit, while no notification occurrence, event, transport attempt, or `.notification` Activity item exists. Existing non-notification delivery/audit Activity remains authoritative.

`AppModel` exposes an optional last-successfully-loaded rule snapshot, a scoped alert-rules failure state, one in-flight update state, `loadAlertRules()`, and async `setAlertRule(_:enabled:)`. Settings reads Toggle values only from the authoritative snapshot and never optimistically changes them. Load failure shows retry instead of guessed defaults. Update failure retains the prior authoritative value and reports failure, never saved. All controls are disabled while the one app-owned update is in flight. `AlertRuleStore` uses `DeliveryStore` directly from the owner app; `AgentCommand`, `AgentCommandDispatcher`, and the external bridge stay unchanged.

**Data / security / privacy:** Rules are local, non-secret owner preferences. Every actual successful change creates exactly one audit with actor `release-radar-owner`, `thread_id NULL`, `thread_attribution = none`, `project_id/entity_type/entity_id NULL`, and exact bounded reason `Set global alert rule <persisted-kind> enabled|disabled`, with substitutions from only the closed enum and Boolean. Failed and no-op updates create no audit. The unscoped audit never appears in project Activity. Disabled rules persist no occurrence activation, event, dispatch attempt, or notification copy.

- [ ] **Step 1: Write RED storage, enforcement, and model tests.** In `StoreAcceptanceTests`, migrate v8 to v9 and assert the exact four rows/defaults survive reopen; unknown kinds and non-Boolean values violate schema; the loader rejects missing/unknown/malformed sets; an actual update has the exact audit contract; failed/no-op updates have none. In `NotificationAcceptanceTests`, trigger all six event kinds through their production paths and prove the mapping above. With each rule disabled, assert the underlying ticket/review/completion/import/goal observation and existing audit commit while occurrence/event/attempt and `.notification` Activity rows remain absent; after re-enable, only the next real transition creates one event with unchanged fingerprint and deduplication semantics. In `AppRouteTests`, assert persisted initial load and relaunch, load-failure retry with no guessed state, and update failure retaining the prior value without a saved indication.

  For one exact linked goal, assert blocked deactivates paused before blocked enqueue, paused deactivates blocked before paused enqueue, and every other runtime state deactivates both. Prove `blocked -> paused -> blocked` advances the blocked generation even when paused alerts are disabled; when paused alerts are enabled, only the current status occurrence is active. A settings Toggle alone never creates, activates, deactivates, or replays an occurrence.

- [ ] **Step 2: Run RED.**

  Run: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/NotificationAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests`

  Expected: FAIL because Settings is static, v9 authority does not exist, enqueue always writes for enabled event types, and paused has no reciprocal occurrence lifecycle.

- [ ] **Step 3: Implement the smallest complete contract.** Add the constrained migration, exact loader, direct owner update/audit, and exhaustive event mapping. Guard enqueue before notification writes but keep disabled suppression non-throwing. Add `goalPaused` plus unconditional reciprocal deactivation. Load alert settings independently of dashboard success; bind four accessible Toggles to authoritative persisted state with stable IDs `alert-blocked-goals`, `alert-agent-completion-review`, `alert-needs-review`, and `alert-paused-goals`; serialize writes; and expose `alert-rules-failure` plus `alert-rules-retry`. Do not modify `AgentCommand` or its dispatcher.

- [ ] **Step 4: Run GREEN and isolated runtime acceptance.** Re-run the focused tests. Build an alternate-bundle isolated app, verify all four accessibility states, successful toggle persistence over relaunch, in-flight serialization, and update-failure recovery without UI drift. Trigger a disabled transition and verify its underlying authoritative state/audit commits while Notifications and notification Activity remain unchanged; re-enable and verify only the next transition creates one event. Do not launch the owner bundle or access owner data.

**Failure behavior:** Load failure shows actionable local-settings recovery and no guessed/interactive state while the rest of the dashboard stays usable. Update failure preserves the last successful snapshot and creates no update audit. Missing/extra/unknown/malformed rows are never interpreted as disabled. Disabled suppression is intentional and never rolls back the enclosing delivery mutation.

**Activity / audit evidence:** Actual owner changes create the exact unscoped audit above. Disabled triggers create no notification Activity, but their ordinary delivery/audit evidence remains. No project scope or bridge request is invented.

**Acceptance criteria:** Four accessible Toggles persist and remain authoritative; scoped failures do not lie or block the dashboard; schema/loader requires the exact four rows; all six event cases map explicitly; suppression precedes notification writes without rolling back delivery; only actual owner changes produce the exact global audit; no agent API can change a rule; enabled fingerprints/deduplication remain stable; paused defaults off; and blocked/paused occurrences are reciprocal.

**Required independent reviews:** Code Reviewer, QA persistence/UI verifier, Architect, Security/Privacy verifier, TPM, Delivery Manager.

**Progress-ledger evidence:** Constrained v9 schema/default/loader result; six-event mapping; reciprocal transition result; authoritative UI/relaunch/failure capture; RED/GREEN command results; suppressed-notification/committed-delivery proof; exact audit and unchanged bridge proof; reviewers/security decision; RR-R5 release decision.

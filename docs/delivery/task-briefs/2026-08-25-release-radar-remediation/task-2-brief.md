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


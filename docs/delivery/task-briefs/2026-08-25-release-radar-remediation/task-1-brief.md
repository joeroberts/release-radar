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

### Gated product decision: complete onboarding when no usable structure exists

**Verified conflict:** Release Radar itself has no pre-existing supported dashboard JSON, and the current “Ask agent to define first phase” action only persists a request marker; the accepted live-Codex feasibility result provides no supported outbound agent invocation. The controlling design simultaneously forbids the app from inventing a default phase, exposing owner phase editing, parsing Markdown as canonical state, or creating a repository-backed dashboard manifest.

**Gate:** Do not hide this conflict behind a fabricated phase or a new repository authority. Completing a structure-less repository requires a later explicit owner choice and matching design/ADR approval: either authorize a supported outbound agent-request integration, or authorize a narrowly defined owner-created first phase. This decision is independent of RR-R1 cancellation/open-existing and RR-R2 through RR-R6, so it does not block their implementation.

**Evidence:** Record the live failure, absence of `docs/delivery/dashboard-status.json`, request-marker-only source path, accepted Codex-unavailable result, and the four prohibited alternatives in `docs/delivery/progress.md`.


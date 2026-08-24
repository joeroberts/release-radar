# Release Radar delivery ledger

## Goal

Deliver the signed native macOS MVP described by
`docs/superpowers/plans/2026-08-23-release-radar-mvp.md` on
`codex/release-radar-mvp`, with serialized subagent writes and no pull request.

## Preimplementation gates

| Role | Status | Required findings incorporated |
| --- | --- | --- |
| Planning | Complete | RR-01 through RR-10 task decomposition and dependencies. |
| Architect | Approved with corrections | Standalone boundary, five lanes, live-Codex feasibility, app-only SQLite authority, sandbox/signing, observer/bridge separation. |
| TPM | Conditional GO satisfied by plan revision | Early persisted board, bounded Codex gate, proportional evidence, autonomous dependency-safe sequence. |
| QA | Approved with acceptance evidence | Five focused service fixtures and one seeded wide/narrow UI flow; no bespoke harness. |
| Delivery Manager | GO | GitHub origin, source-of-truth reconciliation, per-slice ledger updates, and degraded continuation verified. |
| Security/privacy | Conditional pass incorporated | Migration recovery, authenticated IPC, bookmark scope, supported Codex observation, device-only Keychain, minimal Pushover data, atomic outbox. |

## Repository

- Local: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
- Remote: `https://github.com/joeroberts/release-radar`
- Branch: `codex/release-radar-mvp`
- Pull requests: prohibited by owner direction for this goal.

## Current gate

- Current task: RR-02 implemented; independent code, QA, architecture, and security/privacy reviews pending.
- Next eligible task: None until RR-02 review gates accept the slice and TPM/Delivery Manager record release.
- Open product blockers: none.
- Open operational risks: none.

## Task ledger

Each task entry records status, verification, reviews with Required/Optional/Out-of-scope classification, decisions, risks, stop-rule events, commit SHA, and the next eligible task before release.

### RR-01 — Standalone signed application foundation

- Status: Accepted.
- Commits: `487647a` scaffold, `50dab32` evidence, `ca09ba8` focused-test fix, `c3e5f79` fix evidence.
- Verification: normal configured Debug signing build passed; `build_and_run.sh --verify` launched the app; build-for-testing and strict codesign verification passed; focused `AppRouteTests` completed with 2 passed, 0 failed/skipped.
- Code review: Approved; Required 0, Optional 0, Out of scope 0.
- QA: Initial Required finding — main scheme prepared the empty UI runner and the focused unit test never completed. Addressed by keeping the UI target buildable while limiting the current TestAction to unit tests; scoped re-review accepted with no new Critical/Important breakage.
- Architecture: Approved; standalone namespace, target boundaries, synchronized roots, sandbox/hardened signing, scenes, and ADR are structurally suitable for successors.
- Stop-rule event: first implementer attempt produced no files within the foundation timebox and was interrupted; a fresh bounded implementer completed the slice without expanding scope.
- Decisions/risks: UI acceptance execution remains assigned to the later seeded UI slice; no product risk in RR-01.
- Next eligible task: RR-02 transactional local delivery store.

### RR-02 release gate

- TPM: GO; RR-01 technically accepted and RR-02 dependency-safe.
- Delivery Manager: GO; no remaining Required blocker.

### RR-02 — Transactional local delivery store

- Status: Implemented; independent reviews pending. Not accepted or released.
- Scope: Stable typed delivery records; app-owned SQLite connection and actor; versioned transactional migration; distinct delivery/runtime/audit/notification tables; attributed audit writes; read-only projections; foreign-key, uniqueness, project-boundary, and recursive phase/ticket acyclicity enforcement; explicit corruption/migration recovery state with an intact original and pre-migration snapshot.
- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`), `ad6a446` (`fix: reject transaction control in store reads`), `f5a06cf` (`fix: restrict store reads to observational SQL`).
- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, denial and rollback of callback mutations to `audit_events`, rejection of read-callback transaction control, and rejection of read-callback `PRAGMA foreign_keys=OFF` while preserving foreign-key enforcement and later valid audited writes. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 15 of 15 with 0 failures/skips; `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed; `git diff --check` passed.
- Reviews: Fix round 1 addressed the original two Required findings. Fix round 2 addressed transaction-control SQL through a read callback, but independent review found one remaining Required product-integrity defect: SQLite classifies state-setting PRAGMAs as read-only, allowing a read callback to poison the shared connection. Recovery implementation is complete; fresh Code Reviewer, QA, Architect, and Security/privacy re-review remain pending.
- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; transaction callbacks deny transaction control and cannot access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read callbacks now use a strict SQLite authorizer allowlist limited to SELECT, READ, and FUNCTION actions, denying PRAGMA and every connection/schema/transaction/mutation action by default; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
- Risks: Review gates remain open. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
- Stop-rule events: The original read-boundary remediation stopped after two rounds when review found that the denylist still admitted SQLite connection-state mutation. A fresh recovery implementer preserved the existing lease, audit, and transaction protections and replaced only the read authorizer policy with the smaller fail-closed observational allowlist.
- Next eligible task: None until independent RR-02 reviews are recorded and TPM/Delivery Manager release the next dependency-safe task.

### RR-01 — Standalone signed application foundation

- Status: Implemented; QA HOLD round 1 addressed and independent re-review pending.
- Scope: Standalone Xcode project with app, core framework, agent-tool executable, unit-test, and UI-test targets; signed SwiftUI shell; canonical local run action; ADR-001.
- Preimplementation gates: Planning complete; Architect approved with corrections; TPM conditional GO satisfied; QA approved with acceptance evidence; Delivery Manager GO; Security/privacy conditional pass incorporated. See the table above for the findings carried into the implementation.
- Decisions: `com.rekonlabs.ReleaseRadar`, macOS 14.0, filesystem-synchronized source roots, five persisted lanes, app-only database authority, separate observer and typed bridge, App Sandbox and Hardened Runtime.
- Signing identity: `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`; certificate team `2UA854NLX4`.
- Verification: `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` passed; `./script/build_and_run.sh --verify` passed and found PID 10510; `xcodebuild build-for-testing -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed; `codesign --verify --deep --strict` passed; app entitlements contain App Sandbox and the signature contains Hardened Runtime. After QA fix round 1, the exact focused test command completed with `** TEST SUCCEEDED **`.
- Tests: `ReleaseRadarTests/AppRouteTests.swift` covers primary/per-project route labels and SF Symbols. `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug -only-testing:ReleaseRadarTests/AppRouteTests` passed 2 of 2 tests with 0 failures and 0 skips. Result bundle: `Test-ReleaseRadar-2026.08.23_22-35-39--0400.xcresult`.
- Reviews: QA HOLD round 1 found that the focused unit-test invocation did not complete. The main scheme now excludes the still-buildable UI-test target from its TestAction, and Debug code coverage is disabled because process sampling identified post-test runtime-profile collection through a paired-device service as the remaining hang. Fix commit: `ca09ba8`. Independent Code Reviewer, QA, and Architect rechecks remain required before RR-01 acceptance.
- Risks: No app icon yet (foundation only). Runtime integrations and persistence intentionally remain for later tasks.
- Stop-rule events: Initial hosted XCTest execution was stopped rather than expanding test infrastructure; QA fix round 1 resolved the hang without a new harness.
- Commit: `487647a` (`feat: scaffold Release Radar macOS app`).
- Next eligible task: None until independent RR-01 review gates accept this slice.

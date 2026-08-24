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

- Current task: RR-04 onboarding and first-phase creation is implemented; fresh independent code, QA, architecture, and security/privacy review remains required.
- Next eligible task: RR-04 independent review only. RR-06 remains closed until RR-04 is accepted.
- Open product blockers: no known implementation blocker; independent review remains required.
- Open operational risks: macOS may require owner approval for the packaged LaunchAgent on another machine; startup reports the required System Settings action explicitly and fails closed until enabled.

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

- Status: Accepted and released.
- Scope: Stable typed delivery records; app-owned SQLite connection and actor; versioned transactional migration; distinct delivery/runtime/audit/notification tables; attributed audit writes; read-only projections; foreign-key, uniqueness, project-boundary, and recursive phase/ticket acyclicity enforcement; explicit corruption/migration recovery state with an intact original and pre-migration snapshot.
- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`), `ad6a446` (`fix: reject transaction control in store reads`), `f5a06cf` (`fix: restrict store reads to observational SQL`).
- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, denial and rollback of callback mutations to `audit_events`, rejection of read-callback transaction control, and rejection of read-callback `PRAGMA foreign_keys=OFF` while preserving foreign-key enforcement and later valid audited writes. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
- Verification: Fresh controller verification on 2026-08-23: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 15 of 15 with 0 failures/skips, and `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` completed with the configured Apple Development identity and Hardened Runtime. Implementer `git diff --check` passed.
- Reviews: Final recovery reviews are clean. Code Reviewer: ACCEPT, Required 0, Optional 0, Out of scope 0. QA: ACCEPT, 15/15 focused tests, 0 failures/skips, Required 0. Architect: APPROVED, ADR-001 deviation resolved, Required 0. Security/privacy: PASS, Required 0, Optional 0; an independent system-SQLite probe confirmed state-setting PRAGMAs are denied, ordinary SELECT remains available, and foreign-key enforcement remains enabled.
- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; transaction callbacks deny transaction control and cannot access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read callbacks now use a strict SQLite authorizer allowlist limited to SELECT, READ, and FUNCTION actions, denying PRAGMA and every connection/schema/transaction/mutation action by default; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
- Risks: No open RR-02 Required finding. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
- Stop-rule events: The original read-boundary remediation stopped after two rounds when review found that the denylist still admitted SQLite connection-state mutation. A fresh recovery implementer preserved the existing lease, audit, and transaction protections and replaced only the read authorizer policy with the smaller fail-closed observational allowlist.
- Next eligible task: RR-03 typed agent action bridge.

### RR-03 release gate

- TPM: GO; RR-02 is technically accepted with all Required findings closed, scope controlled, and the recorded stop-rule recovery complete.
- Delivery Manager: GO; RR-02 commits, focused verification, signed build, independent reviews, and stop-rule evidence are durable; RR-03 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-03 — Typed agent action bridge

- Status: Accepted and released.
- Commits: `6b7262c` (`feat: add typed agent delivery actions`), `fa8eea0` (`feat: add signed agent bridge transport`), `abb92ef` (`fix: enforce agent bridge result contracts`), `6cbfcb4` (`fix: enforce bridge deadline inside store transaction`), and `7afbe0b` (`fix: report uncertain bridge outcomes truthfully`).
- Implemented scope: the committed typed command/dispatcher core plus a packaged MCP stdio tool, sandboxed LaunchAgent broker, application-hosted callback, exact wire/envelope/size/admission-deadline bounds, same-user and pinned team/identifier signing requirements on every XPC hop, app lifecycle registration, and explicit definitive-versus-uncertain delivery results. The broker/tool do not link `ReleaseRadarCore` or SQLite and cannot open the authoritative store.
- TDD: the original transport and two deadline fix rounds remain recorded in the task report. Recovery RED `/tmp/rr03-recovery-red-clean.log` exposed the absent `outcomeUnknown` result and post-dispatch/pre-reply seam. Recovery GREEN `/tmp/rr03-recovery-green-3.log` passed all 11 focused bridge/transport cases, including pre-admission expiry with no eventual write, committed reply loss followed by exact replay, callback invalidation after handoff, distinct wire/envelope versions, MCP error flags, and strict JSON integer/optional-string rejection.
- Verification: a fresh normal Debug app build passed. Strict deep signing plus explicit app/broker/tool requirements passed; the broker had exactly sandbox + the approved app group, the tool was unsandboxed with no app group, no embedded profile existed, and `otool` showed no Core/SQLite dependency in either executable. The recovery combined run exercised byte-identical normal-package broker/tool binaries and passed 26/26 transport/core/store tests with 0 failures/skips. Normal/test CDHashes matched before and after execution: broker `ce676ee13847bb703a648ad8c5e4e71ca90b0024`, tool `5dd2f5fecc2d98c84ab8189afe635d37ba01d39f`. Cleanup left no registered service or exact helper process; diff checks passed.
- Stop-rule recovery: the earlier anonymous-endpoint and app-owned listener attempts remain recorded as stopped and removed. The fresh recovery used the architect-approved minimal correction: a sandboxed broker with the same-team app group, an unsandboxed tool without the group, two team-prefixed Mach services, and no weaker fallback.
- Deadline stop-rule recovery: after two deadline remediation rounds, independent review showed that `appUnavailable` could still falsely imply no mutation after authenticated callback handoff. The recovery preserves pre-admission no-write enforcement but gives post-handoff uncertainty its own non-persisted `outcomeUnknown` result. Wire protocol version 2 is distinct from durable envelope version 1; once a transaction is admitted it runs to completion, and exact replay after an unknown result returns the original durable result without a duplicate mutation or audit.
- Controller verification: on 2026-08-24, the exact focused `AgentBridgeTransportAcceptanceTests`, `AgentBridgeAcceptanceTests`, and `StoreAcceptanceTests` command passed 26/26 with 0 failures/skips from `/tmp/rr03-controller-verify`; strict deep package signing passed and cleanup reported no registered LaunchAgent or helper process.
- Reviews: Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. QA ACCEPT after a fresh 26/26 signed-package run, Required 0, Optional 0. Architect APPROVED, Required 0 and no ADR update required. Security/privacy PASS, Required 0, Optional 0, Out of scope 0; the original permissive JSON, MCP error, and false timeout findings are closed.
- Decisions/risks: preserve the app-only SQLite writer boundary and durable envelope-version-1 replay. The app composes persisted authorized roots into the existing registry seam; the broker holds only the latest authenticated callback in memory. Transport failures before authenticated callback invocation are definitive `appUnavailable`; timer, callback, or XPC failure after invocation is `outcomeUnknown`. On machines where ServiceManagement returns `requiresApproval`, the app logs the explicit Login Items & Extensions owner action and does not weaken or bypass the gate.
- Next eligible task: RR-04 onboarding and required first-phase creation.

### RR-04 release gate

- TPM: GO; RR-03 is technically accepted with all Required findings closed, truthful outcome/replay semantics verified, and scope controlled through the recorded stop-rule recovery.
- Delivery Manager: GO; RR-03 commits, 26-case focused verification, signed-package boundaries, cleanup, and all four independent reviews are durable. RR-04 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-04 — Folder-backed project onboarding and first phase

- Status: Implemented; not accepted or released pending fresh independent code, QA, architecture, and security/privacy review.
- Commit: `0012372` (`feat: onboard folder-backed projects`).
- Scope: Native folder selection, read-only security-scoped bookmark persistence, canonical component containment, Git-root/worktree discovery, separately authorized external worktrees, durable task exclusions, first-phase gating through the typed dispatcher, persisted unmatched-task review items, and `first_dashboard_opened = false`.
- TDD: RED at `/tmp/rr04-red.log` established the missing onboarding/bookmark/worktree contracts. A second focused RED at `/tmp/rr04-red-authorize.log` established that external worktrees require an explicit authorization path. GREEN at `/tmp/rr04-green.log` covers root/descendant/contained-worktree inclusion, sibling-prefix/outside rejection, separately authorized worktrees, no-phase refusal, typed first-phase audit, durable exclusion after a recreated onboarding service, persisted review items, and notification ineligibility.
- Verification: Fresh focused `OnboardingAcceptanceTests` and directly affected `StoreAcceptanceTests` passed 17/17 with 0 failures/skips at `/tmp/rr04-final-tests.log`. A normal signed Debug `ReleaseRadar` build passed at `/tmp/rr04-final-build.log` with the configured Apple Development identity. Final diff check is recorded with the implementation commit.
- Reviews: Pending. Required/Optional/Out-of-scope classifications are not yet recorded.
- Decisions/risks: The onboarding service never treats a path prefix as containment. A worktree outside the folder bookmark is rejected until the owner selects that exact discovered worktree. The app writes project metadata directly through its store-owned transaction; first-phase creation goes through the existing typed command dispatcher and is audited. No Codex live-observer, board, importer, or notification behavior is introduced.
- Next eligible task: RR-04 independent review only; RR-06 remains closed.

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

- Baseline release state: RR-10 and the Release Radar MVP remain accepted and release-ready at product HEAD `271fcd4`.
- Current remediation state: **Done and Accepted.** On 2026-08-27, the owner confirmed that the installed `/Applications/ReleaseRadar.app` no longer produces the SQLite authorization error, that the pending tracking state persists across relaunch, and that the remediation is explicitly **Done/Accepted**. The accepted product implementation is commit `353322c`; the exact verified Release bundle remains preserved under `dist/` and installed under `/Applications`.
- Next eligible remediation work: none; the remediation gate is closed. No later product writer is released automatically. The coupled product/IA reconciliation is the next potential product decision, while Help, Portable Import/exporter work, wordmark production, warning cleanup, and other deferred or blocked work remain closed until explicitly released.
- Open product blockers: Release Radar has no authoritative portable project archive. Its Markdown delivery records and the existing partial Rekon seed importer cannot import the repository as a complete existing project.
- Nonblocking next-phase candidates: reconcile the coupled product/IA decisions; productionize the owner-approved wordmark recorded in `docs/brand/README.md`; remove the Swift optional-`.none` and test actor-isolation warnings; attach live Codex state only when a supported authenticated endpoint exists; and add Developer ID/notarized packaging only if distribution expands beyond the owner Mac. The structure-less onboarding decision and repaired installed workflow are accepted.
- Install note: macOS may require one-time owner approval for the packaged LaunchAgent in System Settings. Startup reports the required action and fails closed until enabled.

## Unscheduled product backlog

- Add owner-visible Back and Forward navigation buttons with defined navigation-history behavior. This item is not assigned to the current phase or any next-phase gate.

## Planning reconciliation — 2026-08-26

This is the canonical inventory, mockup-gap ruling, and dependency-safe
sequence for current planning. It classifies named work rather than counting
unchecked checklist boxes. Grouped numbered deliveries contribute their stated
quantity to the totals. Each counted item has exactly one classification.
Nothing in this section approves an implementation plan or releases a product
writer.

### Authority and historical records

- This ledger is the sole authority for current status, dependency gates,
  sequencing, and task eligibility.
- `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` and
  `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` are
  historical plans with explicit non-execution banners. Their unchecked boxes
  preserve chronology; they are not open work.
- Durable task contracts remain under `docs/delivery/task-briefs/`, but their
  presence does not make a task active. Exact historical originals remain
  under `docs/delivery/archive/` and are non-authoritative.
- Historical execution entries below retain some temporary-path evidence
  labels verbatim. Those labels are archaeological evidence, not controlling
  briefs, current gates, or current citations. Every controlling source and
  mockup decision in this reconciliation points to a repository-resident path;
  currently untracked paths are disclosed in the reconciliation handoff.

### Classification counts

| Classification | Count | Counted work |
| --- | ---: | --- |
| Active | 0 | None. No product or remediation writer is released. |
| Completed | 21 | RR-01–RR-10 (10), RR-R1–RR-R6 (6), Attach Folder (1), Tasks 7A/7B (2), absorbed RR-R7 route/sidebar work (1), and owner runtime validation of the installed SQLite-23 repair (1). |
| Superseded | 2 | Request-marker/“first phase” onboarding; Ready-lane or automatic transition proposals. |
| Misaligned | 5 | All-phase Work Board, Activity-to-History replacement, one-to-many goal linkage, semantic link/confidence suggestions, and partial Back-to-Goal history. |
| Duplicative | 2 | Replay of historical unchecked tasks; duplicate raster brand copies under the mockup set. |
| Blocked | 3 | Live Codex attachment, portable archive exporter/fixture, and Portable Import. |
| Deferred | 5 | Help, coherent Back/Forward definition, deterministic wordmark/lockups, warning cleanup, and conditional notarized distribution. |
| Proposed/unapproved | 3 | Recorded Project Plan visible UX; process-isolated role-agent workflow; CloudKit-backed read-only iPhone companion. |

### Evidence-backed inventory

| ID | Qty | Work item | Classification | Canonical source and evidence | Reason and surviving requirement | Duplicate/conflict; dependency or blocker | Required mockup |
| --- | ---: | --- | --- | --- | --- | --- | --- |
| A1 | 1 | SQLite-23 repair owner validation | Completed | This ledger, **Current gate** and **Initialize Project Tracking SQLite-23 repair — reopened owner gate** | The owner confirmed the SQLite authorization error is gone, pending tracking state persists across relaunch, and the remediation is Done/Accepted. | Gate closed on 2026-08-27; no product writer is automatically released. | None; validation used the installed app. |
| C1 | 10 | MVP RR-01–RR-10 | Completed | This ledger, **Task ledger**; `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` | Accepted delivery remains intact; preserve historical evidence and do not replay. | Historical unchecked boxes duplicate completed work. | None; completed work is excluded from generation. |
| C2 | 6 | Remediation RR-R1–RR-R6 | Completed | This ledger, **2026-08-25 — Post-MVP reported-defect remediation intake**; `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` | Accepted in the combined validation artifact. | Historical plan state is superseded by later ledger gates. | None; completed work is excluded from generation. |
| C3 | 1 | Attach Folder to Existing Project | Completed | This ledger, **Existing-project onboarding implementation and current gate** | Accepted behavior and residual tooling limitation are historical delivery evidence. | Portable Import is a different blocked workflow. | None; completed work is excluded from generation. |
| C4 | 2 | Initialize Project Tracking Tasks 7A and 7B | Completed | This ledger, **Initialize Project Tracking — owner decision and implementation-plan gate** | The persisted/copy-only handoff behavior is delivered; the later SQLite-23 repair supersedes the earlier closeout status, not the completed UI work. | Old “first phase” and request-marker copy is superseded. | None; completed work is excluded from generation. |
| C5 | 1 | RR-R7 route/sidebar safety | Completed | This ledger, **RR-R7 planning/release gate** historical banner and current classified state | Route/sidebar work is absorbed into the installed combined artifact; no separate writer survives. | Duplicative if opened as a new RR-R7 writer. | None. |
| S1 | 1 | “Ask agent to define first phase” / request-marker onboarding | Superseded | `docs/design/agent-driven-delivery-dashboard-design.md`, **Onboarding**; this ledger, Task 7B acceptance | Replaced by **Initialize Project Tracking** and a path-free copied-not-sent prompt. | `docs/design/mockups/onboarding_state.png` retains obsolete copy and is historical visual evidence only. | No replacement now: the delivered UI and runtime remediation are accepted, and this is not a new design task. |
| S2 | 1 | Ready lane and automatic dependency/runtime transitions | Superseded | `docs/architecture/ADR-001-release-radar-boundaries.md`, **Decision** and **Prohibited alternatives** | Exactly five persisted lanes survive; dependency and observed runtime are derived context only. | Conflicts with any sixth-lane or implicit-transition proposal. | None. |
| M1 | 1 | All-phase Work Board | Misaligned | `docs/design/release-radar-ux-redesign-study.md`, **Work Board contract**; `docs/design/mockups/work_board.png` and `work_board_compact.png` | Proposed surface overlaps the accepted phase-scoped Phase Board and the unapproved Project Plan. | Must be resolved with M2–M5 as one route/state/data decision. | Existing images are proposal evidence only; generate nothing until approval. |
| M2 | 1 | Activity renamed/replaced by History | Misaligned | `docs/design/release-radar-ux-redesign-study.md`, **History contract**; `docs/design/mockups/history.png` and `history_compact.png` | Accepted Activity already owns project chronology; History is a proposed replacement, not a sibling. | Conflicts with the Project Plan proposal, which retains Activity. | Existing images are proposal evidence only. |
| M3 | 1 | One goal linked to many tickets | Misaligned | `docs/design/release-radar-ux-redesign-study.md`, **Data and route implications**; `docs/architecture/ADR-001-release-radar-boundaries.md`, **RR-R3 ticket-goal identity** | The accepted contract is one-to-one. A one-to-many target requires an owner decision and a new architecture decision. | Shares schema, Goals, board, history, and migration contracts with M1–M5. | Existing Goals/flow images cannot be accepted under the current ADR. |
| M4 | 1 | Suggested semantic links and confidence scoring | Misaligned | `docs/design/mockups/goals_data_states.png`; accepted RR-R3 contract in ADR-001 | Automatic semantic matching is new authority and data scope, not an extension of exact links. | Needs explicit source, approval, persistence, audit, and bridge decisions. | Existing image is proposal evidence only. |
| M5 | 1 | Local Back-to-Goal as global history evidence | Misaligned | `docs/design/mockups/goal_to_work_flow.png`; this ledger, **Unscheduled product backlog** | A local return action does not define complete Back/Forward history. | Must be resolved with the shared navigation decision, not scheduled separately against the same routes. | Existing flow is partial evidence; no new image until history semantics are approved. |
| D1 | 1 | Replay of historical unchecked plan tasks | Duplicative | Both historical plans' top banners; `docs/delivery/task-briefs/README.md` | Unchecked boxes and retained briefs are archaeological contracts, not eligibility. | Duplicates C1–C5. | None. |
| D2 | 1 | Duplicate raster brand references | Duplicative | `docs/brand/README.md`; `docs/design/mockups/icon.png`, `full_logo.png`; `docs/brand/release-radar-icon-v1.png`, `release-radar-lockup-v1.png` | The mockup icon is a duplicate brand reference and the two lockup rasters cover the same direction. Preserve all files; brand README is authoritative. | Does not reopen completed AppIcon production. | None; existing references are adequate. |
| B1 | 1 | Supported live Codex attachment / automatic thread discovery | Blocked | ADR-001, **RR-05 feasibility outcome** | Open only when a supported authenticated sandbox-compatible endpoint exists. | External transport prerequisite absent. | None while blocked. |
| B2 | 1 | Portable archive exporter and exporter-produced fixture | Blocked | ADR-001, **Existing-project onboarding and portable project archive v1** | Exporter must establish the authoritative fixture before importer work. | Separate approved brief and complete fixture absent. | None while blocked. |
| B3 | 1 | Portable Import UI/implementation | Blocked | Same ADR section; base design, **Onboarding** | Cannot open before B2; Markdown, seed JSON, repository state, and SQLite copies are prohibited substitutes. | Depends on B2 and any later archive extension for newly approved planning data. | None while blocked. |
| F1 | 1 | Help | Deferred | Base design, **Onboarding** | Future Help remains outside the current onboarding and delivery gates. | No approved task or visual contract. | None. |
| F2 | 1 | Coherent owner-visible Back/Forward history | Deferred | This ledger, **Unscheduled product backlog** | Survives as a need, not as an approved interaction contract. | Must follow M1–M5 reconciliation and be serialized with shared navigation. | Decision gate prevents generation. |
| F3 | 1 | Deterministic wordmark/typeface and light/dark lockups | Deferred | `docs/brand/README.md`, **Remaining next-phase wordmark task** | Existing raster direction survives; the remaining deliverable is deterministic production artwork. | Independent of product IA after A1, but not currently released. | Existing raster lockup is adequate; no new AI mockup. |
| F4 | 1 | Swift optional-`.none` and test actor-isolation warnings | Deferred | This ledger, **Current gate** | Maintenance candidate only. | Independent files may be assigned separately after an explicit release. | None. |
| F5 | 1 | Developer ID/notarized distribution | Deferred | This ledger, **Current gate** and RR-10 accepted limitation | Open only if distribution expands beyond the owner Mac. | Conditional external scope decision. | None. |
| P1 | 1 | Recorded Project Plan visible UX | Proposed/unapproved | `docs/design/release-radar-project-planning-ux-proposal.md`, **Explicit gate statement** | The owner-directed Overview retention survives inside the proposal, but the complete Gate-1 package is not approved. | Shares IA, routes, planning data, archive, and history decisions with M1–M5. | Polished screenshots remain gated; generate nothing. |
| P2 | 1 | Process-isolated independent role-agent workflow | Proposed/unapproved | This ledger, **Pending owner decision — Process-isolated independent role agents** | Not approved and not a current delivery-model change. | Requires a separate explicit owner decision; unrelated to product mockups. | None. |
| P3 | 1 | CloudKit-backed read-only iPhone companion | Proposed/unapproved | `docs/design/cloudkit-iphone-companion-draft.md` | The discussion draft proposes private-cloud publication and a mobile reader but explicitly approves no product, architecture, or implementation work. | Conflicts with ADR-001's local-only/non-cloud authority; also depends on a supported truthful agent-status publisher, mobile IA, privacy/recovery decisions, and the final operational/artifact data boundary. | No mobile mockup until those owner and architecture gates are approved. |

### Mockup gap analysis and generation ruling

Direct inspection covered all 17 PNGs currently present under
`docs/design/mockups/`.
The accepted wide reference set is 1586 × 992; proposal studies use 2048 ×
1280 and 900 × 650. The established language is a deep graphite/navy macOS
window, fixed 220-point wide sidebar or 96-point compact rail, thin blue-gray
borders, subtle panel shadows, cyan selection and primary actions, restrained
status colors, generous native spacing, and read-only cards/inspectors.

| Candidate | Surviving requirement and canonical source | Existing coverage / overlap | Needed states | Ruling |
| --- | --- | --- | --- | --- |
| Projects/Overview portfolio health | Base design, **Goals** and **Dashboard model → Project overview** | No dedicated design PNG, but completed RR-06/RR-10 behavior has durable wide evidence in `docs/delivery/evidence/rr10-projects-overview-board-detail.png`. | Wide populated; compact behavior is already completed and evidenced. | Do not generate: completed work with adequate durable acceptance evidence. |
| Selected Phase Board ticket detail | Base design, **Dashboard model → Phase board** and acceptance criterion 3 | `phase_board.png` plus `dependencies.png` establish the visual pattern; completed integrated behavior is in `docs/delivery/evidence/rr10-projects-overview-board-detail.png`. | Wide selected detail; compact evidence exists in `docs/delivery/evidence/rr10-board-compact.png`. | Do not generate: completed work. |
| Compact five-lane Phase Board | Base design, **Dashboard model → Phase board** | `phase_board.png` is wide; `work_board_compact.png` is an unapproved all-phase proposal. Durable completed runtime evidence exists in `docs/delivery/evidence/rr10-board-compact.png`. | Compact ID/count cards and recoverable five lanes. | Do not generate: completed and already evidenced. |
| Truthful current onboarding state | Base design, **Onboarding** | `onboarding_state.png` has obsolete “first phase”/agent-contact copy and a Portable Import implication; the current text contract and completed delivery supersede it. | Initialize/Attach, copied-not-sent, unavailable/recovery. | Do not generate: completed UI; retain the old PNG as explicitly superseded historical evidence. |
| Project Plan polished screenshots | Proposed Project Plan document, **Explicit gate statement** | No existing Project Plan image; Work Board is an overlapping different proposal. | Wide/compact, no-Current, empty, incomplete, unavailable/error. | Owner Gate-1 decision prevents generation. |
| Goals / Work Board / History | Proposed redesign study and its eight tracked rasters | Images already exist but conflict with accepted IA/data contracts. | Existing wide/compact/state/flow studies are sufficient proposal evidence. | Generate nothing until M1–M5 are reconciled and approved. |
| Back/Forward | Unscheduled backlog and F2 | `goal_to_work_flow.png` covers only local return. | Wide/compact toolbar and complete history/error rules are undecided. | Owner decision gate prevents generation. |
| Wordmark/lockups | Brand README | Existing raster lockup adequately records the approved direction. | Future light/dark deterministic production artwork. | Not an AI-mockup gap. |
| Help, Portable Import, live attachment | F1, B1–B3 | No approved eligible surface. | Undefined or blocked. | Generate nothing while deferred/blocked. |
| Read-only iPhone companion | Concurrent proposed draft P3 | No approved mobile IA; proposed CloudKit authority conflicts with ADR-001 and truthful live status remains blocked. | Mobile dashboard/document states are undecided. | Owner/product/architecture gates prevent generation. |

**Generation result: 0 new mockups.** Every visually missing accepted surface
is completed and already has durable runtime evidence; every genuinely open
surface is proposed, misaligned, blocked, deferred, or missing an owner
decision. Generating any of them would violate the scope rule against mockups
for completed, speculative, blocked, or unresolved work.

### Dependency-safe priority order

| Priority / sequence | Status and gate | Dependencies and blocking decisions | Shared surfaces/contracts; concurrency | Mockup state | Why this priority |
| --- | --- | --- | --- | --- | --- |
| P0 / 1 — Owner runtime validation | **Completed; Done/Accepted** | Owner confirmed the installed Release workflow no longer produces the SQLite authorization error, persists pending tracking state across relaunch, and is accepted. | Installed app and local owner state; no product writer was released during validation. | No mockup required. | Closed successfully on 2026-08-27. |
| P1 / 2 — Coupled product/IA reconciliation | **Closed decision gate; next potential product work** | P0 is complete; owner decisions remain required for Phase Board/Project Plan/Work Board, Activity/History, one-to-one/one-to-many links, semantic suggestions, and complete history semantics; update the ADR where data authority changes. | Project navigation, board/plan routes, goal-link storage, observation provenance, archive coverage, focus/history state. Serialize as one design stream. | Existing proposal images retained but unapproved; new images only after decisions. | These choices overlap and cannot safely be planned or mocked independently. |
| P2 / 3 — Deterministic wordmark/lockups | **Deferred; separable candidate** | P0 is complete; explicit owner release and a production typeface/license or drawn outlines remain required. | Brand files only; may proceed independently from later product IA when released. | Existing raster direction adequate; no new AI mockup. | It is the only surviving visual-production candidate that does not share product routes or data. |
| P3 / 4 — Warning cleanup | **Deferred maintenance** | P0 is complete; explicit owner release remains required. | Compiler/test files; keep separate from product UI/data work. | None. | Low-risk maintenance that is not automatically released by remediation acceptance. |
| P4 / 5 — Portable exporter and fixture | **Blocked prerequisite** | P1 if approved planning concepts extend the archive; separate brief and complete exporter fixture. | Archive schema, persistence, migrations, evidence portability. Serialize with any archive-contract change. | None while blocked. | Export truth must exist before import can be designed or tested. |
| P5 / 6 — Portable Import | **Blocked dependent** | P4 accepted exporter/fixture and any required archive version decision. | Onboarding routes, storage transaction, folder authorization, archive validation. One writer after P4. | None while blocked. | Import cannot precede its authoritative source. |
| P6 / 7 — Live Codex attachment | **Externally blocked** | Supported authenticated sandbox-compatible endpoint. | Observer only; must remain separate from the mutation bridge and delivery authority. | None while blocked. | No local planning can remove the external transport prerequisite. |
| P7 / 8 — iPhone companion product/architecture decision | **Proposed/unapproved; closed** | P1 data-boundary decisions where relevant; a supported truthful status publisher; explicit owner product scope; replacement or amendment of ADR-001's local-only/non-cloud authority; mobile IA, privacy, retention, account, and recovery decisions. | Shares delivery/artifact authority, archive coverage, observation freshness, security/privacy, and cross-device persistence. Do not run in parallel with conflicting archive or live-status contract work. | No mobile mockups before the visible IA is approved. | Cloud publication changes a foundational authority boundary and must not be implied by a discussion draft. |
| P8 / 9 — Notarized distribution | **Conditional deferred** | Explicit distribution-scope expansion. | Packaging/signing only; independent of product IA after a stable release. | None. | It is unnecessary for the current owner-only distribution boundary. |
| P9 / 10 — Help | **Deferred** | Explicit product/visual contract after higher-priority navigation decisions. | Shares navigation and onboarding wording; serialize after P1 if opened. | None. | No approved scope or screen exists. |

No implementation work is released by this sequence. Completed, superseded,
misaligned, duplicative, blocked, deferred, and proposed items remain outside
the executable queue.

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
- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, denial and rollback of callback mutations to `audit_events`, rejection of read-callback transaction control, and rejection of read-callback `PRAGMA foreign_keys=OFF` while preserving foreign-key enforcement and later valid audited writes. Full command/results are preserved in `docs/delivery/archive/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
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

- Status: Accepted and released.
- Commits: `0012372` (`feat: onboard folder-backed projects`), `af5dd0a` (`fix: harden project onboarding boundaries`), and `f545034` (`fix: reject denied bookmark scope access`).
- Scope: Native folder selection, read-only security-scoped bookmark persistence, canonical component containment, Git-root/worktree discovery, separately authorized external worktrees, durable task exclusions, first-phase gating through the typed dispatcher, persisted unmatched-task review items, and `first_dashboard_opened = false`.
- TDD: RED at `/tmp/rr04-red.log` established the missing onboarding/bookmark/worktree contracts. A second focused RED at `/tmp/rr04-red-authorize.log` established that external worktrees require an explicit authorization path. GREEN at `/tmp/rr04-green.log` covers root/descendant/contained-worktree inclusion, sibling-prefix/outside rejection, separately authorized worktrees, no-phase refusal, typed first-phase audit, durable exclusion after a recreated onboarding service, persisted review items, and notification ineligibility.
- Verification: Final focused `OnboardingAcceptanceTests` and directly affected `StoreAcceptanceTests` passed 20/20 with 0 failures/skips. Controller verification on 2026-08-24 repeated the 20/20 pass from `/tmp/rr04-controller-verify`; a normal signed Debug package built with the configured Apple Development identity and passed strict deep codesign verification.
- Reviews: Final Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. Final QA ACCEPT, 20/20 focused cases, Required 0, Optional 0, Out of scope 0. Architect APPROVED, Required 0 and no ADR update required. Security/privacy PASS, Required 0, Optional 0, Out of scope 0.
- Remediation evidence: The first review rejected manual phase impersonation, fail-open bookmark persistence, cross-project root transfer, non-durable editable exclusions, and an ineffective no-phase test. Fix round 1 replaced phase fabrication with an app-owned audited request/wait state, made stale/failed bookmarks unavailable under balanced scope access, rejected root ownership conflicts, reconciled exclusions, and exercised the prepared-but-phase-less gate. Fix round 2 closed the sole residual finding by rejecting denied security-scope starts before discovery or persistence. Both rounds remained within RR-04.
- Decisions/risks: The onboarding service never treats a path prefix as containment. A worktree outside the folder bookmark is rejected until the owner selects that exact discovered worktree. Stale, failed, or denied bookmark access fails closed. The app writes project/request/review metadata only through store-owned audited transactions; only a real agent-originated typed bridge upsert can satisfy phase one. No Codex live-observer, board, importer, notification event, or notification sender behavior is introduced.
- Next eligible task: RR-06 recognizable local-first board.

### RR-06 release gate

- TPM: GO; RR-04 is technically accepted with every Required onboarding, bookmark, ownership, phase-gate, exclusion, and notification-silence finding closed.
- Delivery Manager: GO; RR-04 commits, 20-case controller verification, signed build, independent reviews, and both bounded remediation rounds are durable. RR-06 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-06 — Recognizable local-first board

- Status: Accepted and released.
- Commits: `baeb390` (`feat: add persisted phase dashboard`) and `1ab6486` (`fix: preserve project dashboard context`).
- Scope: Idempotent audited sample persistence for the approved Rekon Pursuit project, Post-MVP refinement phase, 31 tickets, dependencies, blockers, evidence, observed goal/thread link, audit event, and notification history; Projects, Project Overview, and an adaptive five-lane Phase Board; read-only selected-ticket context; a fixed 220-point/96-point navigation rail; and unchanged placeholders for later screens and settings. No live observer, importer, Pushover sender, schema migration, or dependency was added.
- TDD: Initial focused RED at `/tmp/rr06-red.log` failed to compile because `DashboardSampleData`, `DashboardProjection`, and `DashboardLayout` did not exist. Projection GREEN at `/tmp/rr06-projection-green-attempt.log` passed 4/4. The first review-fix RED at `/tmp/rr06-fix1-red.log` failed only because project-level goal context and non-first-project navigation APIs were absent. Fix GREEN at `/tmp/rr06-fix1-green.log` and fresh final verification at `/tmp/rr06-fix1-final-tests.log` passed 8/8 across `DashboardProjectionTests` and `AppRouteTests`, with 0 failures/skips. Coverage proves the ordered counts `[9, 1, 2, 1, 18]`, 31 unique single-lane ticket memberships, seeded `VD2-08` dependency counts, complete read-only `VD2-07c` context and relationship direction, relaunch persistence/idempotence, wide/compact presentation thresholds, verified and unavailable project-goal projections, and non-first-project context through Board, Dependencies, Activity, and back to Projects.
- Build/launch evidence: `./script/build_and_run.sh --verify` completed a normal configured Debug build, signed and launched `DerivedData/Build/Products/Debug/ReleaseRadar.app`, and fresh strict deep codesign verification passed; first-review-fix evidence is in `/tmp/rr06-fix1-build-run.log` and `/tmp/rr06-fix1-codesign.log`. The running normal bundle truthfully surfaces the pre-existing database recovery condition described below.
- Seeded UI evidence: An otherwise identical configured Debug build used the temporary capture-only bundle identifier `com.rekonlabs.ReleaseRadar.RR06Capture` to obtain a fresh sandbox without touching owner data; `/tmp/rr06-fix1-capture-build.log` records the successful build and `/tmp/rr06-fix1-capture-codesign.log` records strict deep codesign verification. `docs/delivery/evidence/rr06-owner-wide.png` and `docs/delivery/evidence/rr06-owner-narrow.png` remain the approved unchanged board evidence. `docs/delivery/evidence/rr06-fix1-projects.png` and `docs/delivery/evidence/rr06-fix1-overview.png` show active phase, verified last-known goal status/context and observation time, current-work count, and owner-attention count on the two affected screens. The temporary bundle's Documents request was denied; no folder access was granted. The captures retain the known macOS background-item banner at the extreme top-right; no product remediation was made for OS chrome.
- Controller verification: On 2026-08-24, the focused `DashboardProjectionTests` and `AppRouteTests` command passed 8/8 with 0 failures/skips from `/tmp/rr06-controller-verify`; the produced configured Debug app passed strict deep codesign verification.
- Reviews: Initial review identified two Required findings: first-project-only navigation context and missing persisted project-level goal state. Both were addressed in `1ab6486`. Final Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. Final QA ACCEPT, fresh 8/8 focused cases, Required 0, Optional 0; the persistent macOS banner is classified Out of scope as OS chrome. Architect APPROVED, Required 0 and no ADR update required. Security/privacy PASS, Required 0, Optional 0, Out of scope 0.
- Decisions/risks: Lane membership is the sole ticket state projection. Project navigation now retains the explicit selected project ID and also derives it from every project-scoped route; the sidebar label and all project-route buttons use that same projected project. Projects and Overview label the latest persisted `observed_goals` row as a verified last-known goal, or state that no persisted goal observation is available; no live observation was added. Cards remain selection-only; the inspector exposes outcome, verified/last-known goal context, dependency direction, owner attention, evidence, audit, and notification histories without manual state controls. The existing owner database at `~/Library/Containers/com.rekonlabs.ReleaseRadar/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/release-radar.sqlite` has `PRAGMA user_version = 3` but a legacy `audit_events` shape without `thread_attribution`. It was inspected read-only and left intact; recovery/repair belongs to the later failure-state work rather than RR-06.
- Stop-rule evidence: A narrow-layout lane-width defect was corrected within the second bounded compile/remediation attempt. Work on the unrelated persistent macOS capture banner stopped after one dismissal attempt.
- Next eligible task: RR-05 read-only live Codex observation feasibility and bounded implementation.

### RR-05 release gate

- TPM: GO; RR-06 is technically accepted with its navigation and project-goal findings closed, responsive board evidence verified, and no manual delivery controls or deferred-screen scope added.
- Delivery Manager: GO; RR-06 commits, 8-case controller verification, signed build/launch evidence, wide/narrow screenshots, and all four independent reviews are durable. RR-05 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-05 — Read-only Codex observation feasibility

- Status: Accepted and released as the explicit unavailable/cached-stale feasibility outcome.
- Commits: `ae5fd63` (`feat: define unavailable Codex observation`) and `c94135f` (`fix: scope cached Codex observations`).
- Feasibility evidence: Codex CLI `0.147.0` official manual/help and the running desktop process were inspected in two bounded read-only passes. The desktop app-server uses its default parent-owned stdio transport and exposes no supported named Unix or TCP listener for a separately sandboxed authenticated client. A separately started app-server is not evidence of the desktop task's state. No Codex database, rollout/session file, terminal, log, UI, or undocumented IPC content was read; no Codex task was mutated.
- Scope: Added normalized thread, goal, completion, waiting, freshness, snapshot, and event models; the required read-only `CodexObserver` contract; an `UnavailableCodexObserver`; and app-state loading. With no cache it reports `unavailable`. Any injected cached snapshot, including one captured as live, is normalized to `stale` with its last-observed time and retained last-known state. No app-server client, helper, importer, notification sender, dependency screen, or RR-07 feature was added.
- TDD and verification: Initial RED failed because the observer models did not exist. Focused observer GREEN passed 4/4, and the app-state integration test passed 1/1 (`/tmp/rr05-focused-green.log`). The fixture covers Active, Paused, Blocked, Awaiting input, Completed/Ready for review, active flags, active goal, and cleared goal. A store-backed boundary case proves observation leaves the formal RR-05 ticket lane unchanged. The directly affected `DashboardProjectionTests` regression passed 5/5 (`/tmp/rr05-projection-regression.log`). `./script/build_and_run.sh --verify` completed the configured signed Debug build (`/tmp/rr05-build-run.log`), and strict deep codesign verification passed (`/tmp/rr05-codesign.log`). Diff checks passed.
- Decision/risk: Live observation remains blocked until Codex exposes a supported authenticated attach surface for the running desktop task. Fixture/cache data is never labeled live, and observer failure cannot become delivery authority. RR-07's explicit unavailable/stale presentation dependency becomes eligible only after independent acceptance of this recorded outcome.
- Required fix round 1: Initial QA found that unsupported cached schema versions were still presented as stale and that cached threads were not bounded to the selected project's authorized roots/exclusions. RED at `/tmp/rr05-fix1-red.log` failed on the absent scope contract. The fix accepts cached schema version 1 only, requires an injected canonical `CodexObservationScope`, filters by component-wise selected-root/descendant or separately authorized worktree containment, rejects sibling-prefix/outside/nonexistent/symlink-escape and excluded threads, and normalizes accepted working directories. Cached data without a scope is unavailable and empty. Final affected verification passed 16/16 observer, dashboard-projection, and app-route cases (`/tmp/rr05-fix1-final-tests.log`); the configured signed build/launch and strict deep codesign verification passed (`/tmp/rr05-fix1-build-run.log`, `/tmp/rr05-fix1-codesign.log`).
- Controller verification: On 2026-08-24, the focused observer, dashboard-projection, and app-route command passed 16/16 with zero failures/skips from `/tmp/rr05-controller`; a configured Debug build passed, and the produced app passed strict deep codesign verification.
- Reviews: Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. QA ACCEPT, both prior Required findings closed, focused verification and signed launch/codesign clean. Architect ACCEPT, Required 0 and no ADR/deviation required; its optional wording clarification is non-blocking. Security/privacy ACCEPT, Required 0, Optional 0, Out of scope 0.
- Decision/risk: Release Radar does not claim live Codex state. Authorized compatible cache is always stale; absent scope, incompatible schema, or absent cache is unavailable and empty. The observation layer cannot mutate formal delivery lanes. A supported authenticated sandbox-compatible shared desktop attachment remains an open product blocker, but the approved degraded path is safe and dependency-complete for RR-07.
- Next eligible task: RR-07 Needs Review, dependencies, activity, and settings navigation.

### RR-07 release gate

- TPM: GO; RR-05 truthfully completed its bounded feasibility gate, retained only scoped cached-stale state, and closed every Required review finding.
- Delivery Manager: GO; RR-05 implementation, fix, controller verification, signed build, and four independent reviews are durable. RR-07 is dependency-safe under the plan's explicit unavailable/stale branch and is released to one Implementer with no concurrent writer.

### RR-07 — Needs Review, dependencies, activity, and settings navigation

- Status: Accepted and released.
- Scope: Added the persisted Needs Review master/detail inbox for uncertain imports, possible duplicates, unresolved dependencies, unmatched tasks, excluded tasks, and agent review requests; audited Resolve/Dismiss actions through the existing typed agent-action boundary without lane mutation; an exact ticket dependency graph with direct, indirect, and unlock projections, semantic lane colors, blocker counts, and precise connector endpoints; persisted project activity that keeps formal delivery lane separate from last-observed runtime state; and General, Connections, Notifications, and Projects settings tabs. Live Codex attachment, imports, network delivery, credential storage, notification sending, and database recovery remain out of scope.
- Commits: `bb9f5b7` (`feat: support audited review decisions`), `4838c33` (`feat: project review inbox and dependency graph`), `472ef3a` (`feat: project activity and settings states`), `6011738` (`feat: add review graph activity and settings surfaces`), `83fd317` (`fix: scope dependency graph edges to phase`), and `4925339` (`fix(rr-07): preserve review origin and scope activity audits`).
- TDD: Focused RED/GREEN logs are `/tmp/rr07-review-boundary-{red,green}.log`, `/tmp/rr07-inbox-{red,green}.log`, `/tmp/rr07-graph-{red,green}.log`, `/tmp/rr07-activity-settings-{red,green}.log`, `/tmp/rr07-appmodel-{red,green}.log`, and `/tmp/rr07-sample-review-{red,green}.log`. The fresh final run at `/tmp/rr07-final-tests.log` passed 24/24 cases across RR-07, agent-bridge, dashboard projection, and route tests with 0 failures/skips.
- Build and visual evidence: `./script/build_and_run.sh --verify` succeeded at `/tmp/rr07-build-run.log`; strict deep codesign verification passed for the Apple Development-signed `com.rekonlabs.ReleaseRadar` app with hardened runtime. A separate `com.rekonlabs.ReleaseRadar.RR07Capture` build used fresh isolated app data and produced `docs/delivery/evidence/rr07-needs-review.png`, `rr07-dependencies.png`, `rr07-activity.png`, and `rr07-settings.png`. Accessibility inspection confirmed the six review rows and both actions; VD2-08's 2 direct requirements, 3 indirect requirements, and 3 unlocks; persisted activity with distinct Lane and Runtime labels; and truthful unavailable Codex connection text.
- Fix round 1: `83fd317` scopes dependency edges to the selected phase's loaded node set, so inspector traversal and layout connectors cannot consume invisible cross-phase relationships. The two-phase regression failed on the prior implementation at `/tmp/rr07-fix1-cross-phase-red.log`, passed after the fix at `/tmp/rr07-fix1-cross-phase-green.log`, and the fresh directly affected 8/8 review/graph suite passed at `/tmp/rr07-fix1-final.log` with 0 failures/skips. Code Reviewer and QA re-review accepted the fix with no remaining Required or Optional findings.
- Fix round 2: `4925339` gives SwiftUI review decisions an explicit owner-app origin while preserving asserted-thread attribution for external agent commands through the same dispatcher validation and mutation path. Additive schema version 4 adds nullable audit `project_id`, `entity_type`, and `entity_id`; the store accepts an optional typed scope, and every dispatcher command supplies one. Activity now selects audits by exact structured project/entity scope, excludes legacy unscoped rows, and derives review timestamps without reason-text correlation. RED/GREEN evidence is `/tmp/rr07-fix2-origin-{red,green}.log`, `/tmp/rr07-fix2-audit-scope-{red,green}.log`, `/tmp/rr07-fix2-dispatch-scope-{red,green}.log`, and `/tmp/rr07-fix2-activity-scope-{red,green}.log`. The fresh required Review/Graph, Store, and Agent Bridge run passed 34/34 with 0 failures/skips at `/tmp/rr07-fix2-required-suites.log`; the non-launching configured Debug build and strict deep codesign verification passed at `/tmp/rr07-fix2-signed-build.log` and `/tmp/rr07-fix2-codesign.log`. The known owner legacy schema drift was neither detected nor repaired, and the owner database was not opened during verification.
- Controller verification: On 2026-08-24, the final focused Review/Graph, Store, Agent Bridge, Dashboard Projection, and App Route command passed 43/43 with zero failures/skips from `/tmp/rr07-final-controller`; a configured Debug build succeeded and the app passed strict deep codesign verification.
- Reviews: Final Code Reviewer ACCEPT, Required 0, Optional 0. Final QA ACCEPT, Required 0, Optional 0. Architect ACCEPT, Required 0, no ADR/deviation required; its terminology note for legacy `resolveImportReview` command names is non-blocking. Security/privacy ACCEPT, Required 0, Optional 0; the cross-project reason-text disclosure is closed and external wire input cannot select owner attribution.
- Decisions/risks: The app-only store remains the sole SQLite writer and observers remain read-only. Review actions require an authorized persisted project root; when none exists, the app surfaces an explicit failure and preserves the open review item. The fresh sample intentionally has no fabricated root. Only Needs Review and Notifications carry sidebar badges, so notification history does not introduce a duplicate bell/count surface. Existing database recovery remains owned by RR-10 and was not changed.
- Next eligible task: RR-08 one-time recognized Rekon delivery artifact import.

### RR-08 release gate

- TPM: GO; RR-07 is accepted with all Required graph, audit-attribution, and project-isolation findings closed, and its final controller evidence is proportional and clean.
- Delivery Manager: GO; RR-07 commits, two bounded remediation rounds, 43-case controller verification, signed package, four screenshots, and four independent reviews are durable. RR-08 is dependency-safe and released to one Implementer with no concurrent writer.

### RR-08 — One-time recognized Rekon delivery import

- Status: Accepted. RR-09 is released.
- Commits: `e0569be` (`feat: import Rekon delivery records`), `c60800c` (`fix: harden Rekon import boundaries`), `5c3c130` (`fix: account for persisted import cycles`), `25e88ed` (`fix: persist active phase and anchor artifact reads`).
- Scope: Added a bounded schema-version-1 Rekon dashboard JSON preview and one-time importer. It maps confident phases, tickets, five lane values, phase/ticket dependencies, and explicit evidence links; recognizes only the fixed roadmap, task-brief, handoff, and ledger evidence families; and never parses arbitrary Markdown as delivery authority. Duplicate IDs, missing outcomes, unresolved references, unmapped states, and existing-record conflicts become deterministic Needs Review items.
- Persistence and boundaries: Apply revalidates the preview, configured authorization, persisted project/root ownership, and evidence containment before writing. One app-owned audited transaction inserts only non-conflicting delivery records, preserves resolved/dismissed review status on replay, remains record-idempotent, writes no notification events, and marks missing importer-owned evidence unavailable without deleting imported delivery state or changing source files.
- TDD: Preview RED is `/tmp/rr08-preview-red.log`; preview GREEN is `/tmp/rr08-preview-green.log`; apply RED is `/tmp/rr08-apply-red.log`; the bounded compile correction is `/tmp/rr08-apply-green-attempt1.log`; and first full apply GREEN is `/tmp/rr08-apply-green-attempt2.log`.
- Implementer verification: Fresh focused verification at `/tmp/rr08-final-tests.log` passed 6/6 `RekonImportAcceptanceTests` with zero failures/skips. The separate configured Debug build at `/tmp/rr08-final-build.log` succeeded with the configured Apple Development identity, and strict deep codesign verification of `/tmp/rr08-final-build/Build/Products/Debug/ReleaseRadar.app` passed. `git diff --check` passed before the feature commit.
- Required fix round 1: Canonical regular-file checks now reject an artifact symlink escaping the authorized source root before decoding. Artifact size is checked from metadata and enforced again through a bounded maximum-plus-one read; recognized evidence discovery uses capped top-level enumeration, limits retained records, canonicalizes every retained path, and accepts only regular files. Deterministically ordered phase and ticket edges that would create multi-node cycles are excluded into `unresolved_dependency` review items while valid records and edges remain applicable. All three findings used RED/GREEN regressions with zero unsuccessful implementation attempts: `/tmp/rr08-fix1-artifact-{red,green}.log`, `/tmp/rr08-fix1-evidence-{red,green}.log`, and `/tmp/rr08-fix1-cycles-{red,green}.log`.
- Fix-round verification: Fresh importer and Store verification at `/tmp/rr08-fix1-final-tests.log` passed 25/25 tests (9 importer, 16 Store) with zero failures/skips. The configured signed Debug build at `/tmp/rr08-fix1-final-build.log` succeeded, and strict deep codesign verification at `/tmp/rr08-fix1-codesign.log` reported the app valid on disk and satisfying its designated requirement. `git diff --check` passed before the fix commit.
- Required fix round 2: The first re-review accepted the symlink and bounded-input fixes and retained one Required cycle finding: apply considered only the source preview graph, so a reverse edge against an already persisted project edge reached the store trigger and rolled back otherwise valid records. Apply now loads each target project's phase and ticket dependency graphs in deterministic order, treats exact persisted edges as idempotent, and checks every other available-endpoint import edge against persisted plus earlier accepted import edges. Cycle-producing edges become the same deterministic open `unresolved_dependency` reviews without weakening the store triggers, catching broad SQLite errors, emitting notifications, or rolling back unrelated confident records. The focused persisted phase-and-ticket RED/GREEN evidence is `/tmp/rr08-fix2-persisted-cycle-{red,green}.log`; the production change passed on the first implementation attempt in this round.
- Fix-round 2 verification: Fresh importer and Store verification at `/tmp/rr08-fix2-final-tests.log` passed 26/26 tests (10 importer, 16 Store) with zero failures/skips. The configured signed Debug build at `/tmp/rr08-fix2-final-build.log` succeeded, and strict deep codesign verification at `/tmp/rr08-fix2-codesign.log` reported the app valid on disk and satisfying its designated requirement. `git diff --check` passed before the code commit.
- Required fix round 3: Additive schema version 5 persists one explicit active phase per project in `project_active_phases`, with composite same-project foreign-key integrity and a phase lookup index. Migration backfills only projects that have exactly one phase; multi-phase projects remain unset. A confident imported `activePhaseId` becomes authoritative, a real first agent-created sole phase initializes the relationship without later replacement, sample data selects its phase explicitly, and the dashboard no longer guesses from row order. Projects without a valid explicit active phase remain visible with a truthful `No active phase` projection and no board. Active-phase RED is `/tmp/rr08-active-phase-red.log`; the first implementation attempt failed because updating `projects` caused SQLite foreign-key evaluation to touch the transaction-protected audit table. The materially different normalized-table attempt passed all 7 focused cases at `/tmp/rr08-active-phase-green-2.log`; unsuccessful active-phase attempts: 1.
- Required fix round 3 artifact boundary: Preview now opens the canonical authorized root once and traverses exact `docs/delivery/dashboard-status.json` components with descriptor-relative `openat`, `O_DIRECTORY`, `O_NOFOLLOW`, and `O_CLOEXEC`. It verifies regular-file type and size with `fstat` on the opened descriptor and performs the maximum-plus-one bounded read from that same descriptor, closing every descriptor on all paths. There is no pathname reopen after validation. The two within-root component/final symlink regressions failed against the old implementation at `/tmp/rr08-secure-reader-red.log`; those cases plus the existing escape and oversize cases passed at `/tmp/rr08-secure-reader-green.log`; unsuccessful descriptor-reader implementation attempts: 0.
- Fix-round 3 verification: Fresh importer, Store, Dashboard Projection, Agent Bridge, and Onboarding verification at `/tmp/rr08-active-secure-final-tests.log` passed 53/53 tests with zero failures/skips. The configured signed Debug build at `/tmp/rr08-active-secure-final-build.log` succeeded. Strict deep verification at `/tmp/rr08-active-secure-codesign.log` reported `com.rekonlabs.ReleaseRadar` valid on disk, satisfying its designated requirement, and signed by the configured Apple Development identity. `git diff --check` passed before the code commit.
- Reviews: Initial Code Reviewer requested 3 Required fixes; the first re-review accepted 2 and retained the persisted-cycle issue closed in round 2. Round 3 closed the newly reported explicit-active-phase and artifact TOCTOU findings. Final independent Code Review ACCEPT: 0 Required, 0 Optional, 0 Out of scope. QA ACCEPT: 0 Required and one unchanged optional direct malformed/cardinality test suggestion that does not block this slice. Architect ACCEPT: 0 Required/Optional/Out of scope and no ADR or deviation. Security/privacy ACCEPT: 0 Required/Optional/Out of scope.
- Controller verification: A fresh isolated run of the importer, Store, Dashboard Projection, Agent Bridge, and Onboarding suites exited successfully with all selected tests passing. The worktree and `git diff --check` remained clean before this gate update.
- Decisions/risks: The existing Rekon project was inspected read-only only to confirm the stable field and evidence-path shapes; acceptance uses a copied synthetic fixture and never imports owner project data. This is a one-time seed, not ongoing synchronization. The owner database was not opened, inspected, migrated, or repaired in round 3. No notification delivery, UI integration, live Codex attachment, arbitrary Markdown inference, or owner database recovery was introduced.
- Next eligible task: RR-09 — app-owned Pushover and notification history.

### RR-09 release gate

- TPM: GO; RR-08 is accepted with all Required importer, active-phase, cycle, and artifact-boundary findings closed. The approved degraded RR-05 live-state semantics remain explicit and do not block app-owned notification delivery.
- Delivery Manager: GO; RR-08 commits, bounded remediation attempts, controller verification, signed package, and four independent acceptances are durable. RR-09 is dependency-safe and released to one Implementer with no concurrent writer.

### RR-09 — App-owned Pushover alerts and notification history

- Status: Accepted. RR-10 is released.
- Commits: `02a71fb` (`feat: add durable Pushover alerts`), `361fb2c` (`docs: record RR-09 verification`), `8781860` (`fix: isolate durable notification dispatch`), `c8b8866` (`fix: coordinate app notification delivery`), and `c701434` (`fix: serialize notification work cycles`).
- Scope: Added atomic meaningful-event occurrence tracking and a durable notification outbox for linked goal blocked, agent completion/review, and ticket/import Needs Review entry. Identical replay and relaunch do not duplicate an occurrence; leaving and re-entering an eligible state opens a new occurrence. Paused linked goals and all events before the first dashboard open remain silent.
- Delivery boundary: The app stores Pushover credentials as two non-synchronizable `WhenUnlockedThisDeviceOnly` Keychain items and sends only fixed, app-derived title/message text to the fixed HTTPS `api.pushover.net` endpoint. The outbox durably records `attempt_started` before transport; an interrupted in-flight attempt becomes visible `unknown` on launch and is never retried automatically. Provider failures are sanitized, visible, and non-blocking; raw provider bodies, agent reasons, goal text, paths, and imported content are not copied into the notification record or request.
- UI: Notifications is a full-width persisted history with explicit queued, sending, unknown, sent, and failed states. The existing Notifications sidebar badge remains the single count surface; the menu-bar view shows recent alert state without a second bell/count. Existing Connections and Notifications settings tabs now expose configuration state, device-only storage guidance, and save/remove controls.
- TDD: Core notification RED/GREEN evidence is `/tmp/rr09-core-{red,green-attempt1}.log` (7/7 GREEN). Focused import, projection, completion, redirect-boundary, and migration RED/GREEN evidence is `/tmp/rr09-import-{red,green}.log`, `/tmp/rr09-projection-{red,green-2}.log`, `/tmp/rr09-completion-{red,green}.log`, `/tmp/rr09-redirect-{red,green}.log`, and `/tmp/rr09-store-migration-green.log`; each focused GREEN passed. Fake transport coverage directly observes the durable attempt marker before transport, terminal failure projection, ambiguous-attempt recovery without retry, occurrence deduplication/re-entry, pause and onboarding silence, sanitized copy, fixed endpoint, and redirect rejection.
- Implementer verification: Fresh combined Notification, Rekon Import, Agent Bridge, Store, Review/Graph, Dashboard Projection, and App Route verification passed 73/73 selected tests with zero failures/skips at `/tmp/rr09-final-affected-tests.log`. An isolated configured Debug build succeeded at `/tmp/rr09-final-build.7sqiIL` using the configured Apple Development identity; strict deep codesign reported the app valid on disk and satisfying its designated requirement. Build/signature evidence is `/tmp/rr09-final-signed-build.log`, `/tmp/rr09-final-codesign.log`, `/tmp/rr09-final-signing-identity.log`, and `/tmp/rr09-final-entitlements.log`. Final diff checks passed.
- Attempts: One unsuccessful product implementation attempt occurred when the initial notification projection expression did not compile; the localized correction passed on the next run. The redirect credential-boundary regression and all other production behaviors passed on their first implementation attempt. The stale schema-version expectations and incomplete synthetic migration fixture were test-fixture corrections, not product remediations.
- Initial independent reviews: Code Review REJECT with 5 Required findings and no Optional findings: competing app dispatchers can misclassify a live attempt as crash-ambiguous; ticketless review/import events are excluded from every visible history/count surface; bridge-created events do not refresh cached app projections; direct sidebar board/overview navigation can leave first-open suppression active; and cross-project goal/occurrence identity is unsafe. QA REJECT with 5 Required findings and no Optional findings: the signed sandbox lacks outbound-network client entitlement; bridge replies await a potentially 20-second send despite the tool's 10-second deadline; ticketless events are invisible; occurrence identity is not project-scoped; and the explicit successful-send replay/relaunch acceptance proof is absent. Overlapping findings are one remediation scope, not duplicate requirements.
- Required fix round 1 scope: Use one coordinated app-owned dispatch owner; perform crash recovery only at a true launch boundary and prevent concurrent callers from reclassifying live attempts. Return bridge results immediately after the committed mutation and schedule notification delivery separately, then refresh the affected project's cached notification history/badge/menu state on the main app model. Scope activity by `notification_events.project_id`, including ticketless review/import failure rows. Persist first-dashboard-open for every actual project dashboard entry path and sequence it before later eligibility. Reject cross-project goal ownership and project-scope occurrence keys/fingerprints/deactivation. Add the sandbox outbound-network client entitlement. Add focused regressions for these seams and one successful send that remains exactly one across recreated store/dispatcher and replay/relaunch.
- Required fix round 1 result: Commits `8781860` and `c8b8866` closed ticketless visibility, model refresh, direct-route first-open sequencing, project identity, nonblocking bridge reply, outbound-network entitlement, and successful replay/relaunch evidence. Independent QA ACCEPTED all scoped cases. Code re-review retained 2 Required concurrency findings: launch recovery can suspend before its recovery transaction and overlap ordinary dispatch, reclassifying a newly live attempt as `unknown`; and a callback arriving during an in-flight send can return without scheduling a rescan, stranding an event committed after the first pending-ID snapshot. This is the first unsuccessful remediation attempt for the dispatcher-concurrency workstream.
- Required fix round 2 scope: Serialize launch recovery against all ordinary dispatch work, and coalesce concurrent dispatch requests so any event queued while transport is in flight is drained before the dispatcher becomes idle. Add direct blocking-transport regressions for both launch-recovery overlap and a second newly inserted event during the first blocked send. Preserve all accepted round-1 behavior. This is the second and final allowed remediation attempt for this workstream under the owner stop rule.
- Required fix round 2 result: The dispatcher now runs launch recovery and ordinary dispatch through one actor-owned work cycle. A launch request takes priority at the next safe boundary; a dispatch request arriving during recovery is drained only after recovery finishes, while a request arriving during an in-flight send sets a wake flag that forces another pending-event scan before the worker becomes idle. The deterministic recovery barrier proves a pre-existing interrupted attempt becomes `unknown` while the newly requested send remains live and reaches `sent`; the blocking transport proves a distinct event committed during the first send is also delivered exactly once without a later trigger. This final remediation implementation passed both direct regressions on its first product attempt.
- Required fix round 2 verification: Compile RED for the injected barrier is `/tmp/rr09-fix2-concurrency-red-compile.log`; behavioral RED is `/tmp/rr09-fix2-concurrency-red.log`. Direct GREEN is `/tmp/rr09-fix2-concurrency-green.log` (2/2), and preserved Notification, App Route, Review/Graph, and Agent Bridge suites passed 38/38 with zero failures/skips at `/tmp/rr09-fix2-preservation-green.log`. The isolated configured Debug build succeeded at `/tmp/rr09-fix2-build.dZh9ve`; strict deep codesign verification passed, and `/tmp/rr09-fix2-entitlements.plist` contains `com.apple.security.network.client = true`. No third architecture or remediation attempt was used.
- Required fix round 1 accepted behavior: One production `AppNotificationCoordinator` owns launch recovery, pending dispatch, and activity refresh. Ordinary and concurrent dispatch never recover a live attempt; only launch preparation converts a pre-existing `attempt_started` row to `unknown`. The bridge returns the committed command result before scheduling notification delivery, and the app model refreshes persisted notification history, sidebar count, and menu data through its observable activity cache. Ticketless events project by their persisted project ID. Every project-scoped route awaits first-dashboard-open persistence before navigation completes. Goal ownership is rejected across projects, and occurrence identity, fingerprints, deactivation, and the version-7 backfill are project-scoped. The sandbox now includes outbound-network client access.
- Fix-round TDD and verification: RED evidence is `/tmp/rr09-fix1-storage-red.log`, `/tmp/rr09-fix1-concurrency-red.log`, `/tmp/rr09-fix1-launch-boundary-red.log`, and `/tmp/rr09-fix1-app-boundary-red.log`. Focused GREEN evidence is `/tmp/rr09-fix1-storage-green.log` (16 notification tests), `/tmp/rr09-fix1-app-boundary-green5.log` (bridge reply and reactive model tests), and `/tmp/rr09-fix1-affected-green.log` (53 affected tests, zero failures/skips). The isolated configured build passed at `/tmp/rr09-fix1-build.0E4mtc`; strict deep code-sign verification passed, and `/tmp/rr09-fix1-entitlements.plist` contains `com.apple.security.network.client = true`.
- Fix-round attempts: Dispatcher/storage behavior passed on the first product implementation attempt. The app-coordinator change required one compile correction for an invalid optional binding and then passed its behavioral tests; later test-source concurrency and selected-project fixture corrections were test corrections, not product remediation attempts. No finding reached the two-attempt stop threshold.
- Final reviews: Code re-review ACCEPT, Required 0, Optional 0; both retained concurrency findings are closed with no missed-wakeup, duplicate-send, recursion, livelock, or launch-idempotency defect identified. QA ACCEPT, Required 0, Optional 0; fresh direct and preservation verification passed and the signed app retained outbound-network entitlement. Architect ACCEPT, Required 0, Optional 0, no ADR/deviation; final ownership, transaction, migration, coordination, bridge, and projection contracts conform to ADR-001. Security/privacy ACCEPT, Required 0, Optional 0; scoped credential, transport, sanitization, isolation, concurrency, signing, and helper-boundary checks passed without real credentials or network delivery.
- Controller verification: A fresh isolated build-and-test run at `/tmp/rr09-controller-final` passed the selected Notification, Agent Bridge Transport, App Route, Store, Agent Bridge, Project Activity, and Review/Graph suites with `** TEST SUCCEEDED **`. Strict deep codesign reported the test-host app valid on disk and satisfying its designated requirement; its effective entitlements contain `com.apple.security.network.client = true`. `git diff --check` passed and the worktree remained clean.
- Decisions/risks: Notification dispatch remains app-owned; the bridge helper/tool receive neither Keychain credentials nor SQLite access. No live Pushover credential or network send is used in acceptance testing; transport behavior is verified with deterministic fakes and the production client's request/redirect boundary. No owner database was intentionally inspected or repaired. Initial pre-fix hosted app tests could instantiate the prior default `AppModel` store at Application Support before the test body; mandatory store injection now removes that path, and all subsequent verification used temporary databases. No recovery flow, live Codex attachment, or RR-10 scope is changed.
- Next eligible task: RR-10 — final failure-state integration, recovery boundary, complete seven-surface UI flow, and signed MVP delivery.

### RR-10 release gate

- TPM: GO; RR-09 is accepted with every Required durability, visibility, isolation, nonblocking, entitlement, and concurrency finding closed within the owner stop rule.
- Delivery Manager: GO; RR-09 feature and remediation commits, controller verification, signed entitlement evidence, and four independent final acceptances are durable. RR-10 is dependency-safe and released to one Implementer with no concurrent writer.

### RR-10 legacy-schema stop-rule recovery

- Status: Accepted for RR-10 integration.
- Commits: `da748b8` (`fix: reject incomplete legacy schemas`), `2f1ba85` (`fix: validate critical schema metadata`), and `d53e36f` (`fix: require canonical cycle triggers`).
- Stop-rule handoff: The original repair work stopped after repeated compile failure. Its first independent review then rejected presence-only schema recognition because malformed version-3 and version-7 databases could be repaired and stamped current. A later oversized validator attempt was stopped and removed. This bounded recovery replaced it with one compact versioned manifest covering every authoritative table and ordered column plus the critical dependency-cycle triggers and migration indexes.
- Scope and safety: Existing databases are snapshotted before any migration or recognized repair. Repair remains limited to the known version-3 missing `thread_attribution` signature and the observed version-7 missing structured audit scope/normalized active-phase signature. Recognized source shapes must otherwise be complete; migrated and already-current databases must match the full version-7 manifest, with only the known harmless legacy `projects.active_phase_id` extra allowed, and must pass `foreign_key_check`. Repairs remain additive and exclusive, active-phase backfill joins project and phase identity, and unknown shapes remain typed unavailable with rollback, original database, and pre-migration snapshot intact. No owner database was opened, inspected, reset, or modified.
- Verification: `/tmp/rr10-exact-schema-recovery-tests.log` passed 22/22 selected cases with zero failures/skips: all four `EndToEndAcceptanceTests` and all 18 `StoreAcceptanceTests`. The two malformed source-shape regressions prove missing core tables fail closed without mutating either original or snapshot; the two recognized repair cases still relaunch available. The version-4 migration test now uses a complete version-4 fixture rather than a partial schema.
- Required fix round 1: Independent review found that column and object-name validation did not prove trigger semantics, index metadata, or declared project-boundary foreign keys. RED `/tmp/rr10-metadata-semantics-red.log` failed all three counterfeit fixtures. The first implementation attempt added only normalized required fragments for the four recursive cycle triggers, exact table/uniqueness/ordered-column/direction metadata for the four critical indexes, and a compact per-table manifest of required foreign-key signatures and delete actions. Direct GREEN `/tmp/rr10-metadata-semantics-green-attempt1.log` passed 3/3.
- Required fix round 1 verification: `/tmp/rr10-metadata-semantics-final-tests.log` passed 25/25 selected cases with zero failures/skips: all seven `EndToEndAcceptanceTests` and all 18 `StoreAcceptanceTests`. Counterfeit/no-op trigger, wrong-column index, and missing composite active-phase foreign-key fixtures each open typed unavailable while the original and pre-migration snapshot retain the malformed schema and seeded delivery data.
- Required fix round 2/final attempt: Independent re-review found that required SQL fragments could be spoofed inside comments while `WHEN 0` disabled the trigger. RED `/tmp/rr10-canonical-trigger-red.log` proved the deceptive trigger was accepted. The four canonical trigger definitions are now the single source used both by version-1 creation and whitespace/case-normalized full stored-SQL equality, so comments or any semantic variation fail closed. The first implementation attempt passed without a formatting correction; direct GREEN is `/tmp/rr10-canonical-trigger-green-attempt1.log`.
- Required fix round 2 verification: `/tmp/rr10-canonical-trigger-final-tests.log` passed 26/26 selected cases with zero failures/skips: all eight `EndToEndAcceptanceTests` and all 18 `StoreAcceptanceTests`. The deceptive disabled version-3 trigger opens typed unavailable while the original and pre-migration snapshot retain `WHEN 0`, schema version 3, missing audit attribution, and seeded delivery data.
- Scope evidence: the final canonical-trigger diff is `+132/-89`, including the 42-line regression; `StoreMigrations.swift` changes by a net one line to 744 because the canonical definitions replace the four duplicated migration definitions. No parser, behavior probe, broader validator, formatting correction, Optional active-phase scope change, UI work, or owner-database access was used.
- Final independent reviews: Code Reviewer ACCEPT — Required 0, Optional 0, Out of scope 0 (`/tmp/rr10-trigger-final-code-review.log`). QA ACCEPT — Required 0, Optional 0, Out of scope 0, with a fresh 26/26 EndToEnd and Store run. Architect GO — Required 0, Optional 0, no ADR/deviation, and a safe normal signed owner launch. Security/privacy GO — Required 0, Optional 0, and a safe normal signed owner launch. Canonical triggers, exact index and foreign-key metadata, the full-schema manifest, snapshots, and typed-unavailable behavior are accepted.
- Next eligible work: RR-10 final integration, signed package verification, and seven-surface acceptance evidence.

### RR-10 — Final integration and signed MVP evidence

- Status: Accepted and release-ready. Required blockers 0.
- Commits: `4a2166d`, `f49b5e8`, `da748b8`, `131a6cb`, `2f1ba85`, `5b573e7`, `d53e36f`, `9e31809`, `cf1d230`, and `c12afb1` delivered recovery, failure-state integration, isolated capture, and evidence. Final blocker corrections are `88d90f9` (truthful project onboarding with no normal-launch sample seed), `1e3416a` (recognized artifact import and same-session agent-defined first phase), `2d0749e` (protected onboarding review markers), and `271fcd4` (globally reserved marker IDs with collision rollback). Capture arguments are Debug-only and use isolated app data; normal Debug and Release launches never seed sample delivery/runtime/notification state.
- Owner launch and recovery boundary: A fresh configured signed Debug build completed `clean build`, passed strict deep code-sign verification, and was launched normally exactly once as `com.rekonlabs.ReleaseRadar`. Accessibility inspection showed the Projects dashboard with the persisted Rekon Pursuit project rather than a typed unavailable state. The app was then terminated cleanly before a minimal read-only SQLite metadata check. The current database passed integrity checking at schema version 7 with all four required structured audit columns, `project_active_phases`, all 11 required notification columns, one project, and 31 tickets. Its recoverable `.pre-migration` snapshot also passed integrity checking at version 7 with one project and 31 tickets while retaining the legacy absence of structured audit scope and active-phase metadata. Both files had the same `2026-08-24T07:44:15-0400` modification time, so the recognized repair had already been applied before the authorized normal launch; the launch confirmed the repaired store remained available and did not perform a second repair. No owner database was reset, deleted, or manually mutated.
- Required service scenarios: One fixture-backed run passed 15/15 selected tests with zero failures/skips: all eight `EndToEndAcceptanceTests` plus seven cases spanning typed agent transition/replay, onboarding reconciliation, scoped cached observation, import persistence and missing-evidence relaunch, and exactly-once notification replay/relaunch. Result bundle: `DerivedData/Logs/Test/Test-ReleaseRadar-2026.08.24_08-32-56--0400.xcresult`.
- Seeded UI acceptance: Computer Use drove one isolated seeded capture bundle across Projects, Overview, Phase Board and ticket detail, Needs Review, Dependencies, Activity, Notifications, and tab-style Settings at full and compact widths. Accessibility evidence confirmed the expanded and collapsed rails, both badges, Full outcomes and Compact IDs board presentations, all five lanes, selected ticket relationships, review actions, persisted activity with truthful Codex-unavailable context, persisted Pushover history, and Settings tabs. The seven primary surface images are `docs/delivery/evidence/rr10-projects-overview-board-detail.png`, `rr10-needs-review.png`, `rr10-dependencies.png`, `rr10-activity.png`, `rr10-notifications.png`, `rr10-onboarding-failure.png`, and `rr10-settings.png`; `rr10-board-compact.png` is the additional 921×697 responsive proof. The primary board/detail and other main-surface captures are 1499×768; Settings uses its natural 660×548 window.
- Onboarding/failure evidence: A distinct empty-store bundle used `--rr10-capture --rr10-empty-store` against isolated app data. Accessibility exposed `failure-no-structure`, “No delivery structure yet,” and the real “Choose Project Folder…” recovery action. No synthetic UI data, owner path, private Codex data, live credential, or real Pushover send was used.
- Interim implementer verification: `/tmp/rr10-final-all-tests.log` recorded 112 passing tests before the final blocker regressions were added. The authoritative final controller result superseding it is 122/122 passed, zero failures/skips, and `** TEST SUCCEEDED **` at `/private/tmp/release-radar-final-271fcd4-tests/Logs/Test/Test-ReleaseRadar-2026.08.24_10-02-23--0400.xcresult`.
- Signing and helper boundary: Strict verification reports the app, `ReleaseRadarAgentTools`, and `ReleaseRadarBridgeAgent` valid on disk and satisfying their designated requirements (`/tmp/rr10-final-codesign-{app,helper,bridge}.log`). All three use the configured Apple Development identity, team `2UA854NLX4`, and hardened runtime. The app retains sandbox, read-only user-selected file, app-group, and outbound-network client entitlements; the helper retains only its application identifier; the bridge retains sandbox plus the app group. No normal owner relaunch was performed for this final non-launching build.
- Attempts and cleanup: The capture-isolation regression followed RED/GREEN and passed again after the Debug-only argument guard. One visual recapture reused compact window restoration and was discarded; the changed-condition recapture used a fresh bundle identifier and produced the verified 1499×768 Full outcomes image. A shell cleanup request was rejected before execution and replaced with recoverable exact-path cleanup. All capture derived data was inspected for unintended source/evidence content and moved to Trash; no generated build directory is staged or retained in the repository.
- Final onboarding acceptance: Normal launches show truthful empty onboarding; existing projects retain Add Project; recognized Rekon artifacts are previewed and imported only after explicit consent; uncertain records remain in Needs Review. Pending projects remain resumable and excluded from ordinary dashboards until a first phase exists and owner finish completes. A bridge already running before folder authorization can accept the agent-defined first phase without restart. Reserved onboarding markers cannot be created, overwritten, resolved, dismissed, or preclaimed cross-project by agent commands, and collision failures roll back without repair. Completion returns to Projects without auto-opening the dashboard.
- Final independent gates: Code Reviewer ACCEPT — Required 0, Optional 0, Out of scope 0, with 45/45 focused tests. QA ACCEPT — release blockers 0, with 17/17 focused tests. Architect GO — Required 0, Optional 0, Out of scope 0, no ADR. Security/privacy GO — Required 0, Optional 0, Out of scope 0. TPM GO — Required blockers 0. Delivery Manager PRODUCT GO — Required product blockers 0.
- Visual evidence: All seven primary surface screenshots plus `rr10-board-compact.png` were independently inspected and accepted. They cover Projects/Overview/Phase Board/detail, Needs Review, Dependencies, Activity/goal state, Notifications, onboarding/failure states, Settings, and compact responsive behavior.
- Release artifact: `build/release-271fcd4/ReleaseRadar-271fcd4.zip`, SHA-256 `09aad61cec2b7aacb95232689a881a6b2c46844e1acef1848d42ec2c98656813`. The unpacked `ReleaseRadar.app` passes strict deep code-sign verification, is version 0.1.0 (1), arm64, targets macOS 14+, uses Apple Development team `2UA854NLX4`, and has hardened runtime. It is a local owner-install build, not a notarized general-distribution artifact.
- Accepted limitation and next phase: Supported live Codex attachment remains unavailable, so the UI truthfully presents unavailable or authorized cached-stale context and never promotes it to formal delivery state. General notarization/distribution, the nonblocking Xcode warnings, and any supported authenticated Codex attachment are next-phase work, not MVP release blockers.

### Next phase — V1 brand production

- Status: Partially complete. The deterministic production AppIcon is accepted under RR-R6; wordmark/typeface and light/dark lockups remain backlog candidates.
- References: `docs/brand/release-radar-icon-v1.png`, `docs/brand/release-radar-lockup-v1.png`, and `docs/brand/README.md`.
- Remaining scope: deterministically recreate the technical/architectural wordmark, settle the production typeface/outlines, and export light/dark lockups. Do not repeat the accepted AppIcon asset-catalog work.
- Guardrail: generated raster drafts remain references only and must not be shipped directly or visually redesigned without owner review.

## 2026-08-25 — Post-MVP reported-defect remediation intake

- Status: Preimplementation gate approved; no remediation implementation has begun and no reported defect is recorded as fixed.
- Live runtime: Computer Use is available and directly inspected the running Debug build at `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/DerivedData/Build/Products/Debug/ReleaseRadar.app`, bundle identifier `com.rekonlabs.ReleaseRadar`.
- Verified findings: the built app has no production icon; Add Project has no visible dismiss action although Escape closes it; structure-less active repositories cannot complete onboarding through the current request-marker-only first-phase path; alert rules are static rather than interactive; the wide board says “Full outcomes” while the narrow board says “Compact IDs,” creating unclear density UX; the inspected ticket has no linked goal and ticket outcomes do not provide meaningful TL;DR content; Dependencies materially diverges from `docs/design/mockups/dependencies.png`; and Needs Review decisions fail with “Folder not authorized.”
- Plan and mapping: `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` controls the bounded work. RR-R1 covers visible Cancel/reset and open-existing without duplicates; RR-R2 covers fail-closed folder reauthorization and review recovery; RR-R3 covers exact ticket-goal identity and authoritative outcome/TL;DR copy; RR-R4 covers persisted alert-rule toggles and event suppression; RR-R5 covers Dependencies selected-path presentation and explicit board density; RR-R6 covers the deterministic production AppIcon.
- Independent plan gates: Planning GO; Architecture GO; QA/test GO; TPM GO; Delivery Manager GO. The plan is scoped, test-first, serialized, and uses the existing repository tools and ledger.
- Product-decision gate: completing onboarding for a repository with no usable delivery structure remains independently gated. The app must not invent a phase, parse Markdown as delivery authority, create a repository-backed manifest, or add owner-facing manual phase editing. Resolution requires an explicit owner choice plus matching design/ADR approval for either a supported outbound agent-request integration or a narrowly defined owner-created first phase. This gate does not block RR-R1 through RR-R6.
- Baseline verification: `xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-baseline-derived` passed. Existing nonblocking warnings remain for optional `.none`, test actor isolation, and signed-binary stripping.
- Release decision: RR-R1 is dependency-safe and released to one fresh Implementer with no concurrent writer. RR-R2 through RR-R6 remain closed until their recorded dependency and independent-review gates are satisfied.

### RR-R1 — Cancellable Add Project and existing-project routing

- Status: Accepted in the current working diff; this supersedes the intake's preimplementation status for RR-R1. No commit has been created.
- Implemented scope: Add Project now has a visible, accessible Cancel action that resets transient onboarding state; the always-inline empty-state onboarding does not render an inert Cancel. Selecting the canonical root of a completed project exposes Open existing project and routes through the established project-opening path without preparing or duplicating durable project state.
- Controller verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r1-controller -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests` passed 11/11 with zero failures/skips. Only the pre-existing optional-`.none`, test actor-isolation, and signed-binary stripping warnings remain.
- Code review: Initial Required finding — the inline onboarding surface rendered a Cancel with no callback. The optional `onCancel` correction removed that inert control while retaining the sheet action; independent re-review ACCEPT, Required 0.
- QA: ACCEPT. Computer Use verified the alternate signed build at `/tmp/release-radar-rr-r1-qa-app/Build/Products/Debug/ReleaseRadar.app`, bundle identifier `com.rekonlabs.ReleaseRadar.RR1QA`. The inline surface had no inert Cancel; sheet `onboarding-cancel` dismissed with Escape and click; Cancel after populating the form reopened clean; `onboarding-open-existing` activated with Return and click and routed to Overview. The seeded isolated QA store remained unchanged before and after repeated open-existing actions at 2 projects, 1 root, 1 bookmark, and 2 onboarding audits, proving no duplicate; owner application data was untouched.
- Architecture: APPROVED, Required 0; the completed-project identity remains a read-only projection over canonical root ownership, open onboarding markers, and persisted phase existence. No ADR change is required.
- Security/privacy: PASS, Required 0. Cancel performs no durable write; a healthy existing bookmark remains unchanged; stale authorization continues to fail closed. Open-existing uses the established navigation path, including its already-defined first-dashboard-open audit when applicable; no new authorization or audit authority was introduced.
- Product-decision gate: Structure-less onboarding remains unresolved and independent. RR-R1 does not invent a phase, parse Markdown as delivery authority, create a repository-backed manifest, or add manual phase editing.
- Delivery Manager: GO. RR-R1 is accepted with all Required findings closed and no owner-data mutation. TPM has returned GO and released RR-R2 as the next serialized writer.

### RR-R2 — Folder-authorization recovery

- Status: In progress; not accepted. The initial implementation's focused verification passed 36/36 tests, but independent review REJECTED it with two Required findings: cross-project recovery authorization leakage and post-commit refresh failure being misreported as a failed decision, which could prompt a duplicate retry. A fresh fix Implementer is assigned to the bounded remediation.
- Runtime-isolation incident: The original Implementer launched the normal `com.rekonlabs.ReleaseRadar` bundle despite intending to isolate it with `CFFIXED_USER_HOME`, and the run touched the owner database. The Implementer manually reversed the identified project root, bookmark, two audits, command record, and review status, then deleted the backup. No bookmark bytes are recorded here.
- Controller follow-up: A later read-only audit found the owner database structurally available with integrity OK, schema version 7, 1 project, 31 tickets, 0 project roots, 0 project bookmarks, 6 open review items, and no audits or notification events after 03:20. The database modification time changed; byte-for-byte restoration and proof that no unrelated state changed are unavailable.
- Evidence disposition: All runtime evidence from the original Implementer is invalid because isolation failed. Independent QA subsequently used the alternate bundle `com.rekonlabs.ReleaseRadar.RR2QA`; owner database metadata remained unchanged during that isolated verification.
- Delivery gate: NO-GO until a fresh Implementer closes both Required review findings and the corrected implementation receives independent code, QA, architecture, security/privacy, TPM, and Delivery Manager acceptance. RR-R3 remains closed.

#### RR-R2 fix round 1 and final gate

- Status: Accepted in the current working diff; no commit has been created. This final gate supersedes the prior RR-R2 NO-GO while preserving the runtime-isolation incident, invalidated evidence, and owner-database uncertainty above.
- Required findings closed: The fresh fix Implementer restricted the review dispatcher registry to the target project's currently resolved canonical root, closing cross-project recovery leakage. A committed review decision is now projected locally before refresh; refresh failure presents “Saved; refresh needed” with an explicit do-not-retry instruction, closing the false-failure and duplicate-retry risk. The fixer launched no application runtime.
- Controller verification: The fresh focused Onboarding, App Route, and Review/Graph acceptance run at `/tmp/release-radar-rr-r2-controller` passed 38/38 with zero failures/skips. `git diff --check` passed.
- Code review: ACCEPT, Required 0; both fix-round findings are closed in the current source.
- QA: ACCEPT. The prior valid live flow used isolated bundle `com.rekonlabs.ReleaseRadar.RR2QA`; a fresh current-source rerun passed the same 38/38 focused cases. Owner-container metadata remained untouched during independent QA.
- Architecture: APPROVED, Required 0. The project-local authorization capability, explicit same-root reauthorization versus first-root association, scoped audit behavior, and post-commit refresh semantics conform to the amended `docs/architecture/ADR-001-release-radar-boundaries.md`.
- Security/privacy: PASS, Required 0. Bookmark material remains local and undisclosed; authorization fails closed; only the target project's verified root reaches the decision dispatcher; unsuccessful recovery performs no review decision; balanced scope access and distinct bounded recovery audits are retained.
- Delivery Manager: GO. RR-R2 is accepted with all implementation Required findings closed. The earlier owner-database incident remains a documented residual uncertainty rather than valid product evidence. RR-R3 is the next serialized writer, pending TPM release confirmation.

### RR-R3 — Exact ticket-goal identity and meaningful ticket outcomes

- Status: Accepted in the current working diff; no commit has been created.
- Implemented scope: Additive schema version 8 persists one exact `(project, ticket, thread, goal)` relationship with composite project-local integrity and one-to-one uniqueness for both ticket and goal. The ambiguity-safe v7 backfill links only an unambiguous ticket/thread/goal identity and otherwise leaves legacy records unlinked and unchanged. The typed `linkGoal` command, ticket detail, ticket-attributed Activity, and blocked-goal notification projection now consume only that exact identity. Fresh dashboard seed tickets use descriptive outcome/TL;DR copy; persisted owner outcomes are not rewritten.
- Controller verification: A fresh isolated command covering Store, Agent Bridge, Dashboard Projection, Notification, and End-to-End acceptance passed 71/71 with zero failures/skips at `/tmp/release-radar-rr-r3-controller`. The configured Debug build succeeded. Only the pre-existing optional-`.none`, test actor-isolation, and signed-binary stripping warnings remain.
- Required fix round 1: Initial independent review found that reusing an existing goal-link ID could move the link to a different valid ticket while auditing only the new ticket. A fresh fixer made link identity stable: an existing ID must retain its original project and ticket, while a same-ticket goal update remains supported. The compact regression observed RED at exit 65, GREEN at exit 0, and proves rejection preserves the original link, audit count, and durable replay count. Fresh focused and End-to-End preservation verification passed 8/8; build and `git diff --check` passed. The fix launched no runtime and accessed no owner data.
- Code review: ACCEPT, Required 0. The stable-link identity finding is closed; no remaining required regression or scope issue was found.
- QA: ACCEPT, Required 0. Current-source verification passed 71/71. Computer Use independently inspected the alternate signed bundle `com.rekonlabs.ReleaseRadar.RR3QA`: descriptive ticket outcomes were visible; the verified ticket link, Activity identity, and blocked notification used the exact approved goal; and an unlinked ticket remained truthfully labeled `No linked goal`. The isolated database was schema version 8 with a clean foreign-key check. The owner bundle and owner data were not used.
- Architecture: APPROVED, Required 0. The implementation conforms to the exact one-to-one identity and ambiguity-safe migration contract recorded in `docs/architecture/ADR-001-release-radar-boundaries.md`; no further ADR change is required.
- Security/privacy: PASS, Required 0. Cross-project, wrong-thread, cross-ticket goal reuse, and cross-ticket ID reassignment fail transactionally without link, audit, or replay writes. Existing owner-authored outcomes remain unchanged.
- TPM: GO, Required blockers 0. RR-R3 is dependency-complete and RR-R4 may proceed under the corrected brief.
- Delivery Manager: GO. RR-R3 is accepted with all Required findings closed and proportionate isolated evidence. No normal application runtime or owner database was accessed during implementation, controller verification, or the stable-link fix.

### RR-R4 release gate — Persisted alert-rule controls

- Planning: GO. The tracked historical detailed brief is `docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-4-brief.md`; the durable accepted scope is recorded in this gate and the implementation/final-gate section below.
- Architecture: GO, Required 0. Additive schema version 9 follows RR-R3's accepted version 8; the app-owned settings/store boundary and existing notification ownership remain intact.
- QA/test: GO, Required 0. The plan proportionally covers exact defaults and reopen, all six event mappings, suppression before notification writes, underlying delivery/audit preservation, reciprocal blocked/paused lifecycles, authoritative UI failure/relaunch/accessibility behavior, and isolated runtime verification without new test infrastructure.
- Security/privacy: GO, Required 0. Rules remain non-secret local preferences; only the owner app can update them; actual changes create one bounded unscoped owner audit; disabled rules create no notification occurrence, event, dispatch attempt, or notification Activity; the bridge and credentials remain unchanged.
- TPM: GO, Required blockers 0. RR-R4 is dependency-safe after RR-R3 acceptance and the corrected independent plan reviews.
- Delivery Manager: GO. RR-R4 is released to one fresh Implementer with no concurrent writer. The Implementer must not launch the normal owner bundle or access owner data; live acceptance must use an alternate isolated bundle. RR-R5 and RR-R6 remain closed until their recorded dependencies and independent gates are satisfied.

#### RR-R4 implementation and final gate

- Status: Accepted in the current working diff; no commit has been created.
- Implemented scope: Additive schema version 9 owns an exact constrained four-row `alert_rules` set. Migration defaults are blocked linked goals on, agent completion/review on, Needs Review on, and paused goals off. The owner app loads and updates the authoritative snapshot directly; actual changes create the bounded unscoped owner audit, while failed and no-op updates create none. All six meaningful event kinds map exhaustively to the four rules, and suppression occurs before notification occurrence, event, attempt, and notification-Activity writes without rolling back the underlying delivery/import/observation mutation or its existing audit. Blocked and paused occurrences remain reciprocal even while their alert rule is disabled.
- TDD and controller verification: The initial focused RED failed on the absent rule authority and UI/model APIs. Initial GREEN passed 57/57 Store, Notification, and App Route acceptance cases, covering v8-to-v9 migration/default/reopen behavior, exact schema and loader rejection, audit behavior, six-event suppression, reciprocal occurrence state, and authoritative model failure/persistence behavior. After the Required retroactive-alert fix below, fresh current-source affected verification passed 85/85 with zero failures/skips; the configured alternate build and `git diff --check` also passed. Existing optional-`.none`, test actor-isolation, and signed-binary stripping warnings remain nonblocking and out of scope.
- Required fix round 1: Initial independent review found that suppression only inside enqueue left no occurrence evidence for a disabled entry, so re-enabling could make a stable same-state observation or stable-ID upsert create a retroactive alert. A fresh fixer gated enqueue on a genuine producer creation or state entry for linked goals, ticket transitions, review requests, completion records, and imported review items while keeping delivery mutations, audits, and exit deactivation unconditional. The focused regressions observed RED, then GREEN 3/3; producer-boundary preservation passed 71/71. Stable state after re-enable now remains silent until a new real entry.
- QA: ACCEPT, Required 0. Computer Use exercised the alternate signed app at `/tmp/release-radar-rr-r4-qa-build.sL7zrK/Build/Products/Debug/ReleaseRadar.app`, bundle identifier `com.rekonlabs.ReleaseRadar.RR4QA`. All four Toggles exposed authoritative accessible values; changes persisted across relaunch; a delayed update disabled every control while in flight; and an injected update failure retained the prior value, showed recoverable failure, and succeeded only on explicit retry. The final Settings capture is `/tmp/release-radar-rr-r4-qa-settings-final.png`.
- Independent reviews: Code Reviewer ACCEPT, Required 0; QA ACCEPT, Required 0; Architect APPROVED, Required 0 and no ADR change required; Security/privacy PASS, Required 0; TPM GO with Required blockers 0. The retroactive-alert Required finding is closed without expanding the agent bridge, credentials, provider, or settings authority.
- Isolation and residual risk: Implementation, controller verification, fix work, and live QA did not launch the normal owner bundle or access owner application data. The prior RR-R2 runtime-isolation incident and owner-database uncertainty remain recorded above and are not altered by this acceptance.
- Delivery Manager: GO. RR-R4 is accepted with all Required findings closed and proportionate persistence, audit, failure, accessibility, relaunch, and event-suppression evidence.

### RR-R5 planning/review gate — Dependencies and board density UX

- Status: Preimplementation gate accepted; implementation is released to one fresh serialized Implementer. RR-R6 remains closed.
- Historical brief and durable mockup inspection: `docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-5-brief.md` is tracked point-in-time evidence. Planning and Delivery Management independently inspected `docs/design/mockups/dependencies.png` and `docs/design/mockups/phase_board.png`, both 1586 x 992. The durable accepted Dependencies target is the mockup's selected-path-only four-column hierarchy (`Foundations`, `Accepted work`, `Selected ticket`, `Unlocks next`), phase-ticket count, five-lane plus dependency/blocking-path legend, directional connectors with non-color-only blocked emphasis, selected-node treatment, and right-side inspector with selected-ticket, direct/indirect requirement, and unlock detail. The accepted Phase Board target is an explicit `Card density` control with exact `Full outcomes` and `Compact density` choices while retaining the five canonical lanes and truthful card constraint metadata.
- Responsive and accessibility gate: Wide acceptance is 1586 x 992 points with a 220-point expanded sidebar, right-side Dependencies inspector, and both board-density choices exercised. Compact acceptance is 900 x 650 points with the same sidebar, the full selected path retained, the inspector stacked below the graph, all five board lanes recoverable without overlap, and requested full cards visibly compacted when lane width is at or below 180 points. Minimum recovery is 760 x 520 points; keyboard and scroll access must expose every graph column, inspector section, lane, and card without clipped actionable controls. Required captures cover both surfaces at wide and compact sizes, plus minimum size only when behavior differs. Accessible nodes must name ID, lane, blocker count, selection, and column role; connector relationships must have inspector text equivalents; compact cards must retain full outcomes in accessibility labels; the density value must disclose a temporary width override.
- Deterministic and failure checklist: Layout includes exactly the selected ticket, its indirect and direct prerequisites, and direct unlocks; lexical column membership, visible frames, and in-path connectors are stable; unrelated and cross-phase branches are absent. A ticket with no relations shows only itself with explicit empty relationship sections. Density is view-local, defaults to full, restores the owner's local full choice after widening, and may truthfully reset when the board is recreated. Narrow content scrolls/stacks rather than clipping. No screenshot-test infrastructure, preference persistence, new ticket field, graph mutation, or delivery transition is authorized.
- Independent preimplementation reviews: Planning GO; Architecture GO, Required 0; QA/test GO, Required 0; TPM GO, Required blockers 0; Delivery Manager GO. The brief contains the required focused selected-path and density regressions, RED/GREEN sequence, exact responsive matrix, live visual/accessibility checklist, isolated alternate-bundle constraint, non-happy-path behavior, and completion evidence without disproportionate test machinery.
- Security/privacy disposition: A separate Security/Privacy preimplementation review is not required because RR-R5 is presentation-only over existing in-memory read-only projections and view-local state. It creates no SQLite row, bookmark, bridge request, audit, notification, credential access, permission change, or owner-data fixture. Any implementation that adds persistence, bridge/permission access, owner-data access, or another security boundary exceeds the accepted brief and returns the task to NO-GO pending a new gate and independent Security/Privacy review.
- Delivery Manager: GO. RR-R4 is accepted, no concurrent writer is authorized, and RR-R5 is released to one fresh Implementer owning only the bounded Dependencies/Phase Board files and focused existing test suites named in the brief. The Implementer must not launch `com.rekonlabs.ReleaseRadar` or access owner data; any live check must use an alternate isolated bundle/container. Independent Code Review, QA visual/responsive/accessibility verification, Architecture review, TPM, and Delivery Management remain required before acceptance. RR-R6 remains closed.

#### RR-R5 implementation and final gate

- Status: Accepted in the current working diff; no commit has been created. Dependencies now presents only the selected ticket, its direct and indirect requirements, and its direct unlocks in the approved deterministic four-column hierarchy with relationship connectors and a responsive inspector. Phase Board now exposes the exact view-local `Full outcomes` and `Compact density` choices, applies a truthful width-forced compact presentation at lane widths of 180 points or less, and restores the requested full presentation after widening. No projection, schema, persistence, audit, notification, bridge, permission, or owner-data behavior changed.
- TDD and controller evidence: The initial RED failed because the selected-path column contract, connector blocking metadata, and `BoardDensity` did not exist. Initial GREEN passed the focused Review/Graph and Dashboard Projection suites 20/20. After the Required fix below, fresh current-source verification again passed 20/20 with zero failures/skips at `/tmp/release-radar-rr-r5-fix1-final-tests.log`; the alternate configured build, strict deep codesign verification, and `git diff --check` passed. Existing optional-`.none`, test actor-isolation, App Intents metadata, and signed-binary stripping warnings remain nonblocking and out of scope.
- Required fix round 1: Initial independent review reported two Required Phase Board findings: the stacked layout clipped selected-ticket detail at 760 x 520, and the macOS Picker exposed the requested `Full outcomes` value without disclosing that compact cards were actually displayed at narrow width. A fresh fixer placed the five-lane workspace and selected-ticket detail in vertical recovery scrolling while preserving horizontal lane recovery, and exposed the effective compact override plus automatic wide-width restoration through the density control's accessibility value and help. The compact regression observed RED at `/tmp/release-radar-rr-r5-fix1-red.log`; the corrected focused suite produced the final 20/20 GREEN above. Both findings are closed without expanding scope.
- Live QA: ACCEPT, Required 0. Computer Use exercised the isolated alternate bundle `com.rekonlabs.ReleaseRadar.RR5FixQA`. Exact wide evidence is `/tmp/release-radar-rr-r5-wide-dependencies-1586x992.jpeg`, `/tmp/release-radar-rr-r5-wide-board-full-1586x992.jpeg`, and `/tmp/release-radar-rr-r5-wide-board-compact-1586x992.jpeg`. Compact evidence is `/tmp/release-radar-rr-r5-dependencies-900x650.jpeg` and `/tmp/release-radar-rr-r5-fix-board-900x650.jpeg`. Minimum 760 x 520 board recovery, including the separately scrolled selected-ticket detail, is shown by `/tmp/release-radar-rr-r5-fix-board-min-top.jpeg` and `/tmp/release-radar-rr-r5-fix-board-min-detail.jpeg`. QA verified the selected-path hierarchy and inspector, both density choices, truthful forced-compact accessibility value, restoration after widening, and scroll access to the five lanes and selected-ticket detail.
- Independent reviews: Code Reviewer ACCEPT, Required 0; Architecture APPROVED, Required 0 and no ADR/deviation; QA ACCEPT, Required 0; TPM GO, Required blockers 0. The two initial Required findings are closed in current source.
- Security/privacy and isolation: The accepted implementation remains presentation-only over existing in-memory read-only projections and view-local density state. It creates no persistence, audit, notification, bridge request, bookmark, permission, credential, graph mutation, or owner-data fixture, so the approved no-separate-security-review disposition remains valid. Implementation and QA did not launch the normal owner bundle or access owner application data. The prior RR-R2 incident and residual owner-database uncertainty remain unchanged above.
- Delivery Manager: GO. RR-R5 is accepted with all Required findings closed and proportionate current-source, exact-size live visual, responsive, accessibility, build, and no-write evidence. RR-R6 may enter granular planning and independent plan review only; RR-R6 implementation remains closed until those gates are durably accepted.

### RR-R6 planning/review gate — Production AppIcon

- Status: Corrected preimplementation gate accepted; one fresh serialized Implementer is released. RR-R5 is accepted, no concurrent writer is authorized, and post-implementation acceptance remains closed.
- Historical brief and durable references: `docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-6-brief.md` is tracked point-in-time evidence. The accepted icon and icon mockup remain byte-identical 1254 x 1254 PNGs with SHA-256 `b94fb5b029dd262cfb9e196efdf089fb3d72aee76d433ebfd448cc26691f7ddd`; `full_logo.png` remains 1968 x 799 with SHA-256 `cb7ba41ca0aeb58e7cbd1d680b4fca10d84facaaf38550a72b0f9105ed56ba78`. A changed hash is an immediate Planning/Design stop condition.
- Exact implementation scope: hand-author one deterministic SVG in the approved V1 direction; export seven lossless PNGs that supply the exact ten macOS AppIcon rows; add only their `Contents.json` and explicit app-only asset-catalog/project wiring; add only the narrow Debug capture predicate/model guard needed for privacy-safe visual QA; and extend only the existing compact App Route launch-policy regression. The wordmark, generated reference rasters, new dependencies/scripts, generalized capture or collaborator infrastructure, persistence/audits, bridge/folder behavior, release packaging, and unrelated product code remain out of scope.
- Explicit app Resources contract: use unused file/build IDs `A10000000000000000000018` and `B10000000000000000000007`; exclude `Assets.xcassets` from implicit synchronized membership through `A90000000000000000000001`; add the explicit build file only to app Resources phase `C10000000000000000000003`; and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` only in app Debug/Release configurations `A50000000000000000000053` and `A50000000000000000000054`. The catalog/setting must not reach Core, helpers, bridge, tests, `Info.plist`, or entitlements.
- Compiled-artifact acceptance: source dimension checks do not prove delivery. A fresh configured bundle must select `AppIcon`, contain `Assets.car` and a parseable `AppIcon.icns`, and expose exactly ten filtered `assetutil` `Icon Image` tuples mapping the seven source filenames across the required scales and dimensions; the `MultiSized Image` summary is excluded. Generated raster references must be absent. Strict nested signing and the existing identifier, team, Apple Development authority, hardened runtime, sandbox, and effective entitlements must remain unchanged; this is not a Developer ID/notarization claim.
- Debug capture privacy seam: the alternate bundle identifier is container evidence, not traditional Keychain isolation. A default-false `externalServicesSuppressed` predicate may become true only for Debug plus `--rr10-capture`, must drive the existing AppDelegate capture guard, and may cause `AppModel` to skip only Pushover configuration loading and pending notification dispatch. Normal Debug/Release startup and dashboard/store/UI loading remain unchanged. The focused regression must prove the predicate matrix and untouched queued-event/attempt state. Independent QA alone may launch a never-before-used alternate bundle with `--rr10-capture --rr10-empty-store`, verify its empty notification tables, and inspect Finder, Dock, and About through Computer Use; no owner bundle, Keychain item, container, database, folder authorization, or notification delivery is permitted.
- Independent preimplementation reviews: Planning GO; Architecture GO, Required 0 and no ADR; QA/test GO, Required 0; Security/privacy GO, Required 0; TPM GO, Required blockers 0. The corrected resource wiring, exact CAR tuple contract, small-size fidelity matrix, configured non-launching build evidence, and privacy-safe live-capture seam are sufficient and proportional.
- Delivery Manager: GO. Release one fresh Implementer for only the recorded scope, with no concurrent writer. The Implementer may run source tests and configured non-launching builds but must not launch a bundle or access owner data. Any change to signing, entitlements, `Info.plist`, bundle identity/default startup, Keychain/coordinator APIs, packaging, owner data, or broader product behavior returns RR-R6 to NO-GO. Independent Code Review, QA visual/artifact/privacy verification, Architecture, Security/Privacy, TPM, and Delivery Management remain required before final remediation acceptance. The prior RR-R2 runtime-isolation incident and residual owner-database uncertainty remain unchanged above.

#### RR-R6 implementation and final remediation gate

- Status and scope: Accepted in the current uncommitted working diff; no commit, packaged release, Developer ID distribution, or notarization has been created or claimed. The app target now owns the deterministic production AppIcon and the narrowly approved Debug capture-suppression seam. `Info.plist`, entitlements, production/default startup, persistence, bridge/folder behavior, and notification/Keychain implementations remain unchanged.
- Deterministic asset evidence: `docs/delivery/archive/sdd/2026-08-25-release-radar-remediation/task-6-report.md` records the exact geometry, renderer/tool versions, source-to-catalog mapping, RED/GREEN evidence, and artifact checks. Current-source SHA-256 values are SVG `83058fa6702b530f5ccd1a8851615db046aea45607c1e254cec920013e1e15fc`; PNG 16 `96f728e31ac046ad67e41b83c76e348a204cb0e78d977e5bb03fa1ba42df9303`; PNG 32 `ca1d66664a36007c512edc6001e802fc732b7ac2358c7008d945d94ea942004a`; PNG 64 `24126e45d935f4966bca80adfa7f1cbdadbf87267ae57fe585babe5f0db37c31`; PNG 128 `2465ed35531ee4e0e43e003563d4d5f8bc7e4c1489efe51920ba3ae8d88c672a`; PNG 256 `20e24cdd1a469c41d4195c1f7e83424b54950bbb001870d8661f3eefed91208c`; PNG 512 `455892a0384c1cb5b854ae2cb1ceedf16c64a171dee6b36db9581aeaa76af7c9`; and PNG 1024 `fc2e48cf435a4b6015843a2770872da7033f0a3020a63e8311e408589bddaaa1`.
- Compiled artifact evidence: the configured app selects `AppIcon`, contains `Assets.car` and a parseable `AppIcon.icns`, and exposes exactly ten filtered CAR `Icon Image` tuples from the seven SVG-derived PNGs: `AppIcon-16.png|1|16|16`, `AppIcon-32.png|1|32|32`, `AppIcon-32.png|2|32|32`, `AppIcon-64.png|2|64|64`, `AppIcon-128.png|1|128|128`, `AppIcon-256.png|1|256|256`, `AppIcon-256.png|2|256|256`, `AppIcon-512.png|1|512|512`, `AppIcon-512.png|2|512|512`, and `AppIcon-1024.png|2|1024|1024`. The app-only PBX assertions, compiled `CFBundleIconFile`, absent reference rasters, and clean build are recorded in the task report.
- Test evidence: the focused Debug-capture launch-policy/coordinator suite passed 15/15 with no failures or skips at `/tmp/release-radar-rr-r6-final-test.2YeUco/Logs/Test/Test-ReleaseRadar-2026.08.25_02-51-34--0400.xcresult`. A final controller run over current combined source passed 146/146 with no failures or skips at `/tmp/release-radar-remediation-final/Logs/Test/Test-ReleaseRadar-2026.08.25_03-05-31--0400.xcresult`.
- Signing and privacy evidence: strict nested signing passed for configured and alternate artifacts. Effective identity remains Apple Development `PT7GS96H3L`, team `2UA854NLX4`, hardened runtime, App Sandbox, app group, read-only user-selected folder access, outbound network, and expected Debug `get-task-allow`. Debug plus `--rr10-capture` alone suppresses Pushover configuration lookup and pending dispatch; ordinary Debug and Release behavior remains unchanged. Independent Security/Privacy found no Required issue and verified app-only resource wiring, ten compiled icon renditions, unchanged source entitlements/Info.plist, no bundled reference raster, and no owner credential, database, folder, or provider access.
- Live QA: ACCEPT, Required 0. Computer Use exercised only `/tmp/release-radar-rr-r6-qa-alt/Build/Products/Debug/ReleaseRadar.app`, identifier `com.rekonlabs.ReleaseRadar.RR6QA`, with the approved capture/empty-store arguments. The fresh alternate container and empty notification state were verified. Finder and standard About visibly presented the production identity; captures are `/tmp/rr-r6-finder-list.png`, `/tmp/rr-r6-finder-icon-24.png`, `/tmp/rr-r6-finder-icon-64b.png`, and `/tmp/rr-r6-about.png`. Direct Dock targeting timed out in the UI bridge, so Dock screenshots are not claimed as acceptance evidence; QA and TPM classified that tooling limitation as nonblocking because Finder/About live evidence, the signed bundle, and the exact compiled icon matrix establish the delivered asset without a demonstrated Dock defect.
- Independent final reviews: Code Reviewer ACCEPT, Required 0; QA ACCEPT, Required 0; Architecture APPROVED, Required 0 and no ADR/deviation; Security/Privacy PASS, Required 0; TPM GO, Required blockers 0.
- Isolation and residuals: RR-R6 implementation, verification, and live QA did not launch the normal owner bundle or access owner application data. The structure-less-project onboarding path still requires the separately recorded explicit owner choice and matching design/ADR approval. The historical RR-R2 incident remains unchanged: the owner database's key counts and integrity were restored, but byte-for-byte restoration and proof that no unrelated state changed remain unavailable.
- Delivery Manager: GO. RR-R6 is accepted and the RR-R1-through-RR-R6 remediation milestone is closed in the current working diff. This closes the approved defect-remediation scope only; it is not a commit, packaged release, notarization, or authorization to bypass the two residual gates above.

### RR-R7 planning/release gate — Empty-workspace route safety and Release handoff

> **Historical interim gate.** Later integration, SQLite-23 repair, packaging,
> installation, and final Delivery decisions supersede the status and release
> statements in this subsection. RR-R7 is not an open separate writer; its
> route/sidebar work is included in the combined artifact awaiting owner
> validation.

- Historical status and dependency gate: At that time, the corrected
  preimplementation brief was accepted, no RR-R7 product code had been
  implemented, and RR-R7 was treated as the sole dependency-safe writer under
  the historical remediation plan. Later integration and acceptance consumed
  that release; it creates no current writer eligibility.
- Reproduction and root cause: Computer Use reproduced the defect only in the isolated `com.rekonlabs.ReleaseRadar.RR6QA` empty-store bundle at `/Users/jroberts/Desktop/Products/Debug/ReleaseRadar.app`: the sidebar exposed a fabricated `Current project` group and project routes, and selecting one surfaced `Delivery data unavailable — SQLite error 19: FOREIGN KEY constraint failed`. The isolated QA database subsequently passed integrity and foreign-key checks, excluding corruption. Current source confirms the runtime chain: `currentProjectID` falls back to `DashboardSampleData.projectID`; `SidebarView` renders project routes even when `currentProject` is nil; `navigate(to:)` calls `markDashboardOpened` for that nonexistent project; and its audited transaction violates the project foreign key. The owner bundle and owner database were not used for this reproduction.
- Historical scope, gates, and evidence contract: The recorded implementation
  boundary, independent reviews, RED/GREEN checks, isolated live QA, signing,
  and Release-handoff requirements below were the accepted RR-R7 contract.
  They are retained as delivery evidence, not instructions for a current
  Implementer. The later combined artifact satisfied and superseded this gate.
- Historical exact scope and exclusions: The Implementer was permitted to
  modify only `ReleaseRadar/App/AppModel.swift`,
  `ReleaseRadar/Navigation/SidebarView.swift`, and
  `ReleaseRadarTests/AppRouteTests.swift`. Admission of a project-scoped route
  had to require exact membership in the successfully loaded dashboard before
  any audit; a rejected route returned to Projects without `dashboardError`;
  valid project navigation retained the existing one owner/dashboard-open
  audit and first-open/notification behavior; and the sidebar project group
  existed only when `currentProject` existed. No schema/migration, owner-data
  access or repair, recorder semantics, route-enum change, sample-ID synthesis,
  onboarding policy change, UI-test target, packaging script, unrelated
  navigation refactor, bundle/entitlement identity change, Desktop QA deletion,
  notarization, Developer ID, App Store, auto-update, or other-user installation
  was authorized.
- Historical independent plan gates: Planning GO after incorporating the exact
  empty-store suppression fixture, valid-project loaded-dashboard audit control,
  and pinned Release handoff checks; Architecture GO, Required 0 and no ADR,
  with dashboard membership as the unchanged route-admission boundary; QA/test
  GO with all three Required brief corrections closed; TPM GO, Required
  blockers 0; Delivery Manager GO. Post-implementation acceptance required a
  fresh Code Reviewer, independent QA, Architect, Security/Privacy signing
  verifier, TPM, and Delivery Manager; the Implementer could not approve its
  own work.
- Historical RED/GREEN and integration evidence contract: retain the exact
  focused RED showing the pre-fix nonexistent-project navigation failure, then
  GREEN for that regression and all `AppRouteTests`. The empty fixture had to
  use `externalServicesSuppressed: true` and prove zero projects, nil current
  project, fallback to Projects, no global error, and unchanged audit count.
  The strengthened valid-project control first had to load the dashboard and
  prove exactly one `release-radar-owner` / `Open project dashboard` audit while
  preserving first-dashboard-open, notification eligibility, and selected-route
  behavior. The full suite and a clean configured build also had to pass; no
  new harness was authorized.
- Historical live and handoff evidence contract: independent QA had to use an
  alternate isolated Debug capture and compare accessibility plus screenshot
  evidence directly with `docs/design/mockups/onboarding_state.png`, proving a
  usable Projects/onboarding surface, no fabricated project heading/routes, no
  `failure-delivery-data` or SQLite error, responsive recovery, and no owner-data
  access. Only `/tmp/ReleaseRadar-RR7-Release/Build/Products/Release/ReleaseRadar.app`
  could be the staged handoff source. Before and after copying it to
  `/Applications/ReleaseRadar.app`, the contract required strict nested signing,
  `com.rekonlabs.ReleaseRadar`, Release configuration, AppIcon metadata, Apple
  Development identity, Hardened Runtime, sandbox/effective entitlements, and
  absence of `com.apple.security.get-task-allow`. Any build, signing, identity,
  icon, or entitlement failure blocked copying and had to leave the last known
  destination untouched. The Release artifact was not to be launched against
  owner data and was not claimed as notarized or suitable for third-party
  distribution.
- Historical Delivery Manager decision: A fresh RR-R7 Implementer was released
  at that time with no concurrent writer. That decision is fully consumed; no
  current or later writer is opened by this subsection.

### Existing-project onboarding — historical task split and preimplementation gate

> **Historical delivery record.** Attach Folder is classified Completed above.
> The later combined-artifact and SQLite-23 owner-validation gates supersede
> every writer-release and conditional-acceptance statement in this section.
> Nothing here establishes current eligibility.

- Historical status and sequencing: The owner prioritized this slice on
  2026-08-25. At that time, fresh controller reconciliation passed all 16
  `AppRouteTests` at
  `/tmp/release-radar-rr-r7-reconcile/Logs/Test/Test-ReleaseRadar-2026.08.25_08-19-53--0400.xcresult`,
  all ephemeral read-only role processes had exited, and **Attach Folder to
  Existing Project** was released as the sole product writer. Later integration
  and acceptance consumed that release; RR-R7 packaging is not deferred by this
  section now.
- Validated workflow split: **Attach Folder to Existing Project** authorizes an existing persisted rootless project and must call `FolderProjectOnboarding.associateFirstProjectRoot` directly. **Import Existing Project** creates a new project only from the portable archive approved in ADR-001; it does not reuse or relabel the partial Rekon seed importer.
- Source verification: `ReleaseRadarCore/Import/RekonArtifactImporter.swift` reads only schema-version-1 `docs/delivery/dashboard-status.json` and its preview omits the complete supported project graph. The repository contains no authoritative `docs/delivery/dashboard-status.json`, portable `.release-radar-project.json`, exporter, or exporter-produced fixture; the only matching dashboard JSON is a synthetic test fixture. Markdown plans, task briefs, handoffs, and this ledger remain non-authoritative for complete-project import.
- Historical dependency order: The accepted order at that time was (1)
  reconcile the RR-R7 baseline and record gates; (2) record portable archive v1
  in ADR/design; (3) implement and independently accept Attach Folder; (4)
  separately plan and approve an authoritative exporter plus exporter-produced
  fixture; (5) implement and verify the portable importer/UI; and (6) produce a
  Release Radar archive before importing this repository. Steps 1–3 are
  historical; current B2/B3 status above controls the still-blocked remainder.
- Attach task brief — objective and outcome: Add Project exposes the exact **Attach Folder to Existing Project** label, lists only established persisted projects with no open onboarding marker, root, or bookmark, lets the owner select one project and one folder, names both in confirmation, preserves all existing delivery/goal/dependency/review/history state, and returns to a refreshed Projects surface with the target selected.
- Attach scope and interfaces: Reuse `associateFirstProjectRoot`; do not call onboarding `inspect`, `prepare`, `requestFirstPhaseDefinition`, `finish`, either importer, Markdown discovery, or marker creation. The app boundary distinguishes committed success from committed-but-refresh-failed, remains on Projects, selects the target, and does not open a dashboard or create a dashboard-open audit. Cancellation, Escape, chooser cancellation, and standard sheet close before confirmation perform no write; interactive dismissal is disabled while the confirmed transaction is in flight.
- Attach persistence, privacy, and failure behavior: The only durable additions are one canonical root, one fresh non-stale local bookmark, and one path-free project-scoped `release-radar-owner` / `Associate first project folder authorization` audit. Canonical/symlink-equivalent ownership, root-only/bookmark-only/already-associated state, missing project, invalid folder, stale/mismatched/denied authorization, and repeated submission fail closed without repair or partial write. Owned-folder errors direct the owner to choose another folder; already-associated state directs to existing reauthorization. A refresh failure says the folder was attached and must not be retried, with Reload recovery.
- Attach test-first acceptance: Characterize the existing service before UI changes with a populated rootless-project snapshot covering project, active phase, phases, tickets, both dependency types, blockers, evidence, exclusions, observed threads/goals, thread/ticket-goal links, reviews, completions, notification/occurrence history, prior audits, unrelated-project state, command requests, and alert rules. Prove only the root/bookmark/audit delta, relaunch persistence, balanced security-scope access, and rollback for ownership and authorization failures. True RED application cases cover the missing labelled workflow, project selection, confirmation, refresh/select behavior, and saved-but-refresh-failed recovery. Use only existing XCTest/temp-store patterns and the repository-native Xcode commands.
- UI and live acceptance: Use a never-before-used alternate Debug bundle/container and isolated database with external services suppressed. Accessibility and screenshots must verify the exact attachment label, eligible-project list, project/folder confirmation, actionable failures, Cancel/Escape/standard close, in-flight dismissal protection, refresh/selection, relaunch persistence, and responsive hierarchy at wide, about 900 x 650, and 760 x 520 against `docs/design/mockups/onboarding_state.png`. Never launch the owner bundle, inspect owner data, read Keychain, start the bridge, or dispatch notifications.
- Historical independent preimplementation gates: Planning, Architecture, QA,
  Security/Privacy, TPM, and Delivery Management released Attach at that time;
  the portable importer remained blocked without an exporter fixture. Those
  decisions are preserved as evidence and create no current writer release.
- Portable archive v1: ADR-001 defines the stable-ID, create-only, single-root complete portable graph; strict source validation and unchanged-source rule; fresh destination bookmark; reject-without-remapping collisions; atomic project/graph/root/bookmark/audit commit; excluded device-local/operational state; and prohibition on Markdown, Rekon seed JSON, repository state, or SQLite copies. Importer implementation is blocked until an authoritative exporter produces the acceptance fixture.
- Completion evidence required here: RED/GREEN commands, complete-graph preservation and exact delta, rollback cases, no onboarding/import/dashboard-open side effects, cancellation and committed-refresh-failure behavior, isolated live accessibility/screenshots, relaunch authorization, full-suite/build results, independent Code Review/QA/Architecture/Security/TPM/Delivery decisions, risks, and next eligible task.

#### Existing-project onboarding implementation and historical gate

- Historical status and scope: **Attach Folder to Existing Project** was
  implemented and independently reviewed. Its then-conditional live-observation
  gate was superseded by later integration and acceptance. **Import Existing
  Project** remains blocked and unimplemented under the current inventory.
- Implementation boundary: Add Project now opens as a singleton native macOS window titled `Add Project`, so Cancel, Escape, and the standard red close control are visible and functional. Folder panels use the nonblocking AppKit completion API. The distinct attachment workflow lists persisted projects with no root, bookmark, or open onboarding marker, names the selected project and folder before confirmation, and routes only through `FolderProjectOnboarding.associateFirstProjectRoot`. It does not call onboarding `inspect`, `prepare`, `requestFirstPhaseDefinition`, or `finish`; either importer; Markdown discovery; marker creation; or dashboard-open behavior. The pre-existing partial Rekon path is explicitly labelled as a new-project seed artifact rather than portable import.
- Persistence, recovery, and audit evidence: Focused acceptance coverage proves the existing project graph and unrelated state are preserved; the only committed delta is one canonical root, one fresh non-stale bookmark, and one path-free project-scoped `release-radar-owner` / `Associate first project folder authorization` audit. Relaunch authorization succeeds. Symlink-equivalent ownership, root-only/bookmark-only/already-associated states, invalid authorization, and ownership conflicts fail closed with rollback. App refresh selects the attached project without opening its dashboard, and committed-but-refresh-failed state directs the owner to Reload without retrying the transaction.
- Test and build evidence: The final focused `OnboardingAcceptanceTests` plus `AppRouteTests` run passed 39/39 with no failures or skips at `/tmp/release-radar-existing-attach-controller/Logs/Test/Test-ReleaseRadar-2026.08.25_08-59-45--0400.xcresult`. The current combined suite passed 154/154 with no failures or skips at `/tmp/release-radar-existing-onboarding-full/Logs/Test/Test-ReleaseRadar-2026.08.25_08-54-30--0400.xcresult`. A fresh configured Release build succeeded at `/tmp/release-radar-existing-onboarding-release/Build/Products/Release/ReleaseRadar.app`; strict nested signature verification passed with identifier `com.rekonlabs.ReleaseRadar`, Apple Development identity and team `2UA854NLX4`, and hardened runtime.
- Live isolated evidence: Computer Use exercised only the alternate bundle `com.rekonlabs.ReleaseRadar.AttachQA2` with `CFFIXED_USER_HOME=/tmp/release-radar-attach-qa.b5Woo9` and external services suppressed. It directly verified the native Add Project title/window, red close, visible Cancel, Escape dismissal, exact `Attach Folder to Existing Project` label, eligible `Rekon Pursuit` selection, native folder picker, and responsive layouts at approximately 760 x 520 and 900 x 650. After Cancel, Escape, and red-close exercises, the isolated database still contained zero project roots, zero bookmarks, and zero association audits. The owner bundle, owner database, Keychain, bridge, and notification delivery were not used.
- Independent final reviews: Code Reviewer GO, Required 0; Architecture GO, Required 0 and no additional ADR required; Security/Privacy GO, Required 0; QA **CONDITIONAL GO**, Required 0; TPM **CONDITIONAL GO**; Delivery Manager **CONDITIONAL GO**. The earlier reviewer concern that the approved Rekon seed importer was being exposed as portable import was closed by explicit new-project seed labelling and a fresh independent GO review.
- Historical residual evidence limitation: Computer Use lost the application
  accessibility connection after `NSOpenPanel` closed, so this slice did not
  directly observe the final live confirmation and return-to-Projects state.
  That limitation no longer controls task eligibility and does not reopen
  Attach Folder.
- Current portable import blocker: **Import Existing Project** remains
  **NO-GO** until Release Radar has an authoritative exporter and an
  exporter-produced `.release-radar-project.json` acceptance fixture for the
  complete ADR-001 archive graph. Repository Markdown, the partial
  `docs/delivery/dashboard-status.json` Rekon seed format, repository state,
  and SQLite copies are not authoritative portable import sources. No RR-R7
  packaging writer or other product writer is released by this historical
  section.

### Initialize Project Tracking — owner decision and implementation-plan gate

- Owner decision — 2026-08-25: Replace owner-facing “first phase” onboarding
  with **Initialize Project Tracking**. Use a truthful human-mediated handoff:
  Release Radar saves a resumable pending project and shows the exact path-free
  prompt recorded in the design/remediation plan. The owner pastes it into a
  Codex task rooted at the folder. The app does not launch, contact, paste into,
  submit to, or otherwise control Codex.
- Required copy affordance: icon-only overlapping squares
  (`square.on.square`), accessibility label **Copy Codex prompt**, visible and
  accessibility-announced success/failure, and disclosure that only the prompt
  is copied and remains on the clipboard until replaced. No folder path,
  bookmark, project content, or secret is copied. The future Help section is
  deferred. Portable Import remains hidden and blocked by its exporter/archive
  gate.
- Validated split: Task 7A first reproduces the exact SQLite-23 statement or
  records isolated current-source non-reproduction, then adds truthful
  nothing-saved versus saved-seed-incomplete persistence outcomes without
  weakening the `audit_events` authorizer. Task 7B adds the explicit
  Initialize/Attach landing, confirmation, saved/waiting/resume hierarchy, and
  copyable prompt while preserving Attach persistence.
- Plan gates: independent Planning delivered the complete two-slice test-first
  brief. Architecture **CONDITIONAL GO** after pinning the exact reproduction,
  saved-incomplete, no-automatic-action, and design-record requirements. TPM
  **CONDITIONAL GO** and confirms no owner decision remains. Fresh QA/test,
  Delivery Manager, and Security/Privacy plan review remain required; no
  Implementer is released.
- Current process blocker: a fresh QA reviewer could not be created because
  the built-in collaboration runtime reported `agent thread limit reached`
  while retaining completed/interrupted agent identities. The primary agent
  did not reuse the Planning agent or substitute its own review. This is a
  process gate only; it does not change the product plan or authorize a writer.
  Resume these missing independent plan gates in a context with fresh role
  capacity before implementation.
- Resumed independent plan reviews — 2026-08-25: Fresh QA/test **GO** for Task
  7A and Task 7B's plan, with 7B contingent on independent 7A acceptance;
  Required 0, Optional evidence refinements only. Fresh Security/Privacy
  **GO** for Task 7A and Task 7B's plan on the same dependency; Required 0,
  Optional authorizer negative-control and pasteboard failure-state evidence
  only. Fresh Delivery Management found the two-slice plan sound and held its
  final 7A release only until these QA/Security reviews and the explicit Attach
  limitation disposition below were durable. Task 7B remains closed until 7A
  is accepted and its fresh five-role release gate is recorded.
- Attach live-observation disposition — 2026-08-25: The final native-picker
  confirm-and-return step is explicitly accepted as a tooling/evidence
  limitation, not claimed as directly observed and not treated as a
  demonstrated product defect. The accessibility connection consistently
  disconnects when `NSOpenPanel` closes; direct isolated acceptance tests
  nevertheless cover the committed root/bookmark/audit delta, rollback,
  relaunch authorization, refresh, and selection, while isolated live checks
  cover the workflow entry, exact label, picker, Cancel, Escape, red close,
  responsive layouts, and their no-write behavior. Fresh QA and Delivery both
  accept this narrow disposition; the prior TPM conditional GO was conditioned
  solely on the same documented gap. This closes Attach's conditional
  QA/TPM/Delivery gate for the purpose of releasing 7A, but does not waive
  7B's own live verification or permit a claim that the missing Attach step was
  visually observed.
- Pre-7A controller baseline — 2026-08-25: The unchanged combined source ran
  all `OnboardingAcceptanceTests` in fresh DerivedData
  `/tmp/release-radar-7a-baseline.EuaopI` and passed 20/20 with no failures or
  skips; result bundle
  `/tmp/release-radar-7a-baseline.EuaopI/Logs/Test/Test-ReleaseRadar-2026.08.25_13-01-13--0400.xcresult`.
  Existing acceptance coverage did not reproduce SQLite error 23. This is only
  a baseline; Task 7A's four-state statement/caller/authorizer reproduction
  gate remains mandatory before any policy or caller change.
- Task 7A release — 2026-08-25: Delivery Management **GO** after re-reading the
  durable fresh QA/Security reviews and Attach limitation disposition. The
  Architecture/TPM conditions are pinned in the approved brief and remain
  binding. Release one fresh 7A Implementer as the sole product writer, first
  performing the isolated four-state SQLite-23 investigation. Task 7B, RR-R7
  packaging, Help, and portable import remain closed. Post-implementation
  acceptance requires fresh independent Code Review, QA, Architecture,
  Security/Privacy, TPM, and Delivery decisions.
- Task 7A implementation and acceptance — 2026-08-25: **Accepted** in the
  current uncommitted combined working diff. The bounded delta adds
  `OnboardingPreparationError.seedApplicationFailedAfterSave(ProjectID)` and
  catches only post-base `RekonArtifactImporter.apply` failure while preserving
  the source-compatible `prepare(_:) -> ProjectID` signature. Acceptance tests
  add successful base-state/no-automatic-action/relaunch/repository-sentinel
  coverage, recognized-seed saved-incomplete/zero-partial-import coverage, and
  pre-commit bookmark-failure rollback/repository preservation. No Task 7A
  change touched `SQLiteConnection`, store/schema policy, importer scope,
  Attach, bridge, notifications, or UI.
- Task 7A SQLite-23 gate: An isolated temporary diagnostic exercised fresh,
  pending, pending-with-phase-request, and pending-with-project-scoped-audit
  states through the current `FolderProjectOnboarding.prepare` SQL path. Both
  retained 1/1 runs passed at
  `/tmp/release-radar-7a-investigation.Kjn2S9/Logs/Test/Test-ReleaseRadar-2026.08.25_13-05-00--0400.xcresult`
  and
  `/tmp/release-radar-7a-investigation.Kjn2S9/Logs/Test/Test-ReleaseRadar-2026.08.25_13-05-23--0400.xcresult`.
  SQLite error 23 did not reproduce, so there is no denied statement or
  authorizer action/argument tuple; no policy or caller was changed, and no
  bundle-mismatch claim is made because bundle provenance was not separately
  established. The historical report remains an accepted non-reproduction,
  not proof that another bundle was responsible.
- Task 7A TDD and behavioral evidence: RED at
  `/tmp/release-radar-7a-red.kYDHnt/Logs/Test/Test-ReleaseRadar-2026.08.25_13-07-38--0400.xcresult`
  failed on the missing `OnboardingPreparationError`. GREEN proves successful
  initialization adds exactly one project, root, fresh bookmark, open pending
  marker, and prepare audit, with zero phase-request markers/audits, phases,
  command requests, notification events, or occurrences. A changed recognized
  seed after preview returns the durable project identity, retains only that
  base delta, and adds zero import rows or import audit. Bookmark creation
  failure leaves the complete database snapshot and audit counts unchanged.
  New-store/onboarding instances recover the pending identity and authorized
  root with balanced test scope access. Disposable-folder sentinel bytes and
  recursive listings are identical before and after success and failure.
- Task 7A verification: Implementer GREEN passed 23/23 onboarding cases plus
  the 1/1 protected-`audit_events` negative control. Fresh independent QA
  repeated 23/23 and 1/1 at
  `/tmp/release-radar-7a-qa-9214c28b-a566-4708-a8e6-6afc84f580e7/onboarding-acceptance.xcresult`
  and
  `/tmp/release-radar-7a-qa-9214c28b-a566-4708-a8e6-6afc84f580e7/store-authorizer-negative-control.xcresult`.
  Fresh controller verification repeated 23/23 and 1/1 at
  `/tmp/release-radar-7a-controller.0I9dkp/Logs/Test/Test-ReleaseRadar-2026.08.25_13-16-17--0400.xcresult`
  and
  `/tmp/release-radar-7a-controller.0I9dkp/Logs/Test/Test-ReleaseRadar-2026.08.25_13-16-36--0400.xcresult`.
  All three existing Attach persistence/rollback regressions passed, and
  `git diff --check` is clean for the two owned files.
- Task 7A independent final reviews: Code Reviewer **APPROVED**, Required 0,
  Optional 0; QA **ACCEPT**, Required 0, Optional 0; Architecture **APPROVED**,
  Required 0 and no ADR/design change; Security/Privacy **PASS**, Required 0,
  Optional 0; TPM **GO**, Required blockers 0; Delivery Management **GO**.
  Accepted residual risk: the reported SQLite-23 failure remains unexplained
  because isolated current source did not reproduce it and bundle provenance
  was not established; the authorizer remains fail-closed.
- Historical release sequence at the original plan gate: no writer was eligible
  until the missing plan gates returned GO and the residual Attach
  live-observation gap was closed or explicitly accepted. Task 7A was then to be
  released as the sole writer and accepted independently before Task 7B.
- Historical Task 7B gate: Task 7B subsequently entered its fresh Architecture,
  TPM, QA/test, Delivery Management, and Security/Privacy preimplementation
  review, with no Implementer released before all five roles returned GO. That
  gate was later completed and is preserved only as evidence; it creates no
  current writer eligibility.
- Task 7B fresh plan-review wave — 2026-08-25: Architecture **GO**, Required
  0 and no ADR change; Security/Privacy **GO**, Required 0. QA/test initially
  returned **NO-GO** on one plan-level gap: the brief required deterministic
  pasteboard failure coverage but did not define its local seam or pin the full
  directly testable RED presentation/persistence matrix. The Task 7B brief now
  requires one `OnboardingView.swift`-local immutable prompt/result plus an
  injected `(String) -> Bool` writer defaulting to `NSPasteboard.general`, with
  success bound to a uniquely named pasteboard and failure forced by returning
  `false`; no framework, global service, or dependency is added. The amended
  RED matrix assigns exact landing/confirmation/clipboard/result contracts to
  `AppRouteTests`, persistence/no-duplicate/no-auto-action/phase-gate/Attach
  contracts to onboarding acceptance coverage, and actual close-control
  interaction to the already required isolated live matrix. QA re-review, then
  fresh TPM and Delivery review, remain required; no writer is released.
- Task 7B amended plan gates — 2026-08-25: Fresh QA/test re-review **GO**,
  Required 0, after confirming the local clipboard seam and exact RED matrix
  close its sole finding. Fresh TPM **GO**, Required blockers 0; Task 7A is
  accepted and 7B is dependency-safe, with the historical SQLite-23
  non-reproduction and native-picker observation limitation retained as
  explicit accepted risks rather than waived evidence. The amended Task 7B
  brief now explicitly requires independent post-implementation Code Review,
  QA/test, Architecture, Security/Privacy, TPM, and Delivery Management before
  acceptance. Delivery re-review remains the last preimplementation gate; no
  writer is released until it returns GO.
- Task 7B release — 2026-08-25: Delivery Management **GO**, Required 0. All
  five fresh preimplementation gates are durable: Architecture, QA/test,
  Security/Privacy, TPM, and Delivery. Release one fresh Task 7B Implementer as
  the sole product writer, limited to the amended brief's two views and focused
  AppRoute/onboarding acceptance coverage. Attach callbacks and transactions,
  `associateFirstProjectRoot`, schema, importer, bridge, Help, Portable Import,
  RR-R7 packaging, owner bundle/data, and new UI-test/clipboard infrastructure
  remain closed. Final acceptance requires fresh independent Code Review,
  QA/test, Architecture, Security/Privacy, TPM, and Delivery decisions.
- Task 7B implementation review wave — 2026-08-25: The bounded four-file
  implementation reached focused GREEN at 48/48, full GREEN at 163/163, and a
  successful configured Debug build. Security/Privacy **PASS**, Required 0.
  Code Review returned spec **NO-GO** with two accepted Required findings:
  superseded owner-facing “ask an agent/first phase” copy remains active in
  existing shared presentations, and clipboard tests call the handoff helper
  without mounting/driving the injected `OnboardingView` state, so removal of
  actual button/result wiring could escape. QA is **CONDITIONAL** with the same
  view-wiring point classified Optional and one Required live-evidence gap:
  after directly observing the alternate Add Project landing, both workflow
  entries, Back/Cancel/Escape/red-close no-write states, and compact/wide
  layouts, Computer Use failed twice when the native picker closed. No product
  defect was established; confirmation, saved/resumed handoff, clipboard,
  persisted phase gate, and remaining responsive matrix are not yet claimed.
- Task 7B Ruling — Code Review's third finding does not expand the exact
  two-action landing contract from **Add Project** to the embedded truly empty
  Projects surface. The controlling Task 7B objective says “Add Project first
  offers” both actions; fresh live QA directly observed both in the Add Project
  window with Import/Help absent. `ProjectsView` constructs the embedded
  initialization surface only when its dashboard projection has no persisted
  projects, so it has no eligible existing project to attach and intentionally
  receives no Attach loader/callback. Adding that integration would require
  out-of-brief `ProjectsView`/model interface changes and a nonfunctional Attach
  action. Cost if wrong: the empty-store embedded surface continues to show
  only Initialize, while the required Add Project window remains the two-action
  workflow; revisit only if product scope is explicitly broadened.
- Task 7B fix round 1/5 opened: return the two accepted Required findings to
  the original Implementer. Add RED coverage for every active shared
  presentation that must drop false first-phase/ask-agent language, and a
  lowest-practical mounted/injected view-state regression proving the actual
  copy action replaces prior success with visible/accessibility failure. Keep
  the live QA gap open for fresh post-fix verification; do not substitute source
  inspection for the unobserved runtime matrix.
  RR-R7 packaging remains deferred; Help and portable import remain closed.
- Task 7B fix-round disposition — 2026-08-25: The shared-copy finding was
  closed with RED coverage and corrected owner-facing **Initialize Project
  Tracking** / **tracking state** terminology across the active shared
  constants and onboarding-error mappings. An attempted mounted SwiftUI test
  demonstrated that the in-process AppKit accessibility tree exposed only the
  selectable prompt, not the hosted SwiftUI controls. The temporary
  `initialHandoffProjectID` and copy-action registrar seams and their rendering
  harness were removed under the proportionality rule: literal in-process
  button activation remains Optional coverage, while production wiring is
  direct and the approved writer seam retains exact-byte success and forced
  success-to-failure replacement tests. No UI-test target, dependency, launch
  flag, global service, debug state, or snapshot infrastructure was added.
- Task 7B implementation and acceptance — 2026-08-25: **Accepted** in the
  current uncommitted combined working diff; no dedicated commit was created.
  Add Project now offers only **Initialize Project Tracking** and **Attach
  Folder to Existing Project**. Initialization separates read-only preview
  from explicit confirmation, persists a resumable pending base state, reports
  a typed saved-seed-incomplete outcome without partial import, displays the
  exact approved 460-byte path-free Codex prompt, and provides the icon-only
  **Copy Codex prompt** affordance with truthful visible/accessibility success
  or failure and clipboard disclosure. The app performs no automatic Codex or
  phase request; **Check Tracking Status** is read-only and **Finish
  Initialization** rechecks the persisted phase gate. Existing Attach
  transactions and recovery behavior remain unchanged. `ProjectsView`, schema,
  importer scope, typed bridge ownership, Help, and Portable Import were not
  expanded.
- Task 7B TDD and final verification: Initial RED is
  `/tmp/release-radar-7b-red.QhHTAi/task-7b-red.xcresult`; the stale-copy RED is
  `/tmp/release-radar-7b-fix1-copy-red.kc1ihS/copy-red.xcresult`. Final
  Implementer verification passed 53/53 focused tests at
  `/tmp/release-radar-7b-fix2-focused.lfduws/focused.xcresult`, 163/163 full
  tests at `/tmp/release-radar-7b-fix2-full.ZAtLRc/full.xcresult`, and the
  configured Debug build at
  `/tmp/release-radar-7b-fix2-build.hAThBc/build.xcresult`; scoped
  `git diff --check` was clean. Fresh independent QA repeated 53/53 focused and
  163/163 full at
  `/tmp/release-radar-7b-qa-fix2-focused.CcJwFF/focused.xcresult` and
  `/tmp/release-radar-7b-qa-fix2-full.cLwar4/full.xcresult`, with a zero-error
  Debug build at
  `/tmp/release-radar-7b-qa-fix2-build.MWlb3p/build.xcresult`. Final controller
  verification passed 54/54 current-source cases, including the protected
  `audit_events` negative control, at
  `/tmp/release-radar-7ab-controller-final.yQdmzs/focused.xcresult`.
- Task 7B live and visual evidence: Independent isolated QA directly observed
  the Add Project two-action landing with Import/Help absent, Initialize and
  Attach entry, Back, Cancel, Escape, red-close no-write behavior, and compact
  and wide layouts. Captures are
  `/tmp/release-radar-7b-qa-live.xMcC4h/add-project-compact.png` (760 x 532),
  `/tmp/release-radar-7b-qa-live.xMcC4h/add-project-landing.png` (760 x 560),
  `/tmp/release-radar-7b-qa-live.xMcC4h/landing-wide.png` (1499 x 768),
  `/tmp/release-radar-7b-qa-fix1-live.lrbv4B/live-add-project-landing.png`
  (1499 x 768), and
  `/tmp/release-radar-7b-qa-fix1-live.lrbv4B/live-disposable-picker.png`
  (880 x 448). The alternate store remained empty and the disposable sentinel
  remained unchanged after abandonment/dismissal checks.
- Task 7B independent final reviews: Code Reviewer **APPROVED**, Required 0;
  QA/test **PASS**, Required 0; Architecture **APPROVED**, Required 0, no ADR
  change, with 53/53 focused verification at
  `/tmp/release-radar-7b-arch.l3NLPt/architecture-focused.xcresult`;
  Security/Privacy **PASS**, Required 0, with 8/8 focused verification at
  `/tmp/release-radar-7b-security-fix1-20260825/Logs/Test/Test-ReleaseRadar-2026.08.25_14-09-24--0400.xcresult`;
  TPM **GO**, Required blockers 0; Delivery Management **GO**, Required 0. The
  exact two-action contract remains scoped to Add Project rather than the
  embedded truly empty Projects surface, as recorded in the ruling above.
- Task 7B accepted residual evidence limitation: Computer Use consistently
  disconnected when `NSOpenPanel` closed, so the post-picker confirmation,
  saved/resumed handoff, general-pasteboard feedback, persisted phase gate, and
  exact 900 x 650 presentation are not claimed as directly observed. QA, TPM,
  and Delivery accept this as a tooling limitation, not a demonstrated product
  defect, because deterministic acceptance tests cover the persistence,
  repository no-write, clipboard, status/phase-gate, relaunch, failure, and
  Attach contracts. A future isolated live rerun when the bridge is stable is
  Optional. Task 7A's unexplained SQLite-23 current-source non-reproduction
  remains a separate accepted residual uncertainty; the store authorizer
  remains fail-closed.
- Historical Initialize Project Tracking remediation closeout, superseded by
  the reopened SQLite-23 gate below: Tasks 7A and 7B were closed
  and accepted. At that time, RR-R7 final route verification and Release
  packaging/handoff were recorded as next; that eligibility was consumed and
  has no current effect. Help, Portable Import/exporter work, and later product
  writers remain closed until their own approved gates.

### Initialize Project Tracking SQLite-23 repair — reopened owner gate

- Status — 2026-08-25: **Reopened; not accepted and not Done.** This section
  supersedes the earlier Task 7A/7B acceptance and closeout statements. The
  owner reproduced a production failure in the installed app while confirming
  **Initialize Project Tracking**: `SQLite error 23: access to
  audit_events.project_id is prohibited`.
- Confirmed root cause: the version-9 migrated schema retains legacy project
  active-phase triggers. Preparing the onboarding project upsert causes SQLite
  to authorize an internal `SQLITE_READ` of `audit_events.project_id`. The
  transaction authorizer currently denies every action that names
  `audit_events`, so SQLite returns `SQLITE_AUTH` (23) before the upsert can
  execute. A fresh-schema test did not reproduce this migrated-schema path and
  was insufficient evidence for the installed app.
- Repair boundary: keep transaction-control denial first; allow only
  `SQLITE_READ` when the protected `audit_events` table is named; continue to
  deny every direct or indirect write to that table. Do not change migrations,
  the recognized schema, onboarding SQL, owner data, or repository contents.
- Diagnostic boundary: add durable unified logging at the SQLite boundary with
  a fixed event/stage identifier, primary and extended SQLite result codes,
  authorizer action code/name, equality-allowlisted identifiers only, schema
  version, and in-transaction state. Never log SQL, bindings, arbitrary SQLite
  or trigger text, actor/reason/thread/project values, project or repository
  names/IDs/paths, bookmark bytes, prompts, credentials, or row data. The
  authorizer logger must not query SQLite.
- Regression boundary: reproduce the exact migrated-schema onboarding failure
  before the repair; retain direct protected-table INSERT/UPDATE/DELETE denial;
  cover indirect foreign-key `ON DELETE SET NULL` denial with complete rollback
  of the parent, protected audit reference, and an ordinary cascade child; and
  verify relaunch persistence, repository no-write behavior, foreign-key
  integrity, focused suites, and the full suite.

#### Owner-mandated delivery guardrails

1. **Owner owns Done.** Engineering may report only **Ready for owner
   validation**. Nothing is Done or Accepted until the owner personally tests
   `/Applications/ReleaseRadar.app` and explicitly approves it.
2. **Release only.** Do not hand off, install, or describe a Debug build as the
   app for owner validation.
3. **Two durable destinations, one verified bundle.** Preserve the Release
   artifact at
   `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app`
   and install the exact same verified bundle at
   `/Applications/ReleaseRadar.app`.
4. **No temporary handoff.** DerivedData and `/tmp` are build/test locations,
   never the owner-facing app destination.
5. **No unsupported priority or scope assumptions.** Material decisions must
   come from explicit owner requirements or recorded evidence; uncertainty is
   inspected or surfaced rather than silently decided.
6. **Production-shaped verification.** Exercise the migrated schema and the
   reported failure path against a database already populated with unrelated
   project, phase/child, and scoped-audit history. Snapshot that existing data
   and prove it remains unchanged except for the exact expected onboarding
   delta. A fresh empty database is only a secondary control, never sufficient
   evidence by itself.
7. **Durable diagnostics before guessing.** Consequential runtime failure paths
   require privacy-bounded logs sufficient to identify the failed stage and
   SQLite/authorizer result without exposing owner data.
8. **Evidence before claims.** Verify the exact command, configuration, bundle,
   signature, entitlements, identity, hashes, and installed destination before
   reporting them. A successful build is not evidence that the installed app
   works.
9. **No hidden weaker substitutions or unrelated work.** Any limitation is
   stated explicitly; no later task, refactor, warning cleanup, or adjacent
   feature is opened to make the repair appear complete.
10. **Ledger accountability.** Failures, review decisions, packaging identity,
    install evidence, remaining uncertainty, and the owner validation state are
    recorded here. Prior erroneous acceptance language remains historical but
    is explicitly superseded by this reopened gate.

#### Completed repair-plan reviews

- Architecture: **GO**, Required 0; the scoped authorizer change preserves the
  app-only audit boundary and requires no ADR.
- QA: **GO**, Required 0 after the gate was corrected so artifact review occurs
  after packaging rather than circularly before it.
- Security/privacy: **GO**, Required 0 after the brief added privacy-bounded
  durable logging, complete cascade-child rollback assertions, and fail-closed
  entitlement verification.
- TPM: **GO**, Required blockers 0.
- Delivery Management: **GO**, Required 0; the nonlaunch modes and rollback
  behavior below are binding delivery requirements.

#### Pinned nonlaunch script contract

- Default/no argument and `stage-release-no-launch` /
  `--stage-release-no-launch`: build **Release**, verify the complete bundle,
  copy it to a unique sibling under `dist/`, verify the temporary copy, then
  atomically promote it to `dist/ReleaseRadar.app`. Do not launch or terminate
  the app.
- `install-staged-release-no-launch` /
  `--install-staged-release-no-launch`: do not build, launch, terminate, or open
  owner data. Verify the staged bundle, copy it to a unique sibling under
  `/Applications`, verify identity there, then atomically promote it to
  `/Applications/ReleaseRadar.app`.
- Existing `run`, `debug`, `logs`, `telemetry`, and `verify` remain explicit
  launch modes only. Every build performed by the script uses Release.
- Promotion rollback: verify the candidate before touching the final path; move
  any prior final bundle to a unique same-directory backup; independently
  verify the promoted bundle; restore the backup on failure. If restoration
  fails, return nonzero, preserve both the backup and failed candidate, and
  print their paths. Never merge into an existing app bundle.
- Bundle evidence must include strict deep signing; bundle identifier
  `com.rekonlabs.ReleaseRadar`; expected Apple Development authority/team;
  Hardened Runtime and exact expected main-app/bridge sandbox, app-group,
  user-selected-read-only, and network-client entitlements; embedded signed
  code identity; unexpected entitlement rejection; and equality between staged
  and installed CDHash, identifier, version/build, main-executable SHA-256, and
  resource manifest.

#### Remaining gate sequence

1. Implement the approved repair test-first and complete focused and full
   engineering verification.
2. Obtain independent Code Review, QA, Architecture, Security/Privacy, TPM, and
   Delivery Management engineering decisions.
3. Delivery Management explicitly authorizes packaging and installation.
4. Stage the nonlaunch Release bundle under `dist/` and install the identical
   verified bundle under `/Applications`.
5. QA and Security/Privacy independently verify the actual staged and installed
   artifacts.
6. Delivery Management records **Ready for owner validation**.
7. The owner personally tests `/Applications/ReleaseRadar.app`; only the
   owner's explicit approval may change this task to Done or Accepted.

#### Repair-plan ruling after first RED — 2026-08-25

- Evidence: the standalone synthetic SQLite diagnostic reproduced primary code
  23, authorizer tuple `(SQLITE_READ, audit_events, project_id)`, and the exact
  owner-visible `access to audit_events.project_id is prohibited` text. The
  real `FolderProjectOnboarding.prepare` XCTest reached the same primary code
  23 on the populated legacy-schema path but `sqlite3_errmsg` surfaced the
  generic text `not authorized`.
- Ruling: bind the RED gate to the stable primary code 23, independently
  captured authorizer tuple, populated migrated schema, and preservation
  assertions. Preserve the owner's exact message as reproduction evidence, but
  do not require every SQLite wrapper/path to reproduce identical human-readable
  wording. The repair's fixed-field diagnostic event becomes the stable future
  evidence for action/stage/result.
- Cost if wrong: a distinct authorization failure could be mistaken for this
  bug. That risk is controlled by the exact legacy triggers and production
  upsert in the real callback fixture, the standalone tuple diagnostic, and the
  populated-state preservation assertions. Fresh Architecture, QA, and
  Security/Privacy review of this ruling is required before implementation
  resumes.
- Fresh post-RED reviews: Architecture **GO**, Required 0 and no ADR change;
  QA/test **GO**, Required 0; Security/Privacy **GO**, Required 0. All three
  require the resumed Implementer to replace the earlier empty-fixture RED
  with a populated synthetic version-9 legacy-shape RED and capture code 23
  through the real onboarding callback before any production authorizer or
  logging change. The earlier empty-fixture result remains diagnostic history
  and is not final acceptance evidence.
- Implementation evidence, engineering review wave 1: the sole Implementer
  retained the populated RED at
  `/tmp/release-radar-sqlite23-populated-red-verified.xcresult`, passed 51/51
  focused Store/Onboarding tests, 167/167 full Debug tests, and 1/1 Release
  diagnostic test, and performed no stage/install/launch. Independent QA
  repeated 51/51, 167/167, and 1/1 but returned **NO-GO** with one Required
  populated-snapshot gap. Code Review returned **NO-GO** with three Required
  findings; Security/Privacy returned **NO-GO** with four Required findings.
  The review wave reported six unique blockers: no SQLite API call from inside the authorizer
  diagnostic path; exact one-element app-group validation; exact configured
  signing authority; fail-safe promotion/rollback through final identity
  verification, including first install; complete phase/legacy-project/audit
  field preservation; and exact new prepare-audit project/entity association.
  Packaging and installation remain closed pending a reviewed fix.
- Fix-round scope ruling: the sixth review demand above is reclassified
  **Optional/out of this repair**, not Required. The controlling Task 7A plan
  requires one prepare audit identified by actor
  `release-radar-onboarding` and reason `Prepare folder-backed project
  onboarding`; it does not require project/entity scope, and the urgent repair
  brief explicitly excludes changes to `FolderProjectOnboarding.prepare`.
  Ruling: preserve the existing audit association contract, remove only the
  newly added project/entity-scope assertion, and still compare every field of
  the pre-existing populated audit row before/after. Cost if wrong: the
  unscoped prepare audit may remain absent from a project-filtered Activity
  view. That behavior requires a separate explicit product/audit-contract
  change and is not allowed to expand this SQLite/persistence repair silently.
- Engineering fix round 1: the Implementer removed SQLite re-entry from the
  authorizer diagnostic callback, enforced exact nested entitlement structure
  and the configured signer, made strict verification/identity/rollback one
  fail-safe promotion transaction, and expanded the populated v9 preservation
  oracle. The populated regression passed 1/1, focused Store/Onboarding passed
  51/51, the full suite passed 167/167, Release diagnostic passed 1/1, and
  disposable adversarial signing/entitlement/rollback checks passed without
  staging, installing, launching, or accessing owner data. Code re-review:
  all findings addressed, Required 0. Security/Privacy re-review: R1-R4 all
  addressed, Required 0. QA re-review retained one Required test-oracle gap:
  the blocker snapshot omitted nullable `resolved_at`.
- Engineering fix round 2: the blocker preservation oracle now captures the
  exact full row. The populated regression passed 1/1 and focused
  Store/Onboarding passed 51/51. QA re-review: addressed, Required 0, no new
  breakage. Code, QA, and Security engineering gates are now clean; packaging
  and installation remain closed pending Architecture, TPM, and Delivery
  engineering decisions followed by a separate explicit Delivery packaging
  authorization.
- Final pre-packaging engineering decisions: Architecture **GO**, Required 0,
  no ADR change; TPM **GO**, Required blockers 0; Delivery Management
  engineering **GO**, Required 0. The Architecture review classifies structured
  project/entity scope on the existing prepare audit out of this repair. Its
  only Optional note is that any future schema-version diagnostic field must be
  precomputed outside the authorizer callback. Delivery holds packaging until
  a separate explicit authorization after final file-integrity evidence.
- Final scoped file integrity before packaging: `SQLiteConnection.swift`
  SHA-256 `f59b52e0263025718059130a75a20cb23c7dd712d6610bf6e1e85f0c9fa0b260`;
  `StoreAcceptanceTests.swift`
  `1fc4a7646a275e299e5283b858d5d6ffe3950a2ba20fd60ce158d2735b2a8052`;
  `OnboardingAcceptanceTests.swift`
  `ab30414f14c50a5a38cc5c0d1624659aa730c21cbebb625a4cd4c31d5abee896`;
  `script/build_and_run.sh`
  `b59bb571af0a0277315690973dadbf96e1aae32664bb4bc61b553098352e9e2e`.
  All four differ from their pre-task snapshots as expected; scoped
  `git diff --check` and `bash -n` passed. No stage/install/launch occurred.
- Delivery packaging authorization: **AUTHORIZED**, Required blockers 0, for
  exactly `script/build_and_run.sh --stage-release-no-launch` followed only on
  success by `script/build_and_run.sh --install-staged-release-no-launch`.
- Release staging/install evidence: the authorized stage command exited 0 and
  preserved the verified Release bundle at
  `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app`.
  The separately authorized install command then exited 0 and promoted the
  identical verified bundle to `/Applications/ReleaseRadar.app`. Neither mode
  launches or terminates the app; no launch mode was invoked, a post-install
  process check found no ReleaseRadar process, and no temporary stage/install,
  backup, or failed-candidate path remained at either final parent.
- Actual artifact identity: both bundles independently pass strict/deep signing
  with identifier `com.rekonlabs.ReleaseRadar`, version/build `0.1.0` / `1`,
  configured leaf authority `Apple Development: jaroberts4@gmail.com
  (PT7GS96H3L)`, team `2UA854NLX4`, Hardened Runtime, exact approved main and
  Bridge entitlements, and no `get-task-allow`. Both have CDHash
  `893c9deab194bfbfbffc8a3966cb92e3c84f448b`, main-executable SHA-256
  `1cce7f95fc18af8c95f855a1cc4a562795b6ff6a9bc79d0207a6e6f0d57282ee`,
  and CodeResources SHA-256
  `a7805f62f34929c63638c896ef85366532cf5365a658439fdede8140ac0e687a`.
  Artifact QA additionally matched a 12-file regular-file manifest digest
  `23f02ed7c4928a25e1a41ec62ada6ba8dc831a4d5c23572b8b10108b3428ffde`
  and three-link path/target manifest digest
  `3191e41574202baf9725748b8bc844dfc9998a1f06839825d2c433be24bce5f0`.
- Post-artifact decisions: QA **PASS**, Required 0, Optional 0; Security/Privacy
  **PASS**, Required 0, Optional 0. Both reviews are artifact-only and do not
  claim the SQLite workflow works for the owner. These reviews released the
  final Delivery Management decision below; Done/Accepted remains owner-only.
- Final Delivery Management decision: **Ready for owner validation**, Required
  blockers 0. This is explicitly not Done, Accepted, working for the owner, or
  release-complete. The owner test target is
  `/Applications/ReleaseRadar.app`; the required test is the same
  **Initialize Project Tracking** confirmation on the intended populated local
  workflow, followed by relaunch/pending-state confirmation. Only the owner's
  explicit approval closes the gate. If the test fails, the installed Release
  emits privacy-bounded unified diagnostics under subsystem
  `com.rekonlabs.ReleaseRadar`, category `SQLite`, including only fixed
  stage/action/result/allowlisted schema fields and no SQL, bindings, owner
  identifiers, paths, bookmarks, prompts, credentials, or row data.
- Owner runtime validation and acceptance — 2026-08-27: the owner confirmed
  that the SQLite authorization error is gone, that the pending tracking state
  persists across relaunch, and explicitly confirmed the remediation is
  **Done/Accepted**. This closes the reopened owner gate with no remaining
  remediation work and does not automatically release any deferred, blocked,
  or proposed product work.

### Pending owner decision — Process-isolated independent role agents

- Status: Proposal recorded for owner consideration; not approved, not implemented, and not a change to `AGENTS.md`, Codex configuration, or the current delivery model.
- Problem to prevent: The built-in collaboration mechanism keeps completed agent identities available, exposes no delete/terminate operation, and reached its thread limit during RR-R7. Reassigning completed RR-R6/RR-R7 agents to new roles violated the required fresh-agent lifecycle and made role attribution misleading. Chat instructions alone do not technically prevent that recurrence.
- Proposed hard boundary: Disable the built-in collaboration feature with `features.multi_agent = false`, then execute every required role through a fresh noninteractive Codex process rather than `spawn_agent` or `followup_task`.
- Proposed invocation contract: Each role runs from the authoritative repository with `codex exec --ephemeral --disable multi_agent -C /Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar -o <role-report> <role-brief>`. `--ephemeral` prevents session persistence or resumption; the child-level feature override prevents nested delegation; process exit ends the role lifecycle; and `-o` preserves the requested output before termination.
- Proposed concurrency contract: Run only read-only roles concurrently. Release exactly one Implementer as the sole workspace writer. Never resume, relabel, or reuse a role process. Each process receives only its bounded role brief, applicable instructions, and controlling artifact paths rather than the parent conversation.
- Proposed enforcement artifact if approved: One small repository-native role runner may validate the allowed role name, require a unique report destination, reject duplicate role execution for the same slice, apply read-only versus single-writer execution settings, and invoke only the ephemeral command above. It must not become a second delivery ledger or external governance system.
- Guarantees and limits: This design provides process-level context independence and lifecycle termination while making built-in agent reuse unavailable. It still consumes a separate model call for each independent role. It does not guarantee the quality of a role's judgment, and it is not active unless the owner explicitly approves both the Codex feature change and the repository runner/workflow change.

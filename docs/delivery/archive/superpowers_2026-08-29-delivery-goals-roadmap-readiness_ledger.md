# SDD ledger — plan: docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md

## Execution baseline

- Branch: `codex/release-radar-mvp`
- Approved planning-package commit: `363a2c7acb5a89405bc282bc8186a5f69d4c7d8d`
- Remote verification: exact `origin/codex/release-radar-mvp` SHA match; ahead/behind `0/0`
- Excluded unrelated path: `default.profraw` remains untracked and untouched
- Controlling plan SHA-256: `c86cab9fcfe90c31dfa92331dee66c154e27b16ebfc2ba4d4eb817edf3bec0c2`
- Corrected plan review: Architecture GO Required 0; TPM/Delivery GO Required 0; QA GO Required 0; owner confirmed

## Rulings

- Ruling: use the existing dedicated `codex/release-radar-mvp` checkout. At the initial decision point the approved artifacts were uncommitted and a second worktree would have required a forbidden intermediate commit, copied state, or later integration. The approved planning package is now committed and remotely verified. Risk if wrong: reduced isolation. Mitigation: one writer at a time, exact task path ownership, task-specific diffs, and a clean verified remote checkpoint before each next task.
- Ruling: the owner's current Git cadence supersedes the earlier agent-inferred single-terminal-commit interpretation. The approved planning package is committed and pushed now; each implementation task is committed and pushed only after full task verification and all required independent reviews return GO with Required 0. Risk if wrong: a task could still produce an oversized review unit. Mitigation: before coding, split any task forecast above roughly eight agent-working hours or too large for one coherent review into smaller dependency-safe, fully testable tasks, each with its own review and Git checkpoint.
- Ruling: no partial or unverified checkpoint commits. A split happens in the canonical task brief before coding; every resulting slice has explicit acceptance criteria and independent verification.
- Ruling: this ignored ledger is temporary orchestration state only. Canonical decisions, briefs, results, and Git evidence are persisted under `docs/delivery/`.

## Preflight consistency table

| Scope | Shared surface / dependency | Preflight disposition |
| --- | --- | --- |
| Task 1 self | Genuine schema-v10 fixture, additive v11 schema, migration/history proof, public models | Consistent. Fixture must be generated and checked in before v11 production code. Planner must split before coding if forecast/review surface exceeds the owner threshold. |
| Task 2 self | Store-owned planning policy and every ticket/phase writer | Consistent. Consumes v11 only; no post-v11 legacy bypass or inferred Delivery Goals. |
| Task 3 self | Typed commands, dispatcher, MCP/helper boundary | Consistent. Consumes Task 2 policy and preserves app-only SQLite writing. |
| Task 4 self | Projections, Phase Board controls, owner-app acceptance | Consistent. Consumes Tasks 1–3; browsing remains non-mutating and owner acceptance remains non-spoofable. |
| Task 5 self | End-to-end integration, signed staging/install, owner-data repair and acceptance | Consistent. Consumes Tasks 1–4 and introduces no new planning abstraction. |
| Task 6 self | Terminal evidence reconciliation and status-only commit | Consistent. Runs only after Task 5 acceptance and exact remote verification for every prior checkpoint. |
| Task 1 → Task 2 | Models/schema/persistence contracts | Clean sequential handoff; Task 2 must not redefine Task 1 contracts without reopening the reviewed brief. |
| Task 1 → Task 5 | v10 fixture, migration history, preservation proof | Clean sequential handoff; Task 5 reuses authoritative fixtures and snapshots. |
| Task 2 → Task 3 | Planning policy, dispatcher, bridge acceptance tests | Shared files are serialized; Task 3 begins only after Task 2 commit and remote verification. |
| Task 2 → Task 4 | Goal/plan lifecycle projections and policy semantics | Clean consumer relationship; Task 4 does not write SQLite directly. |
| Task 2 → Task 5 | Ticket writer enforcement and repair behavior | Clean integration boundary; Task 5 fixes only demonstrated integration defects at their owner. |
| Task 3 → Task 4 | Owner-app command origin and `AppModel` dispatch | Clean sequential handoff; MCP never exposes owner acceptance. |
| Task 3 → Task 5 | Typed MCP repair path and replay semantics | Clean integration boundary; installed helper digest captured only at Task 5 gate. |
| Task 4 → Task 5 | UI projections, accessibility, acceptance action | Clean integration boundary; Task 5 verifies installed behavior and owner acceptance. |
| Tasks 1–5 → progress ledger | `docs/delivery/progress.md` | Serialized single-writer updates; each task records reviews/tests/commit/remote SHA before the next opens. |
| Task 5 → Task 6 | Accepted product state and remote code checkpoint | Clean terminal handoff; Task 6 changes only the canonical ledger and formal completion evidence. |

Preflight result: no unresolved plan conflict. Task 1 planning must make the owner-size threshold explicit and either certify one reviewable task or split it before implementation.

## Task state

| Task | State | Writer | Required preimplementation reviews | Commit / remote |
| --- | --- | --- | --- | --- |
| Planning package | Complete | Primary coordinator | Architecture, TPM/Delivery, QA, owner | `363a2c7acb5a89405bc282bc8186a5f69d4c7d8d` exact remote match |
| Task 1A | Implementation released | Fresh Implementer pending | Architecture, TPM, QA/Test, Delivery Management, Security/Privacy all GO | Planning-only checkpoint `def687a084ddf074c9e914dd127c820ea563669e` exact remote |
| Task 1B | Brief complete; dependency-blocked on Task 1A remote checkpoint | `/root/rr_r10_task1_planner` | Architecture, TPM, QA/Test, Delivery Management, Security/Privacy | Not eligible |
| Tasks 2–6 | Dependency-blocked | Unassigned | Per controlling plan | Not eligible |

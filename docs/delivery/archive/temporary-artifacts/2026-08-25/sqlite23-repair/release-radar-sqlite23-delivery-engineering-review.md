# Independent Delivery Engineering Review — SQLite-23 Repair

**Review status:** **ENGINEERING GO** for the scoped four-file repair and its recorded pre-packaging evidence.  
**Packaging authorization:** **HELD — not authorized in this review.**  
**Open Required implementation/evidence findings:** **0.**

This is a fresh, read-only Delivery Management review of the completed engineering state. It neither stages nor installs a bundle, launches the app, accesses owner data, nor changes the repository or Git state. It cannot move the task to Ready for owner validation, Done, or Accepted.

## Scope and provenance

The intended implementation is limited to these four files, against the stated pre-task snapshot `/tmp/release-radar-sqlite23-pre.ZLUrQy`:

- `ReleaseRadarCore/Store/SQLiteConnection.swift`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- `script/build_and_run.sh`

The current SHA-256 values agree with the reviewed fix-round package for the production/store-test/script files. `OnboardingAcceptanceTests.swift` differs from fix round 1 only by the fix-round-2 reviewed `SELECT * FROM blockers` preservation-oracle correction. Current scoped `git diff --check` is clean. The broad dirty worktree contains many unrelated pre-existing paths; they are excluded from this decision and no attribution is made to them.

## Required contract verification

### SQLite-23 repair and safety boundary — satisfied

- The transaction authorizer checks transaction/savepoint control first, permits `SQLITE_READ` of `audit_events`, and denies every other action referring to that protected table.
- The populated recognized-version-9 legacy fixture exercises the actual onboarding callback, retains the real pre-fix `SQLITE_AUTH` (23) evidence plus the independent exact tuple/message diagnostic, and checks persisted onboarding/relaunch/no-repository-write behavior and populated-state preservation.
- Direct protected-table `INSERT`/`UPDATE`/`DELETE` and indirect foreign-key `ON DELETE SET NULL` mutation paths remain fail-closed with rollback and foreign-key integrity coverage.
- Bounded diagnostics avoid authorizer-to-SQLite re-entry and retain only allowlisted fixed fields; Release diagnostic test evidence is recorded.

### Build/stage/install contract — satisfied in source and disposable verification

- With no argument, `MODE` defaults to `stage-release-no-launch`; the two stage aliases select the same nonlaunch stage function. It builds Release with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`, verifies the complete bundle, copies to a unique `dist` sibling, verifies/compares identity, then promotes atomically to `dist/ReleaseRadar.app`.
- The two install aliases verify the existing staged bundle without building, copy it to a unique `/Applications` sibling, verify/compare identity, then promote atomically to `/Applications/ReleaseRadar.app`.
- `pkill` and `open` are restricted to explicit launch helper/modes, not stage or install.
- Promotion verifies a candidate before touching the final path; it preserves a verified prior final in a same-directory backup; it verifies and identity-checks the promoted final before backup deletion; and it quarantines a failed candidate/restores the backup. Restoration failure is nonzero and preserves/reports both paths. A failed first promotion leaves no final bundle.
- Recorded disposable adversarial checks cover fail-closed verification, exact entitlement structure, signer authority/team, first-promotion failure, replacement rollback, identity-mismatch rollback, and restoration-failure retention. No actual staging or installation mode was used in that evidence.

## Evidence and review closure

The retained evidence reports: populated RED against the real callback; fix-round populated regression **1/1**; focused Store/Onboarding **51/51**; full Debug suite **167/167**; and scoped Release diagnostic **1/1**. Code re-review fix 1 reports **0 Required**. Security/Privacy re-review fix 1 reports **0 Required**. QA re-review fix 2 closes the final `blockers.resolved_at` snapshot gap and reports **0 Required**.

The durable progress ledger records the same sequence and expressly says Code, QA, and Security engineering gates are clean while packaging/install remain closed pending fresh Architecture, TPM, and Delivery engineering decisions followed by a distinct Delivery authorization. The earlier prepare-audit association issue is governed by the recorded scope ruling, not an unresolved implementation defect.

## No packaging/install/launch and owner-data boundary

The implementer report, Code re-review, QA re-review, Security re-review, review packages, and ledger consistently state that no stage mode, install mode, `dist` bundle creation/modification, `/Applications/ReleaseRadar.app` access, app launch, owner database/project-data access, Keychain access, commit, or Git index mutation occurred in this repair/review wave. This review found no contrary record. That is documentary evidence, not a claim that an unobserved external action was independently executed or verified.

## Classification

### Required — 0 open

All prior Required findings are closed by the reviewed four-file state and recorded evidence. Architecture and TPM decisions are mandatory release-gate inputs, but are not defects in the implementation or its engineering evidence.

### Optional

- Associate the new prepare audit with project/entity identifiers. The approved ruling preserves the current actor/reason/count contract and makes this a separate product/audit-contract decision.
- A broader or fresh full-suite rerun after the one-line fix-round-2 test-oracle expansion. The targeted regression and focused suite passed; no production or script behavior changed.

### Out of scope

- UI/copy redesign, Attach, migrations, legacy schema deletion, onboarding SQL, owner data recovery/editing, portable import/export, Help, new infrastructure, and Debug handoff.
- Treating a disposable `/tmp` bundle or any Debug build as the owner artifact.
- Owner approval, Done, Accepted, or Ready for owner validation before the release/artifact/owner gates complete.

## Packaging authorization is explicitly held

Fresh Architecture and TPM decisions after fix round 2 are not part of this review input. Therefore Delivery does **not** authorize the nonlaunch `dist` stage or the `/Applications` install now.

## Exact follow-up inputs required before Delivery may authorize execution

Provide a separate, fresh follow-up package containing all of the following:

1. An independent **Architecture GO**, explicitly reviewing the final fix-round-2 four-file hashes/diff and confirming the action-sensitive authorizer, diagnostics, signing/entitlement, and rollback behavior remain within ADR-001 without a new ADR; Required count must be stated.
2. An independent **TPM GO**, explicitly confirming the repair is the sole eligible work, the post-fix review sequence is complete, and package/install sequencing remains within the owner guardrails; blocker count must be stated.
3. A final Delivery-consumable integrity attestation: current SHA-256 for all four files, the fix-round-2 one-line diff, scoped `git diff --check`, confirmation that no reviewed file changed after those role decisions, and confirmation that unrelated dirty worktree changes remain excluded.
4. The precise nonlaunch execution request: first `script/build_and_run.sh stage-release-no-launch` (or its documented alias), then only after its staged identity evidence is retained, `script/build_and_run.sh install-staged-release-no-launch` (or alias). It must explicitly prohibit `run`, `debug`, `logs`, `telemetry`, `verify`, `open`, and owner-data access.

If those inputs are GO and unchanged, Delivery may release the two nonlaunch commands. That authorization must still require separate post-execution artifact evidence: command/configuration logs; exact `dist` and `/Applications` paths; strict/deep signature, configured authority/team, Hardened Runtime, exact entitlement, embedded-code, identifier/version/build, CDHash, executable SHA-256, and resource-manifest results; staged-to-installed identity equality; rollback/backup outcome if exercised; and independent QA plus Security/Privacy verification of the actual artifacts before Delivery can record Ready for owner validation.

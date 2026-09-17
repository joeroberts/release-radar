# RR-R9A Implementer report

## Status

DONE — serialized RR-R9A implementation and implementer evidence are complete.
Required independent Code Review, QA, Architecture, Security/Privacy, TPM, and
Delivery Management decisions remain outside Implementer authority; RR-R9B and
RR-R9C remain closed.

## Files changed

- `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- `ReleaseRadarAgentTools/main.swift`
- `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- `.superpowers/sdd/2026-08-29-release-radar-active-phase-selection/task-1-report.md`
  (this required non-authoritative implementation report)

## Per-test production break named before test body

- `testSetActivePhaseCommitsOnlyPointerAuditAndReceiptAndDurablyReplays`: catches an absent/non-exhaustive typed command, wrong selected entity result, missing app-owned pointer mutation, wrong external audit actor/scope/asserted attribution, non-durable replay, duplicate replay writes, or mutation of phase/ticket/dependency history. Expected IDs, actor/scope strings, cardinalities, and ordered history fixtures are literal and independent of dispatcher implementation.
- `testSetActivePhaseOwnerOriginUsesOwnerAttributionWithoutAssertedThread`: catches owner-origin dispatch accidentally retaining the external actor or asserted thread. Expected actor `release-radar-owner`, absent thread, `none` attribution, phase scope, and cardinalities are literal.
- `testSetActivePhaseRejectsMissingCrossProjectAndUnauthorizedTargetsWithoutWrites`: catches a missing same-project `phases` validation, cross-project acceptance, authorization bypass, or any rejected-request partial write. Expected typed error cases are chosen from the existing dispatcher contract, and before/after database snapshots come from the real store.
- `testSetActivePhaseRejects258ByteIdentifierBeforeAnyWrite`: catches validation based on grapheme count instead of UTF-8 bytes or validation performed after mutation admission. The test independently establishes that 129 literal `é` characters encode to exactly 258 UTF-8 bytes, then compares full real-store snapshots.
- `testSetActivePhaseFreshAlreadyActiveIntentAuditsOnceAndReplayAddsNothing`: catches short-circuiting a fresh agent assignment of the already-active phase, omitting its explicit-intent audit/receipt, or duplicating either on durable replay. Expected pointer/history preservation and `+1` cardinalities are literal.
- `testSetActivePhaseChangedBodyRequestIDReusePreservesOriginalSelection`: catches canonical replay that ignores the command body or permits one request ID to select a second phase. Expected original phase and unchanged post-success snapshot are literal.
- Existing `testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp`, extended only after core GREEN: catches a 12-tool catalog, an inexact `release_radar_set_active_phase` strict schema, the wrong encoded `setActivePhase`/`phaseID` payload, a packaged tool that bypasses the real registered broker/app callback, wrong phase audit scope/actor, or duplicate signed replay. The complete expected input schema is a hand-written literal and is checked independently from the existing transition schema.

## RED command and expected observed failure

Core RED command (exit 65):

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Core-RED -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests CODE_SIGNING_ALLOWED=NO
```

Observed the expected compilation failure `type 'AgentCommand' has no member
'setActivePhase'` at every new command construction. The first run also exposed
test-only async-autoclosure and Sendable-capture compile issues; those were
corrected without production edits, and the repeated RED retained only the
missing-command failure plus its type-inference cascades. Result bundle:
`/tmp/ReleaseRadar-RR-R9A-Core-RED/Logs/Test/Test-ReleaseRadar-2026.08.29_14-43-18--0400.xcresult`.

Signed transport RED command (exit 65):

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Transport-RED -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests
```

After correcting one test-only type-inference issue and repeating with
AgentTools still unchanged, the package built and the inventory gate rejected
the actual 12-tool `tools/list` response as `invalidResponse`; four tests that
invoke `runTool` failed, while initialize-only passed. This is the expected
missing packaged-tool/schema failure. Result bundle:
`/tmp/ReleaseRadar-RR-R9A-Transport-RED/Logs/Test/Test-ReleaseRadar-2026.08.29_14-46-00--0400.xcresult`.

## Production changes

- Added additive envelope-v1 `AgentCommand.setActivePhase(phaseID:)` without
  changing any existing case.
- Added exhaustive dispatcher validation using the existing non-whitespace and
  256-UTF-8-byte identifier rule, selected-entity result construction, resolved
  project/phase audit scope, same-project `phases` admission, and the brief's
  exact single pointer-upsert SQL inside the existing audited/idempotent
  transaction.
- Added `release_radar_set_active_phase` to AgentTools using the existing strict
  definition helper and encoded only wire key `setActivePhase` plus field
  `phaseID`.
- Added six real-store dispatcher acceptance tests and extended the existing
  real packaged signed-transport acceptance test. No mock transport, generalized
  harness, dependency, service, migration, project-file, permission, schema,
  envelope-version, wire-version, or plugin-version change was introduced.

## GREEN commands/results/counts

Core GREEN, after only command/dispatcher production changes, repeated the core
RED command and exited 0: 19 passed, 0 failed, 0 skipped. Result bundle:
`/tmp/ReleaseRadar-RR-R9A-Core-RED/Logs/Test/Test-ReleaseRadar-2026.08.29_14-43-50--0400.xcresult`.

Signed transport GREEN, after the minimal AgentTools change, repeated the
transport RED command and exited 0: 5 passed, 0 failed, 0 skipped. Result
bundle:
`/tmp/ReleaseRadar-RR-R9A-Transport-RED/Logs/Test/Test-ReleaseRadar-2026.08.29_14-46-53--0400.xcresult`.

Fresh final required GREEN command (exit 0):

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9A-GREEN \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

`** TEST SUCCEEDED **`; the fresh `xcresulttool` summary command also exited 0
and reported 53/53 passed, 0 failed, 0 skipped, 0 expected failures: 19
AgentBridge, 5 signed transport, and 29 store acceptance tests. Result bundle:
`/tmp/ReleaseRadar-RR-R9A-GREEN/Logs/Test/Test-ReleaseRadar-2026.08.29_14-51-02--0400.xcresult`.

The brief's scoped `git diff --check` command exited 0 with no output.

## Replay, audit, history, and signing evidence

- A fresh external success returned `RR-ROADMAP` plus one audit ID, selected
  only `project-1|RR-ROADMAP`, added exactly one external phase-scoped audit and
  one receipt, preserved ordered phases/tickets/phase dependencies/ticket
  dependencies and earlier audit/receipt rows, then returned the byte-equivalent
  durable result after store/dispatcher recreation with no further database
  change.
- Owner-origin dispatch recorded `release-radar-owner`, no thread, `none`
  attribution, exact reason and phase scope; external origin recorded
  `release-radar-agent` and its asserted thread attribution.
- Missing, other-project, unauthorized-root, empty, and independently proven
  258-byte identifiers returned their specified typed failures and left the
  full fixture snapshot unchanged. Changed-body request-ID reuse returned
  `requestIDReused` and retained the first selection/result.
- A fresh assignment of already-active `phase-current` retained the pointer and
  history but created exactly one audit/receipt; recreated-dispatcher replay
  added none.
- The real packaged signed AgentTools, registered broker, and app callback
  listed exactly 13 tools with the hand-written exact strict schema, selected
  `phase-2`, returned MCP `isError: false`, committed one external phase audit
  and one receipt, and returned the same result on replay without another
  mutation. Existing transport cases in the same 5-test suite retained
  malformed/version/payload, deadline, definitive unavailable/wrong peer,
  post-handoff `outcomeUnknown`, and exact-replay behavior.
- The signed test explicitly unregisters the owned `SMAppService` and fails if
  its final status is not `.notRegistered`. A post-run read-only
  `launchctl print gui/501/com.rekonlabs.ReleaseRadar.BridgeAgent` exited 113
  with `Could not find service`, independently confirming no registered broker
  remained.

## Preservation and scope check

- Pre-edit blob comparison used the five recorded RR-R9A blob IDs. It isolates
  only the additive command case, four dispatcher switch/apply hunks, one
  AgentTools command encoder and definition, the six core cases/fixture
  snapshots, and the signed fixture/schema/call assertions. The unrelated
  pre-existing plugin-lifecycle edits in AgentTools and transport tests remain
  byte-preserved outside these RR-R9A hunks.
- The final scoped diff contains only the five owned implementation/test files;
  the required report is the sole additional file written. No UI, app model,
  route, migration, store contract, transport contract, project, manifest,
  permission, plan, design, ADR, progress-ledger, or other repository file was
  edited. Nothing was staged or committed.
- Self-check against each brief acceptance criterion found no Implementer-owned
  gap: all command switches are exhaustive; only the active pointer plus the
  existing transactional audit/receipt path mutates; same-project validation,
  rollback, replay, fresh already-active intent, 258-byte rejection, exact
  13-tool schema, signed path, and historical-state preservation are directly
  covered. Independent review acceptance is deliberately not self-approved.

## Concerns and temporary artifacts

- No open Implementer finding. The required independent reviews are still the
  next gate and RR-R9B remains closed.
- The repository-wide suite was not rerun: the parent baseline records five
  unrelated plugin/schema migration fixture failures. The brief-mandated
  focused suite, including all StoreAcceptanceTests, is the fresh evidence
  above. The final build emitted only destination-selection and already-signed
  binary strip warnings; no test failed or skipped.
- Non-authoritative temporary evidence remains at
  `/tmp/ReleaseRadar-RR-R9A-Core-RED`,
  `/tmp/ReleaseRadar-RR-R9A-Transport-RED`, and
  `/tmp/ReleaseRadar-RR-R9A-GREEN`. As of final verification, 19 real-store
  fixture directories from the TDD/final runs also remained under
  `/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/` with prefix
  `ReleaseRadar-AgentBridgeTests-`; no `ReleaseRadar-TransportTests-` fixture
  directory remained. These temporary artifacts were not deleted because no
  destructive cleanup was authorized.

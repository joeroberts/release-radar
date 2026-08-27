# RR-03 implementation report — typed agent delivery actions

## Outcome

Implemented the complete RR-03 slice in `6b7262c` (`feat: add typed agent delivery actions`) and `fa8eea0` (`feat: add signed agent bridge transport`). The slice defines only the approved typed commands, validates their envelopes and project scope, commits delivery state plus an exact audit ID atomically, records asserted thread attribution explicitly, and persists request IDs/results for durable replay after relaunch.

The fresh recovery proves the required packaged MCP stdio → bounded sandboxed LaunchAgent broker → running application callback path with pinned same-team/identifier identities on every hop. The app remains the sole SQLite authority; neither the broker nor tool links the core framework or SQLite. RR-03 is implementation-complete but is not accepted or released until independent code, QA, architecture, and security/privacy review closes every Required finding.

## Files changed

- `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- `ReleaseRadarCore/Models/DeliveryModels.swift`
- `ReleaseRadarCore/Store/DeliveryStore.swift`
- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadar/App/ReleaseRadarApp.swift`
- `ReleaseRadar/ReleaseRadar.entitlements`
- `ReleaseRadarTransport/BridgeXPCContracts.swift`
- `ReleaseRadarIntegration/AgentBridgeApplicationHost.swift`
- `ReleaseRadarBridgeAgent/main.swift`
- `ReleaseRadarBridgeAgent/ReleaseRadarBridgeAgent.entitlements`
- `ReleaseRadarBridgeAgent/com.rekonlabs.ReleaseRadar.BridgeAgent.plist`
- `ReleaseRadarAgentTools/main.swift`
- `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadar.xcodeproj/project.pbxproj`
- `docs/delivery/progress.md`
- `.superpowers/sdd/2026-08-23-release-radar-mvp/task-3-report.md`

The transport implementation uses a separately signed LaunchAgent executable rather than placing a Mach listener in the sandboxed app process. The broker is the only component with the shared app-group entitlement needed for ServiceManagement registration; the packaged tool remains unsandboxed and has no app-group entitlement.

## Implemented behavior

- Versioned `AgentCommandEnvelope`, typed `AgentCommandResult`, and structured command errors.
- Approved commands only: phase/ticket upsert, ticket transition, phase/ticket dependency set, blocker record/resolve, evidence add, thread link, review request, completion record, and import-review resolve/dismiss.
- Bounded non-empty envelope fields and command payloads; unsupported versions fail before any write.
- Canonicalized onboarded-root resolution through an injected registry boundary; supplied roots are not trusted as project identity.
- Existing evidence must resolve by path components inside an authorized canonical project/worktree root.
- Cross-project, missing-reference, and dependency-cycle failures return typed errors and roll back both delivery and audit writes.
- Durable request-id idempotency stores the canonical request body and original typed result in the authoritative store. Exact replay after store/dispatcher reconstruction returns the original entity IDs and audit ID without a second mutation or audit. Reuse with a different body is rejected.
- Audit events can receive the exact result audit ID and record thread attribution as `none`, `asserted`, or `verified`; bridge-supplied thread IDs are recorded as asserted.
- Store schema version 2 adds thread attribution, blocker resolution state, review status, completion records, and command request records through the existing atomic migration path.
- Store-unavailable dispatch returns `appUnavailable` and leaves the original database bytes unchanged.

## TDD evidence

All commands used the focused `AgentBridgeAcceptanceTests` target with `/tmp/rr03-derived` unless noted.

- Initial command/replay RED: `/tmp/rr03-red-1.log` — compile failed because envelope, registry, and dispatcher types did not exist. GREEN: `/tmp/rr03-green-1.log` — valid transition plus relaunch replay passed.
- Approved command set RED: `/tmp/rr03-red-2.log` — compile failed because the remaining approved cases did not exist. GREEN: `/tmp/rr03-green-2.log` — all approved bounded mutations passed.
- Empty identifier RED: `/tmp/rr03-red-3.log` — invalid command mutated state. GREEN: `/tmp/rr03-green-3.log` — rejected before writes.
- Thread attribution RED: `/tmp/rr03-red-attribution.log` — `ThreadAttribution` and its schema field did not exist. GREEN: `/tmp/rr03-green-attribution.log` — asserted attribution persisted with the exact audit event.
- Empty asserted-thread RED: `/tmp/rr03-red-empty-thread.log` — the invalid envelope was accepted. GREEN: `/tmp/rr03-green-empty-thread.log` — rejected with no state change.
- The final bridge scenarios additionally cover structured invalid-reference/cross-project/cycle rollback, differing request-ID reuse, version/payload/root/evidence rejection, and unavailable-store preservation.

## Earlier signed transport stop-rule evidence

The required MCP stdio → bounded local bridge → running app path was attempted with two concrete signed configurations:

1. Anonymous `NSXPCListenerEndpoint` discovery with an app group. The focused transport test began RED because the service/protocol did not exist (`/tmp/rr03-red-transport.log`), then the signed build failed because the added app-group configuration required a provisioning profile (`/tmp/rr03-green-transport-attempt1.log`). Official Foundation semantics also require an anonymous listener endpoint to be transferred over an existing connection, so file/environment endpoint discovery was not a valid path.
2. A team-ID app group with named XPC/Mach IPC. The app owned the listener, pinned the packaged helper by signing requirement, and validated same-user identity. The app and helper built and signed, but the packaged helper terminated with uncaught signal status 5 before returning an MCP response; the scenario observed zero responses and no store mutation (`/tmp/rr03-green-transport-attempt2b.log`, repeated in `/tmp/rr03-transport-diagnostic.log`).

Per the two-round stop rule, the transport workstream stopped. Every unproven transport artifact was removed rather than retaining a weaker configuration. A fresh transport recovery task is required before RR-03 can enter independent review or RR-04 can open.

## Fresh signed transport recovery

- RED `/tmp/rr03-transport-red.log`: the focused application-hosted transport test failed to compile because `AgentBridgeApplicationHost` did not exist.
- The normal package embeds `ReleaseRadarBridgeAgent` at `Contents/Resources`, its three-key LaunchAgent plist at `Contents/Library/LaunchAgents`, and `ReleaseRadarAgentTools` at `Contents/Helpers`.
- ServiceManagement initially returned `notFound` for the packaged-but-unregistered agent; registration then failed with `EPERM` because a sandboxed app may register only a sandboxed target. Per the architecture checkpoint, the broker received exactly App Sandbox plus the same-team app group; the tool remained unsandboxed without that group. Registration then returned enabled and unified logs proved both Mach listeners reached `main`.
- Both broker listeners require the same effective UID and set a pre-resume signing requirement pinned to team `2UA854NLX4` plus the exact app or tool identifier. The app and tool independently pin the broker with its exact identifier. Invalid requirement construction fails closed.
- The broker accepts only a version handshake and bounded opaque envelope forwarding with a short deadline. It keeps only the latest authenticated application callback in memory, clears it on invalidation, and returns `appUnavailable` on absence, timeout, or disconnect. It imports neither the app core nor SQLite and exposes no shell, filesystem, URL, or generic JSON-RPC method.
- The app registers the packaged service during normal launch, loads persisted authorized roots into the existing registry boundary, owns the dispatcher/store callback, and retains it for the app lifecycle. It distinguishes approval, denial, missing package, registration, connection, and version failures. XCTest automatic startup is suppressed so parallel hosted test processes cannot replace the explicitly fixture-backed callback.
- The MCP stdio executable supports initialize, initialized notification, typed tools/list, and tools/call for exactly the 12 approved mutations. Newline input, JSON data, envelope data, versions, and deadlines are bounded. Unknown methods/tools and invalid identities/versions fail closed.
- The acceptance scenario proves valid transition + exact audit ID, durable identical replay without a second audit/request, rejection of a same-team differently identified signed fixture, bridge-version mismatch, envelope-version mismatch, app callback disconnect with `appUnavailable`, no writes on every failure, and deterministic service cleanup.

## Final verification

- `xcodebuild build -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rr03-final-package-3` — exit 0. Log: `/tmp/rr03-final-package-3-build.log`.
- `codesign --verify --deep --strict --verbose=2` plus explicit designated-requirement verification for the app, broker, and tool — all passed on the normal package. Broker entitlements were exactly sandbox + `2UA854NLX4.com.rekonlabs.ReleaseRadar`; the tool was unsandboxed with no app group; no embedded provisioning profile existed.
- `otool -L` on the normal-package broker and tool found neither `ReleaseRadarCore` nor SQLite.
- The final proof copied the normal-package broker/tool into the signed test host, verified matching CDHashes (`9e2639ca6ae0b110a162c7808882ac752c0111a9` broker, `a4a7b3ae10eecdf003c9b093a6a89d94779ad872` tool), resealed the outer host with its existing test entitlements, and ran `test-without-building` for `AgentBridgeTransportAcceptanceTests`, `AgentBridgeAcceptanceTests`, and `StoreAcceptanceTests`. Result: 23 passed, 0 failed/skipped. Log: `/tmp/rr03-final-focused-tests-4.log`; result bundle under `/tmp/rr03-final-tests-3/Logs/Test/`.
- Final `launchctl print gui/501/com.rekonlabs.ReleaseRadar.BridgeAgent` reported no service and no exact broker/tool process remained. `git diff --check` and staged diff checks passed.

## Fix round 1 — required code-review contracts

- Finding 1: the broker's one-shot timeout gated only the reply; an application callback `Task` could resume after the caller received `appUnavailable` and still dispatch a mutation. RED `/tmp/rr03-fix1-deadline-red-2.log` showed the missing pre-dispatch contract. GREEN `/tmp/rr03-fix1-deadline-green-test.log` used a deterministic 10.5-second delay on one envelope, observed the broker's 10-second `appUnavailable`, waited for the callback to resume, and proved ticket/audit/request counts remained `[0, 0, 0]`. The app host now enforces the maximum incoming deadline and rechecks expiry immediately before entering `AgentCommandDispatcher`; no cancellation framework was added.
- Finding 2: MCP `tools/call` always emitted `isError=false`, including structured domain failures. RED `/tmp/rr03-fix1-mcperror-red-test.log` observed `false` for a non-null domain error. GREEN `/tmp/rr03-fix1-mcperror-green-test.log` followed a bounded minimal JSON inspection of the preserved `AgentCommandResult`; the final assertion covers `isError=false` for success and `true` for `appUnavailable`.
- Final normal package: `/tmp/rr03-fix1-package-final`, build log `/tmp/rr03-fix1-package-final.log`. Strict deep signing and explicit app/broker/tool requirements passed; entitlements/profile shape was unchanged; broker/tool still had no `ReleaseRadarCore` or SQLite linkage.
- Exact-package combined proof: normal-package broker/tool CDHashes `90701a35129bb864abc628952a56feaca9587d20` and `3a593a2dd46cda4048de6bce02dd22d22a9c34d0` matched the executables run in the resealed test host. `AgentBridgeTransportAcceptanceTests`, `AgentBridgeAcceptanceTests`, and `StoreAcceptanceTests` passed 23/23 with 0 failures/skips. Log: `/tmp/rr03-fix1-final-combined.log`; result bundle under `/tmp/rr03-fix1-tests-final/Logs/Test/`.
- Cleanup again left no registered LaunchAgent and no exact broker/tool process. Fix commit: `abb92ef` (`fix: enforce agent bridge result contracts`).

## Open blocker and risks

- The round-2 deadline remediation reached its two-round stop rule when independent review identified a deeper semantic problem: a broker timeout after the authenticated app callback began could be reported as `appUnavailable` even though the transaction might already have committed. The recovery below replaces that false negative with an explicit uncertain outcome.
- RR-03 must not be accepted/released, and RR-04 must not open, until scoped re-review plus architecture and security/privacy review accept the complete slice.
- A different machine may return `requiresApproval`; the app reports the explicit Login Items & Extensions owner action and does not bypass that platform gate.

## Fix round 2 — transaction-boundary deadline

- Residual finding: the fix-round-1 callback guard ran before `await dispatcher.dispatch`, so dispatcher or store actor contention could consume the remaining budget before the transaction callback began.
- RED `/tmp/rr03-fix2-deadline-red.log`: the deterministic regression failed to compile because `AgentCommandDispatcher.dispatch` did not accept transport deadline context.
- GREEN `/tmp/rr03-fix2-deadline-green.log`: the test held the real `DeliveryStore` actor in a read callback, submitted a transport-scoped dispatch, released the store after expiry, and observed `appUnavailable` with delivery, audit, request, and ticket-lane state unchanged.
- The application callback now carries its already-validated deadline into the dispatcher. The optional default preserves ordinary non-transport callers. The first statement inside the dispatcher's `DeliveryStore.transact` callback rejects an expired deadline before replay lookup or any delivery/audit/request write.
- Final normal package: `/tmp/rr03-fix2-package-final`, build log `/tmp/rr03-fix2-package-final.log`. Strict deep signing and explicit requirements passed; entitlement/profile shape was unchanged; broker/tool still had no `ReleaseRadarCore` or SQLite linkage.
- Exact-package combined proof: normal-package broker/tool CDHashes `b146dc34e2d6f59817b60c2b399560b62e687015` and `a77c3f1032216585064b2c384b0380e7bec31bbc` matched the executables run in the resealed test host. `AgentBridgeTransportAcceptanceTests`, `AgentBridgeAcceptanceTests`, and `StoreAcceptanceTests` passed 24/24 with 0 failures/skips. Log: `/tmp/rr03-fix2-final-combined.log`; result bundle under `/tmp/rr03-fix2-tests-final/Logs/Test/`.
- Cleanup left no registered LaunchAgent and no exact broker/tool process. Fix commit: `6cbfcb4` (`fix: enforce bridge deadline inside store transaction`).

## Truthful-outcome recovery after the deadline stop rule

- The transport wire protocol is now version 2 while the durable command envelope remains version 1. Wire and envelope mismatches fail closed independently; durable replay remains compatible with the version-1 request body already stored by the app.
- `AgentCommandError.outcomeUnknown` is a transport-generated result and is never persisted. Before the broker invokes an authenticated application callback, handshake, validation, missing-app, and forwarding failures remain definitive `appUnavailable` results. After callback invocation, callback invalidation, timeout, reply loss, or a reply arriving after the admission deadline returns `outcomeUnknown` through a one-shot reply gate; late duplicate replies are ignored.
- `admissionDeadline` now means exactly that. The first statement inside the authoritative store transaction rejects expiry before transaction admission. Once admitted, the command runs synchronously to its durable result; the broker may report uncertainty if it cannot observe that result. A narrow default-noop `afterDispatchBeforeReply` test seam proves committed reply loss without changing store behavior.
- Exact request replay after an unknown result returns the original stored result and performs no second mutation or audit. Reuse of the same request ID with a different body remains rejected.
- MCP transport setup failures return `appUnavailable`; post-forward timeout or connection loss returns `outcomeUnknown`; broker results pass through unchanged; and `isError` is exactly `result.error != nil`.
- JSON integer decoding rejects Core Foundation booleans, non-finite or fractional numbers, and values outside `Int`, while accepting exact integral values. Present optional `assertedThreadID`, evidence `ticketID`, and review `ticketID` fields must be strings; absent fields decode as nil, while null and wrong-typed values fail with no write.
- RED `/tmp/rr03-recovery-red-clean.log`: the focused tests failed only for the missing `outcomeUnknown` case and the missing post-dispatch/pre-reply seam. GREEN `/tmp/rr03-recovery-green-3.log`: all 11 focused bridge/transport cases passed after the broker also compared callback receipt time with the deadline so a delayed timer could not allow a late callback reply to win.
- Final normal package: `/tmp/rr03-recovery-package`, build log `/tmp/rr03-recovery-package-build.log`. Strict deep signing and explicit app/broker/tool requirements passed; the broker retained exactly sandbox + the approved app group, the tool remained unsandboxed without the group, no embedded profile existed, and neither helper linked `ReleaseRadarCore` or SQLite.
- Exact-package combined proof: normal-package broker/tool CDHashes `ce676ee13847bb703a648ad8c5e4e71ca90b0024` and `5dd2f5fecc2d98c84ab8189afe635d37ba01d39f` matched the binaries exercised in the resealed test host before and after the run. `AgentBridgeTransportAcceptanceTests`, `AgentBridgeAcceptanceTests`, and `StoreAcceptanceTests` passed 26/26 with 0 failures/skips. Log: `/tmp/rr03-recovery-final-combined.log`; result bundle under `/tmp/rr03-recovery-tests/Logs/Test/`.
- Cleanup left no registered `com.rekonlabs.ReleaseRadar.BridgeAgent` LaunchAgent and no exact broker/tool process. RR-03 remains not accepted and not released pending fresh independent code, QA, architecture, and security/privacy review; RR-04 remains closed.

DONE
Implementation commits before the current recovery commit: `6b7262c`, `fa8eea0`, `abb92ef`, `6cbfcb4`

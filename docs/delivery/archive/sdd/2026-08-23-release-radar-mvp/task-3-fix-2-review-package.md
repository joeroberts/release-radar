# Review package: 21fefee9022a2e04aa3af710382433f24b83d792..HEAD

## Commits
8e35e9c docs: record RR-03 fix round two
6cbfcb4 fix: enforce bridge deadline inside store transaction

## Files changed
 .../AgentBridge/AgentCommandDispatcher.swift       | 11 ++++-
 .../AgentBridgeApplicationHost.swift               |  2 +-
 ReleaseRadarTests/AgentBridgeAcceptanceTests.swift | 47 ++++++++++++++++++++++
 docs/delivery/progress.md                          | 16 ++++----
 4 files changed, 66 insertions(+), 10 deletions(-)

## Diff
diff --git a/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift b/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift
index c2c6611..d8da1f7 100644
--- a/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift
+++ b/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift
@@ -4,21 +4,24 @@ public actor AgentCommandDispatcher {
     public static let supportedVersion = 1
 
     private let store: DeliveryStore
     private let projectRegistry: any AuthorizedProjectRegistry
 
     public init(store: DeliveryStore, projectRegistry: any AuthorizedProjectRegistry) {
         self.store = store
         self.projectRegistry = projectRegistry
     }
 
-    public func dispatch(_ envelope: AgentCommandEnvelope) async -> AgentCommandResult {
+    public func dispatch(
+        _ envelope: AgentCommandEnvelope,
+        deadline: TimeInterval? = nil
+    ) async -> AgentCommandResult {
         if let error = validate(envelope) {
             return .init(entityIDs: [], auditEventID: nil, error: error)
         }
         guard let project = projectRegistry.resolve(projectRoot: envelope.projectRoot) else {
             return .init(entityIDs: [], auditEventID: nil, error: .unauthorizedProjectRoot)
         }
 
         do {
             let requestBody = try canonicalRequestBody(envelope)
             let auditEventID = AuditEventID(rawValue: UUID().uuidString)
@@ -29,20 +32,23 @@ public actor AgentCommandDispatcher {
                     actor: .init(
                         id: "release-radar-agent",
                         threadID: envelope.assertedThreadID,
                         threadAttribution: envelope.assertedThreadID == nil
                             ? ThreadAttribution.none
                             : ThreadAttribution.asserted
                     ),
                     reason: envelope.reason,
                     auditEventID: auditEventID
                 ) { connection in
+                    if let deadline, deadline <= Date().timeIntervalSince1970 {
+                        throw DispatchControl.expired
+                    }
                     if let prior = try connection.row(
                         "SELECT request_body, result_data FROM agent_command_requests WHERE request_id = ?",
                         bindings: [.text(envelope.requestID.uuidString)]
                     ) {
                         guard prior["request_body"] == .blob(requestBody),
                               case let .blob(priorResultData)? = prior["result_data"],
                               let priorResult = try? JSONDecoder().decode(AgentCommandResult.self, from: priorResultData)
                         else {
                             throw DispatchControl.requestIDReused
                         }
@@ -57,20 +63,22 @@ public actor AgentCommandDispatcher {
                             .blob(requestBody),
                             .blob(resultData),
                             .text(ISO8601DateFormatter().string(from: Date())),
                         ]
                     )
                     return result
                 }
             } catch let control as DispatchControl {
                 switch control {
                 case let .replay(result): return result
+                case .expired:
+                    return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
                 case .requestIDReused:
                     return .init(entityIDs: [], auditEventID: nil, error: .requestIDReused)
                 }
             }
         } catch let error as StoreError {
             if case .unavailable = error {
                 return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
             }
             return .init(entityIDs: [], auditEventID: nil, error: .internalFailure(error.localizedDescription))
         } catch {
@@ -359,19 +367,20 @@ public actor AgentCommandDispatcher {
             }
             if sqlite.message.localizedCaseInsensitiveContains("foreign key") {
                 return .invalidReference(sqlite.message)
             }
         }
         return .internalFailure(error.localizedDescription)
     }
 }
 
 private enum DispatchControl: Error, Sendable {
+    case expired
     case replay(AgentCommandResult)
     case requestIDReused
 }
 
 private enum CommandValidation: Error, Sendable {
     case invalidReference(String)
     case crossProject(String)
     case cycle(String)
 }
diff --git a/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift b/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
index 8bb6e46..8c036f7 100644
--- a/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
+++ b/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
@@ -233,21 +233,21 @@ private final class AgentBridgeAppCallback: NSObject, ReleaseRadarAppCallbackXPC
             }
             return
         }
 
         Task {
             await beforeDispatch(envelope)
             guard deadline > Date().timeIntervalSince1970 else {
                 replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
                 return
             }
-            let result = await dispatcher.dispatch(envelope)
+            let result = await dispatcher.dispatch(envelope, deadline: deadline)
             replyGate.send((try? JSONEncoder().encode(result)) ?? ReleaseRadarBridgeTransport.appUnavailableResultData())
         }
     }
 }
 
 private final class AgentBridgeDataReply: @unchecked Sendable {
     private let callback: (Data) -> Void
 
     init(_ callback: @escaping (Data) -> Void) {
         self.callback = callback
diff --git a/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift b/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift
index e71cae5..b99348c 100644
--- a/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift
+++ b/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift
@@ -1,15 +1,20 @@
 import Foundation
 import XCTest
 @testable import ReleaseRadarCore
 
 final class AgentBridgeAcceptanceTests: XCTestCase {
+    private final class StoreQueueGate: @unchecked Sendable {
+        let entered = DispatchSemaphore(value: 0)
+        let release = DispatchSemaphore(value: 0)
+    }
+
     func testValidTransitionCommitsAuditAndDurableReplayReturnsOriginalResult() async throws {
         let fixture = try await makeFixture()
         let requestID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
         let envelope = AgentCommandEnvelope(
             version: 1,
             requestID: requestID,
             projectRoot: fixture.projectRoot.path,
             assertedThreadID: "asserted-thread",
             reason: "Move RR-03 into implementation",
             command: .transitionTicket(ticketID: "RR-03", lane: .inProgress)
@@ -257,20 +262,62 @@ final class AgentBridgeAcceptanceTests: XCTestCase {
             requestID: UUID(),
             projectRoot: fixture.projectRoot.path,
             reason: "Must not write without app store",
             command: .transitionTicket(ticketID: "RR-03", lane: .blocked)
         ))
 
         XCTAssertEqual(result.error, .appUnavailable)
         XCTAssertEqual(try Data(contentsOf: corruptURL), bytes)
     }
 
+    func testTransportDeadlineExpiresWhileQueuedForStoreWithoutWriting() async throws {
+        let fixture = try await makeFixture()
+        let baseline = try await counts(fixture.store)
+        let gate = StoreQueueGate()
+        let store = fixture.store
+        let blocker = Task.detached {
+            try await store.read { _ in
+                gate.entered.signal()
+                gate.release.wait()
+            }
+        }
+        XCTAssertEqual(gate.entered.wait(timeout: .now() + 2), .success)
+
+        let deadline = Date().addingTimeInterval(0.1).timeIntervalSince1970
+        let dispatch = Task {
+            await fixture.dispatcher.dispatch(
+                .init(
+                    version: 1,
+                    requestID: UUID(uuidString: "77777777-7777-4777-8777-777777777777")!,
+                    projectRoot: fixture.projectRoot.path,
+                    reason: "Reject after store queue deadline",
+                    command: .transitionTicket(ticketID: "RR-03", lane: .inProgress)
+                ),
+                deadline: deadline
+            )
+        }
+        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
+            gate.release.signal()
+        }
+
+        let result = await dispatch.value
+        try await blocker.value
+
+        XCTAssertEqual(result.error, .appUnavailable)
+        let after = try await counts(fixture.store)
+        XCTAssertEqual(after, baseline)
+        let lane = try await fixture.store.read { connection in
+            try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-03'")
+        }
+        XCTAssertEqual(lane, TicketLane.backlog.rawValue)
+    }
+
     private struct Fixture {
         let databaseURL: URL
         let projectRoot: URL
         let store: DeliveryStore
         let registry: InMemoryAuthorizedProjectRegistry
         let dispatcher: AgentCommandDispatcher
     }
 
     private func makeFixture() async throws -> Fixture {
         let temporaryDirectory = FileManager.default.temporaryDirectory
diff --git a/docs/delivery/progress.md b/docs/delivery/progress.md
index 4c69b04..951693c 100644
--- a/docs/delivery/progress.md
+++ b/docs/delivery/progress.md
@@ -19,23 +19,23 @@ Deliver the signed native macOS MVP described by
 
 ## Repository
 
 - Local: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
 - Remote: `https://github.com/joeroberts/release-radar`
 - Branch: `codex/release-radar-mvp`
 - Pull requests: prohibited by owner direction for this goal.
 
 ## Current gate
 
-- Current task: RR-03 fix round 1 is implemented; the two Required code-review contracts need scoped code/QA re-review before the remaining architecture and security/privacy gates.
+- Current task: RR-03 fix round 2 is implemented; the residual deadline contract needs scoped code/QA re-review before the remaining architecture and security/privacy gates.
 - Next eligible task: RR-03 scoped code/QA re-review only. RR-04 is not eligible until every Required RR-03 finding is closed and the release gate records acceptance.
-- Open product blockers: no known implementation blocker; independent confirmation of the two fixes remains open.
+- Open product blockers: no known implementation blocker; independent confirmation of the deadline fix remains open.
 - Open operational risks: macOS may require owner approval for the packaged LaunchAgent on another machine; startup reports the required System Settings action explicitly and fails closed until enabled.
 
 ## Task ledger
 
 Each task entry records status, verification, reviews with Required/Optional/Out-of-scope classification, decisions, risks, stop-rule events, commit SHA, and the next eligible task before release.
 
 ### RR-01 — Standalone signed application foundation
 
 - Status: Accepted.
 - Commits: `487647a` scaffold, `50dab32` evidence, `ca09ba8` focused-test fix, `c3e5f79` fix evidence.
@@ -65,20 +65,20 @@ Each task entry records status, verification, reviews with Required/Optional/Out
 - Stop-rule events: The original read-boundary remediation stopped after two rounds when review found that the denylist still admitted SQLite connection-state mutation. A fresh recovery implementer preserved the existing lease, audit, and transaction protections and replaced only the read authorizer policy with the smaller fail-closed observational allowlist.
 - Next eligible task: RR-03 typed agent action bridge.
 
 ### RR-03 release gate
 
 - TPM: GO; RR-02 is technically accepted with all Required findings closed, scope controlled, and the recorded stop-rule recovery complete.
 - Delivery Manager: GO; RR-02 commits, focused verification, signed build, independent reviews, and stop-rule evidence are durable; RR-03 is dependency-safe and released to one fresh Implementer with no concurrent writer.
 
 ### RR-03 — Typed agent action bridge
 
-- Status: Fix round 1 implemented; awaiting scoped code/QA re-review. Not accepted or released.
-- Commits: `6b7262c` (`feat: add typed agent delivery actions`), `fa8eea0` (`feat: add signed agent bridge transport`), and `abb92ef` (`fix: enforce agent bridge result contracts`).
+- Status: Fix round 2 implemented; awaiting scoped code/QA re-review. Not accepted or released.
+- Commits: `6b7262c` (`feat: add typed agent delivery actions`), `fa8eea0` (`feat: add signed agent bridge transport`), `abb92ef` (`fix: enforce agent bridge result contracts`), and `6cbfcb4` (`fix: enforce bridge deadline inside store transaction`).
 - Implemented scope: the committed typed command/dispatcher core plus a packaged MCP stdio tool, sandboxed LaunchAgent broker, application-hosted callback, exact version/size/deadline bounds, same-user and pinned team/identifier signing requirements on every XPC hop, app lifecycle registration, explicit unavailable/approval errors, and fail-closed disconnect behavior. The broker/tool do not link `ReleaseRadarCore` or SQLite and cannot open the authoritative store.
-- TDD: the transport scenario began RED with no application host, then proved registration/launch, signed-peer checks, valid commit/audit, durable replay, identity/version/envelope rejection, app-disconnect no-write behavior, production startup wiring, cleanup ownership, and typed MCP discovery. Fix round 1 separately observed RED for the missing pre-dispatch deadline contract and incorrect MCP domain-error flag, then GREEN after the minimal fixes. Detailed commands and logs are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-3-report.md`.
-- Verification: a fresh normal Debug app build passed. Strict deep signing plus explicit app/broker/tool requirements passed; the broker had exactly sandbox + the approved app group, the tool was unsandboxed with no app group, no embedded profile existed, and `otool` showed no Core/SQLite dependency in either executable. The final fix-round combined run exercised byte-identical normal-package broker/tool binaries and passed 23/23 transport/core/store tests with 0 failures/skips, including a delayed callback that produced `appUnavailable` and no later delivery/audit/request write plus MCP success/error flag assertions. Cleanup left no registered service or exact helper process; diff checks passed.
+- TDD: the transport scenario began RED with no application host, then proved registration/launch, signed-peer checks, valid commit/audit, durable replay, identity/version/envelope rejection, app-disconnect no-write behavior, production startup wiring, cleanup ownership, and typed MCP discovery. Fix round 1 separately observed RED for the missing pre-dispatch deadline contract and incorrect MCP domain-error flag. Fix round 2 observed RED for the absent dispatcher deadline context, then GREEN with a deterministic store-actor queue hold that expires before release and proves no delivery/audit/request write. Detailed commands and logs are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-3-report.md`.
+- Verification: a fresh normal Debug app build passed. Strict deep signing plus explicit app/broker/tool requirements passed; the broker had exactly sandbox + the approved app group, the tool was unsandboxed with no app group, no embedded profile existed, and `otool` showed no Core/SQLite dependency in either executable. The fix-round-2 combined run exercised byte-identical normal-package broker/tool binaries and passed 24/24 transport/core/store tests with 0 failures/skips. This includes the real transport timeout proof, MCP success/error flag assertions, and the queued-store regression returning `appUnavailable` with delivery/audit/request/lane state unchanged. Cleanup left no registered service or exact helper process; diff checks passed.
 - Stop-rule recovery: the earlier anonymous-endpoint and app-owned listener attempts remain recorded as stopped and removed. The fresh recovery used the architect-approved minimal correction: a sandboxed broker with the same-team app group, an unsandboxed tool without the group, two team-prefixed Mach services, and no weaker fallback.
-- Required blocker: code review identified two Important contracts: prevent post-timeout callback mutation and set MCP `isError` for structured domain failures. Both are implemented in `abb92ef`; scoped independent re-review is still required.
-- Reviews: initial code review Required 2, both addressed in fix round 1; QA's prior 23-case proof remained green but did not cover them. Scoped code/QA re-review and the remaining architecture/security/privacy reviews are pending.
+- Required blocker: scoped re-review found one residual Important deadline contract: store/dispatcher actor contention could expire after the callback guard but before mutation. It is implemented in `6cbfcb4`; scoped independent re-review is still required.
+- Reviews: initial code review Required 2, both addressed in fix round 1. The residual deadline finding is addressed in fix round 2 with direct queued-store coverage. Scoped code/QA re-review and the remaining architecture/security/privacy reviews are pending.
 - Decisions/risks: preserve the app-only SQLite writer boundary. The app composes persisted authorized roots into the existing registry seam; the broker holds only the latest authenticated callback in memory. On machines where ServiceManagement returns `requiresApproval`, the app logs the explicit Login Items & Extensions owner action and does not weaken or bypass the gate.
 - Next eligible task: scoped RR-03 code/QA re-review, followed by architecture and security/privacy verification if clean. RR-04 remains closed.

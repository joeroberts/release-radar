# Review package: d393dbf076a7c2974520f1bf304d50f130fca688..HEAD

## Commits
21fefee docs: record RR-03 fix round one
abb92ef fix: enforce agent bridge result contracts

## Files changed
 ReleaseRadar/App/ReleaseRadarApp.swift             |  8 +++--
 ReleaseRadarAgentTools/main.swift                  | 12 ++++++-
 .../AgentBridgeApplicationHost.swift               | 30 +++++++++++++----
 .../AgentBridgeTransportAcceptanceTests.swift      | 38 +++++++++++++++++++++-
 docs/delivery/progress.md                          | 20 ++++++------
 5 files changed, 88 insertions(+), 20 deletions(-)

## Diff
diff --git a/ReleaseRadar/App/ReleaseRadarApp.swift b/ReleaseRadar/App/ReleaseRadarApp.swift
index 37856f3..c3ffc50 100644
--- a/ReleaseRadar/App/ReleaseRadarApp.swift
+++ b/ReleaseRadar/App/ReleaseRadarApp.swift
@@ -22,26 +22,30 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
             }
         }
     }
 
     func applicationWillTerminate(_ notification: Notification) {
         agentBridgeHost?.disconnectCallback()
         agentBridgeHost = nil
     }
 
     func startAgentBridge(
-        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL()
+        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL(),
+        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void = { _ in }
     ) async throws -> AgentBridgeApplicationHost {
         if let agentBridgeHost {
             return agentBridgeHost
         }
-        let host = try await AgentBridgeApplicationHost.start(databaseURL: databaseURL)
+        let host = try await AgentBridgeApplicationHost.start(
+            databaseURL: databaseURL,
+            beforeDispatch: beforeDispatch
+        )
         agentBridgeHost = host
         return host
     }
 }
 
 @main
 struct ReleaseRadarApp: App {
     @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
     @State private var model = AppModel()
 
diff --git a/ReleaseRadarAgentTools/main.swift b/ReleaseRadarAgentTools/main.swift
index bafaa3e..0db398a 100644
--- a/ReleaseRadarAgentTools/main.swift
+++ b/ReleaseRadarAgentTools/main.swift
@@ -123,23 +123,24 @@ private struct MCPServer {
             return success(id: id, result: ["tools": Self.toolDefinitions])
         case "tools/call":
             guard initialized else { return error(id: id, code: -32002, message: "MCP session is not initialized") }
             guard let params = request["params"] as? [String: Any],
                   let name = params["name"] as? String,
                   let arguments = params["arguments"] as? [String: Any]
             else { return error(id: id, code: -32602, message: "Invalid tool arguments") }
             do {
                 let envelope = try Self.makeEnvelope(tool: name, arguments: arguments)
                 let response = try BridgeClient().forward(envelope)
+                let isError = try Self.isDomainError(response)
                 return success(id: id, result: [
                     "content": [["type": "text", "text": String(decoding: response, as: UTF8.self)]],
-                    "isError": false,
+                    "isError": isError,
                 ])
             } catch ToolFailure.bridgeUnavailable {
                 return error(id: id, code: -32001, message: "Release Radar app is unavailable")
             } catch {
                 return self.error(id: id, code: -32602, message: error.localizedDescription)
             }
         default:
             return error(id: id, code: -32601, message: "Method not found")
         }
     }
@@ -161,20 +162,29 @@ private struct MCPServer {
         if let threadID = arguments["assertedThreadID"] as? String {
             envelope["assertedThreadID"] = threadID
         }
         let data = try JSONSerialization.data(withJSONObject: envelope)
         guard data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes else {
             throw ToolFailure.invalidRequest("Command envelope exceeds the transport limit")
         }
         return data
     }
 
+    private static func isDomainError(_ response: Data) throws -> Bool {
+        guard response.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
+              let result = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
+              result["entityIDs"] is [Any]
+        else { throw ToolFailure.bridgeUnavailable }
+        guard let error = result["error"] else { return false }
+        return !(error is NSNull)
+    }
+
     private static func commandCase(
         tool: String,
         arguments: [String: Any]
     ) throws -> (String, [String: Any]) {
         switch tool {
         case "release_radar_upsert_phase":
             return ("upsertPhase", ["phaseID": try string("phaseID", in: arguments), "name": try string("name", in: arguments)])
         case "release_radar_upsert_ticket":
             return ("upsertTicket", [
                 "ticketID": try string("ticketID", in: arguments),
diff --git a/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift b/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
index ea3f4af..8bb6e46 100644
--- a/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
+++ b/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
@@ -24,33 +24,39 @@ enum AgentBridgeApplicationError: Error, LocalizedError, Equatable {
         }
     }
 }
 
 final class AgentBridgeApplicationHost: @unchecked Sendable {
     private let service: SMAppService
     private let callback: AgentBridgeAppCallback
     private var connection: NSXPCConnection?
     private var registeredHere = false
 
-    private init(dispatcher: AgentCommandDispatcher) {
+    private init(
+        dispatcher: AgentCommandDispatcher,
+        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void
+    ) {
         service = .agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName)
-        callback = AgentBridgeAppCallback(dispatcher: dispatcher)
+        callback = AgentBridgeAppCallback(dispatcher: dispatcher, beforeDispatch: beforeDispatch)
     }
 
-    static func start(databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL()) async throws -> AgentBridgeApplicationHost {
+    static func start(
+        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL(),
+        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void = { _ in }
+    ) async throws -> AgentBridgeApplicationHost {
         let store = DeliveryStore(databaseURL: databaseURL)
         let projects = try await loadAuthorizedProjects(from: store)
         let dispatcher = AgentCommandDispatcher(
             store: store,
             projectRegistry: InMemoryAuthorizedProjectRegistry(projects: projects)
         )
-        let host = AgentBridgeApplicationHost(dispatcher: dispatcher)
+        let host = AgentBridgeApplicationHost(dispatcher: dispatcher, beforeDispatch: beforeDispatch)
         do {
             try host.registerIfNeeded()
             try await host.connect()
             return host
         } catch {
             host.disconnectCallback()
             try? host.rollbackRegistration()
             throw error
         }
     }
@@ -187,48 +193,60 @@ final class AgentBridgeApplicationHost: @unchecked Sendable {
                     canonicalRoot: canonicalRoot,
                     authorizedRoots: roots
                 )
             }
         }
     }
 }
 
 private final class AgentBridgeAppCallback: NSObject, ReleaseRadarAppCallbackXPC, @unchecked Sendable {
     private let dispatcher: AgentCommandDispatcher
+    private let beforeDispatch: @Sendable (AgentCommandEnvelope) async -> Void
 
-    init(dispatcher: AgentCommandDispatcher) {
+    init(
+        dispatcher: AgentCommandDispatcher,
+        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void
+    ) {
         self.dispatcher = dispatcher
+        self.beforeDispatch = beforeDispatch
     }
 
     func dispatch(
         _ version: Int,
         envelope data: Data,
         deadline: TimeInterval,
         withReply reply: @escaping (Data) -> Void
     ) {
         let replyGate = AgentBridgeDataReply(reply)
+        let now = Date().timeIntervalSince1970
         guard version == ReleaseRadarBridgeTransport.version,
               data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
-              deadline > Date().timeIntervalSince1970,
+              deadline > now,
+              deadline - now <= ReleaseRadarBridgeTransport.maximumDeadlineInterval,
               ReleaseRadarBridgeTransport.envelopeVersion(in: data) == ReleaseRadarBridgeTransport.version,
               let envelope = try? JSONDecoder().decode(AgentCommandEnvelope.self, from: data)
         else {
             if let found = ReleaseRadarBridgeTransport.envelopeVersion(in: data),
                found != ReleaseRadarBridgeTransport.version {
                 replyGate.send(ReleaseRadarBridgeTransport.unsupportedVersionResultData(found: found))
             } else {
                 replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
             }
             return
         }
 
         Task {
+            await beforeDispatch(envelope)
+            guard deadline > Date().timeIntervalSince1970 else {
+                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
+                return
+            }
             let result = await dispatcher.dispatch(envelope)
             replyGate.send((try? JSONEncoder().encode(result)) ?? ReleaseRadarBridgeTransport.appUnavailableResultData())
         }
     }
 }
 
 private final class AgentBridgeDataReply: @unchecked Sendable {
     private let callback: (Data) -> Void
 
     init(_ callback: @escaping (Data) -> Void) {
diff --git a/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift b/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
index bb62896..4b771aa 100644
--- a/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
+++ b/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
@@ -1,22 +1,29 @@
 import Foundation
 import ServiceManagement
 import XCTest
 @testable import ReleaseRadar
 @testable import ReleaseRadarCore
 
 @MainActor
 final class AgentBridgeTransportAcceptanceTests: XCTestCase {
     func testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp() async throws {
         let fixture = try await makeTransportFixture()
+        let delayedRequestID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
         let appDelegate = AppDelegate()
-        let host = try await appDelegate.startAgentBridge(databaseURL: fixture.databaseURL)
+        let host = try await appDelegate.startAgentBridge(
+            databaseURL: fixture.databaseURL,
+            beforeDispatch: { envelope in
+                guard envelope.requestID == delayedRequestID else { return }
+                try? await Task.sleep(for: .milliseconds(10_500))
+            }
+        )
         defer {
             host.disconnectCallback()
             try? host.unregister()
         }
 
         let packagedTool = Bundle.main.bundleURL
             .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
         let wrongTool = Bundle.main.bundleURL
             .deletingLastPathComponent()
             .appendingPathComponent("ReleaseRadarWrongAgentTools")
@@ -30,20 +37,21 @@ final class AgentBridgeTransportAcceptanceTests: XCTestCase {
             "projectRoot": fixture.projectRoot.path,
             "reason": "Prove the packaged signed transport",
             "ticketID": "RR-03",
             "lane": "in_progress",
         ]
 
         let first = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
         let firstResult = try decodeCommandResult(first)
         XCTAssertNil(firstResult.error)
         XCTAssertNotNil(firstResult.auditEventID)
+        XCTAssertEqual(mcpIsError(first), false)
 
         let replay = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
         XCTAssertEqual(try decodeCommandResult(replay), firstResult)
         var counts = try await transportCounts(fixture.store)
         XCTAssertEqual(counts, [1, 1])
 
         let rejectedPeer = try runTool(wrongTool, tool: "release_radar_transition_ticket", arguments: arguments)
         XCTAssertEqual(jsonRPCErrorCode(rejectedPeer), -32001)
         counts = try await transportCounts(fixture.store)
         XCTAssertEqual(counts, [1, 1])
@@ -63,30 +71,44 @@ final class AgentBridgeTransportAcceptanceTests: XCTestCase {
         let wrongEnvelope = try runTool(
             packagedTool,
             tool: "release_radar_transition_ticket",
             arguments: wrongEnvelopeArguments
         )
         let wrongEnvelopeResult = try decodeCommandResult(wrongEnvelope)
         XCTAssertEqual(wrongEnvelopeResult.error, .unsupportedVersion(found: 999, supported: 1))
         counts = try await transportCounts(fixture.store)
         XCTAssertEqual(counts, [1, 1])
 
+        let expired = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: [
+            "version": 1,
+            "requestID": delayedRequestID.uuidString,
+            "projectRoot": fixture.projectRoot.path,
+            "reason": "Do not persist after the transport deadline",
+            "ticketID": "RR-03",
+            "lane": "blocked",
+        ])
+        XCTAssertEqual(try decodeCommandResult(expired).error, .appUnavailable)
+        try await Task.sleep(for: .seconds(1))
+        let expiredCounts = try await expiredRequestCounts(fixture.store)
+        XCTAssertEqual(expiredCounts, [0, 0, 0])
+
         host.disconnectCallback()
         let unavailable = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: [
             "version": 1,
             "requestID": "88888888-8888-4888-8888-888888888888",
             "projectRoot": fixture.projectRoot.path,
             "reason": "Do not persist without the app callback",
             "ticketID": "RR-03",
             "lane": "blocked",
         ])
         XCTAssertEqual(try decodeCommandResult(unavailable).error, .appUnavailable)
+        XCTAssertEqual(mcpIsError(unavailable), true)
         counts = try await transportCounts(fixture.store)
         XCTAssertEqual(counts, [1, 1])
 
         try host.unregister()
         switch SMAppService.agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName).status {
         case .notRegistered, .notFound:
             break
         default:
             XCTFail("Explicit cleanup left the bridge registered")
         }
@@ -207,23 +229,37 @@ final class AgentBridgeTransportAcceptanceTests: XCTestCase {
         else {
             throw TransportTestError.invalidResponse(String(describing: response))
         }
         return try JSONDecoder().decode(AgentCommandResult.self, from: data)
     }
 
     private func jsonRPCErrorCode(_ response: [String: Any]) -> Int? {
         ((response["error"] as? [String: Any])?["code"] as? NSNumber)?.intValue
     }
 
+    private func mcpIsError(_ response: [String: Any]) -> Bool? {
+        (response["result"] as? [String: Any])?["isError"] as? Bool
+    }
+
     private func transportCounts(_ store: DeliveryStore) async throws -> [Int64] {
         try await store.read { connection in
             [
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Prove the packaged signed transport'") ?? -1,
                 try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '77777777-7777-4777-8777-777777777777'") ?? -1,
             ]
         }
     }
+
+    private func expiredRequestCounts(_ store: DeliveryStore) async throws -> [Int64] {
+        try await store.read { connection in
+            [
+                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'RR-03' AND lane = 'blocked'") ?? -1,
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Do not persist after the transport deadline'") ?? -1,
+                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '99999999-9999-4999-8999-999999999999'") ?? -1,
+            ]
+        }
+    }
 }
 
 private enum TransportTestError: Error {
     case invalidResponse(String)
 }
diff --git a/docs/delivery/progress.md b/docs/delivery/progress.md
index 16be2a9..4c69b04 100644
--- a/docs/delivery/progress.md
+++ b/docs/delivery/progress.md
@@ -19,23 +19,23 @@ Deliver the signed native macOS MVP described by
 
 ## Repository
 
 - Local: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
 - Remote: `https://github.com/joeroberts/release-radar`
 - Branch: `codex/release-radar-mvp`
 - Pull requests: prohibited by owner direction for this goal.
 
 ## Current gate
 
-- Current task: RR-03 complete implementation is ready for independent code, QA, architecture, and security/privacy review.
-- Next eligible task: RR-03 independent review only. RR-04 is not eligible until every Required RR-03 finding is closed and the release gate records acceptance.
-- Open product blockers: no implementation blocker; the RR-03 independent review gate remains open.
+- Current task: RR-03 fix round 1 is implemented; the two Required code-review contracts need scoped code/QA re-review before the remaining architecture and security/privacy gates.
+- Next eligible task: RR-03 scoped code/QA re-review only. RR-04 is not eligible until every Required RR-03 finding is closed and the release gate records acceptance.
+- Open product blockers: no known implementation blocker; independent confirmation of the two fixes remains open.
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
 
-- Status: Complete implementation; awaiting independent review. Not accepted or released.
-- Commits: `6b7262c` (`feat: add typed agent delivery actions`) and `fa8eea0` (`feat: add signed agent bridge transport`).
+- Status: Fix round 1 implemented; awaiting scoped code/QA re-review. Not accepted or released.
+- Commits: `6b7262c` (`feat: add typed agent delivery actions`), `fa8eea0` (`feat: add signed agent bridge transport`), and `abb92ef` (`fix: enforce agent bridge result contracts`).
 - Implemented scope: the committed typed command/dispatcher core plus a packaged MCP stdio tool, sandboxed LaunchAgent broker, application-hosted callback, exact version/size/deadline bounds, same-user and pinned team/identifier signing requirements on every XPC hop, app lifecycle registration, explicit unavailable/approval errors, and fail-closed disconnect behavior. The broker/tool do not link `ReleaseRadarCore` or SQLite and cannot open the authoritative store.
-- TDD: the transport scenario began RED with no application host, then proved registration/launch, signed-peer checks, valid commit/audit, durable replay, identity/version/envelope rejection, app-disconnect no-write behavior, production startup wiring, cleanup ownership, and typed MCP discovery through focused RED→GREEN cycles. Detailed commands and logs are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-3-report.md`.
-- Verification: a fresh normal Debug app build passed. Strict deep signing plus explicit app/broker/tool requirements passed; the broker had exactly sandbox + the approved app group, the tool was unsandboxed with no app group, no embedded profile existed, and `otool` showed no Core/SQLite dependency in either executable. The final combined run exercised byte-identical normal-package broker/tool binaries and passed 23/23 transport/core/store tests with 0 failures/skips. Cleanup left no registered service or exact helper process; diff checks passed.
+- TDD: the transport scenario began RED with no application host, then proved registration/launch, signed-peer checks, valid commit/audit, durable replay, identity/version/envelope rejection, app-disconnect no-write behavior, production startup wiring, cleanup ownership, and typed MCP discovery. Fix round 1 separately observed RED for the missing pre-dispatch deadline contract and incorrect MCP domain-error flag, then GREEN after the minimal fixes. Detailed commands and logs are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-3-report.md`.
+- Verification: a fresh normal Debug app build passed. Strict deep signing plus explicit app/broker/tool requirements passed; the broker had exactly sandbox + the approved app group, the tool was unsandboxed with no app group, no embedded profile existed, and `otool` showed no Core/SQLite dependency in either executable. The final fix-round combined run exercised byte-identical normal-package broker/tool binaries and passed 23/23 transport/core/store tests with 0 failures/skips, including a delayed callback that produced `appUnavailable` and no later delivery/audit/request write plus MCP success/error flag assertions. Cleanup left no registered service or exact helper process; diff checks passed.
 - Stop-rule recovery: the earlier anonymous-endpoint and app-owned listener attempts remain recorded as stopped and removed. The fresh recovery used the architect-approved minimal correction: a sandboxed broker with the same-team app group, an unsandboxed tool without the group, two team-prefixed Mach services, and no weaker fallback.
-- Required blocker: none in implementation. Independent RR-03 reviews are still required before acceptance or RR-04 release.
-- Reviews: not started for the complete slice; Required findings from code, QA, architecture, or security/privacy review will block acceptance.
+- Required blocker: code review identified two Important contracts: prevent post-timeout callback mutation and set MCP `isError` for structured domain failures. Both are implemented in `abb92ef`; scoped independent re-review is still required.
+- Reviews: initial code review Required 2, both addressed in fix round 1; QA's prior 23-case proof remained green but did not cover them. Scoped code/QA re-review and the remaining architecture/security/privacy reviews are pending.
 - Decisions/risks: preserve the app-only SQLite writer boundary. The app composes persisted authorized roots into the existing registry seam; the broker holds only the latest authenticated callback in memory. On machines where ServiceManagement returns `requiresApproval`, the app logs the explicit Login Items & Extensions owner action and does not weaken or bypass the gate.
-- Next eligible task: independent RR-03 code review, QA verification, architecture review, and security/privacy verification. RR-04 remains closed.
+- Next eligible task: scoped RR-03 code/QA re-review, followed by architecture and security/privacy verification if clean. RR-04 remains closed.

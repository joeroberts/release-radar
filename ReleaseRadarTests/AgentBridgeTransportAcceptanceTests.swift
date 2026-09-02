import AppKit
import Foundation
import ServiceManagement
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class AgentBridgeTransportAcceptanceTests: XCTestCase {
    private final class OneShotRequestGate: @unchecked Sendable {
        private let lock = NSLock()
        private var requestIDs: Set<UUID> = []

        func take(_ requestID: UUID) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return requestIDs.insert(requestID).inserted
        }
    }

    private final class AsyncSignal: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?
        private var signaled = false

        func wait() async {
            await withCheckedContinuation { continuation in
                lock.lock()
                if signaled {
                    signaled = false
                    lock.unlock()
                    continuation.resume()
                } else {
                    self.continuation = continuation
                    lock.unlock()
                }
            }
        }

        func signal() {
            lock.lock()
            let continuation = continuation
            self.continuation = nil
            if continuation == nil {
                signaled = true
            }
            lock.unlock()
            continuation?.resume()
        }
    }

    private final class CallbackInvalidationGate: @unchecked Sendable {
        let entered = AsyncSignal()
        let release = AsyncSignal()
    }

    private final class ResultCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var captured: AgentCommandResult?

        func set(_ result: AgentCommandResult) {
            lock.lock()
            captured = result
            lock.unlock()
        }

        func get() -> AgentCommandResult? {
            lock.lock()
            defer { lock.unlock() }
            return captured
        }
    }

    private final class DataCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Data, Error>?

        func set(_ result: Result<Data, Error>) {
            lock.lock()
            self.result = result
            lock.unlock()
        }

        func get() throws -> Data {
            lock.lock()
            defer { lock.unlock() }
            return try XCTUnwrap(result).get()
        }

        func getIfAvailable() -> Result<Data, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }

    func testPackagedToolRespondsToInitializeWhileInputRemainsOpen() async throws {
        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: packagedTool.path))

        let process = Process()
        process.executableURL = packagedTool
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        try process.run()
        defer {
            try? input.fileHandleForWriting.close()
            process.waitUntilExit()
        }

        let response = DataCapture()
        DispatchQueue.global().async {
            response.set(Result {
                try Self.readLine(from: output.fileHandleForReading)
            })
        }

        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 42,
            "method": "initialize",
            "params": [
                "protocolVersion": "2025-06-18",
                "capabilities": [:],
                "clientInfo": ["name": "ReleaseRadarTests", "version": "1"],
            ],
        ]
        var requestData = try JSONSerialization.data(withJSONObject: request)
        requestData.append(0x0A)
        input.fileHandleForWriting.write(requestData)

        let deadline = ContinuousClock.now + .seconds(2)
        var captured = response.getIfAvailable()
        while captured == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
            captured = response.getIfAvailable()
        }
        guard let captured else {
            XCTFail("The MCP server did not respond to initialize while stdin remained open")
            return
        }

        let responseData = try captured.get()
        guard let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              (object["id"] as? NSNumber)?.intValue == 42,
              let result = object["result"] as? [String: Any]
        else {
            throw TransportTestError.invalidResponse(String(decoding: responseData, as: UTF8.self))
        }
        XCTAssertEqual(result["protocolVersion"] as? String, "2025-06-18")
    }

    func testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp() async throws {
        let bridgeService = SMAppService.agent(
            plistName: ReleaseRadarBridgeTransport.launchAgentPlistName
        )
        switch bridgeService.status {
        case .notRegistered:
            break
        case .notFound:
            XCTFail("The packaged bridge service was not found")
            return
        case .enabled:
            XCTFail("The packaged bridge service was already registered")
            return
        case .requiresApproval:
            XCTFail("The packaged bridge service requires approval")
            return
        @unknown default:
            XCTFail("The packaged bridge service has an unknown registration status")
            return
        }

        do {
            try bridgeService.register()
        } catch {
            XCTFail("Could not register the packaged bridge service")
            return
        }
        var registrationOwned = true
        let cleanupOwnedBridgeService: () -> Void = {
            guard registrationOwned else { return }
            do {
                try bridgeService.unregister()
            } catch {
                XCTFail("Could not unregister the owned packaged bridge service")
            }
            switch bridgeService.status {
            case .notRegistered:
                registrationOwned = false
            case .notFound:
                XCTFail("The owned packaged bridge service disappeared during cleanup")
            case .enabled:
                XCTFail("Explicit cleanup left the owned bridge service registered")
            case .requiresApproval:
                XCTFail("The owned bridge service requires approval after cleanup")
            @unknown default:
                XCTFail("The owned bridge service has an unknown cleanup status")
            }
        }
        defer {
            cleanupOwnedBridgeService()
        }
        switch bridgeService.status {
        case .enabled:
            break
        case .notRegistered:
            XCTFail("The packaged bridge service remained unregistered")
            return
        case .notFound:
            XCTFail("The packaged bridge service disappeared after registration")
            return
        case .requiresApproval:
            XCTFail("The packaged bridge service requires approval after registration")
            return
        @unknown default:
            XCTFail("The packaged bridge service has an unknown post-registration status")
            return
        }

        let fixture = try await makeTransportFixture()
        let delayedRequestID = UUID(uuidString: "99999999-9999-4999-8999-999999999991")!
        let committedReplyLostRequestID = UUID(uuidString: "99999999-9999-4999-8999-999999999992")!
        let oneShotDelay = OneShotRequestGate()
        let committedResult = ResultCapture()
        let appDelegate = AppDelegate()
        let host = try await appDelegate.startAgentBridge(
            databaseURL: fixture.databaseURL,
            beforeDispatch: { envelope in
                guard envelope.requestID == delayedRequestID,
                      oneShotDelay.take(envelope.requestID)
                else { return }
                try? await Task.sleep(for: .milliseconds(10_500))
            },
            afterDispatchBeforeReply: { envelope, result in
                guard envelope.requestID == committedReplyLostRequestID,
                      oneShotDelay.take(envelope.requestID)
                else { return }
                committedResult.set(result)
                try? await Task.sleep(for: .milliseconds(10_500))
            }
        )
        defer {
            host.disconnectCallback()
        }

        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let wrongTool = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("ReleaseRadarWrongAgentTools")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: packagedTool.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: wrongTool.path))

        let requestID = "77777777-7777-4777-8777-777777777777"
        let arguments: [String: Any] = [
            "version": 1,
            "requestID": requestID,
            "projectRoot": fixture.projectRoot.path,
            "reason": "Prove the packaged signed transport",
            "ticketID": "RR-03",
            "lane": "in_progress",
        ]

        let first = try Self.runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
        let firstResult = try decodeCommandResult(first)
        XCTAssertNil(firstResult.error)
        let firstAuditEventID = try XCTUnwrap(firstResult.auditEventID)
        XCTAssertEqual(mcpIsError(first), false)

        let exactPersistedState: () async throws -> [SQLiteValue] = {
            try await fixture.store.read { connection in
                [
                    .text(try connection.scalarText(
                        "SELECT lane FROM tickets WHERE id = 'RR-03' AND project_id = 'project-1'"
                    ) ?? "missing"),
                    .integer(try connection.scalarInt(
                        "SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '77777777-7777-4777-8777-777777777777'"
                    ) ?? -1),
                    .integer(try connection.scalarInt(
                        "SELECT COUNT(*) FROM audit_events WHERE reason = 'Prove the packaged signed transport'"
                    ) ?? -1),
                    .integer(try connection.scalarInt(
                        """
                        SELECT COUNT(*) FROM audit_events
                        WHERE id = ?
                          AND actor_id = 'release-radar-agent'
                          AND thread_id IS NULL
                          AND thread_attribution = 'none'
                          AND project_id = 'project-1'
                          AND entity_type = 'ticket'
                          AND entity_id = 'RR-03'
                          AND reason = 'Prove the packaged signed transport'
                          AND created_at <> ''
                        """,
                        bindings: [.text(firstAuditEventID.rawValue)]
                    ) ?? -1),
                ]
            }
        }

        let replay = try Self.runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
        XCTAssertEqual(try decodeCommandResult(replay), firstResult)
        let persistedStateBeforeRejectedPeer = try await exactPersistedState()
        XCTAssertEqual(
            persistedStateBeforeRejectedPeer,
            [.text("in_progress"), .integer(1), .integer(1), .integer(1)]
        )

        let guardedRequestID = UUID(uuidString: "77777777-7777-4777-8777-777777777779")!
        let guardedArguments: [String: Any] = [
            "version": 1,
            "requestID": guardedRequestID.uuidString,
            "projectRoot": fixture.projectRoot.path,
            "reason": "Accept a completed plan through the packaged signed transport",
            "ticketID": "RR-PLAN",
            "lane": "accepted",
            "ticketTaskPlanRevision": 2,
        ]
        let guardedFirst = try Self.runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: guardedArguments
        )
        let guardedFirstResult = try decodeCommandResult(guardedFirst)
        XCTAssertNil(guardedFirstResult.error)
        XCTAssertEqual(mcpIsError(guardedFirst), false)
        let guardedReplay = try Self.runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: guardedArguments
        )
        XCTAssertEqual(try decodeCommandResult(guardedReplay), guardedFirstResult)
        let guardedState = try await fixture.store.read { connection in
            [
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-PLAN'") ?? "missing",
                String(try connection.scalarInt("SELECT revision FROM ticket_task_plans WHERE ticket_id = 'RR-PLAN'") ?? -1),
                String(try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?", bindings: [.text(guardedRequestID.uuidString)]) ?? -1),
                String(try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Accept a completed plan through the packaged signed transport'") ?? -1),
            ]
        }
        XCTAssertEqual(guardedState, ["accepted", "2", "1", "1"])

        let activePhaseRequestID = UUID(uuidString: "77777777-7777-4777-8777-777777777778")!
        let activePhaseArguments: [String: Any] = [
            "version": 1,
            "requestID": activePhaseRequestID.uuidString,
            "projectRoot": fixture.projectRoot.path,
            "reason": "Select phase through the packaged signed transport",
            "phaseID": "phase-2",
        ]
        let activePhaseFirst = try Self.runTool(
            packagedTool,
            tool: "release_radar_set_active_phase",
            arguments: activePhaseArguments
        )
        let activePhaseFirstResult = try decodeCommandResult(activePhaseFirst)
        XCTAssertNil(activePhaseFirstResult.error)
        XCTAssertEqual(activePhaseFirstResult.entityIDs, ["phase-2"])
        XCTAssertEqual(mcpIsError(activePhaseFirst), false)
        let activePhaseAuditEventID = try XCTUnwrap(activePhaseFirstResult.auditEventID)

        let activePhaseReplay = try Self.runTool(
            packagedTool,
            tool: "release_radar_set_active_phase",
            arguments: activePhaseArguments
        )
        XCTAssertEqual(try decodeCommandResult(activePhaseReplay), activePhaseFirstResult)
        XCTAssertEqual(mcpIsError(activePhaseReplay), false)
        let activePhaseState: [SQLiteValue] = try await fixture.store.read { connection in
            let phaseID = try connection.scalarText(
                "SELECT phase_id FROM project_active_phases WHERE project_id = 'project-1'"
            ) ?? "missing"
            let requestCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?",
                bindings: [.text(activePhaseRequestID.uuidString)]
            ) ?? -1
            let auditCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM audit_events WHERE reason = 'Select phase through the packaged signed transport'"
            ) ?? -1
            let scopedAuditCount = try connection.scalarInt(
                """
                SELECT COUNT(*) FROM audit_events
                WHERE id = ?
                  AND actor_id = 'release-radar-agent'
                  AND thread_id IS NULL
                  AND thread_attribution = 'none'
                  AND project_id = 'project-1'
                  AND entity_type = 'phase'
                  AND entity_id = 'phase-2'
                  AND reason = 'Select phase through the packaged signed transport'
                  AND created_at <> ''
                """,
                bindings: [.text(activePhaseAuditEventID.rawValue)]
            ) ?? -1
            return [.text(phaseID), .integer(requestCount), .integer(auditCount), .integer(scopedAuditCount)]
        }
        let expectedActivePhaseState: [SQLiteValue] = [.text("phase-2"), .integer(1), .integer(1), .integer(1)]
        XCTAssertEqual(activePhaseState, expectedActivePhaseState)

        let rejectedPeer = try Self.runTool(wrongTool, tool: "release_radar_transition_ticket", arguments: arguments)
        XCTAssertEqual(try decodeCommandResult(rejectedPeer).error, .appUnavailable)
        XCTAssertEqual(mcpIsError(rejectedPeer), true)
        let persistedStateAfterRejectedPeer = try await exactPersistedState()
        XCTAssertEqual(persistedStateAfterRejectedPeer, persistedStateBeforeRejectedPeer)

        let wrongBridge = try Self.runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: arguments,
            environment: ["RELEASE_RADAR_WIRE_VERSION": "999"]
        )
        XCTAssertEqual(try decodeCommandResult(wrongBridge).error, .appUnavailable)
        XCTAssertEqual(mcpIsError(wrongBridge), true)
        var counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

        var wrongEnvelopeArguments = arguments
        wrongEnvelopeArguments["version"] = 999
        let wrongEnvelope = try Self.runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: wrongEnvelopeArguments
        )
        let wrongEnvelopeResult = try decodeCommandResult(wrongEnvelope)
        XCTAssertEqual(wrongEnvelopeResult.error, AgentCommandError.unsupportedVersion(found: 999, supported: 1))
        counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

        let expired = try Self.runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: [
            "version": 1,
            "requestID": delayedRequestID.uuidString,
            "projectRoot": fixture.projectRoot.path,
            "reason": "Do not persist after the transport deadline",
            "ticketID": "RR-03",
            "lane": "blocked",
        ])
        XCTAssertEqual(try decodeCommandResult(expired).error, .outcomeUnknown)
        XCTAssertEqual(mcpIsError(expired), true)
        try await Task.sleep(for: .seconds(1))
        let expiredCounts = try await expiredRequestCounts(fixture.store)
        XCTAssertEqual(expiredCounts, [0, 0, 0])

        let delayedReplay = try Self.runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: [
            "version": 1,
            "requestID": delayedRequestID.uuidString,
            "projectRoot": fixture.projectRoot.path,
            "reason": "Do not persist after the transport deadline",
            "ticketID": "RR-03",
            "lane": "blocked",
        ])
        let delayedReplayResult = try decodeCommandResult(delayedReplay)
        XCTAssertNil(delayedReplayResult.error)
        XCTAssertEqual(mcpIsError(delayedReplay), false)
        let delayedReplayCounts = try await requestCounts(
            fixture.store,
            requestID: delayedRequestID,
            reason: "Do not persist after the transport deadline"
        )
        XCTAssertEqual(delayedReplayCounts, [1, 1])

        let replyLostArguments: [String: Any] = [
            "version": 1,
            "requestID": committedReplyLostRequestID.uuidString,
            "projectRoot": fixture.projectRoot.path,
            "reason": "Commit before the transport reply is lost",
            "ticketID": "RR-03",
            "lane": "needs_review",
        ]
        let replyLost = try Self.runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: replyLostArguments
        )
        XCTAssertEqual(try decodeCommandResult(replyLost).error, .outcomeUnknown)
        XCTAssertEqual(mcpIsError(replyLost), true)
        let originalCommittedResult = try XCTUnwrap(committedResult.get())
        let replyLostReplay = try Self.runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: replyLostArguments
        )
        XCTAssertEqual(try decodeCommandResult(replyLostReplay), originalCommittedResult)
        let replyLostCounts = try await requestCounts(
            fixture.store,
            requestID: committedReplyLostRequestID,
            reason: "Commit before the transport reply is lost"
        )
        XCTAssertEqual(replyLostCounts, [1, 1])

        host.disconnectCallback()
        let unavailable = try Self.runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: [
            "version": 1,
            "requestID": "88888888-8888-4888-8888-888888888888",
            "projectRoot": fixture.projectRoot.path,
            "reason": "Do not persist without the app callback",
            "ticketID": "RR-03",
            "lane": "blocked",
        ])
        XCTAssertEqual(try decodeCommandResult(unavailable).error, .appUnavailable)
        XCTAssertEqual(mcpIsError(unavailable), true)
        counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

        cleanupOwnedBridgeService()
    }

    func testCallbackInvalidationAfterHandoffReturnsOutcomeUnknownAndReplayWritesOnce() async throws {
        let fixture = try await makeTransportFixture(lane: .needsReview)
        let requestID = UUID(uuidString: "99999999-9999-4999-8999-999999999993")!
        let invalidation = CallbackInvalidationGate()
        let appDelegate = AppDelegate()
        let host = try await appDelegate.startAgentBridge(
            databaseURL: fixture.databaseURL,
            beforeDispatch: { envelope in
                guard envelope.requestID == requestID else { return }
                invalidation.entered.signal()
                await invalidation.release.wait()
            }
        )
        defer {
            host.disconnectCallback()
            try? host.unregister()
        }
        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let projectRoot = fixture.projectRoot.path
        let pending = DataCapture()
        let pendingFinished = AsyncSignal()
        DispatchQueue.global().async {
            pending.set(Result {
                try Self.runToolData(packagedTool, tool: "release_radar_transition_ticket", arguments: [
                    "version": 1,
                    "requestID": requestID.uuidString,
                    "projectRoot": projectRoot,
                    "reason": "Invalidate the callback after broker handoff",
                    "ticketID": "RR-03",
                    "lane": "accepted",
                ])
            })
            pendingFinished.signal()
        }
        await invalidation.entered.wait()
        host.disconnectCallback()
        invalidation.release.signal()

        await pendingFinished.wait()
        let uncertain = try Self.decodeToolResponseData(pending.get())
        XCTAssertEqual(try decodeCommandResult(uncertain).error, .outcomeUnknown)
        XCTAssertEqual(mcpIsError(uncertain), true)
        try await Task.sleep(for: .milliseconds(500))

        let reconnectDelegate = AppDelegate()
        let reconnect = try await reconnectDelegate.startAgentBridge(databaseURL: fixture.databaseURL)
        defer { reconnect.disconnectCallback() }
        let replay = try Self.runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: [
            "version": 1,
            "requestID": requestID.uuidString,
            "projectRoot": projectRoot,
            "reason": "Invalidate the callback after broker handoff",
            "ticketID": "RR-03",
            "lane": "accepted",
        ])
        XCTAssertNil(try decodeCommandResult(replay).error)
        let replayCounts = try await requestCounts(
            fixture.store,
            requestID: requestID,
            reason: "Invalidate the callback after broker handoff"
        )
        XCTAssertEqual(replayCounts, [1, 1])
    }

    func testAfterReplyWorkCannotDelayCommittedToolResult() async throws {
        let fixture = try await makeTransportFixture(lane: .inProgress)
        let afterReplyGate = CallbackInvalidationGate()
        let appDelegate = AppDelegate()
        let host = try await appDelegate.startAgentBridge(
            databaseURL: fixture.databaseURL,
            afterReply: { _, result in
                guard result.error == nil else { return }
                afterReplyGate.entered.signal()
                await afterReplyGate.release.wait()
            }
        )
        defer {
            afterReplyGate.release.signal()
            host.disconnectCallback()
            try? host.unregister()
        }
        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let projectRoot = fixture.projectRoot.path
        let responseTask = Task.detached { @Sendable in
            try Self.runToolData(packagedTool, tool: "release_radar_transition_ticket", arguments: [
                "version": 1,
                "requestID": "99999999-9999-4999-8999-999999999995",
                "projectRoot": projectRoot,
                "reason": "Return before notification dispatch",
                "ticketID": "RR-03",
                "lane": "needs_review",
            ])
        }

        let responseData = try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { try await responseTask.value }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TransportTestError.timedOut
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
        let toolResponse = try Self.decodeToolResponseData(responseData)
        let result = try decodeCommandResult(toolResponse)
        XCTAssertNil(result.error)
        _ = try XCTUnwrap(result.auditEventID, "The required transition must commit before waiting for after-reply work")
        XCTAssertEqual(mcpIsError(toolResponse), false)
        await afterReplyGate.entered.wait()
    }

    func testMalformedNumbersAndPresentNonStringOptionalsRejectBeforeTransportOrWrite() async throws {
        let fixture = try await makeTransportFixture()
        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let base: [String: Any] = [
            "version": 1,
            "requestID": "99999999-9999-4999-8999-999999999994",
            "projectRoot": fixture.projectRoot.path,
            "reason": "Reject malformed tool input",
            "ticketID": "RR-03",
            "lane": "blocked",
        ]
        let cases: [(String, String, [String: Any])] = [
            ("Boolean version", "release_radar_transition_ticket", base.merging(["version": true]) { _, new in new }),
            ("fractional version", "release_radar_transition_ticket", base.merging(["version": 1.5]) { _, new in new }),
            ("out-of-Int version", "release_radar_transition_ticket", base.merging(["version": NSNumber(value: UInt64.max)]) { _, new in new }),
            ("null assertedThreadID", "release_radar_transition_ticket", base.merging(["assertedThreadID": NSNull()]) { _, new in new }),
            ("Boolean evidence ticketID", "release_radar_add_evidence", base.merging(["id": "evidence-invalid", "path": fixture.projectRoot.path, "ticketID": true]) { _, new in new }),
            ("array evidence ticketID", "release_radar_add_evidence", base.merging(["id": "evidence-invalid", "path": fixture.projectRoot.path, "ticketID": []]) { _, new in new }),
            ("number review ticketID", "release_radar_request_review", base.merging(["id": "review-invalid", "kind": "agent_request", "summary": "Invalid", "ticketID": 42]) { _, new in new }),
            ("object review ticketID", "release_radar_request_review", base.merging(["id": "review-invalid", "kind": "agent_request", "summary": "Invalid", "ticketID": ["bad": "type"]]) { _, new in new }),
            ("null review ticketID", "release_radar_request_review", base.merging(["id": "review-invalid", "kind": "agent_request", "summary": "Invalid", "ticketID": NSNull()]) { _, new in new }),
            ("Boolean transition revision", "release_radar_transition_ticket", base.merging(["ticketTaskPlanRevision": true]) { _, new in new }),
            ("fractional transition revision", "release_radar_transition_ticket", base.merging(["ticketTaskPlanRevision": 1.5]) { _, new in new }),
            ("null transition revision", "release_radar_transition_ticket", base.merging(["ticketTaskPlanRevision": NSNull()]) { _, new in new }),
            ("zero transition revision", "release_radar_transition_ticket", base.merging(["ticketTaskPlanRevision": 0]) { _, new in new }),
            ("negative transition revision", "release_radar_transition_ticket", base.merging(["ticketTaskPlanRevision": -1]) { _, new in new }),
            ("out-of-Int transition revision", "release_radar_transition_ticket", base.merging(["ticketTaskPlanRevision": NSNumber(value: UInt64.max)]) { _, new in new }),
        ]

        for (name, tool, arguments) in cases {
            let response = try Self.runTool(packagedTool, tool: tool, arguments: arguments)
            XCTAssertEqual(jsonRPCErrorCode(response), -32602, name)
        }
        let counts = try await malformedInputCounts(fixture.store)
        XCTAssertEqual(counts, [0, 0, 0, 0])
    }

    func testDeliveryGoalCallbackPreservesTypedResultsAndTrustedExternalOrigin() async throws {
        let f = try await makeTransportFixture(lane: .needsReview)
        let dispatcher = AgentCommandDispatcher(store: f.store, projectRegistry: PersistedAuthorizedProjectRegistry(store: f.store))
        // Exercise the real callback with synthetic state without registering a service.
        let callback = AgentBridgeAppCallback(dispatcher: dispatcher, queries: AgentQueryDispatcher(store: f.store),
            beforeDispatch: { _ in }, afterDispatchBeforeReply: { _, _ in }, afterReply: { _, _ in })
        func send(_ envelope: AgentCommandEnvelope) async throws -> AgentCommandResult {
            let data = try JSONEncoder().encode(envelope)
            let response: Data = await withCheckedContinuation { continuation in
                callback.dispatch(ReleaseRadarBridgeTransport.wireVersion, envelope: data,
                    admissionDeadline: Date().addingTimeInterval(10).timeIntervalSince1970) { continuation.resume(returning: $0) }
            }
            return try JSONDecoder().decode(AgentCommandResult.self, from: response)
        }
        func envelope(_ command: AgentCommand) -> AgentCommandEnvelope {
            .init(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path, assertedThreadID: "release-radar-owner",
                  reason: "Task 8 callback verification", command: command)
        }
        let revision = envelope(.applyPhasePlanRevision(projectID: "project-1", phaseID: "phase-1", expectedRevision: 0,
            goalUpserts: [.init(id: .init(rawValue: "fixture-goal"), title: "Revised goal", outcome: "Complete fixture", doneCriteria: ["Delivered"], sortOrder: 0)]))
        let revised = try await send(revision)
        XCTAssertNil(revised.error); XCTAssertEqual(revised.phasePlanRevision, 1)
        let finalized = try await send(envelope(.finalizePhasePlan(projectID: "project-1", phaseID: "phase-1", expectedRevision: 1)))
        XCTAssertNil(finalized.error); XCTAssertEqual(finalized.phasePlanRevision, 1)
        for (ticket, taskRevision) in [("RR-03", nil as Int64?), ("RR-PLAN", Int64(2))] {
            let result = try await send(envelope(.transitionTicket(ticketID: ticket, lane: .accepted, ticketTaskPlanRevision: taskRevision)))
            XCTAssertNil(result.error)
        }
        let request = envelope(.transitionDeliveryGoal(projectID: "project-1", phaseID: "phase-1", goalID: "fixture-goal", expectedPlanRevision: 1, lifecycle: .awaitingAcceptance))
        let awaiting = try await send(request)
        XCTAssertNil(awaiting.error); XCTAssertEqual(awaiting.phasePlanRevision, 1)
        let replay = try await send(request); XCTAssertEqual(replay, awaiting)
        let ownerRequest = envelope(.transitionDeliveryGoal(projectID: "project-1", phaseID: "phase-1", goalID: "fixture-goal", expectedPlanRevision: 1, lifecycle: .accepted))
        let denied = try await send(ownerRequest); XCTAssertEqual(denied.error, .ownerAcceptanceRequired)
        let ownerResult = await dispatcher.dispatch(ownerRequest, origin: .ownerApp)
        XCTAssertNil(ownerResult.error)
        let countsBefore = try await requestCounts(f.store, requestID: ownerRequest.requestID, reason: ownerRequest.reason)
        let reused = try await send(ownerRequest)
        XCTAssertEqual(reused.error, .ownerAcceptanceRequired); XCTAssertNil(reused.auditEventID); XCTAssertTrue(reused.entityIDs.isEmpty)
        let countsAfter = try await requestCounts(f.store, requestID: ownerRequest.requestID, reason: ownerRequest.reason)
        XCTAssertEqual(countsAfter, countsBefore)
        let ownerReplay = await dispatcher.dispatch(ownerRequest, origin: .ownerApp); XCTAssertEqual(ownerReplay, ownerResult)
    }

    func testDeliveryGoalToolMalformedInputsAndBoundsRejectBeforeTransport() throws {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        // The invalid reason is the last guard even if a field validator regresses:
        // none of these stdio-only checks can contact the shared broker.
        let base: [String: Any] = ["version": 1, "requestID": UUID().uuidString, "projectRoot": "/task8-validation-only",
            "reason": NSNull(), "projectID": "project-1", "phaseID": "phase-1", "expectedRevision": 0]
        let draft: [String: Any] = ["id": "g", "title": "Goal", "outcome": "Outcome", "doneCriteria": ["Done"], "sortOrder": 0]
        func check(_ fields: [String: Any], expected: String, tool: String = "apply_phase_plan_revision") throws {
            var arguments = base.merging(fields) { _, new in new }
            if tool == "transition_delivery_goal" { arguments.removeValue(forKey: "expectedRevision") }
            let result = try Self.runToolSession(helper, tool: "release_radar_" + tool, arguments: arguments).call
            XCTAssertEqual(jsonRPCErrorCode(result), -32602)
            let message = (result["error"] as? [String: Any])?["message"] as? String ?? ""
            XCTAssertTrue(message.contains(expected), message)
        }
        for key in ["goalUpserts", "assignments", "unassignedTicketIDs", "supersededGoalIDs"] {
            for value: Any in [NSNull(), "bad", [true]] { try check([key: value], expected: key) }
        }
        for value: Any in [true, 1.5, -1, NSNumber(value: UInt64.max), NSNull(), "1"] {
            try check(["expectedRevision": value], expected: "expectedRevision")
            try check(["expectedRevision": value], expected: "expectedRevision", tool: "finalize_phase_plan")
            try check(["goalID": "g", "expectedPlanRevision": value, "lifecycle": "awaiting_acceptance"], expected: "expectedPlanRevision", tool: "transition_delivery_goal")
        }
        try check(["origin": "ownerApp"], expected: "Unsupported")
        try check(["goalUpserts": [draft.merging(["lifecycle": "accepted"]) { _, new in new }]], expected: "exact")
        try check(["assignments": [["goalID": "g", "ticketID": "t", "extra": true]]], expected: "exact")
        for lifecycle in ["accepted", "active", "planned", "draft", "superseded"] {
            try check(["goalID": "g", "expectedPlanRevision": 1, "lifecycle": lifecycle], expected: "awaiting_acceptance", tool: "transition_delivery_goal")
        }
        try check(["goalID": "g", "expectedPlanRevision": 1, "lifecycle": "awaiting_acceptance", "origin": "ownerApp"], expected: "Unsupported", tool: "transition_delivery_goal")
        for count in [63, 64, 65] {
            try check(["goalUpserts": [draft], "supersededGoalIDs": (1..<count).map { "g\($0)" }], expected: count <= 64 ? "reason" : "64")
        }
        for count in [511, 512, 513] {
            try check(["assignments": [["goalID": "g", "ticketID": "t"]], "unassignedTicketIDs": (1..<count).map { "t\($0)" }], expected: count <= 512 ? "reason" : "512")
        }
        try check([:], expected: "reason")
        try check(["goalUpserts": [], "assignments": [], "supersededGoalIDs": [], "unassignedTicketIDs": [], "expectedRevision": Int64.max], expected: "reason")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        for bytes in [65_535, 65_536, 65_537] {
            let empty = AgentCommand.applyPhasePlanRevision(projectID: "project-1", phaseID: "phase-1", expectedRevision: 0,
                goalUpserts: [.init(id: .init(rawValue: "g"), title: "", outcome: "Outcome", doneCriteria: ["Done"], sortOrder: 0)])
            let padding = bytes - (try encoder.encode(empty).count)
            let title = String(repeating: "é", count: padding / 2) + String(repeating: "a", count: padding % 2)
            let record = draft.merging(["title": title]) { _, new in new }
            try check(["goalUpserts": [record]], expected: bytes <= 65_536 ? "reason" : "65,536")
        }
    }

    func testDeliveryGoalToolsExposeOnlyExternalLifecycleAndBoundedSchemas() throws {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let session = try Self.runToolSession(helper, tool: "release_radar_finalize_phase_plan", arguments: ["version": true])
        let result = try XCTUnwrap(session.list["result"] as? [String: Any])
        let tools = try XCTUnwrap(result["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 24)
        for name in ["apply_phase_plan_revision", "finalize_phase_plan", "transition_delivery_goal"] {
            let tool = tools.first { $0["name"] as? String == "release_radar_" + name }
            XCTAssertNotNil(tool, name)
            guard let schema = tool?["inputSchema"] as? [String: Any], let fields = schema["properties"] as? [String: Any] else { continue }
            XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
            XCTAssertNil(fields["origin"])
            let required = Set(schema["required"] as? [String] ?? [])
            XCTAssertTrue(required.isSuperset(of: ["version", "requestID", "projectRoot", "reason", "projectID", "phaseID"]))
            if name == "transition_delivery_goal" {
                XCTAssertEqual((fields["lifecycle"] as? [String: Any])?["enum"] as? [String], ["awaiting_acceptance"])
                XCTAssertTrue(required.isSuperset(of: ["goalID", "expectedPlanRevision", "lifecycle"]))
            } else {
                XCTAssertTrue(required.contains("expectedRevision"))
            }
            if name == "apply_phase_plan_revision" {
                for (key, maximum) in [("goalUpserts", 64), ("supersededGoalIDs", 64), ("assignments", 512), ("unassignedTicketIDs", 512)] {
                    XCTAssertEqual((fields[key] as? [String: Any])?["maxItems"] as? Int, maximum)
                    XCTAssertFalse(required.contains(key))
                }
            }
        }
        XCTAssertEqual(jsonRPCErrorCode(session.call), -32602)
    }

    func testTicketTaskToolSchemasPreserveExistingToolsAndRequireBoundedRecords() throws {
        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let response = try Self.runToolSession(packagedTool, tool: "release_radar_revise_ticket_task_plan", arguments: [
            "version": true,
        ])
        XCTAssertTrue(Self.hasTypedToolSchema(response.list), "The packaged helper must preserve 19 tools and add the two strict task schemas")
        XCTAssertEqual(jsonRPCErrorCode(response.call), -32602)
    }

    func testMalformedTicketTaskInputsRejectBeforeTransport() throws {
        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let revisionTool = "release_radar_revise_ticket_task_plan"
        let completionTool = "release_radar_complete_ticket_task"
        // An invalid reason is a final local guard: even a missing task-input validator
        // cannot forward any of these requests to the shared broker.
        let base: [String: Any] = [
            "version": 1,
            "requestID": "99999999-9999-4999-8999-999999999996",
            "projectRoot": "/task-input-validation-only",
            "reason": NSNull(),
            "ticketID": "RR-03",
        ]
        let draft: [String: Any] = ["id": "task-a", "label": "Task A", "title": "Verify the command", "sortOrder": 0]
        var cases: [(String, String, [String: Any], String)] = []
        func add(_ name: String, _ tool: String = "release_radar_revise_ticket_task_plan", _ fields: [String: Any], _ expected: String) {
            cases.append((name, tool, base.merging(fields) { _, value in value }, expected))
        }
        for field in ["lane", "completion", "lifecycle", "unexpected"] {
            add("unknown top-level \(field)", revisionTool, [field: "active"], "Unsupported")
            add("unknown completion \(field)", completionTool, ["taskID": "task-a", "expectedRevision": 1, field: "active"], "Unsupported")
        }
        for field in ["completion", "lifecycle", "unexpected"] {
            add("unknown draft \(field)", revisionTool, ["additions": [draft.merging([field: "pending"]) { _, value in value }]], "Unsupported")
        }
        add("immutable revised label", revisionTool, ["definitionRevisions": [["id": "task-a", "label": "new"]]], "Unsupported")
        for field in ["additions", "definitionRevisions", "supersededTaskIDs"] {
            for value: Any in [NSNull(), "invalid", [true], [["unexpected": true]]] {
                add("malformed \(field)", revisionTool, [field: value], field == "supersededTaskIDs" ? "supersededTaskIDs" : "\(field)")
            }
        }
        for value: Any in [true, 1.5, 0, -1, NSNumber(value: UInt64.max), NSNull(), "1"] {
            add("invalid plan revision", revisionTool, ["expectedRevision": value], "expectedRevision")
            add("invalid completion revision", completionTool, ["taskID": "task-a", "expectedRevision": value], "expectedRevision")
        }
        add("missing completion revision", completionTool, ["taskID": "task-a"], "expectedRevision")
        for value: Any in [true, 1.5, -1, NSNumber(value: UInt64.max), NSNull(), "1"] {
            add("invalid draft order", revisionTool, ["additions": [draft.merging(["sortOrder": value]) { _, value in value }]], "sortOrder")
            add("invalid revised order", revisionTool, ["definitionRevisions": [["id": "task-a", "sortOrder": value]]], "sortOrder")
        }
        for field in ["id", "label", "title", "sortOrder"] {
            var missing = draft
            missing.removeValue(forKey: field)
            add("missing draft \(field)", revisionTool, ["additions": [missing]], field)
        }
        for field in ["ticketID", "taskID"] {
            add("non-string \(field)", completionTool, ["taskID": "task-a", "expectedRevision": 1].merging([field: true]) { _, value in value }, field)
        }
        for field in ["id", "label", "title"] {
            for value: Any in [true, NSNull(), "", "   "] {
                add("invalid draft \(field)", revisionTool, ["additions": [draft.merging([field: value]) { _, value in value }]], field)
            }
        }
        add("nested typed ID is not flat MCP input", revisionTool, ["additions": [draft.merging(["id": ["rawValue": "task-a"]]) { _, value in value }]], "id")
        add("null revised title", revisionTool, ["definitionRevisions": [["id": "task-a", "title": NSNull()]]], "title")
        for (name, tool, arguments, expected) in cases {
            let response = try Self.runToolSession(packagedTool, tool: tool, arguments: arguments).call
            XCTAssertEqual(jsonRPCErrorCode(response), -32602, name)
            let message = (response["error"] as? [String: Any])?["message"] as? String ?? ""
            XCTAssertTrue(message.contains(expected), "\(name): \(message)")
        }
    }

    func testTicketTaskInputBoundariesRejectBeforeTransport() throws {
        let packagedTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let base: [String: Any] = [
            "version": 1,
            "requestID": "99999999-9999-4999-8999-999999999996",
            "projectRoot": "/task-input-validation-only",
            "reason": NSNull(),
            "ticketID": "RR-03",
        ]
        let draft: [String: Any] = ["id": "task-a", "label": "Task A", "title": "Verify the command", "sortOrder": 0]
        func check(_ fields: [String: Any], expected: String, tool: String = "release_radar_revise_ticket_task_plan") throws {
            let response = try Self.runToolSession(packagedTool, tool: tool, arguments: base.merging(fields) { _, value in value }).call
            XCTAssertEqual(jsonRPCErrorCode(response), -32602)
            let message = (response["error"] as? [String: Any])?["message"] as? String ?? ""
            XCTAssertTrue(message.contains(expected), message)
        }
        for field in ["id", "label", "title"] {
            let maximum = field == "title" ? 4_096 : 256
            for count in [maximum - 1, maximum, maximum + 1] {
                for multibyte in [false, true] {
                    let value = multibyte
                        ? String(repeating: "é", count: count / 2) + String(repeating: "a", count: count % 2)
                        : String(repeating: "a", count: count)
                    XCTAssertEqual(value.utf8.count, count)
                    try check(["additions": [draft.merging([field: value]) { _, value in value }]], expected: count > maximum ? field : "reason")
                    if field == "id" {
                        try check(["supersededTaskIDs": [value]], expected: count > maximum ? "supersededTaskIDs" : "reason")
                        try check(["taskID": value, "expectedRevision": 1], expected: count > maximum ? "taskID" : "reason", tool: "release_radar_complete_ticket_task")
                    }
                    if field != "label" {
                        try check(["definitionRevisions": [["id": field == "id" ? value : "task-a", "title": field == "title" ? value : "Revise the task"]]], expected: count > maximum ? field : "reason")
                    }
                }
            }
        }
        for count in [63, 64, 65] {
            try check([
                "additions": [draft],
                "definitionRevisions": [["id": "existing", "sortOrder": 1]],
                "supersededTaskIDs": (0..<(count - 2)).map { "old-\($0)" },
            ], expected: count > 64 ? "64" : "reason")
        }
        try check([:], expected: "reason")
        try check(["additions": [], "definitionRevisions": [], "supersededTaskIDs": [], "expectedRevision": Int64.max], expected: "reason")
        try check(["additions": [draft.merging(["sortOrder": Int.max]) { _, value in value }]], expected: "reason")
        try check(["taskID": "task-a", "expectedRevision": Int64.max], expected: "reason", tool: "release_radar_complete_ticket_task")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for byteCount in [65_535, 65_536, 65_537] {
            var drafts = (0..<16).map {
                TicketTaskDraft(id: .init(rawValue: "task-\($0)"), label: "Task \($0)", title: String(repeating: "a", count: 4_096), sortOrder: $0)
            }
            let initial = try encoder.encode(AgentCommand.reviseTicketTaskPlan(ticketID: "RR-03", additions: drafts))
            let adjustedTitle = String(repeating: "a", count: 4_096 + byteCount - initial.count)
            XCTAssertLessThanOrEqual(adjustedTitle.utf8.count, 4_096)
            drafts[0] = .init(id: drafts[0].id, label: drafts[0].label, title: adjustedTitle, sortOrder: 0)
            XCTAssertEqual(try encoder.encode(AgentCommand.reviseTicketTaskPlan(ticketID: "RR-03", additions: drafts)).count, byteCount)
            let records: [[String: Any]] = drafts.map { ["id": $0.id.rawValue, "label": $0.label, "title": $0.title, "sortOrder": $0.sortOrder] }
            try check(["additions": records], expected: byteCount > 65_536 ? "65,536" : "reason")
        }
    }

    func testTicketTaskToolsUseRegisteredBrokerAndRecoverExactRequests() async throws {
        let bridgeService = SMAppService.agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName)
        func requireControlledEnvironment() throws {
            guard bridgeService.status == .enabled else {
                throw TransportTestError.invalidResponse("Controlled task transport requires the already enabled bridge; this test does not register it")
            }
            let otherApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.rekonlabs.ReleaseRadar")
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            guard otherApps.isEmpty else {
                throw TransportTestError.invalidResponse("Quiesce other Release Radar app hosts before controlled task transport")
            }
        }
        try requireControlledEnvironment()
        let fixture = try await makeTransportFixture()
        let packagedTool = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let projectRoot = fixture.projectRoot.path
        let reason = "Prove audited ticket task transport"
        let threadID = "asserted-task-4b-transport"
        let creationID = UUID(uuidString: "99999999-9999-4999-8999-999999999981")!
        let revisionID = UUID(uuidString: "99999999-9999-4999-8999-999999999982")!
        let completionID = UUID(uuidString: "99999999-9999-4999-8999-999999999983")!
        let lostReplyID = UUID(uuidString: "99999999-9999-4999-8999-999999999984")!
        let unavailableID = UUID(uuidString: "99999999-9999-4999-8999-999999999985")!
        let lostReply = CallbackInvalidationGate()
        let afterReply = CallbackInvalidationGate()
        let committedResult = ResultCapture()
        let appDelegate = AppDelegate()
        try requireControlledEnvironment()
        let host = try await appDelegate.startAgentBridge(
            databaseURL: fixture.databaseURL,
            afterDispatchBeforeReply: { envelope, result in
                guard envelope.requestID == lostReplyID else { return }
                committedResult.set(result)
                lostReply.entered.signal()
                await lostReply.release.wait()
            },
            afterReply: { envelope, _ in
                guard envelope.requestID == completionID else { return }
                afterReply.entered.signal()
                await afterReply.release.wait()
            }
        )
        defer {
            lostReply.release.signal()
            afterReply.release.signal()
            host.disconnectCallback()
            XCTAssertEqual(bridgeService.status, .enabled, "Controlled task transport must preserve bridge registration")
        }
        func arguments(_ requestID: UUID, _ fields: [String: Any]) -> [String: Any] {
            [
                "version": 1, "requestID": requestID.uuidString, "projectRoot": projectRoot,
                "reason": reason, "assertedThreadID": threadID, "ticketID": "RR-03",
            ].merging(fields) { _, value in value }
        }
        func assertReceipt(_ result: AgentCommandResult, requestID: UUID, command: AgentCommand, revision: Int64) async throws {
            XCTAssertNil(result.error)
            XCTAssertEqual(result.ticketTaskPlanRevision, revision)
            let expected = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: projectRoot, assertedThreadID: threadID, reason: reason, command: command)
            let stored = try await fixture.store.read { connection in
                try connection.row("SELECT request_body, result_data FROM agent_command_requests WHERE request_id = ?", bindings: [.text(requestID.uuidString)])
            }
            guard case let .blob(requestData)? = stored?["request_body"], case let .blob(resultData)? = stored?["result_data"] else {
                XCTFail("A successful task tool must persist its complete receipt")
                return
            }
            var requestBody = try XCTUnwrap(JSONSerialization.jsonObject(with: requestData) as? [String: Any])
            XCTAssertNil(requestBody["requestID"], "Ordinary canonical receipts store the request identity in their key")
            requestBody["requestID"] = requestID.uuidString
            XCTAssertEqual(try JSONDecoder().decode(AgentCommandEnvelope.self, from: JSONSerialization.data(withJSONObject: requestBody)), expected)
            XCTAssertEqual(try JSONDecoder().decode(AgentCommandResult.self, from: resultData), result)
            let auditID = try XCTUnwrap(result.auditEventID)
            let count = try await fixture.store.read { connection in
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE id = ? AND entity_type = 'ticket_task_plan' AND entity_id = 'RR-03' AND project_id = 'project-1' AND actor_id = 'release-radar-agent' AND thread_id = ? AND thread_attribution = 'asserted'", bindings: [.text(auditID.rawValue), .text(threadID)])
            }
            XCTAssertEqual(count, 1)
        }
        let initialTasks: [TicketTaskDraft] = [
            .init(id: .init(rawValue: "task-a"), label: "Task A", title: "Create the plan", sortOrder: 0),
            .init(id: .init(rawValue: "task-b"), label: "Task B", title: "Supersede this task", sortOrder: 1),
            .init(id: .init(rawValue: "task-c"), label: "Task C", title: "Recover the exact request", sortOrder: 2),
        ]
        let creation = arguments(creationID, ["additions": initialTasks.map { ["id": $0.id.rawValue, "label": $0.label, "title": $0.title, "sortOrder": $0.sortOrder] as [String: Any] }])
        let first = try decodeCommandResult(Self.runTool(packagedTool, tool: "release_radar_revise_ticket_task_plan", arguments: creation))
        try await assertReceipt(first, requestID: creationID, command: .reviseTicketTaskPlan(ticketID: "RR-03", additions: initialTasks), revision: 1)
        XCTAssertEqual(try decodeCommandResult(Self.runTool(packagedTool, tool: "release_radar_revise_ticket_task_plan", arguments: creation)), first)

        let replacement = TicketTaskDraft(id: .init(rawValue: "task-d"), label: "Task D", title: "Keep the plan pending", sortOrder: 3)
        let definition = TicketTaskDefinitionRevision(id: .init(rawValue: "task-a"), title: "Verify the committed task revision", sortOrder: 0)
        let revision = arguments(revisionID, [
            "expectedRevision": 1,
            "additions": [["id": "task-d", "label": "Task D", "title": "Keep the plan pending", "sortOrder": 3]],
            "definitionRevisions": [["id": "task-a", "title": "Verify the committed task revision", "sortOrder": 0]],
            "supersededTaskIDs": ["task-b"],
        ])
        let revised = try decodeCommandResult(Self.runTool(packagedTool, tool: "release_radar_revise_ticket_task_plan", arguments: revision))
        try await assertReceipt(revised, requestID: revisionID, command: .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1, additions: [replacement], definitionRevisions: [definition], supersededTaskIDs: [.init(rawValue: "task-b")]), revision: 2)
        XCTAssertEqual(try decodeCommandResult(Self.runTool(packagedTool, tool: "release_radar_revise_ticket_task_plan", arguments: revision)), revised)

        let completionResponse = Task.detached { @Sendable in
            try Self.runToolData(packagedTool, tool: "release_radar_complete_ticket_task", arguments: [
                "version": 1, "requestID": completionID.uuidString, "projectRoot": projectRoot,
                "reason": reason, "assertedThreadID": threadID, "ticketID": "RR-03", "taskID": "task-a", "expectedRevision": 2,
            ])
        }
        await afterReply.entered.wait()
        let completionData = try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { try await completionResponse.value }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TransportTestError.timedOut
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
        afterReply.release.signal()
        let completed = try decodeCommandResult(Self.decodeToolResponseData(completionData))
        try await assertReceipt(completed, requestID: completionID, command: .completeTicketTask(ticketID: "RR-03", taskID: "task-a", expectedRevision: 2), revision: 3)
        XCTAssertEqual(try decodeCommandResult(Self.runTool(packagedTool, tool: "release_radar_complete_ticket_task", arguments: arguments(completionID, ["taskID": "task-a", "expectedRevision": 2]))), completed)
        afterReply.release.signal()

        let pending = DataCapture()
        let pendingFinished = AsyncSignal()
        DispatchQueue.global().async {
            pending.set(Result {
                try Self.runToolData(packagedTool, tool: "release_radar_complete_ticket_task", arguments: [
                    "version": 1, "requestID": lostReplyID.uuidString, "projectRoot": projectRoot,
                    "reason": reason, "assertedThreadID": threadID, "ticketID": "RR-03", "taskID": "task-c", "expectedRevision": 3,
                ])
            })
            pendingFinished.signal()
        }
        await lostReply.entered.wait()
        host.disconnectCallback()
        lostReply.release.signal()
        await pendingFinished.wait()
        let uncertain = try Self.decodeToolResponseData(pending.get())
        XCTAssertEqual(try decodeCommandResult(uncertain).error, .outcomeUnknown)
        XCTAssertEqual(mcpIsError(uncertain), true)
        let original = try XCTUnwrap(committedResult.get())
        try await assertReceipt(original, requestID: lostReplyID, command: .completeTicketTask(ticketID: "RR-03", taskID: "task-c", expectedRevision: 3), revision: 4)

        let reconnectDelegate = AppDelegate()
        try requireControlledEnvironment()
        let reconnect = try await reconnectDelegate.startAgentBridge(databaseURL: fixture.databaseURL)
        defer { reconnect.disconnectCallback() }
        let replay = try decodeCommandResult(Self.runTool(packagedTool, tool: "release_radar_complete_ticket_task", arguments: arguments(lostReplyID, ["taskID": "task-c", "expectedRevision": 3])))
        XCTAssertEqual(replay, original)
        reconnect.disconnectCallback()
        let unavailable = try Self.runTool(packagedTool, tool: "release_radar_complete_ticket_task", arguments: arguments(unavailableID, ["taskID": "task-d", "expectedRevision": 4]))
        XCTAssertEqual(try decodeCommandResult(unavailable).error, .appUnavailable)
        XCTAssertEqual(mcpIsError(unavailable), true)
        let finalState = try await fixture.store.read { connection in
            [
                .integer(try connection.scalarInt("SELECT revision FROM ticket_task_plans WHERE ticket_id = 'RR-03'") ?? -1),
                .integer(try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1),
                .integer(try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = ?", bindings: [.text(reason)]) ?? -1),
                .text(try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-03'") ?? "missing"),
                .text(try connection.scalarText("SELECT group_concat(state, ';') FROM (SELECT id || ':' || completion || ':' || lifecycle AS state FROM ticket_tasks WHERE ticket_id = 'RR-03' ORDER BY id)") ?? "missing"),
            ] as [SQLiteValue]
        }
        XCTAssertEqual(finalState, [.integer(4), .integer(4), .integer(4), .text("backlog"), .text("task-a:completed:active;task-b:pending:superseded;task-c:completed:active;task-d:pending:active")])
    }

    private struct TransportFixture {
        let databaseURL: URL
        let projectRoot: URL
        let store: DeliveryStore
    }

    private func makeTransportFixture(lane: TicketLane = .backlog) async throws -> TransportFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-TransportTests-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed transport fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)",
                bindings: [.text(projectRoot.path)]
            )
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-2', 'project-1', 'Launch')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-1')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Signed bridge', ?)", bindings: [.text(lane.rawValue)])
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-PLAN', 'project-1', 'phase-1', 'Guarded signed bridge', 'needs_review')")
            try connection.execute("""
                INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at, activated_at)
                VALUES ('project-1', 'phase-1', 'fixture-goal', 'Fixture goal', 'Complete fixture', 'active', 0, '2026-09-02T12:00:00Z', '2026-09-02T12:00:00Z', '2026-09-02T12:00:00Z')
                """)
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('project-1', 'phase-1', 'fixture-goal', 0, 'Delivered')")
            for ticketID in ["RR-03", "RR-PLAN"] {
                try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('project-1', 'phase-1', 'fixture-goal', ?)", bindings: [.text(ticketID)])
            }
            try connection.execute("UPDATE phase_plans SET state = 'ready', ready_revision = revision, finalized_at = '2026-09-02T12:00:00Z' WHERE project_id = 'project-1' AND phase_id = 'phase-1'")
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: .init(rawValue: "project-1"),
                ticketID: .init(rawValue: "RR-PLAN"),
                expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "transport-task"), label: "Transport", title: "Prove exact revision", sortOrder: 0)],
                definitionRevisions: [],
                supersededTaskIDs: [],
                connection: connection
            )
            _ = try TicketTaskPlanningPolicy.completeTask(
                projectID: .init(rawValue: "project-1"),
                ticketID: .init(rawValue: "RR-PLAN"),
                taskID: .init(rawValue: "transport-task"),
                expectedRevision: 1,
                connection: connection
            )
        }
        return .init(databaseURL: databaseURL, projectRoot: projectRoot, store: store)
    }

    nonisolated private static func runTool(
        _ executableURL: URL,
        tool: String,
        arguments: [String: Any],
        environment: [String: String] = [:]
    ) throws -> [String: Any] {
        let responses = try runToolSession(executableURL, tool: tool, arguments: arguments, environment: environment)
        guard hasTypedToolSchema(responses.list) else {
            throw TransportTestError.invalidResponse("The packaged helper returned an unexpected tool schema")
        }
        return responses.call
    }

    nonisolated private static func runToolSession(
        _ executableURL: URL,
        tool: String,
        arguments: [String: Any],
        environment: [String: String] = [:]
    ) throws -> (list: [String: Any], call: [String: Any]) {
        let process = Process()
        process.executableURL = executableURL
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, override in override }
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        let requests: [[String: Any]] = [
            [
                "jsonrpc": "2.0",
                "id": 0,
                "method": "initialize",
                "params": [
                    "protocolVersion": "2025-06-18",
                    "capabilities": [:],
                    "clientInfo": ["name": "ReleaseRadarTests", "version": "1"],
                ],
            ],
            [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list",
            ],
            [
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": ["name": tool, "arguments": arguments],
            ],
        ]
        let requestData = try requests.reduce(into: Data()) { data, request in
            data.append(try JSONSerialization.data(withJSONObject: request))
            data.append(0x0A)
        }

        try process.run()
        input.fileHandleForWriting.write(requestData)
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        let responseData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw TransportTestError.invalidResponse(String(decoding: errorData, as: UTF8.self))
        }
        let responses = try responseData.split(separator: 0x0A).map { line -> [String: Any] in
            guard let object = try JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else {
                throw TransportTestError.invalidResponse(String(decoding: line, as: UTF8.self))
            }
            return object
        }
        guard let listResponse = responses.first(where: { ($0["id"] as? NSNumber)?.intValue == 1 }),
              let callResponse = responses.first(where: { ($0["id"] as? NSNumber)?.intValue == 2 })
        else {
            throw TransportTestError.invalidResponse(String(decoding: responseData, as: UTF8.self))
        }
        return (listResponse, callResponse)
    }

    nonisolated private static func readLine(from handle: FileHandle) throws -> Data {
        var line = Data()
        while true {
            let byte = handle.readData(ofLength: 1)
            guard !byte.isEmpty else {
                throw TransportTestError.invalidResponse("stdout closed before a complete JSON-RPC response")
            }
            if byte[byte.startIndex] == 0x0A {
                return line
            }
            line.append(byte)
        }
    }

    nonisolated private static func runToolData(
        _ executableURL: URL,
        tool: String,
        arguments: [String: Any],
        environment: [String: String] = [:]
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: runTool(
            executableURL,
            tool: tool,
            arguments: arguments,
            environment: environment
        ))
    }

    private static func decodeToolResponseData(_ data: Data) throws -> [String: Any] {
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TransportTestError.invalidResponse(String(decoding: data, as: UTF8.self))
        }
        return response
    }

    nonisolated private static func hasTypedToolSchema(_ response: [String: Any]) -> Bool {
        guard let result = response["result"] as? [String: Any],
              let tools = result["tools"] as? [[String: Any]],
              tools.count == 24,
              hasTicketTaskToolSchemas(tools),
              let transition = tools.first(where: { $0["name"] as? String == "release_radar_transition_ticket" }),
              let transitionSchema = transition["inputSchema"] as? [String: Any],
              let transitionProperties = transitionSchema["properties"] as? [String: Any],
              let transitionRequired = transitionSchema["required"] as? [String],
              let upsert = tools.first(where: { $0["name"] as? String == "release_radar_upsert_ticket" }),
              let upsertSchema = upsert["inputSchema"] as? [String: Any],
              let upsertProperties = upsertSchema["properties"] as? [String: Any],
              let activePhase = tools.first(where: { $0["name"] as? String == "release_radar_set_active_phase" }),
              let activePhaseSchema = activePhase["inputSchema"] as? [String: Any]
        else { return false }
        let expectedActivePhaseSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "version": ["type": "integer", "const": 1],
                "requestID": ["type": "string", "format": "uuid"],
                "projectRoot": ["type": "string", "minLength": 1],
                "assertedThreadID": ["type": "string", "minLength": 1],
                "reason": ["type": "string", "minLength": 1],
                "phaseID": ["type": "string", "minLength": 1],
            ],
            "required": ["version", "requestID", "projectRoot", "reason", "phaseID"],
            "additionalProperties": false,
        ]
        let revisionSchema: [String: Any] = ["type": "integer", "minimum": 1]
        return Set(transitionProperties.keys) == ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "ticketID", "lane", "ticketTaskPlanRevision"]
            && Set(transitionRequired) == ["version", "requestID", "projectRoot", "reason", "ticketID", "lane"]
            && NSDictionary(dictionary: transitionProperties["ticketTaskPlanRevision"] as? [String: Any] ?? [:]).isEqual(to: revisionSchema)
            && transitionSchema["additionalProperties"] as? Bool == false
            && upsertProperties["ticketTaskPlanRevision"] == nil
            && upsertSchema["additionalProperties"] as? Bool == false
            && NSDictionary(dictionary: activePhaseSchema).isEqual(to: expectedActivePhaseSchema)
    }

    nonisolated private static func hasTicketTaskToolSchemas(_ tools: [[String: Any]]) -> Bool {
        guard let revise = tools.first(where: { $0["name"] as? String == "release_radar_revise_ticket_task_plan" })?["inputSchema"] as? [String: Any],
              let complete = tools.first(where: { $0["name"] as? String == "release_radar_complete_ticket_task" })?["inputSchema"] as? [String: Any],
              let reviseProperties = revise["properties"] as? [String: Any],
              let completeProperties = complete["properties"] as? [String: Any],
              let additions = reviseProperties["additions"] as? [String: Any],
              let draft = additions["items"] as? [String: Any],
              let draftProperties = draft["properties"] as? [String: Any],
              let revisions = reviseProperties["definitionRevisions"] as? [String: Any],
              let revision = revisions["items"] as? [String: Any],
              let revisionProperties = revision["properties"] as? [String: Any],
              let superseded = reviseProperties["supersededTaskIDs"] as? [String: Any]
        else { return false }
        let common: Set<String> = ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "ticketID"]
        let required: Set<String> = ["version", "requestID", "projectRoot", "reason", "ticketID"]
        let positiveRevision: [String: Any] = ["type": "integer", "minimum": 1, "maximum": Int64.max]
        return Set(reviseProperties.keys) == common.union(["expectedRevision", "additions", "definitionRevisions", "supersededTaskIDs"])
            && Set(completeProperties.keys) == common.union(["taskID", "expectedRevision"])
            && Set(revise["required"] as? [String] ?? []) == required
            && Set(complete["required"] as? [String] ?? []) == required.union(["taskID", "expectedRevision"])
            && revise["additionalProperties"] as? Bool == false
            && complete["additionalProperties"] as? Bool == false
            && NSDictionary(dictionary: reviseProperties["expectedRevision"] as? [String: Any] ?? [:]).isEqual(to: positiveRevision)
            && NSDictionary(dictionary: completeProperties["expectedRevision"] as? [String: Any] ?? [:]).isEqual(to: positiveRevision)
            && Set(draftProperties.keys) == ["id", "label", "title", "sortOrder"]
            && Set(draft["required"] as? [String] ?? []) == ["id", "label", "title", "sortOrder"]
            && draft["additionalProperties"] as? Bool == false
            && Set(revisionProperties.keys) == ["id", "title", "sortOrder"]
            && Set(revision["required"] as? [String] ?? []) == ["id"]
            && revision["additionalProperties"] as? Bool == false
            && [additions, revisions, superseded].allSatisfy { $0["type"] as? String == "array" && ($0["maxItems"] as? NSNumber)?.intValue == 64 }
            && (superseded["items"] as? [String: Any])?["type"] as? String == "string"
            && (draftProperties["id"] as? [String: Any])?["maxLength"] as? Int == 256
            && (draftProperties["label"] as? [String: Any])?["maxLength"] as? Int == 256
            && (draftProperties["title"] as? [String: Any])?["maxLength"] as? Int == 4_096
            && (draftProperties["sortOrder"] as? [String: Any])?["minimum"] as? Int == 0
            && (draftProperties["sortOrder"] as? [String: Any])?["maximum"] as? Int == Int.max
    }

    private func decodeCommandResult(_ response: [String: Any]) throws -> AgentCommandResult {
        guard let result = response["result"] as? [String: Any],
              let content = result["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String,
              let data = text.data(using: .utf8)
        else {
            throw TransportTestError.invalidResponse(String(describing: response))
        }
        return try JSONDecoder().decode(AgentCommandResult.self, from: data)
    }

    private func jsonRPCErrorCode(_ response: [String: Any]) -> Int? {
        ((response["error"] as? [String: Any])?["code"] as? NSNumber)?.intValue
    }

    private func mcpIsError(_ response: [String: Any]) -> Bool? {
        (response["result"] as? [String: Any])?["isError"] as? Bool
    }

    private func transportCounts(_ store: DeliveryStore) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Prove the packaged signed transport'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '77777777-7777-4777-8777-777777777777'") ?? -1,
            ]
        }
    }

    private func expiredRequestCounts(_ store: DeliveryStore) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'RR-03' AND lane = 'blocked'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Do not persist after the transport deadline'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '99999999-9999-4999-8999-999999999999'") ?? -1,
            ]
        }
    }

    private func requestCounts(
        _ store: DeliveryStore,
        requestID: UUID,
        reason: String
    ) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE reason = ?",
                    bindings: [.text(reason)]
                ) ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?", bindings: [.text(requestID.uuidString)]) ?? -1,
            ]
        }
    }

    private func malformedInputCounts(_ store: DeliveryStore) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Reject malformed tool input'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '99999999-9999-4999-8999-999999999994'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM evidence WHERE id = 'evidence-invalid'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'review-invalid'") ?? -1,
            ]
        }
    }
}

private enum TransportTestError: Error {
    case invalidResponse(String)
    case timedOut
}

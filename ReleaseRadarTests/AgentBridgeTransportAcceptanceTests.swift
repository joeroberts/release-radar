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
        let fixture = try await makeTransportFixture()
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
        let fixture = try await makeTransportFixture()
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

        await afterReplyGate.entered.wait()
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
        XCTAssertNil(try decodeCommandResult(toolResponse).error)
        XCTAssertEqual(mcpIsError(toolResponse), false)
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
        ]

        for (name, tool, arguments) in cases {
            let response = try Self.runTool(packagedTool, tool: tool, arguments: arguments)
            XCTAssertEqual(jsonRPCErrorCode(response), -32602, name)
        }
        let counts = try await malformedInputCounts(fixture.store)
        XCTAssertEqual(counts, [0, 0, 0, 0])
    }

    private struct TransportFixture {
        let databaseURL: URL
        let projectRoot: URL
        let store: DeliveryStore
    }

    private func makeTransportFixture() async throws -> TransportFixture {
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
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Signed bridge', 'backlog')")
        }
        return .init(databaseURL: databaseURL, projectRoot: projectRoot, store: store)
    }

    nonisolated private static func runTool(
        _ executableURL: URL,
        tool: String,
        arguments: [String: Any],
        environment: [String: String] = [:]
    ) throws -> [String: Any] {
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
              Self.hasTypedToolSchema(listResponse),
              let callResponse = responses.first(where: { ($0["id"] as? NSNumber)?.intValue == 2 })
        else {
            throw TransportTestError.invalidResponse(String(decoding: responseData, as: UTF8.self))
        }
        return callResponse
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
              tools.count == 13,
              let transition = tools.first(where: { $0["name"] as? String == "release_radar_transition_ticket" }),
              let transitionSchema = transition["inputSchema"] as? [String: Any],
              let transitionProperties = transitionSchema["properties"] as? [String: Any],
              let transitionRequired = transitionSchema["required"] as? [String],
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
        return Set(transitionProperties.keys) == ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "ticketID", "lane"]
            && Set(transitionRequired) == ["version", "requestID", "projectRoot", "reason", "ticketID", "lane"]
            && transitionSchema["additionalProperties"] as? Bool == false
            && NSDictionary(dictionary: activePhaseSchema).isEqual(to: expectedActivePhaseSchema)
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

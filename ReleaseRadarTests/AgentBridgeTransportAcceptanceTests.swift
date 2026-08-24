import Foundation
import ServiceManagement
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class AgentBridgeTransportAcceptanceTests: XCTestCase {
    func testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp() async throws {
        let fixture = try await makeTransportFixture()
        let appDelegate = AppDelegate()
        let host = try await appDelegate.startAgentBridge(databaseURL: fixture.databaseURL)
        defer {
            host.disconnectCallback()
            try? host.unregister()
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

        let first = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
        let firstResult = try decodeCommandResult(first)
        XCTAssertNil(firstResult.error)
        XCTAssertNotNil(firstResult.auditEventID)

        let replay = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
        XCTAssertEqual(try decodeCommandResult(replay), firstResult)
        var counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

        let rejectedPeer = try runTool(wrongTool, tool: "release_radar_transition_ticket", arguments: arguments)
        XCTAssertEqual(jsonRPCErrorCode(rejectedPeer), -32001)
        counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

        let wrongBridge = try runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: arguments,
            environment: ["RELEASE_RADAR_BRIDGE_VERSION": "999"]
        )
        XCTAssertEqual(jsonRPCErrorCode(wrongBridge), -32001)
        counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

        var wrongEnvelopeArguments = arguments
        wrongEnvelopeArguments["version"] = 999
        let wrongEnvelope = try runTool(
            packagedTool,
            tool: "release_radar_transition_ticket",
            arguments: wrongEnvelopeArguments
        )
        let wrongEnvelopeResult = try decodeCommandResult(wrongEnvelope)
        XCTAssertEqual(wrongEnvelopeResult.error, .unsupportedVersion(found: 999, supported: 1))
        counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

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
        counts = try await transportCounts(fixture.store)
        XCTAssertEqual(counts, [1, 1])

        try host.unregister()
        switch SMAppService.agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName).status {
        case .notRegistered, .notFound:
            break
        default:
            XCTFail("Explicit cleanup left the bridge registered")
        }
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
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Signed bridge', 'backlog')")
        }
        return .init(databaseURL: databaseURL, projectRoot: projectRoot, store: store)
    }

    private func runTool(
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
              hasTypedToolSchema(listResponse),
              let callResponse = responses.first(where: { ($0["id"] as? NSNumber)?.intValue == 2 })
        else {
            throw TransportTestError.invalidResponse(String(decoding: responseData, as: UTF8.self))
        }
        return callResponse
    }

    private func hasTypedToolSchema(_ response: [String: Any]) -> Bool {
        guard let result = response["result"] as? [String: Any],
              let tools = result["tools"] as? [[String: Any]],
              tools.count == 12,
              let transition = tools.first(where: { $0["name"] as? String == "release_radar_transition_ticket" }),
              let schema = transition["inputSchema"] as? [String: Any],
              let properties = schema["properties"] as? [String: Any],
              let required = schema["required"] as? [String]
        else { return false }
        return Set(properties.keys) == ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "ticketID", "lane"]
            && Set(required) == ["version", "requestID", "projectRoot", "reason", "ticketID", "lane"]
            && schema["additionalProperties"] as? Bool == false
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

    private func transportCounts(_ store: DeliveryStore) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Prove the packaged signed transport'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '77777777-7777-4777-8777-777777777777'") ?? -1,
            ]
        }
    }
}

private enum TransportTestError: Error {
    case invalidResponse(String)
}

import Foundation
import Darwin

private enum ToolFailure: Error, LocalizedError {
    case invalidRequest(String)
    case appUnavailable

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(message): message
        case .appUnavailable: "Release Radar app is unavailable"
        }
    }
}

private final class BridgeClient: @unchecked Sendable {
    private let connection: NSXPCConnection
    private let requestedWireVersion: Int

    init() throws {
        guard let brokerRequirement = ReleaseRadarBridgeTransport.brokerRequirement else {
            throw ToolFailure.appUnavailable
        }
#if DEBUG
        requestedWireVersion = ProcessInfo.processInfo.environment["RELEASE_RADAR_WIRE_VERSION"]
            .flatMap(Int.init) ?? ReleaseRadarBridgeTransport.wireVersion
#else
        requestedWireVersion = ReleaseRadarBridgeTransport.wireVersion
#endif
        connection = NSXPCConnection(
            machServiceName: ReleaseRadarBridgeTransport.toolsMachService,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarToolsBrokerXPC.self)
        connection.setCodeSigningRequirement(brokerRequirement)
        connection.resume()
        guard handshake() else {
            connection.invalidate()
            throw ToolFailure.appUnavailable
        }
    }

    deinit {
        connection.invalidate()
    }

    func forward(_ envelope: Data) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var response: Data?
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            lock.lock()
            if response == nil {
                response = ReleaseRadarBridgeTransport.outcomeUnknownResultData()
            }
            lock.unlock()
            semaphore.signal()
        }) as? ReleaseRadarToolsBrokerXPC else {
            throw ToolFailure.appUnavailable
        }
        proxy.forward(
            requestedWireVersion,
            envelope: envelope,
            admissionDeadline: Date().addingTimeInterval(10).timeIntervalSince1970
        ) { data in
            lock.lock()
            if response == nil {
                response = data
            }
            lock.unlock()
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 12) == .success else {
            return ReleaseRadarBridgeTransport.outcomeUnknownResultData()
        }
        lock.lock()
        defer { lock.unlock() }
        guard let response else { return ReleaseRadarBridgeTransport.outcomeUnknownResultData() }
        return response
    }

    private func handshake() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var returnedVersion = 0
        var failed = false
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            lock.lock()
            failed = true
            lock.unlock()
            semaphore.signal()
        }) as? ReleaseRadarToolsBrokerXPC else { return false }
        proxy.handshake(requestedWireVersion) { version in
            lock.lock()
            returnedVersion = version
            lock.unlock()
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 5) == .success else { return false }
        lock.lock()
        defer { lock.unlock() }
        return !failed && returnedVersion == requestedWireVersion
    }
}

private struct MCPServer {
    private var initialized = false

    mutating func handle(_ request: [String: Any]) -> [String: Any]? {
        let id = request["id"] ?? NSNull()
        guard request["jsonrpc"] as? String == "2.0",
              let method = request["method"] as? String
        else { return error(id: id, code: -32600, message: "Invalid JSON-RPC request") }

        switch method {
        case "initialize":
            initialized = true
            return success(id: id, result: [
                "protocolVersion": "2025-06-18",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "Release Radar", "version": "1"],
            ])
        case "notifications/initialized":
            return nil
        case "tools/list":
            guard initialized else { return error(id: id, code: -32002, message: "MCP session is not initialized") }
            return success(id: id, result: ["tools": Self.toolDefinitions])
        case "tools/call":
            guard initialized else { return error(id: id, code: -32002, message: "MCP session is not initialized") }
            guard let params = request["params"] as? [String: Any],
                  let name = params["name"] as? String,
                  let arguments = params["arguments"] as? [String: Any]
            else { return error(id: id, code: -32602, message: "Invalid tool arguments") }
            do {
                let envelope = try Self.makeEnvelope(tool: name, arguments: arguments)
                let response: Data
                do {
                    response = try BridgeClient().forward(envelope)
                } catch ToolFailure.appUnavailable {
                    response = ReleaseRadarBridgeTransport.appUnavailableResultData()
                }
                let isError = try Self.isDomainError(response)
                return success(id: id, result: [
                    "content": [["type": "text", "text": String(decoding: response, as: UTF8.self)]],
                    "isError": isError,
                ])
            } catch {
                return self.error(id: id, code: -32602, message: error.localizedDescription)
            }
        default:
            return error(id: id, code: -32601, message: "Method not found")
        }
    }

    private static func makeEnvelope(tool: String, arguments: [String: Any]) throws -> Data {
        let version = try integer("version", in: arguments)
        let requestID = try string("requestID", in: arguments)
        guard UUID(uuidString: requestID) != nil else {
            throw ToolFailure.invalidRequest("requestID must be a UUID")
        }
        let command = try commandCase(tool: tool, arguments: arguments)
        var envelope: [String: Any] = [
            "version": version,
            "requestID": requestID,
            "projectRoot": try string("projectRoot", in: arguments),
            "reason": try string("reason", in: arguments),
            "command": [command.0: command.1],
        ]
        if let threadID = try optionalString("assertedThreadID", in: arguments) {
            envelope["assertedThreadID"] = threadID
        }
        let data = try JSONSerialization.data(withJSONObject: envelope)
        guard data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes else {
            throw ToolFailure.invalidRequest("Command envelope exceeds the transport limit")
        }
        return data
    }

    private static func isDomainError(_ response: Data) throws -> Bool {
        guard response.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
              let result = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
              result["entityIDs"] is [Any]
        else { throw ToolFailure.appUnavailable }
        guard let error = result["error"] else { return false }
        return !(error is NSNull)
    }

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
                "phaseID": try string("phaseID", in: arguments),
                "outcome": try string("outcome", in: arguments),
                "lane": try string("lane", in: arguments),
            ])
        case "release_radar_transition_ticket":
            var value: [String: Any] = [
                "ticketID": try string("ticketID", in: arguments),
                "lane": try string("lane", in: arguments),
            ]
            if arguments["ticketTaskPlanRevision"] != nil {
                let revision = try integer("ticketTaskPlanRevision", in: arguments)
                guard revision > 0, let exactRevision = Int64(exactly: revision) else {
                    throw ToolFailure.invalidRequest("ticketTaskPlanRevision must be a positive integer")
                }
                value["ticketTaskPlanRevision"] = exactRevision
            }
            return ("transitionTicket", value)
        case "release_radar_set_active_phase":
            return ("setActivePhase", [
                "phaseID": try string("phaseID", in: arguments),
            ])
        case "release_radar_set_dependency":
            return ("setDependency", [
                "id": try string("id", in: arguments),
                "kind": try string("kind", in: arguments),
                "subjectID": try string("subjectID", in: arguments),
                "dependsOnID": try string("dependsOnID", in: arguments),
            ])
        case "release_radar_record_blocker":
            return ("recordBlocker", [
                "id": try string("id", in: arguments),
                "ticketID": try string("ticketID", in: arguments),
                "summary": try string("summary", in: arguments),
            ])
        case "release_radar_resolve_blocker":
            return ("resolveBlocker", ["blockerID": try string("blockerID", in: arguments)])
        case "release_radar_add_evidence":
            var value: [String: Any] = [
                "id": try string("id", in: arguments),
                "path": try string("path", in: arguments),
            ]
            if let ticketID = try optionalString("ticketID", in: arguments) { value["ticketID"] = ticketID }
            return ("addEvidence", value)
        case "release_radar_link_thread":
            return ("linkThread", [
                "id": try string("id", in: arguments),
                "ticketID": try string("ticketID", in: arguments),
                "threadID": try string("threadID", in: arguments),
            ])
        case "release_radar_request_review":
            var value: [String: Any] = [
                "id": try string("id", in: arguments),
                "kind": try string("kind", in: arguments),
                "summary": try string("summary", in: arguments),
            ]
            if let ticketID = try optionalString("ticketID", in: arguments) { value["ticketID"] = ticketID }
            return ("requestReview", value)
        case "release_radar_record_completion":
            return ("recordCompletion", [
                "id": try string("id", in: arguments),
                "ticketID": try string("ticketID", in: arguments),
                "summary": try string("summary", in: arguments),
            ])
        case "release_radar_resolve_import_review":
            return ("resolveImportReview", ["reviewItemID": try string("reviewItemID", in: arguments)])
        case "release_radar_dismiss_import_review":
            return ("dismissImportReview", ["reviewItemID": try string("reviewItemID", in: arguments)])
        default:
            throw ToolFailure.invalidRequest("Unknown Release Radar tool")
        }
    }

    private static func string(_ key: String, in arguments: [String: Any]) throws -> String {
        guard let value = arguments[key] as? String else {
            throw ToolFailure.invalidRequest("Missing string argument: \(key)")
        }
        return value
    }

    private static func optionalString(_ key: String, in arguments: [String: Any]) throws -> String? {
        guard let rawValue = arguments[key] else { return nil }
        guard let value = rawValue as? String else {
            throw ToolFailure.invalidRequest("Argument must be a string when present: \(key)")
        }
        return value
    }

    private static func integer(_ key: String, in arguments: [String: Any]) throws -> Int {
        guard let value = ReleaseRadarBridgeTransport.exactJSONInteger(arguments[key]) else {
            throw ToolFailure.invalidRequest("Argument must be an exactly representable integer: \(key)")
        }
        return value
    }

    private func success(id: Any, result: Any) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private func error(id: Any, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }

    private static var toolDefinitions: [[String: Any]] {
        let string: [String: Any] = ["type": "string", "minLength": 1]
        let lane: [String: Any] = [
            "type": "string",
            "enum": ["backlog", "in_progress", "needs_review", "blocked", "accepted"],
        ]
        return [
            definition("release_radar_upsert_phase", required: ["phaseID", "name"], fields: ["phaseID": string, "name": string]),
            definition(
                "release_radar_upsert_ticket",
                required: ["ticketID", "phaseID", "outcome", "lane"],
                fields: ["ticketID": string, "phaseID": string, "outcome": string, "lane": lane]
            ),
            definition(
                "release_radar_transition_ticket",
                required: ["ticketID", "lane"],
                fields: [
                    "ticketID": string,
                    "lane": lane,
                    "ticketTaskPlanRevision": ["type": "integer", "minimum": 1],
                ]
            ),
            definition(
                "release_radar_set_active_phase",
                required: ["phaseID"],
                fields: ["phaseID": string]
            ),
            definition(
                "release_radar_set_dependency",
                required: ["id", "kind", "subjectID", "dependsOnID"],
                fields: [
                    "id": string,
                    "kind": ["type": "string", "enum": ["phase", "ticket"]],
                    "subjectID": string,
                    "dependsOnID": string,
                ]
            ),
            definition(
                "release_radar_record_blocker",
                required: ["id", "ticketID", "summary"],
                fields: ["id": string, "ticketID": string, "summary": string]
            ),
            definition("release_radar_resolve_blocker", required: ["blockerID"], fields: ["blockerID": string]),
            definition(
                "release_radar_add_evidence",
                required: ["id", "path"],
                fields: ["id": string, "ticketID": string, "path": string]
            ),
            definition(
                "release_radar_link_thread",
                required: ["id", "ticketID", "threadID"],
                fields: ["id": string, "ticketID": string, "threadID": string]
            ),
            definition(
                "release_radar_request_review",
                required: ["id", "kind", "summary"],
                fields: ["id": string, "ticketID": string, "kind": string, "summary": string]
            ),
            definition(
                "release_radar_record_completion",
                required: ["id", "ticketID", "summary"],
                fields: ["id": string, "ticketID": string, "summary": string]
            ),
            definition(
                "release_radar_resolve_import_review",
                required: ["reviewItemID"],
                fields: ["reviewItemID": string]
            ),
            definition(
                "release_radar_dismiss_import_review",
                required: ["reviewItemID"],
                fields: ["reviewItemID": string]
            ),
        ]
    }

    private static func definition(
        _ name: String,
        required: [String],
        fields: [String: [String: Any]]
    ) -> [String: Any] {
        var properties: [String: Any] = [
            "version": ["type": "integer", "const": ReleaseRadarBridgeTransport.commandEnvelopeVersion],
            "requestID": ["type": "string", "format": "uuid"],
            "projectRoot": ["type": "string", "minLength": 1],
            "assertedThreadID": ["type": "string", "minLength": 1],
            "reason": ["type": "string", "minLength": 1],
        ]
        properties.merge(fields) { _, commandField in commandField }
        return [
            "name": name,
            "description": "Apply one approved, audited Release Radar delivery mutation.",
            "inputSchema": [
                "type": "object",
                "properties": properties,
                "required": ["version", "requestID", "projectRoot", "reason"] + required,
                "additionalProperties": false,
            ],
        ]
    }
}

private func writeResponse(_ response: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
}

private var server = MCPServer()
private var buffer = Data()
private var inputBytes = [UInt8](repeating: 0, count: 4_096)
while true {
    let bytesRead = inputBytes.withUnsafeMutableBytes { bytes in
        Darwin.read(STDIN_FILENO, bytes.baseAddress, bytes.count)
    }
    if bytesRead == 0 {
        break
    }
    if bytesRead < 0 {
        if errno == EINTR {
            continue
        }
        let message = "Failed to read stdin: \(String(cString: strerror(errno)))\n"
        FileHandle.standardError.write(Data(message.utf8))
        exit(74)
    }

    buffer.append(contentsOf: inputBytes.prefix(Int(bytesRead)))
    if buffer.count > ReleaseRadarBridgeTransport.maximumLineBytes,
       !buffer.contains(0x0A) {
        writeResponse(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32600, "message": "JSON-RPC line exceeds limit"]])
        exit(64)
    }
    while let newline = buffer.firstIndex(of: 0x0A) {
        let line = Data(buffer[..<newline])
        buffer.removeSubrange(...newline)
        guard !line.isEmpty else { continue }
        guard line.count <= ReleaseRadarBridgeTransport.maximumLineBytes,
              let request = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
        else {
            writeResponse(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Invalid bounded JSON"]])
            continue
        }
        if let response = server.handle(request) {
            writeResponse(response)
        }
    }
}

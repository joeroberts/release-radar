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
        if tool == "release_radar_inventory_evidence" {
            var query: [String: Any] = [:]
            for key in ["projectID", "rootID"] { if let value = try optionalString(key, in: arguments) { query[key] = value } }
            let data = try JSONSerialization.data(withJSONObject: ["version": version, "projectRoot": try string("projectRoot", in: arguments), "query": ["inventoryEvidence": query]])
            guard data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes else { throw ToolFailure.invalidRequest("Inventory query exceeds the transport limit") }
            return data
        }
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
        case "release_radar_apply_phase_plan_revision":
            try requireTaskFields(arguments, allowed: ["projectID", "phaseID", "expectedRevision", "goalUpserts", "assignments", "unassignedTicketIDs", "supersededGoalIDs"])
            var value: [String: Any] = [
                "projectID": try taskString("projectID", in: arguments, maximumBytes: 256),
                "phaseID": try taskString("phaseID", in: arguments, maximumBytes: 256),
                "expectedRevision": try phaseRevision("expectedRevision", in: arguments),
            ]
            var goalCount = 0, assignmentCount = 0
            if let raw = arguments["goalUpserts"] {
                guard let records = raw as? [[String: Any]] else { throw ToolFailure.invalidRequest("goalUpserts must be an array of goal records") }
                goalCount += records.count
                value["goalUpserts"] = try records.map { record -> [String: Any] in
                    guard Set(record.keys) == ["id", "title", "outcome", "doneCriteria", "sortOrder"] else {
                        throw ToolFailure.invalidRequest("goalUpserts require exact id, title, outcome, doneCriteria and sortOrder fields")
                    }
                    guard let criteria = record["doneCriteria"] as? [String] else { throw ToolFailure.invalidRequest("doneCriteria must be an array of strings") }
                    let order = try integer("sortOrder", in: record)
                    guard order >= 0 else { throw ToolFailure.invalidRequest("sortOrder must be nonnegative") }
                    return ["id": try taskString("id", in: record, maximumBytes: 256),
                            "title": try string("title", in: record), "outcome": try string("outcome", in: record),
                            "doneCriteria": criteria, "sortOrder": order]
                }
            }
            if let raw = arguments["assignments"] {
                guard let records = raw as? [[String: Any]] else { throw ToolFailure.invalidRequest("assignments must be an array of assignment records") }
                assignmentCount += records.count
                value["assignments"] = try records.map { record -> [String: Any] in
                    guard Set(record.keys) == ["goalID", "ticketID"] else { throw ToolFailure.invalidRequest("assignments require exact goalID and ticketID fields") }
                    return ["goalID": try taskString("goalID", in: record, maximumBytes: 256), "ticketID": try taskString("ticketID", in: record, maximumBytes: 256)]
                }
            }
            for key in ["unassignedTicketIDs", "supersededGoalIDs"] {
                guard let raw = arguments[key] else { continue }
                guard let ids = raw as? [String] else { throw ToolFailure.invalidRequest("\(key) must be an array of IDs") }
                for id in ids { _ = try taskString(key, in: [key: id], maximumBytes: 256) }
                value[key] = ids
                if key == "supersededGoalIDs" { goalCount += ids.count } else { assignmentCount += ids.count }
            }
            guard goalCount <= 64, assignmentCount <= 512 else { throw ToolFailure.invalidRequest("A phase revision permits at most 64 aggregate goal and 512 aggregate assignment operations") }
            return try boundedTaskCommand("applyPhasePlanRevision", value: value)
        case "release_radar_finalize_phase_plan":
            try requireTaskFields(arguments, allowed: ["projectID", "phaseID", "expectedRevision"])
            return try boundedTaskCommand("finalizePhasePlan", value: [
                "projectID": try taskString("projectID", in: arguments, maximumBytes: 256),
                "phaseID": try taskString("phaseID", in: arguments, maximumBytes: 256),
                "expectedRevision": try phaseRevision("expectedRevision", in: arguments),
            ])
        case "release_radar_transition_delivery_goal":
            try requireTaskFields(arguments, allowed: ["projectID", "phaseID", "goalID", "expectedPlanRevision", "lifecycle"])
            guard try string("lifecycle", in: arguments) == "awaiting_acceptance" else {
                throw ToolFailure.invalidRequest("External lifecycle requests may only request awaiting_acceptance")
            }
            return try boundedTaskCommand("transitionDeliveryGoal", value: [
                "projectID": try taskString("projectID", in: arguments, maximumBytes: 256),
                "phaseID": try taskString("phaseID", in: arguments, maximumBytes: 256),
                "goalID": try taskString("goalID", in: arguments, maximumBytes: 256),
                "expectedPlanRevision": try phaseRevision("expectedPlanRevision", in: arguments),
                "lifecycle": "awaiting_acceptance",
            ])
        case "release_radar_revise_ticket_task_plan":
            try requireTaskFields(arguments, allowed: ["ticketID", "expectedRevision", "additions", "definitionRevisions", "supersededTaskIDs"])
            var value: [String: Any] = ["ticketID": try taskString("ticketID", in: arguments, maximumBytes: 256)]
            if arguments["expectedRevision"] != nil {
                value["expectedRevision"] = try positiveRevision("expectedRevision", in: arguments)
            }
            var operationCount = 0
            for key in ["additions", "definitionRevisions"] {
                guard let raw = arguments[key] else { continue }
                guard let records = raw as? [[String: Any]] else {
                    throw ToolFailure.invalidRequest("\(key) must be an array of task records")
                }
                operationCount += records.count
                let allowed: Set<String> = key == "additions" ? ["id", "label", "title", "sortOrder"] : ["id", "title", "sortOrder"]
                value[key] = try records.map { record -> [String: Any] in
                    guard Set(record.keys).isSubset(of: allowed) else {
                        throw ToolFailure.invalidRequest("Unsupported fields in \(key) record")
                    }
                    var task: [String: Any] = ["id": try taskString("id", in: record, maximumBytes: 256)]
                    if key == "additions" {
                        task["label"] = try taskString("label", in: record, maximumBytes: 256)
                    }
                    if key == "additions" || record["title"] != nil {
                        task["title"] = try taskString("title", in: record, maximumBytes: 4_096)
                    }
                    if key == "additions" || record["sortOrder"] != nil {
                        let order = try integer("sortOrder", in: record)
                        guard order >= 0 else { throw ToolFailure.invalidRequest("sortOrder must be a nonnegative integer") }
                        task["sortOrder"] = order
                    }
                    return task
                }
            }
            if let raw = arguments["supersededTaskIDs"] {
                guard let ids = raw as? [String] else {
                    throw ToolFailure.invalidRequest("supersededTaskIDs must be an array of task ID strings")
                }
                operationCount += ids.count
                for id in ids { _ = try taskString("supersededTaskIDs", in: ["supersededTaskIDs": id], maximumBytes: 256) }
                value["supersededTaskIDs"] = ids
            }
            guard operationCount <= 64 else { throw ToolFailure.invalidRequest("A task plan revision may contain at most 64 aggregate operations") }
            return try boundedTaskCommand("reviseTicketTaskPlan", value: value)
        case "release_radar_complete_ticket_task":
            try requireTaskFields(arguments, allowed: ["ticketID", "taskID", "expectedRevision"])
            return try boundedTaskCommand("completeTicketTask", value: [
                "ticketID": try taskString("ticketID", in: arguments, maximumBytes: 256),
                "taskID": try taskString("taskID", in: arguments, maximumBytes: 256),
                "expectedRevision": try positiveRevision("expectedRevision", in: arguments),
            ])
        case "release_radar_bind_documentation_repository":
            return ("bindDocumentationRepository", ["target": try documentationTarget(arguments)])
        case "release_radar_accept_documentation_catalog":
            return ("acceptDocumentationCatalog", ["target": try documentationTarget(arguments), "priorCatalogVersion": try integer("priorCatalogVersion", in: arguments), "priorCatalogDigest": try string("priorCatalogDigest", in: arguments)])
        case "release_radar_add_managed_evidence":
            var value: [String: Any] = ["target": try documentationTarget(arguments), "id": try string("id", in: arguments), "artifactID": try string("artifactID", in: arguments)]
            if let ticket = try optionalString("ticketID", in: arguments) { value["ticketID"] = ticket }
            return ("addManagedEvidence", value)
        case "release_radar_adopt_managed_evidence":
            guard let items = arguments["adoptions"] as? [[String: Any]], (1...128).contains(items.count) else { throw ToolFailure.invalidRequest("adoptions must contain 1...128 exact records") }
            for item in items {
                guard Set(item.keys) == ["evidenceID", "expectedPath", "expectedTicketID", "artifactID"], item["expectedTicketID"] is String || item["expectedTicketID"] is NSNull else { throw ToolFailure.invalidRequest("Each adoption requires exact evidence/path/artifact and nullable expectedTicketID") }
                for key in ["evidenceID", "expectedPath", "artifactID"] { _ = try string(key, in: item) }
            }
            return ("adoptManagedEvidence", ["target": try documentationTarget(arguments), "adoptions": items])
        case "release_radar_relocate_legacy_evidence":
            var value: [String: Any] = [:]
            for key in ["projectID", "rootID", "evidenceID", "expectedPath", "newPath"] { value[key] = try string(key, in: arguments) }
            return ("relocateLegacyEvidence", value)
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

    private static func requireTaskFields(_ arguments: [String: Any], allowed: Set<String>) throws {
        let envelopeFields: Set<String> = ["version", "requestID", "projectRoot", "reason", "assertedThreadID"]
        guard Set(arguments.keys).isSubset(of: allowed.union(envelopeFields)) else {
            throw ToolFailure.invalidRequest("Unsupported task command fields")
        }
    }

    private static func taskString(_ key: String, in arguments: [String: Any], maximumBytes: Int) throws -> String {
        let value = try string(key, in: arguments)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.utf8.count <= maximumBytes else {
            throw ToolFailure.invalidRequest("\(key) must be nonblank and at most \(maximumBytes) UTF-8 bytes")
        }
        return value
    }

    private static func phaseRevision(_ key: String, in arguments: [String: Any]) throws -> Int64 {
        let value = try integer(key, in: arguments)
        guard value >= 0, let revision = Int64(exactly: value) else {
            throw ToolFailure.invalidRequest("\(key) must be a nonnegative Int64 integer")
        }
        return revision
    }

    private static func positiveRevision(_ key: String, in arguments: [String: Any]) throws -> Int64 {
        let value = try integer(key, in: arguments)
        guard value > 0, let revision = Int64(exactly: value) else {
            throw ToolFailure.invalidRequest("\(key) must be a positive Int64 integer")
        }
        return revision
    }

    private static func boundedTaskCommand(_ name: String, value: [String: Any]) throws -> (String, [String: Any]) {
        let data = try JSONSerialization.data(withJSONObject: [name: value], options: [.sortedKeys])
        guard data.count <= 65_536 else {
            throw ToolFailure.invalidRequest("The sorted-key encoded task command exceeds 65,536 bytes")
        }
        return (name, value)
    }

    private static func documentationTarget(_ arguments: [String: Any]) throws -> [String: Any] {
        guard let target = arguments["target"] as? [String: Any], Set(target.keys) == ["projectID", "rootID", "repositoryID", "catalogVersion", "catalogDigest"] else {
            throw ToolFailure.invalidRequest("target requires exact project/root/repository/version/digest")
        }
        for key in ["projectID", "rootID", "repositoryID", "catalogDigest"] { _ = try string(key, in: target) }
        _ = try integer("catalogVersion", in: target)
        return target
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
        let target: [String: Any] = ["type": "object", "additionalProperties": false,
            "required": ["projectID", "rootID", "repositoryID", "catalogVersion", "catalogDigest"],
            "properties": ["projectID": string, "rootID": string, "repositoryID": ["type": "string", "format": "uuid"], "catalogVersion": ["type": "integer", "const": 1], "catalogDigest": ["type": "string", "pattern": "^[0-9a-f]{64}$"]]]
        let adoption: [String: Any] = ["type": "array", "minItems": 1, "maxItems": 128,
            "items": ["type": "object", "additionalProperties": false, "required": ["evidenceID", "expectedPath", "expectedTicketID", "artifactID"],
                      "properties": ["evidenceID": string, "expectedPath": string, "expectedTicketID": ["type": ["string", "null"]], "artifactID": string]]]
        let taskID: [String: Any] = ["type": "string", "minLength": 1, "maxLength": 256, "description": "Nonblank, at most 256 UTF-8 bytes."]
        let taskTitle: [String: Any] = ["type": "string", "minLength": 1, "maxLength": 4_096, "description": "Nonblank, at most 4,096 UTF-8 bytes."]
        let taskOrder: [String: Any] = ["type": "integer", "minimum": 0, "maximum": Int.max]
        let taskRevision: [String: Any] = ["type": "integer", "minimum": 1, "maximum": Int64.max]
        let taskDraft: [String: Any] = [
            "type": "object", "additionalProperties": false, "required": ["id", "label", "title", "sortOrder"],
            "properties": ["id": taskID, "label": taskID, "title": taskTitle, "sortOrder": taskOrder],
        ]
        let taskDefinitionRevision: [String: Any] = [
            "type": "object", "additionalProperties": false, "required": ["id"],
            "properties": ["id": taskID, "title": taskTitle, "sortOrder": taskOrder],
        ]
        let phaseRevision: [String: Any] = ["type": "integer", "minimum": 0, "maximum": Int64.max]
        let goalDraft: [String: Any] = [
            "type": "object", "additionalProperties": false, "required": ["id", "title", "outcome", "doneCriteria", "sortOrder"],
            "properties": ["id": taskID, "title": ["type": "string"], "outcome": ["type": "string"],
                           "doneCriteria": ["type": "array", "items": string], "sortOrder": taskOrder],
        ]
        let assignment: [String: Any] = [
            "type": "object", "additionalProperties": false, "required": ["goalID", "ticketID"],
            "properties": ["goalID": taskID, "ticketID": taskID],
        ]
        return [
            ["name": "release_radar_inventory_evidence", "description": "Read a complete authorized project evidence inventory. Oversized or unavailable inventory fails closed; no rows are silently omitted.",
             "annotations": ["readOnlyHint": true, "destructiveHint": false],
             "inputSchema": ["type": "object", "additionalProperties": false, "required": ["version", "projectRoot"],
                             "properties": ["version": ["type": "integer", "const": 1], "projectRoot": string, "projectID": string, "rootID": string]]],
            definition("release_radar_bind_documentation_repository", required: ["target"], fields: ["target": target]),
            definition("release_radar_accept_documentation_catalog", required: ["target", "priorCatalogVersion", "priorCatalogDigest"], fields: ["target": target, "priorCatalogVersion": ["type": "integer", "const": 1], "priorCatalogDigest": string]),
            definition("release_radar_add_managed_evidence", required: ["target", "id", "artifactID"], fields: ["target": target, "id": string, "ticketID": string, "artifactID": string]),
            definition("release_radar_adopt_managed_evidence", required: ["target", "adoptions"], fields: ["target": target, "adoptions": adoption]),
            definition("release_radar_relocate_legacy_evidence", required: ["projectID", "rootID", "evidenceID", "expectedPath", "newPath"], fields: ["projectID": string, "rootID": string, "evidenceID": string, "expectedPath": string, "newPath": string]),
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
            definition(
                "release_radar_revise_ticket_task_plan",
                required: ["ticketID"],
                fields: [
                    "ticketID": taskID,
                    "expectedRevision": taskRevision,
                    "additions": ["type": "array", "maxItems": 64, "items": taskDraft],
                    "definitionRevisions": ["type": "array", "maxItems": 64, "items": taskDefinitionRevision],
                    "supersededTaskIDs": ["type": "array", "maxItems": 64, "items": taskID],
                ],
                description: "Revise a ticket task plan with at most 64 aggregate operations and a sorted-key encoded command of at most 65,536 bytes. Omitted operation arrays make no changes. New tasks are Active and Pending."
            ),
            definition(
                "release_radar_complete_ticket_task",
                required: ["ticketID", "taskID", "expectedRevision"],
                fields: ["ticketID": taskID, "taskID": taskID, "expectedRevision": taskRevision],
                description: "Complete one ticket task at the exact current plan revision and return the audited committed revision. This does not move the ticket or a Delivery Goal."
            ),
            definition(
                "release_radar_apply_phase_plan_revision",
                required: ["projectID", "phaseID", "expectedRevision"],
                fields: ["projectID": taskID, "phaseID": taskID, "expectedRevision": phaseRevision,
                         "goalUpserts": ["type": "array", "maxItems": 64, "items": goalDraft],
                         "assignments": ["type": "array", "maxItems": 512, "items": assignment],
                         "unassignedTicketIDs": ["type": "array", "maxItems": 512, "items": taskID],
                         "supersededGoalIDs": ["type": "array", "maxItems": 64, "items": taskID]],
                description: "Revise a phase plan with at most 64 aggregate goal operations, 512 aggregate assignment operations and a sorted-key encoded command of at most 65,536 bytes. Omitted arrays make no changes. Returns the committed Draft revision."
            ),
            definition(
                "release_radar_finalize_phase_plan",
                required: ["projectID", "phaseID", "expectedRevision"],
                fields: ["projectID": taskID, "phaseID": taskID, "expectedRevision": phaseRevision],
                description: "Validate complete Delivery Goals and ticket coverage at the exact current revision, then atomically mark the phase plan Ready."
            ),
            definition(
                "release_radar_transition_delivery_goal",
                required: ["projectID", "phaseID", "goalID", "expectedPlanRevision", "lifecycle"],
                fields: ["projectID": taskID, "phaseID": taskID, "goalID": taskID, "expectedPlanRevision": phaseRevision,
                         "lifecycle": ["type": "string", "enum": ["awaiting_acceptance"]]],
                description: "Request owner acceptance of an Active Delivery Goal after all assigned tickets are Accepted. Requires the current Ready plan and preserves its structural revision."
            ),
        ]
    }

    private static func definition(
        _ name: String,
        required: [String],
        fields: [String: [String: Any]],
        description: String = "Apply one approved, audited Release Radar delivery mutation."
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
            "description": description,
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

import Foundation
import ReleaseRadarCore

actor WorkerAdapter {
    struct Worker {
        let id: String
        let policy: WorkerPolicy
        var server: (any ExecutionPeer)?
        var threadID: String?
        var turnID: String?
        var status = "starting"
        var verified = false
        var busy = false
        var error: String?
        var messages: [String] = []
        var truncated = false
        var approvals: [String: [String: Any]] = [:]
        var effective: [String: Any] = [:]
        var uncertainApproval: [String: String]?
    }
    private let store: ProjectExecutionFileStore
    private var workers: [String: Worker] = [:]
    private var starting = false
    private let serverFactory: @Sendable (String, [String], @escaping @Sendable (RPCObject) -> Void) throws -> any ExecutionPeer
    init(store: ProjectExecutionFileStore,
         serverFactory: @escaping @Sendable (String, [String], @escaping @Sendable (RPCObject) -> Void) throws -> any ExecutionPeer = {
             try AppServerTransport(executable: $0, arguments: $1, onMessage: $2)
         }) { self.store = store; self.serverFactory = serverFactory }

    private func worker(_ id: String) throws -> Worker {
        guard let value = workers[id] else { throw ProjectExecutionError.identityMismatch }; return value
    }
    private func prompt(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.count <= 64_000 else { throw ProjectExecutionError.invalidAssignment }
    }
    private func unknown(_ error: Error) -> Bool { (error as? AppServerTransportError)?.outcomeUnknown == true }
    private func rpc(_ server: any ExecutionPeer, _ method: String, _ params: [String: Any]) async throws -> [String: Any] {
        let response = try await server.call(method, RPCObject(params))
        return try response.object()
    }

    func event(_ id: String, _ payload: RPCObject) {
        guard let message = try? payload.object() else { return }
        guard var worker = workers[id], let method = message["method"] as? String else { return }
        let params = message["params"] as? [String: Any] ?? [:]
        if method == "adapter/connectionLost" {
            worker.status = "unknown"; worker.error = "Connection lost; do not redispatch the assignment."
            do { try worker.policy.mark(.unknown, sessionID: worker.threadID, from: [.authorized, .stopped]) }
            catch { worker.error = "Connection lost; assignment revocation failed: \(error.localizedDescription). Stop the worker independently before recovery." }
        } else if worker.status == "unknown" {
            return // Late notifications cannot establish a previously uncertain outcome.
        } else if message["id"] != nil {
            worker.approvals[UUID().uuidString] = message; worker.status = "awaitingApproval"
        } else if params["threadId"] as? String == worker.threadID {
            if method == "turn/started", let turn = params["turn"] as? [String: Any] {
                worker.turnID = turn["id"] as? String; worker.status = "running"
            } else if method == "turn/completed", let turn = params["turn"] as? [String: Any] {
                worker.turnID = turn["id"] as? String; worker.status = turn["status"] as? String ?? "unknown"
                worker.error = (turn["error"] as? [String: Any])?["message"] as? String; worker.approvals.removeAll()
            } else if method == "serverRequest/resolved" {
                for (key, request) in worker.approvals {
                    if let requestID = request["id"], let resolved = params["requestId"],
                       Self.sameJSON(requestID, resolved) { worker.approvals.removeValue(forKey: key) }
                }
            } else if method == "item/completed", let item = params["item"] as? [String: Any], item["type"] as? String == "agentMessage" {
                let text = item["text"] as? String ?? ""
                if text.count > 32_000 || worker.messages.count >= 20 { worker.truncated = true }
                worker.messages.append(String(text.prefix(32_000))); worker.messages = Array(worker.messages.suffix(20))
            }
        }
        workers[id] = worker
    }
    private static func sameJSON(_ lhs: Any, _ rhs: Any) -> Bool {
        guard let left = try? JSONSerialization.data(withJSONObject: lhs, options: [.fragmentsAllowed, .sortedKeys]),
              let right = try? JSONSerialization.data(withJSONObject: rhs, options: [.fragmentsAllowed, .sortedKeys]) else { return false }
        return left == right
    }

    func start(projectID: String, assignmentID: String, prompt value: String) async throws -> RPCObject {
        try prompt(value)
        guard !starting, workers.count < 8 else { throw ProjectExecutionError.conflict }
        let selected = try WorkerPolicy(store: store, projectID: projectID, taskID: assignmentID)
        // An assignment is single-session. A partial/unknown launch is never silently replaced.
        guard selected.assignment.sessionID == nil,
              !workers.values.contains(where: { $0.policy.assignment.registration == selected.assignment.registration && $0.policy.assignment.id == assignmentID }) else { throw ProjectExecutionError.conflict }
        starting = true; defer { starting = false }
        let id = UUID().uuidString
        workers[id] = Worker(id: id, policy: selected)
        try selected.reserve() // Durable start intent prevents redispatch after a partial or uncertain start.
        do {
            guard try store.policy(projectID: projectID) == selected.policy else { throw ProjectExecutionError.assignmentNotAuthorized }
            var args = ["app-server", "--listen", "stdio://"]
            for (key, value) in try selected.overrides(config: [:]).sorted(by: { $0.key < $1.key }) {
                let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
                args += ["-c", key + "=" + String(decoding: data, as: UTF8.self)]
            }
            let server = try serverFactory(selected.policy.appServerExecutable, args) { [weak self] message in
                Task { await self?.event(id, message) }
            }
            workers[id]?.server = server
            _ = try await rpc(server, "initialize", ["clientInfo": ["name": "release_radar_coordinator", "version": "1"], "capabilities": ["experimentalApi": true]])
            try server.send(["method": "initialized"])
            let configResult = try await rpc(server, "config/read", ["cwd": selected.assignment.checkoutPath, "includeLayers": false])
            guard let config = configResult["config"] as? [String: Any] else { throw ProjectExecutionError.invalidAssignment }
            try selected.validate(config: config)
            let result = try await rpc(server, "thread/start", [
                "cwd": selected.assignment.checkoutPath, "runtimeWorkspaceRoots": [selected.assignment.checkoutPath],
                "permissions": selected.assignment.permissionProfile, "model": selected.assignment.model,
                "allowProviderModelFallback": false, "config": try selected.overrides(config: config),
            ])
            guard let thread = result["thread"] as? [String: Any], let threadID = thread["id"] as? String else { throw ProjectExecutionError.identityMismatch }
            workers[id]?.threadID = threadID
            workers[id]?.effective = result.filter { ["cwd", "runtimeWorkspaceRoots", "model", "reasoningEffort", "activePermissionProfile", "sandbox", "approvalPolicy", "approvalsReviewer", "instructionSources"].contains($0.key) }
            guard result["cwd"] as? String == selected.assignment.checkoutPath,
                  result["runtimeWorkspaceRoots"] as? [String] == [selected.assignment.checkoutPath],
                  result["model"] as? String == selected.assignment.model,
                  result["reasoningEffort"] as? String == selected.assignment.effort,
                  (result["activePermissionProfile"] as? [String: Any])?["id"] as? String == selected.assignment.permissionProfile,
                  (result["sandbox"] as? [String: Any])?["networkAccess"] as? Bool == false else { throw ProjectExecutionError.identityMismatch }
            try verifyInstructionSources(result["instructionSources"], selected: selected)
            var cursor: String?
            repeat {
                var params: [String: Any] = ["threadId": threadID, "detail": "full", "limit": 100]
                if let cursor { params["cursor"] = cursor }
                let inventory = try await rpc(server, "mcpServerStatus/list", params)
                guard let entries = inventory["data"] as? [[String: Any]], !entries.contains(where: { entry in
                    ["tools", "resources", "resourceTemplates"].contains { key in
                        if let dictionary = entry[key] as? [String: Any] { return !dictionary.isEmpty }
                        if let array = entry[key] as? [Any] { return !array.isEmpty }
                        return entry[key] != nil && !(entry[key] is NSNull)
                    }
                }) else { throw ProjectExecutionError.identityMismatch }
                cursor = inventory["nextCursor"] as? String
            } while cursor != nil
            try await verifyHook(server, selected: selected)
            try selected.bind(sessionID: threadID)
            workers[id]?.verified = true; workers[id]?.status = "ready"
            _ = try await followUp(workerID: id, prompt: value)
        } catch {
            workers[id]?.status = unknown(error) ? "unknown" : "failed"
            workers[id]?.error = error.localizedDescription
        }
        return try status(workerID: id)
    }

    private func verifyInstructionSources(_ value: Any?, selected: WorkerPolicy) throws {
        guard let sources = value as? [String] else { throw ProjectExecutionError.identityMismatch }
        let expected = Set(selected.assignment.context.map { selected.assignment.checkoutPath + "/" + $0.path })
        guard sources.allSatisfy(expected.contains) else { throw ProjectExecutionError.identityMismatch }
    }

    private func verifyHook(_ server: any ExecutionPeer, selected: WorkerPolicy) async throws {
        let result = try await rpc(server, "hooks/list", ["cwds": [selected.assignment.checkoutPath]])
        let data = try JSONSerialization.data(withJSONObject: result)
        _ = try ProjectExecutionHookReadiness.resolve(data, checkout: selected.assignment.checkoutPath,
            primaryRoot: selected.policy.primaryRoot, command: "\"" + selected.policy.handlerPath + "\" --hook", requireTrusted: true, inline: selected.policy.hookReceipt?.inline ?? false)
    }

    func status(workerID: String) throws -> RPCObject {
        let worker = try worker(workerID)
        var result: [String: Any] = ["workerId": workerID, "status": worker.status,
                                    "messages": worker.messages, "messagesTruncated": worker.truncated,
                                    "effective": worker.effective, "assignmentId": worker.policy.assignment.id,
                                    "projectId": worker.policy.assignment.registration.projectID.rawValue,
                                    "pendingRequests": worker.approvals.map { ["requestKey": $0.key, "method": $0.value["method"] ?? NSNull(), "params": $0.value["params"] ?? [:]] }]
        if let threadID = worker.threadID { result["threadId"] = threadID }
        if let turnID = worker.turnID { result["turnId"] = turnID }
        if let error = worker.error { result["error"] = error }
        if let uncertain = worker.uncertainApproval { result["uncertainApproval"] = uncertain }
        return try RPCObject(result)
    }

    func followUp(workerID: String, prompt value: String) async throws -> RPCObject {
        try prompt(value)
        let worker = try worker(workerID)
        guard worker.verified, !worker.busy, ["ready", "completed", "interrupted", "failed"].contains(worker.status),
              let threadID = worker.threadID, let server = worker.server else { throw ProjectExecutionError.assignmentNotAuthorized }
        workers[workerID]?.busy = true
        defer { workers[workerID]?.busy = false }
        let assignment = try worker.policy.current(sessionID: threadID)
        try await verifyHook(server, selected: worker.policy)
        // Re-read after awaited readiness: a revocation during discovery still prevents admission.
        _ = try worker.policy.current(sessionID: threadID)
        guard workers[workerID]?.threadID == threadID, workers[workerID]?.verified == true,
              ["ready", "completed", "interrupted", "failed"].contains(workers[workerID]?.status ?? "unknown") else { throw ProjectExecutionError.assignmentNotAuthorized }
        workers[workerID]?.status = "startingTurn"
        workers[workerID]?.messages = []; workers[workerID]?.truncated = false
        do {
            let result = try await rpc(server, "turn/start", ["threadId": threadID, "effort": assignment.effort,
                "input": [["type": "text", "text": assignment.workerInstructions + "\n\n" + value, "text_elements": []]]])
            guard let turn = result["turn"] as? [String: Any], let turnID = turn["id"] as? String else { throw ProjectExecutionError.identityMismatch }
            workers[workerID]?.turnID = turnID
            if workers[workerID]?.status == "startingTurn" { workers[workerID]?.status = turn["status"] as? String ?? "inProgress" }
        } catch {
            let failure = error
            let uncertain = unknown(error)
            workers[workerID]?.status = uncertain ? "unknown" : "failed"
            if uncertain {
                do { try worker.policy.mark(.unknown, sessionID: threadID, from: [.authorized, .stopped]) }
                catch { workers[workerID]?.error = "Follow-up outcome is uncertain; admission revocation failed: \(error.localizedDescription). Stop the known run independently." }
            }
            throw failure
        }
        return try status(workerID: workerID)
    }

    func interrupt(workerID: String) async throws -> RPCObject {
        let worker = try worker(workerID)
        guard let thread = worker.threadID, let turn = worker.turnID, let server = worker.server,
              worker.status != "closed" else { throw ProjectExecutionError.identityMismatch }
        try worker.policy.mark(worker.status == "unknown" ? .unknown : .stopped, sessionID: thread, from: [.authorized])
        do { _ = try await rpc(server, "turn/interrupt", ["threadId": thread, "turnId": turn]) }
        catch {
            if unknown(error) { workers[workerID]?.status = "unknown" }
            workers[workerID]?.error = "STOP was requested for the known run; confirmation failed: \(error.localizedDescription)"
            throw error
        }
        return try status(workerID: workerID) // Only turn/completed establishes that work stopped.
    }

    func respond(workerID: String, requestKey: String, decision: String) throws -> RPCObject {
        let worker = try worker(workerID)
        if decision == "accept" {
            guard let session = worker.threadID else { throw ProjectExecutionError.identityMismatch }
            _ = try worker.policy.current(sessionID: session)
        }
        guard !worker.busy, let request = worker.approvals[requestKey], let requestID = request["id"],
              let params = request["params"] as? [String: Any], params["threadId"] as? String == worker.threadID,
              params["turnId"] as? String == worker.turnID, let server = worker.server,
              ["item/commandExecution/requestApproval", "item/fileChange/requestApproval"].contains(request["method"] as? String ?? ""),
              ["accept", "decline", "cancel"].contains(decision),
              (params["availableDecisions"] as? [String])?.contains(decision) != false else { throw ProjectExecutionError.identityMismatch }
        workers[workerID]?.approvals.removeValue(forKey: requestKey)
        do { try server.send(["id": requestID, "result": ["decision": decision]]) }
        catch {
            let failure = error
            workers[workerID]?.status = "unknown"; workers[workerID]?.uncertainApproval = ["requestKey": requestKey, "decision": decision]
            do { try worker.policy.mark(.unknown, sessionID: worker.threadID, from: [.authorized, .stopped]) }
            catch { workers[workerID]?.error = "Approval response is uncertain; admission revocation failed: \(error.localizedDescription). Stop the known run independently." }
            throw failure
        }
        if workers[workerID]?.status == "awaitingApproval" {
            workers[workerID]?.status = workers[workerID]?.approvals.isEmpty == true ? "running" : "awaitingApproval"
        }
        return try status(workerID: workerID)
    }

    func close(workerID: String) throws -> RPCObject {
        let worker = try worker(workerID)
        guard !worker.busy, ["completed", "interrupted", "failed", "ready", "unknown"].contains(worker.status) else { throw ProjectExecutionError.assignmentNotAuthorized }
        do { try worker.server?.close() }
        catch {
            workers[workerID]?.status = "unknown"; workers[workerID]?.error = error.localizedDescription
            do { try worker.policy.mark(.unknown, sessionID: worker.threadID, from: [.authorized, .stopped]) }
            catch let revocationError {
                workers[workerID]?.error = "Cleanup failed: \(error.localizedDescription). Assignment revocation failed: \(revocationError.localizedDescription)."
            }
            throw error
        }
        try worker.policy.mark(worker.status == "completed" ? .closed : .stopped, sessionID: worker.threadID, from: [.authorized, .stopped, .revoked, .superseded, .unknown], connectionClosed: true)
        workers.removeValue(forKey: workerID)
        return try RPCObject(["workerId": workerID, "status": "connectionClosed", "threadId": worker.threadID.map { $0 as Any } ?? NSNull()])
    }
    func disconnect() throws {
        var failure: Error?
        for worker in workers.values {
            do {
                try worker.server?.close()
                try worker.policy.mark(worker.status == "completed" ? .closed : .stopped, sessionID: worker.threadID, from: [.authorized, .stopped, .revoked, .superseded, .unknown], connectionClosed: true)
            }
            catch {
                workers[worker.id]?.status = "unknown"; workers[worker.id]?.error = error.localizedDescription
                do { try worker.policy.mark(.unknown, sessionID: worker.threadID, from: [.authorized, .stopped]) }
                catch let revocationError {
                    workers[worker.id]?.error = "Cleanup failed: \(error.localizedDescription). Assignment revocation failed: \(revocationError.localizedDescription)."
                }
                if failure == nil { failure = error }
            }
        }
        if let failure { throw failure }
    }
}

import Darwin
import Foundation
import ReleaseRadarCore

struct RPCObject: Sendable {
    let data: Data
    init(_ object: [String: Any]) throws { data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }
    func object() throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppServerTransportError(message: "Malformed JSON object.", outcomeUnknown: true)
        }
        return value
    }
}

struct AppServerTransportError: Error, LocalizedError, Sendable {
    let message: String
    let outcomeUnknown: Bool
    var errorDescription: String? { message }
}

protocol ExecutionPeer: Sendable {
    func call(_ method: String, _ parameters: RPCObject) async throws -> RPCObject
    func send(_ message: [String: Any]) throws
    func close() throws
}

/// Newline JSON transport. Correlation IDs do not authorize replay of a mutation.
final class AppServerTransport: ExecutionPeer, @unchecked Sendable {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let lock = NSLock()
    private var serial = 0
    private var alive = true
    private var pending: [Int: CheckedContinuation<RPCObject, Error>] = [:]
    private let processExited = DispatchGroup()
    private let readerExited = DispatchGroup()
    private let onMessage: @Sendable (RPCObject) -> Void

    convenience init(executable: String, arguments: [String], onMessage: @escaping @Sendable (RPCObject) -> Void) throws {
        try self.init(executable: executable, arguments: arguments, environment: nil, onMessage: onMessage)
    }

    #if DEBUG
    // Fixture-only isolation. Release callers cannot redirect Codex's home.
    convenience init(fixtureHome: URL, onMessage: @escaping @Sendable (RPCObject) -> Void) throws {
        guard fixtureHome.isFileURL, fixtureHome.resolvingSymlinksInPath().path == fixtureHome.path else {
            throw ProjectExecutionError.identityMismatch
        }
        try self.init(executable: CodexExecutionIdentity.executable, arguments: ["app-server", "--listen", "stdio://"],
            environment: ["HOME": fixtureHome.path, "CODEX_HOME": fixtureHome.appendingPathComponent("codex").path, "PATH": "/usr/bin:/bin"], onMessage: onMessage)
    }
    #endif

    private init(executable: String, arguments: [String], environment: [String: String]?, onMessage: @escaping @Sendable (RPCObject) -> Void) throws {
        guard executable == CodexExecutionIdentity.executable else { throw ProjectExecutionError.identityMismatch }
        try CodexExecutionIdentity.verify()
        self.onMessage = onMessage
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.standardError
        processExited.enter()
        let exitGroup = processExited
        process.terminationHandler = { _ in exitGroup.leave() }
        do { try process.run() }
        catch { processExited.leave(); throw error }
        readerExited.enter()
        DispatchQueue(label: "ReleaseRadar.AppServer.reader").async { [self] in readMessages() }
    }

    func send(_ message: [String: Any]) throws {
        let bytes = try JSONSerialization.data(withJSONObject: message) + Data([10])
        try lock.withLock {
            guard alive else { throw AppServerTransportError(message: "App Server disconnected; no automatic replay.", outcomeUnknown: true) }
            do { try input.fileHandleForWriting.write(contentsOf: bytes) }
            catch { throw AppServerTransportError(message: "App Server write failed; outcome unknown.", outcomeUnknown: true) }
        }
    }

    func call(_ method: String, _ parameters: RPCObject) async throws -> RPCObject {
        let id = lock.withLock { serial += 1; return serial }
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { pending[id] = continuation }
            do { try send(["id": id, "method": method, "params": try parameters.object()]) }
            catch { fail(id, error: error) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.fail(id, error: AppServerTransportError(message: "App Server \(method) response timed out; outcome unknown. Do not replay.", outcomeUnknown: true))
            }
        }
    }

    private func fail(_ id: Int, error: Error) {
        let continuation = lock.withLock { pending.removeValue(forKey: id) }
        continuation?.resume(throwing: error)
    }

    private func consume(_ line: Data) throws {
        guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            throw AppServerTransportError(message: "Malformed App Server message.", outcomeUnknown: true)
        }
        if message["method"] != nil { onMessage(try RPCObject(message)); return }
        guard let id = message["id"] as? Int else { return }
        let continuation = lock.withLock { pending.removeValue(forKey: id) }
        guard let continuation else { return }
        if let error = message["error"] as? [String: Any] {
            continuation.resume(throwing: AppServerTransportError(message: error["message"] as? String ?? "App Server rejected request.", outcomeUnknown: false))
        } else if let result = message["result"] as? [String: Any] {
            continuation.resume(returning: try RPCObject(result))
        } else {
            continuation.resume(throwing: AppServerTransportError(message: "App Server response has no result or error.", outcomeUnknown: true))
        }
    }

    private func readMessages() {
        defer { readerExited.leave() }
        var buffer = Data()
        var bytes = [UInt8](repeating: 0, count: 16_384)
        var lossReason = "EOF"
        do {
            while true {
                // One POSIX read returns available pipe bytes. Foundation's
                // read(upToCount:) may wait to fill the count or reach EOF.
                let count = bytes.withUnsafeMutableBytes { Darwin.read(output.fileHandleForReading.fileDescriptor, $0.baseAddress, $0.count) }
                if count == 0 { break }
                if count < 0 {
                    if errno == EINTR { continue }
                    throw AppServerTransportError(message: "App Server pipe read failed (errno \(errno)).", outcomeUnknown: true)
                }
                buffer.append(contentsOf: bytes.prefix(count))
                guard buffer.count <= 8 * 1_048_576 else { throw AppServerTransportError(message: "App Server message exceeds limit.", outcomeUnknown: true) }
                while let newline = buffer.firstIndex(of: 10) {
                    let line = buffer[..<newline]; buffer.removeSubrange(...newline)
                    try consume(Data(line))
                }
            }
        } catch { lossReason = error.localizedDescription }
        let continuations = lock.withLock {
            alive = false
            let values = Array(pending.values); pending.removeAll(); return values
        }
        for continuation in continuations {
            continuation.resume(throwing: AppServerTransportError(message: "App Server connection lost; outcome unknown.", outcomeUnknown: true))
        }
        if let event = try? RPCObject(["method": "adapter/connectionLost", "params": ["reason": lossReason]]) { onMessage(event) }
    }

    func close() throws {
        var inputError: String?
        do { try input.fileHandleForWriting.close() }
        catch { inputError = error.localizedDescription }
        if processExited.wait(timeout: .now() + 3) == .timedOut {
            if process.isRunning { process.terminate() }
            if processExited.wait(timeout: .now() + 3) == .timedOut {
                if process.isRunning, Darwin.kill(process.processIdentifier, SIGKILL) != 0, errno != ESRCH {
                    throw AppServerTransportError(message: "App Server cleanup could not terminate its process (errno \(errno)); inspect the residual process. No rollback is established.", outcomeUnknown: true)
                }
                guard processExited.wait(timeout: .now() + 3) == .success else {
                    throw AppServerTransportError(message: "App Server process exit remains unknown after bounded cleanup; inspect it before retrying.", outcomeUnknown: true)
                }
            }
        }
        process.waitUntilExit()
        guard readerExited.wait(timeout: .now() + 3) == .success else {
            throw AppServerTransportError(message: "App Server reader remains active after process exit; connection cleanup is incomplete.", outcomeUnknown: true)
        }
        if let inputError {
            throw AppServerTransportError(message: "App Server exited, but closing its input failed: \(inputError)", outcomeUnknown: true)
        }
        // Process exit does not establish that child side effects rolled back.
    }
}

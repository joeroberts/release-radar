import Foundation

public protocol CodexObserver: Sendable {
    func snapshot() async throws -> CodexSnapshot
    func events() -> AsyncThrowingStream<CodexRuntimeEvent, Error>
}

public struct UnavailableCodexObserver: CodexObserver {
    public static let defaultReason = "Codex desktop live observation is unavailable."

    private let cachedSnapshot: CodexSnapshot?
    private let scope: CodexObservationScope?
    private let reason: String

    public init(
        cachedSnapshot: CodexSnapshot? = nil,
        scope: CodexObservationScope? = nil,
        reason: String = defaultReason
    ) {
        self.cachedSnapshot = cachedSnapshot
        self.scope = scope
        self.reason = reason
    }

    public func snapshot() async throws -> CodexSnapshot {
        normalizedSnapshot
    }

    public func events() -> AsyncThrowingStream<CodexRuntimeEvent, Error> {
        let snapshot = normalizedSnapshot
        return AsyncThrowingStream { continuation in
            continuation.yield(.snapshot(snapshot))
            continuation.finish()
        }
    }

    private var normalizedSnapshot: CodexSnapshot {
        if let cachedSnapshot {
            guard cachedSnapshot.schemaVersion == CodexSnapshot.currentSchemaVersion else {
                return .unavailable(
                    reason: "Cached Codex snapshot schema \(cachedSnapshot.schemaVersion) is unsupported."
                )
            }
            guard let scope else {
                return .unavailable(
                    reason: "Cached Codex observation is unavailable without an authorized project scope."
                )
            }
            let scopedThreads = cachedSnapshot.threads.compactMap { thread -> CodexThreadRuntime? in
                guard let workingDirectory = scope.canonicalWorkingDirectory(for: thread) else {
                    return nil
                }
                return thread.withWorkingDirectory(workingDirectory)
            }
            return cachedSnapshot.retainingAsStale(reason: reason, threads: scopedThreads)
        }
        return .unavailable(reason: reason)
    }
}

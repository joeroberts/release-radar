import Foundation

public protocol CodexObserver: Sendable {
    func snapshot() async throws -> CodexSnapshot
    func events() -> AsyncThrowingStream<CodexRuntimeEvent, Error>
}

public struct UnavailableCodexObserver: CodexObserver {
    public static let defaultReason = "Codex desktop live observation is unavailable."

    private let cachedSnapshot: CodexSnapshot?
    private let reason: String

    public init(cachedSnapshot: CodexSnapshot? = nil, reason: String = defaultReason) {
        self.cachedSnapshot = cachedSnapshot
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
            return cachedSnapshot.retainingAsStale(reason: reason)
        }
        return .unavailable(reason: reason)
    }
}

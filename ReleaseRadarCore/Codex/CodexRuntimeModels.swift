import Foundation

public enum CodexFreshnessState: String, Codable, Equatable, Sendable {
    case live
    case stale
    case unavailable
}

public struct CodexObservationFreshness: Codable, Equatable, Sendable {
    public let state: CodexFreshnessState
    public let lastObservedAt: Date?
    public let reason: String?

    public init(state: CodexFreshnessState, lastObservedAt: Date?, reason: String? = nil) {
        self.state = state
        self.lastObservedAt = lastObservedAt
        self.reason = reason
    }
}

public struct CodexObservationScope: Equatable, Sendable {
    public let selectedRoot: URL
    public let authorizedWorktreeRoots: [URL]
    public let excludedThreadIDs: Set<String>

    public init(
        selectedRoot: URL,
        authorizedWorktreeRoots: [URL] = [],
        excludedThreadIDs: Set<String> = []
    ) {
        self.selectedRoot = Self.canonical(selectedRoot)
        self.authorizedWorktreeRoots = authorizedWorktreeRoots.map(Self.canonical)
        self.excludedThreadIDs = excludedThreadIDs
    }

    func canonicalWorkingDirectory(for thread: CodexThreadRuntime) -> URL? {
        guard !excludedThreadIDs.contains(thread.id), thread.workingDirectory.isFileURL else {
            return nil
        }

        let candidate = Self.canonical(thread.workingDirectory)
        let roots = [selectedRoot] + authorizedWorktreeRoots
        guard roots.contains(where: { Self.contains(candidate, within: $0) }) else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: candidate.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            return nil
        }
        return candidate
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func contains(_ candidate: URL, within root: URL) -> Bool {
        let candidateComponents = candidate.pathComponents
        let rootComponents = root.pathComponents
        return candidateComponents.count >= rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}

public enum CodexThreadRuntimeStatus: String, Codable, Equatable, Sendable {
    case active
    case paused
    case blocked
    case awaitingInput = "awaiting_input"
    case completedReadyForReview = "completed_ready_for_review"
    case idle
    case unknown
}

public enum CodexGoalRuntimeStatus: String, Codable, Equatable, Sendable {
    case active
    case paused
    case blocked
    case completed
    case unknown
}

public struct CodexGoalRuntime: Codable, Equatable, Sendable {
    public let objective: String
    public let status: CodexGoalRuntimeStatus
    public let lastObservedAt: Date

    public init(objective: String, status: CodexGoalRuntimeStatus, lastObservedAt: Date) {
        self.objective = objective
        self.status = status
        self.lastObservedAt = lastObservedAt
    }
}

public struct CodexThreadRuntime: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let workingDirectory: URL
    public let status: CodexThreadRuntimeStatus
    public let activeFlags: [String]
    public let waitingForInput: Bool
    public let lastObservedAt: Date
    public let goal: CodexGoalRuntime?

    public init(
        id: String,
        workingDirectory: URL,
        status: CodexThreadRuntimeStatus,
        activeFlags: [String] = [],
        waitingForInput: Bool,
        lastObservedAt: Date,
        goal: CodexGoalRuntime?
    ) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.status = status
        self.activeFlags = activeFlags
        self.waitingForInput = waitingForInput
        self.lastObservedAt = lastObservedAt
        self.goal = goal
    }

    func withWorkingDirectory(_ workingDirectory: URL) -> CodexThreadRuntime {
        CodexThreadRuntime(
            id: id,
            workingDirectory: workingDirectory,
            status: status,
            activeFlags: activeFlags,
            waitingForInput: waitingForInput,
            lastObservedAt: lastObservedAt,
            goal: goal
        )
    }
}

public struct CodexSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let capturedAt: Date?
    public let freshness: CodexObservationFreshness
    public let threads: [CodexThreadRuntime]

    public init(
        schemaVersion: Int = CodexSnapshot.currentSchemaVersion,
        capturedAt: Date?,
        freshness: CodexObservationFreshness,
        threads: [CodexThreadRuntime]
    ) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.freshness = freshness
        self.threads = threads
    }

    public static func unavailable(reason: String) -> CodexSnapshot {
        CodexSnapshot(
            capturedAt: nil,
            freshness: .init(state: .unavailable, lastObservedAt: nil, reason: reason),
            threads: []
        )
    }

    func retainingAsStale(reason: String, threads scopedThreads: [CodexThreadRuntime]) -> CodexSnapshot {
        let latestThreadObservation = scopedThreads.map(\.lastObservedAt).max()
        let lastObservedAt = freshness.lastObservedAt ?? latestThreadObservation ?? capturedAt
        return CodexSnapshot(
            schemaVersion: schemaVersion,
            capturedAt: capturedAt,
            freshness: .init(state: .stale, lastObservedAt: lastObservedAt, reason: reason),
            threads: scopedThreads
        )
    }
}

public enum CodexRuntimeEvent: Equatable, Sendable {
    case snapshot(CodexSnapshot)
    case threadChanged(CodexThreadRuntime)
    case goalCleared(threadID: String, lastObservedAt: Date)
    case completed(threadID: String, lastObservedAt: Date)
    case disconnected(CodexSnapshot)
}

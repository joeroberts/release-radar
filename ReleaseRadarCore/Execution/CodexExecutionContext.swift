import Darwin
import Foundation

public enum CodexExecutionContextError: Error, LocalizedError, Equatable, Sendable {
    case selectionRequired, accessRequired, changed, subscriptionRequired
    public var errorDescription: String? {
        switch self {
        case .selectionRequired: "Select your existing Codex home in Settings → Connections before setting up execution. Use the folder belonging to your current ChatGPT account."
        case .accessRequired: "Codex folder access could not be restored. In Settings → Connections, select the same existing Codex home again. Its authentication and history are preserved."
        case .subscriptionRequired: "The selected Codex context has no available ChatGPT account. In Settings → Connections, select the existing Codex folder used by your signed-in account. Release Radar does not copy credentials or change your login."
        case .changed: "The selected Codex context changed or no longer matches this operation. Close known workers, restore the original folder in Settings → Connections, and review project execution setup. Reserved or uncertain assignments cannot be replayed."
        }
    }
}

/// Machine-local selection receipt, never portable project data or a credential copy.
public struct CodexExecutionContext: Codable, Equatable, Sendable {
    public let id: UUID
    public let homePath: String
    public let bookmark: Data
    public let selectedAt: Date
    public let previousContextID: UUID?
    private let device: UInt64
    private let inode: UInt64

    public init(home: URL, bookmark: Data, id: UUID = UUID(), previousContextID: UUID? = nil) throws {
        guard home.isFileURL, !bookmark.isEmpty, bookmark.count <= 256_000 else { throw CodexExecutionContextError.accessRequired }
        let path = try Self.canonicalPath(home.path)
        let metadata = try Self.folderMetadata(path)
        self.id = id; homePath = path; self.bookmark = bookmark; selectedAt = Date()
        self.previousContextID = previousContextID
        device = UInt64(truncatingIfNeeded: metadata.st_dev); inode = UInt64(metadata.st_ino)
    }

    public static func canonicalPath(_ path: String) throws -> String {
        guard path.hasPrefix("/"), path.rangeOfCharacter(from: .controlCharacters) == nil,
              let resolved = realpath(path, nil) else { throw CodexExecutionContextError.accessRequired }
        defer { free(resolved) }
        return String(cString: resolved)
    }
    private static func folderMetadata(_ path: String) throws -> stat {
        var metadata = stat()
        guard lstat(path, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFDIR,
              metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0 else { throw CodexExecutionContextError.accessRequired }
        return metadata
    }
    public func validateFolder() throws {
        guard try Self.canonicalPath(homePath) == homePath else { throw CodexExecutionContextError.changed }
        let metadata = try Self.folderMetadata(homePath)
        guard UInt64(truncatingIfNeeded: metadata.st_dev) == device, UInt64(metadata.st_ino) == inode else { throw CodexExecutionContextError.changed }
    }
    public func identifiesSameFolder(as other: Self) -> Bool {
        homePath == other.homePath && device == other.device && inode == other.inode
    }
}

/// A connection owns this lease until its process and reader physically close.
public final class CodexExecutionContextLease: @unchecked Sendable {
    public let context: CodexExecutionContext
    private let current: @Sendable () throws -> CodexExecutionContext?
    private let stop: @Sendable (URL) -> Void
    private let url: URL
    private let lock = NSLock()
    private var active = true

    public convenience init(context: CodexExecutionContext, current: @escaping @Sendable () throws -> CodexExecutionContext?) throws {
        let bookmarks = ProjectBookmarkStore()
        try self.init(context: context, current: current, resolve: bookmarks.resolve,
            start: { $0.startAccessingSecurityScopedResource() }, stop: { $0.stopAccessingSecurityScopedResource() })
    }
    init(context: CodexExecutionContext, current: @escaping @Sendable () throws -> CodexExecutionContext?,
         resolve: @Sendable (Data) throws -> ResolvedProjectBookmark,
         start: @Sendable (URL) -> Bool, stop: @escaping @Sendable (URL) -> Void) throws {
        let resolved: ResolvedProjectBookmark
        do { resolved = try resolve(context.bookmark) }
        catch { throw CodexExecutionContextError.accessRequired }
        guard !resolved.isStale else { throw CodexExecutionContextError.accessRequired }
        guard start(resolved.url) else { throw CodexExecutionContextError.accessRequired }
        do {
            guard try CodexExecutionContext.canonicalPath(resolved.url.path) == context.homePath,
                  try current() == context else { throw CodexExecutionContextError.changed }
            try context.validateFolder()
        } catch { stop(resolved.url); throw error }
        self.context = context; self.current = current; self.stop = stop; url = resolved.url
    }
    public func validate() throws {
        try lock.withLock {
            guard active, try current() == context else { throw CodexExecutionContextError.changed }
            try context.validateFolder()
        }
    }
    public func release() {
        let shouldStop = lock.withLock { if !active { return false }; active = false; return true }
        if shouldStop { stop(url) }
    }
    deinit { release() }
}

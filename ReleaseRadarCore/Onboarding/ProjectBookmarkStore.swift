import Foundation

public struct ResolvedProjectBookmark: Equatable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url.standardizedFileURL.resolvingSymlinksInPath()
        self.isStale = isStale
    }
}

public enum ProjectBookmarkError: Error, LocalizedError, Equatable, Sendable {
    case securityScopeAccessDenied

    public var errorDescription: String? {
        "Release Radar cannot access this folder. Select it again to reauthorize access."
    }
}

public protocol ProjectBookmarkStoring: Sendable {
    func makeBookmark(for url: URL) throws -> Data
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark
    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T
}

public struct ProjectBookmarkStore: ProjectBookmarkStoring, Sendable {
    private let bookmarkResolver: @Sendable (Data) throws -> ResolvedProjectBookmark
    private let startAccessing: @Sendable (URL) -> Bool
    private let stopAccessing: @Sendable (URL) -> Void

    public init() {
        bookmarkResolver = Self.resolveBookmark
        startAccessing = { $0.startAccessingSecurityScopedResource() }
        stopAccessing = { $0.stopAccessingSecurityScopedResource() }
    }

    init(
        resolver: @escaping @Sendable (Data) throws -> ResolvedProjectBookmark,
        startAccessing: @escaping @Sendable (URL) -> Bool,
        stopAccessing: @escaping @Sendable (URL) -> Void
    ) {
        bookmarkResolver = resolver
        self.startAccessing = startAccessing
        self.stopAccessing = stopAccessing
    }

    public func makeBookmark(for url: URL) throws -> Data {
        try url.standardizedFileURL.resolvingSymlinksInPath().bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        try bookmarkResolver(bookmark)
    }

    private static func resolveBookmark(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return .init(url: url, isStale: isStale)
    }

    public func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        let resolved = try resolve(bookmark)
        guard startAccessing(resolved.url) else { throw ProjectBookmarkError.securityScopeAccessDenied }
        defer { stopAccessing(resolved.url) }
        return try await body(resolved)
    }
}

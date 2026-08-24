import Foundation

public struct ResolvedProjectBookmark: Equatable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url.standardizedFileURL.resolvingSymlinksInPath()
        self.isStale = isStale
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
    public init() {}

    public func makeBookmark(for url: URL) throws -> Data {
        try url.standardizedFileURL.resolvingSymlinksInPath().bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
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
        let started = resolved.url.startAccessingSecurityScopedResource()
        defer {
            if started {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }
        return try await body(resolved)
    }
}

import Foundation

public struct ResolvedProjectBookmark: Equatable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        // Scope ownership belongs to the URL returned by Foundation. Callers
        // canonicalize separately when comparing physical folder identity.
        self.url = url
        self.isStale = isStale
    }
}

public enum ProjectBookmarkError: Error, LocalizedError, Equatable, Sendable {
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case securityScopeAccessDenied

    public var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed:
            "Release Radar could not save access to this folder. Select it again and retry."
        case .bookmarkResolutionFailed:
            "Release Radar could not restore access to this folder. Select it again to reauthorize access."
        case .securityScopeAccessDenied:
            "Release Radar cannot access this folder. Select it again to reauthorize access."
        }
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
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw ProjectBookmarkError.bookmarkCreationFailed
        }
    }

    public func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        do {
            return try bookmarkResolver(bookmark)
        } catch let error as ProjectBookmarkError {
            throw error
        } catch {
            throw ProjectBookmarkError.bookmarkResolutionFailed
        }
    }

    // Execution diagnostics retain only sanitized Foundation error codes. The
    // ordinary onboarding error contract remains unchanged.
    func resolveForExecutionContext(_ bookmark: Data) throws -> ResolvedProjectBookmark {
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

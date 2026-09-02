import Foundation

public enum ManagedDocumentResolutionFailure: Equatable, Codable, Sendable {
    case bindingMissing, bindingMismatch, rootNotBound, rootUnavailable, staleRoot
    case guidanceUnavailable, catalogUnaccepted, artifactNotFound, missingDocument, checksumInvalid, unsafeResolution
    case catalogInvalid(RepositoryDocumentError.Code)
}

public struct ResolvedManagedDocument: Equatable, Codable, Sendable {
    public let artifactID: String
    /// Current root-relative catalog path, never persisted as managed identity.
    public let resolvedPath: String?
    public let label: String?
    public let lifecycle: RepositoryDocumentArtifact.Lifecycle?
    public let authority: RepositoryDocumentArtifact.Authority?
    public let authorityRole: String?
    public let failure: ManagedDocumentResolutionFailure?
    public var isAvailable: Bool { failure == nil }
    public var isControlling: Bool { lifecycle == .active && authority == .controlling }
}

/// Enters the exact root's security scope before bounded no-follow catalog reads.
/// No fallback to another project root, remembered path, or unaccepted snapshot.
public struct ManagedDocumentResolver: Sendable {
    private let limits: RepositoryDocumentContract.Limits
    public init(limits: RepositoryDocumentContract.Limits = .init()) { self.limits = limits }

    public func resolve(artifactID: String, projectID: ProjectID, binding: ProjectDocumentationBinding?,
                        root: ProjectRootRecord?, bookmark: Data?,
                        bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) async -> ResolvedManagedDocument {
        await resolve(artifactIDs: [artifactID], projectID: projectID, binding: binding, root: root,
                      bookmark: bookmark, bookmarkStore: bookmarkStore)[artifactID]!
    }

    /// Shares authorization, catalog decoding and whole-catalog validation across a
    /// project readback. A managed row never triggers another inventory scan.
    public func resolve(artifactIDs: [String], projectID: ProjectID, binding: ProjectDocumentationBinding?,
                        root: ProjectRootRecord?, bookmark: Data?,
                        bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) async -> [String: ResolvedManagedDocument] {
        let ids = Set(artifactIDs)
        guard !ids.isEmpty else { return [:] }
        @Sendable func failed(_ failure: ManagedDocumentResolutionFailure) -> [String: ResolvedManagedDocument] {
            Dictionary(uniqueKeysWithValues: ids.map { ($0, result($0, failure: failure)) })
        }
        guard let binding else { return failed(.bindingMissing) }
        guard binding.projectID == projectID, (try? binding.acceptedSnapshot()) != nil else { return failed(.bindingMismatch) }
        guard let root, root.projectID == projectID, root.id == binding.rootID else { return failed(.rootNotBound) }
        guard let bookmark else { return failed(.rootUnavailable) }
        do {
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { resolved in
                guard !resolved.isStale else { return failed(.staleRoot) }
                guard resolved.url.isFileURL, resolved.url.path == root.path else { return failed(.rootNotBound) }
                return resolveAuthorized(artifactIDs: ids, binding: binding, root: resolved.url)
            }
        } catch { return failed(.rootUnavailable) }
    }

    private func resolveAuthorized(artifactIDs: Set<String>, binding: ProjectDocumentationBinding, root: URL) -> [String: ResolvedManagedDocument] {
        var artifacts: [String: RepositoryDocumentArtifact] = [:]
        func failed(_ failure: ManagedDocumentResolutionFailure) -> [String: ResolvedManagedDocument] {
            Dictionary(uniqueKeysWithValues: artifactIDs.map { ($0, result($0, artifact: artifacts[$0], failure: failure)) })
        }
        do {
            let reader: RepositoryDocumentReader
            do { reader = try RepositoryDocumentReader(rootURL: root, limits: limits, afterRead: nil) }
            catch let failure as RepositoryDocumentError where failure.code == .readFailed { return failed(.rootUnavailable) }
            guard try RepositoryDocumentationMode.read(reader) == .managedV2 else { return failed(.guidanceUnavailable) }
            let validator = RepositoryDocumentValidator(limits: limits)
            let snapshot = try validator.decodeCatalogSnapshot(reader.read(RepositoryDocumentContract.catalogPath, catalog: true))
            try reader.verifyStable()
            guard snapshot.catalog.repositoryID.lowercased() == binding.repositoryID else { return failed(.bindingMismatch) }
            guard snapshot.version == binding.acceptedCatalogVersion, snapshot.digest == binding.acceptedCatalogDigest,
                  snapshot.canonicalCatalog == binding.acceptedCatalog else { return failed(.catalogUnaccepted) }
            artifacts = Dictionary(uniqueKeysWithValues: snapshot.catalog.artifacts.map { ($0.artifactID, $0) })
            _ = try validator.validateCurrent(reader: reader)
            return Dictionary(uniqueKeysWithValues: artifactIDs.map {
                ($0, result($0, artifact: artifacts[$0], failure: artifacts[$0] == nil ? .artifactNotFound : nil))
            })
        } catch let failure as RepositoryDocumentError {
            return Dictionary(uniqueKeysWithValues: artifactIDs.map { id in
                let reason: ManagedDocumentResolutionFailure
                switch failure.code {
                case .missingFile where artifacts[id] != nil && failure.artifactPath == artifacts[id]?.path: reason = .missingDocument
                case .checksumMismatch: reason = .checksumInvalid
                case .unsafePath, .unsafeFileType: reason = .unsafeResolution
                default: reason = .catalogInvalid(failure.code)
                }
                return (id, result(id, artifact: artifacts[id], failure: reason))
            })
        } catch { return failed(.catalogInvalid(.readFailed)) }
    }

    private func result(_ artifactID: String, artifact: RepositoryDocumentArtifact? = nil,
                        failure: ManagedDocumentResolutionFailure? = nil) -> ResolvedManagedDocument {
        .init(artifactID: artifactID, resolvedPath: artifact?.path,
              label: artifact.map { String($0.path.split(separator: "/").last ?? "") },
              lifecycle: artifact?.lifecycle, authority: artifact?.authorityLevel,
              authorityRole: artifact?.authorityRole, failure: failure)
    }
}

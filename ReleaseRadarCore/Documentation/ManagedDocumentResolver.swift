import Foundation

public enum ManagedDocumentResolutionFailure: Equatable, Codable, Sendable {
    case bindingMissing, bindingMismatch, rootNotBound, rootUnavailable, staleRoot
    case catalogUnaccepted, artifactNotFound, missingDocument, checksumInvalid, unsafeResolution
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
        guard let binding else { return result(artifactID, failure: .bindingMissing) }
        guard binding.projectID == projectID, (try? binding.acceptedSnapshot()) != nil else {
            return result(artifactID, failure: .bindingMismatch)
        }
        guard let root, root.projectID == projectID, root.id == binding.rootID else {
            return result(artifactID, failure: .rootNotBound)
        }
        guard let bookmark else { return result(artifactID, failure: .rootUnavailable) }
        do {
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { resolved in
                guard !resolved.isStale else { return result(artifactID, failure: .staleRoot) }
                guard resolved.url.isFileURL, resolved.url.path == root.path else {
                    return result(artifactID, failure: .rootNotBound)
                }
                return resolveAuthorized(artifactID: artifactID, binding: binding, root: resolved.url)
            }
        } catch { return result(artifactID, failure: .rootUnavailable) }
    }

    private func resolveAuthorized(artifactID: String, binding: ProjectDocumentationBinding, root: URL) -> ResolvedManagedDocument {
        var artifact: RepositoryDocumentArtifact?
        do {
            let reader: RepositoryDocumentReader
            do { reader = try RepositoryDocumentReader(rootURL: root, limits: limits, afterRead: nil) }
            catch let failure as RepositoryDocumentError where failure.code == .readFailed {
                return result(artifactID, failure: .rootUnavailable)
            }
            let validator = RepositoryDocumentValidator(limits: limits)
            let snapshot = try validator.decodeCatalogSnapshot(reader.read(RepositoryDocumentContract.catalogPath, catalog: true))
            try reader.verifyStable()
            guard snapshot.catalog.repositoryID.lowercased() == binding.repositoryID else {
                return result(artifactID, failure: .bindingMismatch)
            }
            guard snapshot.version == binding.acceptedCatalogVersion, snapshot.digest == binding.acceptedCatalogDigest,
                  snapshot.canonicalCatalog == binding.acceptedCatalog else {
                return result(artifactID, failure: .catalogUnaccepted)
            }
            artifact = snapshot.catalog.artifacts.first { $0.artifactID == artifactID }
            guard artifact != nil else { return result(artifactID, failure: .artifactNotFound) }
            _ = try validator.validateCurrent(reader: reader)
            return result(artifactID, artifact: artifact)
        } catch let failure as RepositoryDocumentError {
            let reason: ManagedDocumentResolutionFailure
            switch failure.code {
            case .missingFile where artifact != nil && failure.artifactPath == artifact?.path: reason = .missingDocument
            case .checksumMismatch: reason = .checksumInvalid
            case .unsafePath, .unsafeFileType: reason = .unsafeResolution
            default: reason = .catalogInvalid(failure.code)
            }
            return result(artifactID, artifact: artifact, failure: reason)
        } catch { return result(artifactID, failure: .catalogInvalid(.readFailed)) }
    }

    private func result(_ artifactID: String, artifact: RepositoryDocumentArtifact? = nil,
                        failure: ManagedDocumentResolutionFailure? = nil) -> ResolvedManagedDocument {
        .init(artifactID: artifactID, resolvedPath: artifact?.path,
              label: artifact.map { String($0.path.split(separator: "/").last ?? "") },
              lifecycle: artifact?.lifecycle, authority: artifact?.authorityLevel,
              authorityRole: artifact?.authorityRole, failure: failure)
    }
}

import Foundation
import ImageIO

public enum EvidencePreviewStatus: Equatable, Sendable {
    case available
    case rejected
    case unsupported
    case oversized
    case inaccessible
    case missing
    case stale
}

public enum EvidencePreviewContent: Equatable, Sendable {
    case text(String, isTruncated: Bool)
    case raster(Data, format: String, width: Int, height: Int)
}

public struct EvidencePreview: Equatable, Sendable {
    public let identity: EvidenceLocator
    public let path: String?
    public let status: EvidencePreviewStatus
    public let content: EvidencePreviewContent?

    public init(identity: EvidenceLocator, path: String?, status: EvidencePreviewStatus, content: EvidencePreviewContent?) {
        self.identity = identity
        self.path = path
        self.status = status
        self.content = content
    }
}

/// Reads an accepted managed artifact into a transient, display-only preview.
/// It deliberately validates the live repository against the bound snapshot for
/// every request; previewing never updates evidence, acceptance, or audit state.
struct EvidencePreviewReader: Sendable {
    static let maximumPreviewBytes = 1 * 1_024 * 1_024
    static let maximumPreviewTextCharacters = 128 * 1_024

    private let limits: RepositoryDocumentContract.Limits

    init(limits: RepositoryDocumentContract.Limits = .init()) {
        self.limits = limits
    }

    func previewManaged(artifactID: String, binding: ProjectDocumentationBinding, root: URL) throws -> EvidencePreview {
        let identity = EvidenceLocator.managedDocument(artifactID: artifactID)
        guard (try? binding.acceptedSnapshot()) != nil else {
            return .init(identity: identity, path: nil, status: .rejected, content: nil)
        }
        do {
            let reader = try RepositoryDocumentReader(rootURL: root, limits: limits, afterRead: nil)
            guard try RepositoryDocumentationMode.read(reader) == .managedV2 else {
                return .init(identity: identity, path: nil, status: .rejected, content: nil)
            }
            let validator = RepositoryDocumentValidator(limits: limits)
            let snapshot = try validator.decodeCatalogSnapshot(reader.read(RepositoryDocumentContract.catalogPath, catalog: true))
            guard snapshot.catalog.repositoryID.lowercased() == binding.repositoryID,
                  snapshot.version == binding.acceptedCatalogVersion,
                  snapshot.digest == binding.acceptedCatalogDigest,
                  snapshot.canonicalCatalog == binding.acceptedCatalog,
                  let artifact = snapshot.catalog.artifacts.first(where: { $0.artifactID == artifactID }) else {
                return .init(identity: identity, path: nil, status: .rejected, content: nil)
            }
            _ = try validator.validateCurrent(reader: reader)
            let bytes = try reader.read(artifact.path)
            try reader.verifyStable()
            return decode(identity: identity, path: artifact.path, bytes: bytes)
        } catch let error as RepositoryDocumentError {
            let status: EvidencePreviewStatus = switch error.code {
            case .missingFile: .missing
            case .limitExceeded: .oversized
            case .readFailed: .inaccessible
            default: .rejected
            }
            return .init(identity: identity, path: error.artifactPath, status: status, content: nil)
        } catch {
            return .init(identity: identity, path: nil, status: .rejected, content: nil)
        }
    }

    func previewManaged(
        artifactID: String,
        projectID: ProjectID,
        binding: ProjectDocumentationBinding?,
        root: ProjectRootRecord?,
        bookmark: Data?,
        bookmarkStore: any ProjectBookmarkStoring
    ) async -> EvidencePreview {
        let identity = EvidenceLocator.managedDocument(artifactID: artifactID)
        guard let binding, binding.projectID == projectID,
              let root, root.projectID == projectID, root.id == binding.rootID,
              let bookmark else {
            return .init(identity: identity, path: nil, status: .rejected, content: nil)
        }
        do {
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { resolved in
                guard !resolved.isStale, resolved.url.isFileURL, resolved.url.path == root.path else {
                    return .init(identity: identity, path: nil, status: .rejected, content: nil)
                }
                return try previewManaged(artifactID: artifactID, binding: binding, root: resolved.url)
            }
        } catch {
            return .init(identity: identity, path: nil, status: .rejected, content: nil)
        }
    }

    func previewLegacy(path: String, root: URL, relativePath: String, bookmark: Data,
                       bookmarkStore: any ProjectBookmarkStoring) async -> EvidencePreview {
        let identity = EvidenceLocator.filePath(path)
        do {
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { resolved in
                guard !resolved.isStale, resolved.url.isFileURL, resolved.url.path == root.path else {
                    return .init(identity: identity, path: path, status: .inaccessible, content: nil)
                }
                do {
                    let reader = try RepositoryDocumentReader(rootURL: resolved.url, limits: limits, afterRead: nil)
                    let bytes = try reader.read(relativePath)
                    try reader.verifyStable()
                    return decode(identity: identity, path: path, bytes: bytes)
                } catch let error as RepositoryDocumentError where error.code == .missingFile {
                    return .init(identity: identity, path: path, status: .missing, content: nil)
                } catch {
                    return .init(identity: identity, path: path, status: .rejected, content: nil)
                }
            }
        } catch {
            return .init(identity: identity, path: path, status: .inaccessible, content: nil)
        }
    }

    func decode(identity: EvidenceLocator, path: String, bytes: Data) -> EvidencePreview {
        guard bytes.count <= Self.maximumPreviewBytes else {
            return .init(identity: identity, path: path, status: .oversized, content: nil)
        }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let textExtensions: Set<String> = ["md", "markdown", "txt", "json", "diff", "patch", "swift", "html", "htm", "svg", "xml", "yaml", "yml", "csv"]
        if textExtensions.contains(ext) {
            guard let text = String(data: bytes, encoding: .utf8) else {
                return .init(identity: identity, path: path, status: .rejected, content: nil)
            }
            let prefix = String(text.prefix(Self.maximumPreviewTextCharacters))
            return .init(identity: identity, path: path, status: .available,
                         content: .text(prefix, isTruncated: prefix.count < text.count))
        }
        if ["png", "jpg", "jpeg", "gif", "webp", "tiff"].contains(ext) {
            guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                  CGImageSourceGetCount(source) == 1,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 4_096, height <= 4_096,
                  width * height <= 16_000_000 else {
                return .init(identity: identity, path: path, status: .rejected, content: nil)
            }
            // The UI decodes only these bounded transient bytes; no web view or
            // remote resource loader participates in preview rendering.
            return .init(identity: identity, path: path, status: .available,
                         content: .raster(bytes, format: ext, width: width, height: height))
        }
        return .init(identity: identity, path: path, status: .unsupported, content: nil)
    }
}

private struct ManagedEvidencePreviewContext: Equatable, Sendable {
    let artifactID: String
    let registration: ProjectRegistration?
    let binding: ProjectDocumentationBinding?
    let root: ProjectRootRecord?
    let bookmark: Data?
    let stale: Bool
}

private struct EvidencePreviewAuthorizedRoot: Equatable, Sendable {
    let id: ProjectRootID
    let path: String
    let bookmark: Data?
    let stale: Bool
}

private struct LegacyEvidencePreviewContext: Equatable, Sendable {
    let path: String
    let registration: ProjectRegistration?
    let primaryRootID: ProjectRootID?
    let selectedRoot: EvidencePreviewAuthorizedRoot?
    let relativePath: String?
}

extension DeliveryStore {
    /// A display-only managed read. It reuses the stored root authorization and
    /// never updates persistent evidence availability or delivery state.
    private func previewManagedEvidence(
        projectID: ProjectID,
        evidenceID: EvidenceID,
        bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()
    ) async -> EvidencePreview {
        let fallback = EvidencePreview(identity: .filePath(""), path: nil, status: .rejected, content: nil)
        do {
            let state = try managedPreviewContext(projectID: projectID, evidenceID: evidenceID)
            guard let state else { return fallback }
            let identity = EvidenceLocator.managedDocument(artifactID: state.artifactID)
            guard state.registration != nil else {
                return .init(identity: identity, path: nil, status: .rejected, content: nil)
            }
            if state.stale {
                return .init(identity: identity, path: nil, status: .stale, content: nil)
            }
            guard state.root != nil, state.bookmark != nil else {
                return .init(identity: identity, path: nil, status: .inaccessible, content: nil)
            }
            let result = await EvidencePreviewReader().previewManaged(
                artifactID: state.artifactID,
                projectID: projectID,
                binding: state.binding,
                root: state.root,
                bookmark: state.bookmark,
                bookmarkStore: bookmarkStore
            )
            guard try managedPreviewContext(projectID: projectID, evidenceID: evidenceID) == state else {
                return .init(identity: identity, path: result.path, status: .rejected, content: nil)
            }
            return result
        } catch { return fallback }
    }

    public func previewEvidence(
        projectID: ProjectID,
        evidenceID: EvidenceID,
        bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()
    ) async -> EvidencePreview {
        guard let record = try? locatedEvidence(projectID: projectID, evidenceID: evidenceID) else {
            return .init(identity: .filePath(""), path: nil, status: .missing, content: nil)
        }
        if case .managedDocument = record.locator {
            return await previewManagedEvidence(projectID: projectID, evidenceID: evidenceID, bookmarkStore: bookmarkStore)
        }
        guard case let .filePath(path) = record.locator else {
            return .init(identity: record.locator, path: nil, status: .rejected, content: nil)
        }
        do {
            let context = try legacyPreviewContext(projectID: projectID, evidenceID: evidenceID, path: path)
            guard context.registration != nil, let selected = context.selectedRoot, let relative = context.relativePath else {
                return .init(identity: record.locator, path: path, status: .inaccessible, content: nil)
            }
            guard !selected.stale else {
                return .init(identity: record.locator, path: path, status: .stale, content: nil)
            }
            guard let bookmark = selected.bookmark else {
                return .init(identity: record.locator, path: path, status: .inaccessible, content: nil)
            }
            let result = await EvidencePreviewReader().previewLegacy(path: path, root: URL(fileURLWithPath: selected.path), relativePath: relative, bookmark: bookmark, bookmarkStore: bookmarkStore)
            guard try legacyPreviewContext(projectID: projectID, evidenceID: evidenceID, path: path) == context else {
                return .init(identity: record.locator, path: path, status: .rejected, content: nil)
            }
            return result
        } catch {
            return .init(identity: record.locator, path: path, status: .inaccessible, content: nil)
        }
    }

    private func managedPreviewContext(projectID: ProjectID, evidenceID: EvidenceID) throws -> ManagedEvidencePreviewContext? {
        let schemaVersion = schemaVersionForDocumentation
        return try documentationRead { c in
            guard let record = try c.row("SELECT artifact_id FROM evidence WHERE project_id = ? AND id = ?", bindings: [.text(projectID.rawValue), .text(evidenceID.rawValue)]),
                  case let .text(artifactID) = record["artifact_id"] else { return nil }
            let registration = try Self.registration(c, projectID: projectID)
            let binding = try DocumentationRootContext.binding(c, projectID: projectID.rawValue, version: schemaVersion)
            guard let binding,
                  let row = try c.row("SELECT r.path, b.bookmark_data, b.is_stale FROM project_roots r LEFT JOIN project_bookmarks b ON b.project_id = r.project_id AND b.path = r.path WHERE r.id = ? AND r.project_id = ?", bindings: [.text(binding.rootID.rawValue), .text(projectID.rawValue)]),
                  case let .text(path) = row["path"] else {
                return .init(artifactID: artifactID, registration: registration, binding: binding, root: nil, bookmark: nil, stale: false)
            }
            let bookmark: Data? = if case let .blob(value) = row["bookmark_data"] { value } else { nil }
            return .init(
                artifactID: artifactID,
                registration: registration,
                binding: binding,
                root: .init(id: binding.rootID, projectID: projectID, path: path),
                bookmark: bookmark,
                stale: row["is_stale"] != .integer(0)
            )
        }
    }

    private func legacyPreviewContext(projectID: ProjectID, evidenceID: EvidenceID, path: String) throws -> LegacyEvidencePreviewContext {
        try documentationRead { c in
            let persistedPath = try c.scalarText("SELECT path FROM evidence WHERE project_id = ? AND id = ? AND artifact_id IS NULL", bindings: [.text(projectID.rawValue), .text(evidenceID.rawValue)])
            guard persistedPath == path else {
                return .init(path: path, registration: nil, primaryRootID: nil, selectedRoot: nil, relativePath: nil)
            }
            let registration = try Self.registration(c, projectID: projectID)
            let boundRootID = try c.scalarText("SELECT root_id FROM project_documentation_bindings WHERE project_id = ?", bindings: [.text(projectID.rawValue)]).map(ProjectRootID.init(rawValue:))
            var roots: [EvidencePreviewAuthorizedRoot] = []
            var offset: Int64 = 0
            while let row = try c.row("SELECT r.id, r.path, b.bookmark_data, b.is_stale FROM project_roots r LEFT JOIN project_bookmarks b ON b.project_id = r.project_id AND b.path = r.path WHERE r.project_id = ? ORDER BY r.rowid LIMIT 1 OFFSET ?", bindings: [.text(projectID.rawValue), .integer(offset)]) {
                guard case let .text(id) = row["id"], case let .text(rootPath) = row["path"] else { break }
                let bookmark: Data? = if case let .blob(data) = row["bookmark_data"] { data } else { nil }
                roots.append(.init(id: .init(rawValue: id), path: rootPath, bookmark: bookmark, stale: row["is_stale"] != .integer(0)))
                offset += 1
            }
            let primaryRootID = boundRootID ?? roots.first?.id
            let absolute = path.hasPrefix("/")
            let candidate = absolute ? URL(fileURLWithPath: path).standardizedFileURL.path : nil
            let selected = if absolute {
                roots.filter { Self.contains(candidate!, within: $0.path) }
                    .max { URL(fileURLWithPath: $0.path).pathComponents.count < URL(fileURLWithPath: $1.path).pathComponents.count }
            } else {
                roots.first(where: { $0.id == primaryRootID })
            }
            let relativePath = selected.map { absolute ? String(candidate!.dropFirst($0.path.count + 1)) : path }
            return .init(path: path, registration: registration, primaryRootID: primaryRootID, selectedRoot: selected, relativePath: relativePath)
        }
    }

    private static func registration(_ c: SQLiteConnection, projectID: ProjectID) throws -> ProjectRegistration? {
        guard let row = try c.row("SELECT registration_id, request_generation FROM project_registrations WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
              case let .text(id) = row["registration_id"], case let .integer(generation) = row["request_generation"] else { return nil }
        return .init(projectID: projectID, registrationID: id, requestGeneration: generation)
    }

    private static func contains(_ candidate: String, within root: String) -> Bool {
        let candidateComponents = URL(fileURLWithPath: candidate).pathComponents
        let rootComponents = URL(fileURLWithPath: root).pathComponents
        return candidateComponents.count > rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}

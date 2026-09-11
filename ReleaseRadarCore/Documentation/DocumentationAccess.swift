import Foundation

struct DocumentationRootContext: Sendable {
    let projectID: String
    let projectName: String
    let rootID: String
    let root: URL
    let bookmark: Data
    let binding: ProjectDocumentationBinding?
    let registration: ProjectRegistration?
    let incarnationID: String?
    let schemaVersion: Int

    init(
        projectID: String,
        projectName: String,
        rootID: String,
        root: URL,
        bookmark: Data,
        binding: ProjectDocumentationBinding?,
        registration: ProjectRegistration? = nil,
        incarnationID: String? = nil,
        schemaVersion: Int
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.rootID = rootID
        self.root = root
        self.bookmark = bookmark
        self.binding = binding
        self.registration = registration
        self.incarnationID = incarnationID
        self.schemaVersion = schemaVersion
    }

    static func read(_ c: SQLiteConnection, path: String, projectID: String? = nil, rootID: String? = nil, schemaVersion: Int = 13) throws -> Self {
        guard path.hasPrefix("/"), !path.utf8.contains(0), path.utf8.count <= 4096,
              let row = try c.row("""
                SELECT r.id, r.project_id, r.path, p.name, b.bookmark_data, b.is_stale
                FROM project_roots r JOIN projects p ON p.id = r.project_id
                LEFT JOIN project_bookmarks b ON b.project_id = r.project_id AND b.path = r.path
                WHERE r.path = ?
                """, bindings: [.text(path)]),
              case let .text(actualProject) = row["project_id"], case let .text(actualRoot) = row["id"],
              case let .text(name) = row["name"] else { throw DocumentationOperationError.rootUnavailable }
        guard projectID.map({ $0 == actualProject }) != false, rootID.map({ $0 == actualRoot }) != false else {
            throw DocumentationOperationError.rootMismatch
        }
        guard row["is_stale"] == .integer(0), case let .blob(bookmark) = row["bookmark_data"] else {
            throw DocumentationOperationError.rootUnavailable
        }
        let version = schemaVersion
        return try .init(projectID: actualProject, projectName: name, rootID: actualRoot,
                         root: URL(fileURLWithPath: path), bookmark: bookmark,
                         binding: binding(c, projectID: actualProject, version: version),
                         registration: registration(c, projectID: actualProject, version: version),
                         incarnationID: incarnationID(c, version: version), schemaVersion: version)
    }
    private static func registration(_ c: SQLiteConnection, projectID: String, version: Int) throws -> ProjectRegistration? {
        guard version >= 15,
              let row = try c.row(
                "SELECT registration_id, request_generation FROM project_registrations WHERE project_id = ?",
                bindings: [.text(projectID)]
              ) else { return nil }
        guard case let .text(registrationID)? = row["registration_id"],
              case let .integer(requestGeneration)? = row["request_generation"] else {
            throw DocumentationOperationError.staleRegistration
        }
        return .init(
            projectID: .init(rawValue: projectID),
            registrationID: registrationID,
            requestGeneration: requestGeneration
        )
    }
    private static func incarnationID(_ c: SQLiteConnection, version: Int) throws -> String? {
        guard version >= 18 else { return nil }
        guard let value = try c.scalarText(
            "SELECT incarnation_id FROM application_recovery_state WHERE singleton_id = 1"
        ) else { throw DocumentationOperationError.staleRegistration }
        return value
    }
    static func binding(_ c: SQLiteConnection, projectID: String, version: Int = 13) throws -> ProjectDocumentationBinding? {
        guard version >= 13, let row = try c.row("SELECT * FROM project_documentation_bindings WHERE project_id = ?", bindings: [.text(projectID)]) else { return nil }
        guard case let .text(root) = row["root_id"], case let .text(repository) = row["repository_id"],
              case let .integer(version) = row["accepted_catalog_version"], case let .text(digest) = row["accepted_catalog_digest"],
              case let .blob(catalog) = row["accepted_catalog"] else { throw DocumentationOperationError.bindingMismatch }
        do {
            return try .init(projectID: .init(rawValue: projectID), rootID: .init(rawValue: root), repositoryID: repository,
                             acceptedCatalogVersion: Int(version), acceptedCatalogDigest: digest, acceptedCatalog: catalog)
        } catch { throw DocumentationOperationError.bindingMismatch }
    }
    func verifyAuthorization(_ resolved: ResolvedProjectBookmark) throws {
        guard !resolved.isStale else { throw DocumentationOperationError.staleRoot }
        guard resolved.url.isFileURL, resolved.url.path == root.path else { throw DocumentationOperationError.rootMismatch }
    }
    func verifyPersisted(_ c: SQLiteConnection) throws {
        let current = try Self.read(
            c, path: root.path, projectID: projectID, rootID: rootID, schemaVersion: schemaVersion
        )
        guard current.registration == registration,
              current.incarnationID == incarnationID else {
            throw DocumentationOperationError.staleRegistration
        }
        guard current.bookmark == bookmark, current.binding == binding else { throw DocumentationOperationError.bindingMismatch }
    }
    func requireAccepted(_ snapshot: RepositoryDocumentSnapshot) throws {
        guard let binding else { throw DocumentationOperationError.bindingMissing }
        guard binding.rootID.rawValue == rootID, binding.repositoryID == snapshot.catalog.repositoryID.lowercased() else { throw DocumentationOperationError.bindingMismatch }
        guard binding.acceptedCatalogVersion == snapshot.version, binding.acceptedCatalogDigest == snapshot.digest else { throw DocumentationOperationError.catalogUnaccepted }
    }
}

struct DocumentationCatalogContext {
    let reader: RepositoryDocumentReader
    let mode: RepositoryDocumentationMode
    let snapshot: RepositoryDocumentSnapshot?
    let validationError: RepositoryDocumentError.Code?

    init(root: URL) throws {
        reader = try RepositoryDocumentReader(rootURL: root, limits: .init(), afterRead: nil)
        mode = try RepositoryDocumentationMode.read(reader)
        do {
            snapshot = try RepositoryDocumentValidator().validateCurrent(reader: reader)
            validationError = nil
        } catch let error as RepositoryDocumentError {
            snapshot = nil; validationError = error.code
        }
    }
    func managedSnapshot(target: DocumentationTarget? = nil) throws -> RepositoryDocumentSnapshot {
        guard mode.isManaged else { throw DocumentationOperationError.guidanceUnavailable }
        guard let snapshot else { throw DocumentationOperationError.catalogInvalid }
        if let target {
            guard target.repositoryID == snapshot.catalog.repositoryID.lowercased(), target.catalogVersion == snapshot.version,
                  target.catalogDigest == snapshot.digest else { throw DocumentationOperationError.catalogUnaccepted }
        }
        return snapshot
    }
    func exactArtifact(path: String, root: URL) throws -> RepositoryDocumentArtifact? {
        let relative = try Self.relative(path: path, root: root)
        // Validate the lexical path and each no-follow component before comparing identity.
        _ = try reader.read(relative)
        return snapshot?.catalog.artifacts.first { $0.path == relative }
    }
    static func relative(path: String, root: URL) throws -> String {
        let relative: String
        if path.hasPrefix("/") {
            guard path.hasPrefix(root.path + "/") else { throw DocumentationOperationError.unsafePath }
            relative = String(path.dropFirst(root.path.count + 1))
        } else { relative = path }
        do { try RepositoryDocumentReader.validatePath(relative, limits: .init(), docsOnly: false) }
        catch { throw DocumentationOperationError.unsafePath }
        return relative
    }
    static func map(_ error: Error) -> DocumentationOperationError {
        if let error = error as? DocumentationOperationError { return error }
        if let error = error as? RepositoryDocumentError {
            switch error.code {
            case .missingFile: return .missingFile
            case .unsafePath, .unsafeFileType: return .unsafePath
            default: return .catalogInvalid
            }
        }
        return .rootUnavailable
    }
}

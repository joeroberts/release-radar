import Foundation

/// Identity is exactly one locator. Managed identity never includes a cached path.
public enum EvidenceLocator: Equatable, Sendable, Codable {
    case filePath(String)
    case managedDocument(artifactID: String)

    private enum CodingKeys: String, CodingKey { case kind, path, artifactID }
    private enum Kind: String, Codable { case filePath, managedDocument }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Kind.self, forKey: .kind) {
        case .filePath:
            guard values.contains(.path), !values.contains(.artifactID) else {
                throw DecodingError.dataCorruptedError(forKey: .path, in: values, debugDescription: "Expected only a file path locator")
            }
            self = .filePath(try values.decode(String.self, forKey: .path))
        case .managedDocument:
            guard values.contains(.artifactID), !values.contains(.path) else {
                throw DecodingError.dataCorruptedError(forKey: .artifactID, in: values, debugDescription: "Expected only an artifact identity locator")
            }
            let id = try values.decode(String.self, forKey: .artifactID)
            guard !id.isEmpty, id.utf8.count <= 128 else {
                throw DecodingError.dataCorruptedError(forKey: .artifactID, in: values, debugDescription: "Invalid artifact identity")
            }
            self = .managedDocument(artifactID: id)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .filePath(path):
            try values.encode(Kind.filePath, forKey: .kind)
            try values.encode(path, forKey: .path)
        case let .managedDocument(artifactID):
            try values.encode(Kind.managedDocument, forKey: .kind)
            try values.encode(artifactID, forKey: .artifactID)
        }
    }
}

/// Additive readback model. EvidenceRecord remains the legacy path-only API;
/// consumers adopt this model when they can handle both locator variants.
public struct LocatedEvidenceRecord: Codable, Equatable, Sendable {
    public let id: EvidenceID
    public let projectID: ProjectID
    public let ticketID: TicketID?
    public let locator: EvidenceLocator
    /// Last persisted availability; managed availability must be resolved afresh.
    public let isAvailable: Bool

    public init(id: EvidenceID, projectID: ProjectID, ticketID: TicketID?, locator: EvidenceLocator, isAvailable: Bool) {
        self.id = id; self.projectID = projectID; self.ticketID = ticketID
        self.locator = locator; self.isAvailable = isAvailable
    }

    public var legacyRecord: EvidenceRecord? {
        guard case let .filePath(path) = locator else { return nil }
        return .init(id: id, projectID: projectID, ticketID: ticketID, path: path, isAvailable: isAvailable)
    }

    private enum CodingKeys: String, CodingKey { case id, projectID, ticketID, locator, path, artifactID, isAvailable }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard !values.contains(.artifactID), values.contains(.locator) != values.contains(.path) else {
            throw DecodingError.dataCorruptedError(forKey: .locator, in: values, debugDescription: "Expected exactly one evidence locator")
        }
        id = try values.decode(EvidenceID.self, forKey: .id)
        projectID = try values.decode(ProjectID.self, forKey: .projectID)
        ticketID = try values.decodeIfPresent(TicketID.self, forKey: .ticketID)
        isAvailable = try values.decode(Bool.self, forKey: .isAvailable)
        locator = try values.contains(.locator) ? values.decode(EvidenceLocator.self, forKey: .locator)
            : .filePath(values.decode(String.self, forKey: .path))
    }
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(projectID, forKey: .projectID)
        try values.encodeIfPresent(ticketID, forKey: .ticketID)
        try values.encode(locator, forKey: .locator)
        try values.encode(isAvailable, forKey: .isAvailable)
    }
}

public enum ProjectDocumentationBindingError: Error, Equatable, Sendable {
    case invalidAcceptedSnapshot
}

/// The durable trust anchor. Construction and decoding validate canonical bytes,
/// metadata, version and digest without accessing a repository.
public struct ProjectDocumentationBinding: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let rootID: ProjectRootID
    public let repositoryID: String
    public let acceptedCatalogVersion: Int
    public let acceptedCatalogDigest: String
    public let acceptedCatalog: Data

    public init(projectID: ProjectID, rootID: ProjectRootID, acceptedSnapshot: RepositoryDocumentSnapshot) throws {
        try self.init(projectID: projectID, rootID: rootID,
                      repositoryID: acceptedSnapshot.catalog.repositoryID.lowercased(),
                      acceptedCatalogVersion: acceptedSnapshot.version,
                      acceptedCatalogDigest: acceptedSnapshot.digest, acceptedCatalog: acceptedSnapshot.canonicalCatalog)
    }

    public init(projectID: ProjectID, rootID: ProjectRootID, repositoryID: String,
                acceptedCatalogVersion: Int, acceptedCatalogDigest: String, acceptedCatalog: Data) throws {
        self.projectID = projectID; self.rootID = rootID; self.repositoryID = repositoryID
        self.acceptedCatalogVersion = acceptedCatalogVersion; self.acceptedCatalogDigest = acceptedCatalogDigest
        self.acceptedCatalog = acceptedCatalog
        _ = try acceptedSnapshot()
    }

    public func acceptedSnapshot() throws -> RepositoryDocumentSnapshot {
        do {
            let snapshot = try RepositoryDocumentValidator().decodeCatalogSnapshot(acceptedCatalog)
            guard snapshot.canonicalCatalog == acceptedCatalog, snapshot.digest == acceptedCatalogDigest,
                  snapshot.version == acceptedCatalogVersion, snapshot.catalog.repositoryID == repositoryID,
                  !projectID.rawValue.isEmpty, !rootID.rawValue.isEmpty else {
                throw ProjectDocumentationBindingError.invalidAcceptedSnapshot
            }
            return snapshot
        } catch { throw ProjectDocumentationBindingError.invalidAcceptedSnapshot }
    }

    private enum CodingKeys: String, CodingKey {
        case projectID, rootID, repositoryID, acceptedCatalogVersion, acceptedCatalogDigest, acceptedCatalog
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(projectID: values.decode(ProjectID.self, forKey: .projectID),
                      rootID: values.decode(ProjectRootID.self, forKey: .rootID),
                      repositoryID: values.decode(String.self, forKey: .repositoryID),
                      acceptedCatalogVersion: values.decode(Int.self, forKey: .acceptedCatalogVersion),
                      acceptedCatalogDigest: values.decode(String.self, forKey: .acceptedCatalogDigest),
                      acceptedCatalog: values.decode(Data.self, forKey: .acceptedCatalog))
    }
}

import CryptoKit
import Foundation

public enum DocumentationOperationError: String, Error, Codable, Sendable {
    case invalidRequest, rootUnavailable, rootMismatch, staleRoot, bindingMissing, bindingConflict
    case bindingMismatch, catalogUnaccepted, catalogInvalid, guidanceUnavailable, managedCommandRequired
    case staleEvidence, evidenceConflict, unsafePath, missingFile, invalidTransition, inventoryTooLarge
}

public struct DocumentationTarget: Codable, Equatable, Sendable {
    public let projectID: String
    public let rootID: String
    public let repositoryID: String
    public let catalogVersion: Int
    public let catalogDigest: String
    public init(projectID: String, rootID: String, repositoryID: String, catalogVersion: Int, catalogDigest: String) {
        self.projectID = projectID; self.rootID = rootID; self.repositoryID = repositoryID
        self.catalogVersion = catalogVersion; self.catalogDigest = catalogDigest
    }
}

public struct DocumentationAdoption: Codable, Equatable, Sendable {
    public let evidenceID: String
    public let expectedPath: String
    public let expectedTicketID: String?
    public let artifactID: String
    public init(evidenceID: String, expectedPath: String, expectedTicketID: String?, artifactID: String) {
        self.evidenceID = evidenceID; self.expectedPath = expectedPath
        self.expectedTicketID = expectedTicketID; self.artifactID = artifactID
    }
    private enum CodingKeys: String, CodingKey { case evidenceID, expectedPath, expectedTicketID, artifactID }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // An omitted association is not permission to accept whichever association exists now.
        guard c.contains(.expectedTicketID) else {
            throw DecodingError.keyNotFound(CodingKeys.expectedTicketID, .init(codingPath: c.codingPath, debugDescription: "expectedTicketID is required, and may be null"))
        }
        evidenceID = try c.decode(String.self, forKey: .evidenceID)
        expectedPath = try c.decode(String.self, forKey: .expectedPath)
        expectedTicketID = try c.decodeIfPresent(String.self, forKey: .expectedTicketID)
        artifactID = try c.decode(String.self, forKey: .artifactID)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(evidenceID, forKey: .evidenceID); try c.encode(expectedPath, forKey: .expectedPath)
        try c.encode(expectedTicketID, forKey: .expectedTicketID); try c.encode(artifactID, forKey: .artifactID)
    }
}

public struct AgentQueryEnvelope: Codable, Equatable, Sendable {
    public let version: Int
    public let projectRoot: String
    public let query: AgentQuery
    public init(version: Int, projectRoot: String, query: AgentQuery) {
        self.version = version; self.projectRoot = projectRoot; self.query = query
    }
}
public enum AgentQuery: Codable, Equatable, Sendable {
    case inventoryEvidence(projectID: String?, rootID: String?)
}

public struct DocumentationBindingMetadata: Codable, Equatable, Sendable {
    public let projectID: String
    public let rootID: String
    public let repositoryID: String
    public let catalogVersion: Int
    public let catalogDigest: String
    init(_ binding: ProjectDocumentationBinding) {
        projectID = binding.projectID.rawValue; rootID = binding.rootID.rawValue; repositoryID = binding.repositoryID
        catalogVersion = binding.acceptedCatalogVersion; catalogDigest = binding.acceptedCatalogDigest
    }
}
public struct DocumentationCatalogObservation: Codable, Equatable, Sendable {
    public let guidance: RepositoryDocumentationMode
    public let repositoryID: String?
    public let version: Int?
    public let digest: String?
    public let error: DocumentationOperationError?
    public let validationError: RepositoryDocumentError.Code?
}
public struct EvidenceInventoryRow: Codable, Equatable, Sendable {
    public let evidence: LocatedEvidenceRecord
    public let phaseID: String?
    public let resolvedPath: String?
    public let resolvedAvailable: Bool
    public let lifecycle: RepositoryDocumentArtifact.Lifecycle?
    public let authority: RepositoryDocumentArtifact.Authority?
    public let candidateArtifactID: String?
    public let rejection: DocumentationOperationError?
}
public struct PreservationDigest: Codable, Equatable, Sendable {
    public let count: Int
    public let digest: String
}
public struct PreservationFingerprint: Codable, Equatable, Sendable {
    public let idHash: String
    public let digest: String
}
public struct DocumentationRootMetadata: Codable, Equatable, Sendable {
    public let rootID: String
    public let path: String
    public let bookmarkDigest: String?
    public let isStale: Bool?
}
public struct EvidenceInventory: Codable, Equatable, Sendable {
    public let projectID: String
    public let projectName: String
    public let rootID: String
    public let schemaVersion: Int
    public let binding: DocumentationBindingMetadata?
    public let catalog: DocumentationCatalogObservation
    public let evidence: [EvidenceInventoryRow]
    public let roots: [DocumentationRootMetadata]
    public let isComplete: Bool
    /// Fixed preservation domains, never caller-selected tables or exclusions.
    public let preservation: [String: PreservationDigest]
    public let audits: [PreservationFingerprint]
    public let receipts: [PreservationFingerprint]
}

/// The declaration is distinct from guidance prose validation (owned by M5).
/// Unknown, duplicate and malformed managed declarations always fail closed.
public enum RepositoryDocumentationMode: String, Codable, Sendable {
    case legacy, managedV2, unavailable
    public static func inspect(contents: String?) -> Self {
        guard let contents else { return .legacy }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let markers = lines.indices.filter { lines[$0].contains(RepositoryDocumentContract.guidanceMarkerName) }
        guard !markers.isEmpty else { return .legacy }
        guard markers.count == 2,
              lines[markers[1]] == RepositoryDocumentContract.guidanceEndMarker else { return .unavailable }
        let prefix = RepositoryDocumentContract.guidanceStartPrefix
        let suffix = RepositoryDocumentContract.guidanceStartSuffix
        switch lines[markers[0]] {
        case "\(prefix)1\(suffix)": return .legacy
        case "\(prefix)2\(suffix)": return .managedV2
        default: return .unavailable
        }
    }
    static func read(_ reader: RepositoryDocumentReader) throws -> Self {
        do {
            let data = try reader.read(RepositoryDocumentContract.guidancePath)
            guard let text = String(data: data, encoding: .utf8) else { return .unavailable }
            return inspect(contents: text)
        } catch let error as RepositoryDocumentError where error.code == .missingFile { return .legacy }
    }
}

extension AgentCommand {
    var documentationTarget: DocumentationTarget? {
        switch self {
        case let .bindDocumentationRepository(target), let .acceptDocumentationCatalog(target, _, _),
             let .addManagedEvidence(target, _, _, _), let .adoptManagedEvidence(target, _): target
        default: nil
        }
    }
    public var isDocumentationMutation: Bool {
        if documentationTarget != nil { return true }
        if case .relocateLegacyEvidence = self { return true }
        return false
    }
    var documentationIDs: [String] {
        switch self {
        case let .bindDocumentationRepository(t), let .acceptDocumentationCatalog(t, _, _): [t.projectID, t.rootID]
        case let .addManagedEvidence(_, id, _, _): [id]
        case let .adoptManagedEvidence(_, adoptions): adoptions.map(\.evidenceID)
        case let .relocateLegacyEvidence(_, _, id, _, _): [id]
        default: []
        }
    }
    var documentationAuditReason: String {
        switch self {
        case let .bindDocumentationRepository(t): "Bind documentation repository \(t.repositoryID) catalog \(t.catalogDigest)"
        case let .acceptDocumentationCatalog(t, _, prior): "Accept documentation catalog \(prior) to \(t.catalogDigest)"
        case let .addManagedEvidence(t, _, _, artifact): "Add managed evidence \(artifact) catalog \(t.catalogDigest)"
        case let .adoptManagedEvidence(t, adoptions): "Adopt \(adoptions.count) managed evidence records catalog \(t.catalogDigest)"
        case .relocateLegacyEvidence: "Relocate exact legacy evidence"
        default: "Documentation operation"
        }
    }
    func validateDocumentation() throws {
        func id(_ s: String, maximum: Int = 256) -> Bool {
            !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.utf8.count <= maximum
                && !s.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
        }
        func digest(_ s: String) -> Bool { s.utf8.count == 64 && s.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
        if let t = documentationTarget {
            guard id(t.projectID), id(t.rootID), UUID(uuidString: t.repositoryID) != nil,
                  t.repositoryID == t.repositoryID.lowercased(), t.catalogVersion == RepositoryDocumentContract.catalogVersion,
                  digest(t.catalogDigest) else { throw DocumentationOperationError.invalidRequest }
        }
        switch self {
        case .bindDocumentationRepository: break
        case let .acceptDocumentationCatalog(_, version, prior):
            guard version == RepositoryDocumentContract.catalogVersion, digest(prior) else { throw DocumentationOperationError.invalidRequest }
        case let .addManagedEvidence(_, value, ticket, artifact):
            guard id(value), ticket.map({ id($0) }) != false, id(artifact, maximum: 128) else { throw DocumentationOperationError.invalidRequest }
        case let .adoptManagedEvidence(_, adoptions):
            guard (1...128).contains(adoptions.count), Set(adoptions.map(\.evidenceID)).count == adoptions.count,
                  Set(adoptions.map(\.artifactID)).count == adoptions.count,
                  adoptions.allSatisfy({ id($0.evidenceID) && id($0.expectedPath, maximum: 4096) && id($0.artifactID, maximum: 128) && $0.expectedTicketID.map({ id($0) }) != false }) else { throw DocumentationOperationError.invalidRequest }
        case let .relocateLegacyEvidence(project, root, evidence, prior, next):
            guard id(project), id(root), id(evidence), id(prior, maximum: 4096), id(next, maximum: 4096) else { throw DocumentationOperationError.invalidRequest }
        default: throw DocumentationOperationError.invalidRequest
        }
    }
}

func documentationDigest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }

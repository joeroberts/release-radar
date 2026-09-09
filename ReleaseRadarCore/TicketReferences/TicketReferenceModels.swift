import Foundation

public enum TicketReferenceKind: String, Codable, Equatable, Sendable {
    case requirement
    case decision
}

public enum TicketReferenceRelationship: String, Codable, Equatable, Sendable {
    case current
    case retired
}

public enum TicketReferenceImpactFact: String, Codable, Equatable, Hashable, Sendable {
    case changed
    case moved
    case retired
    case superseded
    case archived
    case noLongerControlling
    case unavailable
    case unchecked
}

public struct TicketReferenceVersion: Codable, Equatable, Sendable, Identifiable {
    public var id: Int64 { version }
    public let version: Int64
    public let contentDigest: String
    public let sourceLocalID: String?
    public let locator: String?
    public let catalogVersion: Int
    public let catalogDigest: String
    public let observedPath: String
    public let observedLifecycle: RepositoryDocumentArtifact.Lifecycle
    public let observedAuthority: RepositoryDocumentArtifact.Authority
    public let createdAt: String
    public let resolution: TicketReferenceResolution
    public let historicalPreview: String?
    public let previewIsTruncated: Bool
}

public struct TicketReferenceResolution: Codable, Equatable, Sendable {
    public let facts: [TicketReferenceImpactFact]
    public let currentPath: String?
    public let currentDigest: String?
    public let currentLifecycle: RepositoryDocumentArtifact.Lifecycle?
    public let currentAuthority: RepositoryDocumentArtifact.Authority?
}

public struct TicketReference: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: TicketReferenceKind
    public let repositoryID: String
    public let artifactID: String
    public let currentVersion: Int64
    public let relationship: TicketReferenceRelationship
    public let retiredVersion: Int64?
    public let retiredAt: String?
    public let retirementReason: String?
    public let versions: [TicketReferenceVersion]
    public let resolution: TicketReferenceResolution
}

public struct TicketReferenceSet: Codable, Equatable, Sendable {
    public let projectID: String
    public let ticketID: String
    public let phaseID: String?
    public let phaseLabel: String
    public let linkSetRevision: Int64
    public let links: [TicketReference]
}

public struct RecordedImpact: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(ticketID):\(linkID):\(version)" }
    public let ticketID: String
    public let phaseID: String?
    public let phaseLabel: String
    public let linkID: String
    public let kind: TicketReferenceKind
    public let sourceLocalID: String?
    public let contentDigest: String
    public let version: Int64
    public let isCurrent: Bool
}

public struct RecordedImpacts: Codable, Equatable, Sendable {
    public let title: String
    public let projectID: String
    public let repositoryID: String
    public let artifactID: String
    public let rows: [RecordedImpact]
}

enum TicketReferenceMutationError: Error, Equatable, Sendable {
    case linkSetRevisionConflict(expected: Int64, current: Int64)
    case notFound
    case identityImmutable
    case ticketAccepted
    case sourceNotAuthoritative
}

extension AgentCommand {
    var isTicketReferenceMutation: Bool {
        switch self {
        case .upsertTicketReference, .retireTicketReference: true
        default: false
        }
    }

    var ticketReferenceProjectAndRoot: (projectID: String, rootID: String)? {
        switch self {
        case let .upsertTicketReference(target, _, _, _, _, _, _, _, _):
            (target.projectID, target.rootID)
        case let .retireTicketReference(projectID, rootID, _, _, _, _):
            (projectID, rootID)
        default:
            nil
        }
    }

    var ticketReferenceIDs: (ticketID: String, linkID: String)? {
        switch self {
        case let .upsertTicketReference(_, ticketID, linkID, _, _, _, _, _, _),
             let .retireTicketReference(_, _, ticketID, linkID, _, _):
            (ticketID, linkID)
        default:
            nil
        }
    }
}

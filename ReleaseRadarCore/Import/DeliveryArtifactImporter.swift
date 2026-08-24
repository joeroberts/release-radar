import Foundation

public protocol DeliveryArtifactImporter: Sendable {
    func canImport(_ folder: URL) -> Bool
    func preview(_ folder: URL) throws -> ImportPreview
    func apply(_ preview: ImportPreview, to project: ProjectID) async throws
}

public struct ImportPreview: Equatable, Sendable {
    public let sourceRoot: URL
    public let artifactURL: URL
    public let schemaVersion: Int
    public let activePhaseID: PhaseID?
    public let phases: [ImportPhase]
    public let phaseDependencies: [ImportPhaseDependency]
    public let tickets: [ImportTicket]
    public let ticketDependencies: [ImportTicketDependency]
    public let evidence: [ImportEvidence]
    public let reviewItems: [ImportReviewItem]

    public init(
        sourceRoot: URL,
        artifactURL: URL,
        schemaVersion: Int,
        activePhaseID: PhaseID?,
        phases: [ImportPhase],
        phaseDependencies: [ImportPhaseDependency],
        tickets: [ImportTicket],
        ticketDependencies: [ImportTicketDependency],
        evidence: [ImportEvidence],
        reviewItems: [ImportReviewItem]
    ) {
        self.sourceRoot = sourceRoot
        self.artifactURL = artifactURL
        self.schemaVersion = schemaVersion
        self.activePhaseID = activePhaseID
        self.phases = phases
        self.phaseDependencies = phaseDependencies
        self.tickets = tickets
        self.ticketDependencies = ticketDependencies
        self.evidence = evidence
        self.reviewItems = reviewItems
    }
}

public struct ImportPhase: Equatable, Sendable {
    public let id: PhaseID
    public let name: String

    public init(id: PhaseID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct ImportTicket: Equatable, Sendable {
    public let id: TicketID
    public let phaseID: PhaseID
    public let outcome: String
    public let lane: TicketLane

    public init(id: TicketID, phaseID: PhaseID, outcome: String, lane: TicketLane) {
        self.id = id
        self.phaseID = phaseID
        self.outcome = outcome
        self.lane = lane
    }
}

public struct ImportPhaseDependency: Equatable, Sendable {
    public let phaseID: PhaseID
    public let dependsOnPhaseID: PhaseID

    public init(phaseID: PhaseID, dependsOnPhaseID: PhaseID) {
        self.phaseID = phaseID
        self.dependsOnPhaseID = dependsOnPhaseID
    }
}

public struct ImportTicketDependency: Equatable, Sendable {
    public let ticketID: TicketID
    public let dependsOnTicketID: TicketID

    public init(ticketID: TicketID, dependsOnTicketID: TicketID) {
        self.ticketID = ticketID
        self.dependsOnTicketID = dependsOnTicketID
    }
}

public struct ImportEvidence: Equatable, Sendable {
    public let ticketID: TicketID?
    public let label: String
    public let path: String
    public let isAvailable: Bool

    public init(ticketID: TicketID?, label: String, path: String, isAvailable: Bool) {
        self.ticketID = ticketID
        self.label = label
        self.path = path
        self.isAvailable = isAvailable
    }
}

public enum ImportReviewKind: String, Equatable, Hashable, Sendable {
    case duplicate
    case missingOutcome = "missing_outcome"
    case unresolvedDependency = "unresolved_dependency"
    case conflict
    case unmappedStatus = "unmapped_status"
}

public struct ImportReviewItem: Equatable, Sendable {
    public let sourceID: String
    public let ticketID: TicketID?
    public let kind: ImportReviewKind
    public let summary: String

    public init(sourceID: String, ticketID: TicketID?, kind: ImportReviewKind, summary: String) {
        self.sourceID = sourceID
        self.ticketID = ticketID
        self.kind = kind
        self.summary = summary
    }

    static func conflict(sourceID: String, summary: String) -> Self {
        .init(sourceID: sourceID, ticketID: nil, kind: .conflict, summary: summary)
    }
}

public enum RekonImportError: Error, LocalizedError, Equatable, Sendable {
    case missingArtifact
    case unauthorizedFolder
    case unsupportedSchemaVersion(Int)
    case malformedArtifact
    case inputTooLarge
    case limitExceeded(String)
    case invalidPath(String)
    case targetProjectMismatch
    case projectNotFound

    public var errorDescription: String? {
        switch self {
        case .missingArtifact: "No recognized Rekon delivery artifact was found"
        case .unauthorizedFolder: "The folder is outside this project's authorized roots"
        case let .unsupportedSchemaVersion(version): "Unsupported Rekon delivery schema version \(version)"
        case .malformedArtifact: "The Rekon delivery artifact is malformed"
        case .inputTooLarge: "The Rekon delivery artifact exceeds the 1 MiB limit"
        case let .limitExceeded(message): message
        case let .invalidPath(path): "Evidence path is outside the authorized project: \(path)"
        case .targetProjectMismatch: "The import preview belongs to a different project"
        case .projectNotFound: "The target project or authorized root is not persisted"
        }
    }
}

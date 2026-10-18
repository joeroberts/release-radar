import Foundation

public enum RepositoryPlanAuthorityClass: String, Codable, Equatable, Sendable {
    case currentApproved = "current_approved"
    case historical
    case proposed
    case superseded
    case unscheduled
}

public enum RepositoryPlanSourceReference: Codable, Equatable, Sendable {
    case projection(pointer: String)
    case document(documentID: String, locator: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case pointer
        case documentID
        case locator
    }

    private enum Kind: String, Codable {
        case projection
        case document
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Kind.self, forKey: .kind) {
        case .projection:
            self = .projection(pointer: try values.decode(String.self, forKey: .pointer))
        case .document:
            self = .document(
                documentID: try values.decode(String.self, forKey: .documentID),
                locator: try values.decode(String.self, forKey: .locator)
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .projection(pointer):
            try values.encode(Kind.projection, forKey: .kind)
            try values.encode(pointer, forKey: .pointer)
        case let .document(documentID, locator):
            try values.encode(Kind.document, forKey: .kind)
            try values.encode(documentID, forKey: .documentID)
            try values.encode(locator, forKey: .locator)
        }
    }
}

public struct RepositoryPlanProjectionDocument: Codable, Equatable, Sendable {
    public let id: String
    public let artifactID: String
    public let contentSHA256: String

    public init(id: String, artifactID: String, contentSHA256: String) {
        self.id = id
        self.artifactID = artifactID
        self.contentSHA256 = contentSHA256
    }
}

public struct RepositoryPlanProjectionPhase: Codable, Equatable, Sendable {
    public let sourceID: String
    public let authorityClass: RepositoryPlanAuthorityClass
    public let sourceRefs: [RepositoryPlanSourceReference]
    public let name: String
    public let lifecycle: PhaseLifecycle
    public let stateEvidence: [RepositoryPlanSourceReference]

    public init(
        sourceID: String,
        authorityClass: RepositoryPlanAuthorityClass,
        sourceRefs: [RepositoryPlanSourceReference],
        name: String,
        lifecycle: PhaseLifecycle,
        stateEvidence: [RepositoryPlanSourceReference]
    ) {
        self.sourceID = sourceID
        self.authorityClass = authorityClass
        self.sourceRefs = sourceRefs
        self.name = name
        self.lifecycle = lifecycle
        self.stateEvidence = stateEvidence
    }
}

public struct RepositoryPlanProjectionTask: Codable, Equatable, Sendable {
    public let sourceID: String
    public let authorityClass: RepositoryPlanAuthorityClass
    public let sourceRefs: [RepositoryPlanSourceReference]
    public let label: String
    public let title: String
    public let sortOrder: Int
    public let completion: TicketTaskCompletion
    public let lifecycle: TicketTaskLifecycle
    public let stateEvidence: [RepositoryPlanSourceReference]

    public init(
        sourceID: String,
        authorityClass: RepositoryPlanAuthorityClass,
        sourceRefs: [RepositoryPlanSourceReference],
        label: String,
        title: String,
        sortOrder: Int,
        completion: TicketTaskCompletion,
        lifecycle: TicketTaskLifecycle,
        stateEvidence: [RepositoryPlanSourceReference]
    ) {
        self.sourceID = sourceID
        self.authorityClass = authorityClass
        self.sourceRefs = sourceRefs
        self.label = label
        self.title = title
        self.sortOrder = sortOrder
        self.completion = completion
        self.lifecycle = lifecycle
        self.stateEvidence = stateEvidence
    }
}

public struct RepositoryPlanProjectionTaskPlan: Codable, Equatable, Sendable {
    public let sourceRevision: Int
    public let tasks: [RepositoryPlanProjectionTask]

    public init(sourceRevision: Int, tasks: [RepositoryPlanProjectionTask]) {
        self.sourceRevision = sourceRevision
        self.tasks = tasks
    }
}

public struct RepositoryPlanProjectionTicket: Codable, Equatable, Sendable {
    public let sourceID: String
    public let authorityClass: RepositoryPlanAuthorityClass
    public let sourceRefs: [RepositoryPlanSourceReference]
    public let outcome: String
    public let phaseSourceID: String?
    public let lane: TicketLane?
    public let taskPlan: RepositoryPlanProjectionTaskPlan?
    public let stateEvidence: [RepositoryPlanSourceReference]
    public let evidenceRefs: [RepositoryPlanSourceReference]

    public init(
        sourceID: String,
        authorityClass: RepositoryPlanAuthorityClass,
        sourceRefs: [RepositoryPlanSourceReference],
        outcome: String,
        phaseSourceID: String?,
        lane: TicketLane?,
        taskPlan: RepositoryPlanProjectionTaskPlan?,
        stateEvidence: [RepositoryPlanSourceReference],
        evidenceRefs: [RepositoryPlanSourceReference]
    ) {
        self.sourceID = sourceID
        self.authorityClass = authorityClass
        self.sourceRefs = sourceRefs
        self.outcome = outcome
        self.phaseSourceID = phaseSourceID
        self.lane = lane
        self.taskPlan = taskPlan
        self.stateEvidence = stateEvidence
        self.evidenceRefs = evidenceRefs
    }

    private enum CodingKeys: String, CodingKey {
        case sourceID
        case authorityClass
        case sourceRefs
        case outcome
        case phaseSourceID
        case lane
        case taskPlan
        case stateEvidence
        case evidenceRefs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        for key in [CodingKeys.phaseSourceID, .lane, .taskPlan] where !values.contains(key) {
            throw DecodingError.keyNotFound(
                key,
                .init(codingPath: values.codingPath, debugDescription: "The nullable field \(key.stringValue) is required.")
            )
        }
        self.init(
            sourceID: try values.decode(String.self, forKey: .sourceID),
            authorityClass: try values.decode(RepositoryPlanAuthorityClass.self, forKey: .authorityClass),
            sourceRefs: try values.decode([RepositoryPlanSourceReference].self, forKey: .sourceRefs),
            outcome: try values.decode(String.self, forKey: .outcome),
            phaseSourceID: try values.decodeIfPresent(String.self, forKey: .phaseSourceID),
            lane: try values.decodeIfPresent(TicketLane.self, forKey: .lane),
            taskPlan: try values.decodeIfPresent(RepositoryPlanProjectionTaskPlan.self, forKey: .taskPlan),
            stateEvidence: try values.decode([RepositoryPlanSourceReference].self, forKey: .stateEvidence),
            evidenceRefs: try values.decode([RepositoryPlanSourceReference].self, forKey: .evidenceRefs)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(sourceID, forKey: .sourceID)
        try values.encode(authorityClass, forKey: .authorityClass)
        try values.encode(sourceRefs, forKey: .sourceRefs)
        try values.encode(outcome, forKey: .outcome)
        try values.encode(phaseSourceID, forKey: .phaseSourceID)
        try values.encode(lane, forKey: .lane)
        try values.encode(taskPlan, forKey: .taskPlan)
        try values.encode(stateEvidence, forKey: .stateEvidence)
        try values.encode(evidenceRefs, forKey: .evidenceRefs)
    }
}

public struct RepositoryPlanProjectionDependency: Codable, Equatable, Sendable {
    public let sourceID: String
    public let subjectSourceID: String
    public let dependsOnSourceID: String
    public let sourceRefs: [RepositoryPlanSourceReference]

    public init(
        sourceID: String,
        subjectSourceID: String,
        dependsOnSourceID: String,
        sourceRefs: [RepositoryPlanSourceReference]
    ) {
        self.sourceID = sourceID
        self.subjectSourceID = subjectSourceID
        self.dependsOnSourceID = dependsOnSourceID
        self.sourceRefs = sourceRefs
    }
}

public struct RepositoryPlanProjection: Codable, Equatable, Sendable {
    public let format: String
    public let schemaVersion: Int
    public let repositoryID: String
    public let projectionID: String
    public let projectionRevision: Int
    public let documents: [RepositoryPlanProjectionDocument]
    public let phases: [RepositoryPlanProjectionPhase]
    public let tickets: [RepositoryPlanProjectionTicket]
    public let phaseDependencies: [RepositoryPlanProjectionDependency]
    public let ticketDependencies: [RepositoryPlanProjectionDependency]

    public init(
        format: String,
        schemaVersion: Int,
        repositoryID: String,
        projectionID: String,
        projectionRevision: Int,
        documents: [RepositoryPlanProjectionDocument],
        phases: [RepositoryPlanProjectionPhase],
        tickets: [RepositoryPlanProjectionTicket],
        phaseDependencies: [RepositoryPlanProjectionDependency],
        ticketDependencies: [RepositoryPlanProjectionDependency]
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.repositoryID = repositoryID
        self.projectionID = projectionID
        self.projectionRevision = projectionRevision
        self.documents = documents
        self.phases = phases
        self.tickets = tickets
        self.phaseDependencies = phaseDependencies
        self.ticketDependencies = ticketDependencies
    }
}

public struct RepositoryPlanCapturedSource: Codable, Equatable, Sendable {
    public let artifactID: String
    public let path: String
    public let contentSHA256: String
    public let lifecycle: RepositoryDocumentArtifact.Lifecycle
    public let authority: RepositoryDocumentArtifact.Authority
    public let bytes: Data

    public init(
        artifactID: String,
        path: String,
        contentSHA256: String,
        lifecycle: RepositoryDocumentArtifact.Lifecycle,
        authority: RepositoryDocumentArtifact.Authority,
        bytes: Data
    ) {
        self.artifactID = artifactID
        self.path = path
        self.contentSHA256 = contentSHA256
        self.lifecycle = lifecycle
        self.authority = authority
        self.bytes = bytes
    }
}

public struct RepositoryPlanSourceManifest: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let rootID: String
    public let rootPath: String
    public let registration: ProjectRegistration
    public let repositoryID: String
    public let acceptedCatalogVersion: Int
    public let acceptedCatalogDigest: String
    public let sources: [RepositoryPlanCapturedSource]

    public init(
        projectID: ProjectID,
        rootID: String,
        rootPath: String,
        registration: ProjectRegistration,
        repositoryID: String,
        acceptedCatalogVersion: Int,
        acceptedCatalogDigest: String,
        sources: [RepositoryPlanCapturedSource]
    ) {
        self.projectID = projectID
        self.rootID = rootID
        self.rootPath = rootPath
        self.registration = registration
        self.repositoryID = repositoryID
        self.acceptedCatalogVersion = acceptedCatalogVersion
        self.acceptedCatalogDigest = acceptedCatalogDigest
        self.sources = sources
    }
}

public struct ValidatedRepositoryPlanProjection: Equatable, Sendable {
    public let projection: RepositoryPlanProjection
    public let bytes: Data
    public let contentSHA256: String
    public let sourceManifest: RepositoryPlanSourceManifest

    public init(
        projection: RepositoryPlanProjection,
        bytes: Data,
        contentSHA256: String,
        sourceManifest: RepositoryPlanSourceManifest
    ) {
        self.projection = projection
        self.bytes = bytes
        self.contentSHA256 = contentSHA256
        self.sourceManifest = sourceManifest
    }
}

public struct RepositoryPlanProjectionError: Error, LocalizedError, Equatable, Sendable {
    public enum Code: String, Codable, Equatable, Sendable {
        case invalidUTF8
        case malformedJSON
        case duplicateKey
        case unknownKey
        case missingRequiredField
        case unsupportedFormat
        case unsupportedVersion
        case invalidValue
        case limitExceeded
        case duplicateIdentity
        case sourceMismatch
        case invalidReference
        case invalidStateEvidence
        case invalidPlacement
        case dependencyCycle
    }

    public let code: Code
    public let fieldPath: String?
    public let limit: Int?
    public let actual: Int?

    public init(code: Code, fieldPath: String? = nil, limit: Int? = nil, actual: Int? = nil) {
        self.code = code
        self.fieldPath = fieldPath
        self.limit = limit
        self.actual = actual
    }

    public var errorDescription: String? {
        var message = "Repository plan projection validation failed (\(code.rawValue))"
        if let fieldPath { message += " at \(fieldPath)" }
        if let limit, let actual { message += ": limit \(limit), observed \(actual)" }
        return message + "."
    }
}

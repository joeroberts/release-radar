import Foundation

public struct AgentCommandEnvelope: Codable, Equatable, Sendable {
    public let version: Int
    public let requestID: UUID
    public let projectRoot: String
    public let assertedThreadID: String?
    public let reason: String
    public let command: AgentCommand

    public init(
        version: Int,
        requestID: UUID,
        projectRoot: String,
        assertedThreadID: String? = nil,
        reason: String,
        command: AgentCommand
    ) {
        self.version = version
        self.requestID = requestID
        self.projectRoot = projectRoot
        self.assertedThreadID = assertedThreadID
        self.reason = reason
        self.command = command
    }
}

public enum AgentCommand: Codable, Equatable, Sendable {
    case upsertPhase(phaseID: String, name: String)
    case upsertTicket(ticketID: String, phaseID: String, outcome: String, lane: TicketLane)
    case transitionTicket(ticketID: String, lane: TicketLane)
    case setDependency(id: String, kind: DependencyKind, subjectID: String, dependsOnID: String)
    case recordBlocker(id: String, ticketID: String, summary: String)
    case resolveBlocker(blockerID: String)
    case addEvidence(id: String, ticketID: String?, path: String)
    case linkThread(id: String, ticketID: String, threadID: String)
    case requestReview(id: String, ticketID: String?, kind: String, summary: String)
    case recordCompletion(id: String, ticketID: String, summary: String)
    case resolveImportReview(reviewItemID: String)
    case dismissImportReview(reviewItemID: String)
}

public enum DependencyKind: String, Codable, Equatable, Sendable {
    case phase
    case ticket
}

public enum AgentCommandError: Codable, Equatable, Sendable {
    case unsupportedVersion(found: Int, supported: Int)
    case invalidEnvelope(String)
    case unauthorizedProjectRoot
    case invalidReference(String)
    case crossProjectReference(String)
    case dependencyCycle(String)
    case requestIDReused
    case appUnavailable
    case internalFailure(String)
}

public struct AgentCommandResult: Codable, Equatable, Sendable {
    public let entityIDs: [String]
    public let auditEventID: AuditEventID?
    public let error: AgentCommandError?

    public init(entityIDs: [String], auditEventID: AuditEventID?, error: AgentCommandError?) {
        self.entityIDs = entityIDs
        self.auditEventID = auditEventID
        self.error = error
    }
}

public struct AuthorizedProject: Equatable, Sendable {
    public let projectID: ProjectID
    public let canonicalRoot: URL
    public let authorizedRoots: [URL]

    public init(projectID: ProjectID, canonicalRoot: URL, authorizedRoots: [URL]) {
        self.projectID = projectID
        self.canonicalRoot = Self.canonicalize(canonicalRoot)
        self.authorizedRoots = authorizedRoots.map(Self.canonicalize)
    }

    static func canonicalize(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}

public protocol AuthorizedProjectRegistry: Sendable {
    func resolve(projectRoot: String) -> AuthorizedProject?
}

public struct InMemoryAuthorizedProjectRegistry: AuthorizedProjectRegistry, Sendable {
    private let projects: [AuthorizedProject]

    public init(projects: [AuthorizedProject]) {
        self.projects = projects
    }

    public func resolve(projectRoot: String) -> AuthorizedProject? {
        let supplied = AuthorizedProject.canonicalize(URL(fileURLWithPath: projectRoot))
        return projects.first { project in
            project.authorizedRoots.contains(supplied)
        }
    }
}

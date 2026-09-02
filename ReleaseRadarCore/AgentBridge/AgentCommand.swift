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
    case applyPhasePlanRevision(projectID: String, phaseID: String, expectedRevision: Int64, goalUpserts: [DeliveryGoalDraft]? = nil, assignments: [DeliveryGoalAssignment]? = nil, unassignedTicketIDs: [TicketID]? = nil, supersededGoalIDs: [DeliveryGoalID]? = nil)
    case finalizePhasePlan(projectID: String, phaseID: String, expectedRevision: Int64)
    case transitionDeliveryGoal(projectID: String, phaseID: String, goalID: String, expectedPlanRevision: Int64, lifecycle: DeliveryGoalLifecycle)
    case bindDocumentationRepository(target: DocumentationTarget)
    case acceptDocumentationCatalog(target: DocumentationTarget, priorCatalogVersion: Int, priorCatalogDigest: String)
    case addManagedEvidence(target: DocumentationTarget, id: String, ticketID: String?, artifactID: String)
    case adoptManagedEvidence(target: DocumentationTarget, adoptions: [DocumentationAdoption])
    case relocateLegacyEvidence(projectID: String, rootID: String, evidenceID: String, expectedPath: String, newPath: String)
    case upsertPhase(phaseID: String, name: String)
    case upsertTicket(ticketID: String, phaseID: String, outcome: String, lane: TicketLane)
    case transitionTicket(ticketID: String, lane: TicketLane, ticketTaskPlanRevision: Int64? = nil)
    case reviseTicketTaskPlan(ticketID: String, expectedRevision: Int64? = nil, additions: [TicketTaskDraft]? = nil, definitionRevisions: [TicketTaskDefinitionRevision]? = nil, supersededTaskIDs: [TicketTaskID]? = nil)
    case completeTicketTask(ticketID: String, taskID: String, expectedRevision: Int64)
    case setActivePhase(phaseID: String)
    case setDependency(id: String, kind: DependencyKind, subjectID: String, dependsOnID: String)
    case recordBlocker(id: String, ticketID: String, summary: String)
    case resolveBlocker(blockerID: String)
    case addEvidence(id: String, ticketID: String?, path: String)
    case linkThread(id: String, ticketID: String, threadID: String)
    case linkGoal(id: String, ticketID: String, goalID: String)
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
    case documentation(DocumentationOperationError)
    case ticketTaskPlanNotFound
    case ticketTaskPlanAlreadyExists
    case ticketTaskPlanRevisionConflict(expected: Int64?, current: Int64)
    case ticketTaskNotFound(TicketTaskID)
    case ticketTaskImmutable(TicketTaskID)
    case ticketTaskIncomplete(pendingTaskIDs: [TicketTaskID])
    case ticketTaskReplacementRequired
    case invalidTicketTaskMutation(String)
    case phasePlanNotFound
    case planRevisionConflict(expected: Int64, current: Int64)
    case phasePlanNotReady
    case ticketGoalRequired(TicketID)
    case phasePlanIncomplete(PhasePlanReadinessFailure)
    case goalPhaseMismatch(DeliveryGoalID)
    case goalNotFound(DeliveryGoalID)
    case goalNotActionable(DeliveryGoalID)
    case invalidGoalTransition(from: DeliveryGoalLifecycle, to: DeliveryGoalLifecycle)
    case ownerAcceptanceRequired
    case goalAcceptanceEvidenceUnavailable([TicketID])
    case invalidPlanMutation(String)
    case outcomeUnknown
    case internalFailure(String)
}

public struct AgentCommandResult: Codable, Equatable, Sendable {
    public let entityIDs: [String]
    public let auditEventID: AuditEventID?
    public let error: AgentCommandError?
    public let inventory: EvidenceInventory?
    public let ticketTaskPlanRevision: Int64?
    public let phasePlanRevision: Int64?

    public init(entityIDs: [String], auditEventID: AuditEventID?, error: AgentCommandError?, inventory: EvidenceInventory? = nil, ticketTaskPlanRevision: Int64? = nil, phasePlanRevision: Int64? = nil) {
        self.entityIDs = entityIDs
        self.auditEventID = auditEventID
        self.error = error
        self.inventory = inventory
        self.ticketTaskPlanRevision = ticketTaskPlanRevision
        self.phasePlanRevision = phasePlanRevision
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
    func resolve(projectRoot: String) async -> AuthorizedProject?
}

public struct InMemoryAuthorizedProjectRegistry: AuthorizedProjectRegistry, Sendable {
    private let projects: [AuthorizedProject]

    public init(projects: [AuthorizedProject]) {
        self.projects = projects
    }

    public func resolve(projectRoot: String) async -> AuthorizedProject? {
        let supplied = AuthorizedProject.canonicalize(URL(fileURLWithPath: projectRoot))
        return projects.first { project in
            project.authorizedRoots.contains(supplied)
        }
    }
}

public struct PersistedAuthorizedProjectRegistry: AuthorizedProjectRegistry, Sendable {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func resolve(projectRoot: String) async -> AuthorizedProject? {
        let supplied = AuthorizedProject.canonicalize(URL(fileURLWithPath: projectRoot))
        return try? await store.read { connection in
            guard let projectID = try connection.scalarText(
                """
                SELECT project_roots.project_id
                FROM project_roots
                JOIN projects ON projects.id = project_roots.project_id
                WHERE project_roots.path = ?
                """,
                bindings: [.text(supplied.path)]
            ) else {
                return nil
            }

            var roots: [URL] = []
            var offset: Int64 = 0
            while let path = try connection.scalarText(
                "SELECT path FROM project_roots WHERE project_id = ? ORDER BY id LIMIT 1 OFFSET ?",
                bindings: [.text(projectID), .integer(offset)]
            ) {
                roots.append(AuthorizedProject.canonicalize(URL(fileURLWithPath: path)))
                offset += 1
            }
            guard roots.contains(supplied), let canonicalRoot = roots.first else {
                return nil
            }
            return AuthorizedProject(
                projectID: ProjectID(rawValue: projectID),
                canonicalRoot: canonicalRoot,
                authorizedRoots: roots
            )
        }
    }
}

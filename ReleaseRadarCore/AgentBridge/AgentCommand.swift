import Foundation

public struct AgentCommandEnvelope: Codable, Equatable, Sendable {
    public let version: Int
    public let requestID: UUID
    public let projectRoot: String
    public let assertedThreadID: String?
    public let expectedRegistration: ProjectRegistration?
    public let reason: String
    public let command: AgentCommand

    public init(
        version: Int,
        requestID: UUID,
        projectRoot: String,
        assertedThreadID: String? = nil,
        expectedRegistration: ProjectRegistration? = nil,
        reason: String,
        command: AgentCommand
    ) {
        self.version = version
        self.requestID = requestID
        self.projectRoot = projectRoot
        self.assertedThreadID = assertedThreadID
        self.expectedRegistration = expectedRegistration
        self.reason = reason
        self.command = command
    }
}

public enum AgentCommand: Codable, Equatable, Sendable {
    case transitionPhaseLifecycle(
        projectID: String,
        phaseID: String,
        expectedRevision: Int64,
        action: PhaseLifecycleAction,
        planningBaselineDigest: String?
    )
    case savePlanChangeProposal(proposalID: String, expectedPreviousVersion: Int64?, rationale: String, operations: [PlanChangeOperation])
    case decidePlanChangeProposal(
        proposalID: String,
        version: Int64,
        baselineDigest: String,
        decisionID: String,
        disposition: PlanChangeDecisionDisposition
    )
    case applyPlanChangeProposal(
        proposalID: String,
        version: Int64,
        baselineDigest: String,
        decisionID: String,
        applicationID: String
    )
    case applyPhasePlanRevision(projectID: String, phaseID: String, expectedRevision: Int64, goalUpserts: [DeliveryGoalDraft]? = nil, assignments: [DeliveryGoalAssignment]? = nil, unassignedTicketIDs: [TicketID]? = nil, supersededGoalIDs: [DeliveryGoalID]? = nil)
    case finalizePhasePlan(projectID: String, phaseID: String, expectedRevision: Int64)
    case transitionDeliveryGoal(projectID: String, phaseID: String, goalID: String, expectedPlanRevision: Int64, lifecycle: DeliveryGoalLifecycle)
    case bindDocumentationRepository(target: DocumentationTarget)
    case acceptDocumentationCatalog(target: DocumentationTarget, priorCatalogVersion: Int, priorCatalogDigest: String)
    case addManagedEvidence(target: DocumentationTarget, id: String, ticketID: String?, artifactID: String)
    case adoptManagedEvidence(target: DocumentationTarget, adoptions: [DocumentationAdoption])
    case relocateLegacyEvidence(projectID: String, rootID: String, evidenceID: String, expectedPath: String, newPath: String)
    case upsertTicketReference(target: DocumentationTarget, ticketID: String, linkID: String, kind: TicketReferenceKind, artifactID: String, sourceLocalID: String?, locator: String?, expectedContentDigest: String, expectedLinkSetRevision: Int64)
    case retireTicketReference(projectID: String, rootID: String, ticketID: String, linkID: String, version: Int64, expectedLinkSetRevision: Int64)
    case recordDeliveryEvidenceTarget(
        target: DocumentationTarget,
        ticketID: String,
        revision: DeliveryEvidenceRevision,
        expectations: [DeliveryEvidenceExpectation],
        expectedEvidenceRevision: Int64
    )
    case appendDeliveryEvidenceObservation(
        target: DocumentationTarget,
        ticketID: String,
        observation: DeliveryEvidenceObservation,
        expectedEvidenceRevision: Int64
    )
    case upsertPhase(phaseID: String, name: String)
    case upsertUnassignedTicket(ticketID: String, outcome: String)
    case placeUnassignedTicket(ticketID: String, phaseID: String, expectedPlanRevision: Int64)
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
    case staleProjectRegistration
    case phaseLifecycleOwnerAuthorityRequired
    case phaseLifecycleNotFound(PhaseID)
    case phaseLifecycleRevisionConflict(expected: Int64, current: Int64)
    case invalidPhaseLifecycleTransition(from: PhaseLifecycle, action: PhaseLifecycleAction)
    case phaseLifecyclePlanningBaselineRequired
    case phaseLifecyclePlanningBaselineConflict
    case phaseCompletionBlocked([PhaseCompletionBlocker])
    case completedPhaseReadOnly(PhaseID)
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
    case ticketReferenceLinkSetRevisionConflict(expected: Int64, current: Int64)
    case ticketReferenceNotFound
    case ticketReferenceIdentityImmutable
    case ticketReferenceTicketAccepted
    case ticketReferenceSourceNotAuthoritative
    case deliveryEvidenceRevisionConflict(expected: Int64, current: Int64)
    case deliveryEvidenceNotFound
    case deliveryEvidenceTicketAccepted
    case invalidDeliveryEvidence(String)
    case planChangeProposalRegistrationRequired
    case planChangeProposalNotFound
    case planChangeProposalVersionConflict(expected: Int64?, current: Int64?)
    case invalidPlanChangeOperation(String)
    case planChangeProposalOwnerAuthorityRequired
    case planChangeProposalDecisionConflict
    case planChangeProposalDecisionNotApproved
    case planChangeProposalDecisionMismatch
    case planChangeProposalAlreadyApplied
    case planChangeProposalStale([PlanChangeBaselineCategory])
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
    public let ticketReferenceLinkSetRevision: Int64?
    public let ticketReferences: TicketReferenceSet?
    public let recordedImpacts: RecordedImpacts?
    public let deliveryEvidenceRevision: Int64?
    public let deliveryEvidence: TicketDeliveryEvidence?
    public let planChangeProposalVersion: Int64?
    public let planChangeProposalDecisionID: String?
    public let planChangeProposalApplicationID: String?
    public let planChangeProposals: [PlanChangeProposalRecord]?
    public let phaseLifecycle: PhaseLifecycleRecord?
    public let phaseLifecycles: [PhaseLifecycleRecord]?
    public let phaseLifecycleEvents: [PhaseLifecycleEventRecord]?
    public let phaseCompletionAssessments: [PhaseCompletionAssessment]?

    public init(entityIDs: [String], auditEventID: AuditEventID?, error: AgentCommandError?, inventory: EvidenceInventory? = nil, ticketTaskPlanRevision: Int64? = nil, phasePlanRevision: Int64? = nil, ticketReferenceLinkSetRevision: Int64? = nil, ticketReferences: TicketReferenceSet? = nil, recordedImpacts: RecordedImpacts? = nil, deliveryEvidenceRevision: Int64? = nil, deliveryEvidence: TicketDeliveryEvidence? = nil, planChangeProposalVersion: Int64? = nil, planChangeProposalDecisionID: String? = nil, planChangeProposalApplicationID: String? = nil, planChangeProposals: [PlanChangeProposalRecord]? = nil, phaseLifecycle: PhaseLifecycleRecord? = nil, phaseLifecycles: [PhaseLifecycleRecord]? = nil, phaseLifecycleEvents: [PhaseLifecycleEventRecord]? = nil, phaseCompletionAssessments: [PhaseCompletionAssessment]? = nil) {
        self.entityIDs = entityIDs
        self.auditEventID = auditEventID
        self.error = error
        self.inventory = inventory
        self.ticketTaskPlanRevision = ticketTaskPlanRevision
        self.phasePlanRevision = phasePlanRevision
        self.ticketReferenceLinkSetRevision = ticketReferenceLinkSetRevision
        self.ticketReferences = ticketReferences
        self.recordedImpacts = recordedImpacts
        self.deliveryEvidenceRevision = deliveryEvidenceRevision
        self.deliveryEvidence = deliveryEvidence
        self.planChangeProposalVersion = planChangeProposalVersion
        self.planChangeProposalDecisionID = planChangeProposalDecisionID
        self.planChangeProposalApplicationID = planChangeProposalApplicationID
        self.planChangeProposals = planChangeProposals
        self.phaseLifecycle = phaseLifecycle
        self.phaseLifecycles = phaseLifecycles
        self.phaseLifecycleEvents = phaseLifecycleEvents
        self.phaseCompletionAssessments = phaseCompletionAssessments
    }
}

public struct AuthorizedProject: Equatable, Sendable {
    public let projectID: ProjectID
    public let registration: ProjectRegistration?
    public let canonicalRoot: URL
    public let authorizedRoots: [URL]

    public init(registration: ProjectRegistration, canonicalRoot: URL, authorizedRoots: [URL]) {
        self.projectID = registration.projectID
        self.registration = registration
        self.canonicalRoot = Self.canonicalize(canonicalRoot)
        self.authorizedRoots = authorizedRoots.map(Self.canonicalize)
    }

    /// Compatibility for read-only/import previews and unregistered legacy fixtures.
    /// Registered projects require the registration-bearing initializer for mutation.
    public init(projectID: ProjectID, canonicalRoot: URL, authorizedRoots: [URL]) {
        self.projectID = projectID
        self.registration = nil
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
            project.authorizedRoots.contains { $0.path == supplied.path }
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
            guard let row = try connection.row(
                """
                SELECT project_roots.project_id, project_registrations.registration_id,
                       project_registrations.request_generation
                FROM project_roots
                JOIN projects ON projects.id = project_roots.project_id
                LEFT JOIN project_registrations ON project_registrations.project_id = projects.id
                WHERE project_roots.path = ?
                  AND projects.lifecycle = 'active'
                """,
                bindings: [.text(supplied.path)]
            ), case let .text(projectID)? = row["project_id"] else {
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
            if case let .text(registrationID)? = row["registration_id"],
               case let .integer(requestGeneration)? = row["request_generation"] {
                return AuthorizedProject(
                    registration: ProjectRegistration(
                        projectID: ProjectID(rawValue: projectID),
                        registrationID: registrationID,
                        requestGeneration: requestGeneration
                    ),
                    canonicalRoot: canonicalRoot,
                    authorizedRoots: roots
                )
            }
            return AuthorizedProject(
                projectID: ProjectID(rawValue: projectID),
                canonicalRoot: canonicalRoot,
                authorizedRoots: roots
            )
        }
    }
}

extension AgentCommand {
    var requiresPhaseLifecycleOwnerAuthority: Bool {
        if case .transitionPhaseLifecycle = self { return true }
        return false
    }

    var isPlanChangeProposalCommand: Bool {
        switch self {
        case .savePlanChangeProposal, .decidePlanChangeProposal, .applyPlanChangeProposal:
            true
        default:
            false
        }
    }

    var requiresPlanChangeOwnerAuthority: Bool {
        switch self {
        case .decidePlanChangeProposal, .applyPlanChangeProposal:
            true
        default:
            false
        }
    }
}

import Foundation
import OSLog
import ReleaseRadarCore

enum DashboardCardPresentation: Equatable, Sendable {
    case fullOutcome
    case compactID
}
enum DashboardLayout {
    static func presentation(forLaneWidth width: CGFloat) -> DashboardCardPresentation {
        width > 180 ? .fullOutcome : .compactID
    }

    static func sidebarWidth(isCompact: Bool) -> CGFloat {
        isCompact ? 96 : 220
    }
}

struct DashboardProjection: Equatable, Sendable {
    let projects: [ProjectDashboardProjection]
    let archivedProjects: [ArchivedProjectProjection]
    let removedProjects: [RemovedProjectRecord]
    let boards: [PhaseBoardKey: PhaseBoardProjection]
    let projectPlans: [ProjectID: ProjectPlanProjection]
    let allPhaseBoards: [ProjectID: AllPhaseBoardProjection]
    let workspaceGoals: WorkspaceGoalsProjection

    init(
        projects: [ProjectDashboardProjection],
        archivedProjects: [ArchivedProjectProjection] = [],
        removedProjects: [RemovedProjectRecord] = [],
        boards: [PhaseBoardKey: PhaseBoardProjection],
        projectPlans: [ProjectID: ProjectPlanProjection] = [:],
        allPhaseBoards: [ProjectID: AllPhaseBoardProjection] = [:],
        workspaceGoals: WorkspaceGoalsProjection = .empty
    ) {
        self.projects = projects
        self.archivedProjects = archivedProjects
        self.removedProjects = removedProjects
        self.boards = boards
        self.projectPlans = projectPlans
        self.allPhaseBoards = allPhaseBoards
        self.workspaceGoals = workspaceGoals
    }

    func board(for projectID: ProjectID) -> PhaseBoardProjection? {
        guard let phaseID = projects.first(where: { $0.id.rawValue.utf8.elementsEqual(projectID.rawValue.utf8) })?.activePhaseID else { return nil }
        return board(for: projectID, phaseID: phaseID)
    }

    func board(for projectID: ProjectID, phaseID: PhaseID) -> PhaseBoardProjection? {
        boards[PhaseBoardKey(projectID: projectID, phaseID: phaseID)]
    }

    func plan(for projectID: ProjectID) -> ProjectPlanProjection? { projectPlans[projectID] }
    func allPhaseBoard(for projectID: ProjectID) -> AllPhaseBoardProjection? { allPhaseBoards[projectID] }

    static func load(
        from store: DeliveryStore,
        bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore(),
        taskRows: TicketTaskPlanProjection.RowQuery = TicketTaskPlanProjection.queryRows,
        evidenceReadbacks suppliedReadbacks: [ProjectID: [EvidenceReadback]]? = nil
    ) async throws -> DashboardProjection {
        let projectIDs = try await store.read { c in
            try c.dashboardRows("SELECT id FROM projects WHERE lifecycle = 'active' ORDER BY id").map { ProjectID(rawValue: try $0.text("id")) }
        }
        var readbacks = suppliedReadbacks ?? [:]
        if suppliedReadbacks == nil {
            for projectID in projectIDs {
                readbacks[projectID] = try await store.evidenceReadback(projectID: projectID, bookmarkStore: bookmarkStore)
            }
        }
        let evidenceByProject = readbacks
        return try await store.read { connection in
            let projectRows = try connection.dashboardRows(
                """
                SELECT projects.id, projects.name, project_active_phases.phase_id AS active_phase_id,
                       project_registrations.registration_id,
                       project_registrations.request_generation
                FROM projects
                LEFT JOIN project_active_phases ON project_active_phases.project_id = projects.id
                LEFT JOIN project_registrations ON project_registrations.project_id = projects.id
                WHERE projects.lifecycle = 'active'
                  AND NOT EXISTS (
                    SELECT 1
                    FROM review_items
                    WHERE review_items.project_id = projects.id
                      AND review_items.kind = ?
                      AND review_items.status = 'open'
                )
                ORDER BY projects.name
                """,
                bindings: [.text(OnboardingReviewMarkerKind.pending.rawValue)]
            )
            var projects: [ProjectDashboardProjection] = []
            var boards: [PhaseBoardKey: PhaseBoardProjection] = [:]
            var projectPlans: [ProjectID: ProjectPlanProjection] = [:]
            var allPhaseBoards: [ProjectID: AllPhaseBoardProjection] = [:]
            let archivedProjects = try connection.dashboardRows(
                """
                SELECT projects.id, projects.name, project_registrations.registration_id,
                       project_registrations.request_generation,
                       (SELECT COUNT(*) FROM phases WHERE phases.project_id = projects.id) AS phase_count,
                       (SELECT COUNT(*) FROM tickets WHERE tickets.project_id = projects.id) AS ticket_count,
                       (SELECT COUNT(*) FROM evidence WHERE evidence.project_id = projects.id) AS evidence_count,
                       (SELECT COUNT(*) FROM audit_events WHERE audit_events.project_id = projects.id) AS history_count
                FROM projects
                JOIN project_registrations ON project_registrations.project_id = projects.id
                WHERE projects.lifecycle = 'archived'
                ORDER BY projects.name COLLATE NOCASE, projects.id
                """
            ).map { row in
                let id = ProjectID(rawValue: try row.text("id"))
                return ArchivedProjectProjection(
                    id: id,
                    name: try row.text("name"),
                    registration: .init(
                        projectID: id,
                        registrationID: try row.text("registration_id"),
                        requestGeneration: try row.integer("request_generation")
                    ),
                    counts: .init(
                        phases: try row.integer("phase_count"),
                        tickets: try row.integer("ticket_count"),
                        evidence: try row.integer("evidence_count"),
                        history: try row.integer("history_count")
                    )
                )
            }
            let removedProjects = try connection.dashboardRows(
                "SELECT * FROM removed_projects ORDER BY removed_at DESC, project_name COLLATE NOCASE, removal_id"
            ).map { row in
                let projectID = ProjectID(rawValue: try row.text("historical_project_id"))
                guard let lifecycle = ProjectLifecycle(rawValue: try row.text("original_lifecycle")),
                      let removedAt = ISO8601DateFormatter().date(from: try row.text("removed_at")) else {
                    throw DashboardProjectionError.invalidRemovedProject
                }
                return RemovedProjectRecord(
                    id: .init(rawValue: try row.text("removal_id")), projectID: projectID,
                    projectName: try row.text("project_name"), originalLifecycle: lifecycle,
                    registration: .init(
                        projectID: projectID, registrationID: try row.text("registration_id"),
                        requestGeneration: try row.integer("request_generation")
                    ),
                    removedAt: removedAt,
                    counts: .init(
                        phases: try row.integer("phase_count"), tickets: try row.integer("ticket_count"),
                        evidence: try row.integer("evidence_count"), history: try row.integer("history_count")
                    )
                )
            }

            for projectRow in projectRows {
                let projectID = ProjectID(rawValue: try projectRow.text("id"))
                let projectName = try projectRow.text("name")
                let registration = try projectRow.nullableText("registration_id").map {
                    ProjectRegistration(
                        projectID: projectID,
                        registrationID: $0,
                        requestGeneration: try projectRow.integer("request_generation")
                    )
                }
                let goalContext = try connection.projectGoalContext(projectID: projectID)
                let phases = try connection.dashboardRows(
                    "SELECT id, name FROM phases WHERE project_id = ? ORDER BY name COLLATE NOCASE, id",
                    bindings: [.text(projectID.rawValue)]
                ).map {
                    ProjectPhaseProjection(
                        id: PhaseID(rawValue: try $0.text("id")),
                        name: try $0.text("name")
                    )
                }
                let activePhaseID = try projectRow.nullableText("active_phase_id").map(PhaseID.init(rawValue:))
                let activePhase = phases.first { phase in
                    activePhaseID.map { phase.id.rawValue.utf8.elementsEqual($0.rawValue.utf8) } == true
                }
                let activeLanes = try connection.dashboardRows(
                    "SELECT lane FROM tickets WHERE project_id = ? AND phase_id = ? AND NOT EXISTS (SELECT 1 FROM ticket_retirements WHERE ticket_retirements.project_id=tickets.project_id AND ticket_retirements.ticket_id=tickets.id)",
                    bindings: [.text(projectID.rawValue), activePhase.map { .text($0.id.rawValue) } ?? .null]
                ).map { try $0.text("lane") }
                let project = ProjectDashboardProjection(
                    id: projectID, name: projectName, registration: registration,
                    activePhaseID: activePhase?.id, activePhaseName: activePhase?.name ?? "No active phase",
                    phases: phases, goalContext: goalContext,
                    currentWorkCount: activeLanes.filter { $0 != TicketLane.accepted.rawValue }.count,
                    attentionCount: activeLanes.filter { $0 == TicketLane.needsReview.rawValue || $0 == TicketLane.blocked.rawValue }.count,
                    evidence: (evidenceByProject[projectID] ?? []).filter { $0.evidence.ticketID == nil }.map(EvidenceProjection.init)
                )
                projects.append(project)

                for phase in phases {
                    let phaseID = phase.id
                    let ticketRows = try connection.dashboardRows(
                        "SELECT id, outcome, lane, plan_legacy_continuation FROM tickets WHERE project_id = ? AND phase_id = ? AND NOT EXISTS (SELECT 1 FROM ticket_retirements WHERE ticket_retirements.project_id=tickets.project_id AND ticket_retirements.ticket_id=tickets.id) ORDER BY rowid",
                        bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
                    )
                    guard let plan = try DeliveryPlanningPolicy.loadPlan(projectID: projectID, phaseID: phaseID, connection: connection) else {
                        throw DeliveryPlanningPolicyError.phasePlanNotFound
                    }
                    let lifecycle = try PhaseLifecyclePolicy.current(
                        projectID: projectID, phaseID: phaseID, connection: connection)
                    let completionAssessment = try PhaseLifecyclePolicy.assessCompletion(
                        projectID: projectID, phaseID: phaseID, connection: connection)
                    let assignments = try DeliveryPlanningPolicy.loadAssignments(projectID: projectID, phaseID: phaseID, connection: connection)
                    let retiredTicketIDs = Set(try connection.dashboardRows(
                        "SELECT ticket_id FROM ticket_retirements WHERE project_id=?",
                        bindings: [.text(projectID.rawValue)]
                    ).map { Data((try $0.text("ticket_id")).utf8) })
                    let goals = try DeliveryPlanningPolicy.loadGoals(projectID: projectID, phaseID: phaseID, connection: connection).map { goal in
                        DeliveryGoalSummaryProjection(
                            goalID: goal.id, title: goal.title, outcome: goal.outcome, lifecycle: goal.lifecycle,
                            doneCriteria: try DeliveryPlanningPolicy.loadCriteria(projectID: projectID, phaseID: phaseID, goalID: goal.id, connection: connection).map(\.text),
                            ticketIDs: assignments.filter {
                                $0.goalID.rawValue.utf8.elementsEqual(goal.id.rawValue.utf8)
                                    && !retiredTicketIDs.contains(Data($0.ticketID.rawValue.utf8))
                            }.map(\.ticketID),
                            coverage: try DeliveryGoalCoveragePolicy.assess(
                                projectID: projectID, phaseID: phaseID, goalID: goal.id, connection: connection
                            )
                        )
                    }
                    let goalsByID = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
                    let goalsByTicket = Dictionary(uniqueKeysWithValues: assignments.compactMap { assignment -> (TicketID, TicketDeliveryGoalProjection)? in
                        guard let goal = goalsByID[Data(assignment.goalID.rawValue.utf8)], goal.lifecycle != .superseded else { return nil }
                        return (assignment.ticketID, TicketDeliveryGoalProjection(goalID: goal.goalID, title: goal.title, outcome: goal.outcome,
                            lifecycle: goal.lifecycle, doneCriteria: goal.doneCriteria))
                    })
                    let upcomingIDs = try ticketRows.filter { try $0.text("lane") != TicketLane.accepted.rawValue }
                        .map { TicketID(rawValue: try $0.text("id")) }
                    let coveredCount = upcomingIDs.filter { goalsByTicket[$0] != nil }.count
                    let phasePlan = PhasePlanProjection(state: plan.state, revision: plan.revision, readyRevision: plan.readyRevision,
                        upcomingCount: upcomingIDs.count, coveredUpcomingCount: coveredCount,
                        unassignedUpcomingCount: upcomingIDs.count - coveredCount)
                    let taskPlans = TicketTaskPlanProjection.load(
                        connection, projectID: projectID, phaseID: phaseID,
                        ticketIDs: try ticketRows.map { TicketID(rawValue: try $0.text("id")) },
                        query: taskRows
                    )
                    var cardsByLane = Dictionary(uniqueKeysWithValues: TicketLane.allCases.map { ($0, [TicketCardProjection]()) })
                    var details: [TicketID: TicketDetailProjection] = [:]

                    for ticketRow in ticketRows {
                        let ticketID = TicketID(rawValue: try ticketRow.text("id"))
                        guard let lane = TicketLane(rawValue: try ticketRow.text("lane")) else {
                            throw DashboardProjectionError.invalidLane(try ticketRow.text("lane"))
                        }
                        let outcome = try ticketRow.text("outcome")
                        let dependencyCount = Int(try connection.scalarInt(
                            "SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = ? AND ticket_id = ?",
                            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                        ) ?? 0)
                        let blockerCount = Int(try connection.scalarInt(
                            "SELECT COUNT(*) FROM blockers WHERE project_id = ? AND ticket_id = ? AND resolved_at IS NULL",
                            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                        ) ?? 0)
                        let card = TicketCardProjection(
                            id: ticketID,
                            outcome: outcome,
                            dependencyCount: dependencyCount,
                            blockerCount: blockerCount,
                            taskPlan: taskPlans[ticketID] ?? .unavailable(recovery: .init()),
                            deliveryGoal: goalsByTicket[ticketID],
                            phaseID: phaseID,
                            phaseName: phase.name
                        )
                        cardsByLane[lane, default: []].append(card)
                        details[ticketID] = try connection.ticketDetail(
                            projectID: projectID,
                            ticketID: ticketID,
                            outcome: outcome,
                            taskPlan: card.taskPlan,
                            deliveryGoal: card.deliveryGoal,
                            isLegacyContinuation: try ticketRow.integer("plan_legacy_continuation") != 0 && (lane == .inProgress || lane == .needsReview),
                            evidence: (evidenceByProject[projectID] ?? []).filter { $0.evidence.ticketID == ticketID }.map(EvidenceProjection.init)
                        )
                    }

                    let lanes = TicketLane.allCases.map {
                        DashboardLaneProjection(lane: $0, cards: cardsByLane[$0] ?? [])
                    }
                    boards[PhaseBoardKey(projectID: projectID, phaseID: phaseID)] = PhaseBoardProjection(
                        project: project,
                        phaseID: phaseID,
                        phaseName: phase.name,
                        phasePlan: phasePlan,
                        phaseLifecycle: lifecycle,
                        completionAssessment: completionAssessment,
                        deliveryGoals: goals,
                        lanes: lanes,
                        details: details
                    )
                }

                let phasePlans = phases.compactMap { phase -> ProjectPlanPhaseProjection? in
                    guard let board = boards[PhaseBoardKey(projectID: projectID, phaseID: phase.id)] else { return nil }
                    return ProjectPlanPhaseProjection(
                        id: phase.id, name: phase.name, readiness: board.phasePlan,
                        lifecycle: board.phaseLifecycle!,
                        completionAssessment: board.completionAssessment!,
                        deliveryGoals: board.deliveryGoals,
                        ticketCount: board.lanes.reduce(0) { $0 + $1.count }
                    )
                }
                let unassignedRows = try connection.dashboardRows(
                    "SELECT id, outcome FROM tickets WHERE project_id = ? AND phase_id IS NULL AND lane IS NULL AND NOT EXISTS (SELECT 1 FROM ticket_retirements WHERE ticket_retirements.project_id=tickets.project_id AND ticket_retirements.ticket_id=tickets.id) ORDER BY id COLLATE BINARY",
                    bindings: [.text(projectID.rawValue)]
                )
                let unassignedIDs = try unassignedRows.map { TicketID(rawValue: try $0.text("id")) }
                let unassignedTaskPlans = TicketTaskPlanProjection.loadUnassigned(
                    connection, projectID: projectID, ticketIDs: unassignedIDs
                )
                var unassignedCards: [TicketCardProjection] = []
                var unassignedDetails: [TicketID: TicketDetailProjection] = [:]
                for row in unassignedRows {
                    let ticketID = TicketID(rawValue: try row.text("id"))
                    let outcome = try row.text("outcome")
                    let dependencyCount = Int(try connection.scalarInt(
                        "SELECT COUNT(*) FROM ticket_dependencies WHERE project_id=? AND ticket_id=?",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                    ) ?? 0)
                    let blockerCount = Int(try connection.scalarInt(
                        "SELECT COUNT(*) FROM blockers WHERE project_id=? AND ticket_id=? AND resolved_at IS NULL",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                    ) ?? 0)
                    let taskPlan = unassignedTaskPlans[ticketID] ?? .unavailable(recovery: .init())
                    unassignedCards.append(.init(
                        id: ticketID, outcome: outcome, dependencyCount: dependencyCount,
                        blockerCount: blockerCount, taskPlan: taskPlan
                    ))
                    unassignedDetails[ticketID] = try connection.ticketDetail(
                        projectID: projectID, ticketID: ticketID, outcome: outcome,
                        taskPlan: taskPlan, deliveryGoal: nil, isLegacyContinuation: false,
                        evidence: (evidenceByProject[projectID] ?? []).filter { $0.evidence.ticketID == ticketID }.map(EvidenceProjection.init)
                    )
                }
                let retiredRows = try connection.dashboardRows(
                    """
                    SELECT retirements.ticket_id,tickets.outcome,retirements.disposition,
                           retirements.reason,retirements.last_phase_id,retirements.last_lane
                    FROM ticket_retirements retirements
                    JOIN tickets ON tickets.project_id=retirements.project_id AND tickets.id=retirements.ticket_id
                    WHERE retirements.project_id=? ORDER BY retirements.retired_at DESC,retirements.ticket_id
                    """,
                    bindings: [.text(projectID.rawValue)]
                )
                let retiredTickets = try retiredRows.map { row in
                    guard let disposition = TicketRetirementDisposition(
                        rawValue: try row.text("disposition")
                    ) else {
                        throw DashboardProjectionError.invalidRetirementDisposition
                    }
                    return RetiredTicketProjection(
                        id: .init(rawValue: try row.text("ticket_id")), outcome: try row.text("outcome"),
                        disposition: disposition,
                        reason: try row.text("reason"),
                        lastPhaseID: try row.nullableText("last_phase_id").map(PhaseID.init(rawValue:)),
                        lastLane: try row.nullableText("last_lane").flatMap(TicketLane.init(rawValue:)),
                        successorTicketIDs: try connection.dashboardRows(
                            "SELECT successor_ticket_id FROM ticket_successor_links WHERE project_id=? AND original_ticket_id=? ORDER BY sort_order,successor_ticket_id",
                            bindings: [.text(projectID.rawValue), .text(try row.text("ticket_id"))]
                        ).map { TicketID(rawValue: try $0.text("successor_ticket_id")) }
                    )
                }
                var retiredDetails: [TicketID: TicketDetailProjection] = [:]
                for row in retiredRows {
                    let ticketID = TicketID(rawValue: try row.text("ticket_id"))
                    let outcome = try row.text("outcome")
                    let phaseID = try row.nullableText("last_phase_id").map(PhaseID.init(rawValue:))
                    let taskPlan: TicketTaskPlanProjection
                    if let phaseID {
                        taskPlan = TicketTaskPlanProjection.load(
                            connection, projectID: projectID, phaseID: phaseID,
                            ticketIDs: [ticketID], query: taskRows
                        )[ticketID] ?? .unavailable(recovery: .init())
                    } else {
                        taskPlan = TicketTaskPlanProjection.loadUnassigned(
                            connection, projectID: projectID, ticketIDs: [ticketID]
                        )[ticketID] ?? .unavailable(recovery: .init())
                    }
                    let goalRow = try connection.dashboardRows(
                        """
                        SELECT goals.phase_id,goals.id,goals.title,goals.outcome,goals.lifecycle
                        FROM delivery_goal_ticket_assignments assignments
                        JOIN delivery_goals goals
                          ON goals.project_id=assignments.project_id
                         AND goals.phase_id=assignments.phase_id AND goals.id=assignments.goal_id
                        WHERE assignments.project_id=? AND assignments.ticket_id=?
                        """,
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                    ).first
                    let deliveryGoal: TicketDeliveryGoalProjection? = try goalRow.map { goal in
                        guard let lifecycle = DeliveryGoalLifecycle(rawValue: try goal.text("lifecycle")) else {
                            throw DashboardProjectionError.invalidColumn("lifecycle")
                        }
                        return TicketDeliveryGoalProjection(
                            goalID: .init(rawValue: try goal.text("id")), title: try goal.text("title"),
                            outcome: try goal.text("outcome"), lifecycle: lifecycle,
                            doneCriteria: try DeliveryPlanningPolicy.loadCriteria(
                                projectID: projectID,
                                phaseID: .init(rawValue: try goal.text("phase_id")),
                                goalID: .init(rawValue: try goal.text("id")), connection: connection
                            ).map(\.text)
                        )
                    }
                    retiredDetails[ticketID] = try connection.ticketDetail(
                        projectID: projectID, ticketID: ticketID, outcome: outcome,
                        taskPlan: taskPlan, deliveryGoal: deliveryGoal, isLegacyContinuation: false,
                        evidence: (evidenceByProject[projectID] ?? []).filter { $0.evidence.ticketID == ticketID }.map(EvidenceProjection.init)
                    )
                }
                projectPlans[projectID] = ProjectPlanProjection(
                    project: project, phases: phasePlans, unassignedTickets: unassignedCards,
                    unassignedDetails: unassignedDetails,
                    proposals: try PlanChangeProposalQuery.load(from: connection, projectID: projectID),
                    retiredTickets: retiredTickets, retiredDetails: retiredDetails
                )
                let projectBoards = phases.compactMap { boards[PhaseBoardKey(projectID: projectID, phaseID: $0.id)] }
                let allLanes = TicketLane.allCases.map { lane in
                    DashboardLaneProjection(lane: lane, cards: projectBoards.flatMap { $0.lane(lane)?.cards ?? [] })
                }
                allPhaseBoards[projectID] = AllPhaseBoardProjection(
                    project: project,
                    deliveryGoals: projectBoards.flatMap(\.deliveryGoals),
                    lanes: allLanes,
                    details: projectBoards.reduce(into: [:]) { result, board in
                        result.merge(board.details) { first, _ in first }
                    }
                )
            }

            let workspaceGoals = try WorkspaceGoalsProjection.load(
                connection: connection, projects: projects, boards: boards, projectPlans: projectPlans
            )
            for project in projects {
                guard var board = allPhaseBoards[project.id] else { continue }
                board.executionGoalLinks = workspaceGoals.execution.compactMap { goal in
                    guard goal.project.id.rawValue.utf8.elementsEqual(project.id.rawValue.utf8) else { return nil }
                    return goal.boardFilter
                }
                allPhaseBoards[project.id] = board
            }
            return DashboardProjection(
                projects: projects, archivedProjects: archivedProjects,
                removedProjects: removedProjects, boards: boards,
                projectPlans: projectPlans, allPhaseBoards: allPhaseBoards,
                workspaceGoals: workspaceGoals
            )
        }
    }

    func replacingDocumentation(
        for projectID: ProjectID,
        with readbacks: [EvidenceReadback]
    ) -> DashboardProjection {
        let projectEvidence = readbacks.filter { $0.evidence.ticketID == nil }.map(EvidenceProjection.init)
        let projects = projects.map { project in
            guard project.id == projectID else { return project }
            return ProjectDashboardProjection(
                id: project.id,
                name: project.name,
                registration: project.registration,
                activePhaseID: project.activePhaseID,
                activePhaseName: project.activePhaseName,
                phases: project.phases,
                goalContext: project.goalContext,
                currentWorkCount: project.currentWorkCount,
                attentionCount: project.attentionCount,
                evidence: projectEvidence
            )
        }
        let project = projects.first { $0.id == projectID }
        let boards = boards.mapValues { board in
            guard board.project.id == projectID, let project else { return board }
            let details = board.details.mapValues { detail in
                TicketDetailProjection(
                    id: detail.id,
                    outcome: detail.outcome,
                    goalContext: detail.goalContext,
                    requires: detail.requires,
                    unlocks: detail.unlocks,
                    ownerAttention: detail.ownerAttention,
                    evidence: readbacks.filter { $0.evidence.ticketID == detail.id }.map(EvidenceProjection.init),
                    auditHistory: detail.auditHistory,
                    notificationHistory: detail.notificationHistory,
                    taskPlan: detail.taskPlan,
                    deliveryGoal: detail.deliveryGoal,
                    isLegacyContinuation: detail.isLegacyContinuation
                )
            }
            return PhaseBoardProjection(
                project: project,
                phaseID: board.phaseID,
                phaseName: board.phaseName,
                phasePlan: board.phasePlan,
                phaseLifecycle: board.phaseLifecycle,
                completionAssessment: board.completionAssessment,
                deliveryGoals: board.deliveryGoals,
                lanes: board.lanes,
                details: details
            )
        }
        let projectPlans = projectPlans.mapValues { plan in
            guard plan.project.id == projectID, let project else { return plan }
            let details = plan.unassignedDetails.mapValues { detail in
                detail.replacingEvidence(readbacks.filter { $0.evidence.ticketID == detail.id }.map(EvidenceProjection.init))
            }
            let retiredDetails = plan.retiredDetails.mapValues { detail in
                detail.replacingEvidence(readbacks.filter { $0.evidence.ticketID == detail.id }.map(EvidenceProjection.init))
            }
            return ProjectPlanProjection(project: project, phases: plan.phases,
                                         unassignedTickets: plan.unassignedTickets, unassignedDetails: details,
                                         proposals: plan.proposals, retiredTickets: plan.retiredTickets,
                                         retiredDetails: retiredDetails)
        }
        let allPhaseBoards = allPhaseBoards.mapValues { board in
            guard board.project.id == projectID, let project else { return board }
            let details = board.details.mapValues { detail in
                detail.replacingEvidence(readbacks.filter { $0.evidence.ticketID == detail.id }.map(EvidenceProjection.init))
            }
            return AllPhaseBoardProjection(project: project, deliveryGoals: board.deliveryGoals,
                                           lanes: board.lanes, details: details)
        }
        return .init(
            projects: projects,
            archivedProjects: archivedProjects,
            removedProjects: removedProjects,
            boards: boards, projectPlans: projectPlans, allPhaseBoards: allPhaseBoards,
            workspaceGoals: workspaceGoals
        )
    }
}

struct ArchivedProjectProjection: Equatable, Sendable, Identifiable {
    let id: ProjectID
    let name: String
    let registration: ProjectRegistration
    let counts: ProjectLifecycleCounts
}

struct ProjectPhaseProjection: Equatable, Sendable, Identifiable {
    let id: PhaseID
    let name: String
}

struct ProjectDashboardProjection: Equatable, Sendable, Identifiable {
    let id: ProjectID
    let name: String
    let registration: ProjectRegistration?
    let activePhaseID: PhaseID?
    let activePhaseName: String
    let phases: [ProjectPhaseProjection]
    let goalContext: GoalContextProjection
    let currentWorkCount: Int
    let attentionCount: Int
    let evidence: [EvidenceProjection]

    init(
        id: ProjectID,
        name: String,
        registration: ProjectRegistration? = nil,
        activePhaseID: PhaseID? = nil,
        activePhaseName: String,
        phases: [ProjectPhaseProjection] = [],
        goalContext: GoalContextProjection,
        currentWorkCount: Int,
        attentionCount: Int,
        evidence: [EvidenceProjection] = []
    ) {
        self.id = id
        self.name = name
        self.registration = registration
        self.activePhaseID = activePhaseID
        self.activePhaseName = activePhaseName
        self.phases = phases
        self.goalContext = goalContext
        self.currentWorkCount = currentWorkCount
        self.attentionCount = attentionCount
        self.evidence = evidence
    }
}

struct ProjectPlanPhaseProjection: Equatable, Sendable, Identifiable {
    let id: PhaseID
    let name: String
    let readiness: PhasePlanProjection
    let lifecycle: PhaseLifecycleRecord
    let completionAssessment: PhaseCompletionAssessment
    let deliveryGoals: [DeliveryGoalSummaryProjection]
    let ticketCount: Int
}

struct ProjectPlanProjection: Equatable, Sendable {
    let project: ProjectDashboardProjection
    let phases: [ProjectPlanPhaseProjection]
    let unassignedTickets: [TicketCardProjection]
    let unassignedDetails: [TicketID: TicketDetailProjection]
    let proposals: [PlanChangeProposalRecord]
    let retiredTickets: [RetiredTicketProjection]
    let retiredDetails: [TicketID: TicketDetailProjection]

    init(
        project: ProjectDashboardProjection,
        phases: [ProjectPlanPhaseProjection],
        unassignedTickets: [TicketCardProjection],
        unassignedDetails: [TicketID: TicketDetailProjection],
        proposals: [PlanChangeProposalRecord] = [],
        retiredTickets: [RetiredTicketProjection] = [],
        retiredDetails: [TicketID: TicketDetailProjection] = [:]
    ) {
        self.project = project
        self.phases = phases
        self.unassignedTickets = unassignedTickets
        self.unassignedDetails = unassignedDetails
        self.proposals = proposals
        self.retiredTickets = retiredTickets
        self.retiredDetails = retiredDetails
    }

    var recordedTicketCount: Int {
        phases.reduce(0) { $0 + $1.ticketCount } + unassignedTickets.count + retiredTickets.count
    }
    func detail(for ticketID: TicketID) -> TicketDetailProjection? {
        unassignedDetails[ticketID] ?? retiredDetails[ticketID]
    }
}

struct RetiredTicketProjection: Equatable, Sendable, Identifiable {
    let id: TicketID
    let outcome: String
    let disposition: TicketRetirementDisposition
    let reason: String
    let lastPhaseID: PhaseID?
    let lastLane: TicketLane?
    let successorTicketIDs: [TicketID]
}

struct PhaseBoardKey: Hashable, Sendable {
    let projectID: ProjectID
    let phaseID: PhaseID

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.projectID.rawValue.utf8.elementsEqual(rhs.projectID.rawValue.utf8)
            && lhs.phaseID.rawValue.utf8.elementsEqual(rhs.phaseID.rawValue.utf8)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(Data(projectID.rawValue.utf8))
        hasher.combine(Data(phaseID.rawValue.utf8))
    }
}

struct PhasePlanProjection: Equatable, Sendable {
    let state: PhasePlanState
    let revision: Int64
    let readyRevision: Int64?
    let upcomingCount: Int
    let coveredUpcomingCount: Int
    let unassignedUpcomingCount: Int

    var isDeliveryComplete: Bool {
        state == .ready && readyRevision == revision && upcomingCount == 0 && unassignedUpcomingCount == 0
    }
}

struct DeliveryGoalSummaryProjection: Equatable, Sendable, Identifiable {
    let goalID: DeliveryGoalID
    let title: String
    let outcome: String
    let lifecycle: DeliveryGoalLifecycle
    let doneCriteria: [String]
    let ticketIDs: [TicketID]
    let coverage: DeliveryGoalCoverageAssessment?

    init(
        goalID: DeliveryGoalID, title: String, outcome: String,
        lifecycle: DeliveryGoalLifecycle, doneCriteria: [String], ticketIDs: [TicketID],
        coverage: DeliveryGoalCoverageAssessment? = nil
    ) {
        self.goalID = goalID
        self.title = title
        self.outcome = outcome
        self.lifecycle = lifecycle
        self.doneCriteria = doneCriteria
        self.ticketIDs = ticketIDs
        self.coverage = coverage
    }

    // SQLite uses BINARY identity; Swift String equality normalizes Unicode.
    var id: Data { Data(goalID.rawValue.utf8) }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.outcome == rhs.outcome
            && lhs.lifecycle == rhs.lifecycle && lhs.doneCriteria == rhs.doneCriteria
            && lhs.ticketIDs == rhs.ticketIDs && lhs.coverage == rhs.coverage
    }
}

struct TicketDeliveryGoalProjection: Equatable, Sendable, Identifiable {
    let goalID: DeliveryGoalID
    let title: String
    let outcome: String
    let lifecycle: DeliveryGoalLifecycle
    let doneCriteria: [String]

    var id: Data { Data(goalID.rawValue.utf8) }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.outcome == rhs.outcome
            && lhs.lifecycle == rhs.lifecycle && lhs.doneCriteria == rhs.doneCriteria
    }
}

struct ExecutionGoalBoardFilter: Hashable, Sendable {
    let threadID: String
    let goalID: String
    let ticketID: TicketID

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.threadID.utf8.elementsEqual(rhs.threadID.utf8)
            && lhs.goalID.utf8.elementsEqual(rhs.goalID.utf8)
            && lhs.ticketID.rawValue.utf8.elementsEqual(rhs.ticketID.rawValue.utf8)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(Data(threadID.utf8))
        hasher.combine(Data(goalID.utf8))
        hasher.combine(Data(ticketID.rawValue.utf8))
    }
}

enum DeliveryGoalFilter: Hashable, Sendable {
    case all
    case goal(DeliveryGoalID)
    case execution(ExecutionGoalBoardFilter)
    case unassigned

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.unassigned, .unassigned): true
        case let (.goal(a), .goal(b)): a.rawValue.utf8.elementsEqual(b.rawValue.utf8)
        case let (.execution(a), .execution(b)): a == b
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .all: hasher.combine(0)
        case let .goal(id): hasher.combine(1); hasher.combine(Data(id.rawValue.utf8))
        case let .execution(identity): hasher.combine(2); hasher.combine(identity)
        case .unassigned: hasher.combine(3)
        }
    }
}

struct PhaseBoardProjection: Equatable, Sendable {
    let project: ProjectDashboardProjection
    let phaseID: PhaseID
    let phaseName: String
    let phasePlan: PhasePlanProjection
    let phaseLifecycle: PhaseLifecycleRecord?
    let completionAssessment: PhaseCompletionAssessment?
    let deliveryGoals: [DeliveryGoalSummaryProjection]
    let lanes: [DashboardLaneProjection]
    let details: [TicketID: TicketDetailProjection]

    static func == (lhs: Self, rhs: Self) -> Bool {
        PhaseBoardKey(projectID: lhs.project.id, phaseID: lhs.phaseID) == PhaseBoardKey(projectID: rhs.project.id, phaseID: rhs.phaseID)
            && lhs.project == rhs.project && lhs.phaseName == rhs.phaseName && lhs.phasePlan == rhs.phasePlan
            && lhs.phaseLifecycle == rhs.phaseLifecycle && lhs.completionAssessment == rhs.completionAssessment
            && lhs.deliveryGoals == rhs.deliveryGoals && lhs.lanes == rhs.lanes && lhs.details == rhs.details
    }

    var isActivePhase: Bool {
        project.activePhaseID.map { phaseID.rawValue.utf8.elementsEqual($0.rawValue.utf8) } == true
    }
    var filterableDeliveryGoals: [DeliveryGoalSummaryProjection] {
        deliveryGoals.filter { $0.lifecycle != .superseded }
    }

    func filtered(by filter: DeliveryGoalFilter) -> PhaseBoardProjection {
        let filteredLanes = lanes.map { lane in
            DashboardLaneProjection(lane: lane.lane, cards: lane.cards.filter { card in
                switch filter {
                case .all: true
                case let .goal(id): card.deliveryGoal?.id == Data(id.rawValue.utf8)
                case .execution: false
                case .unassigned: lane.lane != .accepted && card.deliveryGoal == nil
                }
            })
        }
        let visibleIDs = Set(filteredLanes.flatMap { $0.cards.map(\.id) })
        return PhaseBoardProjection(project: project, phaseID: phaseID, phaseName: phaseName,
            phasePlan: phasePlan, phaseLifecycle: phaseLifecycle,
            completionAssessment: completionAssessment, deliveryGoals: deliveryGoals, lanes: filteredLanes,
            details: details.filter { visibleIDs.contains($0.key) })
    }

    func lane(_ lane: TicketLane) -> DashboardLaneProjection? {
        lanes.first { $0.lane == lane }
    }

    func detail(for ticketID: TicketID) -> TicketDetailProjection? {
        details[ticketID]
    }
}

struct DashboardLaneProjection: Equatable, Sendable, Identifiable {
    let lane: TicketLane
    let cards: [TicketCardProjection]

    var id: TicketLane { lane }
    var count: Int { cards.count }
}

struct AllPhaseBoardProjection: Equatable, Sendable {
    let project: ProjectDashboardProjection
    let deliveryGoals: [DeliveryGoalSummaryProjection]
    let lanes: [DashboardLaneProjection]
    let details: [TicketID: TicketDetailProjection]
    var executionGoalLinks: [ExecutionGoalBoardFilter] = []

    func lane(_ lane: TicketLane) -> DashboardLaneProjection? { lanes.first { $0.lane == lane } }
    func detail(for ticketID: TicketID) -> TicketDetailProjection? { details[ticketID] }
    var filterableDeliveryGoals: [DeliveryGoalSummaryProjection] {
        deliveryGoals.filter { $0.lifecycle != .superseded }
    }

    func hasExactExecutionGoalLink(_ identity: ExecutionGoalBoardFilter) -> Bool {
        executionGoalLinks.contains(identity)
    }

    func filtered(by filter: DeliveryGoalFilter) -> AllPhaseBoardProjection {
        let filteredLanes = lanes.map { lane in
            DashboardLaneProjection(lane: lane.lane, cards: lane.cards.filter { card in
                switch filter {
                case .all: true
                case let .goal(id): card.deliveryGoal?.id == Data(id.rawValue.utf8)
                case let .execution(identity):
                    hasExactExecutionGoalLink(identity)
                        && card.id.rawValue.utf8.elementsEqual(identity.ticketID.rawValue.utf8)
                case .unassigned: card.deliveryGoal == nil
                }
            })
        }
        let visibleIDs = Set(filteredLanes.flatMap { $0.cards.map(\.id) })
        return .init(project: project, deliveryGoals: deliveryGoals, lanes: filteredLanes,
                     details: details.filter { visibleIDs.contains($0.key) })
    }
}

struct TicketCardProjection: Equatable, Sendable, Identifiable {
    let id: TicketID
    let outcome: String
    let dependencyCount: Int
    let blockerCount: Int
    var taskPlan: TicketTaskPlanProjection = .noPlan
    var deliveryGoal: TicketDeliveryGoalProjection? = nil
    var phaseID: PhaseID? = nil
    var phaseName: String? = nil

    var activeTaskCount: Int? {
        guard case let .loaded(plan) = taskPlan else { return nil }
        return plan.tasks.count
    }

    var taskCountAnnouncement: String? {
        activeTaskCount.map { "\($0) \($0 == 1 ? "task" : "tasks")" }
    }
}

struct TicketDetailProjection: Equatable, Sendable {
    let id: TicketID
    let outcome: String
    let goalContext: GoalContextProjection
    let requires: [TicketReferenceProjection]
    let unlocks: [TicketReferenceProjection]
    let ownerAttention: [String]
    let evidence: [EvidenceProjection]
    let auditHistory: [String]
    let notificationHistory: [String]
    var taskPlan: TicketTaskPlanProjection = .noPlan
    var deliveryGoal: TicketDeliveryGoalProjection? = nil
    var isLegacyContinuation = false

    var codexExecutionGoal: GoalContextProjection { goalContext }

    func replacingEvidence(_ evidence: [EvidenceProjection]) -> TicketDetailProjection {
        .init(id: id, outcome: outcome, goalContext: goalContext, requires: requires, unlocks: unlocks,
              ownerAttention: ownerAttention, evidence: evidence, auditHistory: auditHistory,
              notificationHistory: notificationHistory, taskPlan: taskPlan,
              deliveryGoal: deliveryGoal, isLegacyContinuation: isLegacyContinuation)
    }
}

enum GoalLinkQuality: String, Equatable, Sendable {
    case verified = "Verified link"
    case unavailable = "No linked goal"
}

struct GoalContextProjection: Equatable, Sendable {
    let linkQuality: GoalLinkQuality
    let text: String?
    let status: String?
    let lastObservedAt: Date?
}

struct TicketReferenceProjection: Equatable, Sendable, Identifiable {
    let id: TicketID
    let outcome: String
}

struct EvidenceProjection: Equatable, Sendable, Identifiable {
    let id: EvidenceID
    let label: String
    let path: String
    let isAvailable: Bool
    let locator: EvidenceLocator
    let managedDocument: ResolvedManagedDocument?

    init(id: EvidenceID, label: String, path: String, isAvailable: Bool) {
        self.id = id; self.label = label; self.path = path; self.isAvailable = isAvailable
        locator = .filePath(path); managedDocument = nil
    }
    init(_ readback: EvidenceReadback) {
        id = readback.evidence.id; locator = readback.evidence.locator
        managedDocument = readback.managedDocument
        switch locator {
        case let .filePath(value):
            path = value; label = URL(fileURLWithPath: value).lastPathComponent
            isAvailable = readback.evidence.isAvailable
        case let .managedDocument(id):
            path = readback.managedDocument?.resolvedPath ?? ""
            label = readback.managedDocument?.label ?? id
            isAvailable = readback.managedDocument?.isAvailable == true
        }
    }
}

enum DashboardProjectionError: Error, Equatable {
    case missingColumn(String)
    case invalidColumn(String)
    case invalidLane(String)
    case invalidRetirementDisposition
    case invalidRemovedProject
}

extension TicketLane {
    var dashboardTitle: String {
        switch self {
        case .backlog: "Backlog"
        case .inProgress: "In progress"
        case .needsReview: "Needs review"
        case .blocked: "Blocked"
        case .accepted: "Accepted"
        }
    }
}

private extension SQLiteConnection {
    func dashboardRows(_ sql: String, bindings: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row("\(sql) LIMIT 1 OFFSET ?", bindings: bindings + [.integer(offset)]) {
            rows.append(row)
            offset += 1
        }
        return rows
    }

    func ticketDetail(
        projectID: ProjectID,
        ticketID: TicketID,
        outcome: String,
        taskPlan: TicketTaskPlanProjection,
        deliveryGoal: TicketDeliveryGoalProjection?,
        isLegacyContinuation: Bool,
        evidence: [EvidenceProjection]
    ) throws -> TicketDetailProjection {
        let requires = try dashboardRows(
            """
            SELECT tickets.id, tickets.outcome
            FROM ticket_dependencies
            JOIN tickets ON tickets.id = ticket_dependencies.depends_on_ticket_id
            WHERE ticket_dependencies.project_id = ? AND ticket_dependencies.ticket_id = ?
            ORDER BY ticket_dependencies.rowid
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map {
            TicketReferenceProjection(
                id: TicketID(rawValue: try $0.text("id")),
                outcome: try $0.text("outcome")
            )
        }
        let unlocks = try dashboardRows(
            """
            SELECT tickets.id, tickets.outcome
            FROM ticket_dependencies
            JOIN tickets ON tickets.id = ticket_dependencies.ticket_id
            WHERE ticket_dependencies.project_id = ? AND ticket_dependencies.depends_on_ticket_id = ?
            ORDER BY ticket_dependencies.rowid
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map {
            TicketReferenceProjection(
                id: TicketID(rawValue: try $0.text("id")),
                outcome: try $0.text("outcome")
            )
        }
        let ownerAttention = try dashboardRows(
            "SELECT summary FROM blockers WHERE project_id = ? AND ticket_id = ? AND resolved_at IS NULL ORDER BY rowid",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map { try $0.text("summary") }
        let auditHistory = try dashboardRows(
            """
            SELECT reason FROM audit_events
            WHERE project_id = ? AND (
                (entity_type IN ('ticket', 'ticket_task_plan') AND entity_id = ?)
                OR (entity_type = 'blocker' AND entity_id IN (
                    SELECT id FROM blockers WHERE project_id = audit_events.project_id AND ticket_id = ?
                ))
                OR (entity_type = 'evidence' AND entity_id IN (
                    SELECT id FROM evidence WHERE project_id = audit_events.project_id AND ticket_id = ?
                ))
                OR (entity_type = 'review_item' AND entity_id IN (
                    SELECT id FROM review_items WHERE project_id = audit_events.project_id AND ticket_id = ?
                ))
                OR (entity_type = 'completion' AND entity_id IN (
                    SELECT id FROM completion_records WHERE project_id = audit_events.project_id AND ticket_id = ?
                ))
                OR (entity_type = 'ticket_dependency' AND entity_id IN (
                    SELECT id FROM ticket_dependencies WHERE project_id = audit_events.project_id
                      AND (ticket_id = ? OR depends_on_ticket_id = ?)
                ))
                OR (entity_type = 'thread_link' AND entity_id IN (
                    SELECT id FROM thread_links WHERE project_id = audit_events.project_id AND ticket_id = ?
                ))
                OR EXISTS (
                    SELECT 1 FROM delivery_goal_assignment_events AS assignment
                    WHERE assignment.project_id = audit_events.project_id
                      AND assignment.audit_event_id = audit_events.id AND assignment.ticket_id = ?
                )
            ) ORDER BY created_at DESC, id
            """,
            bindings: [.text(projectID.rawValue)] + Array(repeating: .text(ticketID.rawValue), count: 9)
        ).map { try $0.text("reason") }
        let notificationHistory = try dashboardRows(
            "SELECT fingerprint, state FROM notification_events WHERE ticket_id = ? ORDER BY rowid",
            bindings: [.text(ticketID.rawValue)]
        ).map { "\(try $0.text("fingerprint")) · \(try $0.text("state"))" }

        let goalRow = try row(
            """
            SELECT observed_goals.text, observed_goals.status, observed_goals.last_observed_at
            FROM ticket_goal_links
            JOIN observed_goals
              ON observed_goals.project_id = ticket_goal_links.project_id
             AND observed_goals.id = ticket_goal_links.goal_id
             AND observed_goals.thread_id = ticket_goal_links.thread_id
            WHERE ticket_goal_links.project_id = ? AND ticket_goal_links.ticket_id = ?
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        )
        let goalContext: GoalContextProjection
        if let goalRow {
            goalContext = GoalContextProjection(
                linkQuality: .verified,
                text: try goalRow.text("text"),
                status: try goalRow.text("status"),
                lastObservedAt: ISO8601DateFormatter().date(from: try goalRow.text("last_observed_at"))
            )
        } else {
            goalContext = GoalContextProjection(
                linkQuality: .unavailable,
                text: nil,
                status: nil,
                lastObservedAt: nil
            )
        }

        return TicketDetailProjection(
            id: ticketID,
            outcome: outcome,
            goalContext: goalContext,
            requires: requires,
            unlocks: unlocks,
            ownerAttention: ownerAttention,
            evidence: evidence,
            auditHistory: auditHistory,
            notificationHistory: notificationHistory,
            taskPlan: taskPlan,
            deliveryGoal: deliveryGoal,
            isLegacyContinuation: isLegacyContinuation
        )
    }

    func projectGoalContext(projectID: ProjectID) throws -> GoalContextProjection {
        guard let goalRow = try row(
            """
            SELECT text, status, last_observed_at
            FROM observed_goals
            WHERE project_id = ?
            ORDER BY last_observed_at DESC, rowid DESC LIMIT 1
            """,
            bindings: [.text(projectID.rawValue)]
        ) else {
            return GoalContextProjection(
                linkQuality: .unavailable,
                text: nil,
                status: nil,
                lastObservedAt: nil
            )
        }

        return GoalContextProjection(
            linkQuality: .verified,
            text: try goalRow.text("text"),
            status: try goalRow.text("status"),
            lastObservedAt: ISO8601DateFormatter().date(from: try goalRow.text("last_observed_at"))
        )
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func nullableText(_ column: String) throws -> String? {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        if case .null = value { return nil }
        guard case let .text(text) = value else { throw DashboardProjectionError.invalidColumn(column) }
        return text
    }

    func text(_ column: String) throws -> String {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw DashboardProjectionError.invalidColumn(column) }
        return text
    }

    func integer(_ column: String) throws -> Int64 {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        guard case let .integer(integer) = value else { throw DashboardProjectionError.invalidColumn(column) }
        return integer
    }
}

struct TicketTaskProjection: Equatable, Sendable, Identifiable {
    let id: TicketTaskID
    let label: String
    let title: String
    let completion: TicketTaskCompletion

    func accessibilityLabel(position: Int, total: Int) -> String {
        "\(label): \(title), \(completion == .completed ? "checked" : "unchecked"), item \(position) of \(total)"
    }
}

struct LoadedTicketTaskPlanProjection: Equatable, Sendable {
    let revision: Int64
    let tasks: [TicketTaskProjection]
}

struct TaskPlanRecoveryProjection: Equatable, Sendable {
    let message = "Task information could not be loaded. Reload to try again."
}

enum TicketTaskPlanProjection: Equatable, Sendable {
    case noPlan
    case loaded(plan: LoadedTicketTaskPlanProjection)
    case unavailable(recovery: TaskPlanRecoveryProjection)

    typealias RowQuery = @Sendable (SQLiteConnection, ProjectID, PhaseID, TicketID?) throws -> [[String: SQLiteValue]]

    static func queryRows(
        _ connection: SQLiteConnection,
        projectID: ProjectID,
        phaseID: PhaseID,
        ticketID: TicketID?
    ) throws -> [[String: SQLiteValue]] {
        try connection.rows(
            """
            SELECT tickets.id AS ticket_id, plans.revision,
                   tasks.id, tasks.label, tasks.title, tasks.completion
            FROM tickets
            LEFT JOIN ticket_task_plans AS plans
              ON plans.project_id = tickets.project_id AND plans.ticket_id = tickets.id
            LEFT JOIN ticket_tasks AS tasks
              ON tasks.project_id = plans.project_id AND tasks.ticket_id = plans.ticket_id
             AND tasks.lifecycle = 'active'
            WHERE tickets.project_id = ? AND tickets.phase_id = ?
            \(ticketID == nil ? "" : "AND tickets.id = ?")
            ORDER BY tickets.id, tasks.sort_order, tasks.label COLLATE BINARY, tasks.id COLLATE BINARY
            """,
            bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
                + (ticketID.map { [.text($0.rawValue)] } ?? [])
        )
    }

    static func load(
        _ connection: SQLiteConnection,
        projectID: ProjectID,
        phaseID: PhaseID,
        ticketIDs: [TicketID],
        query: RowQuery
    ) -> [TicketID: TicketTaskPlanProjection] {
        let batches: [String: [[String: SQLiteValue]]]
        do {
            batches = try Dictionary(grouping: query(connection, projectID, phaseID, nil)) {
                try $0.text("ticket_id")
            }
        } catch {
            // A failed phase batch is narrowed so an unrelated ticket remains usable.
            return Dictionary(uniqueKeysWithValues: ticketIDs.map { ticketID in
                let projection: TicketTaskPlanProjection
                do {
                    projection = try decode(query(connection, projectID, phaseID, ticketID))
                } catch {
                    projection = unavailableProjection()
                }
                return (ticketID, projection)
            })
        }
        return Dictionary(uniqueKeysWithValues: ticketIDs.map { ticketID in
            do {
                return (ticketID, try decode(batches[ticketID.rawValue] ?? []))
            } catch {
                return (ticketID, unavailableProjection())
            }
        })
    }

    static func loadUnassigned(
        _ connection: SQLiteConnection,
        projectID: ProjectID,
        ticketIDs: [TicketID]
    ) -> [TicketID: TicketTaskPlanProjection] {
        do {
            let rows = try connection.rows(
                """
                SELECT tickets.id AS ticket_id, plans.revision,
                       tasks.id, tasks.label, tasks.title, tasks.completion
                FROM tickets
                LEFT JOIN ticket_task_plans AS plans
                  ON plans.project_id=tickets.project_id AND plans.ticket_id=tickets.id
                LEFT JOIN ticket_tasks AS tasks
                  ON tasks.project_id=plans.project_id AND tasks.ticket_id=plans.ticket_id
                 AND tasks.lifecycle='active'
                WHERE tickets.project_id=? AND tickets.phase_id IS NULL AND tickets.lane IS NULL
                ORDER BY tickets.id, tasks.sort_order, tasks.label COLLATE BINARY, tasks.id COLLATE BINARY
                """,
                bindings: [.text(projectID.rawValue)]
            )
            let batches = try Dictionary(grouping: rows) { try $0.text("ticket_id") }
            return Dictionary(uniqueKeysWithValues: ticketIDs.map { ticketID in
                do { return (ticketID, try decode(batches[ticketID.rawValue] ?? [])) }
                catch { return (ticketID, unavailableProjection()) }
            })
        } catch {
            return Dictionary(uniqueKeysWithValues: ticketIDs.map { ($0, unavailableProjection()) })
        }
    }

    private static func decode(_ rows: [[String: SQLiteValue]]) throws -> TicketTaskPlanProjection {
        guard let first = rows.first else { throw DashboardProjectionError.missingColumn("task plan") }
        if first["revision"] == .null { return .noPlan }
        let revision = try first.integer("revision")
        let tasks = try rows.map { row in
            guard let completion = TicketTaskCompletion(rawValue: try row.text("completion")) else {
                throw DashboardProjectionError.missingColumn("task completion")
            }
            return TicketTaskProjection(
                id: .init(rawValue: try row.text("id")),
                label: try row.text("label"), title: try row.text("title"), completion: completion
            )
        }
        return .loaded(plan: .init(revision: revision, tasks: tasks))
    }

    private static func unavailableProjection() -> TicketTaskPlanProjection {
        Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "Dashboard")
            .error("Ticket task projection unavailable; reload required")
        return .unavailable(recovery: .init())
    }
}

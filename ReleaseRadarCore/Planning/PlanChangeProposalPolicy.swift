import CryptoKit
import Foundation

enum PlanChangeProposalPolicy {
    static let maximumOperations = 256

    static func saveVersion(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        expectedPreviousVersion: Int64?,
        rationale: String,
        operations: [PlanChangeOperation],
        registration: ProjectRegistration?,
        connection: SQLiteConnection
    ) throws -> Int64 {
        guard let registration, registration.projectID == projectID else {
            throw PlanChangeProposalError.registrationRequired
        }
        let currentVersion = try connection.scalarInt(
            "SELECT current_version FROM plan_change_proposals WHERE project_id = ? AND id = ?",
            bindings: [.text(projectID.rawValue), .text(proposalID.rawValue)]
        )
        guard currentVersion == expectedPreviousVersion else {
            throw PlanChangeProposalError.versionConflict(
                expected: expectedPreviousVersion,
                current: currentVersion
            )
        }
        try validate(operations, projectID: projectID, connection: connection)

        let baseline = try PlanningBaseline.capture(projectID: projectID, connection: connection)
        let baselineDigest = SHA256.hash(data: baseline).map { String(format: "%02x", $0) }.joined()
        let diff = try deriveDiff(
            operations, projectID: projectID, connection: connection
        )
        let sourceImpacts = try captureSourceImpacts(
            for: operations,
            projectID: projectID,
            connection: connection
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let operationData = try encoder.encode(operations)
        let diffData = try encoder.encode(diff)
        let sourceImpactData = try encoder.encode(sourceImpacts)
        let version = (currentVersion ?? 0) + 1
        let now = ISO8601DateFormatter().string(from: Date())

        if currentVersion == nil {
            try connection.execute(
                "INSERT INTO plan_change_proposals (project_id, id, current_version, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                bindings: [.text(projectID.rawValue), .text(proposalID.rawValue), .integer(version), .text(now), .text(now)]
            )
        } else {
            try connection.execute(
                "UPDATE plan_change_proposals SET current_version = ?, updated_at = ? WHERE project_id = ? AND id = ?",
                bindings: [.integer(version), .text(now), .text(projectID.rawValue), .text(proposalID.rawValue)]
            )
        }
        try connection.execute(
            """
            INSERT INTO plan_change_proposal_versions (
                project_id, proposal_id, version, registration_id, request_generation,
                baseline_digest, baseline_data, operations_data, diff_data,
                source_impacts_data, rationale, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(projectID.rawValue), .text(proposalID.rawValue), .integer(version),
                .text(registration.registrationID), .integer(registration.requestGeneration),
                .text(baselineDigest), .blob(baseline), .blob(operationData), .blob(diffData),
                .blob(sourceImpactData), .text(rationale), .text(now),
            ]
        )
        return version
    }

    static func decide(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64,
        baselineDigest: String,
        decisionID: String,
        disposition: PlanChangeDecisionDisposition,
        registration: ProjectRegistration?,
        actorID: String,
        connection: SQLiteConnection
    ) throws {
        guard let registration, registration.projectID == projectID else {
            throw PlanChangeProposalError.registrationRequired
        }
        guard let row = try storedVersion(
            projectID: projectID,
            proposalID: proposalID,
            version: version,
            connection: connection
        ) else {
            throw PlanChangeProposalError.notFound
        }
        guard row["baseline_digest"] == .text(baselineDigest),
              row["registration_id"] == .text(registration.registrationID),
              row["request_generation"] == .integer(registration.requestGeneration),
              try connection.scalarInt(
                "SELECT current_version FROM plan_change_proposals WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(proposalID.rawValue)]
              ) == version else {
            throw PlanChangeProposalError.decisionMismatch
        }
        guard try connection.scalarInt(
            "SELECT COUNT(*) FROM plan_change_proposal_decisions WHERE project_id = ? AND proposal_id = ? AND version = ?",
            bindings: [.text(projectID.rawValue), .text(proposalID.rawValue), .integer(version)]
        ) == 0 else {
            throw PlanChangeProposalError.decisionConflict
        }
        guard case let .blob(savedBaseline)? = row["baseline_data"] else {
            throw PlanChangeProposalError.invalidStoredProposal
        }
        let currentBaseline = try PlanningBaseline.capture(projectID: projectID, connection: connection)
        guard currentBaseline == savedBaseline else {
            throw PlanChangeProposalError.stale(
                try PlanningBaseline.changedCategories(from: savedBaseline, to: currentBaseline)
            )
        }
        try connection.execute(
            """
            INSERT INTO plan_change_proposal_decisions (
                project_id, proposal_id, version, id, disposition, baseline_digest,
                registration_id, request_generation, actor_id, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(projectID.rawValue), .text(proposalID.rawValue), .integer(version),
                .text(decisionID), .text(disposition.rawValue), .text(baselineDigest),
                .text(registration.registrationID), .integer(registration.requestGeneration),
                .text(actorID), .text(timestamp()),
            ]
        )
    }

    static func applyApprovedVersion(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64,
        baselineDigest: String,
        decisionID: String,
        applicationID: String,
        registration: ProjectRegistration?,
        auditEventID: AuditEventID,
        connection: SQLiteConnection
    ) throws {
        guard let registration, registration.projectID == projectID else {
            throw PlanChangeProposalError.registrationRequired
        }
        guard let row = try storedVersion(
            projectID: projectID,
            proposalID: proposalID,
            version: version,
            connection: connection
        ) else {
            throw PlanChangeProposalError.notFound
        }
        guard try connection.scalarInt(
            "SELECT current_version FROM plan_change_proposals WHERE project_id = ? AND id = ?",
            bindings: [.text(projectID.rawValue), .text(proposalID.rawValue)]
        ) == version,
              row["baseline_digest"] == .text(baselineDigest),
              row["registration_id"] == .text(registration.registrationID),
              row["request_generation"] == .integer(registration.requestGeneration) else {
            throw PlanChangeProposalError.decisionMismatch
        }
        guard let decision = try connection.row(
            "SELECT * FROM plan_change_proposal_decisions WHERE project_id = ? AND proposal_id = ? AND version = ?",
            bindings: [.text(projectID.rawValue), .text(proposalID.rawValue), .integer(version)]
        ) else {
            throw PlanChangeProposalError.decisionNotApproved
        }
        guard decision["id"] == .text(decisionID),
              decision["disposition"] == .text(PlanChangeDecisionDisposition.approved.rawValue),
              decision["baseline_digest"] == .text(baselineDigest),
              decision["registration_id"] == .text(registration.registrationID),
              decision["request_generation"] == .integer(registration.requestGeneration) else {
            throw PlanChangeProposalError.decisionMismatch
        }
        guard try connection.scalarInt(
            "SELECT COUNT(*) FROM plan_change_proposal_applications WHERE project_id = ? AND proposal_id = ? AND version = ?",
            bindings: [.text(projectID.rawValue), .text(proposalID.rawValue), .integer(version)]
        ) == 0 else {
            throw PlanChangeProposalError.alreadyApplied
        }
        guard case let .blob(savedBaseline)? = row["baseline_data"],
              case let .blob(operationData)? = row["operations_data"] else {
            throw PlanChangeProposalError.invalidStoredProposal
        }
        let currentBaseline = try PlanningBaseline.capture(projectID: projectID, connection: connection)
        guard currentBaseline == savedBaseline else {
            throw PlanChangeProposalError.stale(
                try PlanningBaseline.changedCategories(from: savedBaseline, to: currentBaseline)
            )
        }
        let operations = try JSONDecoder().decode([PlanChangeOperation].self, from: operationData)
        try validate(operations, projectID: projectID, connection: connection)
        try apply(
            operations,
            projectID: projectID,
            auditEventID: auditEventID,
            connection: connection
        )
        try connection.execute(
            """
            INSERT INTO plan_change_proposal_applications (
                project_id, proposal_id, version, id, decision_id, audit_event_id, applied_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(projectID.rawValue), .text(proposalID.rawValue), .integer(version),
                .text(applicationID), .text(decisionID), .text(auditEventID.rawValue),
                .text(timestamp()),
            ]
        )
    }

    private static func validate(
        _ operations: [PlanChangeOperation],
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        guard !operations.isEmpty, operations.count <= maximumOperations else {
            throw PlanChangeProposalError.invalidOperation("A proposal must contain 1...\(maximumOperations) bounded operations.")
        }
        var phaseIDs = Set<Data>()
        var goalIDs = Set<Data>()
        var ticketIDs = Set<Data>()
        var taskIDs = Set<Data>()
        var phaseDependencyIDs = Set<Data>()
        var ticketDependencyIDs = Set<Data>()
        var placements = Set<Data>()
        var assignments = Set<Data>()
        var retirements: [Data: Set<TicketID>] = [:]
        var moves = Set<Data>()
        var reassignments = Set<Data>()
        var supersessions = Set<Data>()
        var dependencyReconciliations = Set<Data>()
        var obligationResolutions = Set<DeliveryGoalObligationKey>()
        var carriedDescendants = Set<DeliveryGoalObligationKey>()
        var proposedCarryDescendants: [DeliveryGoalObligationKey: Set<DeliveryGoalObligationKey>] = [:]
        var goalCountsByPhase: [Data: Int] = [:]
        let proposedPhases = Set(operations.compactMap { operation -> Data? in
            guard case let .addPhase(id, _) = operation else { return nil }
            return Data(id.rawValue.utf8)
        })
        let proposedTickets = Set(operations.compactMap { operation -> Data? in
            guard case let .addUnassignedTicket(id, _) = operation else { return nil }
            return Data(id.rawValue.utf8)
        })
        let proposedTaskTickets = Set(operations.compactMap { operation -> Data? in
            guard case let .addPendingTicketTasks(ticketID, _) = operation else { return nil }
            return Data(ticketID.rawValue.utf8)
        })
        let proposedGoalPhases = operations.reduce(into: [Data: Data]()) { values, operation in
            guard case let .addDeliveryGoal(phaseID, goal) = operation else { return }
            values[Data(goal.id.rawValue.utf8)] = Data(phaseID.rawValue.utf8)
        }
        let proposedPlacements = operations.reduce(into: [Data: Data]()) { values, operation in
            guard case let .placeTicket(ticketID, phaseID) = operation else { return }
            values[Data(ticketID.rawValue.utf8)] = Data(phaseID.rawValue.utf8)
        }
        let proposedAssignments = Set(operations.compactMap { operation -> DeliveryGoalObligationKey? in
            switch operation {
            case let .assignTicketToGoal(ticketID, phaseID, goalID):
                return .init(phaseID: phaseID, goalID: goalID, ticketID: ticketID)
            case let .reassignTicketToGoal(ticketID, phaseID, _, toGoalID):
                return .init(phaseID: phaseID, goalID: toGoalID, ticketID: ticketID)
            default:
                return nil
            }
        })

        func requireText(_ value: String, label: String, maximum: Int = 4_096) throws {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  value.utf8.count <= maximum,
                  !value.contains("\0") else {
                throw PlanChangeProposalError.invalidOperation("\(label) must contain 1...\(maximum) UTF-8 bytes without a NUL character.")
            }
        }
        func phaseExists(_ id: PhaseID) throws -> Bool {
            if proposedPhases.contains(Data(id.rawValue.utf8)) { return true }
            return try connection.scalarInt(
                "SELECT COUNT(*) FROM phases WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(id.rawValue)]
            ) == 1
        }
        func ticketExists(_ id: TicketID) throws -> Bool {
            if proposedTickets.contains(Data(id.rawValue.utf8)) { return true }
            return try connection.scalarInt(
                "SELECT COUNT(*) FROM tickets WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(id.rawValue)]
            ) == 1
        }
        func baselineTicketExists(_ id: TicketID) throws -> Bool {
            try connection.scalarInt(
                "SELECT COUNT(*) FROM tickets WHERE project_id=? AND id=?",
                bindings: [.text(projectID.rawValue), .text(id.rawValue)]
            ) == 1
        }
        func goalExists(_ phaseID: PhaseID, _ goalID: DeliveryGoalID, actionable: Bool = false) throws -> Bool {
            if proposedGoalPhases[Data(goalID.rawValue.utf8)] == Data(phaseID.rawValue.utf8) { return true }
            let lifecycle = actionable ? " AND lifecycle NOT IN ('accepted','superseded')" : ""
            return try connection.scalarInt(
                "SELECT COUNT(*) FROM delivery_goals WHERE project_id=? AND phase_id=? AND id=?\(lifecycle)",
                bindings: [.text(projectID.rawValue), .text(phaseID.rawValue), .text(goalID.rawValue)]
            ) == 1
        }
        func obligationExists(_ key: DeliveryGoalObligationKey) throws -> Bool {
            if proposedAssignments.contains(key) { return true }
            return try connection.scalarInt(
                "SELECT COUNT(*) FROM delivery_goal_obligations WHERE project_id=? AND phase_id=? AND goal_id=? AND ticket_id=?",
                bindings: [.text(projectID.rawValue), .text(key.phaseID.rawValue), .text(key.goalID.rawValue), .text(key.ticketID.rawValue)]
            ) == 1
        }
        func obligationIsAlreadyResolved(_ key: DeliveryGoalObligationKey) throws -> Bool {
            let bindings: [SQLiteValue] = [.text(projectID.rawValue), .text(key.phaseID.rawValue), .text(key.goalID.rawValue), .text(key.ticketID.rawValue)]
            let dropped = try connection.scalarInt(
                "SELECT COUNT(*) FROM delivery_goal_obligation_drops WHERE project_id=? AND phase_id=? AND goal_id=? AND ticket_id=?",
                bindings: bindings
            ) == 1
            let carried = try connection.scalarInt(
                "SELECT COUNT(*) FROM delivery_goal_obligation_lineage WHERE project_id=? AND source_phase_id=? AND source_goal_id=? AND source_ticket_id=?",
                bindings: bindings
            ) ?? 0
            return dropped || carried > 0
        }
        func obligationHasAcceptedScope(_ key: DeliveryGoalObligationKey) throws -> Bool {
            guard !proposedAssignments.contains(key) else { return false }
            return try connection.scalarInt(
                """
                SELECT COUNT(*)
                FROM delivery_goal_obligations o
                JOIN tickets t ON t.project_id=o.project_id AND t.id=o.ticket_id
                JOIN delivery_goals g ON g.project_id=o.project_id AND g.phase_id=o.phase_id AND g.id=o.goal_id
                WHERE o.project_id=? AND o.phase_id=? AND o.goal_id=? AND o.ticket_id=?
                  AND (
                    g.lifecycle='accepted'
                    OR (
                      t.lane='accepted'
                      AND EXISTS (
                        SELECT 1 FROM delivery_goal_ticket_assignments a
                        WHERE a.project_id=o.project_id AND a.phase_id=o.phase_id
                          AND a.goal_id=o.goal_id AND a.ticket_id=o.ticket_id
                      )
                    )
                  )
                """,
                bindings: [.text(projectID.rawValue), .text(key.phaseID.rawValue), .text(key.goalID.rawValue), .text(key.ticketID.rawValue)]
            ) == 1
        }
        func obligationIsEligibleDescendant(_ key: DeliveryGoalObligationKey) throws -> Bool {
            if proposedAssignments.contains(key) { return true }
            return try connection.scalarInt(
                """
                SELECT COUNT(*)
                FROM delivery_goal_obligations o
                JOIN delivery_goal_ticket_assignments a
                  ON a.project_id=o.project_id AND a.phase_id=o.phase_id
                 AND a.goal_id=o.goal_id AND a.ticket_id=o.ticket_id
                JOIN tickets t ON t.project_id=o.project_id AND t.id=o.ticket_id
                JOIN delivery_goals g ON g.project_id=o.project_id AND g.phase_id=o.phase_id AND g.id=o.goal_id
                WHERE o.project_id=? AND o.phase_id=? AND o.goal_id=? AND o.ticket_id=?
                  AND t.lane<>'accepted' AND g.lifecycle NOT IN ('accepted','superseded')
                """,
                bindings: [.text(projectID.rawValue), .text(key.phaseID.rawValue), .text(key.goalID.rawValue), .text(key.ticketID.rawValue)]
            ) == 1
        }
        func requireEligibleExistingSubject(_ id: TicketID) throws {
            if proposedTickets.contains(Data(id.rawValue.utf8)) { return }
            guard let row = try connection.row(
                "SELECT lane FROM tickets WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(id.rawValue)]
            ) else {
                throw PlanChangeProposalError.invalidOperation("Ticket \(id.rawValue) does not belong to this project.")
            }
            guard row["lane"] == .null || row["lane"] == .text(TicketLane.backlog.rawValue) else {
                throw PlanChangeProposalError.invalidOperation("Only unassigned or Backlog tickets may be changed by an additive proposal.")
            }
        }
        for operation in operations {
            switch operation {
            case let .addPhase(id, name):
                guard phaseIDs.insert(Data(id.rawValue.utf8)).inserted,
                      try connection.scalarInt(
                        "SELECT COUNT(*) FROM phases WHERE project_id = ? AND id = ?",
                        bindings: [.text(projectID.rawValue), .text(id.rawValue)]
                      ) == 0 else {
                    throw PlanChangeProposalError.invalidOperation("Phase \(id.rawValue) already exists or is proposed more than once.")
                }
                try requireText(id.rawValue, label: "Phase ID", maximum: 256)
                try requireText(name, label: "Phase name")
            case let .addDeliveryGoal(phaseID, goal):
                let phaseKey = Data(phaseID.rawValue.utf8)
                goalCountsByPhase[phaseKey, default: 0] += 1
                guard try phaseExists(phaseID) else {
                    throw PlanChangeProposalError.invalidOperation("Goal \(goal.id.rawValue) names an unavailable phase.")
                }
                guard goalCountsByPhase[phaseKey, default: 0] <= DeliveryPlanningPolicy.maximumGoalOperationsPerRevision else {
                    throw PlanChangeProposalError.invalidOperation("A proposed phase revision permits at most \(DeliveryPlanningPolicy.maximumGoalOperationsPerRevision) goal additions.")
                }
                guard goalIDs.insert(Data(goal.id.rawValue.utf8)).inserted,
                      try connection.scalarInt(
                        "SELECT COUNT(*) FROM delivery_goals WHERE project_id = ? AND id = ?",
                        bindings: [.text(projectID.rawValue), .text(goal.id.rawValue)]
                      ) == 0 else {
                    throw PlanChangeProposalError.invalidOperation("Goal \(goal.id.rawValue) already exists or is proposed more than once.")
                }
                try requireText(goal.id.rawValue, label: "Goal ID", maximum: 256)
                try requireText(goal.title, label: "Goal title")
                try requireText(goal.outcome, label: "Goal outcome")
                guard !goal.doneCriteria.isEmpty, goal.sortOrder >= 0 else {
                    throw PlanChangeProposalError.invalidOperation("A proposed goal needs done criteria and a nonnegative sort order.")
                }
                try goal.doneCriteria.forEach { try requireText($0, label: "Goal criterion") }
            case let .addUnassignedTicket(id, outcome):
                guard ticketIDs.insert(Data(id.rawValue.utf8)).inserted,
                      try connection.scalarInt(
                        "SELECT COUNT(*) FROM tickets WHERE project_id = ? AND id = ?",
                        bindings: [.text(projectID.rawValue), .text(id.rawValue)]
                      ) == 0 else {
                    throw PlanChangeProposalError.invalidOperation("Ticket \(id.rawValue) already exists or is proposed more than once.")
                }
                try requireText(id.rawValue, label: "Ticket ID", maximum: 256)
                try requireText(outcome, label: "Ticket outcome")
            case let .addPendingTicketTasks(ticketID, tasks):
                guard try ticketExists(ticketID), !tasks.isEmpty,
                      tasks.count <= TicketTaskPlanningPolicy.maximumOperationsPerRevision else {
                    throw PlanChangeProposalError.invalidOperation("Pending task additions need an available ticket and 1...\(TicketTaskPlanningPolicy.maximumOperationsPerRevision) tasks.")
                }
                try requireEligibleExistingSubject(ticketID)
                for task in tasks {
                    guard taskIDs.insert(Data(task.id.rawValue.utf8)).inserted else {
                        throw PlanChangeProposalError.invalidOperation("Task \(task.id.rawValue) is proposed more than once.")
                    }
                    try requireText(task.id.rawValue, label: "Task ID", maximum: 256)
                    try requireText(task.label, label: "Task label", maximum: 256)
                    try requireText(task.title, label: "Task title")
                    guard task.sortOrder >= 0 else {
                        throw PlanChangeProposalError.invalidOperation("Task sort order must be nonnegative.")
                    }
                }
            case let .placeTicket(ticketID, phaseID):
                guard placements.insert(Data(ticketID.rawValue.utf8)).inserted,
                      try ticketExists(ticketID), try phaseExists(phaseID) else {
                    throw PlanChangeProposalError.invalidOperation("First placement must name one available ticket and phase exactly once.")
                }
                try requireEligibleExistingSubject(ticketID)
                if !proposedTickets.contains(Data(ticketID.rawValue.utf8)) {
                    guard try connection.scalarText(
                        "SELECT phase_id FROM tickets WHERE project_id = ? AND id = ?",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                    ) == nil else {
                        throw PlanChangeProposalError.invalidOperation("Only an unassigned ticket may receive first placement.")
                    }
                }
            case let .assignTicketToGoal(ticketID, phaseID, goalID):
                let ticketKey = Data(ticketID.rawValue.utf8)
                let phaseKey = Data(phaseID.rawValue.utf8)
                let currentPhase = try connection.scalarText(
                    "SELECT phase_id FROM tickets WHERE project_id = ? AND id = ?",
                    bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                ).map { Data($0.utf8) }
                let goalIsAvailable: Bool
                if proposedGoalPhases[Data(goalID.rawValue.utf8)] == phaseKey {
                    goalIsAvailable = true
                } else {
                    goalIsAvailable = try connection.scalarInt(
                        "SELECT COUNT(*) FROM delivery_goals WHERE project_id = ? AND phase_id = ? AND id = ? AND lifecycle NOT IN ('accepted', 'superseded')",
                        bindings: [.text(projectID.rawValue), .text(phaseID.rawValue), .text(goalID.rawValue)]
                    ) == 1
                }
                let hasExistingAssignment: Bool
                if proposedTickets.contains(ticketKey) {
                    hasExistingAssignment = false
                } else {
                    hasExistingAssignment = try connection.scalarInt(
                        "SELECT COUNT(*) FROM delivery_goal_ticket_assignments WHERE project_id = ? AND ticket_id = ?",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                    ) != 0
                }
                guard assignments.insert(Data(ticketID.rawValue.utf8)).inserted,
                      try ticketExists(ticketID), try phaseExists(phaseID),
                      goalIsAvailable, !hasExistingAssignment,
                      proposedPlacements[ticketKey] == phaseKey || currentPhase == phaseKey else {
                    throw PlanChangeProposalError.invalidOperation("Initial goal assignment must name one available unassigned ticket, phase and actionable goal exactly once.")
                }
                try requireEligibleExistingSubject(ticketID)
                guard try connection.scalarInt(
                    "SELECT COUNT(*) FROM delivery_goal_ticket_assignments WHERE project_id = ? AND ticket_id = ?",
                    bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                ) == 0 else {
                    throw PlanChangeProposalError.invalidOperation("Assignment removal or transfer is outside additive proposals.")
                }
            case let .addPhaseDependency(id, phaseID, dependsOnPhaseID):
                guard phaseDependencyIDs.insert(Data(id.rawValue.utf8)).inserted,
                      try phaseExists(phaseID), try phaseExists(dependsOnPhaseID),
                      Data(phaseID.rawValue.utf8) != Data(dependsOnPhaseID.rawValue.utf8),
                      try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE id = ?", bindings: [.text(id.rawValue)]) == 0 else {
                    throw PlanChangeProposalError.invalidOperation("A phase dependency must use a new identity and two available distinct phases.")
                }
                try requireText(id.rawValue, label: "Phase dependency ID", maximum: 256)
            case let .addTicketDependency(id, ticketID, dependsOnTicketID):
                guard ticketDependencyIDs.insert(Data(id.rawValue.utf8)).inserted,
                      try ticketExists(ticketID), try ticketExists(dependsOnTicketID),
                      Data(ticketID.rawValue.utf8) != Data(dependsOnTicketID.rawValue.utf8),
                      try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE id = ?", bindings: [.text(id.rawValue)]) == 0 else {
                    throw PlanChangeProposalError.invalidOperation("A ticket dependency must use a new identity and two available distinct tickets.")
                }
                try requireEligibleExistingSubject(ticketID)
                try requireText(id.rawValue, label: "Ticket dependency ID", maximum: 256)
            case let .retireTicket(ticketID, disposition, reason, successorTicketIDs):
                let ticketKey = Data(ticketID.rawValue.utf8)
                guard retirements[ticketKey] == nil, try baselineTicketExists(ticketID),
                      try connection.scalarInt(
                        "SELECT COUNT(*) FROM ticket_retirements WHERE project_id=? AND ticket_id=?",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                      ) == 0,
                      try connection.scalarText(
                        "SELECT lane FROM tickets WHERE project_id=? AND id=?",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                      ) != TicketLane.accepted.rawValue else {
                    throw PlanChangeProposalError.invalidOperation("Retirement must name an available ticket.")
                }
                try requireText(reason, label: "Retirement reason")
                let expectedSuccessorCount: Bool
                switch disposition {
                case .withdrawn: expectedSuccessorCount = successorTicketIDs.isEmpty
                case .replaced: expectedSuccessorCount = successorTicketIDs.count == 1
                case .split: expectedSuccessorCount = successorTicketIDs.count >= 2
                }
                guard expectedSuccessorCount, Set(successorTicketIDs).count == successorTicketIDs.count else {
                    throw PlanChangeProposalError.invalidOperation("Retirement successors must match the selected disposition and name distinct available tickets.")
                }
                for successorTicketID in successorTicketIDs {
                    guard proposedTickets.contains(Data(successorTicketID.rawValue.utf8)),
                          proposedTaskTickets.contains(Data(successorTicketID.rawValue.utf8)),
                          successorTicketID != ticketID,
                          try !baselineTicketExists(successorTicketID) else {
                        throw PlanChangeProposalError.invalidOperation("Every successor must be a new ticket with new pending tasks created in this same proposal.")
                    }
                }
                retirements[ticketKey] = Set(successorTicketIDs)
            case let .moveBacklogTicket(ticketID, fromPhaseID, toPhaseID):
                guard moves.insert(Data(ticketID.rawValue.utf8)).inserted,
                      try ticketExists(ticketID), try phaseExists(fromPhaseID), try phaseExists(toPhaseID),
                      fromPhaseID != toPhaseID,
                      try connection.scalarInt(
                        "SELECT COUNT(*) FROM tickets WHERE project_id=? AND id=? AND phase_id=? AND lane='backlog'",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue), .text(fromPhaseID.rawValue)]
                      ) == 1 else {
                    throw PlanChangeProposalError.invalidOperation("A Backlog move must name one available ticket and two distinct available phases.")
                }
            case let .reassignTicketToGoal(ticketID, phaseID, fromGoalID, toGoalID):
                guard reassignments.insert(Data(ticketID.rawValue.utf8)).inserted,
                      try ticketExists(ticketID), try phaseExists(phaseID), fromGoalID != toGoalID,
                      try goalExists(phaseID, toGoalID, actionable: true),
                      try connection.scalarInt(
                        "SELECT COUNT(*) FROM tickets WHERE project_id=? AND id=? AND lane='backlog'",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                      ) == 1,
                      try connection.scalarInt(
                        "SELECT COUNT(*) FROM delivery_goal_ticket_assignments WHERE project_id=? AND ticket_id=? AND goal_id=?",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue), .text(fromGoalID.rawValue)]
                      ) == 1 else {
                    throw PlanChangeProposalError.invalidOperation("Goal reassignment must name an available ticket, phase, and distinct goals.")
                }
            case let .supersedeDeliveryGoal(phaseID, goalID):
                guard supersessions.insert(Data(goalID.rawValue.utf8)).inserted,
                      try phaseExists(phaseID), try goalExists(phaseID, goalID, actionable: true) else {
                    throw PlanChangeProposalError.invalidOperation("Goal supersession must name an available phase.")
                }
                try requireText(goalID.rawValue, label: "Goal ID", maximum: 256)
            case let .carryGoalObligation(source, descendants, reason):
                try requireText(reason, label: "Carry reason")
                guard !descendants.isEmpty, Set(descendants).count == descendants.count,
                      !descendants.contains(source), obligationResolutions.insert(source).inserted,
                      try obligationExists(source), try !obligationIsAlreadyResolved(source),
                      try !obligationHasAcceptedScope(source) else {
                    throw PlanChangeProposalError.invalidOperation("A carry must name distinct descendant obligations.")
                }
                for descendant in descendants {
                    guard carriedDescendants.insert(descendant).inserted,
                          try obligationExists(descendant), try obligationIsEligibleDescendant(descendant),
                          try connection.scalarInt(
                            "SELECT COUNT(*) FROM delivery_goal_obligation_lineage WHERE project_id=? AND descendant_phase_id=? AND descendant_goal_id=? AND descendant_ticket_id=?",
                            bindings: [
                                .text(projectID.rawValue), .text(descendant.phaseID.rawValue),
                                .text(descendant.goalID.rawValue), .text(descendant.ticketID.rawValue),
                            ]
                          ) == 0 else {
                        throw PlanChangeProposalError.invalidOperation("Every carry descendant must be an available obligation used by exactly one source.")
                    }
                }
                proposedCarryDescendants[source] = Set(descendants)
            case let .dropGoalObligation(_, reason):
                try requireText(reason, label: "Drop reason")
                if case let .dropGoalObligation(obligation, _) = operation {
                    guard obligationResolutions.insert(obligation).inserted,
                          try obligationExists(obligation), try !obligationIsAlreadyResolved(obligation),
                          try !obligationHasAcceptedScope(obligation) else {
                        throw PlanChangeProposalError.invalidOperation("A drop must name one outstanding obligation exactly once.")
                    }
                }
            case let .retargetTicketDependency(id, ticketID, fromDependsOnTicketID, toDependsOnTicketID):
                guard dependencyReconciliations.insert(Data(id.rawValue.utf8)).inserted,
                      try ticketExists(ticketID), try ticketExists(fromDependsOnTicketID),
                      try ticketExists(toDependsOnTicketID), fromDependsOnTicketID != toDependsOnTicketID else {
                    throw PlanChangeProposalError.invalidOperation("Dependency retargeting must name available tickets and a changed target.")
                }
                guard try connection.scalarInt(
                    "SELECT COUNT(*) FROM ticket_dependencies WHERE project_id=? AND id=? AND ticket_id=? AND depends_on_ticket_id=?",
                    bindings: [.text(projectID.rawValue), .text(id.rawValue), .text(ticketID.rawValue), .text(fromDependsOnTicketID.rawValue)]
                ) == 1 else {
                    throw PlanChangeProposalError.invalidOperation("Dependency retargeting must match the exact current dependency.")
                }
                try requireText(id.rawValue, label: "Ticket dependency ID", maximum: 256)
            case let .removeTicketDependency(id, ticketID, dependsOnTicketID):
                guard dependencyReconciliations.insert(Data(id.rawValue.utf8)).inserted,
                      try ticketExists(ticketID), try ticketExists(dependsOnTicketID) else {
                    throw PlanChangeProposalError.invalidOperation("Dependency removal must name available tickets.")
                }
                guard try connection.scalarInt(
                    "SELECT COUNT(*) FROM ticket_dependencies WHERE project_id=? AND id=? AND ticket_id=? AND depends_on_ticket_id=?",
                    bindings: [.text(projectID.rawValue), .text(id.rawValue), .text(ticketID.rawValue), .text(dependsOnTicketID.rawValue)]
                ) == 1 else {
                    throw PlanChangeProposalError.invalidOperation("Dependency removal must match the exact current dependency.")
                }
                try requireText(id.rawValue, label: "Ticket dependency ID", maximum: 256)
            }
        }

        // Every retired ticket's retained scope must be explicitly carried or
        // dropped in the same approved package. Successor creation alone never
        // resolves a Delivery Goal obligation.
        for (ticketKey, successorTicketIDs) in retirements {
            let ticketID = String(decoding: ticketKey, as: UTF8.self)
            let rows = try connection.rows(
                "SELECT phase_id,goal_id FROM delivery_goal_obligations WHERE project_id=? AND ticket_id=?",
                bindings: [.text(projectID.rawValue), .text(ticketID)], maximum: 4096
            )
            for row in rows {
                guard case let .text(phaseID)? = row["phase_id"], case let .text(goalID)? = row["goal_id"] else {
                    throw PlanChangeProposalError.invalidStoredProposal
                }
                let key = DeliveryGoalObligationKey(
                    phaseID: .init(rawValue: phaseID), goalID: .init(rawValue: goalID),
                    ticketID: .init(rawValue: ticketID)
                )
                let alreadyResolved = try obligationIsAlreadyResolved(key)
                guard obligationResolutions.contains(key) || alreadyResolved else {
                    throw PlanChangeProposalError.invalidOperation("Retirement must explicitly carry or drop every outstanding Delivery Goal obligation.")
                }
                if let descendants = proposedCarryDescendants[key] {
                    let carriedTicketIDs = Set(descendants.map(\.ticketID))
                    guard carriedTicketIDs == successorTicketIDs else {
                        throw PlanChangeProposalError.invalidOperation("Every carried retirement obligation must name all and only the retirement's required successors.")
                    }
                }
                let persistedCarryTicketIDs = Set(try connection.rows(
                    """
                    SELECT descendant_ticket_id FROM delivery_goal_obligation_lineage
                    WHERE project_id=? AND source_phase_id=? AND source_goal_id=?
                      AND source_ticket_id=?
                    """,
                    bindings: [
                        .text(projectID.rawValue), .text(key.phaseID.rawValue),
                        .text(key.goalID.rawValue), .text(key.ticketID.rawValue),
                    ]
                ).compactMap { row -> TicketID? in
                    guard case let .text(ticketID)? = row["descendant_ticket_id"] else { return nil }
                    return .init(rawValue: ticketID)
                })
                if !persistedCarryTicketIDs.isEmpty,
                   persistedCarryTicketIDs != successorTicketIDs
                {
                    throw PlanChangeProposalError.invalidOperation("Existing carried scope does not match the retirement's required successors.")
                }
            }
        }

        // Reject proposed carry cycles against both persisted and proposed
        // lineage before any graph mutation begins.
        var edges: [DeliveryGoalObligationKey: Set<DeliveryGoalObligationKey>] = [:]
        for row in try connection.rows(
            "SELECT source_phase_id,source_goal_id,source_ticket_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id FROM delivery_goal_obligation_lineage WHERE project_id=?",
            bindings: [.text(projectID.rawValue)], maximum: 20_000
        ) {
            guard case let .text(sp)? = row["source_phase_id"], case let .text(sg)? = row["source_goal_id"],
                  case let .text(st)? = row["source_ticket_id"], case let .text(dp)? = row["descendant_phase_id"],
                  case let .text(dg)? = row["descendant_goal_id"], case let .text(dt)? = row["descendant_ticket_id"] else {
                throw PlanChangeProposalError.invalidStoredProposal
            }
            edges[.init(phaseID: .init(rawValue: sp), goalID: .init(rawValue: sg), ticketID: .init(rawValue: st)), default: []]
                .insert(.init(phaseID: .init(rawValue: dp), goalID: .init(rawValue: dg), ticketID: .init(rawValue: dt)))
        }
        for operation in operations {
            guard case let .carryGoalObligation(source, descendants, _) = operation else { continue }
            edges[source, default: []].formUnion(descendants)
        }
        func hasCycle(_ node: DeliveryGoalObligationKey, _ visiting: inout Set<DeliveryGoalObligationKey>, _ visited: inout Set<DeliveryGoalObligationKey>) -> Bool {
            if visiting.contains(node) { return true }
            if visited.contains(node) { return false }
            visiting.insert(node)
            for child in edges[node] ?? [] where hasCycle(child, &visiting, &visited) { return true }
            visiting.remove(node)
            visited.insert(node)
            return false
        }
        var visiting = Set<DeliveryGoalObligationKey>()
        var visited = Set<DeliveryGoalObligationKey>()
        for node in edges.keys where hasCycle(node, &visiting, &visited) {
            throw PlanChangeProposalError.invalidOperation("Delivery Goal obligation carry lineage cannot contain a cycle.")
        }
    }

    private static func deriveDiff(
        _ operations: [PlanChangeOperation],
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> PlanChangeDiff {
        var phaseItems: [PlanChangeDiffItem] = []
        var goalItems: [PlanChangeDiffItem] = []
        var ticketItems: [PlanChangeDiffItem] = []
        var taskItems: [PlanChangeDiffItem] = []
        var assignmentItems: [PlanChangeDiffItem] = []
        var dependencyItems: [PlanChangeDiffItem] = []
        func laneName(_ rawValue: String) -> String {
            switch TicketLane(rawValue: rawValue) {
            case .backlog: "Backlog"
            case .inProgress: "In progress"
            case .needsReview: "Needs review"
            case .blocked: "Blocked"
            case .accepted: "Accepted"
            case nil: rawValue
            }
        }
        func currentPlacement(_ ticketID: TicketID) throws -> String {
            guard let row = try connection.row(
                "SELECT phase_id,lane FROM tickets WHERE project_id=? AND id=?",
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
            ) else { throw PlanChangeProposalError.invalidStoredProposal }
            guard case let .text(phaseID)? = row["phase_id"],
                  case let .text(lane)? = row["lane"] else { return "unassigned" }
            return "\(phaseID) \(laneName(lane))"
        }
        func obligationScope(_ key: DeliveryGoalObligationKey) throws -> String {
            guard let scope = try connection.scalarText(
                "SELECT scope FROM delivery_goal_obligations WHERE project_id=? AND phase_id=? AND goal_id=? AND ticket_id=?",
                bindings: [.text(projectID.rawValue), .text(key.phaseID.rawValue), .text(key.goalID.rawValue), .text(key.ticketID.rawValue)]
            ) else { throw PlanChangeProposalError.invalidStoredProposal }
            return scope
        }
        for operation in operations {
            switch operation {
            case let .addPhase(id, name):
                phaseItems.append(.init(summary: """
                Add phase \(id.rawValue)
                Before: absent
                After:
                Name: \(name)
                """))
            case let .addDeliveryGoal(phaseID, goal):
                goalItems.append(.init(summary: """
                Add goal \(goal.id.rawValue) to \(phaseID.rawValue)
                Before: absent
                After:
                Title: \(goal.title)
                Outcome: \(goal.outcome)
                Done criteria: \(goal.doneCriteria.joined(separator: " | "))
                Sort order: \(goal.sortOrder)
                """))
            case let .addUnassignedTicket(id, outcome):
                ticketItems.append(.init(summary: """
                Add ticket \(id.rawValue)
                Before: absent
                After:
                Outcome: \(outcome)
                Placement: unassigned
                """))
            case let .addPendingTicketTasks(ticketID, tasks):
                taskItems.append(contentsOf: tasks.map { task in
                    .init(summary: """
                    Add task \(task.id.rawValue) to \(ticketID.rawValue)
                    Before: absent
                    After:
                    Label: \(task.label)
                    Title: \(task.title)
                    Sort order: \(task.sortOrder)
                    Completion: pending
                    """)
                })
            case let .placeTicket(ticketID, phaseID):
                ticketItems.append(.init(summary: """
                Place ticket \(ticketID.rawValue)
                Before: unassigned
                After: \(phaseID.rawValue) Backlog
                """))
            case let .assignTicketToGoal(ticketID, phaseID, goalID):
                assignmentItems.append(.init(summary: """
                Assign ticket \(ticketID.rawValue)
                Before: unassigned
                After: \(goalID.rawValue) in \(phaseID.rawValue)
                """))
            case let .addPhaseDependency(id, phaseID, dependsOnPhaseID):
                dependencyItems.append(.init(summary: """
                Add phase dependency \(id.rawValue)
                Before: absent
                After: \(phaseID.rawValue) depends on \(dependsOnPhaseID.rawValue)
                """))
            case let .addTicketDependency(id, ticketID, dependsOnTicketID):
                dependencyItems.append(.init(summary: """
                Add ticket dependency \(id.rawValue)
                Before: absent
                After: \(ticketID.rawValue) depends on \(dependsOnTicketID.rawValue)
                """))
            case let .retireTicket(ticketID, disposition, reason, successors):
                ticketItems.append(.init(summary: "Retire ticket \(ticketID.rawValue) as \(disposition.rawValue)\nBefore: \(try currentPlacement(ticketID))\nAfter: retained original; successors: \(successors.map(\.rawValue).joined(separator: ", "))\nReason: \(reason)"))
            case let .moveBacklogTicket(ticketID, fromPhaseID, toPhaseID):
                ticketItems.append(.init(summary: "Move Backlog ticket \(ticketID.rawValue)\nBefore: \(fromPhaseID.rawValue)\nAfter: \(toPhaseID.rawValue)"))
            case let .reassignTicketToGoal(ticketID, phaseID, fromGoalID, toGoalID):
                assignmentItems.append(.init(summary: "Reassign ticket \(ticketID.rawValue) in \(phaseID.rawValue)\nBefore: \(fromGoalID.rawValue)\nAfter: \(toGoalID.rawValue)"))
            case let .supersedeDeliveryGoal(phaseID, goalID):
                goalItems.append(.init(summary: "Supersede goal \(goalID.rawValue) in \(phaseID.rawValue)\nBefore: actionable\nAfter: superseded"))
            case let .carryGoalObligation(source, descendants, reason):
                let destinations = descendants.map {
                    "\($0.ticketID.rawValue) → \($0.goalID.rawValue) in \($0.phaseID.rawValue)"
                }.joined(separator: "; ")
                assignmentItems.append(.init(summary: "Carry obligation \(source.ticketID.rawValue)\nBefore: \(source.goalID.rawValue) in \(source.phaseID.rawValue)\nOriginal scope: \(try obligationScope(source))\nAfter: \(destinations)\nReason: \(reason)"))
            case let .dropGoalObligation(obligation, reason):
                assignmentItems.append(.init(summary: "Drop obligation \(obligation.ticketID.rawValue) from \(obligation.goalID.rawValue)\nBefore: \(try obligationScope(obligation)) in \(obligation.phaseID.rawValue)\nAfter: explicitly dropped\nReason: \(reason)"))
            case let .retargetTicketDependency(id, ticketID, fromDependsOnTicketID, toDependsOnTicketID):
                dependencyItems.append(.init(summary: "Retarget ticket dependency \(id.rawValue) for \(ticketID.rawValue)\nBefore: \(fromDependsOnTicketID.rawValue)\nAfter: \(toDependsOnTicketID.rawValue)"))
            case let .removeTicketDependency(id, ticketID, dependsOnTicketID):
                dependencyItems.append(.init(summary: "Remove ticket dependency \(id.rawValue) for \(ticketID.rawValue)\nBefore: \(dependsOnTicketID.rawValue)\nAfter: absent"))
            }
        }
        var groups: [PlanChangeDiffGroup] = []
        if !phaseItems.isEmpty { groups.append(.init(kind: .phases, items: phaseItems)) }
        if !goalItems.isEmpty { groups.append(.init(kind: .goals, items: goalItems)) }
        if !ticketItems.isEmpty { groups.append(.init(kind: .tickets, items: ticketItems)) }
        if !taskItems.isEmpty { groups.append(.init(kind: .tasks, items: taskItems)) }
        if !assignmentItems.isEmpty { groups.append(.init(kind: .assignments, items: assignmentItems)) }
        if !dependencyItems.isEmpty { groups.append(.init(kind: .dependencies, items: dependencyItems)) }
        return .init(groups: groups)
    }

    private static func apply(
        _ operations: [PlanChangeOperation],
        projectID: ProjectID,
        auditEventID: AuditEventID,
        connection: SQLiteConnection
    ) throws {
        for operation in operations {
            guard case let .addPhase(id, name) = operation else { continue }
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: projectID, phaseID: id, name: name,
                mode: .governed, connection: connection
            )
        }
        for operation in operations {
            guard case let .addUnassignedTicket(id, outcome) = operation else { continue }
            try DeliveryPlanningPolicy.upsertUnassignedTicket(
                projectID: projectID, ticketID: id, outcome: outcome, connection: connection
            )
        }
        for operation in operations {
            guard case let .placeTicket(ticketID, phaseID) = operation else { continue }
            let revision = try connection.scalarInt(
                "SELECT revision FROM phase_plans WHERE project_id = ? AND phase_id = ?",
                bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
            ) ?? 0
            _ = try DeliveryPlanningPolicy.placeUnassignedTicket(
                projectID: projectID, ticketID: ticketID, phaseID: phaseID,
                expectedPlanRevision: revision, connection: connection
            )
        }

        var phaseOrder: [PhaseID] = []
        var goalsByPhase: [PhaseID: [DeliveryGoalDraft]] = [:]
        var assignmentsByPhase: [PhaseID: [DeliveryGoalAssignment]] = [:]
        for operation in operations {
            switch operation {
            case let .addDeliveryGoal(phaseID, goal):
                if goalsByPhase[phaseID] == nil && assignmentsByPhase[phaseID] == nil { phaseOrder.append(phaseID) }
                goalsByPhase[phaseID, default: []].append(goal)
            case let .assignTicketToGoal(ticketID, phaseID, goalID):
                if goalsByPhase[phaseID] == nil && assignmentsByPhase[phaseID] == nil { phaseOrder.append(phaseID) }
                assignmentsByPhase[phaseID, default: []].append(.init(goalID: goalID, ticketID: ticketID))
            default:
                break
            }
        }
        for phaseID in phaseOrder {
            let revision = try connection.scalarInt(
                "SELECT revision FROM phase_plans WHERE project_id = ? AND phase_id = ?",
                bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
            ) ?? 0
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: phaseID, expectedRevision: revision,
                goalUpserts: goalsByPhase[phaseID] ?? [],
                assignments: assignmentsByPhase[phaseID] ?? [],
                unassignedTicketIDs: [], supersededGoalIDs: [],
                auditEventID: auditEventID, connection: connection
            )
        }
        for operation in operations {
            guard case let .moveBacklogTicket(ticketID, _, toPhaseID) = operation else { continue }
            guard let outcome = try connection.scalarText(
                "SELECT outcome FROM tickets WHERE project_id=? AND id=?",
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
            ) else { throw PlanChangeProposalError.invalidStoredProposal }
            try DeliveryPlanningPolicy.upsertTicket(
                projectID: projectID, ticketID: ticketID, phaseID: toPhaseID,
                outcome: outcome, lane: .backlog, auditEventID: auditEventID,
                connection: connection
            )
        }
        for operation in operations {
            guard case let .reassignTicketToGoal(ticketID, phaseID, _, toGoalID) = operation else { continue }
            let revision = try connection.scalarInt(
                "SELECT revision FROM phase_plans WHERE project_id=? AND phase_id=?",
                bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
            ) ?? 0
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: phaseID, expectedRevision: revision,
                goalUpserts: [], assignments: [.init(goalID: toGoalID, ticketID: ticketID)],
                unassignedTicketIDs: [], supersededGoalIDs: [], auditEventID: auditEventID,
                connection: connection
            )
        }
        for operation in operations {
            guard case let .addPendingTicketTasks(ticketID, tasks) = operation else { continue }
            let current = try connection.scalarInt(
                "SELECT revision FROM ticket_task_plans WHERE project_id = ? AND ticket_id = ?",
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
            )
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: projectID, ticketID: ticketID, expectedRevision: current,
                additions: tasks, definitionRevisions: [], supersededTaskIDs: [],
                connection: connection
            )
        }
        for operation in operations {
            guard case let .retireTicket(ticketID, disposition, reason, successorTicketIDs) = operation else { continue }
            guard let ticket = try connection.row(
                "SELECT phase_id,lane FROM tickets WHERE project_id=? AND id=?",
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
            ) else {
                throw PlanChangeProposalError.invalidOperation("Retirement must name an available ticket.")
            }
            let phaseID: String?
            if case let .text(value)? = ticket["phase_id"] { phaseID = value } else { phaseID = nil }
            let lane: String?
            if case let .text(value)? = ticket["lane"] { lane = value } else { lane = nil }
            guard lane != TicketLane.accepted.rawValue else {
                throw PlanChangeProposalError.invalidOperation("Accepted tickets are immutable. Create separate follow-up work.")
            }
            if let phaseID, lane != nil,
               let previousGoal = try connection.scalarText(
                    "SELECT goal_id FROM delivery_goal_ticket_assignments WHERE project_id=? AND ticket_id=?",
                    bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
               ) {
                let revision = (try connection.scalarInt(
                    "SELECT revision FROM phase_plans WHERE project_id=? AND phase_id=?",
                    bindings: [.text(projectID.rawValue), .text(phaseID)]
                ) ?? 0) + 1
                try connection.execute(
                    "DELETE FROM delivery_goal_ticket_assignments WHERE project_id=? AND ticket_id=?",
                    bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                )
                try connection.execute(
                    """
                    INSERT INTO delivery_goal_assignment_events (
                        audit_event_id,project_id,phase_id,ticket_id,previous_goal_id,
                        current_goal_id,revision,action
                    ) VALUES (?,?,?,?,?,NULL,?,'unassigned')
                    """,
                    bindings: [
                        .text(auditEventID.rawValue), .text(projectID.rawValue), .text(phaseID),
                        .text(ticketID.rawValue), .text(previousGoal), .integer(revision),
                    ]
                )
                try connection.execute(
                    "UPDATE phase_plans SET state='draft',revision=?,ready_revision=NULL,finalized_at=NULL,updated_at=? WHERE project_id=? AND phase_id=?",
                    bindings: [.integer(revision), .text(timestamp()), .text(projectID.rawValue), .text(phaseID)]
                )
            }
            try connection.execute(
                """
                INSERT INTO ticket_retirements (
                    project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at
                ) VALUES (?,?,?,?,?,?,?,?)
                """,
                bindings: [
                    .text(projectID.rawValue), .text(ticketID.rawValue), .text(disposition.rawValue),
                    .text(reason), phaseID.map(SQLiteValue.text) ?? .null,
                    lane.map(SQLiteValue.text) ?? .null, .text(auditEventID.rawValue), .text(timestamp()),
                ]
            )
            let relation = disposition == .replaced ? "replacement" : disposition.rawValue
            for (index, successorTicketID) in successorTicketIDs.enumerated() {
                try connection.execute(
                    """
                    INSERT INTO ticket_successor_links (
                        project_id,original_ticket_id,successor_ticket_id,relation,
                        sort_order,audit_event_id,created_at
                    ) VALUES (?,?,?,?,?,?,?)
                    """,
                    bindings: [
                        .text(projectID.rawValue), .text(ticketID.rawValue),
                        .text(successorTicketID.rawValue), .text(relation), .integer(Int64(index)),
                        .text(auditEventID.rawValue), .text(timestamp()),
                    ]
                )
            }
        }
        for operation in operations {
            guard case let .supersedeDeliveryGoal(phaseID, goalID) = operation else { continue }
            let revision = try connection.scalarInt(
                "SELECT revision FROM phase_plans WHERE project_id=? AND phase_id=?",
                bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
            ) ?? 0
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: phaseID, expectedRevision: revision,
                goalUpserts: [], assignments: [], unassignedTicketIDs: [],
                supersededGoalIDs: [goalID], auditEventID: auditEventID,
                connection: connection
            )
        }
        for operation in operations {
            switch operation {
            case let .carryGoalObligation(source, descendants, reason):
                for descendant in descendants {
                    try connection.execute(
                        """
                        INSERT INTO delivery_goal_obligation_lineage (
                            project_id,source_phase_id,source_goal_id,source_ticket_id,
                            descendant_phase_id,descendant_goal_id,descendant_ticket_id,
                            reason,audit_event_id,created_at
                        ) VALUES (?,?,?,?,?,?,?,?,?,?)
                        """,
                        bindings: [
                            .text(projectID.rawValue), .text(source.phaseID.rawValue),
                            .text(source.goalID.rawValue), .text(source.ticketID.rawValue),
                            .text(descendant.phaseID.rawValue), .text(descendant.goalID.rawValue),
                            .text(descendant.ticketID.rawValue), .text(reason),
                            .text(auditEventID.rawValue), .text(timestamp()),
                        ]
                    )
                }
            case let .dropGoalObligation(obligation, reason):
                try connection.execute(
                    """
                    INSERT INTO delivery_goal_obligation_drops (
                        project_id,phase_id,goal_id,ticket_id,reason,audit_event_id,created_at
                    ) VALUES (?,?,?,?,?,?,?)
                    """,
                    bindings: [
                        .text(projectID.rawValue), .text(obligation.phaseID.rawValue),
                        .text(obligation.goalID.rawValue), .text(obligation.ticketID.rawValue),
                        .text(reason), .text(auditEventID.rawValue), .text(timestamp()),
                    ]
                )
            default:
                break
            }
        }
        for operation in operations {
            switch operation {
            case let .addPhaseDependency(id, phaseID, dependsOnPhaseID):
                try connection.execute(
                    "INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES (?, ?, ?, ?)",
                    bindings: [.text(id.rawValue), .text(projectID.rawValue), .text(phaseID.rawValue), .text(dependsOnPhaseID.rawValue)]
                )
            case let .addTicketDependency(id, ticketID, dependsOnTicketID):
                try connection.execute(
                    "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES (?, ?, ?, ?)",
                    bindings: [.text(id.rawValue), .text(projectID.rawValue), .text(ticketID.rawValue), .text(dependsOnTicketID.rawValue)]
                )
            case let .retargetTicketDependency(id, ticketID, fromDependsOnTicketID, toDependsOnTicketID):
                try connection.execute(
                    "UPDATE ticket_dependencies SET depends_on_ticket_id=? WHERE project_id=? AND id=? AND ticket_id=? AND depends_on_ticket_id=?",
                    bindings: [
                        .text(toDependsOnTicketID.rawValue), .text(projectID.rawValue), .text(id.rawValue),
                        .text(ticketID.rawValue), .text(fromDependsOnTicketID.rawValue),
                    ]
                )
            case let .removeTicketDependency(id, ticketID, dependsOnTicketID):
                try connection.execute(
                    "DELETE FROM ticket_dependencies WHERE project_id=? AND id=? AND ticket_id=? AND depends_on_ticket_id=?",
                    bindings: [
                        .text(projectID.rawValue), .text(id.rawValue), .text(ticketID.rawValue),
                        .text(dependsOnTicketID.rawValue),
                    ]
                )
            default:
                break
            }
        }
    }

    static func captureSourceImpacts(
        for operations: [PlanChangeOperation],
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> [PlanChangeRecordedSourceImpact] {
        let ticketIDs = Set(operations.flatMap { operation -> [TicketID] in
            switch operation {
            case let .addPendingTicketTasks(ticketID, _),
                 let .placeTicket(ticketID, _),
                 let .assignTicketToGoal(ticketID, _, _):
                [ticketID]
            case let .addTicketDependency(_, ticketID, dependsOnTicketID):
                [ticketID, dependsOnTicketID]
            case let .retireTicket(ticketID, _, _, successorTicketIDs):
                [ticketID] + successorTicketIDs
            case let .moveBacklogTicket(ticketID, _, _),
                 let .reassignTicketToGoal(ticketID, _, _, _):
                [ticketID]
            case let .carryGoalObligation(source, descendants, _):
                [source.ticketID] + descendants.map(\.ticketID)
            case let .dropGoalObligation(obligation, _):
                [obligation.ticketID]
            case let .retargetTicketDependency(_, ticketID, fromDependsOnTicketID, toDependsOnTicketID):
                [ticketID, fromDependsOnTicketID, toDependsOnTicketID]
            case let .removeTicketDependency(_, ticketID, dependsOnTicketID):
                [ticketID, dependsOnTicketID]
            default:
                []
            }
        }).sorted { $0.rawValue < $1.rawValue }
        var impacts: [PlanChangeRecordedSourceImpact] = []
        for ticketID in ticketIDs {
            let rows = try connection.rows(
                """
                SELECT links.id, links.kind, links.repository_id, links.artifact_id,
                       versions.version, versions.content_digest, versions.source_local_id,
                       versions.observed_path, versions.observed_lifecycle, versions.observed_authority
                FROM ticket_reference_links links
                JOIN ticket_reference_versions versions
                  ON versions.project_id = links.project_id
                 AND versions.ticket_id = links.ticket_id
                 AND versions.link_id = links.id
                 AND versions.version = links.current_version
                WHERE links.project_id = ? AND links.ticket_id = ?
                ORDER BY links.kind, links.id
                """,
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)],
                maximum: 4096
            )
            for row in rows {
                guard case let .text(linkID)? = row["id"],
                      case let .text(rawKind)? = row["kind"],
                      let kind = TicketReferenceKind(rawValue: rawKind),
                      case let .text(repositoryID)? = row["repository_id"],
                      case let .text(artifactID)? = row["artifact_id"],
                      case let .integer(version)? = row["version"],
                      case let .text(contentDigest)? = row["content_digest"],
                      case let .text(observedPath)? = row["observed_path"],
                      case let .text(rawLifecycle)? = row["observed_lifecycle"],
                      let lifecycle = RepositoryDocumentArtifact.Lifecycle(rawValue: rawLifecycle),
                      case let .text(rawAuthority)? = row["observed_authority"],
                      let authority = RepositoryDocumentArtifact.Authority(rawValue: rawAuthority) else {
                    throw PlanChangeProposalError.invalidStoredProposal
                }
                let sourceLocalID: String? = if case let .text(value)? = row["source_local_id"] { value } else { nil }
                impacts.append(.init(
                    ticketID: ticketID, linkID: linkID, kind: kind,
                    repositoryID: repositoryID, artifactID: artifactID, version: version,
                    contentDigest: contentDigest, sourceLocalID: sourceLocalID,
                    observedPath: observedPath, observedLifecycle: lifecycle,
                    observedAuthority: authority
                ))
            }
        }
        return impacts
    }

    static func sourceImpacts(
        for command: AgentCommand,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> [PlanChangeRecordedSourceImpact] {
        switch command {
        case let .savePlanChangeProposal(_, _, _, operations):
            return try captureSourceImpacts(
                for: operations,
                projectID: projectID,
                connection: connection
            )
        case let .decidePlanChangeProposal(proposalID, version, _, _, _),
             let .applyPlanChangeProposal(proposalID, version, _, _, _):
            guard let row = try storedVersion(
                projectID: projectID,
                proposalID: .init(rawValue: proposalID),
                version: version,
                connection: connection
            ) else {
                return []
            }
            guard case let .blob(data)? = row["source_impacts_data"] else {
                throw PlanChangeProposalError.invalidStoredProposal
            }
            return try JSONDecoder().decode([PlanChangeRecordedSourceImpact].self, from: data)
        default:
            return []
        }
    }

    private static func storedVersion(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64,
        connection: SQLiteConnection
    ) throws -> [String: SQLiteValue]? {
        try connection.row(
            "SELECT * FROM plan_change_proposal_versions WHERE project_id = ? AND proposal_id = ? AND version = ?",
            bindings: [.text(projectID.rawValue), .text(proposalID.rawValue), .integer(version)]
        )
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

public enum PlanChangeProposalQuery {
    public static func load(
        from store: DeliveryStore,
        projectID: ProjectID
    ) async throws -> [PlanChangeProposalRecord] {
        try await store.read { connection in
            try load(from: connection, projectID: projectID)
        }
    }

    public static func load(
        from connection: SQLiteConnection,
        projectID: ProjectID
    ) throws -> [PlanChangeProposalRecord] {
        let proposalRows = try connection.rows(
                "SELECT id, current_version FROM plan_change_proposals WHERE project_id = ? ORDER BY updated_at DESC, id COLLATE BINARY",
                bindings: [.text(projectID.rawValue)],
                maximum: 4096
            )
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        return try proposalRows.map { row in
                guard case let .text(proposalID)? = row["id"],
                      case let .integer(currentVersion)? = row["current_version"] else {
                    throw PlanChangeProposalError.invalidStoredProposal
                }
                let versionRows = try connection.rows(
                    """
                    SELECT versions.*, decisions.id AS decision_id, decisions.disposition,
                           decisions.actor_id, decisions.baseline_digest AS decision_baseline_digest,
                           decisions.registration_id AS decision_registration_id,
                           decisions.request_generation AS decision_request_generation,
                           decisions.created_at AS decision_created_at,
                           applications.id AS application_id, applications.decision_id AS application_decision_id,
                           applications.audit_event_id, applications.applied_at
                    FROM plan_change_proposal_versions versions
                    LEFT JOIN plan_change_proposal_decisions decisions
                      ON decisions.project_id = versions.project_id
                     AND decisions.proposal_id = versions.proposal_id
                     AND decisions.version = versions.version
                    LEFT JOIN plan_change_proposal_applications applications
                      ON applications.project_id = versions.project_id
                     AND applications.proposal_id = versions.proposal_id
                     AND applications.version = versions.version
                    WHERE versions.project_id = ? AND versions.proposal_id = ?
                    ORDER BY versions.version DESC
                    """,
                    bindings: [.text(projectID.rawValue), .text(proposalID)],
                    maximum: 4096
                )
                let versions = try versionRows.map { versionRow -> PlanChangeProposalVersionRecord in
                    guard case let .integer(version)? = versionRow["version"],
                          case let .text(registrationID)? = versionRow["registration_id"],
                          case let .integer(generation)? = versionRow["request_generation"],
                          case let .text(baselineDigest)? = versionRow["baseline_digest"],
                          case let .blob(baseline)? = versionRow["baseline_data"],
                          case let .blob(operationData)? = versionRow["operations_data"],
                          case let .blob(diffData)? = versionRow["diff_data"],
                          case let .blob(sourceImpactData)? = versionRow["source_impacts_data"],
                          case let .text(rationale)? = versionRow["rationale"],
                          case let .text(createdAtText)? = versionRow["created_at"],
                          let createdAt = formatter.date(from: createdAtText) else {
                        throw PlanChangeProposalError.invalidStoredProposal
                    }
                    let decision: PlanChangeDecisionRecord?
                    if case let .text(id)? = versionRow["decision_id"],
                       case let .text(rawDisposition)? = versionRow["disposition"],
                       let disposition = PlanChangeDecisionDisposition(rawValue: rawDisposition),
                       case let .text(actorID)? = versionRow["actor_id"],
                       case let .text(decisionBaselineDigest)? = versionRow["decision_baseline_digest"],
                       case let .text(decisionRegistrationID)? = versionRow["decision_registration_id"],
                       case let .integer(decisionGeneration)? = versionRow["decision_request_generation"],
                       case let .text(decidedAtText)? = versionRow["decision_created_at"],
                       let decidedAt = formatter.date(from: decidedAtText) {
                        decision = .init(
                            id: id, disposition: disposition, actorID: actorID,
                            baselineDigest: decisionBaselineDigest,
                            registration: .init(
                                projectID: projectID,
                                registrationID: decisionRegistrationID,
                                requestGeneration: decisionGeneration
                            ),
                            createdAt: decidedAt
                        )
                    } else {
                        decision = nil
                    }
                    let application: PlanChangeApplicationRecord?
                    if case let .text(id)? = versionRow["application_id"],
                       case let .text(decisionID)? = versionRow["application_decision_id"],
                       case let .text(auditID)? = versionRow["audit_event_id"],
                       case let .text(appliedAtText)? = versionRow["applied_at"],
                       let appliedAt = formatter.date(from: appliedAtText) {
                        application = .init(
                            id: id,
                            decisionID: decisionID,
                            auditEventID: .init(rawValue: auditID),
                            appliedAt: appliedAt
                        )
                    } else {
                        application = nil
                    }
                    return .init(
                        version: version,
                        registration: .init(
                            projectID: projectID,
                            registrationID: registrationID,
                            requestGeneration: generation
                        ),
                        baselineDigest: baselineDigest,
                        baseline: baseline,
                        operations: try decoder.decode([PlanChangeOperation].self, from: operationData),
                        diff: try decoder.decode(PlanChangeDiff.self, from: diffData),
                        sourceImpacts: try decoder.decode([PlanChangeRecordedSourceImpact].self, from: sourceImpactData),
                        rationale: rationale,
                        createdAt: createdAt,
                        decision: decision,
                        application: application
                    )
                }
                return .init(
                    id: .init(rawValue: proposalID),
                    projectID: projectID,
                    currentVersion: currentVersion,
                    versions: versions
                )
        }
    }
}

enum PlanningBaseline {
    private struct Section: Codable {
        let name: String
        let rows: [[String]]
    }

    static func capture(projectID: ProjectID, connection: SQLiteConnection) throws -> Data {
        let project = SQLiteValue.text(projectID.rawValue)
        let queries: [(String, String, [SQLiteValue])] = [
            ("project", "SELECT id,name,lifecycle,first_dashboard_opened FROM projects WHERE id=?", [project]),
            ("registration", "SELECT project_id,registration_id,request_generation,setup_state FROM project_registrations WHERE project_id=?", [project]),
            ("active_phase", "SELECT project_id,phase_id FROM project_active_phases WHERE project_id=?", [project]),
            ("phases", "SELECT id,project_id,name FROM phases WHERE project_id=? ORDER BY id COLLATE BINARY", [project]),
            ("phase_plans", "SELECT * FROM phase_plans WHERE project_id=? ORDER BY phase_id COLLATE BINARY", [project]),
            ("goals", "SELECT * FROM delivery_goals WHERE project_id=? ORDER BY phase_id COLLATE BINARY,id COLLATE BINARY", [project]),
            ("goal_criteria", "SELECT * FROM delivery_goal_done_criteria WHERE project_id=? ORDER BY phase_id COLLATE BINARY,goal_id COLLATE BINARY,sort_order", [project]),
            ("goal_assignments", "SELECT * FROM delivery_goal_ticket_assignments WHERE project_id=? ORDER BY phase_id COLLATE BINARY,ticket_id COLLATE BINARY", [project]),
            ("goal_obligations", "SELECT * FROM delivery_goal_obligations WHERE project_id=? ORDER BY phase_id COLLATE BINARY,goal_id COLLATE BINARY,ticket_id COLLATE BINARY", [project]),
            ("goal_obligation_lineage", "SELECT * FROM delivery_goal_obligation_lineage WHERE project_id=? ORDER BY source_phase_id COLLATE BINARY,source_goal_id COLLATE BINARY,source_ticket_id COLLATE BINARY,descendant_phase_id COLLATE BINARY,descendant_goal_id COLLATE BINARY,descendant_ticket_id COLLATE BINARY", [project]),
            ("goal_obligation_drops", "SELECT * FROM delivery_goal_obligation_drops WHERE project_id=? ORDER BY phase_id COLLATE BINARY,goal_id COLLATE BINARY,ticket_id COLLATE BINARY", [project]),
            ("tickets", "SELECT * FROM tickets WHERE project_id=? ORDER BY id COLLATE BINARY", [project]),
            ("ticket_retirements", "SELECT * FROM ticket_retirements WHERE project_id=? ORDER BY ticket_id COLLATE BINARY", [project]),
            ("ticket_successors", "SELECT * FROM ticket_successor_links WHERE project_id=? ORDER BY original_ticket_id COLLATE BINARY,sort_order,successor_ticket_id COLLATE BINARY", [project]),
            ("task_plans", "SELECT * FROM ticket_task_plans WHERE project_id=? ORDER BY ticket_id COLLATE BINARY", [project]),
            ("tasks", "SELECT * FROM ticket_tasks WHERE project_id=? ORDER BY ticket_id COLLATE BINARY,id COLLATE BINARY", [project]),
            ("phase_dependencies", "SELECT * FROM phase_dependencies WHERE project_id=? ORDER BY id COLLATE BINARY", [project]),
            ("ticket_dependencies", "SELECT * FROM ticket_dependencies WHERE project_id=? ORDER BY id COLLATE BINARY", [project]),
            ("reference_sets", "SELECT * FROM ticket_reference_link_sets WHERE project_id=? ORDER BY ticket_id COLLATE BINARY", [project]),
            ("reference_links", "SELECT * FROM ticket_reference_links WHERE project_id=? ORDER BY ticket_id COLLATE BINARY,id COLLATE BINARY", [project]),
            ("reference_versions", "SELECT * FROM ticket_reference_versions WHERE project_id=? ORDER BY ticket_id COLLATE BINARY,link_id COLLATE BINARY,version", [project]),
            ("evidence", "SELECT * FROM evidence WHERE project_id=? ORDER BY ticket_id COLLATE BINARY,id COLLATE BINARY", [project]),
            ("ticket_threads", "SELECT * FROM thread_links WHERE project_id=? ORDER BY ticket_id COLLATE BINARY,thread_id COLLATE BINARY", [project]),
            ("ticket_goal_links", "SELECT * FROM ticket_goal_links WHERE project_id=? ORDER BY ticket_id COLLATE BINARY,thread_id COLLATE BINARY,goal_id COLLATE BINARY", [project]),
            ("documentation_binding", "SELECT * FROM project_documentation_bindings WHERE project_id=?", [project]),
            ("recovery_authority", "SELECT * FROM application_recovery_state WHERE singleton_id=1", []),
        ]
        let sections = try queries.map { name, sql, bindings in
            let rows = try connection.rows(sql, bindings: bindings, maximum: 20_000).map { row in
                row.keys.sorted().map { key in "\(key)=\(encode(row[key] ?? .null))" }
            }
            return Section(name: name, rows: rows)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(sections)
    }

    static func changedCategories(from saved: Data, to current: Data) throws -> [PlanChangeBaselineCategory] {
        let decoder = JSONDecoder()
        let savedSections = try decoder.decode([Section].self, from: saved)
        let currentSections = try decoder.decode([Section].self, from: current)
        let savedByName = Dictionary(uniqueKeysWithValues: savedSections.map { ($0.name, $0.rows) })
        let currentByName = Dictionary(uniqueKeysWithValues: currentSections.map { ($0.name, $0.rows) })
        return PlanChangeBaselineCategory.allCases.filter {
            savedByName[$0.rawValue] != currentByName[$0.rawValue]
        }
    }

    private static func encode(_ value: SQLiteValue) -> String {
        switch value {
        case .null: "n"
        case let .integer(value): "i:\(value)"
        case let .real(value): "r:\(value.bitPattern)"
        case let .text(value): "t:\(Data(value.utf8).base64EncodedString())"
        case let .blob(value): "b:\(value.base64EncodedString())"
        }
    }
}

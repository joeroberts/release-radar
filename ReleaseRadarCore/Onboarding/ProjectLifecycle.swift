import Foundation

public enum ProjectLifecycle: String, Codable, Equatable, Sendable {
    case active
    case archived
}

public enum ProjectLifecycleTransition: String, Codable, Equatable, Sendable {
    case archive
    case restore

    var source: ProjectLifecycle { self == .archive ? .active : .archived }
    var target: ProjectLifecycle { self == .archive ? .archived : .active }
}

public struct ProjectLifecycleCounts: Codable, Equatable, Sendable {
    public let phases: Int64
    public let tickets: Int64
    public let evidence: Int64
    public let history: Int64

    public init(phases: Int64, tickets: Int64, evidence: Int64, history: Int64) {
        self.phases = phases
        self.tickets = tickets
        self.evidence = evidence
        self.history = history
    }
}

public struct ProjectLifecycleSnapshot: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let projectName: String
    public let lifecycle: ProjectLifecycle
    public let registration: ProjectRegistration
    public let counts: ProjectLifecycleCounts

    public init(
        projectID: ProjectID,
        projectName: String,
        lifecycle: ProjectLifecycle,
        registration: ProjectRegistration,
        counts: ProjectLifecycleCounts
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.lifecycle = lifecycle
        self.registration = registration
        self.counts = counts
    }
}

public struct ProjectLifecyclePreview: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let projectName: String
    public let source: ProjectLifecycle
    public let target: ProjectLifecycle
    public let registration: ProjectRegistration
    public let counts: ProjectLifecycleCounts

    public init(
        projectID: ProjectID,
        projectName: String,
        source: ProjectLifecycle,
        target: ProjectLifecycle,
        registration: ProjectRegistration,
        counts: ProjectLifecycleCounts
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.source = source
        self.target = target
        self.registration = registration
        self.counts = counts
    }
}

public enum ProjectLifecycleError: Error, LocalizedError, Equatable, Sendable {
    case projectNotFound
    case invalidTransition(expected: ProjectLifecycle, found: ProjectLifecycle)
    case stalePreview
    case generationOverflow

    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            "The project no longer exists. Reload Projects and try again."
        case let .invalidTransition(expected, found):
            "The project is \(found.rawValue), but this action requires it to be \(expected.rawValue). Reload Projects and try again."
        case .stalePreview:
            "The project changed after this confirmation was prepared. Review the latest project details and try again."
        case .generationOverflow:
            "The project request generation cannot be advanced. Contact support before changing its archive state."
        }
    }
}

public actor ProjectLifecycleManager {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func snapshot(projectID: ProjectID) async throws -> ProjectLifecycleSnapshot {
        try await store.read { connection in
            try Self.snapshot(projectID: projectID, connection: connection)
        }
    }

    public func preview(
        projectID: ProjectID,
        transition: ProjectLifecycleTransition
    ) async throws -> ProjectLifecyclePreview {
        let current = try await snapshot(projectID: projectID)
        guard current.lifecycle == transition.source else {
            throw ProjectLifecycleError.invalidTransition(expected: transition.source, found: current.lifecycle)
        }
        return .init(
            projectID: current.projectID,
            projectName: current.projectName,
            source: transition.source,
            target: transition.target,
            registration: current.registration,
            counts: current.counts
        )
    }

    public func apply(_ preview: ProjectLifecyclePreview) async throws -> ProjectLifecycleSnapshot {
        try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: preview.target == .archived ? "Archive project" : "Restore project",
            auditScope: .init(projectID: preview.projectID, entityType: .project, entityID: preview.projectID.rawValue)
        ) { connection in
            let current = try Self.snapshot(projectID: preview.projectID, connection: connection)
            guard current.projectName == preview.projectName,
                  current.lifecycle == preview.source,
                  current.registration == preview.registration,
                  current.counts == preview.counts else {
                throw ProjectLifecycleError.stalePreview
            }
            let (generation, overflow) = current.registration.requestGeneration.addingReportingOverflow(1)
            guard !overflow else { throw ProjectLifecycleError.generationOverflow }

            if preview.target == .archived {
                let completedAt = ISO8601DateFormatter().string(from: Date())
                try connection.execute(
                    "UPDATE notification_events SET state = 'suppressed', completed_at = ?, failure_code = 'project_archived' WHERE project_id = ? AND state = 'queued'",
                    bindings: [.text(completedAt), .text(preview.projectID.rawValue)]
                )
                try connection.execute(
                    "UPDATE notification_events SET state = 'unknown', completed_at = ?, failure_code = 'archive_ambiguous_attempt' WHERE project_id = ? AND state = 'attempt_started'",
                    bindings: [.text(completedAt), .text(preview.projectID.rawValue)]
                )
                try connection.execute(
                    "UPDATE notification_occurrences SET is_active = 0 WHERE project_id = ? AND is_active = 1",
                    bindings: [.text(preview.projectID.rawValue)]
                )
            }
            try connection.execute(
                "UPDATE project_registrations SET request_generation = ? WHERE project_id = ?",
                bindings: [.integer(generation), .text(preview.projectID.rawValue)]
            )
            try connection.execute(
                "UPDATE projects SET lifecycle = ? WHERE id = ? AND lifecycle = ?",
                bindings: [.text(preview.target.rawValue), .text(preview.projectID.rawValue), .text(preview.source.rawValue)]
            )
        }
        return try await snapshot(projectID: preview.projectID)
    }

    public static func requireActive(projectID: ProjectID, connection: SQLiteConnection) throws {
        guard try connection.scalarInt(
            "SELECT COUNT(*) FROM projects WHERE id = ? AND lifecycle = 'active'",
            bindings: [.text(projectID.rawValue)]
        ) == 1 else {
            throw ProjectLifecycleError.invalidTransition(expected: .active, found: .archived)
        }
    }

    static func requireCurrentAuthorization(
        projectID: ProjectID,
        registration: ProjectRegistration?,
        connection: SQLiteConnection
    ) throws {
        try requireActive(projectID: projectID, connection: connection)
        if let registration {
            guard registration.projectID == projectID,
                  try connection.scalarInt(
                      "SELECT COUNT(*) FROM project_registrations WHERE project_id = ? AND registration_id = ? AND request_generation = ?",
                      bindings: [
                          .text(projectID.rawValue),
                          .text(registration.registrationID),
                          .integer(registration.requestGeneration),
                      ]
                  ) == 1 else {
                throw ProjectLifecycleError.stalePreview
            }
        } else {
            // Mutation compatibility is limited to projects that genuinely predate
            // registration; a registered project may never use an unversioned grant.
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM project_registrations WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            ) == 0 else {
                throw ProjectLifecycleError.stalePreview
            }
        }
    }

    static func receiptScopeMatches(
        _ row: [String: SQLiteValue],
        registration: ProjectRegistration?
    ) -> Bool {
        guard let registration else {
            return row["registration_project_id"] == .null
                && row["registration_id"] == .null
                && row["request_generation"] == .null
        }
        return row["registration_project_id"] == .text(registration.projectID.rawValue)
            && row["registration_id"] == .text(registration.registrationID)
            && row["request_generation"] == .integer(registration.requestGeneration)
    }

    static func receiptScopeBindings(_ registration: ProjectRegistration?) -> [SQLiteValue] {
        guard let registration else { return [.null, .null, .null] }
        return [
            .text(registration.projectID.rawValue),
            .text(registration.registrationID),
            .integer(registration.requestGeneration),
        ]
    }

    fileprivate static func snapshot(
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> ProjectLifecycleSnapshot {
        guard let row = try connection.row(
            """
            SELECT projects.name, projects.lifecycle, project_registrations.registration_id,
                   project_registrations.request_generation
            FROM projects
            JOIN project_registrations ON project_registrations.project_id = projects.id
            WHERE projects.id = ?
            """,
            bindings: [.text(projectID.rawValue)]
        ), case let .text(name)? = row["name"],
           case let .text(rawLifecycle)? = row["lifecycle"],
           let lifecycle = ProjectLifecycle(rawValue: rawLifecycle),
           case let .text(registrationID)? = row["registration_id"],
           case let .integer(generation)? = row["request_generation"] else {
            throw ProjectLifecycleError.projectNotFound
        }
        func count(_ table: String) throws -> Int64 {
            try connection.scalarInt(
                "SELECT COUNT(*) FROM \(table) WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            ) ?? 0
        }
        return .init(
            projectID: projectID,
            projectName: name,
            lifecycle: lifecycle,
            registration: .init(projectID: projectID, registrationID: registrationID, requestGeneration: generation),
            counts: .init(
                phases: try count("phases"),
                tickets: try count("tickets"),
                evidence: try count("evidence"),
                history: try count("audit_events")
            )
        )
    }
}

public struct ProjectRemovalID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct ProjectRemovalPreview: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let projectName: String
    public let lifecycle: ProjectLifecycle
    public let registration: ProjectRegistration
    public let counts: ProjectLifecycleCounts

    public init(
        projectID: ProjectID,
        projectName: String,
        lifecycle: ProjectLifecycle,
        registration: ProjectRegistration,
        counts: ProjectLifecycleCounts
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.lifecycle = lifecycle
        self.registration = registration
        self.counts = counts
    }
}

public struct RemovedProjectRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: ProjectRemovalID
    public let projectID: ProjectID
    public let projectName: String
    public let originalLifecycle: ProjectLifecycle
    public let registration: ProjectRegistration
    public let removedAt: Date
    public let counts: ProjectLifecycleCounts

    public init(
        id: ProjectRemovalID,
        projectID: ProjectID,
        projectName: String,
        originalLifecycle: ProjectLifecycle,
        registration: ProjectRegistration,
        removedAt: Date,
        counts: ProjectLifecycleCounts
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.originalLifecycle = originalLifecycle
        self.registration = registration
        self.removedAt = removedAt
        self.counts = counts
    }
}

public enum ProjectRemovalError: Error, LocalizedError, Equatable, Sendable {
    case projectNotFound
    case alreadyRemoved
    case removalRecordNotFound
    case stalePreview

    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            "The project no longer exists. Reload Projects and try again."
        case .alreadyRemoved:
            "This project registration was already removed. Its retained history is available under Removed Projects."
        case .removalRecordNotFound:
            "The retained project record is unavailable. Return to Projects and choose it again."
        case .stalePreview:
            "The project changed after this removal confirmation was prepared. Review the latest counts and try again."
        }
    }
}

public actor ProjectRemovalManager {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func preview(projectID: ProjectID) async throws -> ProjectRemovalPreview {
        try await store.read { connection in
            do {
                let snapshot = try ProjectLifecycleManager.snapshot(projectID: projectID, connection: connection)
                return .init(
                    projectID: snapshot.projectID,
                    projectName: snapshot.projectName,
                    lifecycle: snapshot.lifecycle,
                    registration: snapshot.registration,
                    counts: snapshot.counts
                )
            } catch ProjectLifecycleError.projectNotFound {
                if try connection.scalarInt(
                    "SELECT COUNT(*) FROM removed_projects WHERE historical_project_id = ?",
                    bindings: [.text(projectID.rawValue)]
                ) ?? 0 > 0 {
                    throw ProjectRemovalError.alreadyRemoved
                }
                throw ProjectRemovalError.projectNotFound
            }
        }
    }

    public func apply(_ preview: ProjectRemovalPreview) async throws -> RemovedProjectRecord {
        let removalID = ProjectRemovalID(rawValue: UUID().uuidString)
        let formatter = ISO8601DateFormatter()
        let removedAtText = formatter.string(from: Date())
        guard let removedAt = formatter.date(from: removedAtText) else {
            throw StoreError.unavailable("Project removal timestamp could not be recorded")
        }
        let record = RemovedProjectRecord(
            id: removalID,
            projectID: preview.projectID,
            projectName: preview.projectName,
            originalLifecycle: preview.lifecycle,
            registration: preview.registration,
            removedAt: removedAt,
            counts: preview.counts
        )
        try await store.transactRemovingProject(
            projectID: preview.projectID,
            registrationID: preview.registration.registrationID,
            removalID: removalID,
            actor: .init(id: "release-radar-owner"),
            reason: "Remove project from tracking",
        ) { connection in
            let current: ProjectLifecycleSnapshot
            do {
                current = try ProjectLifecycleManager.snapshot(projectID: preview.projectID, connection: connection)
            } catch ProjectLifecycleError.projectNotFound {
                throw ProjectRemovalError.alreadyRemoved
            }
            guard current.projectName == preview.projectName,
                  current.lifecycle == preview.lifecycle,
                  current.registration == preview.registration,
                  current.counts == preview.counts else {
                throw ProjectRemovalError.stalePreview
            }

            let project = SQLiteValue.text(preview.projectID.rawValue)
            let removal = SQLiteValue.text(removalID.rawValue)
            let completedAt = SQLiteValue.text(removedAtText)
            try connection.execute(
                """
                UPDATE notification_events
                SET state = 'suppressed', completed_at = ?, failure_code = 'project_removed'
                WHERE state = 'queued'
                  AND (project_id = ? OR (project_id IS NULL AND ticket_id IN (
                      SELECT id FROM tickets WHERE project_id = ?
                  )))
                """,
                bindings: [completedAt, project, project]
            )
            try connection.execute(
                """
                UPDATE notification_events
                SET state = 'unknown', completed_at = ?, failure_code = 'removal_ambiguous_attempt'
                WHERE state = 'attempt_started'
                  AND (project_id = ? OR (project_id IS NULL AND ticket_id IN (
                      SELECT id FROM tickets WHERE project_id = ?
                  )))
                """,
                bindings: [completedAt, project, project]
            )
            try connection.execute(
                "UPDATE notification_occurrences SET is_active = 0 WHERE project_id = ? AND is_active = 1",
                bindings: [project]
            )
            try connection.execute(
                """
                INSERT INTO removed_projects (
                    removal_id, historical_project_id, project_name, original_lifecycle,
                    registration_id, request_generation, removed_at, phase_count,
                    ticket_count, evidence_count, history_count
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    removal, project, .text(preview.projectName), .text(preview.lifecycle.rawValue),
                    .text(preview.registration.registrationID), .integer(preview.registration.requestGeneration),
                    completedAt, .integer(preview.counts.phases), .integer(preview.counts.tickets),
                    .integer(preview.counts.evidence), .integer(preview.counts.history),
                ]
            )
            try connection.execute(
                "INSERT INTO retained_phase_lifecycles SELECT ?, lifecycles.project_id, lifecycles.phase_id, phases.name, lifecycles.lifecycle, lifecycles.revision, lifecycles.completion_baseline_digest, lifecycles.created_at, lifecycles.updated_at, lifecycles.completed_at FROM phase_lifecycles lifecycles JOIN phases ON phases.project_id=lifecycles.project_id AND phases.id=lifecycles.phase_id WHERE lifecycles.project_id=?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_phase_lifecycle_events SELECT ?, project_id, phase_id, revision, previous_lifecycle, current_lifecycle, action, reason, audit_event_id, registration_id, request_generation, planning_baseline_digest, created_at FROM phase_lifecycle_events WHERE project_id=?",
                bindings: [removal, project]
            )
            try connection.execute(
                "DELETE FROM phase_lifecycle_events WHERE project_id=?",
                bindings: [project]
            )
            try Self.retainActivity(projectID: preview.projectID, removalID: removalID, connection: connection)
            try connection.execute(
                "DELETE FROM notification_events WHERE project_id IS NULL AND ticket_id IN (SELECT id FROM tickets WHERE project_id = ?)",
                bindings: [project]
            )
            try connection.execute(
                """
                INSERT INTO retained_delivery_goal_assignment_events (
                    removal_id, audit_event_id, project_id, phase_id, ticket_id,
                    previous_goal_id, current_goal_id, revision, action
                )
                SELECT ?, audit_event_id, project_id, phase_id, ticket_id,
                       previous_goal_id, current_goal_id, revision, action
                FROM delivery_goal_assignment_events WHERE project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_ticket_retirements SELECT ?, retirements.project_id, retirements.ticket_id, tickets.outcome, retirements.disposition, retirements.reason, retirements.last_phase_id, retirements.last_lane, retirements.audit_event_id, retirements.retired_at FROM ticket_retirements retirements JOIN tickets ON tickets.project_id=retirements.project_id AND tickets.id=retirements.ticket_id WHERE retirements.project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_ticket_successor_links SELECT ?, project_id, original_ticket_id, successor_ticket_id, relation, sort_order, audit_event_id, created_at FROM ticket_successor_links WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_delivery_goal_obligations SELECT ?, project_id, phase_id, goal_id, ticket_id, scope, assessment, created_at FROM delivery_goal_obligations WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_delivery_goal_obligation_lineage SELECT ?, project_id, source_phase_id, source_goal_id, source_ticket_id, descendant_phase_id, descendant_goal_id, descendant_ticket_id, reason, audit_event_id, created_at FROM delivery_goal_obligation_lineage WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_delivery_goal_obligation_drops SELECT ?, project_id, phase_id, goal_id, ticket_id, reason, audit_event_id, created_at FROM delivery_goal_obligation_drops WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute("DELETE FROM delivery_goal_obligation_lineage WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM delivery_goal_obligation_drops WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM ticket_successor_links WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM ticket_retirements WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM delivery_goal_obligations WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM delivery_goal_assignment_events WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM delivery_goal_ticket_assignments WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM delivery_goal_done_criteria WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM delivery_goals WHERE project_id = ?", bindings: [project])
            try connection.execute(
                """
                INSERT INTO retained_ticket_delivery_evidence_targets (
                    removal_id, historical_project_id, ticket_id, version, repository_id,
                    root_id, revision_data, expectations_data, registration_id,
                    request_generation, recorded_at, evidence_revision, current_target_version
                )
                SELECT ?, targets.project_id, targets.ticket_id, targets.version,
                       targets.repository_id, targets.root_id, targets.revision_data,
                       targets.expectations_data, targets.registration_id,
                       targets.request_generation, targets.recorded_at,
                       sets.revision, sets.current_target_version
                FROM ticket_delivery_evidence_targets targets
                JOIN ticket_delivery_evidence_sets sets
                  ON sets.project_id = targets.project_id AND sets.ticket_id = targets.ticket_id
                WHERE targets.project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute(
                """
                INSERT INTO retained_ticket_delivery_evidence_observations (
                    removal_id, historical_project_id, ticket_id, id, target_version,
                    fact_data, source_data, source_availability, outcome, observed_at,
                    recorded_at, attachment_evidence_id, supersedes_observation_id, append_revision
                )
                SELECT ?, project_id, ticket_id, id, target_version, fact_data,
                       source_data, source_availability, outcome, observed_at,
                       recorded_at, attachment_evidence_id, supersedes_observation_id, append_revision
                FROM ticket_delivery_evidence_observations WHERE project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute(
                "DELETE FROM ticket_delivery_evidence_observations WHERE project_id = ?",
                bindings: [project]
            )
            try connection.execute(
                "DELETE FROM ticket_delivery_evidence_targets WHERE project_id = ?",
                bindings: [project]
            )
            try connection.execute(
                "DELETE FROM ticket_delivery_evidence_sets WHERE project_id = ?",
                bindings: [project]
            )
            try connection.execute(
                """
                INSERT INTO retained_ticket_reference_links (
                    removal_id, historical_project_id, ticket_id, link_id, kind,
                    repository_id, artifact_id, current_version, relationship,
                    retired_version, retired_at, retirement_reason, link_set_revision,
                    created_at, updated_at
                )
                SELECT ?, links.project_id, links.ticket_id, links.id, links.kind,
                       links.repository_id, links.artifact_id, links.current_version,
                       links.relationship, links.retired_version, links.retired_at,
                       links.retirement_reason, sets.revision, links.created_at, links.updated_at
                FROM ticket_reference_links links
                JOIN ticket_reference_link_sets sets
                  ON sets.project_id = links.project_id AND sets.ticket_id = links.ticket_id
                WHERE links.project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute(
                """
                INSERT INTO retained_ticket_reference_versions (
                    removal_id, historical_project_id, ticket_id, link_id, version,
                    content_digest, source_local_id, locator, catalog_version,
                    catalog_digest, observed_path, observed_lifecycle,
                    observed_authority, created_at
                )
                SELECT ?, versions.project_id, versions.ticket_id, versions.link_id,
                       versions.version, versions.content_digest, versions.source_local_id,
                       versions.locator, versions.catalog_version, versions.catalog_digest,
                       versions.observed_path, versions.observed_lifecycle,
                       versions.observed_authority, versions.created_at
                FROM ticket_reference_versions versions
                WHERE versions.project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute("DELETE FROM ticket_reference_versions WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM ticket_reference_links WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM ticket_reference_link_sets WHERE project_id = ?", bindings: [project])
            try connection.execute(
                """
                INSERT INTO retained_plan_change_proposals (
                    removal_id, historical_project_id, proposal_id, current_version,
                    created_at, updated_at
                )
                SELECT ?, project_id, id, current_version, created_at, updated_at
                FROM plan_change_proposals WHERE project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute(
                """
                INSERT INTO retained_plan_change_proposal_versions (
                    removal_id, historical_project_id, proposal_id, version,
                    registration_id, request_generation, baseline_digest, baseline_data,
                    operations_data, diff_data, source_impacts_data, rationale, created_at
                )
                SELECT ?, project_id, proposal_id, version, registration_id,
                       request_generation, baseline_digest, baseline_data, operations_data,
                       diff_data, source_impacts_data, rationale, created_at
                FROM plan_change_proposal_versions WHERE project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute(
                """
                INSERT INTO retained_plan_change_proposal_decisions (
                    removal_id, historical_project_id, proposal_id, version, id,
                    disposition, baseline_digest, registration_id, request_generation,
                    actor_id, created_at
                )
                SELECT ?, project_id, proposal_id, version, id, disposition,
                       baseline_digest, registration_id, request_generation, actor_id, created_at
                FROM plan_change_proposal_decisions WHERE project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute(
                """
                INSERT INTO retained_plan_change_proposal_applications (
                    removal_id, historical_project_id, proposal_id, version, id,
                    decision_id, audit_event_id, applied_at
                )
                SELECT ?, project_id, proposal_id, version, id, decision_id,
                       audit_event_id, applied_at
                FROM plan_change_proposal_applications WHERE project_id = ?
                """,
                bindings: [removal, project]
            )
            try connection.execute("DELETE FROM plan_change_proposal_applications WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM plan_change_proposal_decisions WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM plan_change_proposal_versions WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM plan_change_proposals WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM ticket_tasks WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM ticket_task_plans WHERE project_id = ?", bindings: [project])
        }
        return record
    }

    public func record(id: ProjectRemovalID) async throws -> RemovedProjectRecord {
        try await store.read { connection in
            guard let row = try connection.row(
                "SELECT * FROM removed_projects WHERE removal_id = ?",
                bindings: [.text(id.rawValue)]
            ) else { throw ProjectRemovalError.removalRecordNotFound }
            return try Self.record(row: row)
        }
    }

    public func records() async throws -> [RemovedProjectRecord] {
        try await store.read { connection in
            var records: [RemovedProjectRecord] = []
            var offset: Int64 = 0
            while let row = try connection.row(
                "SELECT * FROM removed_projects ORDER BY removed_at DESC, removal_id LIMIT 1 OFFSET ?",
                bindings: [.integer(offset)]
            ) {
                records.append(try Self.record(row: row))
                offset += 1
            }
            return records
        }
    }

    private static func record(row: [String: SQLiteValue]) throws -> RemovedProjectRecord {
        func text(_ name: String) throws -> String {
            guard case let .text(value)? = row[name] else { throw StoreError.unavailable("Removed project record is missing \(name)") }
            return value
        }
        func integer(_ name: String) throws -> Int64 {
            guard case let .integer(value)? = row[name] else { throw StoreError.unavailable("Removed project record is missing \(name)") }
            return value
        }
        let projectID = ProjectID(rawValue: try text("historical_project_id"))
        guard let lifecycle = ProjectLifecycle(rawValue: try text("original_lifecycle")),
              let removedAt = ISO8601DateFormatter().date(from: try text("removed_at")) else {
            throw StoreError.unavailable("Removed project record has invalid lifecycle or timestamp")
        }
        return .init(
            id: .init(rawValue: try text("removal_id")),
            projectID: projectID,
            projectName: try text("project_name"),
            originalLifecycle: lifecycle,
            registration: .init(
                projectID: projectID,
                registrationID: try text("registration_id"),
                requestGeneration: try integer("request_generation")
            ),
            removedAt: removedAt,
            counts: .init(
                phases: try integer("phase_count"), tickets: try integer("ticket_count"),
                evidence: try integer("evidence_count"), history: try integer("history_count")
            )
        )
    }

    private static func retainActivity(
        projectID: ProjectID,
        removalID: ProjectRemovalID,
        connection: SQLiteConnection
    ) throws {
        let bindings: [SQLiteValue] = [.text(removalID.rawValue), .text(projectID.rawValue)]
        try connection.execute(
            """
            INSERT INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, observed_at, ticket_id,
                phase_id, delivery_goal_id, originating_thread_id, delivery_lane, runtime_state
            )
            SELECT ?, 'runtime', observed_goals.thread_id || '|' || observed_goals.id,
                   observed_goals.status, observed_goals.text,
                   observed_goals.last_observed_at, ticket_goal_links.ticket_id, NULL,
                   observed_goals.id, observed_goals.thread_id, NULL, observed_goals.status
            FROM observed_goals
            LEFT JOIN ticket_goal_links
              ON ticket_goal_links.project_id = observed_goals.project_id
             AND ticket_goal_links.goal_id = observed_goals.id
             AND ticket_goal_links.thread_id = observed_goals.thread_id
            WHERE observed_goals.project_id = ?
            """,
            bindings: bindings
        )
        try connection.execute(
            """
            INSERT INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, recorded_at, ticket_id,
                phase_id, delivery_lane
            )
            SELECT ?, 'review', review_items.id, 'Review ' || review_items.status,
                   review_items.summary,
                   (SELECT MAX(created_at) FROM audit_events
                    WHERE project_id = review_items.project_id
                      AND entity_type = 'review_item' AND entity_id = review_items.id),
                   review_items.ticket_id, NULL, NULL
            FROM review_items
            WHERE review_items.project_id = ? AND review_items.status <> 'open'
            """,
            bindings: bindings
        )
        try connection.execute(
            """
            INSERT INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, occurred_at, ticket_id,
                phase_id, delivery_lane, runtime_state
            )
            SELECT ?, 'completion', completion_records.id, 'Completed', completion_records.summary,
                   completion_records.created_at, completion_records.ticket_id,
                   NULL, NULL, 'completed'
            FROM completion_records
            WHERE completion_records.project_id = ?
            """,
            bindings: bindings
        )
        try connection.execute(
            """
            INSERT INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, occurred_at, recorded_at, ticket_id,
                phase_id, delivery_lane, notification_state, notification_status_text
            )
            SELECT ?, 'notification', notification_events.id,
                   COALESCE(notification_events.title, notification_events.fingerprint),
                   COALESCE(notification_events.message, 'Persisted notification delivery event.'),
                   notification_events.created_at, notification_events.completed_at,
                   notification_events.ticket_id, NULL, NULL, notification_events.state,
                   CASE
                     WHEN notification_events.state = 'queued' THEN 'Queued'
                     WHEN notification_events.state = 'attempt_started' THEN 'Sending'
                     WHEN notification_events.state = 'unknown' THEN 'Delivery unknown · Not retried automatically'
                     WHEN notification_events.state = 'sent' THEN 'Pushover delivered'
                     WHEN notification_events.state = 'suppressed'
                       AND notification_events.failure_code = 'project_archived'
                       THEN 'Suppressed when project was archived'
                     WHEN notification_events.state = 'suppressed'
                       AND notification_events.failure_code = 'project_removed'
                       THEN 'Suppressed when project was removed'
                     WHEN notification_events.state = 'suppressed' THEN 'Suppressed'
                     WHEN notification_events.state = 'failed'
                       AND notification_events.failure_code = 'credentials_missing'
                       THEN 'Delivery failed · Credentials missing'
                     WHEN notification_events.state = 'failed'
                       AND notification_events.failure_code = 'provider_rejected'
                       THEN 'Delivery failed · Provider rejected'
                     WHEN notification_events.state = 'failed'
                       AND notification_events.failure_code = 'invalid_provider_response'
                       THEN 'Delivery failed · Invalid provider response'
                     WHEN notification_events.state = 'failed' THEN 'Delivery failed · Transport unavailable'
                     ELSE 'Persisted delivery status'
                   END
            FROM notification_events
            LEFT JOIN tickets
              ON tickets.id = notification_events.ticket_id
             AND (notification_events.project_id IS NULL OR tickets.project_id = notification_events.project_id)
            WHERE notification_events.project_id = ?
               OR (notification_events.project_id IS NULL AND tickets.project_id = ?)
            """,
            bindings: bindings + [.text(projectID.rawValue)]
        )
    }
}

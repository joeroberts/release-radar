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
            try connection.execute(
                "INSERT INTO retained_repository_plan_preparation_attempts SELECT ?, project_id, proposal_id, attempt_id, request_id, registration_id, request_generation, root_id, request_data, revision, state, thread_id, turn_id, draft_data, error, is_current, replaced_by_attempt_id, created_at, updated_at FROM repository_plan_preparation_attempts WHERE project_id=?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_repository_plan_reconstruction_application_attempts SELECT ?, project_id, proposal_id, version, application_id, request_id, registration_id, request_generation, envelope_data, state, result_data, created_at, updated_at FROM repository_plan_reconstruction_application_attempts WHERE project_id=?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_repository_plan_reconstruction_provenance SELECT ?, project_id, proposal_id, version, application_id, record_kind, parent_source_id, source_id, destination_id, disposition, source_fields_data, source_refs_data, evidence_data, original_occurred_at, original_actor_id FROM repository_plan_reconstruction_provenance WHERE project_id=?",
                bindings: [removal, project]
            )
            try connection.execute("DELETE FROM repository_plan_reconstruction_provenance WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM repository_plan_reconstruction_application_attempts WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM repository_plan_preparation_attempts WHERE project_id = ?", bindings: [project])
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

public enum ProjectPermanentPurgeError: Error, LocalizedError, Equatable, Sendable {
    case targetAbsent
    case stalePreview
    case databaseFailure
    case activeExecutionResources
    case unsupportedOpaqueData

    public var errorDescription: String? {
        switch self {
        case .targetAbsent:
            "This removed registration is no longer available. Reload Removed Projects and try again."
        case .stalePreview:
            "Retained project data changed after this confirmation was prepared. Review the latest purge summary and try again."
        case .databaseFailure:
            "Release Radar could not complete the permanent purge. Retained database and execution metadata were preserved or left recoverable."
        case .activeExecutionResources:
            "A worker or execution assignment for this registration is still active or unresolved. Finish its supported recovery before purging history."
        case .unsupportedOpaqueData:
            "Release Radar found retained data whose registration identity cannot be verified safely. Permanent purge is blocked without deleting unrelated data."
        }
    }
}

public enum ProjectPermanentPurgeResult: Equatable, Sendable {
    case purged
    case alreadyAbsent
}

public struct ProjectPermanentPurgeInventory: Equatable, Sendable {
    public let retainedRecordCount: Int64
    public let auditEventCount: Int64
    public let commandReceiptCount: Int64
    public let searchReferenceCount: Int64
    public let executionPolicyCount: Int64
    public let executionAssignmentCount: Int64
}

public struct ProjectPermanentPurgePreview: Equatable, Sendable {
    public let removalID: ProjectRemovalID
    public let projectID: ProjectID
    public let projectName: String
    public let registrationID: String
    public let requestGeneration: Int64
    public let removedAt: Date
    public let inventory: ProjectPermanentPurgeInventory

    fileprivate let databaseInventory: ProjectPermanentPurgeDatabaseInventory
    let executionInventory: ProjectExecutionPurgeInventory
}

fileprivate struct ProjectPermanentPurgeSearchMutation: Equatable, Sendable {
    enum Location: Equatable, Sendable {
        case working
        case saved(String)
    }

    let location: Location
    let originalPayload: Data
    // Compare the proposed value, not a fresh encoding of its unordered domains.
    // The original persisted bytes still participate in stale-preview validation.
    let updatedDefinition: WorkspaceSearchDefinition
}

fileprivate struct ProjectPermanentPurgeDatabaseInventory: Equatable, Sendable {
    let record: RemovedProjectRecord
    let retainedCounts: [String: Int64]
    let identifyingAuditIDs: [String]
    let structuredReceiptIDs: [String]
    let hasPendingExecutionReceipt: Bool
    let searchMutations: [ProjectPermanentPurgeSearchMutation]
}

public actor ProjectPermanentPurgeManager {
    private static let retainedTables = [
        "retained_project_activity_events",
        "retained_delivery_goal_assignment_events",
        "retained_ticket_reference_versions",
        "retained_ticket_reference_links",
        "retained_plan_change_proposal_applications",
        "retained_plan_change_proposal_decisions",
        "retained_plan_change_proposal_versions",
        "retained_plan_change_proposals",
        "retained_ticket_successor_links",
        "retained_ticket_retirements",
        "retained_delivery_goal_obligation_lineage",
        "retained_delivery_goal_obligation_drops",
        "retained_delivery_goal_obligations",
        "retained_phase_lifecycle_events",
        "retained_phase_lifecycles",
        "retained_ticket_delivery_evidence_observations",
        "retained_ticket_delivery_evidence_targets",
        "retained_repository_plan_reconstruction_provenance",
        "retained_repository_plan_reconstruction_application_attempts",
        "retained_repository_plan_preparation_attempts",
    ]

    private let store: DeliveryStore
    private let executionStore: ProjectExecutionFileStore

    public init(store: DeliveryStore, executionStore: ProjectExecutionFileStore) {
        self.store = store
        self.executionStore = executionStore
    }

    public func preview(removalID: ProjectRemovalID) async throws -> ProjectPermanentPurgePreview {
        try await recoverPendingExecutionMetadata()
        guard let databaseInventory = try await store.read({ connection in
            try Self.databaseInventory(removalID: removalID, connection: connection)
        }) else {
            throw ProjectPermanentPurgeError.targetAbsent
        }
        let executionInventory: ProjectExecutionPurgeInventory
        do {
            executionInventory = try executionStore.permanentPurgeInventory(
                registration: databaseInventory.record.registration
            )
        } catch {
            throw ProjectPermanentPurgeError.unsupportedOpaqueData
        }
        let retainedCount = databaseInventory.retainedCounts.values.reduce(0, +) + 1
        return .init(
            removalID: databaseInventory.record.id,
            projectID: databaseInventory.record.projectID,
            projectName: databaseInventory.record.projectName,
            registrationID: databaseInventory.record.registration.registrationID,
            requestGeneration: databaseInventory.record.registration.requestGeneration,
            removedAt: databaseInventory.record.removedAt,
            inventory: .init(
                retainedRecordCount: retainedCount,
                auditEventCount: Int64(databaseInventory.identifyingAuditIDs.count),
                commandReceiptCount: Int64(databaseInventory.structuredReceiptIDs.count),
                searchReferenceCount: Int64(databaseInventory.searchMutations.count),
                executionPolicyCount: executionInventory.targetPolicy == nil ? 0 : 1,
                executionAssignmentCount: Int64(executionInventory.targetAssignments.count)
            ),
            databaseInventory: databaseInventory,
            executionInventory: executionInventory
        )
    }

    public func apply(_ preview: ProjectPermanentPurgePreview) async throws -> ProjectPermanentPurgeResult {
        do {
            try await recoverPendingExecutionMetadata()
            guard let currentDatabase = try await store.read({ connection in
                try Self.databaseInventory(removalID: preview.removalID, connection: connection)
            }) else {
                return .alreadyAbsent
            }
            let currentExecution = try executionStore.permanentPurgeInventory(
                registration: currentDatabase.record.registration
            )
            guard currentExecution.blockingAssignmentIDs.isEmpty,
                  !currentDatabase.hasPendingExecutionReceipt else {
                throw ProjectPermanentPurgeError.activeExecutionResources
            }
            guard currentDatabase == preview.databaseInventory,
                  currentExecution == preview.executionInventory else {
                throw ProjectPermanentPurgeError.stalePreview
            }

            let lease: ProjectExecutionPurgeLease
            do {
                lease = try executionStore.stagePermanentPurge(
                    removalID: preview.removalID,
                    expected: preview.executionInventory
                )
            } catch ProjectExecutionError.assignmentNotAuthorized {
                throw ProjectPermanentPurgeError.activeExecutionResources
            } catch ProjectExecutionError.conflict {
                throw ProjectPermanentPurgeError.stalePreview
            } catch {
                throw ProjectPermanentPurgeError.databaseFailure
            }

            do {
                try await store.transactPermanentlyPurgingProject(
                    removalID: preview.removalID,
                    projectID: preview.projectID,
                    registrationID: preview.registrationID,
                    requestGeneration: preview.requestGeneration
                ) { connection in
                    guard let transactionInventory = try Self.databaseInventory(
                        removalID: preview.removalID,
                        connection: connection
                    ), transactionInventory == preview.databaseInventory else {
                        throw ProjectPermanentPurgeError.stalePreview
                    }
                    try Self.applySearchMutations(
                        preview.databaseInventory.searchMutations,
                        connection: connection
                    )
                    for receiptID in preview.databaseInventory.structuredReceiptIDs {
                        try connection.execute(
                            "DELETE FROM agent_command_requests WHERE request_id = ?",
                            bindings: [.text(receiptID)]
                        )
                    }
                    for table in Self.retainedTables {
                        try connection.execute(
                            "DELETE FROM \(table) WHERE removal_id = ?",
                            bindings: [.text(preview.removalID.rawValue)]
                        )
                    }
                    for auditID in preview.databaseInventory.identifyingAuditIDs {
                        try connection.execute(
                            "DELETE FROM audit_events WHERE id = ?",
                            bindings: [.text(auditID)]
                        )
                    }
                    try connection.execute(
                        "DELETE FROM removed_projects WHERE removal_id = ?",
                        bindings: [.text(preview.removalID.rawValue)]
                    )
                }
            } catch ProjectPermanentPurgeError.targetAbsent {
                try executionStore.finalizePermanentPurge(lease)
                return .alreadyAbsent
            } catch {
                do {
                    try executionStore.restorePermanentPurge(lease)
                } catch {
                    throw ProjectPermanentPurgeError.databaseFailure
                }
                if let error = error as? ProjectPermanentPurgeError { throw error }
                throw ProjectPermanentPurgeError.databaseFailure
            }
            do {
                try executionStore.finalizePermanentPurge(lease)
            } catch {
                // The database commit is authoritative. Leave the staged manifest
                // for deterministic completion on the next manager operation.
                throw ProjectPermanentPurgeError.databaseFailure
            }
            return .purged
        } catch let error as ProjectPermanentPurgeError {
            throw error
        } catch {
            throw ProjectPermanentPurgeError.databaseFailure
        }
    }

    private func recoverPendingExecutionMetadata() async throws {
        do {
            for stage in try executionStore.pendingPermanentPurgeStages() {
                guard let lease = try executionStore.recoverPermanentPurgeLease(stage) else { continue }
                let targetExists = try await store.read { connection in
                    try connection.scalarInt(
                        "SELECT COUNT(*) FROM removed_projects WHERE removal_id = ?",
                        bindings: [.text(stage.removalID.rawValue)]
                    ) == 1
                }
                if targetExists {
                    try executionStore.restorePermanentPurge(lease)
                } else {
                    try executionStore.finalizePermanentPurge(lease)
                }
            }
        } catch {
            throw ProjectPermanentPurgeError.databaseFailure
        }
    }

    private nonisolated static func databaseInventory(
        removalID: ProjectRemovalID,
        connection: SQLiteConnection
    ) throws -> ProjectPermanentPurgeDatabaseInventory? {
        guard let row = try connection.row(
            "SELECT * FROM removed_projects WHERE removal_id = ?",
            bindings: [.text(removalID.rawValue)]
        ) else { return nil }
        guard case let .text(projectIDText)? = row["historical_project_id"],
              case let .text(projectName)? = row["project_name"],
              case let .text(lifecycleText)? = row["original_lifecycle"],
              let lifecycle = ProjectLifecycle(rawValue: lifecycleText),
              case let .text(registrationID)? = row["registration_id"],
              case let .integer(requestGeneration)? = row["request_generation"],
              case let .text(removedAtText)? = row["removed_at"],
              let removedAt = ISO8601DateFormatter().date(from: removedAtText),
              case let .integer(phaseCount)? = row["phase_count"],
              case let .integer(ticketCount)? = row["ticket_count"],
              case let .integer(evidenceCount)? = row["evidence_count"],
              case let .integer(historyCount)? = row["history_count"] else {
            throw ProjectPermanentPurgeError.unsupportedOpaqueData
        }
        let projectID = ProjectID(rawValue: projectIDText)
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: registrationID,
            requestGeneration: requestGeneration
        )
        let record = RemovedProjectRecord(
            id: removalID,
            projectID: projectID,
            projectName: projectName,
            originalLifecycle: lifecycle,
            registration: registration,
            removedAt: removedAt,
            counts: .init(
                phases: phaseCount,
                tickets: ticketCount,
                evidence: evidenceCount,
                history: historyCount
            )
        )
        var retainedCounts = [String: Int64]()
        for table in retainedTables {
            retainedCounts[table] = try connection.scalarInt(
                "SELECT COUNT(*) FROM \(table) WHERE removal_id = ?",
                bindings: [.text(removalID.rawValue)]
            ) ?? 0
        }
        let auditCandidates = try connection.rows(
            """
            SELECT id, project_id, historical_project_id, historical_registration_id, event_registration_id
            FROM audit_events
            WHERE project_id = ? OR historical_project_id = ?
               OR historical_registration_id = ? OR event_registration_id = ?
            ORDER BY id
            """,
            bindings: [
                .text(projectID.rawValue), .text(projectID.rawValue),
                .text(registrationID), .text(registrationID),
            ],
            maximum: 10_000
        )
        func text(_ value: SQLiteValue?) -> String? {
            guard case let .text(value)? = value else { return nil }
            return value
        }
        var audits = [String]()
        for audit in auditCandidates {
            let projects = Set([text(audit["project_id"]), text(audit["historical_project_id"])].compactMap { $0 })
            let registrations = Set([text(audit["historical_registration_id"]), text(audit["event_registration_id"])].compactMap { $0 })
            // A project ID alone cannot distinguish successive registrations. A
            // conflicting or missing provenance field must never widen deletion.
            guard projects.count == 1, registrations.count == 1 else {
                throw ProjectPermanentPurgeError.unsupportedOpaqueData
            }
            if projects.contains(projectIDText), registrations.contains(registrationID) {
                guard let id = text(audit["id"]) else { throw ProjectPermanentPurgeError.unsupportedOpaqueData }
                audits.append(id)
            }
        }
        let auditSet = Set(audits)
        let receiptCandidates = try connection.rows(
            """
            SELECT request_id, registration_project_id, registration_id, request_generation, result_data
            FROM agent_command_requests
            ORDER BY request_id
            """,
            maximum: 10_000
        )
        var receipts = [String]()
        var hasPendingExecutionReceipt = false
        for receipt in receiptCandidates {
            let receiptProject = text(receipt["registration_project_id"])
            let receiptRegistration = text(receipt["registration_id"])
            let auditID: String?
            let commandResult: AgentCommandResult?
            if case let .blob(data)? = receipt["result_data"] {
                commandResult = try? JSONDecoder().decode(AgentCommandResult.self, from: data)
                auditID = (try? JSONDecoder().decode(AuditEventID.self, from: data))?.rawValue
                    ?? commandResult?.auditEventID?.rawValue
            } else {
                auditID = nil
                commandResult = nil
            }
            let mappedToTarget = auditID.map(auditSet.contains) == true
            let exact = receiptProject == projectIDText && receiptRegistration == registrationID
            let legacy = receiptProject == nil && receiptRegistration == nil && receipt["request_generation"] == .null
            if exact || (legacy && mappedToTarget) {
                guard let id = text(receipt["request_id"]) else { throw ProjectPermanentPurgeError.unsupportedOpaqueData }
                receipts.append(id)
                // Preparation records its intent before provisioning can create
                // an assignment file. An unresolved result fences that interval.
                if commandResult?.error == .outcomeUnknown { hasPendingExecutionReceipt = true }
            } else if mappedToTarget {
                throw ProjectPermanentPurgeError.unsupportedOpaqueData
            } else if legacy {
                guard let auditID, let audit = try connection.row(
                    "SELECT project_id, historical_project_id, historical_registration_id, event_registration_id FROM audit_events WHERE id = ?",
                    bindings: [.text(auditID)]
                ) else { throw ProjectPermanentPurgeError.unsupportedOpaqueData }
                let projects = Set([text(audit["project_id"]), text(audit["historical_project_id"])].compactMap { $0 })
                let registrations = Set([text(audit["historical_registration_id"]), text(audit["event_registration_id"])].compactMap { $0 })
                guard projects.count == 1, registrations.count == 1,
                      !projects.contains(projectIDText) || !registrations.contains(registrationID) else {
                    throw ProjectPermanentPurgeError.unsupportedOpaqueData
                }
            } else if receiptProject == nil || receiptRegistration == nil {
                throw ProjectPermanentPurgeError.unsupportedOpaqueData
            }
            // Preserve proven unrelated receipts, including opaque payloads with
            // complete identity columns. Never search payload bytes for IDs.
        }
        let searchMutations = try searchMutations(
            registration: registration,
            connection: connection
        )
        return .init(
            record: record,
            retainedCounts: retainedCounts,
            identifyingAuditIDs: audits,
            structuredReceiptIDs: receipts,
            hasPendingExecutionReceipt: hasPendingExecutionReceipt,
            searchMutations: searchMutations
        )
    }

    private nonisolated static func searchMutations(
        registration: ProjectRegistration,
        connection: SQLiteConnection
    ) throws -> [ProjectPermanentPurgeSearchMutation] {
        var result = [ProjectPermanentPurgeSearchMutation]()
        if let row = try connection.row(
            "SELECT payload_version, payload_data FROM workspace_search_preferences WHERE singleton_id = 1"
        ) {
            guard case let .integer(version)? = row["payload_version"],
                  case let .blob(payload)? = row["payload_data"],
                  version == WorkspaceSearchPreferencesRepository.payloadVersion,
                  let definition = try? JSONDecoder().decode(WorkspaceSearchDefinition.self, from: payload) else {
                throw ProjectPermanentPurgeError.unsupportedOpaqueData
            }
            if let updated = try pruned(definition, removing: registration) {
                result.append(.init(location: .working, originalPayload: payload, updatedDefinition: updated))
            }
        }
        for row in try connection.rows(
            "SELECT id, payload_version, payload_data FROM workspace_saved_queries ORDER BY id",
            maximum: 1_000
        ) {
            guard case let .text(id)? = row["id"],
                  case let .integer(version)? = row["payload_version"],
                  case let .blob(payload)? = row["payload_data"],
                  version == WorkspaceSearchPreferencesRepository.payloadVersion,
                  let definition = try? JSONDecoder().decode(WorkspaceSearchDefinition.self, from: payload) else {
                throw ProjectPermanentPurgeError.unsupportedOpaqueData
            }
            if let updated = try pruned(definition, removing: registration) {
                result.append(.init(location: .saved(id), originalPayload: payload, updatedDefinition: updated))
            }
        }
        return result
    }

    private nonisolated static func pruned(
        _ definition: WorkspaceSearchDefinition,
        removing registration: ProjectRegistration
    ) throws -> WorkspaceSearchDefinition? {
        guard case let .registrations(scope) = definition.scope else { return nil }
        let filtered = scope.filter {
            $0.projectID != registration.projectID || $0.registrationID != registration.registrationID
        }
        guard filtered.count != scope.count else { return nil }
        var updated = definition
        updated.scope = .registrations(filtered)
        return updated
    }

    private nonisolated static func applySearchMutations(
        _ mutations: [ProjectPermanentPurgeSearchMutation],
        connection: SQLiteConnection
    ) throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for mutation in mutations {
            let updatedPayload = try encoder.encode(mutation.updatedDefinition)
            switch mutation.location {
            case .working:
                try connection.execute(
                    """
                    UPDATE workspace_search_preferences
                    SET payload_data = ?, updated_at = ?
                    WHERE singleton_id = 1 AND payload_version = ? AND payload_data = ?
                    """,
                    bindings: [
                        .blob(updatedPayload), .text(timestamp),
                        .integer(WorkspaceSearchPreferencesRepository.payloadVersion),
                        .blob(mutation.originalPayload),
                    ]
                )
            case let .saved(id):
                try connection.execute(
                    """
                    UPDATE workspace_saved_queries
                    SET payload_data = ?, updated_at = ?
                    WHERE id = ? AND payload_version = ? AND payload_data = ?
                    """,
                    bindings: [
                        .blob(updatedPayload), .text(timestamp), .text(id),
                        .integer(WorkspaceSearchPreferencesRepository.payloadVersion),
                        .blob(mutation.originalPayload),
                    ]
                )
            }
        }
    }
}

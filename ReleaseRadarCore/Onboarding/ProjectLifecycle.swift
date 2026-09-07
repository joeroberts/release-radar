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

    private static func snapshot(
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

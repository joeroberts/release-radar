import Foundation

public enum WorkspaceSearchDomain: String, Codable, CaseIterable, Hashable, Sendable {
    case project
    case deliveryGoal
    case executionGoal
    case ticket
    case decisionReference
    case history

    public var title: String {
        switch self {
        case .project: "Projects"
        case .deliveryGoal: "Delivery Goals"
        case .executionGoal: "Execution Goals"
        case .ticket: "Tickets"
        case .decisionReference: "Decision references"
        case .history: "History"
        }
    }
}

public enum WorkspaceSearchSort: String, Codable, CaseIterable, Hashable, Sendable {
    case domainThenTitle
    case title
    case newest
}

public struct WorkspaceSearchRegistrationIdentity: Codable, Equatable, Hashable, Sendable {
    public let projectID: ProjectID
    public let registrationID: String

    public init(projectID: ProjectID, registrationID: String) {
        self.projectID = projectID
        self.registrationID = registrationID
    }
}

public enum WorkspaceSearchScope: Codable, Equatable, Hashable, Sendable {
    case allAuthorized
    case registrations([WorkspaceSearchRegistrationIdentity])
}

public struct WorkspaceSearchDefinition: Codable, Equatable, Hashable, Sendable {
    public var text: String
    public var scope: WorkspaceSearchScope
    public var domains: Set<WorkspaceSearchDomain>
    public var sort: WorkspaceSearchSort
    public var authorityIncarnationID: String?

    public init(
        text: String = "",
        scope: WorkspaceSearchScope = .allAuthorized,
        domains: Set<WorkspaceSearchDomain> = Set(WorkspaceSearchDomain.allCases),
        sort: WorkspaceSearchSort = .domainThenTitle,
        authorityIncarnationID: String? = nil
    ) {
        self.text = text
        self.scope = scope
        self.domains = domains
        self.sort = sort
        self.authorityIncarnationID = authorityIncarnationID
    }
}

public enum WorkspaceSearchProjectLifecycle: String, Codable, Equatable, Hashable, Sendable {
    case active
    case archived
}

public struct WorkspaceSearchProjectIdentity: Codable, Equatable, Hashable, Sendable {
    public let projectID: ProjectID
    public let registrationID: String
    public let name: String
    public let lifecycle: WorkspaceSearchProjectLifecycle

    public init(
        projectID: ProjectID,
        registrationID: String,
        name: String,
        lifecycle: WorkspaceSearchProjectLifecycle
    ) {
        self.projectID = projectID
        self.registrationID = registrationID
        self.name = name
        self.lifecycle = lifecycle
    }
}

public enum WorkspaceSearchHistorySource: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case audit
    case review
    case completion
    case observation
    case notification
}

public enum WorkspaceSearchResultIdentity: Codable, Equatable, Hashable, Sendable {
    case project(projectID: ProjectID, registrationID: String)
    case deliveryGoal(projectID: ProjectID, registrationID: String, phaseID: PhaseID, goalID: String)
    case executionGoal(projectID: ProjectID, registrationID: String, threadID: ObservedThreadID, goalID: ObservedGoalID)
    case ticket(projectID: ProjectID, registrationID: String, ticketID: TicketID, phaseID: PhaseID?)
    case decisionReference(
        projectID: ProjectID,
        registrationID: String,
        ticketID: TicketID,
        linkID: String,
        version: Int64,
        repositoryID: String,
        artifactID: String
    )
    case history(
        projectID: ProjectID,
        registrationID: String,
        source: WorkspaceSearchHistorySource,
        sourceID: String
    )
}

public struct WorkspaceSearchResult: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let domain: WorkspaceSearchDomain
    public let project: WorkspaceSearchProjectIdentity
    public let identity: WorkspaceSearchResultIdentity
    public let title: String
    public let detail: String
    public let occurredAt: String?
    public let isRetired: Bool

    public var id: Data { Data(stableIdentity.utf8) }

    public init(
        domain: WorkspaceSearchDomain,
        project: WorkspaceSearchProjectIdentity,
        identity: WorkspaceSearchResultIdentity,
        title: String,
        detail: String,
        occurredAt: String? = nil,
        isRetired: Bool = false
    ) {
        self.domain = domain
        self.project = project
        self.identity = identity
        self.title = title
        self.detail = detail
        self.occurredAt = occurredAt
        self.isRetired = isRetired
    }

    private var stableIdentity: String {
        switch identity {
        case let .project(projectID, registrationID):
            "project|\(projectID.rawValue)|\(registrationID)"
        case let .deliveryGoal(projectID, registrationID, phaseID, goalID):
            "delivery|\(projectID.rawValue)|\(registrationID)|\(phaseID.rawValue)|\(goalID)"
        case let .executionGoal(projectID, registrationID, threadID, goalID):
            "execution|\(projectID.rawValue)|\(registrationID)|\(threadID.rawValue)|\(goalID.rawValue)"
        case let .ticket(projectID, registrationID, ticketID, phaseID):
            "ticket|\(projectID.rawValue)|\(registrationID)|\(ticketID.rawValue)|\(phaseID?.rawValue ?? "")"
        case let .decisionReference(projectID, registrationID, ticketID, linkID, version, repositoryID, artifactID):
            "decision|\(projectID.rawValue)|\(registrationID)|\(ticketID.rawValue)|\(linkID)|\(version)|\(repositoryID)|\(artifactID)"
        case let .history(projectID, registrationID, source, sourceID):
            "history|\(projectID.rawValue)|\(registrationID)|\(source.rawValue)|\(sourceID)"
        }
    }
}

public struct WorkspaceSearchOmission: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let domain: WorkspaceSearchDomain
    public let message: String
    public var id: WorkspaceSearchDomain { domain }

    public init(domain: WorkspaceSearchDomain, message: String) {
        self.domain = domain
        self.message = message
    }
}

public struct WorkspaceSearchProjection: Codable, Equatable, Sendable {
    public let definition: WorkspaceSearchDefinition
    public let results: [WorkspaceSearchResult]
    public let omissions: [WorkspaceSearchOmission]
    public var omittedDomains: Set<WorkspaceSearchDomain> { Set(omissions.map(\.domain)) }
    public var isComplete: Bool { omissions.isEmpty }

    public init(
        definition: WorkspaceSearchDefinition,
        results: [WorkspaceSearchResult],
        omissions: [WorkspaceSearchOmission]
    ) {
        self.definition = definition
        self.results = results
        self.omissions = omissions
    }
}

public enum WorkspaceSearchError: Error, LocalizedError, Equatable, Sendable {
    case authorizationRequired
    case invalidDefinition(String)

    public var errorDescription: String? {
        switch self {
        case .authorizationRequired:
            "This saved search belongs to an earlier authorization state. Choose its project scope again and resave it."
        case let .invalidDefinition(message):
            message
        }
    }
}

public enum WorkspaceSearchQuery {
    public static func search(
        store: DeliveryStore,
        definition: WorkspaceSearchDefinition
    ) async throws -> WorkspaceSearchProjection {
        let normalizedText = definition.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.utf8.count <= 512 else {
            throw WorkspaceSearchError.invalidDefinition("Search text must be 512 bytes or fewer.")
        }
        guard !definition.domains.isEmpty else {
            return .init(definition: definition, results: [], omissions: [])
        }
        guard !normalizedText.isEmpty else {
            return .init(definition: definition, results: [], omissions: [])
        }

        return try await store.read { connection in
            let authority = try validatedAuthority(connection: connection, definition: definition)
            var results: [WorkspaceSearchResult] = []
            var omissions: [WorkspaceSearchOmission] = []
            for domain in WorkspaceSearchDomain.allCases where definition.domains.contains(domain) {
                do {
                    results.append(contentsOf: try load(
                        domain: domain,
                        text: normalizedText,
                        authority: authority,
                        connection: connection
                    ))
                } catch {
                    omissions.append(.init(domain: domain, message: error.localizedDescription))
                }
            }
            return .init(
                definition: definition,
                results: sorted(results, by: definition.sort),
                omissions: omissions
            )
        }
    }

    public static func boundToCurrentAuthority(
        store: DeliveryStore,
        definition: WorkspaceSearchDefinition
    ) async throws -> WorkspaceSearchDefinition {
        let incarnationID = try await store.read { connection in
            try requiredText(
                try connection.row("SELECT incarnation_id FROM application_recovery_state WHERE singleton_id = 1"),
                "incarnation_id"
            )
        }
        var result = definition
        result.authorityIncarnationID = incarnationID
        return result
    }

    private struct Authority: Sendable {
        let projects: [WorkspaceSearchProjectIdentity]
        var projectIDs: Set<String> { Set(projects.map { $0.projectID.rawValue }) }

        func project(_ rawID: String) -> WorkspaceSearchProjectIdentity? {
            projects.first { Data($0.projectID.rawValue.utf8).elementsEqual(Data(rawID.utf8)) }
        }
    }

    private static func validatedAuthority(
        connection: SQLiteConnection,
        definition: WorkspaceSearchDefinition
    ) throws -> Authority {
        let currentIncarnation = try requiredText(
            try connection.row("SELECT incarnation_id FROM application_recovery_state WHERE singleton_id = 1"),
            "incarnation_id"
        )
        if let expected = definition.authorityIncarnationID,
           !Data(expected.utf8).elementsEqual(Data(currentIncarnation.utf8)) {
            throw WorkspaceSearchError.authorizationRequired
        }

        let rows = try connection.rows(
            """
            SELECT projects.id, projects.name, projects.lifecycle, project_registrations.registration_id
            FROM projects
            JOIN project_registrations ON project_registrations.project_id = projects.id
            WHERE project_registrations.setup_state = 'complete'
            ORDER BY projects.id, project_registrations.registration_id
            """,
            maximum: 2_000
        )
        let available = try rows.map { row in
            WorkspaceSearchProjectIdentity(
                projectID: .init(rawValue: try requiredText(row, "id")),
                registrationID: try requiredText(row, "registration_id"),
                name: try requiredText(row, "name"),
                lifecycle: WorkspaceSearchProjectLifecycle(
                    rawValue: try requiredText(row, "lifecycle")
                ) ?? .active
            )
        }
        switch definition.scope {
        case .allAuthorized:
            return .init(projects: available)
        case let .registrations(requested):
            let availableByKey = Dictionary(uniqueKeysWithValues: available.map {
                ("\($0.projectID.rawValue)\u{1f}\($0.registrationID)", $0)
            })
            let selected = requested.compactMap {
                availableByKey["\($0.projectID.rawValue)\u{1f}\($0.registrationID)"]
            }
            guard selected.count == Set(requested).count else {
                throw WorkspaceSearchError.authorizationRequired
            }
            return .init(projects: selected)
        }
    }

    private static func load(
        domain: WorkspaceSearchDomain,
        text: String,
        authority: Authority,
        connection: SQLiteConnection
    ) throws -> [WorkspaceSearchResult] {
        guard !authority.projects.isEmpty else { return [] }
        switch domain {
        case .project:
            return authority.projects.compactMap { project in
                guard matches(text, in: [project.name, project.projectID.rawValue]) else { return nil }
                return .init(
                    domain: .project,
                    project: project,
                    identity: .project(projectID: project.projectID, registrationID: project.registrationID),
                    title: project.name,
                    detail: project.lifecycle == .archived ? "Archived project" : "Active project"
                )
            }
        case .deliveryGoal:
            return try loadDeliveryGoals(text: text, authority: authority, connection: connection)
        case .executionGoal:
            return try loadExecutionGoals(text: text, authority: authority, connection: connection)
        case .ticket:
            return try loadTickets(text: text, authority: authority, connection: connection)
        case .decisionReference:
            return try loadDecisionReferences(text: text, authority: authority, connection: connection)
        case .history:
            return try loadHistory(text: text, authority: authority, connection: connection)
        }
    }

    private static func loadDeliveryGoals(
        text: String,
        authority: Authority,
        connection: SQLiteConnection
    ) throws -> [WorkspaceSearchResult] {
        let rows = try connection.rows(
            """
            SELECT project_id, phase_id, id, title, outcome, lifecycle, updated_at
            FROM delivery_goals
            ORDER BY project_id, phase_id, sort_order, id
            """,
            maximum: 10_000
        )
        return try rows.compactMap { row in
            let projectID = try requiredText(row, "project_id")
            guard let project = authority.project(projectID), matches(text, in: [
                try requiredText(row, "id"), try requiredText(row, "title"), try requiredText(row, "outcome")
            ]) else { return nil }
            let phaseID = PhaseID(rawValue: try requiredText(row, "phase_id"))
            let goalID = try requiredText(row, "id")
            return .init(
                domain: .deliveryGoal,
                project: project,
                identity: .deliveryGoal(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    phaseID: phaseID,
                    goalID: goalID
                ),
                title: try requiredText(row, "title"),
                detail: "\(try requiredText(row, "lifecycle")) · \(try requiredText(row, "outcome"))",
                occurredAt: optionalText(row, "updated_at")
            )
        }
    }

    private static func loadExecutionGoals(
        text: String,
        authority: Authority,
        connection: SQLiteConnection
    ) throws -> [WorkspaceSearchResult] {
        let rows = try connection.rows(
            """
            SELECT project_id, thread_id, id, status, text, last_observed_at
            FROM observed_goals
            ORDER BY project_id, thread_id, id
            """,
            maximum: 10_000
        )
        return try rows.compactMap { row in
            let projectID = try requiredText(row, "project_id")
            guard let project = authority.project(projectID), matches(text, in: [
                try requiredText(row, "id"), try requiredText(row, "status"), try requiredText(row, "text")
            ]) else { return nil }
            let threadID = ObservedThreadID(rawValue: try requiredText(row, "thread_id"))
            let goalID = ObservedGoalID(rawValue: try requiredText(row, "id"))
            return .init(
                domain: .executionGoal,
                project: project,
                identity: .executionGoal(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    threadID: threadID,
                    goalID: goalID
                ),
                title: try requiredText(row, "text"),
                detail: "\(try requiredText(row, "status")) · thread \(threadID.rawValue)",
                occurredAt: optionalText(row, "last_observed_at")
            )
        }
    }

    private static func loadTickets(
        text: String,
        authority: Authority,
        connection: SQLiteConnection
    ) throws -> [WorkspaceSearchResult] {
        let rows = try connection.rows(
            """
            SELECT tickets.project_id, tickets.id, tickets.phase_id, tickets.outcome, tickets.lane,
                   ticket_retirements.retired_at
            FROM tickets
            LEFT JOIN ticket_retirements
              ON ticket_retirements.project_id = tickets.project_id
             AND ticket_retirements.ticket_id = tickets.id
            ORDER BY tickets.project_id, tickets.id
            """,
            maximum: 10_000
        )
        return try rows.compactMap { row in
            let projectID = try requiredText(row, "project_id")
            guard let project = authority.project(projectID), matches(text, in: [
                try requiredText(row, "id"), try requiredText(row, "outcome"), optionalText(row, "lane") ?? ""
            ]) else { return nil }
            let ticketID = TicketID(rawValue: try requiredText(row, "id"))
            let phaseID = optionalText(row, "phase_id").map(PhaseID.init(rawValue:))
            let retiredAt = optionalText(row, "retired_at")
            let lane = optionalText(row, "lane") ?? "Unplaced"
            return .init(
                domain: .ticket,
                project: project,
                identity: .ticket(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    ticketID: ticketID,
                    phaseID: phaseID
                ),
                title: try requiredText(row, "outcome"),
                detail: retiredAt == nil ? "\(ticketID.rawValue) · \(lane)" : "\(ticketID.rawValue) · Retired",
                occurredAt: retiredAt,
                isRetired: retiredAt != nil
            )
        }
    }

    private static func loadDecisionReferences(
        text: String,
        authority: Authority,
        connection: SQLiteConnection
    ) throws -> [WorkspaceSearchResult] {
        let rows = try connection.rows(
            """
            SELECT links.project_id, links.ticket_id, links.id, links.repository_id, links.artifact_id,
                   versions.version, versions.source_local_id, versions.locator,
                   versions.observed_path, versions.observed_lifecycle, versions.observed_authority,
                   versions.created_at
            FROM ticket_reference_links AS links
            JOIN ticket_reference_versions AS versions
              ON versions.project_id = links.project_id
             AND versions.ticket_id = links.ticket_id
             AND versions.link_id = links.id
             AND versions.version = links.current_version
            WHERE links.kind = 'decision'
            ORDER BY links.project_id, links.ticket_id, links.id
            """,
            maximum: 10_000
        )
        return try rows.compactMap { row in
            let projectID = try requiredText(row, "project_id")
            let artifactID = try requiredText(row, "artifact_id")
            let sourceLocalID = try requiredText(row, "source_local_id")
            let locator = try requiredText(row, "locator")
            guard let project = authority.project(projectID), matches(text, in: [
                artifactID, sourceLocalID, locator, optionalText(row, "observed_path") ?? ""
            ]) else { return nil }
            let ticketID = TicketID(rawValue: try requiredText(row, "ticket_id"))
            let linkID = try requiredText(row, "id")
            let version = try requiredInt(row, "version")
            let repositoryID = try requiredText(row, "repository_id")
            return .init(
                domain: .decisionReference,
                project: project,
                identity: .decisionReference(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    ticketID: ticketID,
                    linkID: linkID,
                    version: version,
                    repositoryID: repositoryID,
                    artifactID: artifactID
                ),
                title: sourceLocalID,
                detail: "\(ticketID.rawValue) · \(locator)",
                occurredAt: optionalText(row, "created_at")
            )
        }
    }

    private static func loadHistory(
        text: String,
        authority: Authority,
        connection: SQLiteConnection
    ) throws -> [WorkspaceSearchResult] {
        var results: [WorkspaceSearchResult] = []
        let auditRows = try connection.rows(
            """
            SELECT id, COALESCE(project_id, historical_project_id) AS project_id,
                   COALESCE(event_registration_id, historical_registration_id) AS registration_id,
                   reason, entity_type, entity_id, created_at
            FROM audit_events
            WHERE COALESCE(project_id, historical_project_id) IS NOT NULL
            ORDER BY created_at, id
            """,
            maximum: 10_000
        )
        for row in auditRows {
            let projectID = try requiredText(row, "project_id")
            guard let project = authority.project(projectID),
                  optionalText(row, "registration_id") == project.registrationID,
                  matches(text, in: [
                    try requiredText(row, "reason"), optionalText(row, "entity_type") ?? "",
                    optionalText(row, "entity_id") ?? ""
                  ]) else { continue }
            let sourceID = try requiredText(row, "id")
            results.append(.init(
                domain: .history,
                project: project,
                identity: .history(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    source: .audit,
                    sourceID: sourceID
                ),
                title: try requiredText(row, "reason"),
                detail: optionalText(row, "entity_type") ?? "Audit event",
                occurredAt: optionalText(row, "created_at")
            ))
        }
        let runtimeRows = try connection.rows(
            """
            SELECT project_id, thread_id, id, status, text, last_observed_at
            FROM observed_goals
            ORDER BY project_id, last_observed_at, thread_id, id
            """,
            maximum: 10_000
        )
        for row in runtimeRows {
            let projectID = try requiredText(row, "project_id")
            let threadID = try requiredText(row, "thread_id")
            let goalID = try requiredText(row, "id")
            guard let project = authority.project(projectID), matches(text, in: [
                threadID, goalID, try requiredText(row, "status"), try requiredText(row, "text")
            ]) else { continue }
            results.append(.init(
                domain: .history,
                project: project,
                identity: .history(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    source: .observation,
                    sourceID: "\(threadID)|\(goalID)"
                ),
                title: try requiredText(row, "status"),
                detail: try requiredText(row, "text"),
                occurredAt: optionalText(row, "last_observed_at")
            ))
        }
        let reviewRows = try connection.rows(
            "SELECT project_id, id, status, summary FROM review_items WHERE status <> 'open' ORDER BY project_id, id",
            maximum: 10_000
        )
        for row in reviewRows {
            let projectID = try requiredText(row, "project_id")
            let sourceID = try requiredText(row, "id")
            guard let project = authority.project(projectID), matches(text, in: [
                sourceID, try requiredText(row, "status"), try requiredText(row, "summary")
            ]) else { continue }
            results.append(.init(
                domain: .history,
                project: project,
                identity: .history(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    source: .review,
                    sourceID: sourceID
                ),
                title: "Review \(try requiredText(row, "status"))",
                detail: try requiredText(row, "summary")
            ))
        }
        let completionRows = try connection.rows(
            "SELECT project_id, id, summary, created_at FROM completion_records ORDER BY project_id, created_at, id",
            maximum: 10_000
        )
        for row in completionRows {
            let projectID = try requiredText(row, "project_id")
            let sourceID = try requiredText(row, "id")
            guard let project = authority.project(projectID), matches(text, in: [
                sourceID, try requiredText(row, "summary")
            ]) else { continue }
            results.append(.init(
                domain: .history,
                project: project,
                identity: .history(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    source: .completion,
                    sourceID: sourceID
                ),
                title: "Completed",
                detail: try requiredText(row, "summary"),
                occurredAt: optionalText(row, "created_at")
            ))
        }
        let notificationRows = try connection.rows(
            """
            SELECT COALESCE(notification_events.project_id, tickets.project_id) AS project_id,
                   notification_events.id, notification_events.state, notification_events.title,
                   notification_events.message, notification_events.created_at
            FROM notification_events
            LEFT JOIN tickets ON tickets.id = notification_events.ticket_id
            WHERE COALESCE(notification_events.project_id, tickets.project_id) IS NOT NULL
            ORDER BY project_id, notification_events.created_at, notification_events.id
            """,
            maximum: 10_000
        )
        for row in notificationRows {
            let projectID = try requiredText(row, "project_id")
            let sourceID = try requiredText(row, "id")
            guard let project = authority.project(projectID), matches(text, in: [
                sourceID, try requiredText(row, "state"), try requiredText(row, "title"),
                try requiredText(row, "message")
            ]) else { continue }
            results.append(.init(
                domain: .history,
                project: project,
                identity: .history(
                    projectID: project.projectID,
                    registrationID: project.registrationID,
                    source: .notification,
                    sourceID: sourceID
                ),
                title: try requiredText(row, "title"),
                detail: try requiredText(row, "message"),
                occurredAt: optionalText(row, "created_at")
            ))
        }
        return results
    }

    private static func sorted(
        _ results: [WorkspaceSearchResult],
        by sort: WorkspaceSearchSort
    ) -> [WorkspaceSearchResult] {
        let domainOrder = Dictionary(uniqueKeysWithValues: WorkspaceSearchDomain.allCases.enumerated().map { ($1, $0) })
        return results.sorted { lhs, rhs in
            switch sort {
            case .domainThenTitle:
                let leftDomain = domainOrder[lhs.domain] ?? .max
                let rightDomain = domainOrder[rhs.domain] ?? .max
                if leftDomain != rightDomain { return leftDomain < rightDomain }
            case .title:
                break
            case .newest:
                if lhs.occurredAt != rhs.occurredAt { return (lhs.occurredAt ?? "") > (rhs.occurredAt ?? "") }
            }
            let leftTitle = lhs.title.localizedLowercase
            let rightTitle = rhs.title.localizedLowercase
            if leftTitle != rightTitle { return leftTitle < rightTitle }
            if lhs.project.name != rhs.project.name { return lhs.project.name < rhs.project.name }
            return lhs.id.lexicographicallyPrecedes(rhs.id)
        }
    }

    private static func matches(_ query: String, in values: [String]) -> Bool {
        values.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private static func requiredText(_ row: [String: SQLiteValue]?, _ column: String) throws -> String {
        guard let row, case let .text(value)? = row[column] else {
            throw SQLiteError(code: 20, message: "Workspace search expected text column \(column)")
        }
        return value
    }

    private static func requiredText(_ row: [String: SQLiteValue], _ column: String) throws -> String {
        try requiredText(Optional(row), column)
    }

    private static func optionalText(_ row: [String: SQLiteValue], _ column: String) -> String? {
        guard case let .text(value)? = row[column] else { return nil }
        return value
    }

    private static func requiredInt(_ row: [String: SQLiteValue], _ column: String) throws -> Int64 {
        guard case let .integer(value)? = row[column] else {
            throw SQLiteError(code: 20, message: "Workspace search expected integer column \(column)")
        }
        return value
    }
}

import Foundation
import ReleaseRadarCore

enum ActivitySource: String, Equatable, Hashable, Sendable {
    case audit
    case runtime
    case review
    case completion
    case notification
}

enum HistoryFilter: String, CaseIterable, Equatable, Hashable, Sendable {
    case all
    case audit
    case observations
    case reviews
    case completions
    case notifications

    var title: String {
        switch self {
        case .all: "All events"
        case .audit: "Audit"
        case .observations: "Observations"
        case .reviews: "Reviews"
        case .completions: "Completions"
        case .notifications: "Notifications"
        }
    }

    func includes(_ source: ActivitySource) -> Bool {
        switch self {
        case .all: true
        case .audit: source == .audit
        case .observations: source == .runtime
        case .reviews: source == .review
        case .completions: source == .completion
        case .notifications: source == .notification
        }
    }
}

enum HistorySurfaceContent: Equatable, Sendable {
    case events([ProjectActivityItem])
    case empty
    case noMatches
    case failed(String)
    case incomplete(String)
}

enum HistorySurfaceState: Equatable, Sendable {
    case loaded(ProjectActivityProjection)
    case failed(String)
    case incomplete(String)

    func content(for filter: HistoryFilter) -> HistorySurfaceContent {
        switch self {
        case let .loaded(projection):
            guard !projection.items.isEmpty else { return .empty }
            let filtered = projection.filtered(by: filter).items
            return filtered.isEmpty ? .noMatches : .events(filtered)
        case let .failed(message):
            return .failed(message)
        case let .incomplete(message):
            return .incomplete(message)
        }
    }
}

enum HistoryProvenance: String, Equatable, Sendable {
    case localAudit
    case persistedObservation
    case reviewRecord
    case completionRecord
    case notificationDelivery
    case retainedSource
}

struct HistoryEventIdentity: Equatable, Hashable, Sendable {
    let projectID: ProjectID
    let registrationID: String?
    let source: ActivitySource
    let sourceID: String
}

struct HistoryEventFacts: Equatable, Sendable {
    let projectName: String?
    let entityType: AuditEntityType?
    let entityID: String?
    let ticketID: TicketID?
    let phaseID: PhaseID?
    let phaseName: String?
    let ticketOutcome: String?
    let previousLane: TicketLane?
    let currentLane: TicketLane?
    let previousPhaseID: PhaseID?
    let currentPhaseID: PhaseID?
}

struct RuntimeStateLanguage: Equatable, Sendable {
    let title: String

    init(storedValue: String) {
        switch storedValue.lowercased().replacingOccurrences(of: " ", with: "_") {
        case "active", "in_progress": title = "Active"
        case "paused": title = "Paused"
        case "awaiting_input", "waiting": title = "Awaiting input"
        case "blocked": title = "Blocked"
        case "completed", "completed_ready_for_review": title = "Completed"
        default: title = "Unavailable"
        }
    }
}

struct RetainedPhaseLifecycleActivity: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case current
        case transition
    }

    let kind: Kind
    let removalID: ProjectRemovalID
    let historicalProjectID: ProjectID
    let phaseID: PhaseID
    let phaseName: String
    let lifecycle: PhaseLifecycle
    let revision: Int64
    let previousLifecycle: PhaseLifecycle?
    let action: PhaseLifecycleAction?
    let reason: String?
    let auditEventID: AuditEventID?
    let registration: ProjectRegistration?
    let planningBaselineDigest: String?
}

struct ProjectActivityItem: Equatable, Identifiable, Sendable {
    let id: String
    let identity: HistoryEventIdentity
    let source: ActivitySource
    let provenance: HistoryProvenance
    let title: String
    let detail: String
    let observedAt: Date?
    let occurredAt: Date?
    let recordedAt: Date?
    let eventFacts: HistoryEventFacts?
    let ticketID: TicketID?
    let deliveryLane: TicketLane?
    let runtimeState: RuntimeStateLanguage?
    let notificationState: NotificationDeliveryState?
    let notificationStatusText: String?
    var phaseID: PhaseID? = nil
    var deliveryGoalID: DeliveryGoalID? = nil
    var actorID: String? = nil
    var originatingThreadID: String? = nil
    var threadAttribution: ThreadAttribution? = nil
    var assignmentEvents: [DeliveryGoalAssignmentEventRecord] = []
    var retainedPhaseLifecycle: RetainedPhaseLifecycleActivity? = nil

    var freshnessText: String? {
        observedAt.map { "Last seen \($0.formatted(date: .abbreviated, time: .shortened))" }
    }

    var timelineDate: Date? { occurredAt ?? observedAt ?? recordedAt }
}

struct ProjectActivityProjection: Equatable, Sendable {
    let projectID: ProjectID
    let items: [ProjectActivityItem]

    func items(for ticketID: TicketID) -> [ProjectActivityItem] {
        items.filter { $0.ticketID == ticketID || $0.assignmentEvents.contains { $0.ticketID == ticketID } }
    }

    func filtered(by filter: HistoryFilter) -> ProjectActivityProjection {
        .init(projectID: projectID, items: items.filter { filter.includes($0.source) })
    }

    static func load(from store: DeliveryStore, projectID: ProjectID) async throws -> ProjectActivityProjection {
        try await store.read { connection in
            let registrationID = try connection.scalarText(
                "SELECT registration_id FROM project_registrations WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
            let ticketRows = try connection.activityRows(
                "SELECT id, lane, phase_id FROM tickets WHERE project_id = ? ORDER BY rowid",
                bindings: [.text(projectID.rawValue)]
            )
            let ticketLanes: [TicketID: TicketLane] = try Dictionary(
                uniqueKeysWithValues: ticketRows.compactMap { row in
                    let id = TicketID(rawValue: try row.activityText("id"))
                    guard let laneText = row.activityOptionalText("lane") else { return nil }
                    guard let lane = TicketLane(rawValue: laneText) else {
                        throw ProjectActivityProjectionError.invalidLane(laneText)
                    }
                    return (id, lane)
                }
            )
            let ticketPhases: [TicketID: PhaseID] = try Dictionary(uniqueKeysWithValues: ticketRows.compactMap {
                guard let phaseID = $0.activityOptionalText("phase_id") else { return nil }
                return (TicketID(rawValue: try $0.activityText("id")), PhaseID(rawValue: phaseID))
            })
            let goalPhases = try Dictionary(uniqueKeysWithValues: connection.activityRows(
                "SELECT id, phase_id FROM delivery_goals WHERE project_id = ? ORDER BY id",
                bindings: [.text(projectID.rawValue)]
            ).map { (Data(try $0.activityText("id").utf8), PhaseID(rawValue: try $0.activityText("phase_id"))) })
            var assignmentsByAudit: [AuditEventID: [DeliveryGoalAssignmentEventRecord]] = [:]
            for ticketID in try ticketRows.map({ TicketID(rawValue: try $0.activityText("id")) })
                .sorted(by: { $0.rawValue.utf8.lexicographicallyPrecedes($1.rawValue.utf8) }) {
                for event in try DeliveryPlanningPolicy.loadAssignmentHistory(projectID: projectID, ticketID: ticketID, connection: connection) {
                    assignmentsByAudit[event.auditEventID, default: []].append(event)
                }
            }
            let reviewRows = try connection.activityRows(
                "SELECT id, ticket_id, summary, status FROM review_items WHERE project_id = ? AND status <> 'open' ORDER BY rowid",
                bindings: [.text(projectID.rawValue)]
            )
            let completionRows = try connection.activityRows(
                "SELECT id, ticket_id, summary, created_at FROM completion_records WHERE project_id = ? ORDER BY created_at DESC",
                bindings: [.text(projectID.rawValue)]
            )
            let runtimeRows = try connection.activityRows(
                """
                SELECT observed_goals.id, observed_goals.thread_id, observed_goals.status,
                       observed_goals.text, observed_goals.last_observed_at,
                       ticket_goal_links.ticket_id
                FROM observed_goals
                LEFT JOIN ticket_goal_links
                  ON ticket_goal_links.project_id = observed_goals.project_id
                 AND ticket_goal_links.goal_id = observed_goals.id
                 AND ticket_goal_links.thread_id = observed_goals.thread_id
                WHERE observed_goals.project_id = ?
                ORDER BY observed_goals.last_observed_at DESC
                """,
                bindings: [.text(projectID.rawValue)]
            )
            let notificationRows = try connection.activityRows(
                """
                SELECT notification_events.id, notification_events.fingerprint,
                       notification_events.state, notification_events.ticket_id,
                       notification_events.title, notification_events.message,
                       notification_events.created_at, notification_events.completed_at,
                       notification_events.failure_code
                FROM notification_events
                LEFT JOIN tickets ON tickets.id = notification_events.ticket_id
                WHERE notification_events.project_id = ?
                   OR (notification_events.project_id IS NULL AND tickets.project_id = ?)
                ORDER BY notification_events.rowid DESC
                """,
                bindings: [.text(projectID.rawValue), .text(projectID.rawValue)]
            )
            let auditRows = try connection.activityRows(
                """
                SELECT id, actor_id, reason, created_at, entity_type, entity_id, thread_id,
                       thread_attribution,
                       historical_project_id, historical_registration_id,
                       event_facts_recorded, event_provenance, event_occurred_at,
                       event_recorded_at, event_project_name, event_registration_id,
                       event_ticket_id, event_phase_id, event_phase_name,
                       event_ticket_outcome, event_previous_lane, event_current_lane,
                       event_previous_phase_id, event_current_phase_id
                FROM audit_events
                WHERE project_id = ?
                ORDER BY created_at DESC
                """,
                bindings: [.text(projectID.rawValue)]
            )
            let reviewTicketIDs = try Dictionary(
                uniqueKeysWithValues: reviewRows.compactMap { row -> (String, TicketID)? in
                    guard let ticketID = row.activityOptionalText("ticket_id") else { return nil }
                    return (try row.activityText("id"), TicketID(rawValue: ticketID))
                }
            )
            let formatter = ISO8601DateFormatter()
            func lane(for ticketID: TicketID?) -> TicketLane? {
                ticketID.flatMap { ticketLanes[$0] }
            }
            func ticketID(for auditRow: [String: SQLiteValue]) -> TicketID? {
                guard
                    let rawType = auditRow.activityOptionalText("entity_type"),
                    let entityType = AuditEntityType(rawValue: rawType),
                    let entityID = auditRow.activityOptionalText("entity_id")
                else { return nil }

                switch entityType {
                case .ticket, .ticketTaskPlan:
                    return TicketID(rawValue: entityID)
                case .reviewItem:
                    return reviewTicketIDs[entityID]
                default:
                    return nil
                }
            }
            var reviewObservedAt: [String: Date] = [:]
            for row in auditRows where row.activityOptionalText("entity_type") == AuditEntityType.reviewItem.rawValue {
                guard
                    let reviewID = row.activityOptionalText("entity_id"),
                    reviewObservedAt[reviewID] == nil,
                    let observedAt = formatter.date(from: try row.activityText("created_at"))
                else { continue }
                reviewObservedAt[reviewID] = observedAt
            }

            var items = try auditRows.map { row in
                let ticketID = ticketID(for: row)
                let auditID = AuditEventID(rawValue: try row.activityText("id"))
                let auditCreatedAt = formatter.date(from: try row.activityText("created_at"))
                let assignmentEvents = assignmentsByAudit[auditID] ?? []
                let entityType = row.activityOptionalText("entity_type").flatMap(AuditEntityType.init(rawValue:))
                let entityID = row.activityOptionalText("entity_id")
                let phaseID: PhaseID?
                let title: String
                switch entityType {
                case .phasePlan:
                    phaseID = entityID.map(PhaseID.init(rawValue:))
                    title = "Delivery Goal plan updated"
                case .deliveryGoal:
                    phaseID = entityID.flatMap { goalPhases[Data($0.utf8)] }
                    title = "Delivery Goal updated"
                case .phase:
                    phaseID = entityID.map(PhaseID.init(rawValue:))
                    title = "Delivery record updated"
                default:
                    phaseID = assignmentEvents.first?.phaseID ?? ticketID.flatMap { ticketPhases[$0] }
                    title = "Delivery record updated"
                }
                return ProjectActivityItem(
                    id: "audit-\(auditID.rawValue)",
                    identity: .init(
                        projectID: row.activityOptionalText("historical_project_id").map(ProjectID.init(rawValue:)) ?? projectID,
                        registrationID: row.activityOptionalText("event_registration_id")
                            ?? row.activityOptionalText("historical_registration_id"),
                        source: .audit,
                        sourceID: auditID.rawValue
                    ),
                    source: .audit,
                    provenance: .localAudit,
                    title: title,
                    detail: try row.activityText("reason"),
                    observedAt: nil,
                    occurredAt: row.activityOptionalText("event_occurred_at").flatMap(formatter.date(from:)),
                    recordedAt: row.activityOptionalText("event_recorded_at").flatMap(formatter.date(from:))
                        ?? auditCreatedAt,
                    eventFacts: row.activityOptionalInteger("event_facts_recorded") == 1 ? .init(
                        projectName: row.activityOptionalText("event_project_name"),
                        entityType: entityType,
                        entityID: entityID,
                        ticketID: row.activityOptionalText("event_ticket_id").map(TicketID.init(rawValue:)),
                        phaseID: row.activityOptionalText("event_phase_id").map(PhaseID.init(rawValue:)),
                        phaseName: row.activityOptionalText("event_phase_name"),
                        ticketOutcome: row.activityOptionalText("event_ticket_outcome"),
                        previousLane: row.activityOptionalText("event_previous_lane").flatMap(TicketLane.init(rawValue:)),
                        currentLane: row.activityOptionalText("event_current_lane").flatMap(TicketLane.init(rawValue:)),
                        previousPhaseID: row.activityOptionalText("event_previous_phase_id").map(PhaseID.init(rawValue:)),
                        currentPhaseID: row.activityOptionalText("event_current_phase_id").map(PhaseID.init(rawValue:))
                    ) : nil,
                    ticketID: ticketID,
                    deliveryLane: row.activityOptionalText("event_current_lane").flatMap(TicketLane.init(rawValue:)),
                    runtimeState: nil,
                    notificationState: nil,
                    notificationStatusText: nil,
                    phaseID: phaseID,
                    deliveryGoalID: entityType == .deliveryGoal ? entityID.map(DeliveryGoalID.init(rawValue:)) : nil,
                    actorID: row.activityOptionalText("actor_id"),
                    originatingThreadID: row.activityOptionalText("thread_id"),
                    threadAttribution: row.activityOptionalText("thread_attribution").flatMap(ThreadAttribution.init(rawValue:)),
                    assignmentEvents: assignmentEvents
                )
            }
            items += try runtimeRows.map { row in
                let ticketID = row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:))
                let state = RuntimeStateLanguage(storedValue: try row.activityText("status"))
                return ProjectActivityItem(
                    id: "runtime-\(try row.activityText("id"))",
                    identity: .init(
                        projectID: projectID, registrationID: registrationID, source: .runtime,
                        sourceID: "\(try row.activityText("thread_id"))|\(try row.activityText("id"))"
                    ),
                    source: .runtime,
                    provenance: .persistedObservation,
                    title: state.title,
                    detail: try row.activityText("text"),
                    observedAt: formatter.date(from: try row.activityText("last_observed_at")),
                    occurredAt: nil,
                    recordedAt: nil,
                    eventFacts: nil,
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: state,
                    notificationState: nil,
                    notificationStatusText: nil
                )
            }
            items += try reviewRows.map { row in
                let reviewID = try row.activityText("id")
                let ticketID = row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:))
                return ProjectActivityItem(
                    id: "review-\(reviewID)",
                    identity: .init(projectID: projectID, registrationID: registrationID, source: .review, sourceID: reviewID),
                    source: .review,
                    provenance: .reviewRecord,
                    title: "Review \(try row.activityText("status"))",
                    detail: try row.activityText("summary"),
                    observedAt: nil,
                    occurredAt: nil,
                    recordedAt: reviewObservedAt[reviewID],
                    eventFacts: nil,
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: nil,
                    notificationState: nil,
                    notificationStatusText: nil
                )
            }
            items += try completionRows.map { row in
                let ticketID = TicketID(rawValue: try row.activityText("ticket_id"))
                return ProjectActivityItem(
                    id: "completion-\(try row.activityText("id"))",
                    identity: .init(
                        projectID: projectID, registrationID: registrationID, source: .completion,
                        sourceID: try row.activityText("id")
                    ),
                    source: .completion,
                    provenance: .completionRecord,
                    title: "Completed",
                    detail: try row.activityText("summary"),
                    observedAt: nil,
                    occurredAt: formatter.date(from: try row.activityText("created_at")),
                    recordedAt: nil,
                    eventFacts: nil,
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: RuntimeStateLanguage(storedValue: "completed"),
                    notificationState: nil,
                    notificationStatusText: nil
                )
            }
            items += try notificationRows.map { row in
                let ticketID = row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:))
                let rawState = try row.activityText("state")
                let fallbackTitle = try row.activityText("fingerprint")
                let state = NotificationDeliveryState(rawValue: rawState)
                    ?? (rawState.lowercased() == "delivered" ? .sent : nil)
                return ProjectActivityItem(
                    id: "notification-\(try row.activityText("id"))",
                    identity: .init(
                        projectID: projectID, registrationID: registrationID, source: .notification,
                        sourceID: try row.activityText("id")
                    ),
                    source: .notification,
                    provenance: .notificationDelivery,
                    title: row.activityOptionalText("title") ?? fallbackTitle,
                    detail: row.activityOptionalText("message") ?? "Persisted notification delivery event.",
                    observedAt: nil,
                    occurredAt: row.activityOptionalText("created_at").flatMap(formatter.date(from:)),
                    recordedAt: row.activityOptionalText("completed_at").flatMap(formatter.date(from:)),
                    eventFacts: nil,
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: nil,
                    notificationState: state,
                    notificationStatusText: Self.notificationStatus(
                        state: state,
                        failureCode: row.activityOptionalText("failure_code")
                    )
                )
            }
            items.sort(by: Self.ordersBefore)
            return ProjectActivityProjection(projectID: projectID, items: items)
        }
    }

    static func loadRemoved(
        from store: DeliveryStore,
        removalID: ProjectRemovalID
    ) async throws -> ProjectActivityProjection {
        try await store.read { connection in
            guard let removal = try connection.row(
                "SELECT historical_project_id, registration_id FROM removed_projects WHERE removal_id = ?",
                bindings: [.text(removalID.rawValue)]
            ) else { throw ProjectRemovalError.removalRecordNotFound }
            let projectID = ProjectID(rawValue: try removal.activityText("historical_project_id"))
            let registrationID = try removal.activityText("registration_id")
            let formatter = ISO8601DateFormatter()
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            func lifecycleDate(_ row: [String: SQLiteValue], column: String) -> Date? {
                guard let value = row.activityOptionalText(column) else { return nil }
                return fractionalFormatter.date(from: value) ?? formatter.date(from: value)
            }

            func lifecycle(_ row: [String: SQLiteValue], column: String) throws -> PhaseLifecycle {
                let value = try row.activityText(column)
                guard let lifecycle = PhaseLifecycle(rawValue: value) else {
                    throw ProjectActivityProjectionError.invalidColumn(column)
                }
                return lifecycle
            }
            func action(_ row: [String: SQLiteValue]) throws -> PhaseLifecycleAction {
                let value = try row.activityText("action")
                guard let action = PhaseLifecycleAction(rawValue: value) else {
                    throw ProjectActivityProjectionError.invalidColumn("action")
                }
                return action
            }

            let retainedLifecycleRows = try connection.activityRows(
                "SELECT * FROM retained_phase_lifecycles WHERE removal_id = ? ORDER BY phase_id",
                bindings: [.text(removalID.rawValue)]
            )
            let retainedLifecycleItems = try retainedLifecycleRows.map { row in
                let historicalProjectID = ProjectID(rawValue: try row.activityText("historical_project_id"))
                guard historicalProjectID == projectID else {
                    throw ProjectActivityProjectionError.invalidColumn("historical_project_id")
                }
                let phaseID = PhaseID(rawValue: try row.activityText("phase_id"))
                let phaseName = try row.activityText("phase_name")
                let current = try lifecycle(row, column: "lifecycle")
                let revision = try row.activityInteger("revision")
                let activity = RetainedPhaseLifecycleActivity(
                    kind: .current, removalID: removalID,
                    historicalProjectID: historicalProjectID, phaseID: phaseID,
                    phaseName: phaseName, lifecycle: current, revision: revision,
                    previousLifecycle: nil, action: nil, reason: nil,
                    auditEventID: nil, registration: nil,
                    planningBaselineDigest: row.activityOptionalText("completion_baseline_digest")
                )
                return ProjectActivityItem(
                    id: "phase-lifecycle-current-\(phaseID.rawValue)",
                    identity: .init(projectID: historicalProjectID, registrationID: registrationID, source: .audit, sourceID: "phase-lifecycle-current-\(phaseID.rawValue)"),
                    source: .audit, provenance: .retainedSource,
                    title: "Phase lifecycle · \(phaseName)",
                    detail: "Current · \(current.displayName) · revision \(revision)",
                    observedAt: nil,
                    occurredAt: nil, recordedAt: lifecycleDate(row, column: "updated_at"),
                    eventFacts: nil,
                    ticketID: nil, deliveryLane: nil, runtimeState: nil,
                    notificationState: nil, notificationStatusText: nil,
                    phaseID: phaseID, retainedPhaseLifecycle: activity
                )
            }
            let retainedLifecycleEventRows = try connection.activityRows(
                "SELECT * FROM retained_phase_lifecycle_events WHERE removal_id = ? ORDER BY phase_id, revision",
                bindings: [.text(removalID.rawValue)]
            )
            var lifecycleEventsByAuditID: [AuditEventID: [String: SQLiteValue]] = [:]
            for row in retainedLifecycleEventRows {
                let historicalProjectID = ProjectID(rawValue: try row.activityText("historical_project_id"))
                guard historicalProjectID == projectID else {
                    throw ProjectActivityProjectionError.invalidColumn("historical_project_id")
                }
                let auditEventID = AuditEventID(rawValue: try row.activityText("audit_event_id"))
                lifecycleEventsByAuditID[auditEventID] = row
            }

            var assignmentsByAudit: [AuditEventID: [DeliveryGoalAssignmentEventRecord]] = [:]
            for row in try connection.activityRows(
                "SELECT * FROM retained_delivery_goal_assignment_events WHERE removal_id = ? ORDER BY revision, ticket_id",
                bindings: [.text(removalID.rawValue)]
            ) {
                let auditID = AuditEventID(rawValue: try row.activityText("audit_event_id"))
                assignmentsByAudit[auditID, default: []].append(.init(
                    auditEventID: auditID,
                    projectID: ProjectID(rawValue: try row.activityText("project_id")),
                    phaseID: PhaseID(rawValue: try row.activityText("phase_id")),
                    ticketID: TicketID(rawValue: try row.activityText("ticket_id")),
                    previousGoalID: row.activityOptionalText("previous_goal_id").map(DeliveryGoalID.init(rawValue:)),
                    currentGoalID: row.activityOptionalText("current_goal_id").map(DeliveryGoalID.init(rawValue:)),
                    revision: try row.activityInteger("revision"),
                    action: try row.activityText("action")
                ))
            }

            var items = try connection.activityRows(
                """
                SELECT id, actor_id, reason, created_at, entity_type, entity_id, thread_id,
                       thread_attribution,
                       event_facts_recorded, event_occurred_at, event_recorded_at,
                       event_project_name, event_registration_id, event_ticket_id,
                       event_phase_id, event_phase_name, event_ticket_outcome,
                       event_previous_lane, event_current_lane,
                       event_previous_phase_id, event_current_phase_id
                FROM audit_events
                WHERE historical_project_id = ? AND historical_registration_id = ?
                ORDER BY created_at DESC
                """,
                bindings: [.text(projectID.rawValue), .text(registrationID)]
            ).compactMap { row -> ProjectActivityItem? in
                let auditID = AuditEventID(rawValue: try row.activityText("id"))
                let auditCreatedAt = formatter.date(from: try row.activityText("created_at"))
                let auditReason = try row.activityText("reason")
                let entityType = row.activityOptionalText("entity_type").flatMap(AuditEntityType.init(rawValue:))
                let entityID = row.activityOptionalText("entity_id")
                let assignments = assignmentsByAudit[auditID] ?? []
                let lifecycleRow = lifecycleEventsByAuditID[auditID]
                let retainedLifecycle: RetainedPhaseLifecycleActivity? = try lifecycleRow.map { lifecycleRow in
                    let phaseID = PhaseID(rawValue: try lifecycleRow.activityText("phase_id"))
                    let eventPhaseName = row.activityOptionalText("event_phase_name") ?? "Unknown"
                    return .init(
                        kind: .transition, removalID: removalID,
                        historicalProjectID: projectID, phaseID: phaseID,
                        phaseName: eventPhaseName,
                        lifecycle: try lifecycle(lifecycleRow, column: "current_lifecycle"),
                        revision: try lifecycleRow.activityInteger("revision"),
                        previousLifecycle: try lifecycle(lifecycleRow, column: "previous_lifecycle"),
                        action: try action(lifecycleRow),
                        reason: try lifecycleRow.activityText("reason"),
                        auditEventID: auditID,
                        registration: .init(
                            projectID: projectID,
                            registrationID: try lifecycleRow.activityText("registration_id"),
                            requestGeneration: try lifecycleRow.activityInteger("request_generation")
                        ),
                        planningBaselineDigest: lifecycleRow.activityOptionalText("planning_baseline_digest")
                    )
                }
                let ticketID: TicketID?
                switch entityType {
                case .ticket, .ticketTaskPlan: ticketID = entityID.map(TicketID.init(rawValue:))
                default: ticketID = assignments.first?.ticketID
                }
                return ProjectActivityItem(
                    id: "audit-\(auditID.rawValue)",
                    identity: .init(projectID: projectID, registrationID: row.activityOptionalText("event_registration_id") ?? registrationID, source: .audit, sourceID: auditID.rawValue),
                    source: .audit, provenance: .localAudit,
                    title: retainedLifecycle.map { "Phase lifecycle transition · \($0.phaseName)" }
                        ?? (entityType == .deliveryGoal ? "Delivery Goal updated" : "Delivery record updated"),
                    detail: retainedLifecycle.map {
                        "\($0.previousLifecycle?.displayName ?? "Unknown") → \($0.lifecycle.displayName) · \($0.action?.displayName ?? "Unknown") · revision \($0.revision) · \($0.reason ?? "Unknown")"
                    } ?? auditReason,
                    observedAt: nil,
                    occurredAt: row.activityOptionalText("event_occurred_at").flatMap(formatter.date(from:)),
                    recordedAt: row.activityOptionalText("event_recorded_at").flatMap(formatter.date(from:))
                        ?? auditCreatedAt,
                    eventFacts: row.activityOptionalInteger("event_facts_recorded") == 1 ? .init(
                        projectName: row.activityOptionalText("event_project_name"), entityType: entityType,
                        entityID: entityID,
                        ticketID: row.activityOptionalText("event_ticket_id").map(TicketID.init(rawValue:)),
                        phaseID: row.activityOptionalText("event_phase_id").map(PhaseID.init(rawValue:)),
                        phaseName: row.activityOptionalText("event_phase_name"),
                        ticketOutcome: row.activityOptionalText("event_ticket_outcome"),
                        previousLane: row.activityOptionalText("event_previous_lane").flatMap(TicketLane.init(rawValue:)),
                        currentLane: row.activityOptionalText("event_current_lane").flatMap(TicketLane.init(rawValue:)),
                        previousPhaseID: row.activityOptionalText("event_previous_phase_id").map(PhaseID.init(rawValue:)),
                        currentPhaseID: row.activityOptionalText("event_current_phase_id").map(PhaseID.init(rawValue:))
                    ) : nil,
                    ticketID: ticketID, deliveryLane: nil, runtimeState: nil,
                    notificationState: nil, notificationStatusText: nil,
                    phaseID: retainedLifecycle?.phaseID ?? assignments.first?.phaseID
                        ?? (entityType == .phase ? entityID.map(PhaseID.init(rawValue:)) : nil),
                    deliveryGoalID: entityType == .deliveryGoal ? entityID.map(DeliveryGoalID.init(rawValue:)) : nil,
                    actorID: row.activityOptionalText("actor_id"),
                    originatingThreadID: row.activityOptionalText("thread_id"),
                    threadAttribution: row.activityOptionalText("thread_attribution").flatMap(ThreadAttribution.init(rawValue:)),
                    assignmentEvents: assignments,
                    retainedPhaseLifecycle: retainedLifecycle
                )
            }

            items += retainedLifecycleItems

            items += try connection.activityRows(
                "SELECT * FROM retained_project_activity_events WHERE removal_id = ?",
                bindings: [.text(removalID.rawValue)]
            ).map { row in
                guard let source = ActivitySource(rawValue: try row.activityText("source")) else {
                    throw ProjectActivityProjectionError.invalidColumn("source")
                }
                let runtime = row.activityOptionalText("runtime_state").map(RuntimeStateLanguage.init(storedValue:))
                let notification = row.activityOptionalText("notification_state").flatMap(NotificationDeliveryState.init(rawValue:))
                let lane = row.activityOptionalText("delivery_lane").flatMap(TicketLane.init(rawValue:))
                let rawSourceID = try row.activityText("source_id")
                let sourceID: String
                if source == .runtime,
                   !rawSourceID.contains("|"),
                   let threadID = row.activityOptionalText("originating_thread_id") {
                    sourceID = "\(threadID)|\(rawSourceID)"
                } else {
                    sourceID = rawSourceID
                }
                return ProjectActivityItem(
                    id: "\(source.rawValue)-\(sourceID)",
                    identity: .init(projectID: projectID, registrationID: registrationID, source: source, sourceID: sourceID),
                    source: source, provenance: .retainedSource,
                    title: try row.activityText("title"), detail: try row.activityText("detail"),
                    observedAt: row.activityOptionalText("observed_at").flatMap(formatter.date(from:)),
                    occurredAt: row.activityOptionalText("occurred_at").flatMap(formatter.date(from:)),
                    recordedAt: row.activityOptionalText("recorded_at").flatMap(formatter.date(from:)),
                    eventFacts: nil,
                    ticketID: row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:)),
                    deliveryLane: lane, runtimeState: runtime, notificationState: notification,
                    notificationStatusText: row.activityOptionalText("notification_status_text"),
                    phaseID: row.activityOptionalText("phase_id").map(PhaseID.init(rawValue:)),
                    deliveryGoalID: row.activityOptionalText("delivery_goal_id").map(DeliveryGoalID.init(rawValue:)),
                    originatingThreadID: row.activityOptionalText("originating_thread_id")
                )
            }
            items.sort(by: Self.ordersBefore)
            return .init(projectID: projectID, items: items)
        }
    }

    private static func ordersBefore(_ lhs: ProjectActivityItem, _ rhs: ProjectActivityItem) -> Bool {
        switch (lhs.timelineDate, rhs.timelineDate) {
        case let (lhsDate?, rhsDate?): lhsDate == rhsDate ? lhs.id < rhs.id : lhsDate > rhsDate
        case (_?, nil): true
        case (nil, _?): false
        case (nil, nil): lhs.id < rhs.id
        }
    }

    private static func notificationStatus(
        state: NotificationDeliveryState?,
        failureCode: String?
    ) -> String {
        switch state {
        case .queued: "Queued"
        case .attemptStarted: "Sending"
        case .unknown: "Delivery unknown · Not retried automatically"
        case .sent: "Pushover delivered"
        case .suppressed: "Suppressed when project was archived"
        case .failed:
            switch failureCode {
            case "credentials_missing": "Delivery failed · Credentials missing"
            case "provider_rejected": "Delivery failed · Provider rejected"
            case "invalid_provider_response": "Delivery failed · Invalid provider response"
            default: "Delivery failed · Transport unavailable"
            }
        case nil: "Persisted delivery status"
        }
    }
}

enum ProjectActivityProjectionError: Error, Equatable {
    case missingColumn(String)
    case invalidColumn(String)
    case invalidLane(String)
}

private extension SQLiteConnection {
    func activityRows(_ sql: String, bindings: [SQLiteValue]) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row("\(sql) LIMIT 1 OFFSET ?", bindings: bindings + [.integer(offset)]) {
            rows.append(row)
            offset += 1
        }
        return rows
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func activityText(_ column: String) throws -> String {
        guard let value = self[column] else { throw ProjectActivityProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw ProjectActivityProjectionError.invalidColumn(column) }
        return text
    }

    func activityOptionalText(_ column: String) -> String? {
        guard case let .text(text)? = self[column] else { return nil }
        return text
    }

    func activityOptionalInteger(_ column: String) -> Int64? {
        guard case let .integer(integer)? = self[column] else { return nil }
        return integer
    }

    func activityInteger(_ column: String) throws -> Int64 {
        guard let value = self[column] else { throw ProjectActivityProjectionError.missingColumn(column) }
        guard case let .integer(integer) = value else { throw ProjectActivityProjectionError.invalidColumn(column) }
        return integer
    }
}

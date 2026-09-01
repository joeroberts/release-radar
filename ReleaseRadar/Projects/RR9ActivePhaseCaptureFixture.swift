#if DEBUG
import Foundation
import ReleaseRadarCore

enum RR9ActivePhaseCaptureScenario: String, Sendable {
    case happy
    case busy
    case noAlternative = "no-alternative"
    case mutationFailure = "mutation-failure"
    case unavailable
    case authorizationFailure = "authorization-failure"
    case savedRefresh = "saved-refresh"
    case emptyPhase = "empty-phase"
    case noActivePointer = "no-active-pointer"
    case crossPhaseDetail = "cross-phase-detail"
}

enum RR9ActivePhaseCaptureError: Error, LocalizedError {
    case savedRefresh

    var errorDescription: String? {
        "The active phase was saved, but the dashboard refresh failed."
    }
}

enum RR9ActivePhaseCaptureFixture {
    static let primaryProjectID = ProjectID(rawValue: "rr9-capture-primary")
    static let happyProjectID = ProjectID(rawValue: "rr9-capture-happy")
    static let emptyProjectID = ProjectID(rawValue: "rr9-capture-empty")
    static let soleProjectID = ProjectID(rawValue: "rr9-capture-sole")
    static let noPointerProjectID = ProjectID(rawValue: "rr9-capture-no-pointer")
    static let authorizationProjectID = ProjectID(rawValue: "rr9-capture-authorization")
    static let savedRefreshProjectID = ProjectID(rawValue: "rr9-capture-saved-refresh")

    static let currentPhaseID = PhaseID(rawValue: "phase-current")
    static let roadmapPhaseID = PhaseID(rawValue: "phase-roadmap")
    static let emptyPhaseID = PhaseID(rawValue: "phase-empty")
    static let happyCurrentPhaseID = PhaseID(rawValue: "rr9-happy-current")
    static let happyTargetPhaseID = PhaseID(rawValue: "rr9-happy-target")
    static let emptyCurrentPhaseID = PhaseID(rawValue: "rr9-empty-current")
    static let emptyTargetPhaseID = PhaseID(rawValue: "rr9-empty-target")
    static let crossPhaseSourceTicketID = TicketID(rawValue: "RR9-CURRENT-CROSS")
    static let crossPhaseTargetTicketID = TicketID(rawValue: "RR9-ROADMAP-TARGET")

    private struct AuthorizedRoot: Sendable {
        let projectID: ProjectID
        let rootID: String
        let folderName: String
    }

    static func projectID(for scenario: RR9ActivePhaseCaptureScenario) -> ProjectID {
        switch scenario {
        case .happy:
            happyProjectID
        case .emptyPhase:
            emptyProjectID
        case .noAlternative:
            soleProjectID
        case .authorizationFailure:
            authorizationProjectID
        case .savedRefresh:
            savedRefreshProjectID
        case .noActivePointer:
            noPointerProjectID
        case .busy, .mutationFailure, .unavailable, .crossPhaseDetail:
            primaryProjectID
        }
    }

    static func seedIfNeeded(
        in store: DeliveryStore,
        rootDirectory: URL,
        scenario: RR9ActivePhaseCaptureScenario
    ) async throws {
        let exists = try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM projects WHERE id = ?",
                bindings: [.text(primaryProjectID.rawValue)]
            ) == 1
        }
        guard !exists else { return }

        let rootDirectory = canonical(rootDirectory)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let authorizedRoots = [
            AuthorizedRoot(projectID: primaryProjectID, rootID: "rr9-capture-primary-root", folderName: "primary"),
            AuthorizedRoot(projectID: happyProjectID, rootID: "rr9-capture-happy-root", folderName: "happy"),
            AuthorizedRoot(projectID: emptyProjectID, rootID: "rr9-capture-empty-root", folderName: "empty"),
            AuthorizedRoot(projectID: soleProjectID, rootID: "rr9-capture-sole-root", folderName: "sole"),
            AuthorizedRoot(projectID: noPointerProjectID, rootID: "rr9-capture-no-pointer-root", folderName: "no-pointer"),
            AuthorizedRoot(projectID: savedRefreshProjectID, rootID: "rr9-capture-saved-refresh-root", folderName: "saved-refresh"),
        ]
        let bookmarkStore = ProjectBookmarkStore()
        var bookmarkFixtures: [(AuthorizedRoot, URL, Data)] = []
        for root in authorizedRoots {
            let url = canonical(rootDirectory.appendingPathComponent(root.folderName, isDirectory: true))
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            bookmarkFixtures.append((root, url, try bookmarkStore.makeBookmark(for: url)))
        }
        let authorizationRoot = canonical(
            rootDirectory.appendingPathComponent("authorization", isDirectory: true)
        )
        try FileManager.default.createDirectory(at: authorizationRoot, withIntermediateDirectories: true)
        let preparedBookmarkFixtures = bookmarkFixtures

        try await store.transact(
            actor: DeliveryActor(id: "release-radar.rr9-capture-seed"),
            reason: "Seed RR-R9 active phase capture fixture",
            auditEventID: AuditEventID(rawValue: "rr9-capture-seed-audit"),
            auditScope: AuditScope(projectID: primaryProjectID, entityType: .phase, entityID: currentPhaseID.rawValue)
        ) { connection in
            try insertProject(primaryProjectID, name: "RR-R9 Active Phase", connection: connection)
            try insertProject(happyProjectID, name: "RR-R9 Happy Path", connection: connection)
            try insertProject(emptyProjectID, name: "RR-R9 Empty Target", connection: connection)
            try insertProject(soleProjectID, name: "RR-R9 No Alternative", connection: connection)
            try insertProject(noPointerProjectID, name: "RR-R9 No Active Pointer", connection: connection)
            try insertProject(authorizationProjectID, name: "RR-R9 Authorization Recovery", connection: connection)
            try insertProject(savedRefreshProjectID, name: "RR-R9 Saved Refresh", connection: connection)

            for (root, url, bookmark) in preparedBookmarkFixtures {
                try connection.execute(
                    "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                    bindings: [.text(root.rootID), .text(root.projectID.rawValue), .text(url.path)]
                )
                try connection.execute(
                    "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)",
                    bindings: [.text(root.projectID.rawValue), .text(url.path), .blob(bookmark)]
                )
            }
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('rr9-capture-authorization-root', ?, ?)",
                bindings: [.text(authorizationProjectID.rawValue), .text(authorizationRoot.path)]
            )

            try insertPhase(currentPhaseID, projectID: primaryProjectID, name: "Current", connection: connection)
            try insertPhase(PhaseID(rawValue: "phase-history"), projectID: primaryProjectID, name: "History", connection: connection)
            try insertPhase(roadmapPhaseID, projectID: primaryProjectID, name: "Roadmap delivery", connection: connection)
            try insertPhase(PhaseID(rawValue: "phase-order-z"), projectID: primaryProjectID, name: "ROADMAP", connection: connection)
            try insertPhase(PhaseID(rawValue: "phase-order-a"), projectID: primaryProjectID, name: "Roadmap", connection: connection)
            try insertPhase(emptyPhaseID, projectID: primaryProjectID, name: "Empty phase", connection: connection)
            try insertActivePhase(currentPhaseID, projectID: primaryProjectID, connection: connection)

            try insertTicket(
                crossPhaseSourceTicketID,
                projectID: primaryProjectID,
                phaseID: currentPhaseID,
                outcome: "Keeps a valid cross-phase requirement visible in ticket detail.",
                lane: .inProgress,
                connection: connection
            )
            try insertTicket(
                TicketID(rawValue: "RR9-CURRENT-READY"),
                projectID: primaryProjectID,
                phaseID: currentPhaseID,
                outcome: "Keeps the current board scoped to current work.",
                lane: .backlog,
                connection: connection
            )
            for index in 1...8 {
                let id = index == 1 ? crossPhaseTargetTicketID : TicketID(rawValue: "RR9-ROADMAP-B\(index)")
                try insertTicket(
                    id,
                    projectID: primaryProjectID,
                    phaseID: roadmapPhaseID,
                    outcome: "Roadmap backlog outcome \(index).",
                    lane: .backlog,
                    connection: connection
                )
            }
            for index in 1...3 {
                try insertTicket(
                    TicketID(rawValue: "RR9-ROADMAP-X\(index)"),
                    projectID: primaryProjectID,
                    phaseID: roadmapPhaseID,
                    outcome: "Roadmap blocked outcome \(index).",
                    lane: .blocked,
                    connection: connection
                )
            }
            try insertTicket(
                TicketID(rawValue: "RR9-HISTORY"),
                projectID: primaryProjectID,
                phaseID: PhaseID(rawValue: "phase-history"),
                outcome: "Preserves accepted historical work.",
                lane: .accepted,
                connection: connection
            )
            try connection.execute(
                "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('rr9-capture-cross-dependency', ?, ?, ?)",
                bindings: [
                    .text(primaryProjectID.rawValue),
                    .text(crossPhaseSourceTicketID.rawValue),
                    .text(crossPhaseTargetTicketID.rawValue),
                ]
            )
            try connection.execute(
                "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('rr9-capture-roadmap-dependency', ?, 'RR9-ROADMAP-X1', ?)",
                bindings: [.text(primaryProjectID.rawValue), .text(crossPhaseTargetTicketID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('rr9-capture-phase-dependency', ?, ?, ?)",
                bindings: [.text(primaryProjectID.rawValue), .text(roadmapPhaseID.rawValue), .text(currentPhaseID.rawValue)]
            )

            try insertPhase(happyCurrentPhaseID, projectID: happyProjectID, name: "Current", connection: connection)
            try insertPhase(happyTargetPhaseID, projectID: happyProjectID, name: "Roadmap delivery", connection: connection)
            try insertActivePhase(happyCurrentPhaseID, projectID: happyProjectID, connection: connection)
            try insertTicket(
                TicketID(rawValue: "RR9-HAPPY-CURRENT"),
                projectID: happyProjectID,
                phaseID: happyCurrentPhaseID,
                outcome: "Shows the happy-path current board before selection.",
                lane: .inProgress,
                connection: connection
            )
            try insertTicket(
                TicketID(rawValue: "RR9-HAPPY-TARGET"),
                projectID: happyProjectID,
                phaseID: happyTargetPhaseID,
                outcome: "Shows the coherently refreshed happy-path target board.",
                lane: .backlog,
                connection: connection
            )

            try insertPhase(emptyCurrentPhaseID, projectID: emptyProjectID, name: "Current", connection: connection)
            try insertPhase(emptyTargetPhaseID, projectID: emptyProjectID, name: "Empty phase", connection: connection)
            try insertActivePhase(emptyCurrentPhaseID, projectID: emptyProjectID, connection: connection)
            try insertTicket(
                TicketID(rawValue: "RR9-EMPTY-CURRENT"),
                projectID: emptyProjectID,
                phaseID: emptyCurrentPhaseID,
                outcome: "Shows work clearing when the empty target becomes active.",
                lane: .inProgress,
                connection: connection
            )

            let solePhaseID = PhaseID(rawValue: "rr9-sole-phase")
            try insertPhase(solePhaseID, projectID: soleProjectID, name: "Only phase", connection: connection)
            try insertActivePhase(solePhaseID, projectID: soleProjectID, connection: connection)

            try insertPhase(PhaseID(rawValue: "rr9-pointer-first"), projectID: noPointerProjectID, name: "First candidate", connection: connection)
            try insertPhase(PhaseID(rawValue: "rr9-pointer-second"), projectID: noPointerProjectID, name: "Second candidate", connection: connection)

            let authorizationCurrent = PhaseID(rawValue: "rr9-authorization-current")
            try insertPhase(authorizationCurrent, projectID: authorizationProjectID, name: "Current", connection: connection)
            try insertPhase(PhaseID(rawValue: "rr9-authorization-target"), projectID: authorizationProjectID, name: "Target", connection: connection)
            try insertActivePhase(authorizationCurrent, projectID: authorizationProjectID, connection: connection)

            let savedCurrent = PhaseID(rawValue: "rr9-saved-current")
            try insertPhase(savedCurrent, projectID: savedRefreshProjectID, name: "Current", connection: connection)
            try insertPhase(PhaseID(rawValue: "rr9-saved-target"), projectID: savedRefreshProjectID, name: "Saved target", connection: connection)
            try insertActivePhase(savedCurrent, projectID: savedRefreshProjectID, connection: connection)
        }
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func insertProject(
        _ projectID: ProjectID,
        name: String,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 1)",
            bindings: [.text(projectID.rawValue), .text(name)]
        )
    }

    private static func insertPhase(
        _ phaseID: PhaseID,
        projectID: ProjectID,
        name: String,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
            bindings: [.text(phaseID.rawValue), .text(projectID.rawValue), .text(name)]
        )
    }

    private static func insertActivePhase(
        _ phaseID: PhaseID,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            "INSERT INTO project_active_phases (project_id, phase_id) VALUES (?, ?)",
            bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
        )
    }

    private static func insertTicket(
        _ ticketID: TicketID,
        projectID: ProjectID,
        phaseID: PhaseID,
        outcome: String,
        lane: TicketLane,
        connection: SQLiteConnection
    ) throws {
        let stagedLane = lane == .accepted ? TicketLane.backlog : lane
        try connection.execute(
            "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
            bindings: [
                .text(ticketID.rawValue), .text(projectID.rawValue), .text(phaseID.rawValue),
                .text(outcome), .text(stagedLane.rawValue),
            ]
        )
        if lane == .accepted {
            try TicketTaskPlanningPolicy.assertCanAcceptTicket(
                projectID: projectID,
                ticketID: ticketID,
                expectedRevision: nil,
                connection: connection
            )
            try connection.execute(
                "UPDATE tickets SET lane = ? WHERE project_id = ? AND id = ?",
                bindings: [
                    .text(TicketLane.accepted.rawValue),
                    .text(projectID.rawValue),
                    .text(ticketID.rawValue),
                ]
            )
        }
    }
}
#endif

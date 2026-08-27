import Foundation
import ReleaseRadarCore

enum DashboardSampleData {
    static let projectID = ProjectID(rawValue: "rekon-pursuit")
    static let phaseID = PhaseID(rawValue: "rekon-pursuit-post-mvp")

    private struct TicketSeed: Sendable {
        let id: String
        let outcome: String
        let lane: TicketLane
    }

    private static let tickets: [TicketSeed] = [
        .init(id: "DESIGN-V2", outcome: "Defines one cohesive visual language across the dashboard.", lane: .backlog),
        .init(id: "VD2-09", outcome: "Packages verified release evidence for owner sign-off.", lane: .backlog),
        .init(id: "UX-D12", outcome: "Makes local search intent and results predictable.", lane: .backlog),
        .init(id: "P2A-1", outcome: "Hands phase-two delivery to agents with explicit context.", lane: .backlog),
        .init(id: "QA-11", outcome: "Confirms critical workflows remain stable before release.", lane: .backlog),
        .init(id: "SEC-10", outcome: "Confirms local delivery data stays private and bounded.", lane: .backlog),
        .init(id: "DOC-09", outcome: "Explains daily owner operations and recovery paths.", lane: .backlog),
        .init(id: "PERF-08", outcome: "Keeps phase-board rendering within the approved performance budget.", lane: .backlog),
        .init(id: "REL-07", outcome: "Produces a signed release candidate ready for validation.", lane: .backlog),
        .init(id: "VD2-08", outcome: "Verifies the dashboard’s visual fidelity and accessibility before release.", lane: .inProgress),
        .init(id: "UX-D10", outcome: "Confirms exported delivery records before they leave the app.", lane: .needsReview),
        .init(id: "VD2-07d", outcome: "Finds local delivery records with precise matching.", lane: .needsReview),
        .init(id: "VD2-07c", outcome: "Makes delivery activity and AI context understandable to the owner.", lane: .blocked),
        .init(id: "VD2-07", outcome: "Separates settings concerns into a maintainable app architecture.", lane: .accepted),
        .init(id: "VD2-06", outcome: "Makes project contacts clear and actionable.", lane: .accepted),
        .init(id: "VD2-05", outcome: "Moves delivery records safely through the approved pipeline.", lane: .accepted),
        .init(id: "VD2-04", outcome: "Onboards folder-backed projects with recoverable authorization.", lane: .accepted),
        .init(id: "VD2-03", outcome: "Exposes bounded agent actions through the typed bridge.", lane: .accepted),
        .init(id: "RR-04", outcome: "Authorizes project folders and preserves recoverable access.", lane: .accepted),
        .init(id: "RR-03", outcome: "Lets agents update delivery through validated typed actions.", lane: .accepted),
        .init(id: "RR-02", outcome: "Persists delivery state transactionally in the local store.", lane: .accepted),
        .init(id: "RR-01", outcome: "Establishes the signed and sandboxed application foundation.", lane: .accepted),
        .init(id: "UX-D09", outcome: "Keeps project navigation clear at every depth.", lane: .accepted),
        .init(id: "UX-D08", outcome: "Translates runtime and delivery states into readable language.", lane: .accepted),
        .init(id: "UX-D07", outcome: "Makes owner attention requests visible and actionable.", lane: .accepted),
        .init(id: "CORE-06", outcome: "Attributes every consequential delivery update to its actor.", lane: .accepted),
        .init(id: "CORE-05", outcome: "Keeps delivery evidence available and visibly recoverable.", lane: .accepted),
        .init(id: "CORE-04", outcome: "Records blockers without hiding their resolution history.", lane: .accepted),
        .init(id: "CORE-03", outcome: "Preserves acyclic ticket dependencies and their direction.", lane: .accepted),
        .init(id: "CORE-02", outcome: "Uses exactly five persisted delivery lanes everywhere.", lane: .accepted),
        .init(id: "CORE-01", outcome: "Persists project and phase identity without guessing.", lane: .accepted),
    ]

    private static let dependencies: [(String, String)] = [
        ("VD2-06", "VD2-03"), ("VD2-06", "VD2-04"),
        ("VD2-07", "VD2-04"), ("VD2-07", "VD2-05"),
        ("VD2-08", "VD2-06"), ("VD2-08", "VD2-07"),
        ("VD2-08", "VD2-03"), ("VD2-08", "VD2-04"),
        ("DESIGN-V2", "VD2-08"), ("P2A-1", "VD2-08"),
        ("UX-D10", "VD2-06"), ("UX-D10", "VD2-07"),
        ("VD2-07d", "VD2-06"),
        ("VD2-07c", "VD2-03"), ("VD2-07c", "VD2-04"), ("VD2-07c", "VD2-05"),
        ("UX-D12", "VD2-07c"), ("UX-D12", "VD2-08"),
    ]

    static func seedIfNeeded(in store: DeliveryStore) async throws {
        let exists = try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM projects WHERE id = ?",
                bindings: [.text(projectID.rawValue)]
            ) == 1
        }
        guard !exists else { return }

        try await store.transact(
            actor: DeliveryActor(id: "release-radar.sample-seed"),
            reason: "Seed RR-06 dashboard examples including VD2-07c",
            auditEventID: AuditEventID(rawValue: "rr06-dashboard-seed-audit"),
            auditScope: AuditScope(projectID: projectID, entityType: .ticket, entityID: "VD2-07c")
        ) { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 0)",
                bindings: [.text(projectID.rawValue), .text("Rekon Pursuit")]
            )
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
                bindings: [.text(phaseID.rawValue), .text(projectID.rawValue), .text("Post-MVP refinement")]
            )
            try connection.execute(
                "INSERT INTO project_active_phases (phase_id, project_id) VALUES (?, ?)",
                bindings: [.text(phaseID.rawValue), .text(projectID.rawValue)]
            )
            for ticket in tickets {
                try connection.execute(
                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
                    bindings: [
                        .text(ticket.id), .text(projectID.rawValue), .text(phaseID.rawValue),
                        .text(ticket.outcome), .text(ticket.lane.rawValue),
                    ]
                )
            }
            for (offset, dependency) in dependencies.enumerated() {
                try connection.execute(
                    "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES (?, ?, ?, ?)",
                    bindings: [
                        .text("rr06-dependency-\(offset)"), .text(projectID.rawValue),
                        .text(dependency.0), .text(dependency.1),
                    ]
                )
            }
            try connection.execute(
                "INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES (?, ?, ?, ?)",
                bindings: [
                    .text("rr06-blocker-policy"), .text(projectID.rawValue), .text("VD2-07c"),
                    .text("Policy decision required before work can continue."),
                ]
            )
            try connection.execute(
                "INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES (?, ?, ?, ?)",
                bindings: [
                    .text("rr06-blocker-search"), .text(projectID.rawValue), .text("UX-D12"),
                    .text("Search vocabulary needs owner confirmation."),
                ]
            )
            try connection.execute(
                "INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES (?, ?, ?, ?, 1)",
                bindings: [
                    .text("rr06-evidence-policy"), .text(projectID.rawValue), .text("VD2-07c"),
                    .text("evidence/Activity areas decision record"),
                ]
            )

            let observedAt = "2026-08-23T22:14:00Z"
            try connection.execute(
                "INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES (?, ?, ?, ?)",
                bindings: [.text("rr06-thread-vd2-07c"), .text(projectID.rawValue), .text("blocked"), .text(observedAt)]
            )
            try connection.execute(
                "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES (?, ?, ?, ?, ?, ?)",
                bindings: [
                    .text("rr06-goal-vd2-07c"), .text(projectID.rawValue), .text("rr06-thread-vd2-07c"),
                    .text("Blocked"), .text("Resolve the policy boundary for Activity and AI areas."), .text(observedAt),
                ]
            )
            try connection.execute(
                "INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES (?, ?, ?, ?)",
                bindings: [
                    .text("rr06-link-vd2-07c"), .text(projectID.rawValue), .text("VD2-07c"), .text("rr06-thread-vd2-07c"),
                ]
            )
            try connection.execute(
                "INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES (?, ?, ?, ?, ?)",
                bindings: [
                    .text("rr06-goal-link-vd2-07c"), .text(projectID.rawValue), .text("VD2-07c"),
                    .text("rr06-thread-vd2-07c"), .text("rr06-goal-vd2-07c"),
                ]
            )
            try connection.execute(
                "INSERT INTO notification_events (id, fingerprint, state, ticket_id, goal_id) VALUES (?, ?, ?, ?, ?)",
                bindings: [
                    .text("rr06-notification-vd2-07c"), .text("Blocked alert"), .text("Delivered"),
                    .text("VD2-07c"), .text("rr06-goal-vd2-07c"),
                ]
            )
            let reviewItems: [(String, String?, String, String)] = [
                ("import-review", nil, "uncertain_import", "Import mapping needs owner confirmation"),
                ("duplicate-review", "VD2-08", "duplicate", "Possible duplicate delivery item"),
                ("dependency-review", "UX-D12", "unresolved_dependency", "Dependency target could not be resolved"),
                ("unmatched-review", nil, "unmatched_task", "Task does not match this project"),
                ("excluded-review", nil, "excluded_task", "Excluded task needs confirmation"),
                ("agent-review", "VD2-07c", "agent_review_request", "Agent requested owner validation"),
            ]
            for review in reviewItems {
                try connection.execute(
                    "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open')",
                    bindings: [
                        .text(review.0),
                        .text(projectID.rawValue),
                        review.1.map(SQLiteValue.text) ?? .null,
                        .text(review.2),
                        .text(review.3),
                    ]
                )
            }
            try connection.execute(
                "INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES (?, ?, ?, ?, ?)",
                bindings: [
                    .text("rr07-completion-ux-d10"),
                    .text(projectID.rawValue),
                    .text("UX-D10"),
                    .text("Agent completed export confirmation and requested validation."),
                    .text("2026-08-23T22:18:00Z"),
                ]
            )
        }
    }
}

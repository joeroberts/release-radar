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
        .init(id: "DESIGN-V2", outcome: "Cohesive visual language", lane: .backlog),
        .init(id: "VD2-09", outcome: "Release-readiness package", lane: .backlog),
        .init(id: "UX-D12", outcome: "Search semantics", lane: .backlog),
        .init(id: "P2A-1", outcome: "Phase two agent handoff", lane: .backlog),
        .init(id: "QA-11", outcome: "Regression confidence", lane: .backlog),
        .init(id: "SEC-10", outcome: "Local privacy review", lane: .backlog),
        .init(id: "DOC-09", outcome: "Owner operating notes", lane: .backlog),
        .init(id: "PERF-08", outcome: "Board rendering budget", lane: .backlog),
        .init(id: "REL-07", outcome: "Signed release candidate", lane: .backlog),
        .init(id: "VD2-08", outcome: "Visual QA and accessibility acceptance", lane: .inProgress),
        .init(id: "UX-D10", outcome: "Export confirmation", lane: .needsReview),
        .init(id: "VD2-07d", outcome: "Precise local search", lane: .needsReview),
        .init(id: "VD2-07c", outcome: "Activity and AI areas", lane: .blocked),
        .init(id: "VD2-07", outcome: "Settings architecture", lane: .accepted),
        .init(id: "VD2-06", outcome: "Contacts workflow", lane: .accepted),
        .init(id: "VD2-05", outcome: "Pipeline movement", lane: .accepted),
        .init(id: "VD2-04", outcome: "Project onboarding", lane: .accepted),
        .init(id: "VD2-03", outcome: "Agent action bridge", lane: .accepted),
        .init(id: "RR-04", outcome: "Folder-backed project setup", lane: .accepted),
        .init(id: "RR-03", outcome: "Typed delivery actions", lane: .accepted),
        .init(id: "RR-02", outcome: "Transactional local store", lane: .accepted),
        .init(id: "RR-01", outcome: "Signed application foundation", lane: .accepted),
        .init(id: "UX-D09", outcome: "Navigation hierarchy", lane: .accepted),
        .init(id: "UX-D08", outcome: "Readable status language", lane: .accepted),
        .init(id: "UX-D07", outcome: "Owner attention states", lane: .accepted),
        .init(id: "CORE-06", outcome: "Audit attribution", lane: .accepted),
        .init(id: "CORE-05", outcome: "Evidence persistence", lane: .accepted),
        .init(id: "CORE-04", outcome: "Blocker records", lane: .accepted),
        .init(id: "CORE-03", outcome: "Ticket dependency graph", lane: .accepted),
        .init(id: "CORE-02", outcome: "Five-lane vocabulary", lane: .accepted),
        .init(id: "CORE-01", outcome: "Project and phase records", lane: .accepted),
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

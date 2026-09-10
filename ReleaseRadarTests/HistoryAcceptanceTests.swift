import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class HistoryAcceptanceTests: XCTestCase {
    func testAuditHistoryRetainsEventTimeFactsAfterLaterProjectPhaseAndTicketChanges() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seed()

        try await fixture.store.transact(
            actor: .init(id: "history-agent", threadID: "history-thread", threadAttribution: .asserted),
            reason: "Move the ticket into review",
            auditEventID: .init(rawValue: "history-transition"),
            auditScope: .init(projectID: fixture.projectID, entityType: .ticket, entityID: fixture.ticketID.rawValue)
        ) { connection in
            try connection.execute(
                "UPDATE tickets SET phase_id = 'phase-review', lane = 'needs_review', outcome = 'Reviewed event-time outcome' WHERE project_id = 'history-project' AND id = 'H-1'"
            )
        }
        try await fixture.store.transact(
            actor: .init(id: "later-agent"),
            reason: "Change current names and delivery state",
            auditEventID: .init(rawValue: "history-later-change"),
            auditScope: .init(projectID: fixture.projectID, entityType: .ticket, entityID: fixture.ticketID.rawValue)
        ) { connection in
            try connection.execute("UPDATE projects SET name = 'Renamed later' WHERE id = 'history-project'")
            try connection.execute("UPDATE phases SET name = 'Renamed review phase' WHERE project_id = 'history-project' AND id = 'phase-review'")
            try connection.execute("UPDATE tickets SET lane = 'accepted', outcome = 'Changed later' WHERE project_id = 'history-project' AND id = 'H-1'")
        }

        let history = try await ProjectActivityProjection.load(from: fixture.store, projectID: fixture.projectID)
        let event = try XCTUnwrap(history.items.first { $0.identity.sourceID == "history-transition" })
        let facts = try XCTUnwrap(event.eventFacts)

        XCTAssertEqual(event.identity.projectID, fixture.projectID)
        XCTAssertEqual(event.identity.registrationID, "history-registration")
        XCTAssertEqual(event.identity.source, .audit)
        XCTAssertEqual(event.provenance, .localAudit)
        XCTAssertNotNil(event.occurredAt)
        XCTAssertNotNil(event.recordedAt)
        XCTAssertEqual(facts.projectName, "History project")
        XCTAssertEqual(facts.entityType, .ticket)
        XCTAssertEqual(facts.entityID, fixture.ticketID.rawValue)
        XCTAssertEqual(facts.ticketID, fixture.ticketID)
        XCTAssertEqual(facts.previousLane, .backlog)
        XCTAssertEqual(facts.currentLane, .needsReview)
        XCTAssertEqual(facts.previousPhaseID?.rawValue, "phase-build")
        XCTAssertEqual(facts.currentPhaseID?.rawValue, "phase-review")
        XCTAssertEqual(facts.phaseName, "Review phase")
        XCTAssertEqual(facts.ticketOutcome, "Reviewed event-time outcome")
    }

    func testFailedTransactionRollsBackStateAndHistoryEventTogether() async throws {
        enum ExpectedFailure: Error { case stop }

        let fixture = try Fixture(testCase: self)
        try await fixture.seed()

        do {
            _ = try await fixture.store.transact(
                actor: .init(id: "history-agent"),
                reason: "This event must roll back",
                auditEventID: .init(rawValue: "history-rolled-back"),
                auditScope: .init(projectID: fixture.projectID, entityType: .ticket, entityID: fixture.ticketID.rawValue)
            ) { connection in
                try connection.execute(
                    "UPDATE tickets SET lane = 'accepted' WHERE project_id = 'history-project' AND id = 'H-1'"
                )
                throw ExpectedFailure.stop
            }
            XCTFail("Expected the transaction callback to fail")
        } catch ExpectedFailure.stop {}

        let state = try await fixture.store.read { connection in
            (
                lane: try connection.scalarText(
                    "SELECT lane FROM tickets WHERE project_id = 'history-project' AND id = 'H-1'"
                ),
                auditCount: try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE id = 'history-rolled-back'"
                )
            )
        }
        XCTAssertEqual(state.lane, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.auditCount, 0)
    }

    func testVersionTwentyThreeAuditRowsRemainExplicitlyUnknownAfterMigration() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seed()
        await fixture.store.close()

        let legacy = try SQLiteConnection(url: fixture.databaseURL)
        for column in Self.versionTwentyFourAuditColumns.reversed() {
            try legacy.execute("ALTER TABLE audit_events DROP COLUMN \(column)")
        }
        try legacy.execute("PRAGMA user_version = 23")
        legacy.close()

        let migratedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let history = try await ProjectActivityProjection.load(from: migratedStore, projectID: fixture.projectID)
        let legacyEvent = try XCTUnwrap(history.items.first { $0.identity.sourceID == "history-seed" })

        XCTAssertNil(legacyEvent.eventFacts)
        XCTAssertNil(legacyEvent.occurredAt)
        XCTAssertNotNil(legacyEvent.recordedAt)
        XCTAssertNil(legacyEvent.deliveryLane)
        XCTAssertEqual(legacyEvent.provenance, .localAudit)
    }

    func testObservationIdentityAndReadsRemainProjectScoped() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seed()
        let otherProjectID = ProjectID(rawValue: "other-history-project")

        try await fixture.store.transact(actor: .init(id: "history-fixture"), reason: "Seed scoped observations") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('other-history-project', 'Other project', 1)")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('other-history-project', 'other-registration', 1, 'complete')")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('history-thread', 'history-project', 'active', '2026-09-10T12:00:00Z'), ('other-thread', 'other-history-project', 'active', '2026-09-10T12:00:00Z')")
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('history-goal', 'history-project', 'history-thread', 'active', 'History goal', '2026-09-10T12:01:00Z'), ('other-history-goal', 'other-history-project', 'other-thread', 'active', 'Other goal', '2026-09-10T12:02:00Z')")
        }

        let projectHistory = try await ProjectActivityProjection.load(from: fixture.store, projectID: fixture.projectID)
        let otherHistory = try await ProjectActivityProjection.load(from: fixture.store, projectID: otherProjectID)
        let projectObservation = try XCTUnwrap(projectHistory.items.first { $0.source == .runtime })
        let otherObservation = try XCTUnwrap(otherHistory.items.first { $0.source == .runtime })

        XCTAssertEqual(projectObservation.identity, .init(
            projectID: fixture.projectID,
            registrationID: "history-registration",
            source: .runtime,
            sourceID: "history-thread|history-goal"
        ))
        XCTAssertEqual(otherObservation.identity, .init(
            projectID: otherProjectID,
            registrationID: "other-registration",
            source: .runtime,
            sourceID: "other-thread|other-history-goal"
        ))
        XCTAssertEqual(projectObservation.provenance, .persistedObservation)
        XCTAssertNotNil(projectObservation.observedAt)
        XCTAssertFalse(projectHistory.items.contains { $0.identity.projectID == otherProjectID })
        XCTAssertFalse(otherHistory.items.contains { $0.identity.projectID == fixture.projectID })
    }

    func testHistoryFiltersAndSurfaceStatesDistinguishEmptyZeroFailedAndIncomplete() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seed()
        try await fixture.store.transact(actor: .init(id: "history-fixture"), reason: "Seed one observation") { connection in
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('history-thread', 'history-project', 'active', '2026-09-10T12:00:00Z')")
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('history-goal', 'history-project', 'history-thread', 'active', 'Observed execution work', '2026-09-10T12:01:00Z')")
        }

        let stateBeforeRead = try await deliveryState(in: fixture.store)
        let history = try await ProjectActivityProjection.load(from: fixture.store, projectID: fixture.projectID)
        let observations = history.filtered(by: .observations)
        _ = try await ProjectActivityProjection.load(from: fixture.store, projectID: fixture.projectID)
        let stateAfterRead = try await deliveryState(in: fixture.store)

        XCTAssertEqual(stateAfterRead, stateBeforeRead)
        XCTAssertEqual(observations.items.map(\.identity.sourceID), ["history-thread|history-goal"])
        XCTAssertEqual(HistorySurfaceState.loaded(history).content(for: .notifications), .noMatches)
        XCTAssertEqual(
            HistorySurfaceState.loaded(.init(projectID: fixture.projectID, items: [])).content(for: .all),
            .empty
        )
        XCTAssertEqual(HistorySurfaceState.failed("History could not be read").content(for: .all), .failed("History could not be read"))
        XCTAssertEqual(HistorySurfaceState.incomplete("Notification source unavailable").content(for: .all), .incomplete("Notification source unavailable"))
    }

    private func deliveryState(in store: DeliveryStore) async throws -> [String] {
        try await store.read { connection in
            [
                try connection.scalarText("SELECT phase_id || '|' || lane || '|' || outcome FROM tickets WHERE project_id='history-project' AND id='H-1'") ?? "missing-ticket",
                try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id='history-project'") ?? "missing-active-phase",
                String(try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1),
                String(try connection.scalarInt("SELECT COUNT(*) FROM notification_events") ?? -1),
            ]
        }
    }
}

private extension HistoryAcceptanceTests {
    static let versionTwentyFourAuditColumns = [
        "event_facts_recorded", "event_provenance", "event_occurred_at", "event_recorded_at",
        "event_project_name", "event_registration_id", "event_request_generation", "event_ticket_id",
        "event_phase_id", "event_phase_name", "event_ticket_outcome", "event_previous_lane",
        "event_current_lane", "event_previous_phase_id", "event_current_phase_id",
    ]

    struct Fixture {
        let store: DeliveryStore
        let databaseURL: URL
        let projectID = ProjectID(rawValue: "history-project")
        let ticketID = TicketID(rawValue: "H-1")

        init(testCase: XCTestCase) throws {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReleaseRadar-Phase6A-History-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            testCase.addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
            databaseURL = directory.appendingPathComponent("store.sqlite")
            store = DeliveryStore(databaseURL: databaseURL)
        }

        func seed() async throws {
            try await store.transact(
                actor: .init(id: "history-fixture"),
                reason: "Seed History fixture",
                auditEventID: .init(rawValue: "history-seed"),
                auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
            ) { connection in
                try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('history-project', 'History project', 1)")
                try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('history-project', 'history-registration', 3, 'complete')")
                try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-build', 'history-project', 'Build phase'), ('phase-review', 'history-project', 'Review phase')")
                try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('history-project', 'phase-build')")
                try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('H-1', 'history-project', 'phase-build', 'Initial outcome', 'backlog')")
            }
        }
    }
}

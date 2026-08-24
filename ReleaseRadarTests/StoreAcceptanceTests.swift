import Foundation
import XCTest
@testable import ReleaseRadarCore

final class StoreAcceptanceTests: XCTestCase {
    func testSuccessfulTicketTransitionCommitsAttributedAuditEvent() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let projectID = ProjectID(rawValue: "project-1")
        let phaseID = PhaseID(rawValue: "phase-1")
        let ticketID = TicketID(rawValue: "RR-02")
        let actor = DeliveryActor(id: "agent-implementer", threadID: "thread-42")

        try await store.transact(actor: actor, reason: "Complete transactional storage") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name) VALUES (?, ?)",
                bindings: [.text(projectID.rawValue), .text("Release Radar")]
            )
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
                bindings: [.text(phaseID.rawValue), .text(projectID.rawValue), .text("MVP")]
            )
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
                bindings: [
                    .text(ticketID.rawValue),
                    .text(projectID.rawValue),
                    .text(phaseID.rawValue),
                    .text("Persist delivery state"),
                    .text(TicketLane.backlog.rawValue),
                ]
            )
            try connection.execute(
                "UPDATE tickets SET lane = ? WHERE id = ?",
                bindings: [.text(TicketLane.accepted.rawValue), .text(ticketID.rawValue)]
            )
        }

        let lane = try await store.read { connection in
            try connection.scalarText(
                "SELECT lane FROM tickets WHERE id = ?",
                bindings: [.text(ticketID.rawValue)]
            )
        }
        let audit = try await store.read { connection in
            try connection.row(
                "SELECT actor_id, thread_id, reason FROM audit_events"
            )
        }

        XCTAssertEqual(lane, TicketLane.accepted.rawValue)
        XCTAssertEqual(audit?["actor_id"], .text(actor.id))
        XCTAssertEqual(audit?["thread_id"], .text(actor.threadID!))
        XCTAssertEqual(audit?["reason"], .text("Complete transactional storage"))
    }

    func testInvalidReferenceRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-invalid-reference"), reason: "Add blocker") { connection in
                try connection.execute(
                    "UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'"
                )
                try connection.execute(
                    "INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('blocker-1', 'project-1', 'missing-ticket', 'Missing ticket')"
                )
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM blockers"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 1)
    }

    func testCrossProjectThreadLinkRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed second project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-2', 'Other')")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-2', 'project-2', 'running', '2026-08-23T12:00:00Z')")
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-cross-project"), reason: "Link thread") { connection in
                try connection.execute("UPDATE tickets SET lane = 'in_progress' WHERE id = 'RR-02'")
                try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('link-1', 'project-1', 'RR-02', 'thread-2')")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM thread_links"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 2)
    }

    func testDependencyCycleRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed dependency") { connection in
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Bridge', 'backlog')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dependency-1', 'project-1', 'RR-03', 'RR-02')")
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-cycle"), reason: "Add cyclic dependency") { connection in
                try connection.execute("UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'")
                try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dependency-2', 'project-1', 'RR-02', 'RR-03')")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 2)
    }

    func testPhaseDependencyCycleRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed phase dependency") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-2', 'project-1', 'Launch')")
            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-1', 'project-1', 'phase-2', 'phase-1')")
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-cycle"), reason: "Add cyclic phase dependency") { connection in
                try connection.execute("UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'")
                try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-2', 'project-1', 'phase-1', 'phase-2')")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 2)
    }

    func testReadProjectionCannotBypassAuditedTransactions() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.read { connection in
                try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
    }

    func testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit() async throws {
        let databaseURL = try makeDatabaseURL()
        do {
            let legacy = try SQLiteConnection(url: databaseURL)
            try legacy.execute("CREATE TABLE legacy_marker (value TEXT NOT NULL)")
            try legacy.execute("INSERT INTO legacy_marker (value) VALUES ('before-migration')")
            try legacy.execute("PRAGMA user_version = 0")
        }

        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        await XCTAssertThrowsErrorAsync {
            try await store!.transact(actor: .init(id: "agent-invalid"), reason: "Reject missing reference") { connection in
                try connection.execute("INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('rejected', 'project-1', 'missing', 'Rejected')")
            }
        }
        store = nil

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
        let persisted = try await relaunchedStore.read { connection in
            (
                try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("PRAGMA user_version"),
                try connection.scalarInt("SELECT COUNT(*) FROM blockers")
            )
        }
        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))

        XCTAssertEqual(persisted.0, "Store")
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2, 1)
        XCTAssertEqual(persisted.3, 0)
        XCTAssertEqual(try snapshot.scalarText("SELECT value FROM legacy_marker"), "before-migration")
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
    }

    func testCorruptDatabaseOpensUnavailableAndLeavesOriginalBytesIntact() async throws {
        let databaseURL = try makeDatabaseURL()
        let originalBytes = Data("not-a-sqlite-database".utf8)
        try originalBytes.write(to: databaseURL)

        let store = DeliveryStore(databaseURL: databaseURL)
        let availability = await store.availability

        guard case let .unavailable(recovery) = availability else {
            return XCTFail("Expected corrupt database to be unavailable")
        }
        XCTAssertEqual(recovery.kind, .corruption)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        XCTAssertNil(recovery.preMigrationSnapshotURL)
        XCTAssertEqual(try Data(contentsOf: databaseURL), originalBytes)
        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent"), reason: "Must not reset") { _ in }
        }
        XCTAssertEqual(try Data(contentsOf: databaseURL), originalBytes)
    }

    func testMigrationFailureOpensUnavailableWithOriginalAndSnapshotRecoverable() async throws {
        let databaseURL = try makeDatabaseURL()
        do {
            let malformedLegacy = try SQLiteConnection(url: databaseURL)
            try malformedLegacy.execute("CREATE TABLE projects (legacy_value TEXT NOT NULL)")
            try malformedLegacy.execute("INSERT INTO projects (legacy_value) VALUES ('authoritative-original')")
            try malformedLegacy.execute("PRAGMA user_version = 0")
        }

        let store = DeliveryStore(databaseURL: databaseURL)
        let availability = await store.availability

        guard case let .unavailable(recovery) = availability else {
            return XCTFail("Expected failed migration to leave the store unavailable")
        }
        XCTAssertEqual(recovery.kind, .migration)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        XCTAssertEqual(recovery.preMigrationSnapshotURL, DeliveryStore.preMigrationSnapshotURL(for: databaseURL))

        let original = try SQLiteConnection(url: databaseURL)
        let snapshot = try SQLiteConnection(url: try XCTUnwrap(recovery.preMigrationSnapshotURL))
        XCTAssertEqual(try original.scalarText("SELECT legacy_value FROM projects"), "authoritative-original")
        XCTAssertEqual(try snapshot.scalarText("SELECT legacy_value FROM projects"), "authoritative-original")
        XCTAssertEqual(try original.scalarInt("PRAGMA user_version"), 0)
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
        XCTAssertNil(try original.scalarText("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'tickets'"))
    }

    private func seedProject(_ store: DeliveryStore) async throws {
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-02', 'project-1', 'phase-1', 'Store', 'backlog')")
        }
    }

    private func makeDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadarStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("release-radar.sqlite")
    }

    private func XCTAssertThrowsErrorAsync(
        _ expression: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected expression to throw", file: file, line: line)
        } catch {}
    }
}

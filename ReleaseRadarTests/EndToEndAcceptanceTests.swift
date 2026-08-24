import Foundation
import XCTest
@testable import ReleaseRadarCore

final class EndToEndAcceptanceTests: XCTestCase {
    func testRelaunchRepairsVersionThreeDatabaseMissingAuditAttribution() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeVersionThreeAuditDrift(at: databaseURL)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        let availability = await relaunchedStore.availability
        XCTAssertEqual(availability, .available)
        try await relaunchedStore.transact(
            actor: .init(id: "rr10-recovery", threadID: "thread-recovery"),
            reason: "Verify repaired version three schema",
            auditScope: .init(
                projectID: .init(rawValue: "project-1"),
                entityType: .ticket,
                entityID: "RR-10"
            )
        ) { _ in }
        let repairedConnection = try SQLiteConnection(url: databaseURL)
        let repaired = (
            try repairedConnection.scalarInt("PRAGMA user_version"),
            try repairedConnection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'thread_attribution'"),
            try repairedConnection.scalarText("SELECT thread_attribution FROM audit_events WHERE reason = 'Verify repaired version three schema'")
        )
        XCTAssertEqual(repaired.0, 7)
        XCTAssertEqual(repaired.1, 1)
        XCTAssertEqual(repaired.2, "asserted")

        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 3)
        XCTAssertEqual(
            try snapshot.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'thread_attribution'"),
            0
        )
    }

    func testRelaunchRepairsObservedVersionSevenOwnerSchemaDrift() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeObservedVersionSevenDrift(at: databaseURL)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        let availability = await relaunchedStore.availability
        XCTAssertEqual(availability, .available)
        let repairedConnection = try SQLiteConnection(url: databaseURL)
        let repaired = (
            try repairedConnection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name IN ('project_id', 'entity_type', 'entity_id')"),
            try repairedConnection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'project-1'")
        )
        XCTAssertEqual(repaired.0, 3)
        XCTAssertEqual(repaired.1, "phase-1")
        try await relaunchedStore.transact(
            actor: .init(id: "rr10-recovery"),
            reason: "Verify repaired version seven schema",
            auditScope: .init(
                projectID: .init(rawValue: "project-1"),
                entityType: .project,
                entityID: "project-1"
            )
        ) { _ in }

        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 7)
        XCTAssertEqual(
            try snapshot.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'project_active_phases'"),
            0
        )
        XCTAssertEqual(
            try snapshot.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name IN ('project_id', 'entity_type', 'entity_id')"),
            0
        )
    }

    private func seedProject(_ store: DeliveryStore) async throws {
        try await store.transact(actor: .init(id: "rr10-seed"), reason: "Seed recovery fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-1')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-10', 'project-1', 'phase-1', 'Final integration', 'in_progress')")
        }
    }

    private func makeVersionThreeAuditDrift(at databaseURL: URL) throws {
        let connection = try SQLiteConnection(url: databaseURL)
        try connection.executeScript("""
        DROP INDEX notification_events_project_created_index;
        DROP INDEX notification_events_state_index;
        DROP TABLE notification_occurrences;
        ALTER TABLE notification_events DROP COLUMN failure_code;
        ALTER TABLE notification_events DROP COLUMN completed_at;
        ALTER TABLE notification_events DROP COLUMN attempt_started_at;
        ALTER TABLE notification_events DROP COLUMN attempt_count;
        ALTER TABLE notification_events DROP COLUMN created_at;
        ALTER TABLE notification_events DROP COLUMN message;
        ALTER TABLE notification_events DROP COLUMN title;
        ALTER TABLE notification_events DROP COLUMN occurrence;
        ALTER TABLE notification_events DROP COLUMN subject_id;
        ALTER TABLE notification_events DROP COLUMN event_kind;
        ALTER TABLE notification_events DROP COLUMN project_id;
        DROP INDEX project_active_phases_phase_index;
        DROP TABLE project_active_phases;
        DROP INDEX audit_events_project_entity_index;
        ALTER TABLE audit_events DROP COLUMN entity_id;
        ALTER TABLE audit_events DROP COLUMN entity_type;
        ALTER TABLE audit_events DROP COLUMN project_id;
        ALTER TABLE audit_events DROP COLUMN thread_attribution;
        PRAGMA user_version = 3;
        """)
    }

    private func makeObservedVersionSevenDrift(at databaseURL: URL) throws {
        let connection = try SQLiteConnection(url: databaseURL)
        try connection.executeScript("""
        ALTER TABLE projects ADD COLUMN active_phase_id TEXT;
        UPDATE projects SET active_phase_id = 'phase-1' WHERE id = 'project-1';
        DROP INDEX project_active_phases_phase_index;
        DROP TABLE project_active_phases;
        DROP INDEX audit_events_project_entity_index;
        ALTER TABLE audit_events DROP COLUMN entity_id;
        ALTER TABLE audit_events DROP COLUMN entity_type;
        ALTER TABLE audit_events DROP COLUMN project_id;
        PRAGMA user_version = 7;
        """)
    }

    private func makeDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadarEndToEndTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("release-radar.sqlite")
    }
}

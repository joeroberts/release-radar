import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class DocumentationMaintenanceTests: XCTestCase {
    @MainActor
    func testReadOnlyRecoveryCannotPrepareOrConfirmMutation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("M3C-Maintenance-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let recovery = RepositoryRecoveryModel(store: store, projectID: .init(rawValue: "p"), allowsRelocation: false)
        await recovery.prepare(folder: directory)
        XCTAssertNil(recovery.prepared)
        XCTAssertEqual(recovery.message, "This maintenance session is read-only.")
        await recovery.confirm()
        let audits = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(audits, 0)
    }

    @MainActor
    func testMaintenanceReadsLegacySchemasWithoutMigrationOrMutation() async throws {
        for version in [10, 11, 12] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("M3C-legacy-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let database = directory.appendingPathComponent("store.sqlite")
            let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/SchemaV\(version)/release-radar-v\(version).sqlite")
            try FileManager.default.copyItem(at: fixture, to: database)
            let fixtureConnection = try SQLiteConnection(url: database)
            try fixtureConnection.execute("INSERT INTO projects (id, name) VALUES ('m3c-read-only', 'Read-only legacy project')")
            try fixtureConnection.execute("INSERT INTO evidence (id, project_id, path) VALUES ('m3c-legacy-evidence', 'm3c-read-only', '/synthetic/legacy.md')")
            let before = try Data(contentsOf: database)
            let session = try DocumentationMaintenanceSession(databaseURL: database, mode: .readOnly)
            await session.load()
            XCTAssertNil(session.message)
            XCTAssertFalse(session.projects.isEmpty)
            for project in session.projects {
                session.selectedProjectID = project.id
                await session.selectProject()
                XCTAssertNil(session.recovery?.message)
                XCTAssertNil(session.recovery?.binding)
                XCTAssertEqual(session.recovery?.allowsRelocation, false)
                XCTAssertTrue(session.recovery!.evidence.allSatisfy { if case .filePath = $0.locator { return true }; return false })
            }
            XCTAssertEqual(try Data(contentsOf: database), before)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["store.sqlite"])
        }
    }

    func testMaintenanceLaunchParsingFailsClosedAndXCTestTakesPrecedence() {
        let root = URL(fileURLWithPath: "/existing/store.sqlite")
        XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app"], environment: [:]), .application)
        XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app", "--documentation-maintenance=read-only", "--documentation-maintenance-store=/existing/store.sqlite"], environment: [:]), .maintenance(mode: .readOnly, databaseURL: root))
        for args in [["--documentation-maintenance=no"], ["--documentation-maintenance=commands", "--documentation-maintenance=read-only"], ["--documentation-maintenance-store=/x"], ["--documentation-maintenance=commands", "--documentation-maintenance-store=relative"], ["--documentation-maintenance=commands", "--documentation-maintenance-other=x"]] {
            XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app"] + args, environment: [:]), .invalid)
        }
        XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app", "--documentation-maintenance=no"], environment: ["XCTestConfigurationFilePath": "test"]), .application)
    }
}

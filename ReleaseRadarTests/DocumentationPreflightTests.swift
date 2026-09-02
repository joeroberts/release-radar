import Foundation
import XCTest
@testable import ReleaseRadarCore

final class DocumentationPreflightTests: XCTestCase {
    func testVersionFourteenPreflightIsReadOnlyAndRejectsVersionShapeMismatch() async throws {
        let directory = try temporaryDirectory()
        let db = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: db)
        guard case .available = await store.availability else { return XCTFail("Expected current synthetic store") }
        let before = try files(directory)
        let preflight = try DeliveryStore(existingReadOnlyDatabaseURL: db)
        let version = await preflight.schemaVersionForDocumentation
        XCTAssertEqual(version, 14)
        XCTAssertEqual(try files(directory), before)
        let raw = try SQLiteConnection(url: db)
        // A historical version must have its historical event-to-ticket shape.
        for incompatibleVersion in [11, 12, 13, 15] {
            try raw.execute("PRAGMA user_version = \(incompatibleVersion)")
            let unchanged = try files(directory)
            XCTAssertThrowsError(try DeliveryStore(existingReadOnlyDatabaseURL: db))
            XCTAssertEqual(try files(directory), unchanged)
        }
    }

    func testFrozenSupportedSchemasOpenWithoutMigrationOrEffects() async throws {
        for version in [10, 11, 12] {
            let directory = try temporaryDirectory()
            let db = directory.appendingPathComponent("store.sqlite")
            let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/SchemaV\(version)/release-radar-v\(version).sqlite")
            try FileManager.default.copyItem(at: fixture, to: db)
            let before = try Data(contentsOf: db)
            let store = try DeliveryStore(existingReadOnlyDatabaseURL: db)
            let found = await store.schemaVersionForDocumentation
            XCTAssertEqual(found, version)
            XCTAssertEqual(try Data(contentsOf: db), before)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["store.sqlite"])
            do {
                try await store.transact(actor: .init(id: "must-not-write"), reason: "Must reject") { _ in }
                XCTFail("Preflight accepted a mutation")
            } catch { }
        }
    }

    func testNoCreateSymlinkAndCounterfeitSchemaFailClosed() async throws {
        let directory = try temporaryDirectory()
        let missing = directory.appendingPathComponent("missing.sqlite")
        XCTAssertThrowsError(try DeliveryStore(existingReadOnlyDatabaseURL: missing))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        let db = directory.appendingPathComponent("store.sqlite")
        let normal = DeliveryStore(databaseURL: db)
        _ = try await normal.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        let link = directory.appendingPathComponent("link.sqlite")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: db)
        XCTAssertThrowsError(try DeliveryStore(existingReadOnlyDatabaseURL: link))
        let parentLink = directory.appendingPathComponent("parent")
        try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: directory)
        XCTAssertThrowsError(try DeliveryStore(existingReadOnlyDatabaseURL: parentLink.appendingPathComponent("store.sqlite")))
        let fake = directory.appendingPathComponent("fake.sqlite")
        let raw = try SQLiteConnection(url: fake)
        for version in [13, 14] {
            try raw.execute("PRAGMA user_version = \(version)")
            XCTAssertThrowsError(try DeliveryStore(existingReadOnlyDatabaseURL: fake))
        }
    }

    func testUncheckpointedWALFailsClosedWithoutSidecarWrites() async throws {
        let directory = try temporaryDirectory()
        let db = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: db)
        _ = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        let writer = try SQLiteConnection(url: db)
        XCTAssertEqual(try writer.scalarText("PRAGMA journal_mode = WAL"), "wal")
        try writer.execute("INSERT INTO projects (id, name) VALUES ('wal', 'Committed WAL')")
        let before = try files(directory)
        XCTAssertThrowsError(try DeliveryStore(existingReadOnlyDatabaseURL: db))
        XCTAssertEqual(try files(directory), before)
    }

    func testChangedDatabaseInvalidatesReadOnlySession() async throws {
        let directory = try temporaryDirectory()
        let db = directory.appendingPathComponent("store.sqlite")
        let writer = DeliveryStore(databaseURL: db)
        let readOnly = try DeliveryStore(existingReadOnlyDatabaseURL: db)
        try await writer.transact(actor: .init(id: "fixture"), reason: "Change after read-only open") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('changed', 'Changed')")
        }
        do {
            _ = try await readOnly.documentationRead { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
            XCTFail("Changing store must invalidate preflight")
        } catch { }
    }
    func testFrozenV10BaselinePreservesAllExistingSemanticDomainsAfterMigration() async throws {
        let directory = try temporaryDirectory()
        let root = directory.appendingPathComponent("repository")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let db = directory.appendingPathComponent("store.sqlite")
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/SchemaV10/release-radar-v10.sqlite")
        try FileManager.default.copyItem(at: fixture, to: db)
        // Only the disposable fixture's authorization metadata is adapted.
        let fixtureConnection = try SQLiteConnection(url: db)
        let project = try fixtureConnection.scalarText("SELECT id FROM projects ORDER BY id LIMIT 1") ?? "preflight-project"
        if try fixtureConnection.scalarText("SELECT id FROM projects WHERE id = ?", bindings: [.text(project)]) == nil {
            try fixtureConnection.execute("INSERT INTO projects (id, name) VALUES (?, 'Preflight fixture')", bindings: [.text(project)])
        }
        let rootID = "preflight-root"
        try fixtureConnection.execute("INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)", bindings: [.text(rootID), .text(project), .text(root.path)])
        try fixtureConnection.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES (?, ?, ?)", bindings: [.text(project), .text(root.path), .blob(Data([1]))])
        let bookmarks = ProjectBookmarkStore(resolver: { _ in .init(url: root, isStale: false) }, startAccessing: { _ in true }, stopAccessing: { _ in })
        let query = AgentQueryEnvelope(version: 1, projectRoot: root.path, query: .inventoryEvidence(projectID: project, rootID: rootID))
        let baselineStore = try DeliveryStore(existingReadOnlyDatabaseURL: db)
        let baselineResult = await AgentQueryDispatcher(store: baselineStore, bookmarkStore: bookmarks).dispatch(query)
        let before = try XCTUnwrap(baselineResult.inventory, "\(String(describing: baselineResult.error))")
        XCTAssertEqual(before.schemaVersion, 10)
        let migrated = DeliveryStore(databaseURL: db)
        let afterResult = await AgentQueryDispatcher(store: migrated, bookmarkStore: bookmarks).dispatch(query)
        let after = try XCTUnwrap(afterResult.inventory)
        XCTAssertEqual(after.schemaVersion, Int(StoreMigrations.currentVersion))
        XCTAssertEqual(before.evidence.map(\.evidence), after.evidence.map(\.evidence))
        XCTAssertEqual(before.roots, after.roots)
        XCTAssertEqual(before.audits, after.audits)
        XCTAssertEqual(before.receipts, after.receipts)
        for (key, value) in before.preservation { XCTAssertEqual(after.preservation[key], value, key) }
        XCTAssertNotNil(after.preservation["project.planningV11"])
        XCTAssertNotNil(after.preservation["project.tasksV12"])
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ReleaseRadar-M3B-Preflight-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func files(_ directory: URL) throws -> [String: Data] {
        try Dictionary(uniqueKeysWithValues: FileManager.default.contentsOfDirectory(atPath: directory.path).map { ($0, try Data(contentsOf: directory.appendingPathComponent($0))) })
    }
}

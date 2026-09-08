import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class DocumentationMaintenanceTests: XCTestCase {
    @MainActor
    func testLiveObservationWithdrawsPreviewAfterExternalSourceChangeWithoutManualReload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("M3C-live-preview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("notes.md")
        try Data("before".utf8).write(to: source)
        let projectID = ProjectID(rawValue: "p")
        let evidenceID = EvidenceID(rawValue: "e")
        let readback = EvidenceReadback(
            evidence: .init(id: evidenceID, projectID: projectID, ticketID: nil, locator: .filePath(source.path), isAvailable: true),
            managedDocument: nil
        )
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Live preview fixture") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try c.execute("INSERT INTO project_registrations (project_id, registration_id) VALUES ('p', 'registration')")
            try c.execute("INSERT INTO evidence (id, project_id, path) VALUES ('e', 'p', ?)", bindings: [.text(source.path)])
        }
        let observer = DocumentationObservationCoordinator { requestedProjectID in
            let current = (try? Data(contentsOf: source)) == Data("before".utf8)
            return .init(
                identity: .init(projectID: requestedProjectID, registration: nil, rootID: nil, rootPath: directory.path, binding: nil),
                checkedAt: Date(),
                documentationState: .legacy(.unavailable),
                evidence: current ? [readback] : []
            )
        }
        let session = try DocumentationMaintenanceSession(
            databaseURL: store.databaseURL,
            mode: .readOnly,
            previewLoader: { _, _ in
                .init(identity: readback.evidence.locator, path: source.path, status: .available,
                      content: .text("before", isTruncated: false))
            },
            documentationObserver: observer,
            monitoringInterval: .milliseconds(10)
        )
        await session.load()
        let preview = await session.previewEvidence(evidenceID, projectID: projectID)
        XCTAssertEqual(preview.content, .text("before", isTruncated: false))

        session.startDocumentationMonitoring()
        defer { session.stopDocumentationMonitoring() }
        try Data("after".utf8).write(to: source)
        for _ in 0..<100 {
            if session.documentationObservationStatus?.evidence.isEmpty == true { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(session.documentationObservationStatus?.evidence, [])
        let withdrawn = await session.previewEvidence(evidenceID, projectID: projectID)
        XCTAssertEqual(withdrawn.status, .rejected)
        XCTAssertNil(withdrawn.content)
    }

    @MainActor
    func testReloadWithdrawsEqualEvidenceAndRejectsLatePreviewCompletion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("M3C-preview-freshness-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Maintenance preview fixture") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try c.execute("INSERT INTO project_registrations (project_id, registration_id) VALUES ('p', 'registration')")
            try c.execute("INSERT INTO evidence (id, project_id, path) VALUES ('e', 'p', 'notes.md')")
        }
        let loader = ControlledMaintenancePreviewLoader()
        let session = try DocumentationMaintenanceSession(
            databaseURL: store.databaseURL,
            mode: .readOnly,
            previewLoader: { _, _ in await loader.load() }
        )
        await session.load()
        let initialGeneration = session.evidenceObservationGeneration
        let task = Task { await session.previewEvidence(.init(rawValue: "e"), projectID: .init(rawValue: "p")) }
        await loader.waitUntilEntered()
        await session.load()
        XCTAssertGreaterThan(session.evidenceObservationGeneration, initialGeneration)
        await loader.finish(.init(identity: .filePath("notes.md"), path: "notes.md", status: .available, content: .text("late", isTruncated: false)))
        let result = await task.value
        XCTAssertEqual(result.status, .rejected)
        XCTAssertNil(result.content)
    }

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

private actor ControlledMaintenancePreviewLoader {
    private var entered = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var resultContinuation: CheckedContinuation<EvidencePreview, Never>?
    func load() async -> EvidencePreview {
        entered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        return await withCheckedContinuation { resultContinuation = $0 }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }
    func finish(_ result: EvidencePreview) { resultContinuation?.resume(returning: result); resultContinuation = nil }
}

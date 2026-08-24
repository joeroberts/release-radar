import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RekonImportAcceptanceTests: XCTestCase {
    func testPreviewMapsStableContractAndRoutesAmbiguityWithoutMarkdownInference() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let sourceBytes = try Data(contentsOf: fixture.artifactURL)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )

        XCTAssertTrue(importer.canImport(fixture.root))
        let preview = try importer.preview(fixture.root)

        XCTAssertEqual(preview.schemaVersion, 1)
        XCTAssertEqual(preview.activePhaseID, PhaseID(rawValue: "phase-main"))
        XCTAssertEqual(preview.phases.map(\.id), [PhaseID(rawValue: "phase-main"), PhaseID(rawValue: "phase-next")])
        XCTAssertEqual(preview.phaseDependencies, [
            .init(phaseID: .init(rawValue: "phase-next"), dependsOnPhaseID: .init(rawValue: "phase-main")),
        ])
        XCTAssertEqual(preview.tickets.map(\.id), [
            TicketID(rawValue: "TASK-A"),
            TicketID(rawValue: "TASK-B"),
            TicketID(rawValue: "TASK-C"),
        ])
        XCTAssertEqual(preview.tickets.map(\.lane), [.accepted, .inProgress, .blocked])
        XCTAssertEqual(preview.ticketDependencies, [
            .init(ticketID: .init(rawValue: "TASK-B"), dependsOnTicketID: .init(rawValue: "TASK-A")),
        ])

        let evidencePaths = Set(preview.evidence.map { URL(fileURLWithPath: $0.path).lastPathComponent })
        XCTAssertEqual(evidencePaths, ["TASK-A.md", "roadmap.md", "owner-handoff.md", "delivery-ledger.md"])
        XCTAssertFalse(evidencePaths.contains("README.md"))
        XCTAssertEqual(Set(preview.reviewItems.map(\.kind)), [.duplicate, .missingOutcome, .unresolvedDependency])
        XCTAssertEqual(Set(preview.reviewItems.map(\.sourceID)), ["DUP", "NO-TITLE", "TASK-C→TASK-MISSING"])
        XCTAssertEqual(try Data(contentsOf: fixture.artifactURL), sourceBytes)
    }

    func testApplyIsTransactionalIdempotentAndPersistsAcrossRelaunch() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        let preview = try importer.preview(fixture.root)
        let sourceBytes = try Data(contentsOf: fixture.artifactURL)

        try await importer.apply(preview, to: fixture.projectID)
        try await importer.apply(preview, to: fixture.projectID)

        let relaunchedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let state = try await relaunchedStore.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM evidence WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(state.0, 2)
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, 4)
        XCTAssertEqual(state.5, 3)
        XCTAssertEqual(state.6, 0)
        XCTAssertEqual(try Data(contentsOf: fixture.artifactURL), sourceBytes)
    }

    func testReimportMarksMissingEvidenceUnavailableWithoutDeletingDeliveryOrReopeningReview() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let reviewID = try await store.read { connection in
            try connection.scalarText(
                "SELECT id FROM review_items WHERE project_id = 'project-import' AND kind = 'duplicate'"
            )
        }
        try await store.transact(actor: .init(id: "owner"), reason: "Resolve duplicate") { connection in
            try connection.execute(
                "UPDATE review_items SET status = 'resolved' WHERE id = ?",
                bindings: [.text(try XCTUnwrap(reviewID))]
            )
        }
        try FileManager.default.removeItem(at: fixture.handoffURL)

        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let missingEvidencePath = fixture.handoffURL.path
        let resolvedReviewID = try XCTUnwrap(reviewID)
        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT is_available FROM evidence WHERE path = ?", bindings: [.text(missingEvidencePath)]),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarText("SELECT status FROM review_items WHERE id = ?", bindings: [.text(resolvedReviewID)])
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, "resolved")
    }

    func testApplyRejectsWrongTargetAndUnpersistedRootWithoutPartialWrites() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        let preview = try importer.preview(fixture.root)

        do {
            try await importer.apply(preview, to: .init(rawValue: "wrong-project"))
            XCTFail("Expected target mismatch")
        } catch let error as RekonImportError {
            XCTAssertEqual(error, .targetProjectMismatch)
        }
        do {
            try await importer.apply(preview, to: fixture.projectID)
            XCTFail("Expected an unpersisted project/root rejection")
        } catch let error as RekonImportError {
            XCTAssertEqual(error, .projectNotFound)
        }

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, 0)
    }

    func testCrossProjectRecordConflictBecomesReviewWhileOtherRecordsImport() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        try await store.transact(actor: .init(id: "test-seed"), reason: "Seed conflicting project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-other', 'Other')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('other-phase', 'project-other', 'Other phase')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('TASK-A', 'project-other', 'other-phase', 'Existing task', 'backlog')")
        }
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)

        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'TASK-A' AND project_id = 'project-other'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = 'project-import' AND kind = 'conflict'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(state.0, 2)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 2)
        XCTAssertEqual(state.3, 0)
    }

    func testPreviewFailsClosedForUnsupportedOversizedAndEscapingArtifacts() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        XCTAssertThrowsError(try importer.preview(fixture.root.appendingPathComponent("sibling"))) { error in
            XCTAssertEqual(error as? RekonImportError, .unauthorizedFolder)
        }

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture.artifactURL)) as? [String: Any])
        object["schemaVersion"] = 2
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            XCTAssertEqual(error as? RekonImportError, .unsupportedSchemaVersion(2))
        }

        object["schemaVersion"] = 1
        var tasks = try XCTUnwrap(object["tasks"] as? [[String: Any]])
        tasks[0]["evidence"] = ["label": "Escape", "href": "../../../../outside.md"]
        object["tasks"] = tasks
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .invalidPath = error as? RekonImportError else {
                return XCTFail("Expected invalid evidence path, got \(error)")
            }
        }

        let oversizedHandle = try FileHandle(forWritingTo: fixture.artifactURL)
        try oversizedHandle.truncate(atOffset: 1_048_577)
        try oversizedHandle.close()
        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            XCTAssertEqual(error as? RekonImportError, .inputTooLarge)
        }
    }

    func testPreviewStopsWhenRecognizedEvidenceDirectoryExceedsScanLimit() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        let taskBriefs = fixture.root.appendingPathComponent("docs/delivery/task-briefs", isDirectory: true)
        for index in 0...512 {
            FileManager.default.createFile(
                atPath: taskBriefs.appendingPathComponent("generated-\(index).md").path,
                contents: Data()
            )
        }

        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .limitExceeded = error as? RekonImportError else {
                return XCTFail("Expected bounded evidence scan, got \(error)")
            }
        }
        XCTAssertFalse(importer.canImport(fixture.root))
    }

    func testTwoNodePhaseAndTicketCyclesBecomeReviewsWhileConfidentEdgesApply() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fixture.artifactURL)) as? [String: Any]
        )
        var phases = try XCTUnwrap(object["phases"] as? [[String: Any]])
        phases[0]["dependsOnPhaseIds"] = ["phase-next"]
        object["phases"] = phases
        var tasks = try XCTUnwrap(object["tasks"] as? [[String: Any]])
        tasks[0]["dependsOnTaskIds"] = ["TASK-B"]
        object["tasks"] = tasks
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)

        let preview = try importer.preview(fixture.root)

        XCTAssertEqual(preview.phaseDependencies, [
            .init(phaseID: .init(rawValue: "phase-main"), dependsOnPhaseID: .init(rawValue: "phase-next")),
        ])
        XCTAssertEqual(preview.ticketDependencies, [
            .init(ticketID: .init(rawValue: "TASK-A"), dependsOnTicketID: .init(rawValue: "TASK-B")),
        ])
        let cycleReviews = preview.reviewItems.filter { $0.kind == .unresolvedDependency }
        XCTAssertTrue(cycleReviews.contains { $0.sourceID == "phase-next→phase-main" })
        XCTAssertTrue(cycleReviews.contains { $0.sourceID == "TASK-B→TASK-A" })

        try await importer.apply(preview, to: fixture.projectID)
        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = 'project-import' AND kind = 'unresolved_dependency'")
            )
        }
        XCTAssertEqual(state.0, 2)
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, 3)
    }

    func testPreviewRejectsArtifactSymlinkThatEscapesAuthorizedRoot() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        let externalDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RekonImportExternal-\(UUID().uuidString)", isDirectory: true)
        let externalArtifact = externalDirectory.appendingPathComponent("dashboard-status.json")
        try FileManager.default.createDirectory(at: externalDirectory, withIntermediateDirectories: true)
        try Data(contentsOf: fixture.artifactURL).write(to: externalArtifact)
        try FileManager.default.removeItem(at: fixture.artifactURL)
        try FileManager.default.createSymbolicLink(at: fixture.artifactURL, withDestinationURL: externalArtifact)
        addTeardownBlock { try? FileManager.default.removeItem(at: externalDirectory) }

        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .invalidPath = error as? RekonImportError else {
                return XCTFail("Expected escaped artifact rejection, got \(error)")
            }
        }
        XCTAssertFalse(importer.canImport(fixture.root))
    }
}

private final class RekonImportFixture {
    let root: URL
    let databaseURL: URL
    let artifactURL: URL
    let projectID = ProjectID(rawValue: "project-import")

    var taskBriefURL: URL {
        root.appendingPathComponent("docs/delivery/task-briefs/TASK-A.md")
    }

    var handoffURL: URL {
        root.appendingPathComponent("docs/delivery/handoffs/owner-handoff.md")
    }

    var authorizedProject: AuthorizedProject {
        .init(projectID: projectID, canonicalRoot: root, authorizedRoots: [root])
    }

    init(testCase: XCTestCase) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RekonImportTests-\(UUID().uuidString)", isDirectory: true)
        databaseURL = root.appendingPathComponent("release-radar.sqlite")
        artifactURL = root.appendingPathComponent("docs/delivery/dashboard-status.json")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("docs/delivery/task-briefs"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("docs/delivery/handoffs"),
            withIntermediateDirectories: true
        )
        let bundle = Bundle(for: RekonImportAcceptanceTests.self)
        try Self.copy("rekon-import-dashboard-status", extension: "json", from: bundle, to: artifactURL)
        try Self.copy("rekon-import-task-brief", extension: "md", from: bundle, to: taskBriefURL)
        try Self.copy("rekon-import-roadmap", extension: "md", from: bundle, to: root.appendingPathComponent("docs/delivery/roadmap.md"))
        try Self.copy("rekon-import-handoff", extension: "md", from: bundle, to: handoffURL)
        try Self.copy("rekon-import-ledger", extension: "md", from: bundle, to: root.appendingPathComponent("docs/delivery/delivery-ledger.md"))
        try Self.copy("rekon-import-arbitrary", extension: "md", from: bundle, to: root.appendingPathComponent("README.md"))
        testCase.addTeardownBlock { [root] in try? FileManager.default.removeItem(at: root) }
    }

    func seedProject(in store: DeliveryStore) async throws {
        let projectID = projectID
        let rootPath = root.path
        try await store.transact(actor: .init(id: "test-seed"), reason: "Seed import project") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name) VALUES (?, ?)",
                bindings: [.text(projectID.rawValue), .text("Imported project")]
            )
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                bindings: [.text("root-import"), .text(projectID.rawValue), .text(rootPath)]
            )
        }
    }

    private static func copy(_ name: String, extension fileExtension: String, from bundle: Bundle, to destination: URL) throws {
        let source = try XCTUnwrap(bundle.url(forResource: name, withExtension: fileExtension))
        try FileManager.default.copyItem(at: source, to: destination)
    }
}

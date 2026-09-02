import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class ProjectDocumentationPreviewTests: XCTestCase {
    func testCentralContractNamesOnlyCanonicalApplicationPaths() {
        XCTAssertEqual(RepositoryDocumentContract.guidanceVersion, 2)
        XCTAssertEqual(RepositoryDocumentContract.rekonSeedVersion, 1)
        XCTAssertEqual([
            RepositoryDocumentContract.guidancePath,
            RepositoryDocumentContract.catalogPath,
            RepositoryDocumentContract.rootIndexPath,
            RepositoryDocumentContract.progressPath,
            RepositoryDocumentContract.rekonSeedPath,
            RepositoryDocumentContract.taskBriefCollectionPath,
            RepositoryDocumentContract.handoffCollectionPath,
            RepositoryDocumentContract.reviewCollectionPath,
            RepositoryDocumentContract.evidenceCollectionPath,
            RepositoryDocumentContract.planCollectionPath,
            RepositoryDocumentContract.archiveCollectionPath
        ], ["AGENTS.md", "docs/catalog.json", "docs/README.md", "docs/delivery/progress.md", "docs/delivery/dashboard-status.json", "docs/delivery/task-briefs", "docs/delivery/handoffs", "docs/delivery/reviews", "docs/delivery/evidence", "docs/delivery/plans", "docs/delivery/archive"])
        XCTAssertEqual(RepositoryDocumentContract.guidanceStartMarker, "<!-- release-radar-guidance:v2:start -->")
        XCTAssertEqual(RepositoryDocumentContract.guidanceEndMarker, "<!-- release-radar-guidance:end -->")
        XCTAssertEqual(RepositoryDocumentContract.handoffEvidenceIDPrefix, "release-radar-handoff:v1:")
    }

    func testAbsentCatalogKeepsExactLegacyGuidanceAndPresentation() throws {
        let root = try fixture()
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/catalog.json"))
        for audited in [false, true] {
            let guidance: ProjectGuidanceState = .outdated(installed: 1, current: 2)
            let state = ProjectGuidanceInspection.inspectDocumentation(rootURL: root, hasAuditedHandoff: audited)
            XCTAssertEqual(state, .legacy(guidance))
            XCTAssertEqual(ProjectGuidancePresentation(documentationState: state), ProjectGuidancePresentation(state: guidance))
        }
    }

    func testValidCatalogStagesReadOnlyUnderExactV1WithEitherHandoffState() throws {
        let root = try fixture()
        let before = try repositoryBytes(root)
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        for audited in [false, true] {
            let state = ProjectGuidanceInspection.inspectDocumentation(rootURL: root, hasAuditedHandoff: audited)
            XCTAssertEqual(state, .stagedCatalog(hasAuditedHandoff: audited, preview: .valid(version: 1, digest: snapshot.digest)))
            XCTAssertEqual(state.guidanceState, .outdated(installed: 1, current: 2))
            let presentation = ProjectGuidancePresentation(documentationState: state)
            XCTAssertEqual(presentation.status, "Release Radar catalog staged · v1")
            XCTAssertTrue(presentation.detail.contains("read-only"))
            XCTAssertTrue(presentation.detail.contains("Import, evidence, and delivery state are unchanged."))
            XCTAssertEqual(presentation.actionTitle, "Copy update prompt")
        }
        XCTAssertEqual(try repositoryBytes(root), before)
    }

    func testInvalidStagedCatalogIsActionableWithoutMakingGuidanceUnreadable() throws {
        let cases: [(RepositoryDocumentError.Code, (URL) throws -> Void)] = [
            (.malformedCatalog, { try Data("{".utf8).write(to: $0.appendingPathComponent("docs/catalog.json")) }),
            (.unsupportedVersion, { try Data("{\"version\":2}".utf8).write(to: $0.appendingPathComponent("docs/catalog.json")) }),
            (.unsafeFileType, { root in
                let catalog = root.appendingPathComponent("docs/catalog.json")
                let outside = root.appendingPathComponent("outside-catalog.json")
                try FileManager.default.moveItem(at: catalog, to: outside)
                try FileManager.default.createSymbolicLink(at: catalog, withDestinationURL: outside)
            }),
            (.unsafeFileType, { root in
                try FileManager.default.moveItem(at: root.appendingPathComponent("docs"), to: root.appendingPathComponent("outside-docs"))
                try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("docs"), withDestinationURL: root.appendingPathComponent("outside-docs"))
            }),
            (.missingFile, { try FileManager.default.removeItem(at: $0.appendingPathComponent("docs/plans/draft.md")) }),
            (.checksumMismatch, { try Data("changed".utf8).write(to: $0.appendingPathComponent("docs/plans/evidence.md")) })
        ]
        for (expected, mutate) in cases {
            let root = try fixture()
            try mutate(root)
            let state = ProjectGuidanceInspection.inspectDocumentation(rootURL: root, hasAuditedHandoff: true)
            guard case let .stagedCatalog(audited, .invalid(error)) = state else {
                return XCTFail("Expected invalid staged preview for \(expected), received \(state)")
            }
            XCTAssertTrue(audited)
            XCTAssertEqual(error.code, expected)
            XCTAssertEqual(state.guidanceState, .outdated(installed: 1, current: 2))
            XCTAssertEqual(ProjectGuidanceInspection.inspect(rootURL: root, hasAuditedHandoff: true), .outdated(installed: 1, current: 2))
            let presentation = ProjectGuidancePresentation(documentationState: state)
            XCTAssertEqual(presentation.status, "Release Radar staged catalog needs repair")
            XCTAssertTrue(presentation.detail.contains("retry"))
            XCTAssertFalse(presentation.detail.contains(root.path))
        }
    }

    func testNonExactV1GuidanceDoesNotActivateStagedCatalog() throws {
        let root = try fixture()
        for contents in ["# Owner guidance", RepositoryDocumentContract.legacyManagedGuidanceBlock + "\n<!-- release-radar-guidance:end -->", RepositoryDocumentContract.legacyManagedGuidanceBlock.replacingOccurrences(of: "v1:start", with: "v2:start")] {
            try Data(contents.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
            let guidance = ProjectGuidanceInspection.inspect(rootURL: root, hasAuditedHandoff: true)
            XCTAssertEqual(ProjectGuidanceInspection.inspectDocumentation(rootURL: root, hasAuditedHandoff: true), .legacy(guidance))
        }
    }

    func testOnboardingAndImporterKeepLegacyPreviewAndStoreUnchangedForEveryCatalogState() async throws {
        let root = try fixture()
        try addSeed(root)
        let database = root.deletingLastPathComponent().appendingPathComponent("store-\(UUID().uuidString).sqlite")
        let store = DeliveryStore(databaseURL: database)
        let project = AuthorizedProject(projectID: .init(rawValue: "preview"), canonicalRoot: root, authorizedRoots: [root])
        let importer = RekonArtifactImporter(store: store, project: project)
        let expectedImport = try importer.preview(root)
        let catalogURL = root.appendingPathComponent("docs/catalog.json")
        let validCatalog = try Data(contentsOf: catalogURL)
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: PreviewBookmarkStore())
        let beforeStore = try await storeCounts(store)
        for catalog in [nil, validCatalog, Data("{".utf8)] {
            if let catalog { try catalog.write(to: catalogURL) }
            else { try FileManager.default.removeItem(at: catalogURL) }
            let beforeFiles = try repositoryBytes(root)
            let preview = try await onboarding.inspect(folder: root)
            XCTAssertEqual(preview.recognizedArtifactPreview, expectedImport)
            XCTAssertEqual(try importer.preview(root), expectedImport)
            XCTAssertEqual(preview.projectGuidanceState, .outdated(installed: 1, current: 2))
            if catalog == nil {
                XCTAssertEqual(preview.documentationState, .legacy(.outdated(installed: 1, current: 2)))
            } else if catalog == validCatalog {
                XCTAssertEqual(preview.documentationState, .stagedCatalog(hasAuditedHandoff: false, preview: .valid(version: 1, digest: snapshot.digest)))
            } else {
                XCTAssertEqual(preview.documentationState, .stagedCatalog(hasAuditedHandoff: false, preview: .invalid(.init(.malformedCatalog))))
            }
            XCTAssertEqual(try repositoryBytes(root), beforeFiles)
            let afterStore = try await storeCounts(store)
            XCTAssertEqual(afterStore, beforeStore)
        }
        XCTAssertFalse(expectedImport.evidence.isEmpty)
        XCTAssertTrue(expectedImport.evidence.allSatisfy { !$0.isAvailable })
    }

    func testTransitionalSuperpowersFilesAreNotLegacyImportOrGuidanceDependencies() async throws {
        let root = try fixture()
        try addSeed(root)
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/catalog.json"))
        let store = DeliveryStore(databaseURL: root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
        let project = AuthorizedProject(projectID: .init(rawValue: "legacy"), canonicalRoot: root, authorizedRoots: [root])
        let importer = RekonArtifactImporter(store: store, project: project)
        let before = try importer.preview(root)
        let plans = root.appendingPathComponent("docs/superpowers/plans", isDirectory: true)
        try FileManager.default.createDirectory(at: plans, withIntermediateDirectories: true)
        try Data("Arbitrary historical content".utf8).write(to: plans.appendingPathComponent("delivery-ledger.md"))
        XCTAssertEqual(try importer.preview(root), before)
        XCTAssertEqual(ProjectGuidanceInspection.inspectDocumentation(rootURL: root, hasAuditedHandoff: true), .legacy(.outdated(installed: 1, current: 2)))
    }

    func testAuthorizedSavedProjectObservationPreservesAuditedHandoffAndEvidence() async throws {
        let root = try fixture()
        let store = DeliveryStore(databaseURL: root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: PreviewBookmarkStore())
        let preview = try await onboarding.inspect(folder: root)
        let projectID = try await onboarding.prepare(.init(preview: preview, projectName: "Preview"))
        let path = root.appendingPathComponent("AGENTS.md").path
        try await store.transact(actor: .init(id: "fixture"), reason: "Fixture guidance handoff") { connection in
            try connection.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES (?, ?, ?, 1)", bindings: [.text("release-radar-handoff:v1:fixture"), .text(projectID.rawValue), .text(path)])
        }
        let before = try await storeCounts(store)
        let observation = await onboarding.observeProjectGuidanceContext(projectID: projectID)
        XCTAssertEqual(observation.projectRoot, root)
        XCTAssertEqual(observation.state, .outdated(installed: 1, current: 2))
        guard case .stagedCatalog(hasAuditedHandoff: true, preview: .valid) = observation.documentationState else {
            return XCTFail("Saved authorization must expose the staged catalog with its audited handoff")
        }
        let counts = try await storeCounts(store)
        XCTAssertEqual(counts, before)
        let evidence = try await store.read { connection in
            try connection.row("SELECT path, is_available FROM evidence WHERE id = 'release-radar-handoff:v1:fixture'")
        }
        XCTAssertEqual(evidence?["path"], .text(path))
        XCTAssertEqual(evidence?["is_available"], .integer(1))
    }

    private func fixture() throws -> URL {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-M2C-\(UUID().uuidString)", isDirectory: true).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("repository", isDirectory: true)
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        return root
    }

    private func addSeed(_ root: URL) throws {
        let delivery = root.appendingPathComponent("docs/delivery", isDirectory: true)
        try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
        let seed = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RekonImport/rekon-import-dashboard-status.json")
        try FileManager.default.copyItem(at: seed, to: delivery.appendingPathComponent("dashboard-status.json"))
        let url = root.appendingPathComponent("docs/catalog.json")
        var catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var collections = try XCTUnwrap(catalog["collections"] as? [[String: Any]])
        collections.append(["collectionID": "delivery", "path": "docs/delivery", "parentCollection": "docs", "purpose": "Delivery seed", "allowedContents": ["Seed"], "prohibitedContents": ["Temporary files"], "isLeaf": true])
        catalog["collections"] = collections
        var artifacts = try XCTUnwrap(catalog["artifacts"] as? [[String: Any]])
        artifacts.append(["artifactID": "seed", "path": "docs/delivery/dashboard-status.json", "kind": "document", "lifecycle": "active", "authorityLevel": "supporting", "parentCollection": "delivery", "supersedes": [], "applicationSensitivity": ["importer"], "checksum": ["policy": "notApplicable"]])
        catalog["artifacts"] = artifacts
        try JSONSerialization.data(withJSONObject: catalog).write(to: url)
    }

    private func repositoryBytes(_ root: URL) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for path in try FileManager.default.subpathsOfDirectory(atPath: root.path) {
            let url = root.appendingPathComponent(path)
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[path] = try Data(contentsOf: url)
            }
        }
        return result
    }

    private func storeCounts(_ store: DeliveryStore) async throws -> [Int64?] {
        try await store.read { connection in
            try ["projects", "phases", "tickets", "evidence", "audit_events", "agent_command_requests", "notification_events"].map {
                try connection.scalarInt("SELECT COUNT(*) FROM \($0)")
            }
        }
    }
}

private struct PreviewBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false)
    }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        try await body(resolve(bookmark))
    }
}

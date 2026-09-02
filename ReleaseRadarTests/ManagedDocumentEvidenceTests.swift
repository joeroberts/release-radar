import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ManagedDocumentEvidenceTests: XCTestCase {
    func testLocatedEvidenceRoundTripsBothLocatorsAndDecodesLegacyPayload() throws {
        let legacy = EvidenceRecord(id: .init(rawValue: "e"), projectID: .init(rawValue: "p"), ticketID: nil,
                                    path: "/test/arbitrary.md", isAvailable: false)
        let decoded = try JSONDecoder().decode(LocatedEvidenceRecord.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.locator, .filePath("/test/arbitrary.md"))
        XCTAssertEqual(decoded.legacyRecord, legacy)
        for locator: EvidenceLocator in [.filePath("/test/arbitrary.md"), .managedDocument(artifactID: "current")] {
            let record = LocatedEvidenceRecord(id: legacy.id, projectID: legacy.projectID, ticketID: nil,
                                               locator: locator, isAvailable: false)
            XCTAssertEqual(try JSONDecoder().decode(LocatedEvidenceRecord.self, from: JSONEncoder().encode(record)), record)
            if case .managedDocument = locator { XCTAssertNil(record.legacyRecord) }
        }
    }

    func testLocatorDecodingRejectsMissingMixedNullAndUnknownVariants() throws {
        for text in ["{}", #"{"kind":"filePath"}"#, #"{"kind":"managedDocument","artifactID":"a","path":null}"#,
                     #"{"kind":"filePath","path":"x","artifactID":"a"}"#, #"{"kind":"other","path":"x"}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(EvidenceLocator.self, from: Data(text.utf8)))
        }
        let legacy = EvidenceRecord(id: .init(rawValue: "e"), projectID: .init(rawValue: "p"), ticketID: nil,
                                    path: "x", isAvailable: true)
        var payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        payload["locator"] = ["kind": "managedDocument", "artifactID": "a"]
        XCTAssertThrowsError(try JSONDecoder().decode(LocatedEvidenceRecord.self, from: JSONSerialization.data(withJSONObject: payload)))
        payload.removeValue(forKey: "locator"); payload.removeValue(forKey: "path")
        XCTAssertThrowsError(try JSONDecoder().decode(LocatedEvidenceRecord.self, from: JSONSerialization.data(withJSONObject: payload)))
    }

    func testBindingCanonicalSnapshotRoundTripAndTamperedPayloadsReject() throws {
        let root = try fixture()
        let binding = try makeBinding(root)
        let data = try JSONEncoder().encode(binding)
        XCTAssertEqual(try JSONDecoder().decode(ProjectDocumentationBinding.self, from: data), binding)
        for (key, value): (String, Any) in [("repositoryID", "22222222-2222-2222-2222-222222222222"),
                                            ("acceptedCatalogVersion", 2), ("acceptedCatalogDigest", String(repeating: "0", count: 64)),
                                            ("acceptedCatalog", Data("{}".utf8).base64EncodedString())] {
            var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            object[key] = value
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectDocumentationBinding.self, from: JSONSerialization.data(withJSONObject: object)))
        }
    }

    func testResolverRequiresBindingProjectRootAuthorizationAndFreshBookmark() async throws {
        let root = try fixture()
        let binding = try makeBinding(root)
        assertFailure(await resolve(root, binding: nil), .bindingMissing)
        assertFailure(await resolve(root, binding: binding, project: "other"), .bindingMismatch)
        assertFailure(await resolve(root, binding: binding, rootID: "old-root"), .rootNotBound)
        assertFailure(await resolve(root, binding: binding, rootProject: "other"), .rootNotBound)
        assertFailure(await resolve(root, binding: binding, stale: true), .staleRoot)
        assertFailure(await resolve(root, binding: binding, access: false), .rootUnavailable)
        let other = try fixture()
        assertFailure(await resolve(other, binding: binding, persistedRoot: root), .rootNotBound)
    }

    func testUnavailableRootAndMissingAuthorizationFailBeforeCatalogAccess() async throws {
        let root = try fixture()
        let binding = try makeBinding(root)
        assertFailure(await resolve(root.appendingPathComponent("unavailable"), binding: binding), .rootUnavailable)
        let resolver = ManagedDocumentResolver()
        assertFailure(await resolver.resolve(artifactID: "draft", projectID: binding.projectID, binding: binding,
                                             root: nil, bookmark: Data([1])), .rootNotBound)
        assertFailure(await resolver.resolve(artifactID: "draft", projectID: binding.projectID, binding: binding,
                                             root: .init(id: binding.rootID, projectID: binding.projectID, path: root.path),
                                             bookmark: nil), .rootUnavailable)
    }

    func testResolverRejectsSameRepositoryUnacceptedCatalogAndRetainsIdentity() async throws {
        let root = try fixture()
        let binding = try makeBinding(root)
        try edit(root) { object in
            var artifacts = object["artifacts"] as! [[String: Any]]
            artifacts[3]["lifecycle"] = "active"; object["artifacts"] = artifacts
        }
        let result = await resolve(root, binding: binding)
        XCTAssertEqual(result.failure, .catalogUnaccepted)
        XCTAssertEqual(result.artifactID, "draft")
        XCTAssertNil(result.resolvedPath)
        try edit(root) { $0["repositoryID"] = "22222222-2222-2222-2222-222222222222" }
        assertFailure(await resolve(root, binding: binding), .bindingMismatch)
    }

    func testManagedIdentityResolvesAcceptedMoveWithoutChangingEvidence() async throws {
        let root = try fixture()
        let binding = try makeBinding(root)
        let before = await resolve(root, binding: binding)
        XCTAssertEqual(before.resolvedPath, "docs/plans/draft.md")
        XCTAssertEqual(before.label, "draft.md")
        XCTAssertEqual(before.lifecycle, .proposed)
        XCTAssertEqual(before.authority, .supporting)
        XCTAssertTrue(before.isAvailable)
        try FileManager.default.moveItem(at: root.appendingPathComponent("docs/plans/draft.md"), to: root.appendingPathComponent("docs/plans/renamed.md"))
        try editArtifact(root, "draft") { $0["path"] = "docs/plans/renamed.md" }
        try Data("# Current\n".utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
        assertFailure(await resolve(root, binding: binding), .catalogUnaccepted)
        let accepted = try makeBinding(root)
        let after = await resolve(root, binding: accepted)
        XCTAssertEqual(after.artifactID, before.artifactID)
        XCTAssertEqual(after.resolvedPath, "docs/plans/renamed.md")
        XCTAssertTrue(after.isAvailable)
    }

    func testMissingAndRestoredFilesChangeAvailabilityWithoutIdentityLoss() async throws {
        let root = try fixture()
        let binding = try makeBinding(root)
        let file = root.appendingPathComponent("docs/plans/draft.md")
        let bytes = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        let missing = await resolve(root, binding: binding)
        XCTAssertEqual(missing.failure, .missingDocument)
        XCTAssertEqual(missing.artifactID, "draft")
        XCTAssertEqual(missing.resolvedPath, "docs/plans/draft.md")
        XCTAssertFalse(missing.isAvailable)
        try bytes.write(to: file)
        let restored = await resolve(root, binding: binding)
        XCTAssertTrue(restored.isAvailable)
        XCTAssertEqual(restored.artifactID, missing.artifactID)
    }

    func testAvailableHistoricalArtifactsRemainNonControlling() async throws {
        for lifecycle in ["archived", "superseded", "completed"] {
            let root = try fixture()
            try editArtifact(root, "draft") { $0["lifecycle"] = lifecycle; $0["authorityLevel"] = "nonAuthoritative" }
            try Data("# Current\n".utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
            let result = await resolve(root, binding: try makeBinding(root))
            XCTAssertTrue(result.isAvailable)
            XCTAssertEqual(result.lifecycle?.rawValue, lifecycle)
            XCTAssertEqual(result.authority, .nonAuthoritative)
            XCTAssertFalse(result.isControlling)
        }
    }

    func testCatalogFailuresChecksumFailureAndMissingIdentityAreTyped() async throws {
        let root = try fixture()
        let binding = try makeBinding(root)
        assertFailure(await resolve(root, binding: binding, artifact: "unknown"), .artifactNotFound)
        try Data("changed".utf8).write(to: root.appendingPathComponent("docs/plans/evidence.md"))
        assertFailure(await resolve(root, binding: binding, artifact: "evidence"), .checksumInvalid)
        try Data("{".utf8).write(to: root.appendingPathComponent("docs/catalog.json"))
        assertFailure(await resolve(root, binding: binding), .catalogInvalid(.malformedCatalog))
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/catalog.json"))
        assertFailure(await resolve(root, binding: binding), .catalogInvalid(.missingFile))
    }

    func testSymlinkAndTraversalResolutionFailClosedWithoutAbsolutePathLeak() async throws {
        for path in ["docs/catalog.json", "docs/plans/draft.md", "docs/plans"] {
            let root = try fixture()
            let binding = try makeBinding(root)
            let file = root.appendingPathComponent(path)
            let outside = root.appendingPathComponent("outside")
            try FileManager.default.moveItem(at: file, to: outside)
            try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
            let result = await resolve(root, binding: binding)
            XCTAssertEqual(result.failure, .unsafeResolution)
            XCTAssertFalse(String(describing: result).contains(root.path))
        }
        let root = try fixture()
        let binding = try makeBinding(root)
        try editArtifact(root, "draft") { $0["path"] = "docs/../../owner-secret" }
        assertFailure(await resolve(root, binding: binding), .unsafeResolution)
    }

    func testResolutionRequiresCurrentManagedGuidanceDeclaration() async throws {
        for contents: String? in [nil, "Legacy guidance", "<!-- release-radar:managed-guidance:start v99 -->"] {
            let root = try fixture()
            let binding = try makeBinding(root)
            let guidance = root.appendingPathComponent("AGENTS.md")
            if let contents { try Data(contents.utf8).write(to: guidance) }
            else { try FileManager.default.removeItem(at: guidance) }
            let resolved = await resolve(root, binding: binding)
            XCTAssertFalse(resolved.isAvailable, "Managed evidence cannot be available without current v2 guidance")
            XCTAssertNotNil(resolved.failure)
        }
    }

    func testPublicReadbackResolvesStoredIdentityWithoutMutatingAvailability() async throws {
        let root = try fixture()
        let database = root.appendingPathComponent("test.sqlite")
        let store = DeliveryStore(databaseURL: database)
        let binding = try makeBinding(root)
        try await store.transact(actor: .init(id: "fixture"), reason: "Readback fixture") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'p', ?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)", bindings: [.text(root.path), .blob(Data(root.path.utf8))])
            try c.execute("INSERT INTO project_documentation_bindings VALUES ('p', 'root', ?, 1, ?, ?)", bindings: [.text(binding.repositoryID), .text(binding.acceptedCatalogDigest), .blob(binding.acceptedCatalog)])
            try c.execute("INSERT INTO evidence (id, project_id, artifact_id, is_available) VALUES ('proposed', 'p', 'draft', 0)")
            try c.execute("INSERT INTO evidence (id, project_id, artifact_id, is_available) VALUES ('historical', 'p', 'history', 0)")
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('legacy', 'p', '/arbitrary/legacy.md', 1)")
        }
        let rows = try await store.evidenceReadback(projectID: binding.projectID, bookmarkStore: RelocationBookmarks())
        let proposed = try XCTUnwrap(rows.first { $0.evidence.id.rawValue == "proposed" })
        XCTAssertFalse(proposed.evidence.isAvailable)
        XCTAssertTrue(proposed.managedDocument!.isAvailable)
        XCTAssertEqual(proposed.managedDocument?.lifecycle, .proposed)
        XCTAssertFalse(proposed.managedDocument!.isControlling)
        XCTAssertNil(rows.first { $0.evidence.id.rawValue == "legacy" }?.managedDocument)
        let auditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(auditCount, 1)
    }

    private func assertFailure(_ result: ResolvedManagedDocument, _ failure: ManagedDocumentResolutionFailure,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.failure, failure, file: file, line: line)
        XCTAssertFalse(result.isAvailable, file: file, line: line)
    }
    private func fixture() throws -> URL {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ReleaseRadar-Managed-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func makeBinding(_ root: URL) throws -> ProjectDocumentationBinding {
        try .init(projectID: .init(rawValue: "p"), rootID: .init(rawValue: "root"),
                  acceptedSnapshot: RepositoryDocumentValidator().validateCurrent(authorizedRoot: root))
    }
    private func resolve(_ root: URL, binding: ProjectDocumentationBinding?, project: String = "p",
                         rootID: String = "root", rootProject: String = "p", stale: Bool = false,
                         access: Bool = true, persistedRoot: URL? = nil, artifact: String = "draft") async -> ResolvedManagedDocument {
        let bookmarks = ProjectBookmarkStore(resolver: { _ in .init(url: root, isStale: stale) },
                                            startAccessing: { _ in access }, stopAccessing: { _ in })
        return await ManagedDocumentResolver().resolve(artifactID: artifact, projectID: .init(rawValue: project),
            binding: binding, root: .init(id: .init(rawValue: rootID), projectID: .init(rawValue: rootProject), path: (persistedRoot ?? root).path),
            bookmark: Data([1]), bookmarkStore: bookmarks)
    }
    private func edit(_ root: URL, _ mutate: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent("docs/catalog.json")
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&object)
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url)
    }
    private func editArtifact(_ root: URL, _ id: String, _ mutate: (inout [String: Any]) -> Void) throws {
        try edit(root) { object in
            var artifacts = object["artifacts"] as! [[String: Any]]
            let index = artifacts.firstIndex { $0["artifactID"] as? String == id }!
            mutate(&artifacts[index]); object["artifacts"] = artifacts
        }
    }
}

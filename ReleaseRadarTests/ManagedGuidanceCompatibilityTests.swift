import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class ManagedGuidanceCompatibilityTests: XCTestCase {
    func testCurrentGuidanceBlockPathsAndStableHandoffIdentity() {
        XCTAssertEqual(RepositoryDocumentContract.guidanceVersion, 2)
        XCTAssertEqual(RepositoryDocumentContract.managedGuidanceBlock, Self.v2)
        XCTAssertEqual(RepositoryDocumentContract.planCollectionPath, "docs/delivery/plans")
        XCTAssertEqual(RepositoryDocumentContract.handoffEvidenceIDPrefix, "release-radar-handoff:v1:")
        XCTAssertEqual(ProjectGuidanceInspection.inspect(contents: Self.v2), .current(version: 2))
    }

    func testExactLegacyGuidanceIsUpgradeableAndModifiedOrFutureV2FailsClosed() {
        XCTAssertEqual(ProjectGuidanceInspection.inspect(contents: Self.v1), .outdated(installed: 1, current: 2))
        XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: Self.v1), .legacy)
        XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: Self.v2), .managedV2)
        for content in [Self.v2.replacingOccurrences(of: "task-relevant", with: "all"), Self.v2.replacingOccurrences(of: "v2:start", with: "v3:start"), "<!-- release-radar-guidance:v2:start -->\n<!-- release-radar-guidance:end -->"] {
            XCTAssertEqual(ProjectGuidanceInspection.inspect(contents: content), .needsRepair)
            XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: content), .unavailable)
        }
    }

    func testReadableV2WithoutBindingIsManagedUnavailableRatherThanCurrent() throws {
        let root = try fixture()
        let state = ProjectGuidanceInspection.inspectDocumentation(rootURL: root, hasAuditedHandoff: true)
        XCTAssertEqual(state.guidanceState, .current(version: 2))
        let presentation = ProjectGuidancePresentation(documentationState: state)
        XCTAssertEqual(presentation.status, "Release Radar managed documentation unavailable")
        XCTAssertTrue(presentation.detail.contains("bind"))
        XCTAssertNil(presentation.actionTitle, "Binding recovery must not offer a misleading guidance rewrite")
    }

    func testSavedBoundObservationRequiresExactAcceptedSnapshotAndKeepsLegacyHandoff() async throws {
        let root = try fixture()
        let store = DeliveryStore(databaseURL: root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: ManagedGuidanceBookmarks())
        let project = try await onboarding.prepare(.init(preview: onboarding.inspect(folder: root), projectName: "Managed"))
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let rootPath = root.path
        try await store.transact(actor: .init(id: "fixture"), reason: "Accepted synthetic binding and legacy handoff") { c in
            let rootID = try XCTUnwrap(c.scalarText("SELECT id FROM project_roots WHERE project_id = ? AND path = ?", bindings: [.text(project.rawValue), .text(rootPath)]))
            try c.execute("INSERT INTO project_documentation_bindings (project_id, root_id, repository_id, accepted_catalog_version, accepted_catalog_digest, accepted_catalog) VALUES (?, ?, ?, 1, ?, ?)", bindings: [.text(project.rawValue), .text(rootID), .text(snapshot.catalog.repositoryID.lowercased()), .text(snapshot.digest), .blob(snapshot.canonicalCatalog)])
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('release-radar-handoff:v1:existing', ?, ?, 1)", bindings: [.text(project.rawValue), .text(root.appendingPathComponent("AGENTS.md").path)])
        }
        let before = try await counts(store)
        let observation = await onboarding.observeProjectGuidanceContext(projectID: project)
        XCTAssertEqual(observation.state, .current(version: 2))
        XCTAssertEqual(ProjectGuidancePresentation(documentationState: observation.documentationState).status, "Release Radar managed documentation current · v2")
        let catalog = root.appendingPathComponent("docs/catalog.json")
        var changed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any])
        changed["retiredArtifactIDs"] = ["retired-document", "newly-retired"]
        try JSONSerialization.data(withJSONObject: changed).write(to: catalog)
        let pending = await onboarding.observeProjectGuidanceContext(projectID: project)
        XCTAssertEqual(ProjectGuidancePresentation(documentationState: pending.documentationState).status, "Release Radar managed documentation unavailable")
        XCTAssertTrue(ProjectGuidancePresentation(documentationState: pending.documentationState).detail.contains("accept"))
        let after = try await counts(store)
        XCTAssertEqual(after, before)
    }

    func testBundledCandidateAndUpgradePromptNameV2() throws {
        let package = try CodexPluginPackage(rootURL: Self.repository.appendingPathComponent("ReleaseRadar/CodexPluginMarketplace"))
        XCTAssertEqual(package.version, "0.1.6")
        let prompt = CodexPromptHandoff.prompt(for: .outdated(installed: 1, current: 2), projectRoot: URL(fileURLWithPath: "/Synthetic/Managed"))
        XCTAssertTrue(prompt.contains("guidance v2"))
        XCTAssertTrue(prompt.contains("existing handoff evidence ID"))
    }

    func testSavedPhaseLessRootUsesPersistedOwnerForDocumentationObservation() async throws {
        let root = try fixture()
        let store = DeliveryStore(databaseURL: root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        try await store.transact(actor: .init(id: "fixture"), reason: "Saved phase-less project at relocated root") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('persisted-before-relocation', 'Saved project')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'persisted-before-relocation', ?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('persisted-before-relocation', ?, ?, 0)", bindings: [.text(root.path), .blob(Data(root.path.utf8))])
            try c.execute("INSERT INTO project_documentation_bindings (project_id, root_id, repository_id, accepted_catalog_version, accepted_catalog_digest, accepted_catalog) VALUES ('persisted-before-relocation', 'root', ?, 1, ?, ?)", bindings: [.text(snapshot.catalog.repositoryID.lowercased()), .text(snapshot.digest), .blob(snapshot.canonicalCatalog)])
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('release-radar-handoff:v1:existing', 'persisted-before-relocation', ?, 1)", bindings: [.text(root.appendingPathComponent("AGENTS.md").path)])
        }
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: ManagedGuidanceBookmarks())
        for hasPhaseRequest in [false, true] {
            if hasPhaseRequest {
                try await store.transact(actor: .init(id: "fixture"), reason: "Awaiting first phase") { c in
                    try c.execute("INSERT INTO review_items (id, project_id, kind, summary, status) VALUES ('phase-request', 'persisted-before-relocation', ?, 'First phase requested', 'open')", bindings: [.text(OnboardingReviewMarkerKind.phaseRequest.rawValue)])
                }
            }
            let before = try await counts(store)
            let preview = try await onboarding.inspect(folder: root)
            XCTAssertEqual(preview.documentationState, .managed(hasAuditedHandoff: true, catalogVersion: 1, catalogDigest: snapshot.digest))
            XCTAssertNil(preview.pendingProjectID)
            XCTAssertNil(preview.completedProjectID)
            let after = try await counts(store)
            XCTAssertEqual(after, before)
        }
    }

    func testV2HandoffRequiresExistingCataloguedProgressBeforeWriting() throws {
        let skill = try String(contentsOf: Self.repository.appendingPathComponent("ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md"), encoding: .utf8)
        let prompt = CodexPromptHandoff.prompt(for: .outdated(installed: 1, current: 2), projectRoot: URL(fileURLWithPath: "/Synthetic/Managed"))
        XCTAssertTrue(skill.contains("existing catalogued `docs/delivery/progress.md`"))
        XCTAssertTrue(prompt.contains("existing catalogued docs/delivery/progress.md"))
        XCTAssertFalse(skill.contains("Release Radar audit: Pending"))
        XCTAssertFalse(skill.contains("if this handoff created the ledger"))
        XCTAssertFalse(prompt.contains("create docs/delivery/progress.md"))
    }

    func testNormalWorkflowChecksActualRepositoryWithAcceptedIndexTool() throws {
        XCTAssertEqual(RepositoryDocumentContract.guidanceVersion, 2)
        try RepositoryDocumentIndexTool().check(authorizedRoot: Self.repository)
    }

    func testReadableV2ReportsEveryUnavailableCatalogWithoutMutation() throws {
        for failure in ["missing", "malformed", "unsupported", "unsafe", "checksum"] {
            let root = try fixture()
            let catalog = root.appendingPathComponent("docs/catalog.json")
            switch failure {
            case "missing": try FileManager.default.removeItem(at: catalog)
            case "malformed": try Data("{".utf8).write(to: catalog)
            case "unsupported": try Data("{\"version\":3}".utf8).write(to: catalog)
            case "unsafe":
                let original = root.appendingPathComponent("catalog-original.json")
                try FileManager.default.moveItem(at: catalog, to: original)
                try FileManager.default.createSymbolicLink(at: catalog, withDestinationURL: original)
            default: try Data("changed".utf8).write(to: root.appendingPathComponent("docs/plans/evidence.md"))
            }
            let state = ProjectGuidanceInspection.inspectDocumentation(rootURL: root, hasAuditedHandoff: false)
            guard case let .managedUnavailable(audited, reason, validation) = state else { return XCTFail("Expected unavailable: \(failure)") }
            XCTAssertFalse(audited); XCTAssertEqual(reason, .catalogInvalid); XCTAssertNotNil(validation)
            XCTAssertEqual(state.guidanceState, .handoffIncomplete(version: 2))
            XCTAssertNil(ProjectGuidancePresentation(documentationState: state).actionTitle)
        }
    }

    func testOrdinaryConformanceRejectsDamagedDisposableRealRepository() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-M5-Conformance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: parent) }
        try FileManager.default.copyItem(at: Self.repository.appendingPathComponent("docs"), to: parent.appendingPathComponent("docs"))
        let fixturePath = "ReleaseRadarTests/Fixtures/SchemaV12/release-radar-v12.sqlite"
        let fixture = parent.appendingPathComponent(fixturePath)
        try FileManager.default.createDirectory(at: fixture.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Self.repository.appendingPathComponent(fixturePath), to: fixture)
        let catalog = parent.appendingPathComponent("docs/catalog.json")
        let index = parent.appendingPathComponent("docs/README.md")
        let catalogBytes = try Data(contentsOf: catalog), indexBytes = try Data(contentsOf: index)
        for failure in ["missing", "malformed", "unsafe", "stale"] {
            switch failure {
            case "missing": try FileManager.default.removeItem(at: catalog)
            case "malformed": try Data("{".utf8).write(to: catalog)
            case "unsafe":
                try FileManager.default.removeItem(at: catalog)
                let target = parent.appendingPathComponent("catalog-original.json")
                try catalogBytes.write(to: target)
                try FileManager.default.createSymbolicLink(at: catalog, withDestinationURL: target)
            default:
                let text = String(decoding: indexBytes, as: UTF8.self).replacingOccurrences(of: "## Collection: docs", with: "## Stale collection")
                try Data(text.utf8).write(to: index)
            }
            XCTAssertThrowsError(try RepositoryDocumentIndexTool().check(authorizedRoot: parent), failure) { error in
                if failure == "stale" { XCTAssertEqual((error as? RepositoryDocumentIndexError)?.code, .staleIndex) }
                else { XCTAssertNotNil(error as? RepositoryDocumentError) }
            }
            if FileManager.default.fileExists(atPath: catalog.path) { try FileManager.default.removeItem(at: catalog) }
            try catalogBytes.write(to: catalog); try indexBytes.write(to: index)
        }
        try RepositoryDocumentIndexTool().check(authorizedRoot: parent)
        XCTAssertEqual(try Data(contentsOf: catalog), catalogBytes)
        XCTAssertEqual(try Data(contentsOf: index), indexBytes)
    }

    private func fixture() throws -> URL {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-M5-\(UUID().uuidString)", isDirectory: true).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("repository")
        try FileManager.default.copyItem(at: Self.repository.appendingPathComponent("ReleaseRadarTests/Fixtures/RepositoryDocuments/valid"), to: root)
        try Data(Self.v2.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        return root
    }

    private func counts(_ store: DeliveryStore) async throws -> [Int64?] {
        try await store.read { c in try ["evidence", "audit_events", "agent_command_requests", "notification_events", "tickets", "phases"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") } }
    }

    static let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static let v1 = """
    <!-- release-radar-guidance:v1:start -->
    ## Release Radar tracking

    This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

    - `docs/delivery/progress.md` is the repository's durable delivery source of truth.
    - Codex may update repository tracking documents under owner authorization.
    - Release Radar is the only writer of its SQLite database. Use its existing typed MCP mutations; never edit that database directly.
    - Do not claim synchronization without both a successful audited MCP result and direct readback of the corresponding repository files.
    - Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state.
    <!-- release-radar-guidance:end -->
    """
    static let v2 = """
    <!-- release-radar-guidance:v2:start -->
    ## Release Radar tracking

    This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

    - Read `docs/catalog.json` and begin documentation discovery at `docs/README.md`. Follow generated local indexes before broad search and load only task-relevant controlling artifacts.
    - The catalog owns documentation identity, lifecycle, authority, and navigation. `docs/delivery/progress.md` remains the durable delivery source of truth; the catalog and indexes never authorize or infer ticket or phase state.
    - Under owner authorization, update the catalog, collection/index metadata, active references, and applicable checksums in the same change as any durable add, move, rename, supersession, closeout, restoration, or deletion. Preserve stable artifact IDs and never reuse retired IDs.
    - Keep only active operational detail in `docs/delivery/progress.md`; move closed detail to `docs/delivery/archive/` and label it historical and non-authoritative. Place implementation plans in `docs/delivery/plans/` and controlling task briefs in `docs/delivery/task-briefs/`.
    - Add no new content under `docs/superpowers/` during transition and never recreate it after cutover.
    - Release Radar is the only SQLite writer. Never edit that database or repair a managed evidence path directly. Use supported read-only inventory and typed, audited evidence operations with exact artifact IDs and request identities.
    - Managed operations require the exact authorized root and accepted repository ID, catalog version, and digest. Only explicit repository binding establishes a missing binding; only catalog acceptance advances an accepted snapshot. Treat a changed catalog as pending until Release Radar accepts its validated transition.
    - Run the repository documentation check and read back the resulting repository and application state before completion. Do not claim completion while catalog, indexes, lifecycle, authority, references, applicable checksums, evidence resolution, or application readback disagree. Preserve exact requests across uncertain outcomes.
    - Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state. Repository-local rules outside this block may narrow this contract but must not weaken or duplicate it.
    <!-- release-radar-guidance:end -->
    """
}

private struct ManagedGuidanceBookmarks: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false) }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T { try await body(resolve(bookmark)) }
}

import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectRootManagementTests: XCTestCase {
    func testExplicitWorktreeGrantReconnectAndRevokePreservePrimaryAndHistory() async throws {
        let f = try await fixture()
        let service = ProjectRootManagement(store: f.store, bookmarkStore: RelocationBookmarks())
        let original = try await service.snapshot(projectID: f.project)
        XCTAssertEqual(original.roots.first?.role, .primary)
        let grant = try await service.prepare(.authorize, folder: f.worktree, snapshot: original)
        let unchanged = try await service.snapshot(projectID: f.project)
        XCTAssertEqual(unchanged.roots.count, 1, "Preparation must not grant access")
        _ = try await service.confirm(grant)
        let granted = try await service.snapshot(projectID: f.project)
        XCTAssertEqual(granted.roots.count, 2)
        XCTAssertEqual(granted.roots.first(where: { $0.path == f.worktree.path })?.role, .worktree)
        _ = try await service.confirm(grant)
        let reconnect = try await service.prepare(.reconnect, folder: f.worktree, snapshot: granted)
        _ = try await service.confirm(reconnect)
        let current = try await service.snapshot(projectID: f.project)
        let revoke = try await service.prepare(.revoke, folder: f.worktree, snapshot: current)
        _ = try await service.confirm(revoke)
        let reopened = try await ProjectRootManagement(store: DeliveryStore(databaseURL: f.database), bookmarkStore: RelocationBookmarks()).snapshot(projectID: f.project)
        XCTAssertEqual(reopened.roots.map(\.path), [f.primary.path])
        XCTAssertEqual(reopened.registration, original.registration)
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.worktree.appendingPathComponent("untouched.txt").path))
        let retained = try await f.store.read { c in
            [try c.scalarInt("SELECT COUNT(*) FROM evidence"), try c.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-owner'")]
        }
        XCTAssertEqual(retained, [1, 3])
    }

    func testWrongWorktreeDeniedAuthorizationPrimaryRevokeAndStaleRequestPreserveAssociations() async throws {
        let f = try await fixture()
        let service = ProjectRootManagement(store: f.store, bookmarkStore: RelocationBookmarks())
        let original = try await service.snapshot(projectID: f.project)
        do { _ = try await service.prepare(.revoke, folder: f.primary, snapshot: original); XCTFail("Primary revoked") } catch {}
        let unrelated = f.primary.deletingLastPathComponent().appendingPathComponent("unrelated")
        try FileManager.default.createDirectory(at: unrelated.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try Data("ref: refs/heads/main\n".utf8).write(to: unrelated.appendingPathComponent(".git/HEAD"))
        do { _ = try await service.prepare(.authorize, folder: unrelated, snapshot: original); XCTFail("Unrelated repository authorized") } catch {}
        let denied = ProjectRootManagement(store: f.store, bookmarkStore: RelocationBookmarks(denied: true))
        do { _ = try await denied.prepare(.authorize, folder: f.worktree, snapshot: original); XCTFail("Denied access authorized") } catch {}
        let prepared = try await service.prepare(.authorize, folder: f.worktree, snapshot: original)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Registration replacement") { c in
            try c.execute("UPDATE project_registrations SET registration_id = 'replacement' WHERE project_id = 'p'")
        }
        do { _ = try await service.confirm(prepared); XCTFail("Stale worktree request committed") } catch {}
        let after = try await service.snapshot(projectID: f.project)
        XCTAssertEqual(after.roots.map(\.path), original.roots.map(\.path))
    }

    func testLateTransactionFailureRollsBackWorktreeGrant() async throws {
        let f = try await fixture()
        let service = ProjectRootManagement(store: f.store, bookmarkStore: RelocationBookmarks())
        let original = try await service.snapshot(projectID: f.project)
        let prepared = try await service.prepare(.authorize, folder: f.worktree, snapshot: original)
        let connection = try SQLiteConnection(url: f.database)
        try connection.execute("CREATE TRIGGER fail_root_audit BEFORE INSERT ON audit_events WHEN NEW.actor_id = 'release-radar-owner' BEGIN SELECT RAISE(ABORT, 'fixture'); END")
        do { _ = try await service.confirm(prepared); XCTFail("Audit failure committed partial grant") } catch {}
        let after = try await service.snapshot(projectID: f.project)
        XCTAssertEqual(after.roots.map(\.path), original.roots.map(\.path))
        let count = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM project_bookmarks") }
        XCTAssertEqual(count, 1)
    }

    func testRootHealthRejectsRegistrationReplacedDuringAuthorizationRead() async throws {
        let f = try await fixture()
        let service = ProjectRootManagement(store: f.store, bookmarkStore: RegistrationChangingBookmarks(store: f.store))
        do { _ = try await service.snapshot(projectID: f.project); XCTFail("Late root health crossed registration replacement") } catch {}
        let roots = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM project_roots") }
        XCTAssertEqual(roots, 1)
    }

    func testSandboxedMembershipValidatesGitMetadataAndRejectsUnsafeOrChangedLinks() async throws {
        for scenario in ["valid", "outside", "prefixEscape", "backlink", "symlink", "oversized", "traversal", "mainRedirect", "changed"] {
            let f = try await fixture()
            let service = ProjectRootManagement(store: f.store, bookmarkStore: RelocationBookmarks())
            let snapshot = try await service.snapshot(projectID: f.project)
            let pointer = f.worktree.appendingPathComponent(".git")
            let admin = f.primary.appendingPathComponent(".git/worktrees/linked")
            switch scenario {
            case "outside": try Data("gitdir: /outside/ungranted/admin\n".utf8).write(to: pointer)
            case "prefixEscape": try Data("gitdir: \(f.primary.path)-other/.git/worktrees/linked\n".utf8).write(to: pointer)
            case "traversal": try Data("gitdir: \(f.primary.path)/name/../.git/worktrees/linked\n".utf8).write(to: pointer)
            case "mainRedirect": try Data("../outside\n".utf8).write(to: f.primary.appendingPathComponent(".git/commondir"))
            case "backlink": try Data("/unrelated/.git\n".utf8).write(to: admin.appendingPathComponent("gitdir"))
            case "symlink":
                try FileManager.default.removeItem(at: pointer)
                try FileManager.default.createSymbolicLink(at: pointer, withDestinationURL: admin.appendingPathComponent("gitdir"))
            case "oversized": try Data(repeating: 65, count: 8192).write(to: pointer)
            default: break
            }
            do {
                let prepared = try await service.prepare(.authorize, folder: f.worktree, snapshot: snapshot)
                if scenario == "changed" { try Data("/unrelated/.git\n".utf8).write(to: admin.appendingPathComponent("gitdir")) }
                _ = try await service.confirm(prepared)
                XCTAssertEqual(scenario, "valid", "Invalid Git membership was authorized")
            } catch { XCTAssertNotEqual(scenario, "valid", "Valid sandboxed Git membership failed: \(error)") }
            let after = try await service.snapshot(projectID: f.project)
            XCTAssertEqual(after.roots.count, scenario == "valid" ? 2 : 1)
        }
    }

    func testGitGeneratedAbsoluteAndRelativeLinksWithSpacesWorkInTheSandboxForEitherPrimary() async throws {
        // Linkage metadata generated by Git 2.55 outside the test sandbox.
        for mode in ["absolute", "relative"] {
            let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/GitWorktreeMembership/\(mode)-links.json")
            let files = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: fixtureURL))
            for linkedPrimary in [false, true] {
                let f = try await fixture()
                let root = f.primary.deletingLastPathComponent().appendingPathComponent("git generated")
                for (path, text) in files {
                    let file = root.appendingPathComponent(path)
                    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try Data(text.replacingOccurrences(of: "${FIXTURE_ROOT}", with: root.path).utf8).write(to: file)
                }
                let main = root.appendingPathComponent("main repo"), linked = root.appendingPathComponent(mode == "relative" ? "linked worktree" : "absolute worktree")
                let primary = linkedPrimary ? linked : main, candidate = linkedPrimary ? main : linked
                try await f.store.transact(actor: .init(id: "fixture"), reason: "Git-generated fixture roots") { c in
                    try c.execute("UPDATE project_roots SET path = ? WHERE id = 'primary'", bindings: [.text(primary.path)])
                    try c.execute("UPDATE project_bookmarks SET path = ?, bookmark_data = ? WHERE project_id = 'p'", bindings: [.text(primary.path), .blob(Data(primary.path.utf8))])
                }
                let service = ProjectRootManagement(store: f.store, bookmarkStore: RelocationBookmarks())
                let snapshot = try await service.snapshot(projectID: f.project)
                let prepared = try await service.prepare(.authorize, folder: candidate, snapshot: snapshot)
                _ = try await service.confirm(prepared)
                let after = try await service.snapshot(projectID: f.project)
                XCTAssertEqual(after.roots.count, 2)
                XCTAssertEqual(after.roots.first(where: { $0.role == .primary })?.path, primary.path)
            }
        }
    }

    func testDeniedPrimaryScopeFailsPreparationAndConfirmationWithoutGrantingCandidate() async throws {
        let f = try await fixture()
        let normal = ProjectRootManagement(store: f.store, bookmarkStore: RelocationBookmarks())
        let snapshot = try await normal.snapshot(projectID: f.project)
        let denied = ProjectRootManagement(store: f.store, bookmarkStore: PrimaryDeniedBookmarks(primary: f.primary))
        do { _ = try await denied.prepare(.authorize, folder: f.worktree, snapshot: snapshot); XCTFail("Denied primary access accepted") }
        catch ProjectRootManagementError.primaryUnavailable { }
        let prepared = try await normal.prepare(.authorize, folder: f.worktree, snapshot: snapshot)
        do { _ = try await denied.confirm(prepared); XCTFail("Denied primary access committed") }
        catch ProjectRootManagementError.primaryUnavailable { }
        let after = try await normal.snapshot(projectID: f.project)
        XCTAssertEqual(after.roots.count, 1)
    }

    private struct Fixture { let store: DeliveryStore; let primary: URL; let worktree: URL; let database: URL; let project = ProjectID(rawValue: "p") }
    private func fixture() async throws -> Fixture {
        let dir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("C4-\(UUID().uuidString)")
        let primary = dir.appendingPathComponent("primary"), worktree = dir.appendingPathComponent("worktree")
        try FileManager.default.createDirectory(at: primary, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try Data("preserve".utf8).write(to: worktree.appendingPathComponent("untouched.txt"))
        let admin = primary.appendingPathComponent(".git/worktrees/linked")
        try FileManager.default.createDirectory(at: admin, withIntermediateDirectories: true)
        try Data("ref: refs/heads/main\n".utf8).write(to: primary.appendingPathComponent(".git/HEAD"))
        try Data("gitdir: \(admin.path)\n".utf8).write(to: worktree.appendingPathComponent(".git"))
        try Data("../..\n".utf8).write(to: admin.appendingPathComponent("commondir"))
        try Data("\(worktree.appendingPathComponent(".git").path)\n".utf8).write(to: admin.appendingPathComponent("gitdir"))
        try Data("0123456789012345678901234567890123456789\n".utf8).write(to: admin.appendingPathComponent("HEAD"))
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let database = dir.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: database)
        try await store.transact(actor: .init(id: "fixture"), reason: "Roots fixture") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try c.execute("INSERT INTO project_registrations (project_id, registration_id) VALUES ('p', 'registration-p')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('primary', 'p', ?)", bindings: [.text(primary.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)", bindings: [.text(primary.path), .blob(Data(primary.path.utf8))])
            try c.execute("INSERT INTO evidence (id, project_id, path) VALUES ('history', 'p', 'retained.txt')")
        }
        return .init(store: store, primary: primary, worktree: worktree, database: database)
    }
}

private struct RegistrationChangingBookmarks: ProjectBookmarkStoring {
    let store: DeliveryStore
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false) }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        try await store.transact(actor: .init(id: "fixture"), reason: "Concurrent registration replacement") { c in
            try c.execute("UPDATE project_registrations SET registration_id = 'replacement' WHERE project_id = 'p'")
        }
        return try await body(resolve(bookmark))
    }
}

private struct PrimaryDeniedBookmarks: ProjectBookmarkStoring {
    let primary: URL
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false) }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        let resolved = try resolve(bookmark)
        if resolved.url.path == primary.path { throw ProjectBookmarkError.securityScopeAccessDenied }
        return try await body(resolved)
    }
}

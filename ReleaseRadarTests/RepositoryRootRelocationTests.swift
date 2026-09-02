import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RepositoryRootRelocationTests: XCTestCase {
    func testMoveReplacesExactBoundRootRevokesBookmarkPreservesEvidenceAndReplaysAfterRelaunch() async throws {
        for handoff in [false, true] {
            let f = try await fixture(handoff: handoff)
            let service = RepositoryRootRelocation(store: f.store, bookmarkStore: RelocationBookmarks())
            let prepared = try await service.prepare(projectID: f.project, folder: f.next)
            let before = try await f.store.locatedEvidence(projectID: f.project, evidenceID: .init(rawValue: "managed"))
            try FileManager.default.removeItem(at: f.root)
            let result = try await service.confirm(prepared)
            let binding = try await f.store.documentationBinding(projectID: f.project)
            XCTAssertEqual(binding?.rootID, result.rootID)
            XCTAssertNotEqual(result.rootID.rawValue, "root")
            let rows = try await f.store.read { c in
                [try c.scalarInt("SELECT COUNT(*) FROM project_roots WHERE id = 'root'"),
                 try c.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE path = ?", bindings: [.text(f.root.path)]),
                 try c.scalarInt("SELECT COUNT(*) FROM agent_command_requests")]
            }
            XCTAssertEqual(rows, [0, 0, 1])
            let after = try await f.store.locatedEvidence(projectID: f.project, evidenceID: .init(rawValue: "managed"))
            XCTAssertEqual(after, before)
            let legacy = try await f.store.locatedEvidence(projectID: f.project, evidenceID: .init(rawValue: "legacy"))
            XCTAssertEqual(legacy?.locator, .filePath(f.root.appendingPathComponent("arbitrary.md").path))
            if handoff {
                let row = try await f.store.locatedEvidence(projectID: f.project, evidenceID: .init(rawValue: ProjectGuidanceInspection.handoffEvidenceIDPrefix + "one"))
                XCTAssertEqual(row?.locator, .filePath(f.next.appendingPathComponent("AGENTS.md").path))
                XCTAssertFalse(row!.isAvailable)
            }
            let reopened = DeliveryStore(databaseURL: f.database)
            let replay = try await RepositoryRootRelocation(store: reopened, bookmarkStore: RelocationBookmarks(denied: true)).confirm(prepared)
            XCTAssertEqual(replay, result, "Exact replay must not need the revoked old authorization")
            let resolved = try await reopened.evidenceReadback(projectID: f.project, bookmarkStore: RelocationBookmarks())
            XCTAssertTrue(resolved.first(where: { $0.evidence.id.rawValue == "managed" })!.managedDocument!.isAvailable)
            let authorized = try await FolderProjectOnboarding(store: reopened, bookmarkStore: RelocationBookmarks()).withAuthorizedProject(projectID: f.project) { $0.canonicalRoot }
            XCTAssertEqual(authorized.path, f.next.path)
            let receipt = try await f.store.read { try $0.row("SELECT request_body, result_data FROM agent_command_requests") }
            for value in receipt!.values {
                if case let .blob(data) = value {
                    XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(f.root.path))
                    XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(f.next.path))
                }
            }
            let reason = try await f.store.read { try $0.scalarText("SELECT reason FROM audit_events WHERE id = ?", bindings: [.text(result.auditEventID.rawValue)]) }
            XCTAssertEqual(reason, "Relocate bound documentation repository")
        }
    }

    func testAcceptedUppercaseRepositoryIdentityCanRelocate() async throws {
        let f = try await fixture(uppercaseRepositoryID: true)
        let service = RepositoryRootRelocation(store: f.store, bookmarkStore: RelocationBookmarks())
        let prepared = try await service.prepare(projectID: f.project, folder: f.next)
        _ = try await service.confirm(prepared)
        let binding = try await f.store.documentationBinding(projectID: f.project)
        XCTAssertEqual(binding?.repositoryID, "abcdefab-cdef-abcd-efab-cdefabcdefab")
    }

    func testSerializedRecoveryTokenReadsExactReceiptAfterPreparedStateIsLost() async throws {
        let f = try await fixture(handoff: true)
        let service = RepositoryRootRelocation(store: f.store, bookmarkStore: RelocationBookmarks())
        let prepared = try await service.prepare(projectID: f.project, folder: f.next)
        let tokenBytes = try JSONEncoder().encode(prepared.recoveryToken)
        XCTAssertFalse(String(decoding: tokenBytes, as: UTF8.self).contains(f.root.path))
        XCTAssertFalse(String(decoding: tokenBytes, as: UTF8.self).contains(f.next.path))
        let pending = try await service.recover(prepared.recoveryToken)
        XCTAssertNil(pending)
        let result = try await service.confirm(prepared)
        let reopened = DeliveryStore(databaseURL: f.database)
        let token = try JSONDecoder().decode(RepositoryRootRelocationRecoveryToken.self, from: tokenBytes)
        let recovered = try await RepositoryRootRelocation(store: reopened, bookmarkStore: RelocationBookmarks(denied: true)).recover(token)
        XCTAssertEqual(recovered, result)
        var object = try JSONSerialization.jsonObject(with: tokenBytes) as! [String: Any]
        object["requestHash"] = String(repeating: "0", count: 64)
        let conflicting = try JSONDecoder().decode(RepositoryRootRelocationRecoveryToken.self, from: JSONSerialization.data(withJSONObject: object))
        do { _ = try await service.recover(conflicting); XCTFail("Mismatched token accepted") } catch {}
    }

    func testReceiptRecoveryRejectsChangedReadOnlyStore() async throws {
        let f = try await fixture()
        let service = RepositoryRootRelocation(store: f.store, bookmarkStore: RelocationBookmarks())
        let prepared = try await service.prepare(projectID: f.project, folder: f.next)
        let readOnly = try DeliveryStore(existingReadOnlyDatabaseURL: f.database)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Source changed") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('changed', 'Changed')")
        }
        do {
            _ = try await RepositoryRootRelocation(store: readOnly).recover(prepared.recoveryToken)
            XCTFail("Recovery accepted a changed immutable read-only source")
        } catch {}
    }

    func testBoundAuthorizationIgnoresEarlierUnboundRoot() async throws {
        let f = try await fixture()
        let root = try await FolderProjectOnboarding(store: f.store, bookmarkStore: RelocationBookmarks()).withAuthorizedProject(projectID: f.project) { $0.canonicalRoot }
        XCTAssertEqual(root.path, f.root.path)
    }

    func testSameRootMismatchedCatalogIdentityDigestVersionAndUnsafeCandidateRejectWithoutWrites() async throws {
        for scenario in ["same", "repository", "digest", "version", "symlink", "missing", "guidance"] {
            let f = try await fixture()
            var candidate = f.next
            switch scenario {
            case "same": candidate = f.root
            case "missing": try FileManager.default.removeItem(at: f.next.appendingPathComponent("docs/plans/draft.md"))
            case "guidance": try Data("Legacy".utf8).write(to: f.next.appendingPathComponent("AGENTS.md"))
            case "symlink":
                candidate = f.next.deletingLastPathComponent().appendingPathComponent("link")
                try FileManager.default.createSymbolicLink(at: candidate, withDestinationURL: f.next)
            default:
                let url = f.next.appendingPathComponent("docs/catalog.json")
                var catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
                if scenario == "repository" { catalog["repositoryID"] = "22222222-2222-2222-2222-222222222222" }
                if scenario == "version" { catalog["version"] = 99 }
                if scenario == "digest" {
                    var artifacts = catalog["artifacts"] as! [[String: Any]]
                    artifacts[3]["lifecycle"] = "active"; catalog["artifacts"] = artifacts
                }
                try JSONSerialization.data(withJSONObject: catalog).write(to: url)
            }
            let before = try await snapshot(f.store)
            do { _ = try await RepositoryRootRelocation(store: f.store, bookmarkStore: RelocationBookmarks()).prepare(projectID: f.project, folder: candidate); XCTFail(scenario) } catch {}
            let after = try await snapshot(f.store)
            XCTAssertEqual(after, before, scenario)
        }
    }

    func testStaleDeniedAndMismatchedFreshBookmarkReject() async throws {
        for bookmarks in [RelocationBookmarks(stale: true), RelocationBookmarks(denied: true), RelocationBookmarks(mismatch: true)] {
            let f = try await fixture()
            let before = try await snapshot(f.store)
            do { _ = try await RepositoryRootRelocation(store: f.store, bookmarkStore: bookmarks).prepare(projectID: f.project, folder: f.next); XCTFail("Bad authorization accepted") } catch {}
            let after = try await snapshot(f.store)
            XCTAssertEqual(after, before)
        }
    }

    func testHandoffMismatchAmbiguityAndDestinationCollisionReject() async throws {
        for scenario in ["mismatch", "multiple", "association", "destination", "rootCollision"] {
            let f = try await fixture(handoff: true)
            try await f.store.transact(actor: .init(id: "fixture"), reason: "Conflict fixture") { c in
                switch scenario {
                case "mismatch": try c.execute("UPDATE evidence SET path = 'wrong/AGENTS.md' WHERE id = ?", bindings: [.text(ProjectGuidanceInspection.handoffEvidenceIDPrefix + "one")])
                case "multiple": try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', 'another/AGENTS.md')", bindings: [.text(ProjectGuidanceInspection.handoffEvidenceIDPrefix + "two")])
                case "association": try c.execute("UPDATE evidence SET ticket_id = 't' WHERE id = ?", bindings: [.text(ProjectGuidanceInspection.handoffEvidenceIDPrefix + "one")])
                case "destination": try c.execute("INSERT INTO evidence (id, project_id, path) VALUES ('collision', 'p', ?)", bindings: [.text(f.next.appendingPathComponent("AGENTS.md").path)])
                default:
                    try c.execute("INSERT INTO projects (id, name) VALUES ('other', 'Other')")
                    try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('collision', 'other', ?)", bindings: [.text(f.next.path)])
                }
            }
            let before = try await snapshot(f.store)
            do { _ = try await RepositoryRootRelocation(store: f.store, bookmarkStore: RelocationBookmarks()).prepare(projectID: f.project, folder: f.next); XCTFail(scenario) } catch {}
            let after = try await snapshot(f.store)
            XCTAssertEqual(after, before, scenario)
        }
    }

    func testChangedPreparedHandoffBindingBookmarkOrCatalogRejectAndLateFailureRollsBack() async throws {
        for scenario in ["handoff", "newHandoff", "bookmark", "binding", "catalog", "receipt", "audit"] {
            let f = try await fixture(handoff: scenario != "newHandoff")
            let service = RepositoryRootRelocation(store: f.store, bookmarkStore: RelocationBookmarks())
            let prepared = try await service.prepare(projectID: f.project, folder: f.next)
            if scenario == "catalog" { try Data("changed".utf8).write(to: f.next.appendingPathComponent("docs/plans/evidence.md")) }
            else if scenario == "audit" {
                let connection = try SQLiteConnection(url: f.database)
                try connection.execute("CREATE TRIGGER fail_audit BEFORE INSERT ON audit_events WHEN NEW.reason = 'Relocate bound documentation repository' BEGIN SELECT RAISE(ABORT, 'fixture'); END")
            } else {
                try await f.store.transact(actor: .init(id: "fixture"), reason: "Changed preparation fixture") { c in
                    switch scenario {
                    case "handoff": try c.execute("UPDATE evidence SET ticket_id = 't' WHERE id = ?", bindings: [.text(ProjectGuidanceInspection.handoffEvidenceIDPrefix + "one")])
                    case "newHandoff": try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text(ProjectGuidanceInspection.handoffEvidenceIDPrefix + "one"), .text(f.root.appendingPathComponent("AGENTS.md").path)])
                    case "bookmark": try c.execute("UPDATE project_bookmarks SET is_stale = 1 WHERE path = ?", bindings: [.text(f.root.path)])
                    case "binding": try c.execute("UPDATE project_documentation_bindings SET root_id = 'unbound' WHERE project_id = 'p'")
                    case "receipt": try c.execute("CREATE TRIGGER fail_receipt BEFORE INSERT ON agent_command_requests BEGIN SELECT RAISE(ABORT, 'fixture'); END")
                    default: try c.execute("CREATE TRIGGER fail_audit BEFORE INSERT ON audit_events WHEN NEW.reason = 'Relocate bound documentation repository' BEGIN SELECT RAISE(ABORT, 'fixture'); END")
                    }
                }
            }
            let before = try await snapshot(f.store)
            do { _ = try await service.confirm(prepared); XCTFail(scenario) } catch {}
            let after = try await snapshot(f.store)
            XCTAssertEqual(after, before, scenario)
        }
    }

    private func snapshot(_ store: DeliveryStore) async throws -> String {
        try await store.read { c in
            var values: [String] = []
            for table in ["project_roots", "project_bookmarks", "project_documentation_bindings", "evidence", "audit_events", "agent_command_requests"] {
                var offset = 0
                while let row = try c.row("SELECT * FROM \(table) ORDER BY rowid LIMIT 1 OFFSET \(offset)") {
                    values.append(row.keys.sorted().map { "\($0)=\(row[$0]!)" }.joined(separator: "|")); offset += 1
                }
            }
            return values.joined(separator: "\n")
        }
    }

    private struct Fixture: Sendable { let store: DeliveryStore; let root: URL; let next: URL; let database: URL; let project = ProjectID(rawValue: "p") }
    private func fixture(handoff: Bool = false, uppercaseRepositoryID: Bool = false) async throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ReleaseRadar-M3C-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("old"), next = directory.appendingPathComponent("new")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        try Data("\(RepositoryDocumentContract.guidanceStartPrefix)2\(RepositoryDocumentContract.guidanceStartSuffix)\nManaged documentation\n\(RepositoryDocumentContract.guidanceEndMarker)\n".utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        if uppercaseRepositoryID {
            let url = root.appendingPathComponent("docs/catalog.json")
            var catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
            catalog["repositoryID"] = "ABCDEFAB-CDEF-ABCD-EFAB-CDEFABCDEFAB"
            try JSONSerialization.data(withJSONObject: catalog).write(to: url)
        }
        try FileManager.default.copyItem(at: root, to: next)
        let database = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: database)
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        try await store.transact(actor: .init(id: "fixture"), reason: "Fixture") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            for (id, path) in [("unbound", directory.path), ("root", root.path)] {
                try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text(id), .text(path)])
                try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)", bindings: [.text(path), .blob(Data(path.utf8))])
            }
            try c.execute("INSERT INTO project_documentation_bindings VALUES ('p', 'root', ?, ?, ?, ?)", bindings: [.text(snapshot.catalog.repositoryID.lowercased()), .integer(Int64(snapshot.version)), .text(snapshot.digest), .blob(snapshot.canonicalCatalog)])
            try c.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase', 'p', 'Phase')")
            try c.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('t', 'p', 'phase', 'Outcome', 'backlog')")
            try c.execute("INSERT INTO evidence (id, project_id, ticket_id, artifact_id, is_available) VALUES ('managed', 'p', 't', 'draft', 0)")
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('legacy', 'p', ?, 0)", bindings: [.text(root.appendingPathComponent("arbitrary.md").path)])
            if handoff { try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES (?, 'p', ?, 0)", bindings: [.text(ProjectGuidanceInspection.handoffEvidenceIDPrefix + "one"), .text(root.appendingPathComponent("AGENTS.md").path)]) }
        }
        return .init(store: store, root: root, next: next, database: database)
    }
}

struct RelocationBookmarks: ProjectBookmarkStoring {
    var stale = false
    var denied = false
    var mismatch = false
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { .init(url: URL(fileURLWithPath: mismatch ? "/mismatched" : String(decoding: bookmark, as: UTF8.self)), isStale: stale) }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        if denied { throw ProjectBookmarkError.securityScopeAccessDenied }
        return try await body(resolve(bookmark))
    }
}

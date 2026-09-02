import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ManagedDocumentationOperationsTests: XCTestCase {
    func testGuidanceUpgradeReusesExactLegacyHandoffAndReplaysFreshAudit() async throws {
        let f = try await makeFixture()
        let path = f.root.appendingPathComponent("AGENTS.md").path
        let id = "release-radar-handoff:v1:existing"
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let initial = await f.dispatcher.dispatch(envelope(f.root, .addEvidence(id: id, ticketID: nil, path: path)))
        XCTAssertNil(initial.error)
        let before = try await f.store.read { c in try ["evidence", "audit_events", "agent_command_requests", "notification_events"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") } }
        let captured = await inventory(f.store, f.root)
        let observed = try XCTUnwrap(captured)
        XCTAssertTrue(observed.isComplete)
        let exact = observed.evidence.filter { $0.evidence.ticketID == nil && $0.evidence.locator == .filePath(path) }
        XCTAssertEqual(exact.map { $0.evidence.id.rawValue }, [id])
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let request = envelope(f.root, .addEvidence(id: exact[0].evidence.id.rawValue, ticketID: nil, path: path))
        let upgraded = await f.dispatcher.dispatchDocumentationMaintenance(request)
        XCTAssertNil(upgraded.error); XCTAssertNotNil(upgraded.auditEventID)
        XCTAssertNotEqual(upgraded.auditEventID, initial.auditEventID)
        let replay = await f.dispatcher.dispatchDocumentationMaintenance(request)
        XCTAssertEqual(replay, upgraded)
        let after = try await f.store.read { c in try ["evidence", "audit_events", "agent_command_requests", "notification_events"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") } }
        XCTAssertEqual(after, [before[0], before[1]! + 1, before[2]! + 1, before[3]])
        let row = try await f.store.locatedEvidence(projectID: .init(rawValue: "p"), evidenceID: .init(rawValue: id))
        XCTAssertEqual(row?.locator, .filePath(path)); XCTAssertNil(row?.ticketID)
    }

    func testFiveTypedDocumentationCommandsDecode() throws {
        let target: [String: Any] = ["projectID": "p", "rootID": "root", "repositoryID": "11111111-1111-1111-1111-111111111111", "catalogVersion": 1, "catalogDigest": String(repeating: "a", count: 64)]
        let commands: [[String: Any]] = [
            ["bindDocumentationRepository": ["target": target]],
            ["acceptDocumentationCatalog": ["target": target, "priorCatalogVersion": 1, "priorCatalogDigest": String(repeating: "b", count: 64)]],
            ["addManagedEvidence": ["target": target, "id": "new", "artifactID": "draft"]],
            ["adoptManagedEvidence": ["target": target, "adoptions": [["evidenceID": "e", "expectedPath": "/repo/docs/plans/draft.md", "artifactID": "draft", "expectedTicketID": NSNull()]]]],
            ["relocateLegacyEvidence": ["projectID": "p", "rootID": "root", "evidenceID": "e", "expectedPath": "/old", "newPath": "new.md"]],
        ]
        for command in commands {
            let data = try JSONSerialization.data(withJSONObject: command)
            XCTAssertNoThrow(try JSONDecoder().decode(AgentCommand.self, from: data))
        }
    }

    func testLegacyCommandRejectsCataloguedV2PathWithoutMutation() async throws {
        let fixture = try await makeFixture()
        let before = try await fixture.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let result = await fixture.dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: fixture.root.path,
            reason: "Catalogued path must use managed creation", command: .addEvidence(id: "bad", ticketID: nil, path: "docs/plans/draft.md")))
        XCTAssertNotNil(result.error)
        let after = try await fixture.store.read { connection in
            [try connection.scalarInt("SELECT COUNT(*) FROM audit_events"), try connection.scalarInt("SELECT COUNT(*) FROM evidence")]
        }
        XCTAssertEqual(after, [before, 0])
    }

    func testInventoryBindAdoptReplayAndRelaunch() async throws {
        let f = try await makeFixture()
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed all evidence") { c in
            try c.execute("INSERT INTO phases (id, project_id, name) VALUES ('inactive', 'p', 'Inactive')")
            try c.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('t', 'p', 'inactive', 'Existing', 'backlog')")
            try c.execute("INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES ('e', 'p', 't', ?, 0)", bindings: [.text(f.root.appendingPathComponent("docs/plans/draft.md").path)])
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('arbitrary', 'p', ?, 1)", bindings: [.text(f.root.appendingPathComponent("arbitrary.md").path)])
        }
        let query = AgentQueryEnvelope(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: nil, rootID: nil))
        let queries = AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root))
        let before = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let unbound = await queries.dispatch(query)
        XCTAssertEqual(unbound.inventory?.projectID, "p")
        XCTAssertEqual(unbound.inventory?.rootID, "root")
        XCTAssertEqual(unbound.inventory?.evidence.count, 2)
        XCTAssertNil(unbound.inventory?.binding)
        XCTAssertEqual(unbound.inventory?.catalog.error, .bindingMissing)
        let after = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(before, after)
        let target = try target(f.root)
        let bind = envelope(f.root, .bindDocumentationRepository(target: target))
        let bound = await f.dispatcher.dispatch(bind)
        XCTAssertNil(bound.error)
        let repeated = await f.dispatcher.dispatch(bind)
        XCTAssertEqual(repeated, bound)
        let inventory = await queries.dispatch(query)
        XCTAssertTrue(inventory.inventory?.isComplete == true)
        XCTAssertEqual(inventory.inventory?.evidence.first(where: { $0.evidence.id.rawValue == "e" })?.candidateArtifactID, "draft")
        let adopt = envelope(f.root, .adoptManagedEvidence(target: target, adoptions: [.init(evidenceID: "e", expectedPath: f.root.appendingPathComponent("docs/plans/draft.md").path, expectedTicketID: "t", artifactID: "draft")]))
        let adopted = await f.dispatcher.dispatch(adopt)
        XCTAssertNil(adopted.error)
        let record = try await f.store.locatedEvidence(projectID: .init(rawValue: "p"), evidenceID: .init(rawValue: "e"))
        XCTAssertEqual(record?.locator, .managedDocument(artifactID: "draft"))
        XCTAssertEqual(record?.ticketID?.rawValue, "t")
        XCTAssertFalse(record!.isAvailable)
        let reopened = DeliveryStore(databaseURL: f.root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
        let replay = await dispatcher(reopened, f.root).dispatch(adopt)
        XCTAssertEqual(replay, adopted)
        let receipts = try await f.store.read { c in try c.row("SELECT request_body FROM agent_command_requests WHERE request_id = ?", bindings: [.text(adopt.requestID.uuidString)]) }
        guard case let .blob(bytes) = receipts?["request_body"] else { return XCTFail("Receipt missing") }
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains(f.root.path))
    }

    func testStaleCatalogAndChangedAssociationRejectAtomicSet() async throws {
        let f = try await makeFixture()
        let target = try target(f.root)
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(bound.error)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed") { c in
            for (id, path) in [("a", "docs/plans/draft.md"), ("b", "docs/plans/current.md")] {
                try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text(id), .text(f.root.appendingPathComponent(path).path)])
            }
        }
        let before = await AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root)).dispatch(.init(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: "p", rootID: "root")))
        let bad = await f.dispatcher.dispatch(envelope(f.root, .adoptManagedEvidence(target: target, adoptions: [
            .init(evidenceID: "a", expectedPath: f.root.appendingPathComponent("docs/plans/draft.md").path, expectedTicketID: nil, artifactID: "draft"),
            .init(evidenceID: "b", expectedPath: f.root.appendingPathComponent("docs/plans/current.md").path, expectedTicketID: "changed", artifactID: "current")
        ])))
        XCTAssertNotNil(bad.error)
        let after = await AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root)).dispatch(.init(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: "p", rootID: "root")))
        XCTAssertEqual(after.inventory, before.inventory)
    }

    func testManagedV2ImporterFailsBeforeDeliveryMutationWhenCatalogIsUnavailable() async throws {
        let f = try await makeFixture()
        let delivery = f.root.appendingPathComponent("docs/delivery")
        try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
        let seed = #"{"schemaVersion":1,"activePhaseId":"phase","phases":[{"id":"phase","label":"Imported"}],"tasks":[]}"#
        try Data(seed.utf8).write(to: delivery.appendingPathComponent("dashboard-status.json"))
        let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]))
        let before = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        do {
            let preview = try importer.preview(f.root)
            try await importer.apply(preview, to: .init(rawValue: "p"))
            XCTFail("Unavailable managed catalog must reject before import")
        } catch { }
        let after = try await f.store.read { c in [try c.scalarInt("SELECT COUNT(*) FROM audit_events"), try c.scalarInt("SELECT COUNT(*) FROM phases")] }
        XCTAssertEqual(after, [before, 0])
    }

    func testEveryDocumentationMutationReplaysAndRejectsRequestReuseAcrossRelaunch() async throws {
        for kind in 0..<5 {
            let f = try await makeFixture()
            let command = try await preparedCommand(kind, fixture: f)
            let request = envelope(f.root, command)
            let result = await f.dispatcher.dispatch(request)
            XCTAssertNil(result.error, "kind \(kind)")
            let before = await inventory(f.store, f.root)
            let reopened = DeliveryStore(databaseURL: f.root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
            let replayed = await dispatcher(reopened, f.root).dispatch(request)
            XCTAssertEqual(replayed, result)
            let changed = AgentCommandEnvelope(version: 1, requestID: request.requestID, projectRoot: f.root.path, reason: "Changed request body", command: command)
            let rejected = await dispatcher(reopened, f.root).dispatch(changed)
            XCTAssertEqual(rejected.error, .requestIDReused)
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before)
        }
    }

    func testEveryDocumentationMutationRollsBackAfterLateReceiptFailure() async throws {
        for kind in 0..<5 {
            let f = try await makeFixture()
            let command = try await preparedCommand(kind, fixture: f)
            try await f.store.transact(actor: .init(id: "fixture"), reason: "Inject late receipt failure") { c in
                try c.execute("CREATE TRIGGER m3b_fail_receipt BEFORE INSERT ON agent_command_requests BEGIN SELECT RAISE(ABORT, 'Injected receipt failure'); END")
            }
            let before = await inventory(f.store, f.root)
            let result = await f.dispatcher.dispatch(envelope(f.root, command))
            XCTAssertNotNil(result.error, "kind \(kind)")
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before, "kind \(kind)")
        }
    }

    func testPendingAndInvalidCatalogRetainBindingWithoutResolvingRows() async throws {
        let f = try await makeFixture()
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        _ = await f.dispatcher.dispatch(envelope(f.root, .addManagedEvidence(target: try target(f.root), id: "managed", ticketID: nil, artifactID: "draft")))
        let accepted = await inventory(f.store, f.root)
        try editCatalog(f.root) { catalog in
            var items = catalog["artifacts"] as! [[String: Any]]
            items[3]["lifecycle"] = "active"; catalog["artifacts"] = items
        }
        let pending = await inventory(f.store, f.root)
        XCTAssertEqual(pending?.binding, accepted?.binding)
        XCTAssertEqual(pending?.catalog.error, .catalogUnaccepted)
        XCTAssertNil(pending?.evidence.first?.resolvedPath)
        XCTAssertFalse(pending!.isComplete)
        let target = try target(f.root)
        let stale = await f.dispatcher.dispatch(envelope(f.root, .addManagedEvidence(target: target, id: "blocked", ticketID: nil, artifactID: "current")))
        XCTAssertEqual(stale.error, .documentation(.catalogUnaccepted))
        try Data("{bad".utf8).write(to: f.root.appendingPathComponent("docs/catalog.json"))
        let invalid = await inventory(f.store, f.root)
        XCTAssertEqual(invalid?.binding, accepted?.binding)
        XCTAssertEqual(invalid?.catalog.error, .catalogInvalid)
        XCTAssertNil(invalid?.evidence.first?.resolvedPath)
    }

    func testExactCandidateClassificationRejectsAliasesMissingAndOutsidePaths() async throws {
        let f = try await makeFixture()
        try Data("arbitrary".utf8).write(to: f.root.appendingPathComponent("arbitrary.md"))
        try FileManager.default.createSymbolicLink(at: f.root.appendingPathComponent("alias.md"), withDestinationURL: f.root.appendingPathComponent("docs/plans/draft.md"))
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed classification") { c in
            for (id, path) in [("exact", "docs/plans/draft.md"), ("arbitrary", "arbitrary.md"), ("missing", "missing.md"), ("alias", "alias.md"), ("basename", "draft.md")] {
                try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text(id), .text(f.root.appendingPathComponent(path).path)])
            }
            try c.execute("INSERT INTO evidence (id, project_id, path) VALUES ('outside', 'p', '/outside/draft.md')")
        }
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        let result = await inventory(f.store, f.root)
        XCTAssertEqual(result?.evidence.count, 6)
        XCTAssertEqual(result?.evidence.filter { $0.candidateArtifactID != nil }.map { $0.evidence.id.rawValue }, ["exact"])
        XCTAssertEqual(result?.evidence.first { $0.evidence.id.rawValue == "alias" }?.rejection, .unsafePath)
        XCTAssertEqual(result?.evidence.first { $0.evidence.id.rawValue == "missing" }?.rejection, .missingFile)
    }

    func testBoundsRejectWholeRequestAndOversizedInventory() async throws {
        let f = try await makeFixture()
        let target = try target(f.root)
        for count in [0, 129] {
            let items = (0..<count).map { DocumentationAdoption(evidenceID: "e\($0)", expectedPath: "x", expectedTicketID: nil, artifactID: "a\($0)") }
            let result = await f.dispatcher.dispatch(envelope(f.root, .adoptManagedEvidence(target: target, adoptions: items)))
            XCTAssertNotNil(result.error)
        }
        let large = (0..<30).map { DocumentationAdoption(evidenceID: "e\($0)", expectedPath: String(repeating: "x", count: 4000), expectedTicketID: nil, artifactID: "a\($0)") }
        let tooManyBytes = await f.dispatcher.dispatch(envelope(f.root, .adoptManagedEvidence(target: target, adoptions: large)))
        XCTAssertNotNil(tooManyBytes.error)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed bounded inventory limit") { c in
            for index in 0..<100 {
                try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text("e\(index)"), .text(f.root.path + "/" + String(repeating: "x", count: 1500) + String(index))])
            }
        }
        let query = await AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root)).dispatch(.init(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: nil, rootID: nil)))
        XCTAssertEqual(query.error, .documentation(.inventoryTooLarge))
        XCTAssertNil(query.inventory)
    }

    func testBindingUsesLowercaseUUIDAndRejectsRootAndProjectCollisions() async throws {
        let f = try await makeFixture()
        try editCatalog(f.root) { $0["repositoryID"] = ($0["repositoryID"] as! String).uppercased() }
        let observedInventory = await inventory(f.store, f.root)
        let observed = try XCTUnwrap(observedInventory)
        let t = DocumentationTarget(projectID: observed.projectID, rootID: observed.rootID, repositoryID: try XCTUnwrap(observed.catalog.repositoryID), catalogVersion: try XCTUnwrap(observed.catalog.version), catalogDigest: try XCTUnwrap(observed.catalog.digest))
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
        XCTAssertNil(bound.error)
        let result = await inventory(f.store, f.root)
        XCTAssertEqual(result?.binding?.repositoryID, t.repositoryID)
        XCTAssertTrue(result!.isComplete)
        let other = DocumentationTarget(projectID: "other", rootID: "root", repositoryID: t.repositoryID, catalogVersion: t.catalogVersion, catalogDigest: t.catalogDigest)
        let rejected = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: other)))
        XCTAssertEqual(rejected.error, .documentation(.rootMismatch))
    }

    func testManagedImporterRequiresAcceptedBindingAndClassifiesOnlyExactDocuments() async throws {
        let f = try await makeFixture()
        try prepareImportTree(f.root)
        let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]), bookmarkStore: bookmarks(f.root))
        let preview = try importer.preview(f.root)
        XCTAssertNotNil(preview.documentationCatalogDigest)
        do { try await importer.apply(preview, to: .init(rawValue: "p")); XCTFail("Unbound import must reject") }
        catch { XCTAssertEqual(error as? RekonImportError, .documentation(.bindingMissing)) }
        let empty = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM phases") }
        XCTAssertEqual(empty, 0)
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        XCTAssertNil(bound.error)
        try await importer.apply(preview, to: .init(rawValue: "p"))
        let rows = try await f.store.read { try $0.rows("SELECT ticket_id, path, artifact_id FROM evidence ORDER BY ticket_id") }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["artifact_id"], .text("draft"))
        XCTAssertEqual(rows[0]["path"], .null)
        XCTAssertEqual(rows[1]["artifact_id"], .null)
        XCTAssertEqual(rows[1]["path"], .text(f.root.appendingPathComponent("arbitrary.md").path))
        let before = await inventory(f.store, f.root)
        try editCatalog(f.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts[3]["lifecycle"] = "active"; catalog["artifacts"] = artifacts
        }
        let pendingPreview = try importer.preview(f.root)
        do { try await importer.apply(pendingPreview, to: .init(rawValue: "p")); XCTFail("Pending import must reject") }
        catch { XCTAssertEqual(error as? RekonImportError, .documentation(.catalogUnaccepted)) }
        let after = await inventory(f.store, f.root)
        XCTAssertEqual(after?.preservation, before?.preservation)
        XCTAssertEqual(after?.audits, before?.audits)
    }

    func testStagedV1ImporterRetainsLegacyIdentityAndLegacyArbitraryCommandIsCompatible() async throws {
        let f = try await makeFixture()
        try prepareImportTree(f.root)
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]))
        let preview = try importer.preview(f.root)
        XCTAssertNil(preview.documentationCatalogDigest)
        try await importer.apply(preview, to: .init(rawValue: "p"))
        let managed = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM evidence WHERE artifact_id IS NOT NULL") }
        XCTAssertEqual(managed, 0)
        let arbitrary = f.root.appendingPathComponent("other%file.md")
        try Data("arbitrary".utf8).write(to: arbitrary)
        let result = await f.dispatcher.dispatch(envelope(f.root, .addEvidence(id: "other", ticketID: nil, path: arbitrary.path)))
        XCTAssertNil(result.error)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let underV2 = await f.dispatcher.dispatch(envelope(f.root, .addEvidence(id: "other", ticketID: nil, path: arbitrary.path)))
        XCTAssertNil(underV2.error)
    }

    func testGuidanceDeclarationRejectsMalformedUnknownAndDuplicateMarkers() {
        let prefix = RepositoryDocumentContract.guidanceStartPrefix
        let suffix = RepositoryDocumentContract.guidanceStartSuffix
        let end = RepositoryDocumentContract.guidanceEndMarker
        XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: nil), .legacy)
        XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: RepositoryDocumentContract.legacyManagedGuidanceBlock), .legacy)
        for contents in ["\(prefix)3\(suffix)\n\(end)", "\(prefix)2\(suffix)", "\(prefix)2\(suffix)\n\(end)\n\(end)", " \(prefix)2\(suffix)\n\(end)"] {
            XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: contents), .unavailable)
        }
    }

    func testCatalogAcceptanceRejectsStalePriorAndIllegalLifecycleWithoutEffects() async throws {
        let f = try await makeFixture()
        let accepted = try target(f.root)
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: accepted)))
        try editCatalog(f.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts[3]["lifecycle"] = "archived"; artifacts[3]["authorityLevel"] = "nonAuthoritative"; catalog["artifacts"] = artifacts
        }
        // Remove an active prose link to the now historical fixture artifact.
        try Data("# Current\n".utf8).write(to: f.root.appendingPathComponent("docs/plans/current.md"))
        let candidate = try target(f.root)
        let before = await inventory(f.store, f.root)
        let illegal = await f.dispatcher.dispatch(envelope(f.root, .acceptDocumentationCatalog(target: candidate, priorCatalogVersion: 1, priorCatalogDigest: accepted.catalogDigest)))
        XCTAssertEqual(illegal.error, .documentation(.invalidTransition))
        let stale = await f.dispatcher.dispatch(envelope(f.root, .acceptDocumentationCatalog(target: candidate, priorCatalogVersion: 1, priorCatalogDigest: String(repeating: "0", count: 64))))
        XCTAssertEqual(stale.error, .documentation(.catalogUnaccepted))
        let after = await inventory(f.store, f.root)
        XCTAssertEqual(after, before)
    }

    func testAuthorizationFailuresAndCrossProjectRepositoryCollisionAreZeroEffect() async throws {
        let f = try await makeFixture()
        let t = try target(f.root)
        for stale in [false, true] {
            let denied = ProjectBookmarkStore(resolver: { _ in .init(url: f.root, isStale: stale) }, startAccessing: { _ in stale }, stopAccessing: { _ in })
            let badDispatcher = AgentCommandDispatcher(store: f.store, projectRegistry: PersistedAuthorizedProjectRegistry(store: f.store), bookmarkStore: denied)
            let result = await badDispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
            XCTAssertEqual(result.error, .documentation(stale ? .staleRoot : .rootUnavailable))
        }
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
        let other = f.root.deletingLastPathComponent().appendingPathComponent("other")
        try FileManager.default.copyItem(at: f.root, to: other)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Second authorized project") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('other', 'Other')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('other-root', 'other', ?)", bindings: [.text(other.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('other', ?, ?)", bindings: [.text(other.path), .blob(Data([1]))])
        }
        let second = AgentCommandDispatcher(store: f.store, projectRegistry: PersistedAuthorizedProjectRegistry(store: f.store), bookmarkStore: bookmarks(other))
        let collision = DocumentationTarget(projectID: "other", rootID: "other-root", repositoryID: t.repositoryID, catalogVersion: t.catalogVersion, catalogDigest: t.catalogDigest)
        let result = await second.dispatch(envelope(other, .bindDocumentationRepository(target: collision)))
        XCTAssertEqual(result.error, .documentation(.bindingConflict))
        let count = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings") }
        XCTAssertEqual(count, 1)
    }

    func testManagedEvidenceCannotRelocateAndReplayDoesNotConsumeLaterCatalog() async throws {
        let f = try await makeFixture()
        let t = try target(f.root)
        let bindRequest = envelope(f.root, .bindDocumentationRepository(target: t))
        let bound = await f.dispatcher.dispatch(bindRequest)
        let created = await f.dispatcher.dispatch(envelope(f.root, .addManagedEvidence(target: t, id: "managed", ticketID: nil, artifactID: "draft")))
        XCTAssertNil(created.error)
        try Data("arbitrary".utf8).write(to: f.root.appendingPathComponent("arbitrary.md"))
        let relocated = await f.dispatcher.dispatch(envelope(f.root, .relocateLegacyEvidence(projectID: "p", rootID: "root", evidenceID: "managed", expectedPath: f.root.appendingPathComponent("docs/plans/draft.md").path, newPath: "arbitrary.md")))
        XCTAssertEqual(relocated.error, .documentation(.staleEvidence))
        try Data("bad catalog".utf8).write(to: f.root.appendingPathComponent("docs/catalog.json"))
        let replay = await f.dispatcher.dispatch(bindRequest)
        XCTAssertEqual(replay, bound)
    }

    func testSavedV1PreviewRejectsAfterV2ActivationForUnboundAcceptedAndPendingRoots() async throws {
        for state in ["unbound", "accepted", "pending"] {
            let f = try await makeFixture()
            try prepareImportTree(f.root)
            try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
            let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]), bookmarkStore: bookmarks(f.root))
            let v1 = try importer.preview(f.root)
            XCTAssertNil(v1.documentationCatalogDigest)
            try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
            if state != "unbound" { _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root)))) }
            if state == "pending" {
                try editCatalog(f.root) { catalog in
                    var artifacts = catalog["artifacts"] as! [[String: Any]]
                    artifacts[3]["lifecycle"] = "active"; catalog["artifacts"] = artifacts
                }
            }
            let before = await inventory(f.store, f.root)
            do { try await importer.apply(v1, to: .init(rawValue: "p")); XCTFail("Saved v1 preview applied under v2 \(state)") }
            catch { XCTAssertEqual(error as? RekonImportError, .malformedArtifact) }
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before, state)
        }
    }

    func testPreservationIncludesUnattributedHistoricalNotifications() async throws {
        let f = try await makeFixture()
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed historical notification") { c in
            try c.execute("INSERT INTO notification_events (id, fingerprint, state, project_id) VALUES ('historical', 'historical', 'sent', NULL)")
        }
        let before = await inventory(f.store, f.root)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Change historical notification") { c in
            try c.execute("UPDATE notification_events SET state = 'unknown' WHERE id = 'historical'")
        }
        let after = await inventory(f.store, f.root)
        XCTAssertNotEqual(after?.preservation["other.deliveryV10"], before?.preservation["other.deliveryV10"])
        XCTAssertEqual(after?.preservation["project.deliveryV10"], before?.preservation["project.deliveryV10"])
    }

    private func prepareImportTree(_ root: URL) throws {
        let delivery = root.appendingPathComponent("docs/delivery")
        try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
        let seed = #"{"schemaVersion":1,"activePhaseId":"phase","phases":[{"id":"phase","label":"Imported"}],"tasks":[{"id":"t1","title":"Managed","phaseId":"phase","status":"backlog","evidence":{"href":"../../plans/draft.md"}},{"id":"t2","title":"Arbitrary","phaseId":"phase","status":"backlog","evidence":{"href":"../../../arbitrary.md"}}]}"#
        try Data(seed.utf8).write(to: delivery.appendingPathComponent("dashboard-status.json"))
        try Data("arbitrary".utf8).write(to: root.appendingPathComponent("arbitrary.md"))
        try editCatalog(root) { catalog in
            var collections = catalog["collections"] as! [[String: Any]]
            collections.append(["collectionID": "delivery", "path": "docs/delivery", "parentCollection": "docs", "purpose": "Delivery", "allowedContents": ["seed"], "prohibitedContents": ["temp"], "firstRead": "seed", "isLeaf": true])
            catalog["collections"] = collections
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts.append(["artifactID": "seed", "path": "docs/delivery/dashboard-status.json", "kind": "document", "lifecycle": "active", "authorityLevel": "supporting", "parentCollection": "delivery", "supersedes": [], "applicationSensitivity": ["importer"], "checksum": ["policy": "notApplicable"]])
            catalog["artifacts"] = artifacts
        }
        _ = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
    }

    private func inventory(_ store: DeliveryStore, _ root: URL) async -> EvidenceInventory? {
        await AgentQueryDispatcher(store: store, bookmarkStore: bookmarks(root)).dispatch(.init(version: 1, projectRoot: root.path, query: .inventoryEvidence(projectID: nil, rootID: nil))).inventory
    }
    private func preparedCommand(_ kind: Int, fixture f: (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher)) async throws -> AgentCommand {
        let t = try target(f.root)
        if kind == 0 { return .bindDocumentationRepository(target: t) }
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
        XCTAssertNil(bound.error)
        if kind == 1 {
            try editCatalog(f.root) { catalog in
                var items = catalog["artifacts"] as! [[String: Any]]
                items[3]["lifecycle"] = "active"; catalog["artifacts"] = items
            }
            return .acceptDocumentationCatalog(target: try target(f.root), priorCatalogVersion: t.catalogVersion, priorCatalogDigest: t.catalogDigest)
        }
        if kind == 2 { return .addManagedEvidence(target: t, id: "new", ticketID: nil, artifactID: "draft") }
        let old = f.root.appendingPathComponent("docs/plans/draft.md").path
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed exact evidence") { c in
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('e', 'p', ?, 0)", bindings: [.text(old)])
        }
        if kind == 3 { return .adoptManagedEvidence(target: t, adoptions: [.init(evidenceID: "e", expectedPath: old, expectedTicketID: nil, artifactID: "draft")]) }
        try Data("arbitrary".utf8).write(to: f.root.appendingPathComponent("arbitrary.md"))
        return .relocateLegacyEvidence(projectID: "p", rootID: "root", evidenceID: "e", expectedPath: old, newPath: "arbitrary.md")
    }
    private func editCatalog(_ root: URL, mutate: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent("docs/catalog.json")
        var catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&catalog)
        try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys]).write(to: url)
    }

    private func target(_ root: URL) throws -> DocumentationTarget {
        let s = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        return .init(projectID: "p", rootID: "root", repositoryID: s.catalog.repositoryID.lowercased(), catalogVersion: s.version, catalogDigest: s.digest)
    }
    private func envelope(_ root: URL, _ command: AgentCommand, requestID: UUID = UUID()) -> AgentCommandEnvelope {
        .init(version: 1, requestID: requestID, projectRoot: root.path, reason: "Approved documentation operation", command: command)
    }
    private func bookmarks(_ root: URL) -> ProjectBookmarkStore {
        ProjectBookmarkStore(resolver: { _ in .init(url: root, isStale: false) }, startAccessing: { _ in true }, stopAccessing: { _ in })
    }
    private func dispatcher(_ store: DeliveryStore, _ root: URL) -> AgentCommandDispatcher {
        AgentCommandDispatcher(store: store, projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [.init(projectID: .init(rawValue: "p"), canonicalRoot: root, authorizedRoots: [root])]), bookmarkStore: bookmarks(root))
    }

    private func makeFixture() async throws -> (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher) {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ReleaseRadar-M3B-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("repository")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        let block = RepositoryDocumentContract.managedGuidanceBlock
        try Data(block.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed authorized project") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'p', ?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)", bindings: [.text(root.path), .blob(Data([1]))])
        }
        let registry = InMemoryAuthorizedProjectRegistry(projects: [.init(projectID: .init(rawValue: "p"), canonicalRoot: root, authorizedRoots: [root])])
        return (store, root, AgentCommandDispatcher(store: store, projectRegistry: registry, bookmarkStore: bookmarks(root)))
    }
}

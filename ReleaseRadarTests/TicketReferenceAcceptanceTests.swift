import Foundation
import CryptoKit
import XCTest
@testable import ReleaseRadarCore

final class TicketReferenceAcceptanceTests: XCTestCase {
    func testCurrentStoreCreatesEmptyReferenceTablesWithoutInferringLinks() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-reference-\(UUID().uuidString).sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await store.availability else {
            return XCTFail("Expected the synthetic store to be available")
        }

        try await store.transact(
            actor: .init(id: "reference-test"),
            reason: "Seed an unrelated ticket",
            auditEventID: .init(rawValue: "audit-seed-reference-test"),
            auditScope: .init(projectID: .init(rawValue: "project"), entityType: .project, entityID: "project")
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project', 'Project')")
            try connection.execute("INSERT INTO tickets (id, project_id, outcome) VALUES ('ticket', 'project', 'Outcome')")
        }

        let connection = try SQLiteConnection(url: databaseURL)
        XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 23)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_link_sets"), 0)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_links"), 0)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_versions"), 0)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_reference_links"), 0)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_reference_versions"), 0)
        XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
    }

    func testReferenceWriterRejectsCompletedTicketBeforeReadingOrWritingSource() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(
            envelope(fixture.root, .bindDocumentationRepository(target: target))
        )
        XCTAssertNil(binding.error)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Complete reference owner") { connection in
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='completed',revision=1,completion_baseline_digest='fixture-baseline',completed_at='2026-09-10T00:00:00Z' WHERE project_id='p' AND phase_id='phase'")
        }
        let result = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: target,
                ticketID: "placed",
                linkID: "blocked-reference",
                kind: .requirement,
                artifactID: "current",
                sourceLocalID: "REQ-BLOCKED",
                locator: "Must reopen",
                expectedContentDigest: try sourceDigest(fixture.root),
                expectedLinkSetRevision: 0
            )
        ))

        XCTAssertEqual(result.error, .completedPhaseReadOnly(.init(rawValue: "phase")))
        let count = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM ticket_reference_links WHERE project_id='p'")
        }
        XCTAssertEqual(count, 0)
    }

    func testTypedReferenceCommandsCaptureExactBytesRevisePlaceReplayAndRetireWithoutSource() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(fixture.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(binding.error)

        let source = fixture.root.appendingPathComponent("docs/plans/current.md")
        let initialBytes = try Data(contentsOf: source)
        let initialDigest = SHA256.hash(data: initialBytes).map { String(format: "%02x", $0) }.joined()
        let createRequestID = UUID()
        let create = envelope(
            fixture.root,
            .upsertTicketReference(
                target: target,
                ticketID: "unassigned",
                linkID: "requirement-main",
                kind: .requirement,
                artifactID: "current",
                sourceLocalID: "REQ-1",
                locator: "Acceptance criteria",
                expectedContentDigest: initialDigest,
                expectedLinkSetRevision: 0
            ),
            requestID: createRequestID
        )
        let created = await fixture.dispatcher.dispatch(create)
        XCTAssertNil(created.error)
        XCTAssertEqual(created.ticketReferenceLinkSetRevision, 1)
        let replay = await fixture.dispatcher.dispatch(create)
        XCTAssertEqual(replay, created)
        let storedRequest = try await fixture.store.read { connection in
            try connection.row(
                "SELECT request_body FROM agent_command_requests WHERE request_id = ?",
                bindings: [.text(createRequestID.uuidString)]
            )
        }
        guard case let .blob(storedRequestBytes)? = storedRequest?["request_body"] else {
            return XCTFail("Expected a complete retained request body")
        }
        let storedRequestObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: storedRequestBytes) as? [String: Any]
        )
        XCTAssertEqual(storedRequestObject["version"] as? Int, create.version)
        XCTAssertEqual(storedRequestObject["projectRoot"] as? String, create.projectRoot)
        XCTAssertEqual(storedRequestObject["reason"] as? String, create.reason)
        let storedCommandBytes = try JSONSerialization.data(withJSONObject: try XCTUnwrap(storedRequestObject["command"]))
        XCTAssertEqual(try JSONDecoder().decode(AgentCommand.self, from: storedCommandBytes), create.command)
        let conflictingReplay = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: target, ticketID: "unassigned", linkID: "requirement-main",
                kind: .requirement, artifactID: "current", sourceLocalID: "REQ-1",
                locator: "Conflicting replay", expectedContentDigest: initialDigest,
                expectedLinkSetRevision: 1
            ),
            requestID: createRequestID
        ))
        XCTAssertEqual(conflictingReplay.error, .requestIDReused)

        let sharedBytes = Data("Shared authoritative requirements\n".utf8)
        try sharedBytes.write(to: source)
        let second = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: target,
                ticketID: "placed",
                linkID: "decision-shared",
                kind: .decision,
                artifactID: "current",
                sourceLocalID: "ADR-SHARED",
                locator: nil,
                expectedContentDigest: documentationDigest(sharedBytes),
                expectedLinkSetRevision: 0
            )
        ))
        XCTAssertEqual(second.ticketReferenceLinkSetRevision, 1)
        let queries = AgentQueryDispatcher(
            store: fixture.store,
            bookmarkStore: ProjectBookmarkStore(
                resolver: { _ in .init(url: fixture.root, isStale: false) },
                startAccessing: { _ in true },
                stopAccessing: { _ in }
            )
        )
        let sharedImpacts = await queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .recordedImpacts(
                projectID: "p", rootID: "root",
                repositoryID: target.repositoryID, artifactID: "current"
            )
        ))
        XCTAssertEqual(sharedImpacts.recordedImpacts?.rows.map(\.ticketID), ["placed", "unassigned"])
        XCTAssertEqual(sharedImpacts.recordedImpacts?.rows.map(\.phaseLabel), ["Phase", "Not placed"])
        XCTAssertEqual(
            sharedImpacts.recordedImpacts?.rows.map(\.contentDigest),
            [documentationDigest(sharedBytes), initialDigest]
        )

        let first = try await fixture.store.read { connection in
            try connection.row("SELECT * FROM ticket_reference_versions WHERE link_id = 'requirement-main' AND version = 1")
        }
        XCTAssertEqual(first?["content_digest"], .text(initialDigest))
        XCTAssertEqual(first?["observed_path"], .text("docs/plans/current.md"))
        XCTAssertEqual(first?["observed_lifecycle"], .text("active"))
        XCTAssertEqual(first?["observed_authority"], .text("controlling"))

        let placed = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .placeUnassignedTicket(ticketID: "unassigned", phaseID: "phase", expectedPlanRevision: 0)
        ))
        XCTAssertNil(placed.error)
        let placedLinkCount = try await fixture.store.read { try $0.scalarInt("SELECT COUNT(*) FROM ticket_reference_links WHERE ticket_id = 'unassigned'") }
        XCTAssertEqual(placedLinkCount, 1)

        let revisedBytes = Data("Revised authoritative requirements\n".utf8)
        try revisedBytes.write(to: source)
        let revised = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: target,
                ticketID: "unassigned",
                linkID: "requirement-main",
                kind: .requirement,
                artifactID: "current",
                sourceLocalID: "REQ-1",
                locator: "Revised acceptance criteria",
                expectedContentDigest: documentationDigest(revisedBytes),
                expectedLinkSetRevision: 1
            )
        ))
        XCTAssertNil(revised.error)
        XCTAssertEqual(revised.ticketReferenceLinkSetRevision, 2)
        let versionCount = try await fixture.store.read { try $0.scalarInt("SELECT COUNT(*) FROM ticket_reference_versions WHERE link_id = 'requirement-main'") }
        XCTAssertEqual(versionCount, 2)

        try FileManager.default.removeItem(at: source)
        let retired = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .retireTicketReference(
                projectID: "p",
                rootID: "root",
                ticketID: "unassigned",
                linkID: "requirement-main",
                version: 2,
                expectedLinkSetRevision: 2
            )
        ))
        XCTAssertNil(retired.error)
        XCTAssertEqual(retired.ticketReferenceLinkSetRevision, 3)
        let relationship = try await fixture.store.read { try $0.scalarText("SELECT relationship FROM ticket_reference_links WHERE id = 'requirement-main'") }
        XCTAssertEqual(relationship, "retired")

        let lifecycle = ProjectLifecycleManager(store: fixture.store)
        _ = try await lifecycle.apply(try await lifecycle.preview(projectID: .init(rawValue: "p"), transition: .archive))
        _ = try await lifecycle.apply(try await lifecycle.preview(projectID: .init(rawValue: "p"), transition: .restore))
        let databaseURL = fixture.store.databaseURL
        await fixture.store.close()
        let relaunched = DeliveryStore(databaseURL: databaseURL)
        let retainedAfterRelaunch = try await relaunched.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_links WHERE project_id = 'p'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_versions WHERE project_id = 'p'"),
                try connection.scalarText("SELECT relationship FROM ticket_reference_links WHERE id = 'requirement-main'")
            )
        }
        XCTAssertEqual(retainedAfterRelaunch.0, 2)
        XCTAssertEqual(retainedAfterRelaunch.1, 3)
        XCTAssertEqual(retainedAfterRelaunch.2, "retired")
        await relaunched.close()
    }

    func testReferenceMutationRejectsStaleRevisionNonControllingSourceAndAcceptedTicket() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(fixture.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(binding.error)

        let proposed = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(target: target, ticketID: "unassigned", linkID: "bad", kind: .decision,
                                   artifactID: "draft", sourceLocalID: nil, locator: nil,
                                   expectedContentDigest: try sourceDigest(fixture.root, artifactID: "draft"),
                                   expectedLinkSetRevision: 0)
        ))
        XCTAssertEqual(proposed.error, .ticketReferenceSourceNotAuthoritative)

        let created = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(target: target, ticketID: "accepted", linkID: "accepted-link", kind: .decision,
                                   artifactID: "current", sourceLocalID: nil, locator: nil,
                                   expectedContentDigest: try sourceDigest(fixture.root), expectedLinkSetRevision: 0)
        ))
        XCTAssertEqual(created.error, .ticketReferenceTicketAccepted)

        let stale = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .retireTicketReference(projectID: "p", rootID: "root", ticketID: "unassigned",
                                   linkID: "missing", version: 1, expectedLinkSetRevision: 1)
        ))
        XCTAssertEqual(stale.error, .ticketReferenceLinkSetRevisionConflict(expected: 1, current: 0))
    }

    func testUnsafeSourceAndRegistrationMismatchLeaveNoReferenceAuditOrReceipt() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(
            fixture.root, .bindDocumentationRepository(target: target)
        ))
        XCTAssertNil(binding.error)
        let countsBefore = try await referenceMutationCounts(fixture.store)

        let current = fixture.root.appendingPathComponent("docs/plans/current.md")
        try FileManager.default.removeItem(at: current)
        try FileManager.default.createSymbolicLink(
            at: current,
            withDestinationURL: fixture.root.appendingPathComponent("docs/plans/draft.md")
        )
        let unsafe = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: target, ticketID: "unassigned", linkID: "unsafe",
                kind: .requirement, artifactID: "current", sourceLocalID: nil,
                locator: nil, expectedContentDigest: String(repeating: "0", count: 64),
                expectedLinkSetRevision: 0
            )
        ))
        XCTAssertNotNil(unsafe.error)
        let countsAfterUnsafe = try await referenceMutationCounts(fixture.store)
        XCTAssertEqual(countsAfterUnsafe, countsBefore)

        let staleRegistration = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            expectedRegistration: .init(
                projectID: .init(rawValue: "p"),
                registrationID: "wrong-registration",
                requestGeneration: 1
            ),
            reason: "Reject stale reference registration",
            command: .retireTicketReference(
                projectID: "p", rootID: "root", ticketID: "unassigned",
                linkID: "missing", version: 1, expectedLinkSetRevision: 0
            )
        )
        let stale = await fixture.dispatcher.dispatch(staleRegistration)
        XCTAssertEqual(stale.error, .staleProjectRegistration)
        let countsAfterStale = try await referenceMutationCounts(fixture.store)
        XCTAssertEqual(countsAfterStale, countsBefore)
    }

    func testReferenceMutationRejectsBytesChangedAfterReviewWithoutSideEffects() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(
            envelope(fixture.root, .bindDocumentationRepository(target: target))
        )
        XCTAssertNil(bound.error)
        let reviewedDigest = try sourceDigest(fixture.root)
        try Data("Changed after caller review\n".utf8).write(
            to: fixture.root.appendingPathComponent("docs/plans/current.md")
        )
        let before = try await referenceMutationCounts(fixture.store)

        let result = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: target,
                ticketID: "unassigned",
                linkID: "stale-bytes",
                kind: .requirement,
                artifactID: "current",
                sourceLocalID: "REQ-STALE",
                locator: nil,
                expectedContentDigest: reviewedDigest,
                expectedLinkSetRevision: 0
            )
        ))

        XCTAssertEqual(result.error, .documentation(.staleEvidence))
        let after = try await referenceMutationCounts(fixture.store)
        XCTAssertEqual(after, before)
    }

    func testReadOnlyTicketHistoryAndRecordedImpactsExposeCurrentAndHistoricalFacts() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(fixture.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(binding.error)
        let initial = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(target: target, ticketID: "unassigned", linkID: "requirement-main",
                                   kind: .requirement, artifactID: "current", sourceLocalID: "REQ-1",
                                   locator: "Acceptance criteria",
                                   expectedContentDigest: try sourceDigest(fixture.root), expectedLinkSetRevision: 0)
        ))
        XCTAssertNil(initial.error)

        let queries = AgentQueryDispatcher(
            store: fixture.store,
            bookmarkStore: ProjectBookmarkStore(
                resolver: { _ in .init(url: fixture.root, isStale: false) },
                startAccessing: { _ in true },
                stopAccessing: { _ in }
            )
        )
        let currentResult = await queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "unassigned")
        ))
        let current = try XCTUnwrap(currentResult.ticketReferences)
        XCTAssertEqual(current.phaseLabel, "Not placed")
        XCTAssertEqual(current.linkSetRevision, 1)
        XCTAssertEqual(current.links.first?.resolution.facts, [])
        XCTAssertNotNil(current.links.first?.versions.first?.historicalPreview)
        XCTAssertFalse(current.links.first?.versions.first?.previewIsTruncated ?? true)

        let source = fixture.root.appendingPathComponent("docs/plans/current.md")
        try Data("Changed authoritative bytes\n".utf8).write(to: source)
        let changedResult = await queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "unassigned")
        ))
        XCTAssertEqual(changedResult.ticketReferences?.links.first?.resolution.facts, [.changed])
        XCTAssertNil(changedResult.ticketReferences?.links.first?.versions.first?.historicalPreview)

        let revised = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(target: target, ticketID: "unassigned", linkID: "requirement-main",
                                   kind: .requirement, artifactID: "current", sourceLocalID: "REQ-1",
                                   locator: "Changed criteria",
                                   expectedContentDigest: try sourceDigest(fixture.root), expectedLinkSetRevision: 1)
        ))
        XCTAssertEqual(revised.ticketReferenceLinkSetRevision, 2)
        let historyResult = await queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "unassigned")
        ))
        let history = try XCTUnwrap(historyResult.ticketReferences?.links.first?.versions)
        XCTAssertEqual(history.map(\.version), [2, 1])
        XCTAssertEqual(history[0].resolution.facts, [])
        XCTAssertEqual(history[1].resolution.facts, [.changed])

        let impactsResult = await queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .recordedImpacts(projectID: "p", rootID: "root",
                                    repositoryID: target.repositoryID, artifactID: "current")
        ))
        let impacts = try XCTUnwrap(impactsResult.recordedImpacts)
        XCTAssertEqual(impacts.title, "Recorded impacts")
        XCTAssertEqual(impacts.rows.map(\.version), [2, 1])
        XCTAssertEqual(impacts.rows.map(\.isCurrent), [true, false])
        XCTAssertTrue(impacts.rows.allSatisfy { $0.phaseLabel == "Not placed" })
        XCTAssertTrue(impacts.rows.allSatisfy { $0.kind == .requirement && $0.sourceLocalID == "REQ-1" })

        let missing = await queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "missing")
        ))
        XCTAssertEqual(missing.error, .ticketReferenceNotFound)
    }

    func testReadOnlyReferenceQueryWithdrawsResultAfterAuthorizationReplacement() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(
            envelope(fixture.root, .bindDocumentationRepository(target: target))
        )
        XCTAssertNil(bound.error)
        let gate = TicketReferenceQueryAccessGate()
        let dispatcher = AgentQueryDispatcher(
            store: fixture.store,
            bookmarkStore: BlockingTicketReferenceBookmarkStore(root: fixture.root, gate: gate)
        )
        let query = Task {
            await dispatcher.dispatch(.init(
                version: 1,
                projectRoot: fixture.root.path,
                query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "unassigned")
            ))
        }
        await gate.waitUntilEntered()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Replace authorization") { connection in
            try connection.execute(
                "UPDATE project_bookmarks SET bookmark_data = X'02' WHERE project_id = 'p' AND path = ?",
                bindings: [.text(fixture.root.path)]
            )
        }
        await gate.release()

        let result = await query.value
        XCTAssertNil(result.ticketReferences)
        XCTAssertEqual(result.error, .documentation(.bindingMismatch))
    }

    func testAcceptedMoveCanCoexistWithChangedBytesWithoutSubstitutingHistoricalContent() async throws {
        let fixture = try await makeReferenceFixture()
        let accepted = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(
            fixture.root, .bindDocumentationRepository(target: accepted)
        ))
        XCTAssertNil(binding.error)
        let linked = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: accepted, ticketID: "unassigned", linkID: "moved-link",
                kind: .requirement, artifactID: "current", sourceLocalID: nil,
                locator: nil, expectedContentDigest: try sourceDigest(fixture.root),
                expectedLinkSetRevision: 0
            )
        ))
        XCTAssertNil(linked.error)

        let original = fixture.root.appendingPathComponent("docs/plans/current.md")
        let moved = fixture.root.appendingPathComponent("docs/plans/moved.md")
        try FileManager.default.moveItem(at: original, to: moved)
        try Data("Changed after an accepted move\n".utf8).write(to: moved)
        try Data("# Plans\n[Current](moved.md)\n".utf8)
            .write(to: fixture.root.appendingPathComponent("docs/plans/README.md"))
        try editCatalog(fixture.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            let index = artifacts.firstIndex { $0["artifactID"] as? String == "current" }!
            artifacts[index]["path"] = "docs/plans/moved.md"
            catalog["artifacts"] = artifacts
        }
        let candidate = try documentationTarget(fixture.root)
        let acceptance = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .acceptDocumentationCatalog(
                target: candidate,
                priorCatalogVersion: accepted.catalogVersion,
                priorCatalogDigest: accepted.catalogDigest
            )
        ))
        XCTAssertNil(acceptance.error)

        let revised = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: candidate, ticketID: "unassigned", linkID: "moved-link",
                kind: .requirement, artifactID: "current", sourceLocalID: nil,
                locator: "Moved source", expectedContentDigest: try sourceDigest(fixture.root),
                expectedLinkSetRevision: 1
            )
        ))
        XCTAssertEqual(revised.ticketReferenceLinkSetRevision, 2)

        let result = await queryDispatcher(fixture).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "unassigned")
        ))
        let link = try XCTUnwrap(result.ticketReferences?.links.first)
        XCTAssertEqual(link.resolution.facts, [])
        XCTAssertEqual(link.versions.map(\.version), [2, 1])
        XCTAssertEqual(link.versions[0].resolution.facts, [])
        XCTAssertEqual(link.versions[1].resolution.facts, [.changed, .moved])
        XCTAssertNil(link.versions[1].historicalPreview)
        XCTAssertEqual(link.versions[1].observedPath, "docs/plans/current.md")
    }

    func testAcceptedSupersessionAndRetirementRemainDistinctResolutionFacts() async throws {
        let fixture = try await makeReferenceFixture()
        let accepted = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(
            fixture.root, .bindDocumentationRepository(target: accepted)
        ))
        XCTAssertNil(binding.error)
        let linked = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: accepted, ticketID: "unassigned", linkID: "lifecycle-link",
                kind: .decision, artifactID: "current", sourceLocalID: "ADR-CURRENT",
                locator: nil, expectedContentDigest: try sourceDigest(fixture.root),
                expectedLinkSetRevision: 0
            )
        ))
        XCTAssertNil(linked.error)

        try editCatalog(fixture.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            let current = artifacts.firstIndex { $0["artifactID"] as? String == "current" }!
            artifacts[current]["lifecycle"] = "superseded"
            artifacts[current]["authorityLevel"] = "nonAuthoritative"
            artifacts[current].removeValue(forKey: "authorityRole")
            let replacement = artifacts.firstIndex { $0["artifactID"] as? String == "draft" }!
            artifacts[replacement]["lifecycle"] = "active"
            artifacts[replacement]["authorityLevel"] = "controlling"
            artifacts[replacement]["authorityRole"] = "delivery"
            artifacts[replacement]["supersedes"] = ["current"]
            catalog["artifacts"] = artifacts
        }
        let supersededCatalog = try documentationTarget(fixture.root)
        let supersededAcceptance = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .acceptDocumentationCatalog(
                target: supersededCatalog,
                priorCatalogVersion: accepted.catalogVersion,
                priorCatalogDigest: accepted.catalogDigest
            )
        ))
        XCTAssertNil(supersededAcceptance.error)
        let superseded = await queryDispatcher(fixture).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "unassigned")
        ))
        XCTAssertEqual(
            superseded.ticketReferences?.links.first?.resolution.facts,
            [.superseded, .noLongerControlling]
        )

        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("docs/plans/current.md"))
        try Data("# Plans\n[Current](draft.md)\n".utf8)
            .write(to: fixture.root.appendingPathComponent("docs/plans/README.md"))
        try editCatalog(fixture.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts.removeAll { $0["artifactID"] as? String == "current" }
            catalog["artifacts"] = artifacts
            var collections = catalog["collections"] as! [[String: Any]]
            let plans = collections.firstIndex { $0["collectionID"] as? String == "plans" }!
            collections[plans]["firstRead"] = "draft"
            catalog["collections"] = collections
            var retired = catalog["retiredArtifactIDs"] as! [String]
            retired.append("current")
            catalog["retiredArtifactIDs"] = retired
        }
        let retiredCatalog = try documentationTarget(fixture.root)
        let retirementAcceptance = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .acceptDocumentationCatalog(
                target: retiredCatalog,
                priorCatalogVersion: supersededCatalog.catalogVersion,
                priorCatalogDigest: supersededCatalog.catalogDigest
            )
        ))
        XCTAssertNil(retirementAcceptance.error)
        let retired = await queryDispatcher(fixture).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketReferences(projectID: "p", rootID: "root", ticketID: "unassigned")
        ))
        XCTAssertEqual(retired.ticketReferences?.links.first?.resolution.facts, [.retired])
    }

    func testProjectRemovalRetainsReferenceIdentityVersionsAndRetirementFacts() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(fixture.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(binding.error)
        let created = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(target: target, ticketID: "unassigned", linkID: "decision-main",
                                   kind: .decision, artifactID: "current", sourceLocalID: "ADR-1",
                                   locator: "Decision", expectedContentDigest: try sourceDigest(fixture.root),
                                   expectedLinkSetRevision: 0)
        ))
        XCTAssertNil(created.error)
        let retired = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .retireTicketReference(projectID: "p", rootID: "root", ticketID: "unassigned",
                                   linkID: "decision-main", version: 1, expectedLinkSetRevision: 1)
        ))
        XCTAssertNil(retired.error)

        let manager = ProjectRemovalManager(store: fixture.store)
        let preview = try await manager.preview(projectID: .init(rawValue: "p"))
        let removed = try await manager.apply(preview)
        let retained = try await fixture.store.read { connection in
            (
                try connection.row("SELECT * FROM retained_ticket_reference_links WHERE removal_id = ?", bindings: [.text(removed.id.rawValue)]),
                try connection.row("SELECT * FROM retained_ticket_reference_versions WHERE removal_id = ?", bindings: [.text(removed.id.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_links WHERE project_id = 'p'")
            )
        }
        XCTAssertEqual(retained.0?["historical_project_id"], .text("p"))
        XCTAssertEqual(retained.0?["link_id"], .text("decision-main"))
        XCTAssertEqual(retained.0?["relationship"], .text("retired"))
        XCTAssertEqual(retained.0?["retired_version"], .integer(1))
        XCTAssertEqual(retained.0?["link_set_revision"], .integer(2))
        XCTAssertEqual(retained.1?["source_local_id"], .text("ADR-1"))
        XCTAssertEqual(retained.1?["version"], .integer(1))
        XCTAssertEqual(retained.2, 0)
        do {
            try await fixture.store.transact(
                actor: .init(id: "ordinary-writer"),
                reason: "Must not alter retained reference history"
            ) { connection in
                try connection.execute(
                    "UPDATE retained_ticket_reference_links SET relationship = 'current' WHERE removal_id = ?",
                    bindings: [.text(removed.id.rawValue)]
                )
            }
            XCTFail("Expected retained reference history to reject ordinary writes")
        } catch {}
    }

    func testFullBackupRestorePreservesCompleteReferenceRecordsAndRenewsAuthority() async throws {
        let fixture = try await makeReferenceFixture()
        let target = try documentationTarget(fixture.root)
        let binding = await fixture.dispatcher.dispatch(envelope(
            fixture.root, .bindDocumentationRepository(target: target)
        ))
        XCTAssertNil(binding.error)
        let linked = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .upsertTicketReference(
                target: target, ticketID: "unassigned", linkID: "backup-link",
                kind: .requirement, artifactID: "current", sourceLocalID: "REQ-BACKUP",
                locator: "Backup behavior", expectedContentDigest: try sourceDigest(fixture.root),
                expectedLinkSetRevision: 0
            )
        ))
        XCTAssertNil(linked.error)
        let beforeRegistration = try await ProjectLifecycleManager(store: fixture.store)
            .snapshot(projectID: .init(rawValue: "p")).registration
        let package = fixture.store.databaseURL.deletingLastPathComponent()
            .appendingPathComponent("references.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: fixture.store, databaseURL: fixture.store.databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: package))
        let backupStore = DeliveryStore(
            databaseURL: package.appendingPathComponent(ApplicationBackupManifest.databaseFileName)
        )
        let backedUp = try await backupStore.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_links WHERE id = 'backup-link'"),
                try connection.scalarText("SELECT content_digest FROM ticket_reference_versions WHERE link_id = 'backup-link'")
            )
        }
        XCTAssertEqual(backedUp.0, 1)
        XCTAssertEqual(backedUp.1?.count, 64)
        await backupStore.close()

        let recovery = ApplicationRecoveryManager(store: fixture.store, databaseURL: fixture.store.databaseURL)
        let restored = try await recovery.restore(try await recovery.previewRestore(packageURL: package))
        let afterRegistration = try await ProjectLifecycleManager(store: restored.store)
            .snapshot(projectID: .init(rawValue: "p")).registration
        XCTAssertNotEqual(afterRegistration, beforeRegistration)
        let restoredFacts = try await restored.store.read { connection in
            (
                try connection.scalarText("SELECT source_local_id FROM ticket_reference_versions WHERE link_id = 'backup-link'"),
                try connection.scalarInt("SELECT is_stale FROM project_bookmarks WHERE project_id = 'p'")
            )
        }
        XCTAssertEqual(restoredFacts.0, "REQ-BACKUP")
        XCTAssertEqual(restoredFacts.1, 1)
    }

    private func makeReferenceFixture() async throws -> (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher) {
        let directory = URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
            .appendingPathComponent("release-radar-reference-fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let root = directory.appendingPathComponent("repository")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: root.appendingPathComponent("AGENTS.md"))
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed reference fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('p', 'reference-registration', 1, 'complete')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'p', ?)", bindings: [.text(root.path)])
            try connection.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, X'01')", bindings: [.text(root.path)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase', 'p', 'Phase')")
            try connection.execute("INSERT INTO tickets (id, project_id, outcome) VALUES ('unassigned', 'p', 'Unassigned')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('placed', 'p', 'phase', 'Placed', 'backlog')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('accepted', 'p', 'phase', 'Accepted', 'accepted')")
        }
        let registration = ProjectRegistration(projectID: .init(rawValue: "p"), registrationID: "reference-registration", requestGeneration: 1)
        let project = AuthorizedProject(registration: registration, canonicalRoot: root, authorizedRoots: [root])
        let bookmarks = ProjectBookmarkStore(
            resolver: { _ in .init(url: root, isStale: false) },
            startAccessing: { _ in true },
            stopAccessing: { _ in }
        )
        return (store, root, AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]),
            bookmarkStore: bookmarks
        ))
    }

    private func documentationTarget(_ root: URL) throws -> DocumentationTarget {
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        return .init(projectID: "p", rootID: "root", repositoryID: snapshot.catalog.repositoryID.lowercased(),
                     catalogVersion: snapshot.version, catalogDigest: snapshot.digest)
    }

    private func sourceDigest(_ root: URL, artifactID: String = "current") throws -> String {
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let artifact = try XCTUnwrap(snapshot.catalog.artifacts.first { $0.artifactID == artifactID })
        return documentationDigest(try Data(contentsOf: root.appendingPathComponent(artifact.path)))
    }

    private func referenceMutationCounts(_ store: DeliveryStore) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_links") ?? 0,
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_versions") ?? 0,
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? 0,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? 0,
            ]
        }
    }

    private func queryDispatcher(
        _ fixture: (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher)
    ) -> AgentQueryDispatcher {
        AgentQueryDispatcher(
            store: fixture.store,
            bookmarkStore: ProjectBookmarkStore(
                resolver: { _ in .init(url: fixture.root, isStale: false) },
                startAccessing: { _ in true },
                stopAccessing: { _ in }
            )
        )
    }

    private func editCatalog(_ root: URL, mutate: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent("docs/catalog.json")
        var catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&catalog)
        try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys]).write(to: url)
    }

    private func envelope(_ root: URL, _ command: AgentCommand, requestID: UUID = UUID()) -> AgentCommandEnvelope {
        .init(
            version: 1,
            requestID: requestID,
            projectRoot: root.path,
            expectedRegistration: .init(
                projectID: .init(rawValue: "p"),
                registrationID: "reference-registration",
                requestGeneration: 1
            ),
            reason: "Authorized reference operation",
            command: command
        )
    }

}

private struct BlockingTicketReferenceBookmarkStore: ProjectBookmarkStoring {
    let root: URL
    let gate: TicketReferenceQueryAccessGate

    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: root, isStale: false)
    }
    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        await gate.pause()
        return try await body(resolve(bookmark))
    }
}

private actor TicketReferenceQueryAccessGate {
    private var entered = false
    private var released = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func pause() async {
        entered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        guard !released else { return }
        await withCheckedContinuation { releaseContinuations.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func release() {
        released = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

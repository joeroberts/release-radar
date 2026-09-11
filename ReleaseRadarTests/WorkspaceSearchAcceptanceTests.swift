import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class WorkspaceSearchAcceptanceTests: XCTestCase {
    func testSearchReturnsEveryAuthorizedRecordDomainWithoutMutatingTheStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "project-byte-exact")
        try await store.transact(
            actor: .init(id: "workspace-search-test"),
            reason: "Needle history event",
            auditEventID: .init(rawValue: "needle-history"),
            auditScope: .init(projectID: projectID, entityType: .ticket, entityID: "needle-ticket")
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Needle project')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'registration-byte-exact', 1, 'complete')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('needle-phase', ?, 'Needle phase')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('needle-ticket', ?, 'needle-phase', 'Needle ticket outcome', 'backlog')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES (?, 'needle-phase', 'needle-delivery-goal', 'Needle delivery goal', 'Needle delivery outcome', 'draft', 0, '2026-09-10T12:00:00Z', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('needle-thread', ?, 'completed', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('needle-execution-goal', ?, 'needle-thread', 'Completed', 'Needle execution outcome', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('needle-review', ?, 'needle-ticket', 'completion', 'Needle review summary', 'resolved')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES ('needle-completion', ?, 'needle-ticket', 'Needle completion summary', '2026-09-10T12:01:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO notification_events (id, fingerprint, state, ticket_id, project_id, title, message, created_at) VALUES ('needle-notification', 'needle-notification-fingerprint', 'delivered', 'needle-ticket', ?, 'Needle notification', 'Needle notification message', '2026-09-10T12:02:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO ticket_reference_link_sets (project_id, ticket_id, revision, created_at, updated_at) VALUES (?, 'needle-ticket', 1, '2026-09-10T12:00:00Z', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO ticket_reference_links (project_id, ticket_id, id, kind, repository_id, artifact_id, current_version, relationship, created_at, updated_at) VALUES (?, 'needle-ticket', 'needle-decision-link', 'decision', '11111111-1111-4111-8111-111111111111', 'needle-artifact', 1, 'current', '2026-09-10T12:00:00Z', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO ticket_reference_versions (project_id, ticket_id, link_id, version, content_digest, source_local_id, locator, catalog_version, catalog_digest, observed_path, observed_lifecycle, observed_authority, created_at) VALUES (?, 'needle-ticket', 'needle-decision-link', 1, ?, 'NEEDLE-DECISION', 'Needle decision heading', 1, ?, 'docs/decisions.md', 'active', 'controlling', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue), .text(String(repeating: "a", count: 64)), .text(String(repeating: "b", count: 64))])
        }
        let beforeAuditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }

        let projection = try await WorkspaceSearchQuery.search(
            store: store,
            definition: .init(
                text: "needle",
                scope: .allAuthorized,
                domains: Set(WorkspaceSearchDomain.allCases),
                sort: .domainThenTitle
            )
        )

        XCTAssertEqual(Set(projection.results.map(\.domain)), Set(WorkspaceSearchDomain.allCases))
        XCTAssertEqual(projection.results.count, 10)
        XCTAssertTrue(projection.isComplete)
        XCTAssertTrue(projection.omittedDomains.isEmpty)
        XCTAssertEqual(Set(projection.results.map(\.project.registrationID)), ["registration-byte-exact"])
        XCTAssertEqual(try XCTUnwrap(projection.results.first { $0.domain == .decisionReference }).identity,
                       .decisionReference(projectID: projectID, registrationID: "registration-byte-exact", ticketID: .init(rawValue: "needle-ticket"), linkID: "needle-decision-link", version: 1, repositoryID: "11111111-1111-4111-8111-111111111111", artifactID: "needle-artifact"))
        XCTAssertTrue(projection.results.contains {
            $0.identity == .history(projectID: projectID, registrationID: "registration-byte-exact", source: .audit, sourceID: "needle-history")
        })
        XCTAssertTrue(projection.results.contains {
            $0.identity == .history(projectID: projectID, registrationID: "registration-byte-exact", source: .observation, sourceID: "needle-thread|needle-execution-goal")
        })
        XCTAssertEqual(Set(projection.results.compactMap { result -> WorkspaceSearchHistorySource? in
            guard case let .history(_, _, source, _) = result.identity else { return nil }
            return source
        }), Set(WorkspaceSearchHistorySource.allCases))
        let afterAuditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(afterAuditCount, beforeAuditCount)
    }

    func testSavedQueriesRelaunchWithEveryFilterAndUnsupportedPayloadStaysRecoverable() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let projectID = ProjectID(rawValue: "project-saved")
        try await seedProject(store, projectID: projectID, registrationID: "registration-saved")
        let definition = WorkspaceSearchDefinition(
            text: "release candidate",
            scope: .registrations([.init(projectID: projectID, registrationID: "registration-saved")]),
            domains: [.ticket, .history],
            sort: .newest
        )
        let repository = WorkspaceSearchPreferencesRepository(store: store)

        try await repository.saveWorkingDefinition(definition)
        _ = try await repository.saveQuery(id: "saved-release", name: "Release review", definition: definition)
        await store.close()

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
        let relaunched = WorkspaceSearchPreferencesRepository(store: relaunchedStore)
        guard case let .supported(working) = try await relaunched.loadWorkingDefinition() else {
            return XCTFail("Expected the complete working query after relaunch")
        }
        XCTAssertEqual(working.text, definition.text)
        XCTAssertEqual(working.scope, definition.scope)
        XCTAssertEqual(working.domains, definition.domains)
        XCTAssertEqual(working.sort, definition.sort)
        XCTAssertNotNil(working.authorityIncarnationID)
        let relaunchedQueries = try await relaunched.loadSavedQueries()
        guard case let .supported(saved) = try XCTUnwrap(relaunchedQueries.first) else {
            return XCTFail("Expected a supported saved query")
        }
        XCTAssertEqual(saved.name, "Release review")
        XCTAssertEqual(saved.definition, working)

        let unsupportedPayload = Data("future-filter-payload".utf8)
        try await relaunchedStore.transact(actor: .init(id: "fixture"), reason: "Seed unsupported saved search") { connection in
            try connection.execute(
                "UPDATE workspace_saved_queries SET payload_version = 99, payload_data = ? WHERE id = 'saved-release'",
                bindings: [.blob(unsupportedPayload)]
            )
        }
        _ = try await ApplicationPreferenceReset(store: relaunchedStore).apply()
        let preservedQueries = try await relaunched.loadSavedQueries()
        let preserved = try XCTUnwrap(preservedQueries.first)
        guard case let .unsupported(unsupported) = preserved else {
            return XCTFail("Unsupported payloads must stay visible instead of dropping filters")
        }
        XCTAssertEqual(unsupported.id, "saved-release")
        XCTAssertEqual(unsupported.name, "Release review")
        XCTAssertEqual(unsupported.payloadVersion, 99)
        XCTAssertEqual(unsupported.payloadData, unsupportedPayload)

        try await relaunched.deleteQuery(id: unsupported.id)
        let remainingQueries = try await relaunched.loadSavedQueries()
        XCTAssertTrue(remainingQueries.isEmpty)
    }

    func testAuthorityRotationRejectsSavedScopeUntilProjectsAreReselectedAndResaved() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let projectID = ProjectID(rawValue: "project-rotation")
        try await seedProject(store, projectID: projectID, registrationID: "registration-before")
        let repository = WorkspaceSearchPreferencesRepository(store: store)
        let original = WorkspaceSearchDefinition(
            text: "needle",
            scope: .registrations([.init(projectID: projectID, registrationID: "registration-before")]),
            domains: [.project],
            sort: .title
        )
        let saved = try await repository.saveQuery(id: "saved-rotation", name: "Needle", definition: original)

        try await store.transact(actor: .init(id: "fixture"), reason: "Simulate recovery authority rotation") { connection in
            try connection.execute("UPDATE application_recovery_state SET incarnation_id = '22222222-2222-4222-8222-222222222222' WHERE singleton_id = 1")
            try connection.execute("UPDATE project_registrations SET registration_id = 'registration-after' WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
        }

        do {
            _ = try await WorkspaceSearchQuery.search(store: store, definition: saved.definition)
            XCTFail("An earlier authority incarnation must not execute")
        } catch let error as WorkspaceSearchError {
            XCTAssertEqual(error, .authorizationRequired)
        }

        let reselected = WorkspaceSearchDefinition(
            text: saved.definition.text,
            scope: .registrations([.init(projectID: projectID, registrationID: "registration-after")]),
            domains: saved.definition.domains,
            sort: saved.definition.sort
        )
        let resaved = try await repository.saveQuery(id: saved.id, name: saved.name, definition: reselected)
        XCTAssertNotEqual(resaved.definition.authorityIncarnationID, saved.definition.authorityIncarnationID)
        let projection = try await WorkspaceSearchQuery.search(store: store, definition: resaved.definition)
        XCTAssertEqual(projection.results.count, 1)
    }

    func testTicketSearchIncludesRetiredRecordsAndSortsCollisionResultsDeterministically() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store, projectID: .init(rawValue: "project-b"), registrationID: "registration-b")
        try await seedProject(store, projectID: .init(rawValue: "project-a"), registrationID: "registration-a")
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed retirement audit",
            auditEventID: .init(rawValue: "retirement-a"),
            auditScope: .init(
                projectID: .init(rawValue: "project-a"),
                entityType: .ticket,
                entityID: "ticket-a"
            )
        ) { _ in }
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed colliding ticket results") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-b', 'project-b', 'Phase B'), ('phase-a', 'project-a', 'Phase A')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ticket-b', 'project-b', 'phase-b', 'Needle collision', 'backlog'), ('ticket-a', 'project-a', 'phase-a', 'Needle collision', 'accepted')")
            try connection.execute(
                "INSERT INTO ticket_retirements (project_id, ticket_id, disposition, reason, last_phase_id, last_lane, audit_event_id, retired_at) VALUES ('project-a', 'ticket-a', 'replaced', 'Done', 'phase-a', 'accepted', 'retirement-a', '2026-09-10T13:00:00Z')"
            )
        }

        let projection = try await WorkspaceSearchQuery.search(
            store: store,
            definition: .init(text: "needle", domains: [.ticket], sort: .title)
        )

        XCTAssertEqual(projection.results.map { $0.project.projectID.rawValue }, ["project-a", "project-b"])
        XCTAssertEqual(projection.results.map(\.isRetired), [true, false])
        XCTAssertTrue(projection.isComplete)
    }

    func testProjectionNeverCallsAnIncompleteResultSetComplete() {
        let projection = WorkspaceSearchProjection(
            definition: .init(text: "needle"),
            results: [],
            omissions: [.init(domain: .history, message: "History unavailable")]
        )

        XCTAssertFalse(projection.isComplete)
        XCTAssertEqual(projection.omittedDomains, [.history])
    }

    private func makeDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("store.sqlite")
    }

    private func seedProject(
        _ store: DeliveryStore,
        projectID: ProjectID,
        registrationID: String
    ) async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed searchable project") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name) VALUES (?, 'Needle project')",
                bindings: [.text(projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, 1, 'complete')",
                bindings: [.text(projectID.rawValue), .text(registrationID)]
            )
        }
    }
}

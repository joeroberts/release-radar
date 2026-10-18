import XCTest
@testable import ReleaseRadarCore

final class DependencyGraphPresentationRepositoryAcceptanceTests: XCTestCase {
    func testRepositoryPreservesHigherUnsupportedPayloadAndResetIsExact() async throws {
        let fixture = try await makeFixture()
        let repository = DependencyGraphPresentationRepository(store: fixture.store)
        let layout = DependencyGraphPresentationLayout(ranks: [
            .init(depth: 0, ticketIDs: [fixture.ticketID]),
        ])

        try await repository.save(layout, registration: fixture.registration, focusTicketID: fixture.ticketID)
        let initiallyLoaded = try await repository.load(
            registration: fixture.registration,
            focusTicketID: fixture.ticketID
        )
        XCTAssertEqual(initiallyLoaded, .supported(layout))

        let opaque = Data([0x99, 0x28])
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed future presentation payload") { connection in
            try connection.execute(
                "INSERT INTO dependency_graph_presentations (project_id, registration_id, focus_ticket_id, payload_version, payload_data, updated_at) VALUES (?, ?, ?, 2, ?, '2026-10-18T00:00:00Z')",
                bindings: [.text(fixture.projectID.rawValue), .text(fixture.registration.registrationID), .text(fixture.ticketID.rawValue), .blob(opaque)]
            )
        }
        let rowsBeforeRefusal = try await fixture.store.read { connection in
            try connection.rows("SELECT payload_version,payload_data,updated_at FROM dependency_graph_presentations ORDER BY payload_version")
        }

        let unsupportedBeforeSave = try await repository.load(
            registration: fixture.registration,
            focusTicketID: fixture.ticketID
        )
        XCTAssertEqual(unsupportedBeforeSave, .unsupported(payloadVersion: 2, payloadData: opaque))
        do {
            try await repository.save(layout, registration: fixture.registration, focusTicketID: fixture.ticketID)
            XCTFail("Save must refuse an unsupported highest payload")
        } catch let error as DependencyGraphPresentationError {
            XCTAssertEqual(error, .unsupportedPayload(payloadVersion: 2))
        }
        let unsupportedAfterSave = try await repository.load(
            registration: fixture.registration,
            focusTicketID: fixture.ticketID
        )
        XCTAssertEqual(
            unsupportedAfterSave,
            .unsupported(payloadVersion: 2, payloadData: opaque),
            "Saving v1 must not overwrite a higher unsupported payload"
        )

        do {
            try await repository.reset(registration: fixture.registration, focusTicketID: fixture.ticketID)
            XCTFail("Reset must refuse an unsupported highest payload")
        } catch let error as DependencyGraphPresentationError {
            XCTAssertEqual(error, .unsupportedPayload(payloadVersion: 2))
        } catch {
            XCTFail("Unexpected reset failure: \(error)")
        }
        let unsupportedAfterReset = try await repository.load(
            registration: fixture.registration,
            focusTicketID: fixture.ticketID
        )
        XCTAssertEqual(
            unsupportedAfterReset,
            .unsupported(payloadVersion: 2, payloadData: opaque),
            "Reset must refuse an unsupported highest payload without deleting its bytes"
        )
        let rowsAfterRefusal = try await fixture.store.read { connection in
            try connection.rows("SELECT payload_version,payload_data,updated_at FROM dependency_graph_presentations ORDER BY payload_version")
        }
        XCTAssertEqual(rowsAfterRefusal, rowsBeforeRefusal)
    }

    func testMalformedVersionOneRefusesSaveAndResetWithoutChangingExactBytes() async throws {
        let fixture = try await makeFixture()
        let repository = DependencyGraphPresentationRepository(store: fixture.store)
        let malformed = Data([0x00, 0xFF, 0x28])
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed malformed presentation payload") { connection in
            try connection.execute(
                "INSERT INTO dependency_graph_presentations (project_id, registration_id, focus_ticket_id, payload_version, payload_data, updated_at) VALUES (?, ?, ?, 1, ?, '2026-10-18T00:00:00Z')",
                bindings: [.text(fixture.projectID.rawValue), .text(fixture.registration.registrationID), .text(fixture.ticketID.rawValue), .blob(malformed)]
            )
        }
        let replacement = DependencyGraphPresentationLayout(ranks: [.init(depth: 0, ticketIDs: [fixture.ticketID])])
        let rowBeforeRefusal = try await fixture.store.read { connection in
            try connection.rows("SELECT payload_version,payload_data,updated_at FROM dependency_graph_presentations")
        }
        let operations: [() async throws -> Void] = [
            { try await repository.save(replacement, registration: fixture.registration, focusTicketID: fixture.ticketID) },
            { try await repository.reset(registration: fixture.registration, focusTicketID: fixture.ticketID) },
        ]
        for operation in operations {
            do {
                try await operation()
                XCTFail("Malformed v1 must refuse mutation")
            } catch let error as DependencyGraphPresentationError {
                XCTAssertEqual(error, .unsupportedPayload(payloadVersion: 1))
            }
        }
        let malformedAfterRefusal = try await repository.load(
            registration: fixture.registration,
            focusTicketID: fixture.ticketID
        )
        XCTAssertEqual(malformedAfterRefusal, .unsupported(payloadVersion: 1, payloadData: malformed))
        let rowAfterRefusal = try await fixture.store.read { connection in
            try connection.rows("SELECT payload_version,payload_data,updated_at FROM dependency_graph_presentations")
        }
        XCTAssertEqual(rowAfterRefusal, rowBeforeRefusal)
    }

    func testRepositoryRejectsStaleRegistrationWithoutMutatingPresentation() async throws {
        let fixture = try await makeFixture()
        let repository = DependencyGraphPresentationRepository(store: fixture.store)
        let layout = DependencyGraphPresentationLayout(ranks: [.init(depth: 0, ticketIDs: [fixture.ticketID])])
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Rotate project registration") { connection in
            try connection.execute(
                "UPDATE project_registrations SET registration_id = 'replacement', request_generation = 2 WHERE project_id = ?",
                bindings: [.text(fixture.projectID.rawValue)]
            )
        }

        let staleLoad = try await repository.load(
            registration: fixture.registration,
            focusTicketID: fixture.ticketID
        )
        XCTAssertEqual(staleLoad, .none)
        await XCTAssertThrowsErrorAsync { try await repository.save(layout, registration: fixture.registration, focusTicketID: fixture.ticketID) }
        await XCTAssertThrowsErrorAsync { try await repository.reset(registration: fixture.registration, focusTicketID: fixture.ticketID) }
        let count = try await fixture.store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM dependency_graph_presentations")
        }
        XCTAssertEqual(count, 0)
    }

    func testPresentationSchemaCascadesTicketAndProjectButPreservesOtherFocusAndRegistration() async throws {
        let fixture = try await makeFixture()
        let otherTicket = TicketID(rawValue: "TICKET-2")
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed presentation isolation") { connection in
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, 'phase', 'Second ticket', 'backlog')",
                bindings: [.text(otherTicket.rawValue), .text(fixture.projectID.rawValue)]
            )
        }
        let repository = DependencyGraphPresentationRepository(store: fixture.store)
        let layout = DependencyGraphPresentationLayout(ranks: [.init(depth: 0, ticketIDs: [fixture.ticketID])])
        try await repository.save(layout, registration: fixture.registration, focusTicketID: fixture.ticketID)
        try await repository.save(layout, registration: fixture.registration, focusTicketID: otherTicket)
        try await repository.reset(registration: fixture.registration, focusTicketID: fixture.ticketID)
        let remainingPresentation = try await repository.load(
            registration: fixture.registration,
            focusTicketID: otherTicket
        )
        XCTAssertEqual(remainingPresentation, .supported(layout))

        let schemaConnection = try SQLiteConnection(url: fixture.databaseURL, createIfMissing: false)
        let columns: [String] = try schemaConnection.rows("PRAGMA table_info(dependency_graph_presentations)").compactMap { row in
            guard case let .text(name)? = row["name"] else { return nil }
            return name
        }
        schemaConnection.close()
        XCTAssertEqual(columns, ["project_id", "registration_id", "focus_ticket_id", "payload_version", "payload_data", "updated_at"])

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Delete focused ticket") { connection in
            try connection.execute("DELETE FROM tickets WHERE project_id = ? AND id = ?", bindings: [.text(fixture.projectID.rawValue), .text(otherTicket.rawValue)])
        }
        let count = try await fixture.store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM dependency_graph_presentations")
        }
        XCTAssertEqual(count, 0, "Ticket cascade must remove only presentation rows for the deleted focus")
    }

    private func makeFixture() async throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-DependencyPresentation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "presentation-project")
        let ticketID = TicketID(rawValue: "TICKET-1")
        let registration = ProjectRegistration(projectID: projectID, registrationID: "presentation-registration", requestGeneration: 1)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed presentation repository") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Presentation project')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, 1, 'complete')", bindings: [.text(projectID.rawValue), .text(registration.registrationID)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase', ?, 'Phase')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, 'phase', 'Ticket', 'backlog')", bindings: [.text(ticketID.rawValue), .text(projectID.rawValue)])
        }
        return .init(databaseURL: directory.appendingPathComponent("store.sqlite"), store: store, projectID: projectID, ticketID: ticketID, registration: registration)
    }
}

private struct Fixture {
    let databaseURL: URL
    let store: DeliveryStore
    let projectID: ProjectID
    let ticketID: TicketID
    let registration: ProjectRegistration
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @escaping () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}

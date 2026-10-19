import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectCompanionPublicationProjectionTests: XCTestCase {
    func testProjectionKeepsUnavailableCoverageAndAdmitsOnlyExactCurrentOrArchivedRegistration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-CompanionProjection-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let registration = ProjectRegistration(projectID: .init(rawValue: "project"), registrationID: "registration", requestGeneration: 1)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed companion projection") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project', 'Project', 1)")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('project', 'registration', 1, 'complete')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project', 'unsafe phase name')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ticket-1', 'project', 'phase-1', 'unsafe outcome', 'backlog')")
            try connection.execute("INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('review-1', 'project', 'ticket-1', 'completion', 'unsafe summary', 'resolved')")
        }
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed controlled history",
            auditEventID: .init(rawValue: "audit-1"),
            auditScope: .init(projectID: registration.projectID, entityType: .project, entityID: "project")
        ) { _ in }
        let identities = ProjectCompanionPublicationIdentityStore(store: store)
        _ = try await identities.ensureActiveIncarnations(
            registration: registration,
            itemIDs: ["delivery.phase:phase-1", "delivery.ticket:ticket-1", "review:review-1", "history:audit-1"],
            actor: .init(id: "fixture")
        )
        let selected: Set<ProjectCompanionPublicationCategory> = [.deliveryGraph, .reviewMetadata, .historyMetadata, .documentation, .evidence]
        let active = try await ProjectCompanionPublicationProjection.load(store: store, scope: .current(registration), selectedCategories: selected)
        XCTAssertEqual(active.registrationID, registration.registrationID)
        XCTAssertEqual(Set(active.items.map(\.identity.itemID)), ["delivery.phase:phase-1", "delivery.ticket:ticket-1", "review:review-1", "history:audit-1"])
        XCTAssertEqual(active.classInventories.first { $0.classID == "deliveryGraph" }?.coverage, .init(status: .complete, itemCount: 2, reason: nil))
        XCTAssertEqual(active.classInventories.first { $0.classID == "reviewMetadata" }?.coverage, .init(status: .complete, itemCount: 1, reason: nil))
        XCTAssertEqual(active.classInventories.first { $0.classID == "historyMetadata" }?.coverage, .init(status: .complete, itemCount: 1, reason: nil))
        let payloads = Dictionary(uniqueKeysWithValues: active.items.map { ($0.identity.itemID, String(decoding: $0.payload, as: UTF8.self)) })
        XCTAssertEqual(payloads["delivery.phase:phase-1"], #"{"id":"phase-1","kind":"phase"}"#)
        XCTAssertEqual(payloads["delivery.ticket:ticket-1"], #"{"id":"ticket-1","kind":"ticket","lane":"backlog","phaseID":"phase-1"}"#)
        XCTAssertEqual(payloads["review:review-1"], #"{"id":"review-1","kind":"review","reviewKind":"completion","status":"resolved","ticketID":"ticket-1"}"#)
        let history = try XCTUnwrap(payloads["history:audit-1"].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] })
        XCTAssertEqual(Set(history.keys), ["kind", "id", "entityType", "createdAt"])
        XCTAssertEqual(history["kind"] as? String, "history")
        XCTAssertEqual(history["id"] as? String, "audit-1")
        XCTAssertEqual(history["entityType"] as? String, "project")
        XCTAssertNil(history["entityID"])
        XCTAssertNotNil(history["createdAt"] as? String)
        for item in active.items {
            XCTAssertEqual(item.lifecycle, .active)
            XCTAssertEqual(item.provenance.sourceIdentity, item.identity.itemID)
        }
        for category in [ProjectCompanionPublicationCategory.documentation, .evidence] {
            let inventory = try XCTUnwrap(active.classInventories.first { $0.classID == category.rawValue })
            XCTAssertEqual(inventory.coverage.status, .unavailable)
            XCTAssertEqual(inventory.coverage.reason?.rawValue, "derived-artifact-projection-not-yet-implemented")
        }

        let originalTicket = try XCTUnwrap(active.items.first { $0.identity.itemID == "delivery.ticket:ticket-1" })
        try await store.transact(actor: .init(id: "fixture"), reason: "Change projected ticket") { connection in
            try connection.execute("UPDATE tickets SET lane = 'done' WHERE id = 'ticket-1'")
        }
        let changed = try await ProjectCompanionPublicationProjection.load(
            store: store,
            scope: .current(registration),
            selectedCategories: [.deliveryGraph]
        )
        let changedTicket = try XCTUnwrap(changed.items.first { $0.identity.itemID == "delivery.ticket:ticket-1" })
        XCTAssertEqual(changedTicket.identity.publicationIncarnationID, originalTicket.identity.publicationIncarnationID)
        XCTAssertNotEqual(changedTicket.identity.versionID, originalTicket.identity.versionID)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed unselected nullable review") { connection in
            try connection.execute("INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('review-project', 'project', NULL, 'completion', 'project review', 'open')")
        }
        _ = try await ProjectCompanionPublicationProjection.load(
            store: store,
            scope: .current(registration),
            selectedCategories: [.deliveryGraph]
        )

        let lifecycle = ProjectLifecycleManager(store: store)
        let archived = try await lifecycle.apply(try await lifecycle.preview(projectID: registration.projectID, transition: .archive))
        _ = try await ProjectCompanionPublicationProjection.load(store: store, scope: .current(archived.registration), selectedCategories: selected)
        do {
            _ = try await ProjectCompanionPublicationProjection.load(store: store, scope: .current(registration), selectedCategories: selected)
            XCTFail("Expected stale registration to reject")
        } catch {
            XCTAssertEqual(error as? ProjectCompanionPublicationError, .staleRegistration)
        }

        let removal = ProjectRemovalManager(store: store)
        let removed = try await removal.apply(try await removal.preview(projectID: registration.projectID))
        let removedProjection = try await ProjectCompanionPublicationProjection.load(
            store: store,
            scope: .removed(removalID: removed.id, registration: removed.registration),
            selectedCategories: selected
        )
        for category in [ProjectCompanionPublicationCategory.deliveryGraph, .reviewMetadata, .historyMetadata] {
            XCTAssertEqual(
                removedProjection.classInventories.first { $0.classID == category.rawValue }?.coverage.status,
                .unavailable
            )
        }
    }

    func testIdentityStorePreservesActiveIdentityAndRequiresExplicitReintroduction() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-CompanionIdentity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let registration = ProjectRegistration(projectID: .init(rawValue: "project"), registrationID: "registration", requestGeneration: 1)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed companion identities") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project', 'Project', 1)")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('project', 'registration', 1, 'complete')")
        }
        let identities = ProjectCompanionPublicationIdentityStore(store: store)
        let first = try await identities.ensureActiveIncarnations(registration: registration, itemIDs: ["item"], actor: .init(id: "fixture"))
        let repeated = try await identities.ensureActiveIncarnations(registration: registration, itemIDs: ["item"], actor: .init(id: "fixture"))
        XCTAssertEqual(first["item"], repeated["item"])
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed future companion row") { connection in
            try connection.execute(
                "UPDATE companion_publication_incarnations SET created_at = '2099-01-01T00:00:00Z' WHERE registration_id = ? AND item_id = 'item'",
                bindings: [.text(registration.registrationID)]
            )
        }
        try await identities.withdraw(scope: .current(registration), itemIDs: ["item"], actor: .init(id: "fixture"))
        try await store.read { connection in
            XCTAssertNotNil(
                try connection.scalarText(
                    "SELECT withdrawn_at FROM companion_publication_incarnations WHERE registration_id = ? AND item_id = 'item'",
                    bindings: [.text(registration.registrationID)]
                )
            )
        }
        do {
            _ = try await identities.ensureActiveIncarnations(registration: registration, itemIDs: ["item"], actor: .init(id: "fixture"))
            XCTFail("Withdrawn identity must not be recreated")
        } catch {
            XCTAssertEqual(error as? ProjectCompanionPublicationError, .withdrawnIncarnation("item"))
        }
        let reintroduced = try await identities.reintroduce(registration: registration, itemIDs: ["item"], actor: .init(id: "fixture"))
        XCTAssertNotEqual(first["item"], reintroduced["item"])
    }

    func testOnboardingReaddGetsFreshRegistrationAndCompanionIncarnation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-CompanionReadd-\(UUID().uuidString)")
        let repository = root.appendingPathComponent("repository")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("store.sqlite"))
        let onboarding = FolderProjectOnboarding(store: store)
        let original = try await onboarding.inspect(folder: repository)
        let originalDecision = OnboardingDecision(preview: original, projectName: "Original")
        _ = try await onboarding.prepare(originalDecision)
        _ = try await onboarding.finish(originalDecision)
        let identities = ProjectCompanionPublicationIdentityStore(store: store)
        let old = try await identities.ensureActiveIncarnations(registration: original.registration, itemIDs: ["stable-item"], actor: .init(id: "fixture"))

        let removal = ProjectRemovalManager(store: store)
        _ = try await removal.apply(try await removal.preview(projectID: original.registration.projectID))
        let readd = try await onboarding.inspect(folder: repository)
        XCTAssertNotEqual(readd.registration.projectID, original.registration.projectID)
        XCTAssertNotEqual(readd.registration.registrationID, original.registration.registrationID)
        let readdDecision = OnboardingDecision(preview: readd, projectName: "Re-added")
        _ = try await onboarding.prepare(readdDecision)
        _ = try await onboarding.finish(readdDecision)
        let fresh = try await identities.ensureActiveIncarnations(registration: readd.registration, itemIDs: ["stable-item"], actor: .init(id: "fixture"))
        XCTAssertNotEqual(old["stable-item"], fresh["stable-item"])
        try await store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM companion_publication_incarnations WHERE project_id = ? AND registration_id = ?", bindings: [.text(original.registration.projectID.rawValue), .text(original.registration.registrationID)]), 1)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM companion_publication_incarnations WHERE project_id = ? AND registration_id = ?", bindings: [.text(readd.registration.projectID.rawValue), .text(readd.registration.registrationID)]), 1)
        }
    }
}

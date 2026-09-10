import Foundation
import XCTest
@testable import ReleaseRadarCore

final class DeliveryEvidenceAcceptanceTests: XCTestCase {
    func testMigrationCreatesEmptyRevisionEvidenceTablesWithoutInferringLegacyEvidence() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-delivery-evidence-\(UUID().uuidString).sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await store.availability else {
            return XCTFail("Expected the synthetic store to be available")
        }
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed legacy evidence") { connection in
            try connection.execute("INSERT INTO projects (id,name) VALUES ('p','Project')")
            try connection.execute("INSERT INTO evidence (id,project_id,path) VALUES ('legacy','p','old.log')")
        }

        XCTAssertEqual(
            try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"),
            StoreMigrations.currentVersion
        )
        let counts = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_sets"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_targets"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_observations"),
                try connection.scalarInt("SELECT COUNT(*) FROM evidence")
            )
        }
        XCTAssertEqual(counts.0, 0)
        XCTAssertEqual(counts.1, 0)
        XCTAssertEqual(counts.2, 0)
        XCTAssertEqual(counts.3, 1)
    }

    func testTypedCommandsReplayReadBackAndPreserveObservationsAcrossTargetChanges() async throws {
        let fixture = try await makeFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(envelope(fixture.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(bound.error)

        let firstTargetRequest = UUID()
        let firstTarget = envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("a", checkout: .clean),
                expectations: [.init(category: .check, scope: "unit")],
                expectedEvidenceRevision: 0
            ),
            requestID: firstTargetRequest
        )
        let created = await fixture.dispatcher.dispatch(firstTarget)
        XCTAssertNil(created.error)
        XCTAssertEqual(created.deliveryEvidenceRevision, 1)
        let replayed = await fixture.dispatcher.dispatch(firstTarget)
        XCTAssertEqual(replayed, created)

        let changedReplay = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("b", checkout: .clean),
                expectations: [],
                expectedEvidenceRevision: 1
            ),
            requestID: firstTargetRequest
        ))
        XCTAssertEqual(changedReplay.error, .requestIDReused)

        let observation = DeliveryEvidenceObservation(
            id: "unit-check",
            targetVersion: 1,
            fact: .check(.init(scope: "unit")),
            source: .init(kind: .localObservation, label: "Focused XCTest run"),
            sourceAvailability: .available,
            outcome: .passed,
            observedAt: "2026-09-10T18:00:00Z",
            recordedAt: "2026-09-10T18:01:00Z"
        )
        let appended = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "ticket",
                observation: observation,
                expectedEvidenceRevision: 1
            )
        ))
        XCTAssertEqual(appended.deliveryEvidenceRevision, 2)

        let currentResult = await query(fixture).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketDeliveryEvidence(projectID: "p", rootID: "root", ticketID: "ticket")
        ))
        let current = try XCTUnwrap(currentResult.deliveryEvidence)
        XCTAssertEqual(current.revision, 2)
        XCTAssertEqual(current.currentTargetVersion, 1)
        XCTAssertEqual(current.expectations.map(\.status), [.satisfied])
        XCTAssertEqual(current.ownerAcceptance, .notAccepted)

        let secondTarget = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("b", checkout: .dirty, snapshot: "snapshot-b"),
                expectations: [.init(category: .build, scope: nil)],
                expectedEvidenceRevision: 2
            )
        ))
        XCTAssertEqual(secondTarget.deliveryEvidenceRevision, 3)

        let changedResult = await query(fixture).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketDeliveryEvidence(projectID: "p", rootID: "root", ticketID: "ticket")
        ))
        let changed = try XCTUnwrap(changedResult.deliveryEvidence)
        XCTAssertEqual(changed.targets.map(\.version), [2, 1])
        XCTAssertEqual(changed.observations.count, 1)
        XCTAssertEqual(changed.observations[0].applicability.state, .stale)
        XCTAssertEqual(changed.observations[0].applicability.reasons, [.targetVersionMismatch])
        XCTAssertEqual(changed.expectations.map(\.status), [.missing])
    }

    func testManagedDocumentReadbackSeparatesRecordedFactFromCurrentBytes() async throws {
        let fixture = try await makeFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(envelope(fixture.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(bound.error)
        let targetResult = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("a", checkout: .clean),
                expectations: [.init(category: .document, scope: nil)],
                expectedEvidenceRevision: 0
            )
        ))
        XCTAssertNil(targetResult.error)

        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: fixture.root)
        let artifact = try XCTUnwrap(snapshot.catalog.artifacts.first { $0.artifactID == "current" })
        let sourceURL = fixture.root.appendingPathComponent(artifact.path)
        let originalDigest = documentationDigest(try Data(contentsOf: sourceURL))
        let observation = DeliveryEvidenceObservation(
            id: "document",
            targetVersion: 1,
            fact: .document(.init(
                repositoryID: target.repositoryID,
                revision: revision("a", checkout: .clean),
                artifactID: artifact.artifactID,
                contentDigest: originalDigest,
                catalogVersion: snapshot.version,
                catalogDigest: snapshot.digest
            )),
            source: .init(kind: .managedDocument, label: artifact.artifactID),
            sourceAvailability: .available,
            outcome: .observed,
            observedAt: "2026-09-10T18:00:00Z",
            recordedAt: "2026-09-10T18:01:00Z"
        )
        let observationResult = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "ticket",
                observation: observation,
                expectedEvidenceRevision: 1
            )
        ))
        XCTAssertNil(observationResult.error)

        try Data("Changed document bytes\n".utf8).write(to: sourceURL)
        let readbackResult = await query(fixture).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketDeliveryEvidence(projectID: "p", rootID: "root", ticketID: "ticket")
        ))
        let readback = try XCTUnwrap(readbackResult.deliveryEvidence)
        XCTAssertEqual(readback.observations[0].observation.fact, observation.fact)
        XCTAssertEqual(readback.observations[0].currentSourceAvailability, .available)
        XCTAssertNotEqual(readback.observations[0].currentDocumentDigest, originalDigest)
        XCTAssertEqual(readback.observations[0].applicability.state, .stale)
        XCTAssertTrue(readback.observations[0].applicability.reasons.contains(.documentContentChanged))
        XCTAssertEqual(readback.expectations.map(\.status), [.missing])

        let beforeRefresh = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT revision FROM ticket_delivery_evidence_sets WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        try FileManager.default.removeItem(at: sourceURL)
        let unavailableResult = await query(fixture).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketDeliveryEvidence(projectID: "p", rootID: "root", ticketID: "ticket")
        ))
        let unavailable = try XCTUnwrap(unavailableResult.deliveryEvidence)
        XCTAssertEqual(unavailable.observations[0].observation.fact, observation.fact)
        XCTAssertEqual(unavailable.observations[0].currentSourceAvailability, .unavailable)
        XCTAssertNil(unavailable.observations[0].currentDocumentDigest)
        XCTAssertEqual(unavailable.expectations.map(\.status), [.unavailable])
        let afterRefresh = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT revision FROM ticket_delivery_evidence_sets WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        XCTAssertEqual(beforeRefresh.0, afterRefresh.0)
        XCTAssertEqual(beforeRefresh.1, afterRefresh.1)
        XCTAssertEqual(beforeRefresh.2, afterRefresh.2)
    }

    func testCompletedPhaseAndAcceptedTicketRejectEvidenceWithoutSideEffects() async throws {
        let fixture = try await makeFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(envelope(fixture.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(bound.error)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Complete phase") { connection in
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='completed',revision=1,completion_baseline_digest='baseline',completed_at='2026-09-10T00:00:00Z' WHERE project_id='p' AND phase_id='phase'")
        }
        let completed = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("a", checkout: .clean),
                expectations: [],
                expectedEvidenceRevision: 0
            )
        ))
        XCTAssertEqual(completed.error, .completedPhaseReadOnly(.init(rawValue: "phase")))

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Reopen fixture and accept ticket") { connection in
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='in_delivery',revision=2,completion_baseline_digest=NULL,completed_at=NULL WHERE project_id='p' AND phase_id='phase'")
            try connection.execute("UPDATE tickets SET lane='accepted' WHERE project_id='p' AND id='ticket'")
        }
        let accepted = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("a", checkout: .clean),
                expectations: [],
                expectedEvidenceRevision: 0
            )
        ))
        XCTAssertEqual(accepted.error, .deliveryEvidenceTicketAccepted)
        let counts = try await fixture.store.read {
            (
                try $0.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_targets"),
                try $0.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_body LIKE '%DeliveryEvidence%'")
            )
        }
        XCTAssertEqual(counts.0, 0)
    }

    func testInvalidObservationRollsBackWithoutAuditReceiptOrEvidenceMutation() async throws {
        let fixture = try await makeFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .bindDocumentationRepository(target: target)
        ))
        XCTAssertNil(bound.error)
        let targetResult = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("a", checkout: .clean),
                expectations: [.init(category: .check, scope: "unit")],
                expectedEvidenceRevision: 0
            )
        ))
        XCTAssertNil(targetResult.error)
        let before = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT revision FROM ticket_delivery_evidence_sets WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_observations"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        let invalid = DeliveryEvidenceObservation(
            id: "missing-attachment",
            targetVersion: 1,
            fact: .check(.init(scope: "unit")),
            source: .init(kind: .recordedClaim, label: "Claim with missing attachment"),
            sourceAvailability: .available,
            outcome: .passed,
            observedAt: "2026-09-10T18:00:00Z",
            recordedAt: "2026-09-10T18:01:00Z",
            attachmentEvidenceID: "not-present"
        )
        let result = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "ticket",
                observation: invalid,
                expectedEvidenceRevision: 1
            )
        ))
        guard case let .invalidDeliveryEvidence(message) = result.error else {
            return XCTFail("Expected invalid evidence, got \(String(describing: result.error))")
        }
        XCTAssertTrue(message.contains("attachment"))
        XCTAssertNil(result.auditEventID)

        let after = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT revision FROM ticket_delivery_evidence_sets WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_observations"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        XCTAssertEqual(before.0, after.0)
        XCTAssertEqual(before.1, after.1)
        XCTAssertEqual(before.2, after.2)
        XCTAssertEqual(before.3, after.3)
    }

    func testProjectRemovalRetainsRevisionBoundEvidenceAndClearsLiveRows() async throws {
        let fixture = try await makeFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .bindDocumentationRepository(target: target)
        ))
        XCTAssertNil(bound.error)
        let targetResult = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("a", checkout: .dirty, snapshot: "snapshot-a"),
                expectations: [.init(category: .check, scope: "unit")],
                expectedEvidenceRevision: 0
            )
        ))
        XCTAssertNil(targetResult.error)
        let observationResult = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "ticket",
                observation: observation(
                    id: "unit-check",
                    targetVersion: 1
                ),
                expectedEvidenceRevision: 1
            )
        ))
        XCTAssertNil(observationResult.error)

        let removal = ProjectRemovalManager(store: fixture.store)
        let record = try await removal.apply(try await removal.preview(projectID: .init(rawValue: "p")))
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_sets WHERE project_id='p'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_targets WHERE project_id='p'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_observations WHERE project_id='p'"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_delivery_evidence_targets WHERE removal_id=?", bindings: [.text(record.id.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_delivery_evidence_observations WHERE removal_id=?", bindings: [.text(record.id.rawValue)]),
                try connection.scalarInt("SELECT evidence_revision FROM retained_ticket_delivery_evidence_targets WHERE removal_id=?", bindings: [.text(record.id.rawValue)]),
                try connection.scalarText("SELECT registration_id FROM retained_ticket_delivery_evidence_targets WHERE removal_id=?", bindings: [.text(record.id.rawValue)])
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 0)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, 1)
        XCTAssertEqual(state.5, 2)
        XCTAssertEqual(state.6, "evidence-registration")
    }

    func testOlderBackupRestoreRotatesAuthorityAndReconcilesNewerEvidenceAsHistory() async throws {
        let fixture = try await makeFixture()
        let target = try documentationTarget(fixture.root)
        let bound = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .bindDocumentationRepository(target: target)
        ))
        XCTAssertNil(bound.error)
        let firstTarget = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("a", checkout: .clean),
                expectations: [.init(category: .check, scope: "unit")],
                expectedEvidenceRevision: 0
            )
        ))
        XCTAssertNil(firstTarget.error)
        let firstObservation = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "ticket",
                observation: observation(
                    id: "before-backup",
                    targetVersion: 1
                ),
                expectedEvidenceRevision: 1
            )
        ))
        XCTAssertNil(firstObservation.error)

        let packageURL = fixture.store.databaseURL.deletingLastPathComponent()
            .appendingPathComponent("evidence.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: fixture.store, databaseURL: fixture.store.databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))

        let secondTarget = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("b", checkout: .dirty, snapshot: "snapshot-b"),
                expectations: [.init(category: .check, scope: "unit")],
                expectedEvidenceRevision: 2
            )
        ))
        XCTAssertNil(secondTarget.error)
        let secondObservation = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "ticket",
                observation: observation(
                    id: "after-backup",
                    targetVersion: 2
                ),
                expectedEvidenceRevision: 3
            )
        ))
        XCTAssertNil(secondObservation.error)

        let recovery = ApplicationRecoveryManager(store: fixture.store, databaseURL: fixture.store.databaseURL)
        let preview = try await recovery.previewRestore(packageURL: packageURL)
        XCTAssertTrue(preview.newerHistoryReconciliationAvailable)
        let restored = try await recovery.restore(preview)
        XCTAssertTrue(restored.newerHistoryWasReconciled)

        let registration = try await ProjectLifecycleManager(store: restored.store)
            .snapshot(projectID: .init(rawValue: "p")).registration
        XCTAssertNotEqual(registration.registrationID, "evidence-registration")
        XCTAssertEqual(registration.requestGeneration, 2)
        let activeResult = await query(store: restored.store, root: fixture.root).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketDeliveryEvidence(projectID: "p", rootID: "root", ticketID: "ticket")
        ))
        XCTAssertEqual(activeResult.error, .documentation(.rootUnavailable))
        XCTAssertNil(activeResult.deliveryEvidence)
        let restoredActive = try await restored.store.read { connection in
            (
                try connection.scalarInt("SELECT revision FROM ticket_delivery_evidence_sets WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarInt("SELECT current_target_version FROM ticket_delivery_evidence_sets WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_targets WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_delivery_evidence_observations WHERE project_id='p' AND ticket_id='ticket'"),
                try connection.scalarText("SELECT registration_id FROM ticket_delivery_evidence_targets WHERE project_id='p' AND ticket_id='ticket' AND version=1"),
                try connection.scalarText("SELECT id FROM ticket_delivery_evidence_observations WHERE project_id='p' AND ticket_id='ticket'")
            )
        }
        XCTAssertEqual(restoredActive.0, 2)
        XCTAssertEqual(restoredActive.1, 1)
        XCTAssertEqual(restoredActive.2, 1)
        XCTAssertEqual(restoredActive.3, 1)
        XCTAssertEqual(restoredActive.4, "evidence-registration")
        XCTAssertEqual(restoredActive.5, "before-backup")

        let retained = try await restored.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_delivery_evidence_targets WHERE historical_project_id='p'"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_delivery_evidence_observations WHERE historical_project_id='p'"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_delivery_evidence_targets WHERE historical_project_id='p' AND version=2"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_ticket_delivery_evidence_observations WHERE historical_project_id='p' AND id='after-backup'")
            )
        }
        XCTAssertEqual(retained.0, 2)
        XCTAssertEqual(retained.1, 2)
        XCTAssertEqual(retained.2, 1)
        XCTAssertEqual(retained.3, 1)

        let currentProject = AuthorizedProject(
            registration: registration,
            canonicalRoot: fixture.root,
            authorizedRoots: [fixture.root]
        )
        let staleDispatcher = AgentCommandDispatcher(
            store: restored.store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [currentProject]),
            bookmarkStore: ProjectBookmarkStore(
                resolver: { _ in .init(url: fixture.root, isStale: false) },
                startAccessing: { _ in true },
                stopAccessing: { _ in }
            )
        )
        let stale = await staleDispatcher.dispatch(envelope(
            fixture.root,
            .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "ticket",
                revision: revision("c", checkout: .clean),
                expectations: [],
                expectedEvidenceRevision: 2
            )
        ))
        XCTAssertEqual(stale.error, .staleProjectRegistration)
    }

    private func makeFixture() async throws -> (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher) {
        let directory = URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
            .appendingPathComponent("release-radar-delivery-evidence-fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let root = directory.appendingPathComponent("repository")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: root.appendingPathComponent("AGENTS.md"))
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed delivery evidence fixture") { connection in
            try connection.execute("INSERT INTO projects (id,name) VALUES ('p','Project')")
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('p','evidence-registration',1,'complete')")
            try connection.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root','p',?)", bindings: [.text(root.path)])
            try connection.execute("INSERT INTO project_bookmarks (project_id,path,bookmark_data) VALUES ('p',?,X'01')", bindings: [.text(root.path)])
            try connection.execute("INSERT INTO phases (id,project_id,name) VALUES ('phase','p','Phase')")
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('ticket','p','phase','Outcome','needs_review')")
        }
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "p"),
            registrationID: "evidence-registration",
            requestGeneration: 1
        )
        let project = AuthorizedProject(registration: registration, canonicalRoot: root, authorizedRoots: [root])
        let bookmarks = ProjectBookmarkStore(
            resolver: { _ in .init(url: root, isStale: false) },
            startAccessing: { _ in true },
            stopAccessing: { _ in }
        )
        return (
            store,
            root,
            AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]),
                bookmarkStore: bookmarks
            )
        )
    }

    private func query(
        _ fixture: (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher)
    ) -> AgentQueryDispatcher {
        query(store: fixture.store, root: fixture.root)
    }

    private func query(store: DeliveryStore, root: URL) -> AgentQueryDispatcher {
        AgentQueryDispatcher(
            store: store,
            bookmarkStore: ProjectBookmarkStore(
                resolver: { _ in .init(url: root, isStale: false) },
                startAccessing: { _ in true },
                stopAccessing: { _ in }
            )
        )
    }

    private func documentationTarget(_ root: URL) throws -> DocumentationTarget {
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        return .init(
            projectID: "p",
            rootID: "root",
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest
        )
    }

    private func revision(
        _ character: Character,
        checkout: DeliveryEvidenceCheckoutState,
        snapshot: String? = nil
    ) -> DeliveryEvidenceRevision {
        .init(
            commitSHA: String(repeating: String(character), count: 40),
            checkoutState: checkout,
            dirtySnapshotID: snapshot
        )
    }

    private func observation(
        id: String,
        targetVersion: Int
    ) -> DeliveryEvidenceObservation {
        .init(
            id: id,
            targetVersion: targetVersion,
            fact: .check(.init(scope: "unit")),
            source: .init(kind: .localObservation, label: "Focused XCTest run"),
            sourceAvailability: .available,
            outcome: .passed,
            observedAt: "2026-09-10T18:00:00Z",
            recordedAt: "2026-09-10T18:01:00Z"
        )
    }

    private func envelope(
        _ root: URL,
        _ command: AgentCommand,
        requestID: UUID = UUID()
    ) -> AgentCommandEnvelope {
        .init(
            version: 1,
            requestID: requestID,
            projectRoot: root.path,
            assertedThreadID: "phase6c-test",
            expectedRegistration: .init(
                projectID: .init(rawValue: "p"),
                registrationID: "evidence-registration",
                requestGeneration: 1
            ),
            reason: "Authorized evidence operation",
            command: command
        )
    }
}

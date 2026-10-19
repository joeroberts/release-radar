import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class ProjectPermanentPurgeAcceptanceTests: XCTestCase {
    func testPreviewIdentifiesExactRemovedRegistrationAndDroppingItWritesNothing() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: true)
        let before = try await fixture.targetState(target)

        let preview = try await fixture.manager.preview(removalID: target.id)

        XCTAssertEqual(preview.removalID, target.id)
        XCTAssertEqual(preview.projectID, target.projectID)
        XCTAssertEqual(preview.registrationID, target.registration.registrationID)
        XCTAssertEqual(preview.requestGeneration, target.registration.requestGeneration)
        XCTAssertEqual(preview.removedAt, target.removedAt)

        // Cancelling is represented at the persistence boundary by discarding the
        // prepared preview without calling apply. Reopen the exact fixture to prove
        // preview preparation itself did not write.
        let reopened = DeliveryStore(
            databaseURL: fixture.databaseURL,
            executionAssignmentRoot: { fixture.executionRoot }
        )
        let after = try await fixture.targetState(target, store: reopened)
        XCTAssertEqual(after, before)

        do {
            _ = try await fixture.manager.preview(removalID: .init(rawValue: "missing-removal"))
            XCTFail("Expected an absent removed registration to be rejected")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .targetAbsent)
        }
    }

    func testPurgeErasesExactDatabaseAndExecutionIdentityWhilePreservingReplacementAndFiles() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: true)
        let otherRemoved = try await fixture.seedOtherRemovedProject()
        try fixture.seedRetiredExecutionMetadata(for: target)
        let replacementPolicyBefore = try fixture.files.policy(projectID: fixture.replacementProjectID.rawValue)
        let repositoryBytes = try Data(contentsOf: fixture.repositoryFile)
        let auditIDsBefore = try await fixture.auditIDs()

        let preview = try await fixture.manager.preview(removalID: target.id)
        _ = try await fixture.manager.apply(preview)

        let repeated = try await fixture.manager.apply(preview)
        XCTAssertEqual(repeated, .alreadyAbsent)

        try await fixture.assertTargetAbsent(target)
        try await fixture.store.read { connection in
            XCTAssertEqual(
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM removed_projects WHERE removal_id = ?",
                    bindings: [.text(otherRemoved.id.rawValue)]
                ),
                1
            )
            XCTAssertEqual(
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM projects WHERE id = ?",
                    bindings: [.text(fixture.replacementProjectID.rawValue)]
                ),
                1
            )
            XCTAssertEqual(
                try connection.scalarText(
                    "SELECT registration_id FROM project_registrations WHERE project_id = ?",
                    bindings: [.text(fixture.replacementProjectID.rawValue)]
                ),
                fixture.replacementRegistrationID
            )
            XCTAssertEqual(
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM agent_command_requests WHERE request_id = 'replacement-receipt'"
                ),
                1,
                "Receipt deletion must use structured registration identity, not byte-pattern matching"
            )
        }
        XCTAssertEqual(try Data(contentsOf: fixture.repositoryFile), repositoryBytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.preservedWorktreeFile.path))
        XCTAssertEqual(try Data(contentsOf: fixture.preservedWorktreeFile), Data("preserve worktree\n".utf8))

        XCTAssertNil(try fixture.files.policyIfPresent(projectID: target.projectID.rawValue))
        XCTAssertNil(try fixture.files.assignmentIfPresent(projectID: target.projectID.rawValue, taskID: "retired-target"))
        let replacementPolicyAfter = try fixture.files.policy(projectID: fixture.replacementProjectID.rawValue)
        XCTAssertEqual(replacementPolicyAfter.registration, replacementPolicyBefore.registration)
        XCTAssertEqual(replacementPolicyAfter.primaryRoot, replacementPolicyBefore.primaryRoot)
        XCTAssertEqual(replacementPolicyAfter.enabled, replacementPolicyBefore.enabled)
        XCTAssertFalse(replacementPolicyAfter.previousProjectIDs?.contains(target.projectID.rawValue) == true)

        let search = try await WorkspaceSearchPreferencesRepository(store: fixture.store).loadSavedQueries()
        guard case let .supported(saved)? = search.first(where: { $0.id == "purge-scope" }),
              case let .registrations(scope) = saved.definition.scope else {
            return XCTFail("Expected the supported saved query to remain readable")
        }
        XCTAssertEqual(scope, [
            .init(projectID: fixture.replacementProjectID, registrationID: fixture.replacementRegistrationID),
        ])

        let newAuditRows = try await fixture.auditRows(excluding: auditIDsBefore)
        XCTAssertEqual(newAuditRows.count, 1, "Successful purge must record exactly one generic audit event")
        let genericAudit = try XCTUnwrap(newAuditRows.first)
        for column in [
            "project_id", "historical_project_id", "historical_registration_id", "entity_type", "entity_id",
            "thread_id", "event_project_name", "event_registration_id", "event_request_generation",
            "event_ticket_id", "event_phase_id", "event_phase_name", "event_ticket_outcome",
        ] {
            XCTAssertEqual(genericAudit[column], .null, "Generic purge audit must not populate \(column)")
        }
        let forbidden = [
            target.id.rawValue, target.projectID.rawValue, target.projectName,
            target.registration.registrationID, fixture.repositoryRoot.path,
        ]
        for value in genericAudit.values {
            let text: String?
            switch value {
            case let .text(raw): text = raw
            case let .blob(raw): text = String(data: raw, encoding: .utf8)
            default: text = nil
            }
            for marker in forbidden {
                XCTAssertFalse(text?.contains(marker) == true, "Generic purge audit leaked target marker \(marker)")
            }
        }
        XCTAssertTrue((genericAudit["reason"]?.textValue ?? "").localizedCaseInsensitiveContains("purge"))

        let reopened = DeliveryStore(
            databaseURL: fixture.databaseURL,
            executionAssignmentRoot: { fixture.executionRoot }
        )
        do {
            _ = try await ProjectPermanentPurgeManager(store: reopened, executionStore: fixture.files)
                .preview(removalID: target.id)
            XCTFail("Purged registration reappeared after reopening")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .targetAbsent)
        }
    }

    func testChangedRetainedInventoryMakesPreviewStaleWithoutDeletingEitherRegistration() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: true)
        let otherRemoved = try await fixture.seedOtherRemovedProject()
        let preview = try await fixture.manager.preview(removalID: target.id)
        let auditIDsBefore = try await fixture.auditIDs()

        try fixture.appendRetainedActivity(removalID: target.id)

        do {
            _ = try await fixture.manager.apply(preview)
            XCTFail("Expected changed retained inventory to invalidate the prepared confirmation")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .stalePreview)
        }

        try await fixture.store.read { connection in
            XCTAssertEqual(
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM removed_projects WHERE removal_id IN (?, ?)",
                    bindings: [.text(target.id.rawValue), .text(otherRemoved.id.rawValue)]
                ),
                2
            )
            XCTAssertEqual(
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM retained_project_activity_events WHERE removal_id = ? AND source_id = 'late-retained-event'",
                    bindings: [.text(target.id.rawValue)]
                ),
                1
            )
        }
        let auditIDsAfter = try await fixture.auditIDs()
        XCTAssertEqual(auditIDsAfter, auditIDsBefore)
    }

    func testDatabaseFailureRollsBackRowsAndRestoresStagedExecutionMetadataWithoutAudit() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: true)
        try fixture.seedRetiredExecutionMetadata(for: target)
        let preview = try await fixture.manager.preview(removalID: target.id)
        let stateBefore = try await fixture.targetState(target)
        let paths = try ProjectExecutionPaths(
            storageRoot: fixture.executionRoot,
            projectID: target.projectID.rawValue,
            taskID: "retired-target"
        )
        let policyBefore = try Data(contentsOf: paths.projectPolicy)
        let assignmentBefore = try Data(contentsOf: paths.assignment)
        let auditIDsBefore = try await fixture.auditIDs()

        let fault = try SQLiteConnection(url: fixture.databaseURL)
        try fault.execute(
            """
            CREATE TRIGGER reject_permanent_purge
            BEFORE DELETE ON removed_projects
            WHEN OLD.removal_id = '\(target.id.rawValue)'
            BEGIN SELECT RAISE(ABORT, 'synthetic permanent purge failure'); END
            """
        )

        do {
            _ = try await fixture.manager.apply(preview)
            XCTFail("Expected injected database failure")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .databaseFailure)
        }

        let stateAfter = try await fixture.targetState(target)
        XCTAssertEqual(stateAfter, stateBefore)
        XCTAssertEqual(try Data(contentsOf: paths.projectPolicy), policyBefore)
        XCTAssertEqual(try Data(contentsOf: paths.assignment), assignmentBefore)
        let auditIDsAfter = try await fixture.auditIDs()
        XCTAssertEqual(auditIDsAfter, auditIDsBefore)
    }

    func testUnknownWorkerBlocksPurgeAndPreservesDatabaseAndAllFiles() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: true)
        try fixture.seedUnknownExecutionMetadata(for: target)
        let preview = try await fixture.manager.preview(removalID: target.id)
        let stateBefore = try await fixture.targetState(target)
        let paths = try ProjectExecutionPaths(
            storageRoot: fixture.executionRoot,
            projectID: target.projectID.rawValue,
            taskID: "unknown-target"
        )
        let policyBefore = try Data(contentsOf: paths.projectPolicy)
        let assignmentBefore = try Data(contentsOf: paths.assignment)
        let repositoryBytes = try Data(contentsOf: fixture.repositoryFile)
        let auditIDsBefore = try await fixture.auditIDs()

        do {
            _ = try await fixture.manager.apply(preview)
            XCTFail("Expected unresolved worker resources to block permanent purge")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .activeExecutionResources)
            XCTAssertTrue(error.localizedDescription.localizedCaseInsensitiveContains("worker"))
        }

        let stateAfter = try await fixture.targetState(target)
        XCTAssertEqual(stateAfter, stateBefore)
        XCTAssertEqual(try Data(contentsOf: paths.projectPolicy), policyBefore)
        XCTAssertEqual(try Data(contentsOf: paths.assignment), assignmentBefore)
        XCTAssertEqual(try Data(contentsOf: fixture.repositoryFile), repositoryBytes)
        let auditIDsAfter = try await fixture.auditIDs()
        XCTAssertEqual(auditIDsAfter, auditIDsBefore)
    }

    func testIncompleteProfileCleanupReceiptsBlockPermanentPurge() async throws {
        let cases: [(String, ProjectExecutionProfileCleanupReceipt.State,
            ProjectExecutionProfileCleanupReceipt.HelperClosureState?, Bool)] = [
            ("intent", .intentRecorded, .pending, true),
            ("unknown-effect", .outcomeUnknown, .unknown, true),
            ("audit-pending", .removalVerified, .verified, true),
            ("missing-helper-evidence", .removalVerified, nil, false),
            ("unknown-helper", .removalVerified, .unknown, false),
            ("pending-helper", .removalVerified, .pending, false),
        ]

        for scenario in cases {
            let fixture = try Fixture(testCase: self)
            let target = try await fixture.seedRemovedTarget(includeReplacement: true)
            try fixture.seedRetiredExecutionMetadata(for: target)
            try fixture.seedCleanupReceipt(for: target, state: scenario.1,
                helperClosureState: scenario.2, finalizationPending: scenario.3)
            let preview = try await fixture.manager.preview(removalID: target.id)

            do {
                _ = try await fixture.manager.apply(preview)
                XCTFail("Incomplete cleanup state \(scenario.0) must block permanent purge")
            } catch {
                XCTAssertEqual(error as? ProjectPermanentPurgeError, .activeExecutionResources,
                    "Unexpected error for \(scenario.0)")
            }

            XCTAssertNotNil(try fixture.files.assignmentIfPresent(
                projectID: target.projectID.rawValue, taskID: "retired-target"))
        }
    }

    func testVerifiedClosedAndAuditedProfileCleanupReceiptAllowsExistingPurgePath() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: true)
        try fixture.seedRetiredExecutionMetadata(for: target)
        try fixture.seedCleanupReceipt(for: target, state: .removalVerified,
            helperClosureState: .verified, finalizationPending: false)

        let preview = try await fixture.manager.preview(removalID: target.id)
        _ = try await fixture.manager.apply(preview)

        try await fixture.assertTargetAbsent(target)
        XCTAssertNil(try fixture.files.assignmentIfPresent(
            projectID: target.projectID.rawValue, taskID: "retired-target"))
    }

    func testMissingRepositoryDoesNotPreventPurgingRetainedRecords() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try FileManager.default.removeItem(at: fixture.repositoryRoot)

        let preview = try await fixture.manager.preview(removalID: target.id)
        _ = try await fixture.manager.apply(preview)

        try await fixture.assertTargetAbsent(target)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.repositoryRoot.path))
    }

    func testOpaqueSavedSearchBlocksPurgeWithoutWritingDatabaseOrFiles() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: true)
        try fixture.seedRetiredExecutionMetadata(for: target)
        let before = try await fixture.targetState(target)
        let repositoryBytes = try Data(contentsOf: fixture.repositoryFile)

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed opaque saved search") { connection in
            try connection.execute(
                "UPDATE workspace_saved_queries SET payload_version = 99, payload_data = ? WHERE id = 'purge-scope'",
                bindings: [.blob(Data("opaque \(target.registration.registrationID)".utf8))]
            )
        }
        let auditIDsBefore = try await fixture.auditIDs()

        do {
            _ = try await fixture.manager.preview(removalID: target.id)
            XCTFail("Expected an opaque saved-search payload to block permanent purge")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .unsupportedOpaqueData)
        }

        let after = try await fixture.targetState(target)
        XCTAssertEqual(after, before)
        XCTAssertEqual(try Data(contentsOf: fixture.repositoryFile), repositoryBytes)
        XCTAssertNotNil(try fixture.files.policyIfPresent(projectID: target.projectID.rawValue))
        XCTAssertNotNil(try fixture.files.assignmentIfPresent(projectID: target.projectID.rawValue, taskID: "retired-target"))
        let auditIDsAfter = try await fixture.auditIDs()
        XCTAssertEqual(auditIDsAfter, auditIDsBefore)
    }

    func testRetainedForeignKeyChildrenArePurgedBeforeTheirParents() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedRetainedForeignKeyGraph(for: target)

        _ = try await fixture.manager.apply(try await fixture.manager.preview(removalID: target.id))

        try await fixture.assertTargetAbsent(target)
    }

    func testPurgePreservesAuditForAnotherRegistrationSharingHistoricalProjectIdentity() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedSiblingRegistrationAudit(for: target)

        _ = try await fixture.manager.apply(try await fixture.manager.preview(removalID: target.id))

        try await fixture.store.read { connection in
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE id = 'sibling-registration-audit'"),
                1,
                "Historical project identity alone must not authorize deleting another registration's audit"
            )
        }
    }

    func testPurgeRemovesReceiptsAndTerminalAssignmentsAcrossRegistrationGenerations() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedRetiredExecutionMetadata(for: target)
        try fixture.seedTerminalAssignment(for: target, generation: 3, taskID: "older-terminal-target")
        try await fixture.seedReceipt(for: target, generation: 3, requestID: "older-generation-receipt")

        let preview = try await fixture.manager.preview(removalID: target.id)
        XCTAssertEqual(preview.inventory.executionAssignmentCount, 2)
        XCTAssertEqual(preview.inventory.commandReceiptCount, 2)

        _ = try await fixture.manager.apply(preview)

        XCTAssertNil(
            try fixture.files.assignmentIfPresent(
                projectID: target.projectID.rawValue,
                taskID: "older-terminal-target"
            )
        )
        try await fixture.store.read { connection in
            XCTAssertEqual(
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM agent_command_requests WHERE registration_project_id = ? AND registration_id = ?",
                    bindings: [.text(target.projectID.rawValue), .text(target.registration.registrationID)]
                ),
                0
            )
        }
    }

    func testOlderGenerationUnknownWorkerBlocksPurgeAndPreservesAllState() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedUnknownAssignment(for: target, generation: 3, taskID: "older-unknown-target")
        let before = try await fixture.targetState(target)

        let preview = try await fixture.manager.preview(removalID: target.id)
        XCTAssertEqual(preview.inventory.executionAssignmentCount, 1)
        do {
            _ = try await fixture.manager.apply(preview)
            XCTFail("Expected an unresolved worker from an older generation of the registration to block purge")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .activeExecutionResources)
        }

        let after = try await fixture.targetState(target)
        XCTAssertEqual(after, before)
        XCTAssertNotNil(
            try fixture.files.assignmentIfPresent(
                projectID: target.projectID.rawValue,
                taskID: "older-unknown-target"
            )
        )
    }

    func testLegacyReceiptMappedToTargetAuditIsPurged() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try await fixture.seedLegacyReceipt(
            requestID: "mapped-legacy-receipt",
            resultData: JSONEncoder().encode(AuditEventID(rawValue: "purge-target-audit"))
        )

        _ = try await fixture.manager.apply(try await fixture.manager.preview(removalID: target.id))

        try await fixture.store.read { connection in
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = 'mapped-legacy-receipt'"),
                0
            )
        }
    }

    func testOpaqueLegacyReceiptBlocksPurgeWithoutWrites() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try await fixture.seedLegacyReceipt(
            requestID: "opaque-legacy-receipt",
            resultData: Data("not-an-audit-identity".utf8)
        )
        let before = try await fixture.targetState(target)
        let auditIDsBefore = try await fixture.auditIDs()

        do {
            _ = try await fixture.manager.preview(removalID: target.id)
            XCTFail("Expected an unscoped legacy receipt to make permanent purge ambiguous")
        } catch {
            XCTAssertEqual(error as? ProjectPermanentPurgeError, .unsupportedOpaqueData)
        }

        let after = try await fixture.targetState(target)
        let auditIDsAfter = try await fixture.auditIDs()
        XCTAssertEqual(after, before)
        XCTAssertEqual(auditIDsAfter, auditIDsBefore)
        try await fixture.store.read { connection in
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = 'opaque-legacy-receipt'"),
                1
            )
        }
    }

    func testLivePurgeLeaseCannotBeRecoveredAsAnAbandonedOperation() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedRetiredExecutionMetadata(for: target)
        let preview = try await fixture.manager.preview(removalID: target.id)
        let lease = try fixture.files.stagePermanentPurge(
            removalID: target.id,
            expected: preview.executionInventory
        )
        let recoveringStore = try ProjectExecutionFileStore(root: fixture.executionRoot, create: false)
        let pending = try XCTUnwrap(recoveringStore.pendingPermanentPurgeStages().first)

        XCTAssertNil(
            try recoveringStore.recoverPermanentPurgeLease(pending),
            "Recovery must skip a stage whose originating purge still owns it"
        )
        XCTAssertNil(try fixture.files.policyIfPresent(projectID: target.projectID.rawValue))

        try fixture.files.restorePermanentPurge(lease)
        XCTAssertNotNil(try fixture.files.policyIfPresent(projectID: target.projectID.rawValue))
    }

    func testAbandonedPurgeStageCanBeAdoptedAndRestored() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedRetiredExecutionMetadata(for: target)
        let preview = try await fixture.manager.preview(removalID: target.id)
        var originalLease: ProjectExecutionPurgeLease? = try fixture.files.stagePermanentPurge(
            removalID: target.id,
            expected: preview.executionInventory
        )
        let stage = try XCTUnwrap(originalLease).stage
        originalLease = nil

        let recoveringStore = try ProjectExecutionFileStore(root: fixture.executionRoot, create: false)
        let recovered = try XCTUnwrap(recoveringStore.recoverPermanentPurgeLease(stage))
        try recoveringStore.restorePermanentPurge(recovered)

        XCTAssertNotNil(try fixture.files.policyIfPresent(projectID: target.projectID.rawValue))
        XCTAssertNotNil(
            try fixture.files.assignmentIfPresent(
                projectID: target.projectID.rawValue,
                taskID: "retired-target"
            )
        )
        XCTAssertTrue(try fixture.files.pendingPermanentPurgeStages().isEmpty)
    }

    func testFinalizationToleratesAlreadyRemovedTargetMetadataAncestors() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedRetiredExecutionMetadata(for: target)
        let preview = try await fixture.manager.preview(removalID: target.id)
        let lease = try fixture.files.stagePermanentPurge(
            removalID: target.id,
            expected: preview.executionInventory
        )
        let targetAssignments = fixture.executionRoot
            .appendingPathComponent("Assignments", isDirectory: true)
            .appendingPathComponent(target.projectID.rawValue, isDirectory: true)
        let targetPolicy = fixture.executionRoot
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(target.projectID.rawValue, isDirectory: true)
        try FileManager.default.removeItem(at: targetAssignments)
        try FileManager.default.removeItem(at: targetPolicy)

        try fixture.files.finalizePermanentPurge(lease)

        XCTAssertTrue(try fixture.files.pendingPermanentPurgeStages().isEmpty)
    }

    func testFinalizationDoesNotReportSuccessWhileTargetMetadataRemnantsRemain() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        try fixture.seedRetiredExecutionMetadata(for: target)
        let preview = try await fixture.manager.preview(removalID: target.id)
        let lease = try fixture.files.stagePermanentPurge(
            removalID: target.id,
            expected: preview.executionInventory
        )
        let remnant = fixture.executionRoot
            .appendingPathComponent("Assignments", isDirectory: true)
            .appendingPathComponent(target.projectID.rawValue, isDirectory: true)
            .appendingPathComponent("retired-target", isDirectory: true)
            .appendingPathComponent("identifying-remnant.txt")
        try Data(target.registration.registrationID.utf8).write(to: remnant)

        XCTAssertThrowsError(try fixture.files.finalizePermanentPurge(lease))
        XCTAssertTrue(FileManager.default.fileExists(atPath: remnant.path))
        XCTAssertEqual(
            try fixture.files.pendingPermanentPurgeStages().map(\.id),
            [lease.stage.id],
            "A recoverable manifest must remain until identifying metadata is completely removed"
        )
    }

    func testStoreTransactionFailsFastInsteadOfWaitingBehindPurgeFilesystemLease() async throws {
        let fixture = try Fixture(testCase: self)
        let target = try await fixture.seedRemovedTarget(includeReplacement: false)
        let replacement = try await fixture.seedSameProjectIdentityReplacement(for: target)
        let replacementRemoval = ProjectRemovalManager(store: fixture.store)
        let replacementPreview = try await replacementRemoval.preview(projectID: replacement.projectID)
        let purgePreview = try await fixture.manager.preview(removalID: target.id)
        var purgeLease: ProjectExecutionPurgeLease? = try fixture.files.stagePermanentPurge(
            removalID: target.id,
            expected: purgePreview.executionInventory
        )
        let outcome = OperationOutcomeProbe()
        let removalTask = Task {
            do {
                _ = try await replacementRemoval.apply(replacementPreview)
                await outcome.record("succeeded")
            } catch {
                await outcome.record("failed")
            }
        }

        try await Task.sleep(for: .milliseconds(500))
        let earlyOutcome = await outcome.value
        XCTAssertEqual(
            earlyOutcome,
            "failed",
            "A store transaction that cannot obtain purge-owned metadata locks must fail fast instead of blocking the store actor"
        )

        try fixture.files.restorePermanentPurge(try XCTUnwrap(purgeLease))
        purgeLease = nil
        _ = await removalTask.result
    }
}

private extension ProjectPermanentPurgeAcceptanceTests {
    struct TargetState: Equatable {
        let removalTableCounts: [String: Int64]
        let identifyingAuditCount: Int64
        let structuredReceiptCount: Int64
    }

    struct Fixture {
        let databaseURL: URL
        let executionRoot: URL
        let repositoryRoot: URL
        let replacementBootstrapRoot: URL
        let repositoryFile: URL
        let preservedWorktreeFile: URL
        let store: DeliveryStore
        let files: ProjectExecutionFileStore
        let targetProjectID = ProjectID(rawValue: "purge-target-project")
        let targetRegistrationID = "purge-target-registration"
        let replacementProjectID = ProjectID(rawValue: "purge-replacement-project")
        let replacementRegistrationID = "purge-replacement-registration"

        var manager: ProjectPermanentPurgeManager {
            ProjectPermanentPurgeManager(store: store, executionStore: files)
        }

        init(testCase: XCTestCase) throws {
            let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
                .appendingPathComponent("ReleaseRadar-PermanentPurge-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            testCase.addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

            databaseURL = directory.appendingPathComponent("fixture.sqlite")
            let fixtureExecutionRoot = directory.appendingPathComponent("Execution", isDirectory: true)
            executionRoot = fixtureExecutionRoot
            repositoryRoot = directory.appendingPathComponent("Repository", isDirectory: true)
            replacementBootstrapRoot = directory.appendingPathComponent("ReplacementRepository", isDirectory: true)
            repositoryFile = repositoryRoot.appendingPathComponent("owner.txt")
            preservedWorktreeFile = executionRoot
                .appendingPathComponent("Worktrees/preserved-other/worktree.txt")
            try FileManager.default.createDirectory(at: repositoryRoot, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: replacementBootstrapRoot, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: preservedWorktreeFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("repository content\n".utf8).write(to: repositoryFile)
            try Data("preserve worktree\n".utf8).write(to: preservedWorktreeFile)

            store = DeliveryStore(
                databaseURL: databaseURL,
                executionAssignmentRoot: { fixtureExecutionRoot }
            )
            files = try ProjectExecutionFileStore(root: fixtureExecutionRoot, create: true)
        }

        func seedRemovedTarget(includeReplacement: Bool) async throws -> RemovedProjectRecord {
            let targetProjectID = targetProjectID
            let replacementProjectID = replacementProjectID
            let replacementBootstrapRoot = replacementBootstrapRoot
            try await store.transact(actor: .init(id: "fixture"), reason: "Seed purge registrations") { connection in
                try connection.execute(
                    "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Historical Purge Target', 1)",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, 7, 'complete')",
                    bindings: [.text(targetProjectID.rawValue), .text(targetRegistrationID)]
                )
                try connection.execute(
                    "INSERT INTO project_roots (id, project_id, path) VALUES ('purge-root', ?, ?)",
                    bindings: [.text(targetProjectID.rawValue), .text(repositoryRoot.path)]
                )
                try connection.execute(
                    "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)",
                    bindings: [
                        .text(targetProjectID.rawValue), .text(repositoryRoot.path),
                        .blob(Data(repositoryRoot.path.utf8)),
                    ]
                )
                if includeReplacement {
                    try connection.execute(
                        "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Current Same Root', 1)",
                        bindings: [.text(replacementProjectID.rawValue)]
                    )
                    try connection.execute(
                        "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, 2, 'complete')",
                        bindings: [.text(replacementProjectID.rawValue), .text(replacementRegistrationID)]
                    )
                    try connection.execute(
                        "INSERT INTO project_roots (id, project_id, path) VALUES ('replacement-root', ?, ?)",
                        bindings: [.text(replacementProjectID.rawValue), .text(replacementBootstrapRoot.path)]
                    )
                    try connection.execute(
                        "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at, registration_project_id, registration_id, request_generation) VALUES ('replacement-receipt', ?, ?, '2026-10-18T00:06:00Z', ?, ?, 2)",
                        bindings: [
                            .blob(Data("payload mentions \(targetRegistrationID) but belongs to replacement".utf8)),
                            .blob(Data("replacement result".utf8)),
                            .text(replacementProjectID.rawValue), .text(replacementRegistrationID),
                        ]
                    )
                }
            }
            try await store.transact(
                actor: .init(id: "fixture", threadID: "purge-target-thread", threadAttribution: .asserted),
                reason: "Seed identifying target history",
                auditEventID: .init(rawValue: "purge-target-audit"),
                auditScope: .init(projectID: targetProjectID, entityType: .project, entityID: targetProjectID.rawValue)
            ) { connection in
                try connection.execute(
                    "INSERT INTO phases (id, project_id, name) VALUES ('purge-phase', ?, 'Purge phase')",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('purge-ticket', ?, 'purge-phase', 'Purge outcome', 'backlog')",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES ('purge-evidence', ?, 'purge-ticket', ?, 1)",
                    bindings: [.text(targetProjectID.rawValue), .text(repositoryFile.path)]
                )
                try connection.execute(
                    "INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('purge-thread', ?, 'completed', '2026-10-18T00:00:00Z')",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('purge-goal', ?, 'purge-thread', 'Completed', 'Target history', '2026-10-18T00:01:00Z')",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('purge-review', ?, 'purge-ticket', 'completion', 'Target review', 'resolved')",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES ('purge-completion', ?, 'purge-ticket', 'Target completion', '2026-10-18T00:02:00Z')",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO notification_events (id, fingerprint, state, project_id, event_kind, subject_id, occurrence, title, message, created_at, completed_at, attempt_count) VALUES ('purge-notification', 'purge-notification-fingerprint', 'sent', ?, 'review_requested', 'purge-review', 1, 'Target notice', 'Target notification', '2026-10-18T00:03:00Z', '2026-10-18T00:04:00Z', 1)",
                    bindings: [.text(targetProjectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at, registration_project_id, registration_id, request_generation) VALUES ('target-receipt', ?, ?, '2026-10-18T00:05:00Z', ?, ?, 7)",
                    bindings: [
                        .blob(Data("target receipt".utf8)), .blob(Data("target result".utf8)),
                        .text(targetProjectID.rawValue), .text(targetRegistrationID),
                    ]
                )
            }

            if includeReplacement {
                let scope = [
                    WorkspaceSearchRegistrationIdentity(projectID: targetProjectID, registrationID: targetRegistrationID),
                    WorkspaceSearchRegistrationIdentity(projectID: replacementProjectID, registrationID: replacementRegistrationID),
                ]
                let repository = WorkspaceSearchPreferencesRepository(store: store)
                try await repository.saveWorkingDefinition(.init(text: "target", scope: .registrations(scope)))
                _ = try await repository.saveQuery(
                    id: "purge-scope",
                    name: "Purge scope",
                    definition: .init(text: "target", scope: .registrations(scope))
                )
            }

            let removal = ProjectRemovalManager(store: store)
            let removed = try await removal.apply(try await removal.preview(projectID: targetProjectID))

            if includeReplacement {
                try await store.transact(actor: .init(id: "fixture"), reason: "Reuse removed project root") { connection in
                    try connection.execute(
                        "UPDATE project_roots SET path = ? WHERE project_id = ? AND id = 'replacement-root'",
                        bindings: [.text(repositoryRoot.path), .text(replacementProjectID.rawValue)]
                    )
                }
            }
            return removed
        }

        func seedSameProjectIdentityReplacement(for target: RemovedProjectRecord) async throws -> ProjectRegistration {
            let registration = ProjectRegistration(
                projectID: target.projectID,
                registrationID: "purge-newer-registration",
                requestGeneration: target.registration.requestGeneration + 1
            )
            try await store.transact(actor: .init(id: "fixture"), reason: "Seed reused project identity") { connection in
                try connection.execute(
                    "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Current Reused Identity', 1)",
                    bindings: [.text(registration.projectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, ?, 'complete')",
                    bindings: [
                        .text(registration.projectID.rawValue), .text(registration.registrationID),
                        .integer(registration.requestGeneration),
                    ]
                )
                try connection.execute(
                    "INSERT INTO project_roots (id, project_id, path) VALUES ('reused-identity-root', ?, ?)",
                    bindings: [.text(registration.projectID.rawValue), .text(repositoryRoot.path)]
                )
            }
            try files.savePolicy(
                .init(
                    registration: registration,
                    primaryRoot: repositoryRoot.path,
                    appServerExecutable: CodexExecutionIdentity.executable,
                    handlerPath: "/fixture/release-radar-handler"
                ),
                expected: nil
            )
            return registration
        }

        func seedOtherRemovedProject() async throws -> RemovedProjectRecord {
            let projectID = ProjectID(rawValue: "other-removed-project")
            try await store.transact(actor: .init(id: "fixture"), reason: "Seed other removed registration") { connection in
                try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Other Removed')", bindings: [.text(projectID.rawValue)])
                try connection.execute(
                    "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'other-removed-registration', 1, 'complete')",
                    bindings: [.text(projectID.rawValue)]
                )
            }
            let removal = ProjectRemovalManager(store: store)
            return try await removal.apply(try await removal.preview(projectID: projectID))
        }

        func seedRetiredExecutionMetadata(for target: RemovedProjectRecord) throws {
            var targetPolicy = ProjectExecutionPolicy(
                registration: target.registration,
                primaryRoot: repositoryRoot.path,
                appServerExecutable: CodexExecutionIdentity.executable,
                handlerPath: "/fixture/release-radar-handler",
                enabled: false
            )
            targetPolicy.consent = .init()
            try files.savePolicy(targetPolicy, expected: nil)

            let paths = try ProjectExecutionPaths(
                storageRoot: executionRoot,
                projectID: target.projectID.rawValue,
                taskID: "retired-target"
            )
            var assignment = ProjectExecutionAssignment(
                id: "retired-target",
                registration: target.registration,
                checkoutPath: paths.checkout.path,
                role: .delivery,
                permissionProfile: "purge-retired-profile",
                model: "gpt-5.6-terra",
                effort: "medium",
                authorization: "Fixture-only retired assignment",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                state: .superseded
            )
            assignment.connectionClosed = true
            assignment.retirement = .init(requestID: UUID(), priorState: .revoked)
            assignment.retirement?.worktreeRemoved = true
            assignment.retirement?.profileRemoved = true
            assignment.retirement?.completed = true
            try files.saveAssignment(assignment, expected: nil)

            var replacementPolicy = ProjectExecutionPolicy(
                registration: .init(
                    projectID: replacementProjectID,
                    registrationID: replacementRegistrationID,
                    requestGeneration: 2
                ),
                primaryRoot: repositoryRoot.path,
                appServerExecutable: CodexExecutionIdentity.executable,
                handlerPath: "/fixture/release-radar-handler",
                enabled: true
            )
            replacementPolicy.previousProjectIDs = [target.projectID.rawValue]
            try files.savePolicy(replacementPolicy, expected: nil)
        }

        func seedCleanupReceipt(
            for target: RemovedProjectRecord,
            state: ProjectExecutionProfileCleanupReceipt.State,
            helperClosureState: ProjectExecutionProfileCleanupReceipt.HelperClosureState?,
            finalizationPending: Bool
        ) throws {
            let existing = try files.assignment(
                projectID: target.projectID.rawValue, taskID: "retired-target")
            var assignment = existing
            let contextID = UUID(uuidString: "19600000-0000-0000-0000-000000000001")!
            let definition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
            assignment.codexContextID = contextID
            assignment.permissionProfileDefinition = definition
            let acknowledgement: ProjectExecutionProfileCleanupReceipt.Acknowledgement
            let presence: ProjectExecutionProfileCleanupReceipt.TargetPresence
            let observedVersion: String?
            switch state {
            case .intentRecorded:
                acknowledgement = .notAttempted
                presence = .present
                observedVersion = nil
            case .outcomeUnknown:
                acknowledgement = .unknown
                presence = .unavailable
                observedVersion = nil
            case .removalVerified:
                acknowledgement = .acknowledged
                presence = .absent
                observedVersion = "after-v2"
            }
            assignment.profileCleanupReceipt = .init(
                requestID: UUID(), profileID: assignment.permissionProfile,
                selectedCodexContextID: contextID, configurationVersion: "before-v1",
                expectedDefinition: definition, state: state,
                acknowledgement: acknowledgement, observedTargetPresence: presence,
                observedConfigurationVersion: observedVersion,
                helperClosureState: helperClosureState,
                configurationSessionID: helperClosureState == nil ? nil
                    : UUID(uuidString: "19600000-0000-0000-0000-000000000002")!,
                finalizationPending: finalizationPending)
            try files.saveAssignment(assignment, expected: existing)
        }

        func seedUnknownExecutionMetadata(for target: RemovedProjectRecord) throws {
            var targetPolicy = ProjectExecutionPolicy(
                registration: target.registration,
                primaryRoot: repositoryRoot.path,
                appServerExecutable: CodexExecutionIdentity.executable,
                handlerPath: "/fixture/release-radar-handler",
                enabled: false
            )
            targetPolicy.consent = .init()
            try files.savePolicy(targetPolicy, expected: nil)
            let paths = try ProjectExecutionPaths(
                storageRoot: executionRoot,
                projectID: target.projectID.rawValue,
                taskID: "unknown-target"
            )
            var assignment = ProjectExecutionAssignment(
                id: "unknown-target",
                registration: target.registration,
                checkoutPath: paths.checkout.path,
                role: .delivery,
                permissionProfile: "purge-unknown-profile",
                model: "gpt-5.6-terra",
                effort: "medium",
                authorization: "Fixture-only unresolved assignment",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "b", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                state: .unknown,
                sessionID: "fixture-session"
            )
            assignment.launchReserved = true
            assignment.uncertainOutcome = true
            try files.saveAssignment(assignment, expected: nil)
        }

        func seedTerminalAssignment(
            for target: RemovedProjectRecord,
            generation: Int64,
            taskID: String
        ) throws {
            let registration = ProjectRegistration(
                projectID: target.projectID,
                registrationID: target.registration.registrationID,
                requestGeneration: generation
            )
            let paths = try ProjectExecutionPaths(
                storageRoot: executionRoot,
                projectID: target.projectID.rawValue,
                taskID: taskID
            )
            var assignment = ProjectExecutionAssignment(
                id: taskID,
                registration: registration,
                checkoutPath: paths.checkout.path,
                role: .delivery,
                permissionProfile: "purge-older-terminal-profile",
                model: "gpt-5.6-terra",
                effort: "medium",
                authorization: "Fixture-only older terminal assignment",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "c", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                state: .superseded
            )
            assignment.connectionClosed = true
            assignment.retirement = .init(requestID: UUID(), priorState: .revoked)
            assignment.retirement?.worktreeRemoved = true
            assignment.retirement?.profileRemoved = true
            assignment.retirement?.completed = true
            try files.saveAssignment(assignment, expected: nil)
        }

        func seedUnknownAssignment(
            for target: RemovedProjectRecord,
            generation: Int64,
            taskID: String
        ) throws {
            let registration = ProjectRegistration(
                projectID: target.projectID,
                registrationID: target.registration.registrationID,
                requestGeneration: generation
            )
            let paths = try ProjectExecutionPaths(
                storageRoot: executionRoot,
                projectID: target.projectID.rawValue,
                taskID: taskID
            )
            var assignment = ProjectExecutionAssignment(
                id: taskID,
                registration: registration,
                checkoutPath: paths.checkout.path,
                role: .delivery,
                permissionProfile: "purge-older-unknown-profile",
                model: "gpt-5.6-terra",
                effort: "medium",
                authorization: "Fixture-only unresolved older assignment",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "d", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                state: .unknown,
                sessionID: "older-fixture-session"
            )
            assignment.launchReserved = true
            assignment.uncertainOutcome = true
            try files.saveAssignment(assignment, expected: nil)
        }

        func seedReceipt(
            for target: RemovedProjectRecord,
            generation: Int64,
            requestID: String
        ) async throws {
            try await store.transact(actor: .init(id: "fixture"), reason: "Seed older registration receipt") { connection in
                try connection.execute(
                    "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at, registration_project_id, registration_id, request_generation) VALUES (?, ?, ?, '2026-10-18T00:07:00Z', ?, ?, ?)",
                    bindings: [
                        .text(requestID), .blob(Data("older request".utf8)), .blob(Data("older result".utf8)),
                        .text(target.projectID.rawValue), .text(target.registration.registrationID), .integer(generation),
                    ]
                )
            }
        }

        func seedLegacyReceipt(requestID: String, resultData: Data) async throws {
            try await store.transact(actor: .init(id: "fixture"), reason: "Seed legacy receipt") { connection in
                try connection.execute(
                    "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES (?, ?, ?, '2026-10-18T00:08:00Z')",
                    bindings: [.text(requestID), .blob(Data("legacy request".utf8)), .blob(resultData)]
                )
            }
        }

        func seedSiblingRegistrationAudit(for target: RemovedProjectRecord) throws {
            let connection = try SQLiteConnection(url: databaseURL)
            try connection.execute(
                """
                INSERT INTO audit_events (
                    id, actor_id, reason, created_at, historical_project_id,
                    historical_registration_id, event_facts_recorded, event_provenance,
                    event_registration_id, event_request_generation
                ) VALUES (
                    'sibling-registration-audit', 'fixture', 'Sibling registration event',
                    '2026-10-18T00:09:00Z', ?, 'sibling-registration', 1,
                    'local_audit', 'sibling-registration', 1
                )
                """,
                bindings: [.text(target.projectID.rawValue)]
            )
        }

        func seedRetainedForeignKeyGraph(for target: RemovedProjectRecord) throws {
            let connection = try SQLiteConnection(url: databaseURL)
            try connection.execute("BEGIN IMMEDIATE TRANSACTION")
            do {
                try connection.withTransactionCallbackRestrictions(allowProjectRemovalHistoryWrites: true) {
                    let identity: [SQLiteValue] = [
                        .text(target.id.rawValue), .text(target.projectID.rawValue),
                    ]
                    try connection.execute(
                        """
                        INSERT INTO retained_ticket_reference_links (
                            removal_id, historical_project_id, ticket_id, link_id, kind,
                            repository_id, artifact_id, current_version, relationship,
                            link_set_revision, created_at, updated_at
                        ) VALUES (?, ?, 'purge-ticket', 'retained-link', 'requirement',
                            'fixture-repository', 'fixture-artifact', 1, 'current', 1,
                            '2026-10-18T00:10:00Z', '2026-10-18T00:10:00Z')
                        """,
                        bindings: identity
                    )
                    try connection.execute(
                        """
                        INSERT INTO retained_ticket_reference_versions (
                            removal_id, historical_project_id, ticket_id, link_id, version,
                            content_digest, catalog_version, catalog_digest, observed_path,
                            observed_lifecycle, observed_authority, created_at
                        ) VALUES (?, ?, 'purge-ticket', 'retained-link', 1,
                            'content-digest', 1, 'catalog-digest', 'Requirements.md',
                            'accepted', 'owner', '2026-10-18T00:10:01Z')
                        """,
                        bindings: identity
                    )
                    try connection.execute(
                        """
                        INSERT INTO retained_plan_change_proposals (
                            removal_id, historical_project_id, proposal_id, current_version,
                            created_at, updated_at
                        ) VALUES (?, ?, 'retained-proposal', 1,
                            '2026-10-18T00:11:00Z', '2026-10-18T00:11:00Z')
                        """,
                        bindings: identity
                    )
                    try connection.execute(
                        """
                        INSERT INTO retained_plan_change_proposal_versions (
                            removal_id, historical_project_id, proposal_id, version,
                            registration_id, request_generation, baseline_digest,
                            baseline_data, operations_data, diff_data, source_impacts_data,
                            rationale, created_at
                        ) VALUES (?, ?, 'retained-proposal', 1, ?, 7, 'baseline-digest',
                            ?, ?, ?, ?, 'Retained proposal', '2026-10-18T00:11:01Z')
                        """,
                        bindings: identity + [
                            .text(target.registration.registrationID),
                            .blob(Data("baseline".utf8)), .blob(Data("operations".utf8)),
                            .blob(Data("diff".utf8)), .blob(Data("impacts".utf8)),
                        ]
                    )
                    try connection.execute(
                        """
                        INSERT INTO retained_plan_change_proposal_decisions (
                            removal_id, historical_project_id, proposal_id, version, id,
                            disposition, baseline_digest, registration_id,
                            request_generation, actor_id, created_at
                        ) VALUES (?, ?, 'retained-proposal', 1, 'retained-decision',
                            'approved', 'baseline-digest', ?, 7, 'fixture',
                            '2026-10-18T00:11:02Z')
                        """,
                        bindings: identity + [.text(target.registration.registrationID)]
                    )
                    try connection.execute(
                        """
                        INSERT INTO retained_plan_change_proposal_applications (
                            removal_id, historical_project_id, proposal_id, version, id,
                            decision_id, audit_event_id, applied_at
                        ) VALUES (?, ?, 'retained-proposal', 1, 'retained-application',
                            'retained-decision', 'purge-target-audit', '2026-10-18T00:11:03Z')
                        """,
                        bindings: identity
                    )
                    try connection.execute(
                        """
                        INSERT INTO retained_phase_lifecycle_events (
                            removal_id, historical_project_id, phase_id, revision,
                            previous_lifecycle, current_lifecycle, action, reason,
                            audit_event_id, registration_id, request_generation, created_at
                        ) VALUES (?, ?, 'purge-phase', 1, 'unassessed', 'in_progress',
                            'start', 'Retained lifecycle event', 'purge-target-audit', ?, 7,
                            '2026-10-18T00:12:00Z')
                        """,
                        bindings: identity + [.text(target.registration.registrationID)]
                    )
                }
                try connection.execute("COMMIT")
            } catch {
                try? connection.execute("ROLLBACK")
                throw error
            }
        }

        func appendRetainedActivity(removalID: ProjectRemovalID) throws {
            let connection = try SQLiteConnection(url: databaseURL)
            try connection.execute("BEGIN IMMEDIATE TRANSACTION")
            do {
                try connection.withTransactionCallbackRestrictions(allowProjectRemovalHistoryWrites: true) {
                    try connection.execute(
                        "INSERT INTO retained_project_activity_events (removal_id, source, source_id, title, detail) VALUES (?, 'runtime', 'late-retained-event', 'Late event', 'Changed after preview')",
                        bindings: [.text(removalID.rawValue)]
                    )
                }
                try connection.execute("COMMIT")
            } catch {
                try? connection.execute("ROLLBACK")
                throw error
            }
        }

        func targetState(_ target: RemovedProjectRecord, store selectedStore: DeliveryStore? = nil) async throws -> TargetState {
            let selectedStore = selectedStore ?? store
            return try await selectedStore.read { connection in
                var counts: [String: Int64] = [:]
                for table in Self.removalTables {
                    counts[table] = try connection.scalarInt(
                        "SELECT COUNT(*) FROM \(table) WHERE removal_id = ?",
                        bindings: [.text(target.id.rawValue)]
                    ) ?? 0
                }
                return TargetState(
                    removalTableCounts: counts,
                    identifyingAuditCount: try connection.scalarInt(
                        "SELECT COUNT(*) FROM audit_events WHERE historical_project_id = ? OR historical_registration_id = ? OR event_registration_id = ?",
                        bindings: [
                            .text(target.projectID.rawValue), .text(target.registration.registrationID),
                            .text(target.registration.registrationID),
                        ]
                    ) ?? 0,
                    structuredReceiptCount: try connection.scalarInt(
                        "SELECT COUNT(*) FROM agent_command_requests WHERE registration_project_id = ? AND registration_id = ?",
                        bindings: [.text(target.projectID.rawValue), .text(target.registration.registrationID)]
                    ) ?? 0
                )
            }
        }

        private static let removalTables = [
            "removed_projects",
            "retained_project_activity_events",
            "retained_delivery_goal_assignment_events",
            "retained_ticket_reference_links",
            "retained_ticket_reference_versions",
            "retained_plan_change_proposals",
            "retained_plan_change_proposal_versions",
            "retained_plan_change_proposal_decisions",
            "retained_plan_change_proposal_applications",
            "retained_ticket_retirements",
            "retained_ticket_successor_links",
            "retained_delivery_goal_obligations",
            "retained_delivery_goal_obligation_lineage",
            "retained_delivery_goal_obligation_drops",
            "retained_phase_lifecycles",
            "retained_phase_lifecycle_events",
            "retained_ticket_delivery_evidence_targets",
            "retained_ticket_delivery_evidence_observations",
        ]

        func assertTargetAbsent(_ target: RemovedProjectRecord) async throws {
            let state = try await targetState(target)
            XCTAssertTrue(state.removalTableCounts.values.allSatisfy { $0 == 0 }, "Retained removal rows remain: \(state.removalTableCounts)")
            XCTAssertEqual(state.identifyingAuditCount, 0)
            XCTAssertEqual(state.structuredReceiptCount, 0)
        }

        func auditIDs() async throws -> Set<String> {
            try await store.read { connection in
                Set(try connection.rows("SELECT id FROM audit_events", maximum: 10_000).compactMap {
                    guard case let .text(id)? = $0["id"] else { return nil }
                    return id
                })
            }
        }

        func auditRows(excluding prior: Set<String>) async throws -> [[String: SQLiteValue]] {
            try await store.read { connection in
                try connection.rows("SELECT * FROM audit_events", maximum: 10_000).filter {
                    guard case let .text(id)? = $0["id"] else { return false }
                    return !prior.contains(id)
                }
            }
        }
    }
}

private actor OperationOutcomeProbe {
    private(set) var value: String?

    func record(_ value: String) {
        self.value = value
    }
}

private extension SQLiteValue {
    var textValue: String? {
        guard case let .text(value) = self else { return nil }
        return value
    }
}

import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionStoreTests: XCTestCase {
    func testProfileProvisioningReceiptRoundTripsWithoutAdoptingLegacyAssignment() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"),
            registrationID: "registration-one", requestGeneration: 1)
        var assignment = ProjectExecutionAssignment(id: "delivery-receipt", registration: registration,
            checkoutPath: "/Worktrees/project-one/delivery-receipt", role: .delivery,
            permissionProfile: "rr-delivery-receipt", model: "gpt-5.6-terra", effort: "medium",
            authorization: "Approved work", context: [.init(path: "AGENTS.md",
                digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .preparing)
        assignment.permissionProfileDefinition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
        try store.saveAssignment(assignment, expected: nil)
        XCTAssertNil(try store.assignment(projectID: "project-one", taskID: assignment.id)
            .profileProvisioningReceipt, "A legacy assignment without a receipt remains unknown, not verified")

        var pending = assignment
        let requestedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        pending.profileProvisioningReceipt = .init(state: .pending, provenance: .newlyPrepared,
            requestedAt: requestedAt, verifiedAt: nil)
        try store.saveAssignment(pending, expected: assignment)

        let reopened = try ProjectExecutionFileStore(root: root, create: false)
        let persisted = try reopened.assignment(projectID: "project-one", taskID: pending.id)
        XCTAssertEqual(persisted.profileProvisioningReceipt?.state, .pending)
        XCTAssertEqual(persisted.profileProvisioningReceipt?.provenance, .newlyPrepared)
        XCTAssertEqual(persisted.profileProvisioningReceipt?.requestedAt, requestedAt)
        XCTAssertNil(persisted.profileProvisioningReceipt?.verifiedAt)
        XCTAssertEqual(persisted.permissionProfileDefinition, pending.permissionProfileDefinition)
    }

    func testProfileAssociationRequiresExactProtectedEvidenceAndPreservesOutsideProfiles() throws {
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"),
            registrationID: "registration-one", requestGeneration: 1)
        let contextID = UUID()
        let definition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
        var assignment = ProjectExecutionAssignment(id: "delivery-association", registration: registration,
            checkoutPath: "/Worktrees/project-one/delivery-association", role: .delivery,
            permissionProfile: "rr-delivery-association", model: "gpt-5.6-terra", effort: "medium",
            authorization: "Approved work", context: [.init(path: "AGENTS.md",
                digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .preparing)
        assignment.codexContextID = contextID
        assignment.permissionProfileDefinition = definition
        assignment.profileProvisioningReceipt = .init(state: .verified, provenance: .newlyPrepared,
            requestedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            verifiedAt: Date(timeIntervalSinceReferenceDate: 1_001))

        let owned = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: contextID, observation: .present(definition),
            candidateProfileID: assignment.permissionProfile)
        XCTAssertEqual(owned.category, .owned)
        XCTAssertEqual(owned.assignmentID, assignment.id)
        XCTAssertNil(owned.reason)
        XCTAssertEqual(owned.ownershipProvenance, .verifiedProvisioningReceipt)
        XCTAssertEqual(owned.installationEvidence, .verified)
        XCTAssertFalse(owned.requiresInstallationRecovery)

        let equivalentSerialization = Data(#"{ "network" : { "enabled" : false }, "filesystem" : { } }"#.utf8)
        let semanticallyOwned = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: contextID, observation: .present(equivalentSerialization),
            candidateProfileID: assignment.permissionProfile)
        XCTAssertEqual(semanticallyOwned.category, .owned,
            "Profile ownership compares complete JSON definitions semantically, not by byte layout")

        let extraGrant = Data(#"{"network":{"enabled":false},"filesystem":{"unexpected":"write"}}"#.utf8)
        let broadened = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: contextID, observation: .present(extraGrant),
            candidateProfileID: assignment.permissionProfile)
        XCTAssertEqual(broadened.category, .unknown)
        XCTAssertEqual(broadened.reason, .definitionMismatch)

        var malformedDefinition = assignment
        malformedDefinition.permissionProfileDefinition = Data("not-json".utf8)
        let malformed = ProjectExecutionProfileAssociation.classify(assignment: malformedDefinition,
            selectedCodexContextID: contextID, observation: .present(Data("not-json".utf8)),
            candidateProfileID: malformedDefinition.permissionProfile)
        XCTAssertEqual(malformed.category, .unknown)
        XCTAssertEqual(malformed.reason, .definitionMismatch)

        var legacyAssignment = assignment
        legacyAssignment.profileProvisioningReceipt = nil
        let legacyOwned = ProjectExecutionProfileAssociation.classify(assignment: legacyAssignment,
            selectedCodexContextID: contextID, observation: .present(definition),
            candidateProfileID: legacyAssignment.permissionProfile)
        XCTAssertEqual(legacyOwned.category, .owned,
            "An exact protected legacy record is ownership evidence even without a new receipt")
        XCTAssertEqual(legacyOwned.assignmentID, legacyAssignment.id)
        XCTAssertEqual(legacyOwned.ownershipProvenance, .legacyProtectedAssignment)
        XCTAssertEqual(legacyOwned.installationEvidence, .unrecorded)
        XCTAssertTrue(legacyOwned.requiresInstallationRecovery,
            "Legacy ownership must not fabricate installation history")

        var pendingAssignment = assignment
        pendingAssignment.profileProvisioningReceipt = .init(state: .pending, provenance: .newlyPrepared,
            requestedAt: Date(timeIntervalSinceReferenceDate: 1_002), verifiedAt: nil)
        let pendingOwned = ProjectExecutionProfileAssociation.classify(assignment: pendingAssignment,
            selectedCodexContextID: contextID, observation: .present(definition),
            candidateProfileID: pendingAssignment.permissionProfile)
        XCTAssertEqual(pendingOwned.category, .owned)
        XCTAssertEqual(pendingOwned.ownershipProvenance, .pendingProvisioningReceipt)
        XCTAssertEqual(pendingOwned.installationEvidence, .pending)
        XCTAssertTrue(pendingOwned.requiresInstallationRecovery)

        var reservedLegacyAttempt = assignment
        reservedLegacyAttempt.launchReserved = true
        reservedLegacyAttempt.uncertainOutcome = true
        reservedLegacyAttempt.workerAttemptID = nil
        let unknownAttempt = ProjectExecutionProfileAssociation.classify(assignment: reservedLegacyAttempt,
            selectedCodexContextID: contextID, observation: .present(definition),
            candidateProfileID: reservedLegacyAttempt.permissionProfile)
        XCTAssertEqual(unknownAttempt.category, .unknown)
        XCTAssertEqual(unknownAttempt.reason, .legacyWorkerIdentityUnavailable)

        var contextlessAssignment = assignment
        contextlessAssignment.codexContextID = nil
        let contextless = ProjectExecutionProfileAssociation.classify(assignment: contextlessAssignment,
            selectedCodexContextID: nil, observation: .present(definition),
            candidateProfileID: contextlessAssignment.permissionProfile)
        XCTAssertEqual(contextless.category, .unknown,
            "Nil context values cannot establish selected-context ownership")
        XCTAssertEqual(contextless.reason, .selectedContextMismatch)

        let mismatch = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: contextID, observation: .present(Data("different".utf8)),
            candidateProfileID: assignment.permissionProfile)
        XCTAssertEqual(mismatch.category, .unknown)
        XCTAssertEqual(mismatch.reason, .definitionMismatch)

        let staleContext = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: UUID(), observation: .present(definition),
            candidateProfileID: assignment.permissionProfile)
        XCTAssertEqual(staleContext.category, .unknown)
        XCTAssertEqual(staleContext.reason, .selectedContextMismatch)

        let missing = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: contextID, observation: .missing,
            candidateProfileID: assignment.permissionProfile)
        XCTAssertEqual(missing.category, .unknown)
        XCTAssertEqual(missing.reason, .profileMissing)

        let unavailable = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: contextID, observation: .unavailable,
            candidateProfileID: assignment.permissionProfile)
        XCTAssertEqual(unavailable.category, .unknown)
        XCTAssertEqual(unavailable.reason, .configurationUnavailable)

        let legacy = ProjectExecutionProfileAssociation.classify(assignment: nil,
            selectedCodexContextID: contextID, observation: .present(definition),
            candidateProfileID: "rr-delivery-legacy")
        XCTAssertEqual(legacy.category, .unknown,
            "A matching-looking name without a protected assignment must never be adopted")

        for reserved in ["rr-project-ro", "rr-project-restricted", "rr-command-read-probe"] {
            let result = ProjectExecutionProfileAssociation.classify(assignment: assignment,
                selectedCodexContextID: contextID, observation: .present(definition),
                candidateProfileID: reserved)
            XCTAssertEqual(result.category, .outsideAssignmentCleanup)
            XCTAssertEqual(result.reason, .reservedProfile)
        }

        let unrelated = ProjectExecutionProfileAssociation.classify(assignment: assignment,
            selectedCodexContextID: contextID, observation: .present(definition),
            candidateProfileID: "rr-other-assignment")
        XCTAssertEqual(unrelated.category, .outsideAssignmentCleanup)
        XCTAssertNil(unrelated.assignmentID)
    }

    func testHookExpectedBytesAndSymlinkCannotOverwriteUnrelatedConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let original = Data(#"{"hooks":{},"owner":"keep"}"#.utf8)
        try store.saveHookConfiguration(original, expected: nil)
        XCTAssertThrowsError(try store.saveHookConfiguration(Data(#"{"hooks":{}}"#.utf8), expected: nil))
        XCTAssertEqual(try store.hookConfiguration(), original)
        let aliasRoot = root.appendingPathComponent("AliasRoot")
        let aliasStore = try ProjectExecutionFileStore(root: aliasRoot, create: true)
        try FileManager.default.createSymbolicLink(at: aliasRoot.appendingPathComponent(".codex"), withDestinationURL: root.appendingPathComponent(".codex"))
        XCTAssertThrowsError(try aliasStore.saveHookConfiguration(Data(#"{"hooks":{}}"#.utf8), expected: nil))
        XCTAssertEqual(try store.hookConfiguration(), original)
    }

    func testSymlinkAuthorityLockFailsClosed() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let directory = root.appendingPathComponent("Projects/project-one")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside")
        try Data("unchanged".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent(".policy.json.lock"), withDestinationURL: outside)
        let policy = ProjectExecutionPolicy(registration: .init(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1), primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        XCTAssertThrowsError(try store.savePolicy(policy, expected: nil))
        XCTAssertEqual(try Data(contentsOf: outside), Data("unchanged".utf8))
        XCTAssertNil(try store.policyIfPresent(projectID: "project-one"))
    }

    func testIndependentStoresSerializeConflictingPolicyUpdates() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let first = try ProjectExecutionFileStore(root: root, create: true)
        let second = try ProjectExecutionFileStore(root: root, create: false)
        let original = ProjectExecutionPolicy(registration: .init(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1), primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        try first.savePolicy(original, expected: nil)
        var disabled = original; disabled.enabled = false
        var consenting = original; consenting.consent = .init()
        let updates = [disabled, consenting]
        let successes = await withTaskGroup(of: Bool.self) { group in
            for (index, store) in [first, second].enumerated() {
                let update = updates[index]
                group.addTask { do { try store.savePolicy(update, expected: original); return true } catch { return false } }
            }
            var count = 0; for await success in group { if success { count += 1 } }; return count
        }
        XCTAssertEqual(successes, 1)
        XCTAssertTrue(updates.contains(try first.policy(projectID: "project-one")))
    }

    func testPolicyRetryPreservesIdentityAndDoesNotOverwriteConflict() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let policy = ProjectExecutionPolicy(registration: registration, primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        try store.savePolicy(policy, expected: nil)
        XCTAssertEqual(try store.policy(projectID: "project-one"), policy)
        try store.savePolicy(policy, expected: policy)
        let other = ProjectExecutionPolicy(registration: .init(projectID: registration.projectID, registrationID: "other", requestGeneration: 1), primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        XCTAssertThrowsError(try store.savePolicy(other, expected: nil))
        XCTAssertEqual(try store.policy(projectID: "project-one"), policy)
    }

    func testSymlinkStorageAndSymlinkAssignmentCannotRedirectAuthorityReads() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let alias = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        XCTAssertThrowsError(try ProjectExecutionFileStore(root: alias, create: false))
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let dir = root.appendingPathComponent("Assignments/project-one/task-one")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("untrusted.json")
        try Data("{}".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("assignment.json"), withDestinationURL: outside)
        XCTAssertThrowsError(try store.assignment(projectID: "project-one", taskID: "task-one"))
    }
}

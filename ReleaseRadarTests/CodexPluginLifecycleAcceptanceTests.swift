import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class CodexPluginLifecycleAcceptanceTests: XCTestCase {
    func testPackageHasCanonicalInventoryVersionAndDeterministicDigest() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CodexPluginLifecycle/v2", isDirectory: true)
        let package = try CodexPluginPackage(rootURL: fixture)

        XCTAssertEqual(package.version, "1.1.0")
        XCTAssertEqual(package.relativeFiles, [
            ".codex-plugin/plugin.json",
            ".mcp.json",
            "skills/release-radar/SKILL.md",
        ])
        XCTAssertEqual(package.digest, try CodexPluginPackage(rootURL: fixture).digest)
    }

    func testPackageRejectsUnexpectedEntryAndSymlink() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PluginPackage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        try copyFixture(version: "v2", to: directory)
        try Data("unexpected".utf8).write(to: directory.appendingPathComponent("plugins/release-radar/unexpected"))

        XCTAssertThrowsError(try CodexPluginPackage(rootURL: directory)) { error in
            XCTAssertEqual(error as? CodexPluginPackageError, .invalidInventory)
        }

        try FileManager.default.removeItem(at: directory.appendingPathComponent("plugins/release-radar/unexpected"))
        let skill = directory.appendingPathComponent("plugins/release-radar/skills/release-radar/SKILL.md")
        try FileManager.default.removeItem(at: skill)
        try FileManager.default.createSymbolicLink(at: skill, withDestinationURL: URL(fileURLWithPath: "/dev/null"))
        XCTAssertThrowsError(try CodexPluginPackage(rootURL: directory)) { error in
            XCTAssertEqual(error as? CodexPluginPackageError, .invalidInventory)
        }
    }

    func testBundledPackageMatchesAppVersionAndCanonicalDigest() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try CodexPluginPackage(
            rootURL: repositoryRoot.appendingPathComponent("ReleaseRadar/CodexPluginMarketplace")
        )

        XCTAssertEqual(package.version, "0.1.6")
        XCTAssertEqual(
            package.version,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )
        XCTAssertEqual(package.digest, "dad143d88e77af7e2ed4523c17c31a24fdd8810e87d02a2ccfe2c39ba5558f8c")
    }

    func testBundledSkillDefinesOwnerAuthorizedAuditedRepositoryHandoff() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let skillURL = repositoryRoot.appendingPathComponent(
            "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md"
        )
        let skill = try String(contentsOf: skillURL, encoding: .utf8)
        let fencedBlockStart = try XCTUnwrap(skill.range(of: "```markdown\n")).upperBound
        let fencedBlockEnd = try XCTUnwrap(
            skill.range(of: "\n```", range: fencedBlockStart..<skill.endIndex)
        ).lowerBound

        XCTAssertFalse(skill.contains("Act only on an owner-requested initialization"))
        XCTAssertEqual(
            String(skill[fencedBlockStart..<fencedBlockEnd]),
            ProjectGuidanceInspection.managedBlock
        )
        XCTAssertTrue(skill.contains(
            "Current project-guidance version: `\(ProjectGuidanceInspection.currentVersion)`."
        ))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("owner explicitly authorizes"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("owner authorization"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("exact authorized repository root"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("canonicalize that stated root and the current Codex task root"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("continue only when they match exactly"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("parent, child, or different folder"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("stop before writing any file or calling Release Radar"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("preserve every existing byte"))
        XCTAssertTrue(skill.contains("release-radar-guidance:v2:start"))
        XCTAssertTrue(skill.contains("release-radar-guidance:end"))
        XCTAssertTrue(skill.contains("## Release Radar tracking"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("append"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("replace only"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("root `AGENTS.md`"))
        XCTAssertTrue(skill.contains("only when"))
        XCTAssertTrue(skill.contains("docs/delivery/progress.md"))
        XCTAssertTrue(skill.contains("existing catalogued `docs/delivery/progress.md`"))
        XCTAssertTrue(skill.contains("preserve it byte-for-byte throughout this handoff"))
        for rule in ["release_radar_inventory_evidence", "existing handoff evidence ID unchanged", "isComplete", "v1-to-v2 upgrade", "release_radar_bind_documentation_repository", "release_radar_accept_documentation_catalog", "release_radar_add_managed_evidence", "release_radar_adopt_managed_evidence", "release_radar_relocate_legacy_evidence", "docs/delivery/plans/", "never recreate", "modified current block"] { XCTAssertTrue(skill.contains(rule), rule) }
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("symlink"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("non-regular"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("every existing path component"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("write the permitted guidance first"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("changed the managed guidance block"))
        XCTAssertTrue(skill.contains("release-radar-handoff:v1:"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("handoff incomplete"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("already matches"))
        XCTAssertTrue(skill.contains("release_radar_add_evidence"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("omit `ticketID`"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("never use `release_radar_upsert_phase`"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("successful audited"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("read the files back"))
        XCTAssertTrue(skill.contains("appUnavailable"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("audit pending"))
        XCTAssertTrue(skill.contains("outcomeUnknown"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("complete original request verbatim"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("idempotent request receipt"))
        XCTAssertTrue(skill.localizedCaseInsensitiveContains("without a second mutation"))
        XCTAssertFalse(skill.localizedCaseInsensitiveContains("MCP repository-read"))
    }

    func testPackageDigestDoesNotDependOnCreationOrEnumerationOrder() throws {
        let forward = try makePackageCopy(prefix: "Forward")
        let reverse = try makePackageCopy(prefix: "Reverse", reverseOrder: true)
        let forwardPackage = try CodexPluginPackage(rootURL: forward)
        let reversePackage = try CodexPluginPackage(rootURL: reverse)

        XCTAssertEqual(forwardPackage.digest, reversePackage.digest)
    }

    func testPackageRejectsSymlinkedRootOrIntermediateAndUnexpectedDirectory() throws {
        let rootTarget = try makePackageCopy(prefix: "RootTarget")
        let rootLink = rootTarget.deletingLastPathComponent()
            .appendingPathComponent("RootLink-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: rootLink, withDestinationURL: rootTarget)
        addTeardownBlock { try? FileManager.default.removeItem(at: rootLink) }
        assertInvalidInventory(rootLink)

        let intermediate = try makePackageCopy(prefix: "IntermediateLink")
        let agents = intermediate.appendingPathComponent(".agents")
        let realAgents = intermediate.appendingPathComponent(".agents-real")
        try FileManager.default.moveItem(at: agents, to: realAgents)
        try FileManager.default.createSymbolicLink(
            at: agents,
            withDestinationURL: URL(fileURLWithPath: ".agents-real")
        )
        assertInvalidInventory(intermediate)

        let extraDirectory = try makePackageCopy(prefix: "ExtraDirectory")
        try FileManager.default.createDirectory(
            at: extraDirectory.appendingPathComponent("plugins/release-radar/unexpected"),
            withIntermediateDirectories: false
        )
        assertInvalidInventory(extraDirectory)
    }

    func testPackageRejectsMissingAndNonRegularApprovedFile() throws {
        let missing = try makePackageCopy(prefix: "Missing")
        try FileManager.default.removeItem(
            at: missing.appendingPathComponent("plugins/release-radar/.mcp.json")
        )
        assertInvalidInventory(missing)

        let nonRegular = try makePackageCopy(prefix: "NonRegular")
        let skill = nonRegular.appendingPathComponent(
            "plugins/release-radar/skills/release-radar/SKILL.md"
        )
        try FileManager.default.removeItem(at: skill)
        XCTAssertEqual(mkfifo(skill.path, S_IRUSR | S_IWUSR), 0)
        assertInvalidInventory(nonRegular)
    }

    func testPackageRejectsFileChangedDuringCompleteSnapshot() throws {
        let directory = try makePackageCopy(prefix: "ChangedDuringRead")
        let marketplace = directory.appendingPathComponent(".agents/plugins/marketplace.json")

        XCTAssertThrowsError(try CodexPluginPackage(
            rootURL: directory,
            afterReadingFile: { relative in
                guard relative == ".agents/plugins/marketplace.json" else { return }
                try? Data("{}".utf8).write(to: marketplace)
            }
        )) { error in
            XCTAssertEqual(error as? CodexPluginPackageError, .invalidInventory)
        }
    }

    func testLifecyclePresentationCoversAllOwnerStates() {
        let managed = CodexPluginReceipt(
            intent: .managedInstalled,
            managedVersion: "0.1.0",
            managedDigest: "known",
            verifiedAt: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(
            CodexPluginLifecycleReducer.presentation(
                receipt: .neverInstalled,
                observed: .absent,
                shippedVersion: "0.1.0"
            ),
            .notInstalled
        )
        XCTAssertEqual(
            CodexPluginLifecycleReducer.presentation(
                receipt: managed,
                observed: .clean(version: "0.1.0", digest: "known"),
                shippedVersion: "0.1.0"
            ),
            .installed(version: "0.1.0")
        )
        XCTAssertEqual(
            CodexPluginLifecycleReducer.presentation(
                receipt: managed,
                observed: .clean(version: "0.0.9", digest: "known"),
                shippedVersion: "0.1.0"
            ),
            .updateAvailable(installed: "0.0.9", shipped: "0.1.0")
        )
        XCTAssertEqual(
            CodexPluginLifecycleReducer.presentation(
                receipt: managed,
                observed: .modified(version: "0.1.0", observedDigest: "changed"),
                shippedVersion: "0.1.0"
            ),
            .modified(version: "0.1.0")
        )
        XCTAssertEqual(
            CodexPluginLifecycleReducer.presentation(
                receipt: managed,
                observed: .needsRepair(.integrityInvalid),
                shippedVersion: "0.1.0"
            ),
            .needsRepair
        )
    }

    func testAutomaticUpdateRequiresCleanOlderManagedReceipt() {
        let receipt = CodexPluginReceipt(
            intent: .managedInstalled,
            managedVersion: "0.0.9",
            managedDigest: "digest",
            verifiedAt: Date(timeIntervalSince1970: 1)
        )
        XCTAssertTrue(CodexPluginLifecycleReducer.shouldAutomaticallyUpdate(
            receipt: receipt,
            observed: .clean(version: "0.0.9", digest: "digest"),
            shippedVersion: "0.1.0"
        ))
        XCTAssertFalse(CodexPluginLifecycleReducer.shouldAutomaticallyUpdate(
            receipt: receipt,
            observed: .modified(version: "0.0.9", observedDigest: "different"),
            shippedVersion: "0.1.0"
        ))
        XCTAssertFalse(CodexPluginLifecycleReducer.shouldAutomaticallyUpdate(
            receipt: receipt,
            observed: .clean(version: "0.0.8", digest: "digest"),
            shippedVersion: "0.1.0"
        ))
        XCTAssertFalse(CodexPluginLifecycleReducer.shouldAutomaticallyUpdate(
            receipt: receipt,
            observed: .clean(version: "0.0.9", digest: "different"),
            shippedVersion: "0.1.0"
        ))
        XCTAssertFalse(CodexPluginLifecycleReducer.shouldAutomaticallyUpdate(
            receipt: CodexPluginReceipt(intent: .removed, managedVersion: "0.0.9", managedDigest: "digest", verifiedAt: Date()),
            observed: .clean(version: "0.0.9", digest: "digest"),
            shippedVersion: "0.1.0"
        ))
    }

    func testAutomaticUpdateUsesStrictSemVerPrereleasePrecedenceAndIgnoresBuildMetadata() {
        func isEligible(installed: String, shipped: String) -> Bool {
            CodexPluginLifecycleReducer.shouldAutomaticallyUpdate(
                receipt: .init(
                    intent: .managedInstalled,
                    managedVersion: installed,
                    managedDigest: "digest",
                    verifiedAt: Date(timeIntervalSince1970: 1)
                ),
                observed: .clean(version: installed, digest: "digest"),
                shippedVersion: shipped
            )
        }

        XCTAssertTrue(isEligible(installed: "1.0.0-beta.11", shipped: "1.0.0"))
        XCTAssertTrue(isEligible(installed: "1.0.0-beta.2", shipped: "1.0.0-beta.11"))
        XCTAssertTrue(isEligible(installed: "1.0.0-1", shipped: "1.0.0-alpha"))
        XCTAssertTrue(isEligible(installed: "1.0.0-alpha", shipped: "1.0.0-beta"))
        XCTAssertFalse(isEligible(installed: "1.0.0+build.1", shipped: "1.0.0+build.2"))
    }

    func testAutomaticCheckPersistsModifiedAttentionOnceAndStillPresentsRecovery() async throws {
        let (store, lifecycleStore) = try makeLifecycleStore(prefix: "AutomaticModified")
        let verifiedAt = Date(timeIntervalSince1970: 1_789_000_000)
        try await lifecycleStore.recordVerified(
            .init(intent: .managedInstalled, managedVersion: "0.1.0", managedDigest: "known", verifiedAt: verifiedAt),
            reason: "Install Release Radar Codex plugin"
        )
        let manager = ScriptedLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .modified(version: "0.1.0", observedDigest: "changed"), error: nil),
            .init(wireVersion: 1, observedState: .modified(version: "0.1.0", observedDigest: "changed"), error: nil),
        ])
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: lifecycleStore,
            shippedVersion: "0.2.0",
            shippedDigest: "shipped"
        )

        let first = await coordinator.performAutomaticUpdateIfEligible()
        let second = await coordinator.performAutomaticUpdateIfEligible()
        XCTAssertEqual(first.state, .modified(version: "0.1.0"))
        XCTAssertEqual(second.state, .modified(version: "0.1.0"))
        let receipt = try await lifecycleStore.load()
        let observationAudits = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-observer'")
        }
        XCTAssertEqual(receipt, .init(
            intent: .attentionRequired,
            managedVersion: "0.1.0",
            managedDigest: "known",
            verifiedAt: verifiedAt
        ))
        XCTAssertEqual(observationAudits, 1)
        let operations = await manager.operations()
        XCTAssertEqual(operations, [.status, .status])
    }

    func testAutomaticCheckPersistsExternalRemovalAndRepairWithoutMutation() async throws {
        let cases: [(CodexPluginObservedState, CodexPluginPresentationState, CodexPluginIntent)] = [
            (.absent, .notInstalled, .removed),
            (.needsRepair(.integrityInvalid), .needsRepair, .attentionRequired),
        ]

        for (observed, expectedState, expectedIntent) in cases {
            let (_, lifecycleStore) = try makeLifecycleStore(prefix: "AutomaticObservation")
            try await lifecycleStore.recordVerified(
                .init(intent: .managedInstalled, managedVersion: "0.1.0", managedDigest: "known", verifiedAt: Date(timeIntervalSince1970: 1)),
                reason: "Install Release Radar Codex plugin"
            )
            let manager = ScriptedLifecycleManager(replies: [
                .init(wireVersion: 1, observedState: observed, error: nil),
            ])
            let coordinator = CodexPluginLifecycleCoordinator(
                manager: manager,
                store: lifecycleStore,
                shippedVersion: "0.2.0",
                shippedDigest: "shipped"
            )

            let result = await coordinator.performAutomaticUpdateIfEligible()
            let receipt = try await lifecycleStore.load()
            let operations = await manager.operations()
            XCTAssertEqual(result.state, expectedState)
            XCTAssertEqual(receipt.intent, expectedIntent)
            XCTAssertEqual(operations, [.status])
        }
    }

    func testVersionTenLifecycleReceiptPersistsAcrossRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PluginReceipt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        let receipt = CodexPluginReceipt(
            intent: .managedInstalled,
            managedVersion: "0.1.0",
            managedDigest: "abc123",
            verifiedAt: Date(timeIntervalSince1970: 1_789_000_000)
        )

        try await lifecycleStore.recordVerified(receipt, reason: "Install Release Radar Codex plugin")

        let relaunched = CodexPluginLifecycleStore(store: DeliveryStore(databaseURL: databaseURL))
        let reloadedReceipt = try await relaunched.load()
        XCTAssertEqual(reloadedReceipt, receipt)
        let schemaVersion = try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version")
        let persisted = try await DeliveryStore(databaseURL: databaseURL).read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM codex_plugin_lifecycle WHERE plugin_id = 'release-radar'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-owner' AND reason = 'Install Release Radar Codex plugin'")
            )
        }
        XCTAssertEqual(schemaVersion, StoreMigrations.currentVersion)
        XCTAssertEqual(persisted.0, 1)
        XCTAssertEqual(persisted.1, 1)
    }

    func testInstallRecordsReceiptOnlyAfterFreshCleanPostcondition() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PluginCoordinator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let manager = ScriptedLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .clean(version: "0.1.0", digest: "digest"), error: nil),
            .init(wireVersion: 1, observedState: .clean(version: "0.1.0", digest: "digest"), error: nil),
        ])
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: CodexPluginLifecycleStore(store: store),
            shippedVersion: "0.1.0",
            shippedDigest: "digest",
            now: { Date(timeIntervalSince1970: 1_789_000_000) }
        )

        let result = await coordinator.install()

        XCTAssertEqual(result.state, .installed(version: "0.1.0"))
        let operations = await manager.operations()
        let receipt = try await CodexPluginLifecycleStore(store: store).load()
        let audit = try await store.read { connection in
            try connection.row(
                "SELECT actor_id, reason FROM audit_events WHERE reason = 'Install Release Radar Codex plugin'"
            )
        }
        XCTAssertEqual(operations, [.install, .status])
        XCTAssertEqual(receipt.intent, .managedInstalled)
        XCTAssertEqual(audit?["actor_id"], .text("release-radar-owner"))
        XCTAssertEqual(audit?["reason"], .text("Install Release Radar Codex plugin"))
    }

    func testContradictoryInstallPostconditionPreservesReceiptAndCreatesNoAudit() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PluginCoordinatorFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let manager = ScriptedLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .clean(version: "0.1.0", digest: "digest"), error: nil),
            .init(wireVersion: 1, observedState: .modified(version: "0.1.0", observedDigest: "changed"), error: nil),
        ])
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: CodexPluginLifecycleStore(store: store),
            shippedVersion: "0.1.0",
            shippedDigest: "digest"
        )

        let result = await coordinator.install()

        XCTAssertEqual(result.state, .failed(.postconditionFailed))
        let receipt = try await CodexPluginLifecycleStore(store: store).load()
        let ownerAuditCount = try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-owner'")
        }
        XCTAssertEqual(receipt, .neverInstalled)
        XCTAssertEqual(ownerAuditCount, 0)
    }

    func testChangedDigestPersistsAttentionOnlyOnceAndPreservesVerifiedReceipt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PluginObservation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        let verifiedAt = Date(timeIntervalSince1970: 1_789_000_000)
        try await lifecycleStore.recordVerified(
            .init(intent: .managedInstalled, managedVersion: "0.1.0", managedDigest: "known", verifiedAt: verifiedAt),
            reason: "Install Release Radar Codex plugin"
        )
        let manager = ScriptedLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .clean(version: "0.1.0", digest: "changed"), error: nil),
            .init(wireVersion: 1, observedState: .clean(version: "0.1.0", digest: "changed"), error: nil),
        ])
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: lifecycleStore,
            shippedVersion: "0.1.0",
            shippedDigest: "shipped"
        )

        let firstStatus = await coordinator.status()
        let secondStatus = await coordinator.status()
        XCTAssertEqual(firstStatus.state, .modified(version: "0.1.0"))
        XCTAssertEqual(secondStatus.state, .modified(version: "0.1.0"))

        let receipt = try await lifecycleStore.load()
        let observationAuditCount = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-observer'")
        }
        XCTAssertEqual(receipt.intent, .attentionRequired)
        XCTAssertEqual(receipt.managedVersion, "0.1.0")
        XCTAssertEqual(receipt.managedDigest, "known")
        XCTAssertEqual(receipt.verifiedAt, verifiedAt)
        XCTAssertEqual(observationAuditCount, 1)
    }

    func testPartialReinstallPresentsRepairAndPreservesReceiptWithoutAudit() async throws {
        let (store, lifecycleStore) = try makeLifecycleStore(prefix: "PartialReinstall")
        let receipt = CodexPluginReceipt(
            intent: .managedInstalled,
            managedVersion: "0.1.0",
            managedDigest: "known",
            verifiedAt: Date(timeIntervalSince1970: 1)
        )
        try await lifecycleStore.recordVerified(receipt, reason: "Install Release Radar Codex plugin")
        let auditCountBefore = try await auditCount(in: store)
        let manager = ScriptedLifecycleManager(replies: [
            .init(
                wireVersion: 1,
                observedState: nil,
                error: .partialReinstall
            ),
        ])
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: lifecycleStore,
            shippedVersion: "0.2.0",
            shippedDigest: "shipped"
        )

        let result = await coordinator.reinstall()

        XCTAssertEqual(result, .init(state: .needsRepair))
        XCTAssertEqual(CodexPluginLifecycleReducer.actions(for: result.state), [.reinstall, .remove])
        let persisted = try await lifecycleStore.load()
        let auditCountAfter = try await auditCount(in: store)
        let operations = await manager.operations()
        XCTAssertEqual(persisted, receipt)
        XCTAssertEqual(auditCountAfter, auditCountBefore)
        XCTAssertEqual(operations, [.reinstall])
    }

    func testUpdateReinstallAndRemoveAuditOnlyTheirVerifiedPostconditions() async throws {
        enum Change { case update, reinstall }
        let changes: [(Change, ScriptedLifecycleManager.Operation, String)] = [
            (.update, .install, "Update Release Radar Codex plugin"),
            (.reinstall, .reinstall, "Reinstall Release Radar Codex plugin"),
        ]
        for (change, expectedOperation, reason) in changes {
            let (store, lifecycleStore) = try makeLifecycleStore(prefix: "VerifiedChange")
            try await lifecycleStore.recordVerified(
                .init(intent: .managedInstalled, managedVersion: "0.1.0", managedDigest: "old", verifiedAt: Date(timeIntervalSince1970: 1)),
                reason: "Install Release Radar Codex plugin"
            )
            let manager = ScriptedLifecycleManager(replies: [
                .init(wireVersion: 1, observedState: .clean(version: "0.2.0", digest: "new"), error: nil),
                .init(wireVersion: 1, observedState: .clean(version: "0.2.0", digest: "new"), error: nil),
            ])
            let coordinator = CodexPluginLifecycleCoordinator(
                manager: manager,
                store: lifecycleStore,
                shippedVersion: "0.2.0",
                shippedDigest: "new",
                now: { Date(timeIntervalSince1970: 2) }
            )

            let result = change == .update ? await coordinator.update() : await coordinator.reinstall()
            let audit = try await store.read {
                try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-owner' AND reason = ?", bindings: [.text(reason)])
            }
            let operations = await manager.operations()
            let persisted = try await lifecycleStore.load()
            XCTAssertEqual(result, .init(state: .installed(version: "0.2.0"), changedInstallation: true))
            XCTAssertEqual(operations, [expectedOperation, .status])
            XCTAssertEqual(persisted.managedDigest, "new")
            XCTAssertEqual(audit, 1)
        }

        let (removeStore, removeLifecycleStore) = try makeLifecycleStore(prefix: "VerifiedRemove")
        let installed = CodexPluginReceipt(
            intent: .managedInstalled,
            managedVersion: "0.2.0",
            managedDigest: "new",
            verifiedAt: Date(timeIntervalSince1970: 2)
        )
        try await removeLifecycleStore.recordVerified(installed, reason: "Install Release Radar Codex plugin")
        let removeManager = ScriptedLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .absent, error: nil),
            .init(wireVersion: 1, observedState: .absent, error: nil),
        ])
        let removeCoordinator = CodexPluginLifecycleCoordinator(
            manager: removeManager,
            store: removeLifecycleStore,
            shippedVersion: "0.2.0",
            shippedDigest: "new"
        )

        let removeResult = await removeCoordinator.remove()
        let removed = try await removeLifecycleStore.load()
        let removeOperations = await removeManager.operations()
        let removeAudit = try await removeStore.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-owner' AND reason = 'Remove Release Radar Codex plugin'")
        }
        XCTAssertEqual(removeResult, .init(state: .notInstalled, changedInstallation: true))
        XCTAssertEqual(removeOperations, [.remove, .status])
        XCTAssertEqual(removed.intent, .removed)
        XCTAssertEqual(removed.managedDigest, installed.managedDigest)
        XCTAssertEqual(removeAudit, 1)
    }

    func testTimeoutAndMalformedCommandRepliesDoNotPollOrAudit() async throws {
        let cases: [(CodexPluginHelperReply, CodexPluginPresentationState)] = [
            (.init(wireVersion: 1, observedState: nil, error: .timeout), .failed(.timeout)),
            (.init(wireVersion: 2, observedState: .clean(version: "0.1.0", digest: "digest"), error: nil), .failed(.malformedResult)),
        ]
        for (reply, expected) in cases {
            let (store, lifecycleStore) = try makeLifecycleStore(prefix: "RejectedChange")
            let manager = ScriptedLifecycleManager(replies: [reply])
            let coordinator = CodexPluginLifecycleCoordinator(
                manager: manager,
                store: lifecycleStore,
                shippedVersion: "0.1.0",
                shippedDigest: "digest"
            )

            let result = await coordinator.install()
            let receipt = try await lifecycleStore.load()
            let operations = await manager.operations()
            let audits = try await auditCount(in: store)
            XCTAssertEqual(result.state, expected)
            XCTAssertEqual(receipt, .neverInstalled)
            XCTAssertEqual(operations, [.install])
            XCTAssertEqual(audits, 0)
        }
    }

    func testLifecycleReducerCoversIntentObservationAndActionContract() {
        let receipts: [CodexPluginIntent: CodexPluginReceipt] = [
            .neverInstalled: .neverInstalled,
            .managedInstalled: .init(intent: .managedInstalled, managedVersion: "0.1.0", managedDigest: "known", verifiedAt: Date(timeIntervalSince1970: 1)),
            .removed: .init(intent: .removed, managedVersion: "0.1.0", managedDigest: "known", verifiedAt: Date(timeIntervalSince1970: 1)),
            .attentionRequired: .init(intent: .attentionRequired, managedVersion: "0.1.0", managedDigest: "known", verifiedAt: Date(timeIntervalSince1970: 1)),
        ]
        let cases: [(CodexPluginIntent, CodexPluginObservedState, CodexPluginPresentationState, [CodexPluginLifecycleAction])] = [
            (.neverInstalled, .absent, .notInstalled, [.install]),
            (.neverInstalled, .clean(version: "0.0.9", digest: "known"), .modified(version: "0.0.9"), [.reinstall, .remove]),
            (.neverInstalled, .clean(version: "0.1.0", digest: "known"), .modified(version: "0.1.0"), [.reinstall, .remove]),
            (.neverInstalled, .modified(version: "0.1.0", observedDigest: "changed"), .modified(version: "0.1.0"), [.reinstall, .remove]),
            (.neverInstalled, .needsRepair(.integrityInvalid), .needsRepair, [.reinstall, .remove]),
            (.managedInstalled, .absent, .notInstalled, [.install]),
            (.managedInstalled, .clean(version: "0.0.9", digest: "known"), .updateAvailable(installed: "0.0.9", shipped: "0.1.0"), [.update, .remove]),
            (.managedInstalled, .clean(version: "0.1.0", digest: "known"), .installed(version: "0.1.0"), [.remove]),
            (.managedInstalled, .modified(version: "0.1.0", observedDigest: "changed"), .modified(version: "0.1.0"), [.reinstall, .remove]),
            (.managedInstalled, .needsRepair(.integrityInvalid), .needsRepair, [.reinstall, .remove]),
            (.removed, .absent, .notInstalled, [.install]),
            (.removed, .clean(version: "0.0.9", digest: "known"), .needsRepair, [.reinstall, .remove]),
            (.removed, .clean(version: "0.1.0", digest: "known"), .needsRepair, [.reinstall, .remove]),
            (.removed, .modified(version: "0.1.0", observedDigest: "changed"), .modified(version: "0.1.0"), [.reinstall, .remove]),
            (.removed, .needsRepair(.integrityInvalid), .needsRepair, [.reinstall, .remove]),
            (.attentionRequired, .absent, .notInstalled, [.install]),
            (.attentionRequired, .clean(version: "0.0.9", digest: "known"), .needsRepair, [.reinstall, .remove]),
            (.attentionRequired, .clean(version: "0.1.0", digest: "known"), .needsRepair, [.reinstall, .remove]),
            (.attentionRequired, .modified(version: "0.1.0", observedDigest: "changed"), .modified(version: "0.1.0"), [.reinstall, .remove]),
            (.attentionRequired, .needsRepair(.integrityInvalid), .needsRepair, [.reinstall, .remove]),
        ]

        for (intent, observed, expectedState, expectedActions) in cases {
            let state = CodexPluginLifecycleReducer.presentation(
                receipt: receipts[intent]!,
                observed: observed,
                shippedVersion: "0.1.0"
            )
            XCTAssertEqual(state, expectedState, "intent=\(intent), observed=\(observed)")
            XCTAssertEqual(CodexPluginLifecycleReducer.actions(for: state), expectedActions)
        }
        XCTAssertEqual(CodexPluginLifecycleReducer.actions(for: .checking), [])
        XCTAssertEqual(
            CodexPluginLifecycleReducer.presentation(
                receipt: receipts[.managedInstalled]!,
                observed: .needsRepair(.integrityUnknown),
                shippedVersion: "0.1.0"
            ),
            .failed(.integrityUnknown)
        )
        XCTAssertEqual(
            CodexPluginLifecycleReducer.actions(for: .failed(.integrityUnknown)),
            [.tryAgain]
        )
    }

    private func makeLifecycleStore(prefix: String) throws -> (DeliveryStore, CodexPluginLifecycleStore) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        return (store, CodexPluginLifecycleStore(store: store))
    }

    private func auditCount(in store: DeliveryStore) async throws -> Int64? {
        try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
    }

    private func copyFixture(version: String, to destination: URL) throws {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CodexPluginLifecycle/\(version)", isDirectory: true)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ))
        while let sourceURL = enumerator.nextObject() as? URL {
            let relative = sourceURL.path.replacingOccurrences(of: source.path + "/", with: "")
            let target = destination.appendingPathComponent(relative)
            if try sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourceURL, to: target)
            }
        }
        for relative in [
            ".agents/plugins/marketplace.json",
            "plugins/release-radar/.codex-plugin/plugin.json",
            "plugins/release-radar/.mcp.json",
        ] {
            let sourceURL = source.appendingPathComponent(relative)
            let target = destination.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: sourceURL.path),
               !FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourceURL, to: target)
            }
        }
    }

    private func makePackageCopy(prefix: String, reverseOrder: Bool = false) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        if !reverseOrder {
            try copyFixture(version: "v2", to: directory)
            return directory
        }
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CodexPluginLifecycle/v2", isDirectory: true)
        for relative in [
            "plugins/release-radar/skills/release-radar/SKILL.md",
            "plugins/release-radar/.mcp.json",
            "plugins/release-radar/.codex-plugin/plugin.json",
            ".agents/plugins/marketplace.json",
        ] {
            let target = directory.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: source.appendingPathComponent(relative), to: target)
        }
        return directory
    }

    private func assertInvalidInventory(_ root: URL, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try CodexPluginPackage(rootURL: root), file: file, line: line) { error in
            XCTAssertEqual(error as? CodexPluginPackageError, .invalidInventory, file: file, line: line)
        }
    }
}

private actor ScriptedLifecycleManager: CodexPluginLifecycleManaging {
    enum Operation: Equatable { case status, install, remove, reinstall }
    private var replies: [CodexPluginHelperReply]
    private var calls: [Operation] = []

    init(replies: [CodexPluginHelperReply]) {
        self.replies = replies
    }

    func status() async -> CodexPluginHelperReply { next(.status) }
    func install() async -> CodexPluginHelperReply { next(.install) }
    func remove() async -> CodexPluginHelperReply { next(.remove) }
    func reinstall() async -> CodexPluginHelperReply { next(.reinstall) }
    func operations() -> [Operation] { calls }

    private func next(_ operation: Operation) -> CodexPluginHelperReply {
        calls.append(operation)
        return replies.isEmpty
            ? .init(wireVersion: 1, observedState: nil, error: .malformedResult)
            : replies.removeFirst()
    }
}

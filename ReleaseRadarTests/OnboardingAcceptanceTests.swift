import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class OnboardingAcceptanceTests: XCTestCase {
    func testTask11AOnboardingImportCreatesNoTaskPlansAndPreservesManagedEvidenceOnReimport() async throws {
        for managed in [false, true] {
            let fixture = try FolderFixture()
            // Onboarding's production importer resolves persisted bookmark bytes;
            // use real local bookmarks, not TestBookmarkStore's path-only bytes.
            let bookmarks = ProjectBookmarkStore()
            let template = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("Fixtures/RepositoryDocuments/valid/docs")
            try FileManager.default.copyItem(at: template, to: fixture.root.appendingPathComponent("docs"))
            try Data((managed ? RepositoryDocumentContract.managedGuidanceBlock : RepositoryDocumentContract.legacyManagedGuidanceBlock).utf8)
                .write(to: fixture.root.appendingPathComponent("AGENTS.md"))
            let delivery = fixture.root.appendingPathComponent("docs/delivery")
            try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
            let artifactURL = delivery.appendingPathComponent("dashboard-status.json")
            let tasks = TicketLane.allCases.map { lane -> [String: Any] in
                ["id": "source-\(lane.rawValue)", "title": "Imported \(lane.rawValue)", "phaseId": "import-phase",
                 "status": lane.rawValue, "evidence": ["href": "../../plans/draft.md"]]
            }
            let artifact: [String: Any] = ["schemaVersion": 1, "activePhaseId": "import-phase",
                                            "phases": [["id": "import-phase", "label": "Imported phase"]], "tasks": tasks]
            let source = try JSONSerialization.data(withJSONObject: artifact, options: [.sortedKeys])
            try source.write(to: artifactURL)
            let catalogURL = fixture.root.appendingPathComponent("docs/catalog.json")
            var catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
            var collections = try XCTUnwrap(catalog["collections"] as? [[String: Any]])
            collections.append(["collectionID": "delivery", "path": "docs/delivery", "parentCollection": "docs", "purpose": "Seed delivery",
                                "allowedContents": ["seed"], "prohibitedContents": ["temp"], "firstRead": "seed", "isLeaf": true])
            catalog["collections"] = collections
            var artifacts = try XCTUnwrap(catalog["artifacts"] as? [[String: Any]])
            artifacts.append(["artifactID": "seed", "path": "docs/delivery/dashboard-status.json", "kind": "document", "lifecycle": "active",
                              "authorityLevel": "supporting", "parentCollection": "delivery", "supersedes": [],
                              "applicationSensitivity": ["importer"], "checksum": ["policy": "notApplicable"]])
            catalog["artifacts"] = artifacts
            try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys]).write(to: catalogURL)
            let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: fixture.root)
            let store = DeliveryStore(databaseURL: fixture.databaseURL)
            let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: bookmarks,
                                                    worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]))
            let preview = try await onboarding.inspect(folder: fixture.root)
            let projectID = try await onboarding.prepare(.init(preview: preview, projectName: "Import integration"))
            let project = AuthorizedProject(projectID: projectID, canonicalRoot: fixture.root, authorizedRoots: [fixture.root])
            let dispatcher = AgentCommandDispatcher(store: store, projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]), bookmarkStore: bookmarks)
            let importer = RekonArtifactImporter(store: store, project: project, bookmarkStore: bookmarks)
            let importPreview = try importer.preview(fixture.root)
            if managed {
                let before = try await attachmentDatabaseSnapshot(store: store)
                do { try await importer.apply(importPreview, to: projectID); XCTFail("Unbound managed import must reject") }
                catch { XCTAssertEqual(error as? RekonImportError, .documentation(.bindingMissing)) }
                let after = try await attachmentDatabaseSnapshot(store: store)
                XCTAssertEqual(after, before)
                let rootID = try await store.read { try XCTUnwrap($0.scalarText("SELECT id FROM project_roots WHERE project_id=?", bindings: [.text(projectID.rawValue)])) }
                let bound = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: fixture.root.path, reason: "Bind synthetic managed repository",
                                                             command: .bindDocumentationRepository(target: .init(projectID: projectID.rawValue, rootID: rootID,
                                                                 repositoryID: snapshot.catalog.repositoryID, catalogVersion: snapshot.version, catalogDigest: snapshot.digest))))
                XCTAssertNil(bound.error)
            }
            _ = try await onboarding.prepare(.init(preview: preview, projectName: "Import integration", importRecognizedArtifacts: true))
            let imported = try await store.read { c in
                (try c.rows("SELECT id,lane,plan_legacy_continuation FROM tickets ORDER BY id"),
                 try c.scalarInt("SELECT COUNT(*) FROM ticket_task_plans"),
                 try c.scalarInt("SELECT COUNT(*) FROM ticket_tasks"),
                 try c.scalarInt("SELECT COUNT(*) FROM delivery_goals"),
                 try c.scalarInt("SELECT COUNT(*) FROM review_items WHERE kind='source_lane'"),
                 try c.rows("SELECT path,artifact_id FROM evidence"),
                 try c.scalarInt("SELECT COUNT(*) FROM notification_events"))
            }
            XCTAssertEqual(imported.0, ["accepted", "backlog", "blocked", "in_progress", "needs_review"].map {
                ["id": .text("source-\($0)"), "lane": .text("backlog"), "plan_legacy_continuation": .integer(0)]
            })
            XCTAssertEqual(imported.1, 0); XCTAssertEqual(imported.2, 0); XCTAssertEqual(imported.3, 0)
            XCTAssertEqual(imported.4, 4); XCTAssertEqual(imported.6, 0)
            XCTAssertFalse(imported.5.isEmpty)
            for row in imported.5 {
                XCTAssertEqual(row["artifact_id"], managed ? .text("draft") : .null)
                XCTAssertEqual(row["path"], managed ? .null : .text(fixture.root.appendingPathComponent("docs/plans/draft.md").path))
            }
            let additionalTables = ["project_documentation_bindings", "ticket_task_plans", "ticket_tasks"]
            let beforeReimport = try await attachmentDatabaseSnapshot(store: store, additionalTables: additionalTables)
            try await importer.apply(try importer.preview(fixture.root), to: projectID)
            let afterReimport = try await attachmentDatabaseSnapshot(store: store, additionalTables: additionalTables)
            // Import has its own audit; delivery/evidence identity is idempotent.
            for table in ["tickets", "phases", "evidence", "project_documentation_bindings", "ticket_task_plans", "ticket_tasks", "review_items"] {
                XCTAssertEqual(try XCTUnwrap(afterReimport[table]), try XCTUnwrap(beforeReimport[table]), table)
            }
            XCTAssertEqual(try Data(contentsOf: artifactURL), source)
            XCTAssertEqual(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: fixture.root).digest, snapshot.digest)
            if managed {
                let relaunched = DeliveryStore(databaseURL: fixture.databaseURL)
                let result = await AgentQueryDispatcher(store: relaunched, bookmarkStore: bookmarks).dispatch(
                    .init(version: 1, projectRoot: fixture.root.path, query: .inventoryEvidence(projectID: projectID.rawValue, rootID: nil)))
                let inventory = try XCTUnwrap(result.inventory)
                XCTAssertTrue(inventory.isComplete)
                XCTAssertTrue(inventory.evidence.allSatisfy { $0.evidence.locator == .managedDocument(artifactID: "draft") && $0.resolvedAvailable })
            }
        }
    }

    func testCentralizedHandoffPromptPinsV2SetupAndLegacyAuditRepair() {
        let root = URL(fileURLWithPath: "/Users/example/Project", isDirectory: true)
        let binding = "The exact Release Radar-authorized repository root is `/Users/example/Project`. Confirm that this Codex task's canonical repository root exactly matches it. If it does not match, stop before writing any file or calling Release Radar and tell the owner to open a task rooted at that exact folder."
        let setup = "Explicitly invoke and follow the installed $release-radar:release-radar skill. You are authorizing this task to create or update only the exact Release Radar guidance v2 managed block in the authorized repository's root AGENTS.md, while preserving every other instruction and all existing delivery content. Require an existing catalogued docs/delivery/progress.md, preserve it byte-for-byte, and validate the existing docs/catalog.json and generated indexes with the repository documentation check; stop before any handoff write and report missing or invalid prerequisites for separately authorized preparation, without creating a ledger or catalog, moving documents, binding a repository, or accepting a catalog. Use the supported read-only inventory to preserve the exact existing handoff evidence ID when one matches this project's ticketless root AGENTS.md; reject incomplete, ambiguous, or mismatched results. Follow the skill's repository handoff: write and read back the permitted guidance, record that exact file with the existing ticketless evidence mutation, retain the complete request across uncertain outcomes, and report pending audit or discrepancies."
        let repair = "Explicitly invoke and follow the installed $release-radar:release-radar skill. Release Radar reports this repository's guidance handoff incomplete: the v1 managed block already matches, but its required ticketless evidence record is absent. You are authorizing this task to read back the exact root AGENTS.md and complete the handoff through the skill's audited repair path without changing unrelated repository instructions, delivery documentation, or delivery state. Preserve the complete request across uncertain outcomes and report any pending audit or discrepancy instead of guessing."
        XCTAssertTrue(CodexPromptHandoff.prompt(for: .missing, projectRoot: root).hasPrefix(binding + "\n\n" + setup + "\n\n"))
        XCTAssertTrue(CodexPromptHandoff.prompt(for: .handoffIncomplete(version: 1), projectRoot: root).hasPrefix(binding + "\n\n" + repair + "\n\n"))
    }

    func testCodexHandoffPromptRunsInCurrentTaskWithExactInstalledReleaseRadarSkill() {
        let root = URL(fileURLWithPath: "/Users/example/RekonDesignSystem", isDirectory: true)
        let setup = CodexPromptHandoff.prompt(for: .missing, projectRoot: root)
        let repair = CodexPromptHandoff.prompt(for: .handoffIncomplete(version: 1), projectRoot: root)

        XCTAssertTrue(setup.localizedCaseInsensitiveContains("this Codex task"))
        XCTAssertTrue(setup.contains("$release-radar:release-radar"))
        XCTAssertTrue(setup.localizedCaseInsensitiveContains("installed"))
        XCTAssertTrue(setup.contains("root AGENTS.md"))
        XCTAssertTrue(setup.localizedCaseInsensitiveContains("authorizing"))
        XCTAssertTrue(setup.localizedCaseInsensitiveContains("preserving every other instruction"))
        XCTAssertTrue(setup.contains(root.path))
        XCTAssertTrue(setup.localizedCaseInsensitiveContains("exactly matches"))
        XCTAssertTrue(setup.localizedCaseInsensitiveContains("stop before writing any file"))
        XCTAssertFalse(setup.localizedCaseInsensitiveContains("start a fresh"))
        XCTAssertFalse(setup.localizedCaseInsensitiveContains("create another task"))
        XCTAssertFalse(setup.localizedCaseInsensitiveContains("delegate another task"))
        XCTAssertTrue(repair.localizedCaseInsensitiveContains("handoff incomplete"))
        XCTAssertTrue(repair.localizedCaseInsensitiveContains("already matches"))
        XCTAssertTrue(repair.contains("$release-radar:release-radar"))
    }

    func testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation() async throws {
        let fixture = try FolderFixture()
        let sentinelURL = fixture.root.appendingPathComponent("owner-sentinel.txt")
        let sentinel = Data("synthetic repository content".utf8)
        try sentinel.write(to: sentinelURL)
        let listingBefore = try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted()
        let unrelatedProjectID = ProjectID(rawValue: "existing-project")

        do {
            let initialStore = DeliveryStore(databaseURL: fixture.databaseURL)
            let initialAvailability = await initialStore.availability
            XCTAssertEqual(initialAvailability, .available)
            try await initialStore.transact(
                actor: .init(id: "fixture-existing"),
                reason: "Seed existing durable state",
                auditScope: .init(
                    projectID: unrelatedProjectID,
                    entityType: .project,
                    entityID: unrelatedProjectID.rawValue
                )
            ) { connection in
                try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('existing-project', 'Existing Project', 1)")
                try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('existing-phase', 'existing-project', 'Existing Phase')")
                try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('existing-project', 'existing-phase')")
                try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('EXISTING-01', 'existing-project', 'existing-phase', 'Existing ticket', 'in_progress')")
                try connection.execute("INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('existing-blocker', 'existing-project', 'EXISTING-01', 'Existing child')")
            }
        }
        var legacyConnection: SQLiteConnection? = try SQLiteConnection(url: fixture.databaseURL)
        try legacyConnection?.executeScript("""
        ALTER TABLE projects ADD COLUMN active_phase_id TEXT;
        CREATE INDEX projects_active_phase_index ON projects(active_phase_id);
        CREATE TRIGGER validate_project_active_phase_insert
        BEFORE INSERT ON projects
        WHEN NEW.active_phase_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM phases
            WHERE phases.id = NEW.active_phase_id AND phases.project_id = NEW.id
        )
        BEGIN
            SELECT RAISE(ABORT, 'active phase must belong to project');
        END;
        CREATE TRIGGER validate_project_active_phase_update
        BEFORE UPDATE OF id, active_phase_id ON projects
        WHEN NEW.active_phase_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM phases
            WHERE phases.id = NEW.active_phase_id AND phases.project_id = NEW.id
        )
        BEGIN
            SELECT RAISE(ABORT, 'active phase must belong to project');
        END;
        UPDATE projects SET active_phase_id = 'existing-phase' WHERE id = 'existing-project';
        """)
        legacyConnection = nil

        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let availability = await store.availability
        XCTAssertEqual(availability, .available)
        let version = try SQLiteConnection(url: fixture.databaseURL).scalarInt("PRAGMA user_version")
        XCTAssertEqual(version, StoreMigrations.currentVersion)
        let populatedBefore = try await populatedLegacyFixtureSnapshot(store: store)
        XCTAssertEqual(populatedBefore["project"]?["name"], .text("Existing Project"))
        XCTAssertEqual(populatedBefore["project"]?["active_phase_id"], .text("existing-phase"))
        XCTAssertEqual(populatedBefore["phase"]?["name"], .text("Existing Phase"))
        XCTAssertEqual(populatedBefore["activePhase"]?["phase_id"], .text("existing-phase"))
        XCTAssertEqual(populatedBefore["ticket"]?["lane"], .text("in_progress"))
        XCTAssertEqual(populatedBefore["blocker"]?["summary"], .text("Existing child"))
        XCTAssertEqual(populatedBefore["audit"]?["project_id"], .text(unrelatedProjectID.rawValue))
        XCTAssertEqual(populatedBefore["counts"]?["projects"], .integer(1))
        XCTAssertEqual(populatedBefore["counts"]?["audit_events"], .integer(1))
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )

        let preview = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))
        let rootPath = fixture.root.path
        let persisted = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_roots WHERE project_id = ? AND path = ?", bindings: [.text(projectID.rawValue), .text(rootPath)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ? AND path = ? AND is_stale = 0", bindings: [.text(projectID.rawValue), .text(rootPath)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending' AND status = 'open'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-onboarding' AND reason = 'Prepare folder-backed project onboarding'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_phase_request'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences"),
                try connection.row(
                    "SELECT actor_id, reason, project_id, entity_type, entity_id FROM audit_events WHERE actor_id = 'release-radar-onboarding' AND reason = 'Prepare folder-backed project onboarding'"
                )
            )
        }
        let rawConnection = try SQLiteConnection(url: fixture.databaseURL)
        let foreignKeys = try rawConnection.scalarInt("PRAGMA foreign_keys")
        let foreignKeyCheck = try rawConnection.scalarInt("SELECT COUNT(*) FROM pragma_foreign_key_check")
        XCTAssertEqual(persisted.0, 1)
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2, 1)
        XCTAssertEqual(persisted.3, 1)
        XCTAssertEqual(persisted.4, 1)
        XCTAssertEqual(persisted.5, 0)
        XCTAssertEqual(persisted.6, 0)
        XCTAssertEqual(persisted.7, 0)
        XCTAssertEqual(persisted.8, 0)
        XCTAssertEqual(persisted.9, 0)
        XCTAssertEqual(persisted.10?["actor_id"], .text("release-radar-onboarding"))
        XCTAssertEqual(persisted.10?["reason"], .text("Prepare folder-backed project onboarding"))
        XCTAssertEqual(foreignKeys, 1)
        XCTAssertEqual(foreignKeyCheck, 0)
        let populatedAfter = try await populatedLegacyFixtureSnapshot(store: store)
        var preexistingRows = populatedBefore
        let countsBefore = try XCTUnwrap(preexistingRows.removeValue(forKey: "counts"))
        var preservedRows = populatedAfter
        let countsAfter = try XCTUnwrap(preservedRows.removeValue(forKey: "counts"))
        XCTAssertEqual(preservedRows, preexistingRows)
        guard case let .integer(projectsBefore)? = countsBefore["projects"],
              case let .integer(auditsBefore)? = countsBefore["audit_events"]
        else {
            return XCTFail("Synthetic populated fixture counts were not integers")
        }
        XCTAssertEqual(countsAfter["projects"], .integer(projectsBefore + 1))
        XCTAssertEqual(countsAfter["audit_events"], .integer(auditsBefore + 1))
        XCTAssertEqual(countsAfter["phases"], countsBefore["phases"])
        XCTAssertEqual(countsAfter["project_active_phases"], countsBefore["project_active_phases"])
        XCTAssertEqual(countsAfter["tickets"], countsBefore["tickets"])
        XCTAssertEqual(countsAfter["blockers"], countsBefore["blockers"])
        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinel)
        XCTAssertEqual(try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted(), listingBefore)

        let relaunched = FolderProjectOnboarding(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let resumed = try await relaunched.inspect(folder: fixture.root)
        XCTAssertEqual(resumed.pendingProjectID, projectID)
        XCTAssertNil(resumed.completedProjectID)
        let authorizedRoot = try await relaunched.withAuthorizedProject(projectID: projectID) { project in
            project.canonicalRoot
        }
        XCTAssertEqual(authorizedRoot, fixture.root)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    private func populatedLegacyFixtureSnapshot(
        store: DeliveryStore
    ) async throws -> [String: [String: SQLiteValue]] {
        try await store.read { connection in
            guard
                let project = try connection.row("SELECT id, name, first_dashboard_opened, active_phase_id FROM projects WHERE id = 'existing-project'"),
                let phase = try connection.row("SELECT * FROM phases WHERE id = 'existing-phase'"),
                let activePhase = try connection.row("SELECT project_id, phase_id FROM project_active_phases WHERE project_id = 'existing-project'"),
                let ticket = try connection.row("SELECT id, project_id, phase_id, outcome, lane FROM tickets WHERE id = 'EXISTING-01'"),
                let blocker = try connection.row("SELECT * FROM blockers WHERE id = 'existing-blocker'"),
                let audit = try connection.row("SELECT * FROM audit_events WHERE project_id = 'existing-project'")
            else {
                throw SQLiteError(code: 1, message: "Synthetic populated legacy fixture was not seeded")
            }
            return [
                "project": project,
                "phase": phase,
                "activePhase": activePhase,
                "ticket": ticket,
                "blocker": blocker,
                "audit": audit,
                "counts": [
                    "projects": .integer(try connection.scalarInt("SELECT COUNT(*) FROM projects") ?? -1),
                    "phases": .integer(try connection.scalarInt("SELECT COUNT(*) FROM phases") ?? -1),
                    "project_active_phases": .integer(try connection.scalarInt("SELECT COUNT(*) FROM project_active_phases") ?? -1),
                    "tickets": .integer(try connection.scalarInt("SELECT COUNT(*) FROM tickets") ?? -1),
                    "blockers": .integer(try connection.scalarInt("SELECT COUNT(*) FROM blockers") ?? -1),
                    "audit_events": .integer(try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1),
                ],
            ]
        }
    }

    func testInitializePreviewAbandonedBeforeConfirmationLeavesStoreAndRepositoryUnchanged() async throws {
        let fixture = try FolderFixture()
        let sentinelURL = fixture.root.appendingPathComponent("owner-sentinel.txt")
        let sentinel = Data("owner repository content".utf8)
        try sentinel.write(to: sentinelURL)
        let listingBefore = try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let before = try await attachmentDatabaseSnapshot(store: store)

        let preview = try await onboarding.inspect(folder: fixture.root)

        XCTAssertEqual(preview.selectedFolder, fixture.root)
        XCTAssertNil(preview.pendingProjectID)
        XCTAssertNil(preview.completedProjectID)
        let afterPreview = try await attachmentDatabaseSnapshot(store: store)
        XCTAssertEqual(afterPreview, before)
        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinel)
        XCTAssertEqual(try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted(), listingBefore)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testInitializeProjectTrackingPersistsOnlyResumableBaseStateWithoutChangingRepository() async throws {
        let fixture = try FolderFixture()
        let sentinelURL = fixture.root.appendingPathComponent("owner-sentinel.txt")
        let sentinel = Data("owner repository content".utf8)
        try sentinel.write(to: sentinelURL)
        let listingBefore = try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)

        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))
        let rootPath = fixture.root.path

        let persisted = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_roots WHERE project_id = ? AND path = ?", bindings: [.text(projectID.rawValue), .text(rootPath)]),
                try connection.row("SELECT bookmark_data, is_stale FROM project_bookmarks WHERE project_id = ? AND path = ?", bindings: [.text(projectID.rawValue), .text(rootPath)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending' AND status = 'open'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_phase_request'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-onboarding' AND reason = 'Prepare folder-backed project onboarding'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Request agent-defined first phase'")
            )
        }
        XCTAssertEqual(persisted.0, 1)
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2?["bookmark_data"], .blob(Data(fixture.root.path.utf8)))
        XCTAssertEqual(persisted.2?["is_stale"], .integer(0))
        XCTAssertEqual(persisted.3, 1)
        XCTAssertEqual(persisted.4, 0)
        XCTAssertEqual(persisted.5, 0)
        XCTAssertEqual(persisted.6, 0)
        XCTAssertEqual(persisted.7, 0)
        XCTAssertEqual(persisted.8, 0)
        XCTAssertEqual(persisted.9, 1)
        XCTAssertEqual(persisted.10, 0)
        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinel)
        XCTAssertEqual(try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted(), listingBefore)

        let relaunchedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let relaunched = FolderProjectOnboarding(
            store: relaunchedStore,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let resumedPreview = try await relaunched.inspect(folder: fixture.root)
        XCTAssertEqual(resumedPreview.pendingProjectID, projectID)
        XCTAssertNil(resumedPreview.completedProjectID)
        let resumedCounts = try await relaunchedStore.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Prepare folder-backed project onboarding'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE kind = 'onboarding_phase_request'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        XCTAssertEqual(resumedCounts.0, 1)
        XCTAssertEqual(resumedCounts.1, 1)
        XCTAssertEqual(resumedCounts.2, 0)
        XCTAssertEqual(resumedCounts.3, 0)
        XCTAssertFalse(CodexPromptHandoff.prompt(for: .missing, projectRoot: fixture.root).isEmpty)
        let authorizedRoot = try await relaunched.withAuthorizedProject(projectID: projectID) { project in
            project.canonicalRoot
        }
        XCTAssertEqual(authorizedRoot, fixture.root)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testRecognizedSeedRevalidationFailureReportsSavedIncompleteWithoutPartialImport() async throws {
        let fixture = try FolderFixture()
        try fixture.installRecognizedArtifact()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        XCTAssertNotNil(preview.recognizedArtifactPreview)
        try fixture.changeRecognizedArtifactAfterPreview()

        let savedProjectID: ProjectID
        do {
            _ = try await onboarding.prepare(.init(
                preview: preview,
                projectName: "Fixture Project",
                importRecognizedArtifacts: true
            ))
            XCTFail("Expected recognized seed revalidation to report saved-incomplete state")
            return
        } catch let error as OnboardingPreparationError {
            guard case let .seedApplicationFailedAfterSave(projectID) = error else {
                XCTFail("Expected typed saved-incomplete state, received \(error)")
                return
            }
            savedProjectID = projectID
        }

        let persisted = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_roots WHERE project_id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ? AND is_stale = 0", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending' AND status = 'open'", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind <> 'onboarding_pending'", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_active_phases WHERE project_id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE project_id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM evidence WHERE project_id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Prepare folder-backed project onboarding'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Import recognized Rekon delivery records'")
            )
        }
        XCTAssertEqual(persisted.0, 1)
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2, 1)
        XCTAssertEqual(persisted.3, 1)
        XCTAssertEqual(persisted.4, 0)
        XCTAssertEqual(persisted.5, 0)
        XCTAssertEqual(persisted.6, 0)
        XCTAssertEqual(persisted.7, 0)
        XCTAssertEqual(persisted.8, 0)
        XCTAssertEqual(persisted.9, 0)
        XCTAssertEqual(persisted.10, 0)
        XCTAssertEqual(persisted.11, 0)
        XCTAssertEqual(persisted.12, 0)
        XCTAssertEqual(persisted.13, 0)
        XCTAssertEqual(persisted.14, 1)
        XCTAssertEqual(persisted.15, 0)

        let relaunched = FolderProjectOnboarding(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let resumed = try await relaunched.inspect(folder: fixture.root)
        XCTAssertEqual(resumed.pendingProjectID, savedProjectID)
        let resumedCounts = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = ?", bindings: [.text(savedProjectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Prepare folder-backed project onboarding'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Import recognized Rekon delivery records'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE kind = 'onboarding_phase_request'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        XCTAssertEqual(resumedCounts.0, 1)
        XCTAssertEqual(resumedCounts.1, 1)
        XCTAssertEqual(resumedCounts.2, 0)
        XCTAssertEqual(resumedCounts.3, 0)
        XCTAssertEqual(resumedCounts.4, 0)
        XCTAssertFalse(CodexPromptHandoff.prompt(for: .missing, projectRoot: fixture.root).isEmpty)
        let authorizedRoot = try await relaunched.withAuthorizedProject(projectID: savedProjectID) { project in
            project.canonicalRoot
        }
        XCTAssertEqual(authorizedRoot, fixture.root)
    }

    func testBookmarkFailureBeforeBaseCommitLeavesStoreAndRepositoryUnchanged() async throws {
        let fixture = try FolderFixture()
        let sentinelURL = fixture.root.appendingPathComponent("owner-sentinel.txt")
        let sentinel = Data("owner repository content".utf8)
        try sentinel.write(to: sentinelURL)
        let listingBefore = try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: RejectingBookmarkStore(),
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = OnboardingPreview(
            selectedFolder: fixture.root,
            gitRoot: nil,
            includedTaskDescriptors: [],
            rejectedTaskDescriptors: [],
            authorizedWorktreeURLs: [],
            worktreesRequiringAuthorization: []
        )
        let before = try await attachmentDatabaseSnapshot(store: store)

        do {
            _ = try await onboarding.prepare(.init(preview: preview, projectName: "Fixture Project"))
            XCTFail("Expected bookmark creation to fail before the base transaction")
        } catch let error as ProjectBookmarkError {
            XCTAssertEqual(error, .bookmarkCreationFailed)
        }

        let after = try await attachmentDatabaseSnapshot(store: store)
        XCTAssertEqual(after, before)
        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinel)
        XCTAssertEqual(try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted(), listingBefore)
    }

    func testRecognizedArtifactPreviewRequiresExplicitImportDecision() async throws {
        let fixture = try FolderFixture()
        try fixture.installRecognizedArtifact()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )

        let preview = try await onboarding.inspect(folder: fixture.root)
        let importPreview = try XCTUnwrap(preview.recognizedArtifactPreview)
        XCTAssertEqual(importPreview.phases.map(\.id.rawValue), ["phase-imported"])
        XCTAssertEqual(importPreview.tickets.map(\.id.rawValue), ["TASK-IMPORTED"])
        XCTAssertEqual(importPreview.reviewItems.map(\.sourceID), ["TASK-UNCERTAIN"])

        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))
        let beforeOptIn = try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
        }
        XCTAssertEqual(beforeOptIn, 0)

        _ = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project",
            importRecognizedArtifacts: true
        ))
        let imported = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'missing_outcome' AND status = 'open'", bindings: [.text(projectID.rawValue)])
            )
        }
        XCTAssertEqual(imported.0, 1)
        XCTAssertEqual(imported.1, 1)
        XCTAssertEqual(imported.2, 1)
    }

    func testRunningDispatcherAuthorizesRootCommittedByOnboardingPrepare() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store)
        )
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))

        let result = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.appendingPathComponent("..").appendingPathComponent("project").path,
            reason: "Define the first phase without restarting the bridge",
            command: .upsertPhase(phaseID: "phase-agent", name: "Agent phase")
        ))

        XCTAssertNil(result.error)
        let hasFirstPhase = try await onboarding.hasFirstPhase(projectID: projectID)
        XCTAssertTrue(hasFirstPhase)
    }

    func testPreparedProjectRemainsPendingUntilFirstPhaseAndFinish() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let decision = OnboardingDecision(preview: preview, projectName: "Fixture Project")
        let projectID = try await onboarding.prepare(decision)

        let pendingMarkerCount = try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending' AND status = 'open'",
                bindings: [.text(projectID.rawValue)]
            )
        }
        XCTAssertEqual(pendingMarkerCount, 1)
        let preparedDashboard = try await DashboardProjection.load(from: store)
        XCTAssertTrue(preparedDashboard.projects.isEmpty)
        let relaunchedOnboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let resumedPreview = try await relaunchedOnboarding.inspect(folder: fixture.root)
        XCTAssertEqual(resumedPreview.pendingProjectID, projectID)
        XCTAssertNil(resumedPreview.completedProjectID)
        try await onboarding.requestFirstPhaseDefinition(projectID: projectID)

        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store)
        )
        let result = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            reason: "Define first phase",
            command: .upsertPhase(phaseID: "phase-first", name: "First phase")
        ))
        XCTAssertNil(result.error)
        let phaseReadyDashboard = try await DashboardProjection.load(from: store)
        XCTAssertTrue(phaseReadyDashboard.projects.isEmpty)

        _ = try await onboarding.finish(decision)

        let completed = try await DashboardProjection.load(from: store)
        XCTAssertEqual(completed.projects.map(\.id), [projectID])
        let inbox = try await ReviewInboxProjection.load(from: store, projectID: projectID)
        XCTAssertTrue(inbox.openItems.isEmpty)
        let finalState = try await store.read { connection in
            (
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind IN ('onboarding_pending', 'onboarding_phase_request') AND status = 'open'",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt("SELECT first_dashboard_opened FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)])
            )
        }
        XCTAssertEqual(finalState.0, 0)
        XCTAssertEqual(finalState.1, 0)
    }

    func testCheckTrackingStatusIsReadOnlyAndFinishRechecksPersistedPhase() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let decision = OnboardingDecision(preview: preview, projectName: "Fixture Project")
        let projectID = try await onboarding.prepare(decision)
        let beforeCheck = try await attachmentDatabaseSnapshot(store: store)

        let hasPhaseBeforeAgentUpdate = try await onboarding.hasFirstPhase(projectID: projectID)
        let afterCheck = try await attachmentDatabaseSnapshot(store: store)
        XCTAssertFalse(hasPhaseBeforeAgentUpdate)
        XCTAssertEqual(afterCheck, beforeCheck)
        do {
            _ = try await onboarding.finish(decision)
            XCTFail("Expected Finish Initialization to remain phase-gated")
        } catch let error as OnboardingError {
            XCTAssertEqual(error, .noFirstPhase)
        }

        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store)
        )
        let result = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            reason: "Define tracking phase",
            command: .upsertPhase(phaseID: "phase-current", name: "Current tracking")
        ))
        XCTAssertNil(result.error)

        let hasPhaseAfterAgentUpdate = try await onboarding.hasFirstPhase(projectID: projectID)
        let finishedProjectID = try await onboarding.finish(decision)
        XCTAssertTrue(hasPhaseAfterAgentUpdate)
        XCTAssertEqual(finishedProjectID, projectID)
        let completed = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending' AND status = 'open'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE kind = 'onboarding_phase_request'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        XCTAssertEqual(completed.0, 0)
        XCTAssertEqual(completed.1, 0)
        XCTAssertEqual(completed.2, 1)
    }

    func testFinishedProjectRootIsReportedAsCompletedWithoutCreatingDuplicateState() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let decision = OnboardingDecision(preview: preview, projectName: "Fixture Project")
        let projectID = try await onboarding.prepare(decision)
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store)
        )
        let phaseResult = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            reason: "Define first phase",
            command: .upsertPhase(phaseID: "phase-first", name: "First phase")
        ))
        XCTAssertNil(phaseResult.error)
        _ = try await onboarding.finish(decision)

        let completedPreview = try await onboarding.inspect(folder: fixture.symlinkedRoot)

        XCTAssertEqual(completedPreview.completedProjectID, projectID)
        XCTAssertNil(completedPreview.pendingProjectID)
        let durableCounts = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects"),
                try connection.scalarInt("SELECT COUNT(*) FROM project_roots"),
                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks")
            )
        }
        XCTAssertEqual(durableCounts.0, 1)
        XCTAssertEqual(durableCounts.1, 1)
        XCTAssertEqual(durableCounts.2, 1)
    }

    func testMarkerlessRootWithoutPhaseIsNotReportedAsCompleted() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed markerless incomplete project") { connection in
            try connection.execute(
                "DELETE FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending'",
                bindings: [.text(projectID.rawValue)]
            )
        }

        let incompletePreview = try await onboarding.inspect(folder: fixture.symlinkedRoot)

        XCTAssertNil(incompletePreview.pendingProjectID)
        XCTAssertNil(incompletePreview.completedProjectID)
    }

    func testDeniedSecurityScopeDoesNotRunDiscoveryOrAuthorizeFolder() async throws {
        let fixture = try FolderFixture()
        let scopeAccess = DeniedScopeAccessRecorder()
        let discovery = CountingWorktreeDiscovery()
        let root = fixture.root
        let bookmarkStore = ProjectBookmarkStore(
            resolver: { _ in .init(url: root, isStale: false) },
            startAccessing: { scopeAccess.start($0) },
            stopAccessing: { scopeAccess.stop($0) }
        )
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: bookmarkStore,
            worktreeDiscovery: discovery
        )

        do {
            _ = try await onboarding.inspect(folder: fixture.root)
            XCTFail("Expected denied security-scoped access")
        } catch let error as ProjectBookmarkError {
            XCTAssertEqual(error, .securityScopeAccessDenied)
        }

        XCTAssertEqual(scopeAccess.startCount, 1)
        XCTAssertEqual(scopeAccess.stopCount, 0)
        XCTAssertEqual(discovery.callCount, 0)
        let persistedAuthorizationCount = try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM project_roots")
        }
        XCTAssertEqual(persistedAuthorizationCount, 0)
    }

    func testPreviewContainsOnlySelectedRootDescendantsAndAuthorizedWorktrees() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.containedWorktree, fixture.externalWorktree]),
            codexTasks: [
                .init(id: "root", workingDirectory: fixture.root, title: "Root task"),
                .init(id: "descendant", workingDirectory: fixture.descendant, title: "Nested task"),
                .init(id: "worktree", workingDirectory: fixture.containedWorktree, title: "Worktree task"),
                .init(id: "external-worktree", workingDirectory: fixture.externalWorktree, title: "External worktree task"),
                .init(id: "sibling", workingDirectory: fixture.sibling, title: "Sibling task"),
                .init(id: "outside", workingDirectory: fixture.outside, title: "Outside task"),
            ]
        )

        let preview = try await onboarding.inspect(folder: fixture.symlinkedRoot)

        XCTAssertEqual(Set(preview.includedTaskDescriptors.map(\.id)), ["root", "descendant", "worktree"])
        XCTAssertEqual(Set(preview.rejectedTaskDescriptors.map(\.id)), ["external-worktree", "sibling", "outside"])
        XCTAssertFalse(preview.authorizedWorktreeURLs.contains(fixture.externalWorktree))

        try await onboarding.authorizeWorktree(fixture.externalWorktree, for: preview)
        let authorizedPreview = try await onboarding.inspect(folder: fixture.root)
        XCTAssertTrue(authorizedPreview.authorizedWorktreeURLs.contains(fixture.externalWorktree))
        XCTAssertEqual(Set(authorizedPreview.includedTaskDescriptors.map(\.id)), ["root", "descendant", "worktree", "external-worktree"])
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
        XCTAssertGreaterThan(fixture.bookmarks.accessStarts, 0)
    }

    func testPersistedBookmarksFailClosedWhenStaleOrUnresolvable() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.externalWorktree, fixture.outside])
        )
        let initial = try await onboarding.inspect(folder: fixture.root)
        try await onboarding.authorizeWorktree(fixture.externalWorktree, for: initial)
        let partiallyAuthorized = try await onboarding.inspect(folder: fixture.root)
        try await onboarding.authorizeWorktree(fixture.outside, for: partiallyAuthorized)
        let authorized = try await onboarding.inspect(folder: fixture.root)
        _ = try await onboarding.prepare(.init(preview: authorized, projectName: "Fixture Project"))

        fixture.bookmarks.markStale(fixture.externalWorktree)
        fixture.bookmarks.failResolution(for: fixture.outside)
        let unavailablePreview = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.externalWorktree, fixture.outside])
        ).inspect(folder: fixture.root)
        XCTAssertFalse(unavailablePreview.authorizedWorktreeURLs.contains(fixture.externalWorktree))
        XCTAssertFalse(unavailablePreview.authorizedWorktreeURLs.contains(fixture.outside))
        XCTAssertTrue(unavailablePreview.worktreesRequiringAuthorization.contains(fixture.externalWorktree))
        XCTAssertTrue(unavailablePreview.worktreesRequiringAuthorization.contains(fixture.outside))

        let staleBookmarkCount = try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM project_bookmarks WHERE is_stale = 1"
            )
        }
        XCTAssertEqual(staleBookmarkCount, 2)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testReviewDecisionFailsClosedForStaleBookmarkWithoutDecisionAudit() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let (onboarding, projectID) = try await preparedReviewProject(fixture: fixture, store: store)
        fixture.bookmarks.markStale(fixture.root)

        do {
            _ = try await resolveReview(
                onboarding: onboarding,
                store: store,
                projectID: projectID
            )
            XCTFail("Expected stale bookmark authorization to fail")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .bookmarkStale)
        }

        let state = try await reviewDecisionState(store: store, projectID: projectID)
        XCTAssertEqual(state.status, "open")
        XCTAssertEqual(state.decisionAudits, 0)
        XCTAssertEqual(state.commandRows, 0)
        XCTAssertEqual(state.staleBookmarks, 1)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testReviewDecisionFailsClosedForBookmarkResolverFailureWithoutDecisionAudit() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let (onboarding, projectID) = try await preparedReviewProject(fixture: fixture, store: store)
        fixture.bookmarks.failResolution(for: fixture.root)

        do {
            _ = try await resolveReview(
                onboarding: onboarding,
                store: store,
                projectID: projectID
            )
            XCTFail("Expected bookmark resolution to fail")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .bookmarkResolutionFailed)
        }

        let state = try await reviewDecisionState(store: store, projectID: projectID)
        XCTAssertEqual(state.status, "open")
        XCTAssertEqual(state.decisionAudits, 0)
        XCTAssertEqual(state.commandRows, 0)
        XCTAssertEqual(state.staleBookmarks, 1)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testReviewDecisionFailsClosedForDeniedScopeWithoutDecisionAudit() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let (onboarding, projectID) = try await preparedReviewProject(fixture: fixture, store: store)
        fixture.bookmarks.denyAccess(to: fixture.root)

        do {
            _ = try await resolveReview(
                onboarding: onboarding,
                store: store,
                projectID: projectID
            )
            XCTFail("Expected security scope access to be denied")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .securityScopeAccessDenied)
        }

        let state = try await reviewDecisionState(store: store, projectID: projectID)
        XCTAssertEqual(state.status, "open")
        XCTAssertEqual(state.decisionAudits, 0)
        XCTAssertEqual(state.commandRows, 0)
        XCTAssertEqual(state.staleBookmarks, 1)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testSameRootReauthorizationRejectsMismatchAndResetsOnlySelectedBookmark() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.externalWorktree])
        )
        let initial = try await onboarding.inspect(folder: fixture.root)
        try await onboarding.authorizeWorktree(fixture.externalWorktree, for: initial)
        let authorized = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: authorized,
            projectName: "Fixture Project"
        ))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed stale authorization fixtures") { connection in
            try connection.execute(
                "UPDATE project_bookmarks SET is_stale = 1 WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }

        do {
            try await onboarding.reauthorizeProjectRoot(fixture.sibling, for: projectID)
            XCTFail("Expected a different root to be rejected")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .projectRootMismatch)
        }
        try await onboarding.reauthorizeProjectRoot(fixture.symlinkedRoot, for: projectID)

        let rootPath = fixture.root.path
        let externalWorktreePath = fixture.externalWorktree.path
        let state = try await store.read { connection in
            (
                try connection.scalarInt(
                    "SELECT is_stale FROM project_bookmarks WHERE project_id = ? AND path = ?",
                    bindings: [.text(projectID.rawValue), .text(rootPath)]
                ),
                try connection.scalarInt(
                    "SELECT is_stale FROM project_bookmarks WHERE project_id = ? AND path = ?",
                    bindings: [.text(projectID.rawValue), .text(externalWorktreePath)]
                ),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-owner' AND reason = 'Reauthorize project folder access' AND project_id = ?",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE reason LIKE '%' || ? || '%'",
                    bindings: [.text(rootPath)]
                )
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 0)
    }

    func testRootlessLegacyProjectAssociatesOneUnownedRootOnly() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: fixture.bookmarks)
        let projectID = ProjectID(rawValue: "legacy-rootless")
        let siblingPath = fixture.sibling.path
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed rootless legacy review") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('legacy-rootless', 'Legacy Project')")
            try connection.execute("INSERT INTO projects (id, name) VALUES ('other-project', 'Other Project')")
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('other-root', 'other-project', ?)",
                bindings: [.text(siblingPath)]
            )
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('rr-r2-review', 'legacy-rootless', NULL, 'uncertain_import', 'Review fixture', 'open')"
            )
        }

        do {
            _ = try await resolveReview(onboarding: onboarding, store: store, projectID: projectID)
            XCTFail("Expected a rootless project to require owner association")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .projectRootMissing)
        }
        do {
            try await onboarding.associateFirstProjectRoot(fixture.sibling, for: projectID)
            XCTFail("Expected an owned root to be rejected")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .rootAlreadyOwned)
        }
        try await onboarding.associateFirstProjectRoot(fixture.root, for: projectID)
        do {
            try await onboarding.associateFirstProjectRoot(fixture.outside, for: projectID)
            XCTFail("Expected a second root association to be rejected")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .projectRootAlreadyAssociated)
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT status FROM review_items WHERE id = 'rr-r2-review'"),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE reason = 'Resolve review rr-r2-review'"
                ),
                try connection.scalarInt("SELECT COUNT(*) FROM project_roots WHERE project_id = 'legacy-rootless'"),
                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE project_id = 'legacy-rootless'"),
                try connection.scalarText("SELECT path FROM project_roots WHERE project_id = 'legacy-rootless'"),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-owner' AND reason = 'Associate first project folder authorization' AND project_id = 'legacy-rootless'"
                )
            )
        }
        XCTAssertEqual(state.0, "open")
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, fixture.root.path)
        XCTAssertEqual(state.5, 1)
    }

    func testEligibleAttachmentProjectsExcludeOpenOnboardingAndAnyAuthorization() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: fixture.bookmarks)
        let rootedPath = fixture.sibling.path
        let bookmarkedPath = fixture.outside.path
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed attachment eligibility") { connection in
            for (id, name) in [
                ("eligible-zulu", "Zulu"),
                ("eligible-alpha", "Alpha"),
                ("closed-marker", "Closed Marker"),
                ("pending", "Pending"),
                ("phase-request", "Phase Request"),
                ("rooted", "Rooted"),
                ("bookmarked", "Bookmarked"),
            ] {
                try connection.execute(
                    "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 0)",
                    bindings: [.text(id), .text(name)]
                )
            }
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('rooted-root', 'rooted', ?)",
                bindings: [.text(rootedPath)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('bookmarked', ?, ?, 0)",
                bindings: [.text(bookmarkedPath), .blob(Data(bookmarkedPath.utf8))]
            )
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('pending-marker', 'pending', NULL, ?, 'Pending', 'open')",
                bindings: [.text(OnboardingReviewMarkerKind.pending.rawValue)]
            )
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('phase-request-marker', 'phase-request', NULL, ?, 'Requested', 'open')",
                bindings: [.text(OnboardingReviewMarkerKind.phaseRequest.rawValue)]
            )
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('closed-marker-row', 'closed-marker', NULL, ?, 'Completed', 'resolved')",
                bindings: [.text(OnboardingReviewMarkerKind.pending.rawValue)]
            )
        }

        let eligible = try await onboarding.eligibleProjectsForFirstRootAssociation()

        XCTAssertEqual(eligible.map(\.id.rawValue), ["eligible-alpha", "closed-marker", "eligible-zulu"])
        XCTAssertEqual(eligible.map(\.name), ["Alpha", "Closed Marker", "Zulu"])
    }

    func testAttachFolderPreservesExistingProjectGraphAndAddsOnlyAuthorization() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await seedPopulatedRootlessAttachmentProject(store: store, fixture: fixture)
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: fixture.bookmarks)
        let before = try await attachmentDatabaseSnapshot(store: store)

        try await onboarding.associateFirstProjectRoot(fixture.symlinkedRoot, for: DashboardSampleData.projectID)

        let after = try await attachmentDatabaseSnapshot(store: store)
        for table in attachmentSnapshotTables where !["project_roots", "project_bookmarks", "audit_events"].contains(table) {
            XCTAssertEqual(after[table], before[table], "Unexpected mutation in \(table)")
        }
        let priorAudits = try XCTUnwrap(before["audit_events"])
        let currentAudits = try XCTUnwrap(after["audit_events"])
        let associationAudits = currentAudits.filter {
            $0["reason"] == .text("Associate first project folder authorization")
        }
        XCTAssertEqual(associationAudits.count, 1)
        XCTAssertEqual(
            currentAudits.filter { $0["reason"] != .text("Associate first project folder authorization") },
            priorAudits
        )
        let associationAudit = try XCTUnwrap(associationAudits.first)
        XCTAssertEqual(associationAudit["actor_id"], .text("release-radar-owner"))
        XCTAssertEqual(associationAudit["project_id"], .text(DashboardSampleData.projectID.rawValue))
        XCTAssertEqual(associationAudit["entity_type"], .text(AuditEntityType.project.rawValue))
        XCTAssertEqual(associationAudit["entity_id"], .text(DashboardSampleData.projectID.rawValue))
        XCTAssertFalse(associationAudit.values.contains(.text(fixture.root.path)))
        XCTAssertFalse(associationAudit.values.contains { if case .blob = $0 { true } else { false } })

        let authorization = try await store.read { connection in
            (
                try connection.row(
                    "SELECT id, project_id, path FROM project_roots WHERE project_id = ?",
                    bindings: [.text(DashboardSampleData.projectID.rawValue)]
                ),
                try connection.row(
                    "SELECT project_id, path, bookmark_data, is_stale FROM project_bookmarks WHERE project_id = ?",
                    bindings: [.text(DashboardSampleData.projectID.rawValue)]
                )
            )
        }
        XCTAssertEqual(authorization.0?["id"], .text("\(DashboardSampleData.projectID.rawValue)-root-0"))
        XCTAssertEqual(authorization.0?["path"], .text(fixture.root.path))
        XCTAssertEqual(authorization.1?["path"], .text(fixture.root.path))
        XCTAssertEqual(authorization.1?["bookmark_data"], .blob(Data(fixture.root.path.utf8)))
        XCTAssertEqual(authorization.1?["is_stale"], .integer(0))

        let relaunchedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let relaunched = FolderProjectOnboarding(store: relaunchedStore, bookmarkStore: fixture.bookmarks)
        let authorizedRoot = try await relaunched.withAuthorizedProject(projectID: DashboardSampleData.projectID) {
            $0.canonicalRoot
        }
        XCTAssertEqual(authorizedRoot, fixture.root)
        let relaunchedSnapshot = try await attachmentDatabaseSnapshot(store: relaunchedStore)
        XCTAssertEqual(relaunchedSnapshot, after)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testAttachFolderOwnedSymlinkConflictRollsBackPopulatedGraph() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await seedPopulatedRootlessAttachmentProject(
            store: store,
            fixture: fixture,
            ownedPath: fixture.root.path
        )
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: fixture.bookmarks)
        let before = try await attachmentDatabaseSnapshot(store: store)
        let accessStartsBefore = fixture.bookmarks.accessStarts
        let accessStopsBefore = fixture.bookmarks.accessStops

        do {
            try await onboarding.associateFirstProjectRoot(fixture.symlinkedRoot, for: DashboardSampleData.projectID)
            XCTFail("Expected a symlink-equivalent owned root to be rejected")
        } catch let error as ProjectAuthorizationError {
            XCTAssertEqual(error, .rootAlreadyOwned)
        }

        let after = try await attachmentDatabaseSnapshot(store: store)
        XCTAssertEqual(after, before)
        XCTAssertEqual(fixture.bookmarks.accessStarts, accessStartsBefore)
        XCTAssertEqual(fixture.bookmarks.accessStops, accessStopsBefore)
    }

    func testAttachFolderRejectsRootOnlyBookmarkOnlyAndPairedAuthorizationWithoutRepair() async throws {
        for (label, hasRoot, hasBookmark) in [
            ("root-only", true, false),
            ("bookmark-only", false, true),
            ("paired", true, true),
        ] {
            let fixture = try FolderFixture()
            let store = DeliveryStore(databaseURL: fixture.databaseURL)
            let projectID = ProjectID(rawValue: "attachment-\(label)")
            let persistedPath = fixture.sibling.path
            try await store.transact(actor: .init(id: "fixture"), reason: "Seed inconsistent authorization") { connection in
                try connection.execute(
                    "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 0)",
                    bindings: [.text(projectID.rawValue), .text(label)]
                )
                if hasRoot {
                    try connection.execute(
                        "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                        bindings: [.text("\(projectID.rawValue)-root-0"), .text(projectID.rawValue), .text(persistedPath)]
                    )
                }
                if hasBookmark {
                    try connection.execute(
                        "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)",
                        bindings: [.text(projectID.rawValue), .text(persistedPath), .blob(Data(persistedPath.utf8))]
                    )
                }
            }
            let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: fixture.bookmarks)
            let before = try await attachmentDatabaseSnapshot(store: store)

            do {
                try await onboarding.associateFirstProjectRoot(fixture.root, for: projectID)
                XCTFail("Expected \(label) authorization to require recovery")
            } catch let error as ProjectAuthorizationError {
                XCTAssertEqual(error, .projectRootAlreadyAssociated, label)
            }

            let after = try await attachmentDatabaseSnapshot(store: store)
            XCTAssertEqual(after, before, label)
            XCTAssertEqual(fixture.bookmarks.accessStarts, 0, label)
            XCTAssertEqual(fixture.bookmarks.accessStops, 0, label)
        }
    }

    func testPrepareRejectsRootAlreadyOwnedByAnotherProject() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let first = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.externalWorktree])
        )
        let firstPreview = try await first.inspect(folder: fixture.root)
        try await first.authorizeWorktree(fixture.externalWorktree, for: firstPreview)
        let authorizedFirstPreview = try await first.inspect(folder: fixture.root)
        let firstID = try await first.prepare(.init(preview: authorizedFirstPreview, projectName: "First"))

        let secondPreview = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.sibling, fixture.externalWorktree])
        ).inspect(folder: fixture.sibling)
        let second = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.sibling, fixture.externalWorktree])
        )
        try await second.authorizeWorktree(fixture.externalWorktree, for: secondPreview)
        let authorizedSecondPreview = try await second.inspect(folder: fixture.sibling)
        do {
            _ = try await second.prepare(.init(preview: authorizedSecondPreview, projectName: "Second"))
            XCTFail("Expected root ownership conflict")
        } catch let error as OnboardingError {
            XCTAssertEqual(error, .rootAlreadyOwned)
        }

        let rootPath = fixture.root.path
        let persisted = try await store.read { connection in
            (
                try connection.scalarText("SELECT project_id FROM project_roots WHERE path = ?", bindings: [.text(rootPath)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks"),
                try connection.scalarInt("SELECT COUNT(*) FROM projects")
            )
        }
        XCTAssertEqual(persisted.0, firstID.rawValue)
        XCTAssertEqual(persisted.1, 2)
        XCTAssertEqual(persisted.2, 1)
    }

    func testPrepareRejectsWrongKindMarkerCollisionWithoutRepairOrPartialUpdate() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Original Project"
        ))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed wrong-kind marker collision") { connection in
            try connection.execute(
                "UPDATE review_items SET kind = 'agent_request' WHERE id = ?",
                bindings: [.text("\(projectID.rawValue)-onboarding-pending")]
            )
        }

        do {
            _ = try await onboarding.prepare(.init(
                preview: preview,
                projectName: "Renamed Project"
            ))
            XCTFail("Expected the marker collision to fail onboarding prepare")
        } catch let error as OnboardingError {
            XCTAssertEqual(error, .reviewMarkerConflict)
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT name FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarText("SELECT project_id || '|' || kind || '|' || summary || '|' || status FROM review_items WHERE id = ?", bindings: [.text("\(projectID.rawValue)-onboarding-pending")])
            )
        }
        XCTAssertEqual(state.0, "Original Project")
        XCTAssertEqual(
            state.1,
            "\(projectID.rawValue)|agent_request|Project onboarding is awaiting owner completion|open"
        )
    }

    func testFinishWaitsForTypedAgentPhaseAndReconcilesEditableExclusions() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let decision = OnboardingDecision(
            preview: preview,
            projectName: "Fixture Project",
            excludedTaskIDs: ["excluded"]
        )

        let projectID = try await onboarding.prepare(decision)
        let hadFirstPhaseBeforeRequest = try await onboarding.hasFirstPhase(projectID: projectID)
        XCTAssertFalse(hadFirstPhaseBeforeRequest)
        do {
            _ = try await onboarding.finish(decision)
            XCTFail("Expected no first phase")
        } catch let error as OnboardingError {
            XCTAssertEqual(error, .noFirstPhase)
        }

        let beforeAgentPhase = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind <> 'onboarding_pending'", bindings: [.text(projectID.rawValue)])
            )
        }
        XCTAssertEqual(beforeAgentPhase.0, 0)
        XCTAssertEqual(beforeAgentPhase.1, 0)

        try await onboarding.requestFirstPhaseDefinition(projectID: projectID)
        let request = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_phase_request'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarText("SELECT actor_id FROM audit_events ORDER BY created_at DESC LIMIT 1")
            )
        }
        XCTAssertEqual(request.0, 1)
        XCTAssertEqual(request.1, "release-radar-onboarding")

        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(projectID: projectID, canonicalRoot: fixture.root, authorizedRoots: [fixture.root])
            ])
        )
        let phaseResult = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            reason: "Define first phase",
            command: .upsertPhase(phaseID: "phase-1", name: "First phase")
        ))
        XCTAssertNil(phaseResult.error)
        let hasFirstPhaseAfterAgentCommand = try await onboarding.hasFirstPhase(projectID: projectID)
        XCTAssertTrue(hasFirstPhaseAfterAgentCommand)
        let finishedProjectID = try await onboarding.finish(decision)
        XCTAssertEqual(finishedProjectID, projectID)

        let persisted = try await store.read { connection in
            (
                try connection.scalarInt("SELECT first_dashboard_opened FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM thread_exclusions WHERE project_id = ? AND thread_id = 'excluded'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'unmatched_codex_task'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(persisted.0, 0)
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2, 1)
        XCTAssertEqual(persisted.3, 1)
        XCTAssertEqual(persisted.4, 0)

        let relaunchedOnboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        )
        let rescanned = try await relaunchedOnboarding.inspect(folder: fixture.root)
        XCTAssertEqual(rescanned.includedTaskDescriptors.map(\.id), ["included"])

        _ = try await relaunchedOnboarding.finish(.init(preview: rescanned, projectName: "Fixture Project"))
        let reIncluded = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        ).inspect(folder: fixture.root)
        XCTAssertEqual(Set(reIncluded.includedTaskDescriptors.map(\.id)), ["included", "excluded"])

        _ = try await relaunchedOnboarding.finish(decision)
        let reExcluded = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        ).inspect(folder: fixture.root)
        XCTAssertEqual(reExcluded.includedTaskDescriptors.map(\.id), ["included"])
    }

    private func preparedReviewProject(
        fixture: FolderFixture,
        store: DeliveryStore
    ) async throws -> (FolderProjectOnboarding, ProjectID) {
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed RR-R2 review fixture") { connection in
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('rr-r2-review', ?, NULL, 'uncertain_import', 'Review fixture', 'open')",
                bindings: [.text(projectID.rawValue)]
            )
        }
        return (onboarding, projectID)
    }

    private func resolveReview(
        onboarding: FolderProjectOnboarding,
        store: DeliveryStore,
        projectID: ProjectID
    ) async throws -> AgentCommandResult {
        try await onboarding.withAuthorizedProject(projectID: projectID) { project in
            await AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
            ).dispatch(
                .init(
                    version: AgentCommandDispatcher.commandEnvelopeVersion,
                    requestID: UUID(),
                    projectRoot: project.canonicalRoot.path,
                    reason: "Resolve review rr-r2-review",
                    command: .resolveImportReview(reviewItemID: "rr-r2-review")
                ),
                origin: .ownerApp
            )
        }
    }

    private func reviewDecisionState(
        store: DeliveryStore,
        projectID: ProjectID
    ) async throws -> (status: String?, decisionAudits: Int64?, commandRows: Int64?, staleBookmarks: Int64?) {
        try await store.read { connection in
            (
                try connection.scalarText("SELECT status FROM review_items WHERE id = 'rr-r2-review'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Resolve review rr-r2-review'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ? AND is_stale = 1",
                    bindings: [.text(projectID.rawValue)]
                )
            )
        }
    }

    private var attachmentSnapshotTables: [String] {
        [
            "projects", "project_active_phases", "project_roots", "project_bookmarks",
            "phases", "phase_dependencies", "tickets", "ticket_dependencies", "blockers",
            "evidence", "thread_exclusions", "observed_threads", "observed_goals",
            "thread_links", "ticket_goal_links", "review_items", "completion_records",
            "notification_events", "notification_occurrences", "audit_events",
            "agent_command_requests", "alert_rules",
        ]
    }

    private func attachmentDatabaseSnapshot(
        store: DeliveryStore,
        additionalTables: [String] = []
    ) async throws -> [String: [[String: SQLiteValue]]] {
        let tables = attachmentSnapshotTables + additionalTables
        return try await store.read { connection in
            var snapshot: [String: [[String: SQLiteValue]]] = [:]
            for table in tables {
                var rows: [[String: SQLiteValue]] = []
                var offset: Int64 = 0
                while let row = try connection.row(
                    "SELECT * FROM \(table) ORDER BY rowid LIMIT 1 OFFSET ?",
                    bindings: [.integer(offset)]
                ) {
                    rows.append(row)
                    offset += 1
                }
                snapshot[table] = rows
            }
            return snapshot
        }
    }

    private func seedPopulatedRootlessAttachmentProject(
        store: DeliveryStore,
        fixture: FolderFixture,
        ownedPath: String? = nil
    ) async throws {
        try await DashboardSampleData.seedIfNeeded(in: store)
        let unrelatedRootPath = ownedPath ?? fixture.sibling.path
        try await store.transact(actor: .init(id: "fixture"), reason: "Populate attachment graph") { connection in
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES ('attachment-prerequisite', ?, 'Prerequisite')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('attachment-phase-dependency', ?, ?, 'attachment-prerequisite')",
                bindings: [.text(DashboardSampleData.projectID.rawValue), .text(DashboardSampleData.phaseID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO thread_exclusions (id, project_id, thread_id, reason) VALUES ('attachment-exclusion', ?, 'excluded-thread', 'Owner excluded this thread')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO notification_occurrences (subject_key, project_id, event_kind, subject_id, generation, is_active) VALUES ('attachment-occurrence', ?, 'blocked_linked_goal', 'VD2-07c', 2, 1)",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES ('attachment-command', ?, ?, '2026-08-25T12:00:00Z')",
                bindings: [.blob(Data("request".utf8)), .blob(Data("result".utf8))]
            )
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('attachment-unrelated', 'Unrelated Project', 0)"
            )
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES ('attachment-unrelated-phase', 'attachment-unrelated', 'Unrelated Phase')"
            )
            try connection.execute(
                "INSERT INTO project_active_phases (project_id, phase_id) VALUES ('attachment-unrelated', 'attachment-unrelated-phase')"
            )
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('attachment-unrelated-root', 'attachment-unrelated', ?)",
                bindings: [.text(unrelatedRootPath)]
            )
        }
    }
}

private final class FolderFixture {
    let directory: URL
    let databaseURL: URL
    let root: URL
    let symlinkedRoot: URL
    let descendant: URL
    let containedWorktree: URL
    let externalWorktree: URL
    let sibling: URL
    let outside: URL
    let bookmarks = TestBookmarkStore()

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        root = directory.appendingPathComponent("project", isDirectory: true)
        symlinkedRoot = directory.appendingPathComponent("project-link", isDirectory: true)
        descendant = root.appendingPathComponent("Sources/Feature", isDirectory: true)
        containedWorktree = root.appendingPathComponent(".worktrees/feature", isDirectory: true)
        externalWorktree = directory.appendingPathComponent("external-worktree", isDirectory: true)
        sibling = directory.appendingPathComponent("project-sibling", isDirectory: true)
        outside = directory.appendingPathComponent("outside", isDirectory: true)
        databaseURL = directory.appendingPathComponent("release-radar.sqlite")

        try FileManager.default.createDirectory(at: descendant, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: containedWorktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: externalWorktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlinkedRoot, withDestinationURL: root)
    }

    func installRecognizedArtifact() throws {
        let delivery = root.appendingPathComponent("docs/delivery", isDirectory: true)
        try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
        let artifact = """
        {
          "schemaVersion": 1,
          "activePhaseId": "phase-imported",
          "phases": [
            { "id": "phase-imported", "label": "Imported phase", "dependsOnPhaseIds": [] }
          ],
          "tasks": [
            {
              "id": "TASK-IMPORTED",
              "title": "Imported outcome",
              "status": "backlog",
              "phaseId": "phase-imported",
              "dependsOnTaskIds": []
            },
            {
              "id": "TASK-UNCERTAIN",
              "title": "   ",
              "status": "backlog",
              "phaseId": "phase-imported",
              "dependsOnTaskIds": []
            }
          ]
        }
        """
        try Data(artifact.utf8).write(to: delivery.appendingPathComponent("dashboard-status.json"))
    }

    func changeRecognizedArtifactAfterPreview() throws {
        let artifactURL = root.appendingPathComponent("docs/delivery/dashboard-status.json")
        let original = try String(contentsOf: artifactURL, encoding: .utf8)
        let changed = original.replacingOccurrences(of: "Imported phase", with: "Changed after preview")
        try Data(changed.utf8).write(to: artifactURL)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

private struct RejectingBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data {
        throw ProjectBookmarkError.bookmarkCreationFailed
    }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        throw ProjectBookmarkError.bookmarkResolutionFailed
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        throw ProjectBookmarkError.securityScopeAccessDenied
    }
}

private final class TestBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
    private let lock = NSLock()
    private var stalePaths: Set<String> = []
    private var failedPaths: Set<String> = []
    private var deniedPaths: Set<String> = []
    private var starts = 0
    private var stops = 0

    var accessStarts: Int { lock.withLock { starts } }
    var accessStops: Int { lock.withLock { stops } }

    func makeBookmark(for url: URL) throws -> Data {
        lock.withLock {
            stalePaths.remove(url.path)
            failedPaths.remove(url.path)
            deniedPaths.remove(url.path)
        }
        return Data(url.path.utf8)
    }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        let path = String(decoding: bookmark, as: UTF8.self)
        if lock.withLock({ failedPaths.contains(path) }) {
            throw CocoaError(.fileNoSuchFile)
        }
        return .init(url: URL(fileURLWithPath: path), isStale: lock.withLock { stalePaths.contains(path) })
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        let resolved = try resolve(bookmark)
        if lock.withLock({ deniedPaths.contains(resolved.url.path) }) {
            throw ProjectBookmarkError.securityScopeAccessDenied
        }
        lock.withLock { starts += 1 }
        defer { lock.withLock { stops += 1 } }
        return try await body(resolved)
    }

    func markStale(_ url: URL) {
        _ = lock.withLock { stalePaths.insert(url.path) }
    }

    func failResolution(for url: URL) {
        _ = lock.withLock { failedPaths.insert(url.path) }
    }

    func denyAccess(to url: URL) {
        _ = lock.withLock { deniedPaths.insert(url.path) }
    }
}

private final class DeniedScopeAccessRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var starts = 0
    private var stops = 0

    var startCount: Int { lock.withLock { starts } }
    var stopCount: Int { lock.withLock { stops } }

    func start(_ url: URL) -> Bool {
        lock.withLock { starts += 1 }
        return false
    }

    func stop(_ url: URL) {
        lock.withLock { stops += 1 }
    }
}

private final class CountingWorktreeDiscovery: @unchecked Sendable, GitWorktreeDiscovering {
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int { lock.withLock { calls } }

    func discoverWorktrees(at folder: URL) throws -> [URL] {
        lock.withLock { calls += 1 }
        return []
    }
}

private struct FixtureWorktreeDiscovery: GitWorktreeDiscovering {
    let worktrees: [URL]

    func discoverWorktrees(at folder: URL) throws -> [URL] { worktrees }
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: @escaping @Sendable () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected an error", file: file, line: line)
        } catch {}
    }
}

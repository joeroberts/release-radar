import Foundation
import XCTest
@testable import ReleaseRadarCore

final class TaskAdoptionAcceptanceTests: XCTestCase {
    func testGuidanceV3AndPackagedSkillDefineExactOwnerApprovedAdoption() throws {
        XCTAssertEqual(RepositoryDocumentContract.guidanceVersion, 3)
        let guidance = RepositoryDocumentContract.managedGuidanceBlock
        let skillURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md")
        let skill = try String(contentsOf: skillURL, encoding: .utf8)

        for text in [guidance, skill] {
            XCTAssertTrue(text.contains("release_radar_delivery_inventory"))
            XCTAssertTrue(text.contains("one exact reconciliation"))
            XCTAssertTrue(text.contains("every scoped non-Accepted ticket"))
            XCTAssertTrue(text.contains("already-planned"))
            XCTAssertTrue(text.contains("blocked"))
            XCTAssertTrue(text.contains("explicitly applicable"))
            XCTAssertTrue(text.contains("does not imply task completion"))
            XCTAssertTrue(text.contains("exact command envelope"))
            XCTAssertTrue(text.contains("ticketTaskPlanRevision"))
        }
        XCTAssertTrue(guidance.contains("Owner approval must identify that exact reconciliation"))
        XCTAssertTrue(skill.contains("General approval of code or a delivery task is not approval to mutate Release Radar state"))
    }

    func testPackagedSkillRequiresPreImplementationClassificationAndDurableReplayRecord() throws {
        let skillURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md")
        let skill = try String(contentsOf: skillURL, encoding: .utf8)

        XCTAssertTrue(skill.contains("Before implementation begins"))
        XCTAssertTrue(skill.contains("classify each non-Accepted ticket as atomic or non-atomic"))
        XCTAssertTrue(skill.contains("Atomic tickets may remain without a task plan"))
        XCTAssertTrue(skill.contains("complete titled task catalog"))
        XCTAssertTrue(skill.contains("explicit owner approval of that exact catalog"))
        XCTAssertTrue(skill.contains("existing repository delivery documentation referenced by `docs/delivery/progress.md`"))
        XCTAssertTrue(skill.contains("pending or committed disposition"))
        XCTAssertTrue(skill.contains("returned `ticketTaskPlanRevision` and audit ID"))
        XCTAssertTrue(skill.contains("interruption, conversation loss, or partial execution"))
        XCTAssertTrue(skill.contains("before replaying only an unchanged exact pending envelope"))
    }

    func testDeliveryInventoryCapturesCompleteMixedTicketScopeWithoutWrites() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-TaskAdoption-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let projectRoot = directory.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))

        try await store.transact(
            actor: .init(id: "phase6d-fixture"),
            reason: "Create mixed task adoption inventory",
            auditEventID: .init(rawValue: "phase6d-fixture-audit")
        ) { connection in
            try connection.execute("INSERT INTO projects (id,name) VALUES ('project-6d','Phase 6D project')")
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('project-6d','registration-6d',4,'complete')")
            try connection.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root-6d','project-6d',?)", bindings: [.text(projectRoot.path)])
            try connection.execute("INSERT INTO project_bookmarks (project_id,path,bookmark_data,is_stale) VALUES ('project-6d',?,?,0)", bindings: [.text(projectRoot.path), .blob(Data(projectRoot.path.utf8))])
            try connection.execute("INSERT INTO phases (id,project_id,name) VALUES ('phase-open','project-6d','Open phase'),('phase-complete','project-6d','Completed phase')")
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='in_delivery',revision=2 WHERE project_id='project-6d' AND phase_id='phase-open'")
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='completed',revision=3,completion_baseline_digest='phase6d-complete-baseline',completed_at='2026-09-10T20:00:00Z' WHERE project_id='project-6d' AND phase_id='phase-complete'")
            try connection.execute(
                """
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                    ('T-ATOMIC','project-6d','phase-open','Atomic change','backlog'),
                    ('T-PLANNED','project-6d','phase-open','Planned change','in_progress'),
                    ('T-ACCEPTED','project-6d','phase-open','Accepted history','backlog'),
                    ('T-RETIRED','project-6d','phase-open','Retired history','backlog'),
                    ('T-COMPLETE-PHASE','project-6d','phase-complete','Closed phase work','backlog'),
                    ('T-UNASSIGNED','project-6d',NULL,'Unassigned work',NULL)
                """
            )

            let projectID = ProjectID(rawValue: "project-6d")
            func createPlan(_ ticket: String, _ tasks: [TicketTaskDraft]) throws {
                _ = try TicketTaskPlanningPolicy.revisePlan(
                    projectID: projectID,
                    ticketID: .init(rawValue: ticket),
                    expectedRevision: nil,
                    additions: tasks,
                    definitionRevisions: [],
                    supersededTaskIDs: [],
                    connection: connection
                )
            }
            try createPlan("T-PLANNED", [
                .init(id: .init(rawValue: "planned-complete"), label: "Task 1", title: "Completed checkpoint", sortOrder: 0),
                .init(id: .init(rawValue: "planned-superseded"), label: "Task 2", title: "Superseded checkpoint", sortOrder: 1),
                .init(id: .init(rawValue: "planned-pending"), label: "Task 3", title: "Pending checkpoint", sortOrder: 2),
            ])
            _ = try TicketTaskPlanningPolicy.completeTask(
                projectID: projectID,
                ticketID: .init(rawValue: "T-PLANNED"),
                taskID: .init(rawValue: "planned-complete"),
                expectedRevision: 1,
                connection: connection
            )
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: projectID,
                ticketID: .init(rawValue: "T-PLANNED"),
                expectedRevision: 2,
                additions: [],
                definitionRevisions: [],
                supersededTaskIDs: [.init(rawValue: "planned-superseded")],
                connection: connection
            )
            try createPlan("T-ACCEPTED", [
                .init(id: .init(rawValue: "accepted-task"), label: "Task A", title: "Accepted task history", sortOrder: 0),
            ])
            try connection.execute("UPDATE tickets SET lane='accepted' WHERE project_id='project-6d' AND id='T-ACCEPTED'")
            try createPlan("T-RETIRED", [
                .init(id: .init(rawValue: "retired-task"), label: "Task R", title: "Retired task history", sortOrder: 0),
            ])
            try connection.execute("INSERT INTO ticket_retirements (project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at) VALUES ('project-6d','T-RETIRED','withdrawn','Scope no longer applies','phase-open','backlog','phase6d-fixture-audit','2026-09-10T20:01:00Z')")
            try createPlan("T-UNASSIGNED", [
                .init(id: .init(rawValue: "unassigned-task"), label: "Task U", title: "Defined before placement", sortOrder: 0),
            ])
        }

        let before = try await writeSensitiveCounts(store)
        let queryJSON: [String: Any] = [
            "version": 1,
            "projectRoot": projectRoot.path,
            "query": ["deliveryInventory": ["projectID": "project-6d", "rootID": "root-6d"]],
        ]
        let envelopeData = try JSONSerialization.data(withJSONObject: queryJSON)
        guard let envelope = try? JSONDecoder().decode(AgentQueryEnvelope.self, from: envelopeData) else {
            return XCTFail("The complete project-scoped deliveryInventory query is unavailable")
        }

        let result = await AgentQueryDispatcher(
            store: store,
            bookmarkStore: TaskAdoptionBookmarkStore()
        ).dispatch(envelope)
        let after = try await writeSensitiveCounts(store)
        XCTAssertEqual(after, before, "A complete inventory read must not create audits, receipts, or delivery rows")
        XCTAssertNil(result.error)

        let resultObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any]
        )
        let inventory = try XCTUnwrap(resultObject["deliveryInventory"] as? [String: Any])
        XCTAssertEqual(inventory["isComplete"] as? Bool, true)
        XCTAssertEqual(inventory["projectID"] as? String, "project-6d")
        XCTAssertEqual(inventory["projectName"] as? String, "Phase 6D project")
        XCTAssertEqual(inventory["rootID"] as? String, "root-6d")
        XCTAssertEqual(inventory["rootPath"] as? String, projectRoot.path)
        let registration = try XCTUnwrap(inventory["registration"] as? [String: Any])
        XCTAssertEqual(registration["registrationID"] as? String, "registration-6d")
        XCTAssertEqual((registration["requestGeneration"] as? NSNumber)?.int64Value, 4)

        let phases = try XCTUnwrap(inventory["phases"] as? [[String: Any]])
        XCTAssertEqual(phases.map { $0["phaseID"] as? String }, ["phase-complete", "phase-open"])
        XCTAssertEqual(phases.map { $0["lifecycle"] as? String }, ["completed", "in_delivery"])
        XCTAssertEqual(phases.map { ($0["lifecycleRevision"] as? NSNumber)?.int64Value }, [3, 2])

        let tickets = try XCTUnwrap(inventory["tickets"] as? [[String: Any]])
        XCTAssertEqual(tickets.count, 6)
        func ticket(_ id: String) throws -> [String: Any] {
            try XCTUnwrap(tickets.first { $0["ticketID"] as? String == id })
        }
        XCTAssertNil(try ticket("T-ATOMIC")["taskPlanRevision"])
        XCTAssertEqual(try ticket("T-ATOMIC")["definitionEligibility"] as? String, "eligible")
        XCTAssertEqual(try ticket("T-ACCEPTED")["definitionEligibility"] as? String, "accepted_ticket")
        XCTAssertEqual(try ticket("T-RETIRED")["definitionEligibility"] as? String, "retired_ticket")
        XCTAssertEqual(try ticket("T-COMPLETE-PHASE")["definitionEligibility"] as? String, "completed_phase")
        XCTAssertEqual(try ticket("T-UNASSIGNED")["definitionEligibility"] as? String, "eligible")
        XCTAssertEqual(try ticket("T-UNASSIGNED")["completionEligibility"] as? String, "unassigned_ticket")
        XCTAssertEqual((try ticket("T-PLANNED")["taskPlanRevision"] as? NSNumber)?.int64Value, 3)
        let plannedTasks = try XCTUnwrap(try ticket("T-PLANNED")["tasks"] as? [[String: Any]])
        XCTAssertEqual(plannedTasks.map { $0["taskID"] as? String }, ["planned-complete", "planned-superseded", "planned-pending"])
        XCTAssertEqual(plannedTasks.map { $0["completion"] as? String }, ["completed", "pending", "pending"])
        XCTAssertEqual(plannedTasks.map { $0["lifecycle"] as? String }, ["active", "superseded", "active"])
        XCTAssertEqual((inventory["activeTaskCount"] as? NSNumber)?.intValue, 5)
    }

    func testMixedAdoptionUsesCurrentEvidenceExactCommandsReplayAndFinalInventory() async throws {
        let fixture = try await makeAuthorizedAdoptionFixture()
        let target = try documentationTarget(projectID: fixture.registration.projectID.rawValue, root: fixture.root)
        let bind = commandEnvelope(
            fixture,
            command: .bindDocumentationRepository(target: target),
            reason: "Bind the exact managed repository"
        )
        let bound = await fixture.commands.dispatch(bind)
        XCTAssertNil(bound.error)

        let recorded = await fixture.commands.dispatch(commandEnvelope(
            fixture,
            command: .recordDeliveryEvidenceTarget(
                target: target,
                ticketID: "T-PLANNED",
                revision: .init(
                    commitSHA: String(repeating: "a", count: 40),
                    checkoutState: .clean,
                    dirtySnapshotID: nil
                ),
                expectations: [.init(category: .check, scope: "phase6d-prior-completion")],
                expectedEvidenceRevision: 0
            ),
            reason: "Record the exact prior-completion evidence target"
        ))
        XCTAssertEqual(recorded.deliveryEvidenceRevision, 1)
        let observed = await fixture.commands.dispatch(commandEnvelope(
            fixture,
            command: .appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "T-PLANNED",
                observation: .init(
                    id: "phase6d-prior-completion",
                    targetVersion: 1,
                    fact: .check(.init(scope: "phase6d-prior-completion")),
                    source: .init(kind: .localObservation, label: "Focused Phase 6D acceptance"),
                    sourceAvailability: .available,
                    outcome: .passed,
                    observedAt: "2026-09-10T20:00:00Z",
                    recordedAt: "2026-09-10T20:01:00Z"
                ),
                expectedEvidenceRevision: 1
            ),
            reason: "Record the applicable prior-completion observation"
        ))
        XCTAssertEqual(observed.deliveryEvidenceRevision, 2)

        let priorEvidence = await fixture.queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .ticketDeliveryEvidence(
                projectID: fixture.registration.projectID.rawValue,
                rootID: "root-adoption",
                ticketID: "T-PLANNED"
            )
        ))
        XCTAssertNil(priorEvidence.error)
        XCTAssertEqual(priorEvidence.deliveryEvidence?.expectations.map(\.status), [.satisfied])
        XCTAssertEqual(priorEvidence.deliveryEvidence?.observations.map(\.applicability.state), [.applicable])

        let priorInventory = await deliveryInventory(fixture)
        XCTAssertNil(priorInventory.error)
        XCTAssertNil(priorInventory.deliveryInventory?.tickets.first { $0.ticketID == "T-ATOMIC" }?.taskPlanRevision)
        XCTAssertEqual(
            priorInventory.deliveryInventory?.tickets.first { $0.ticketID == "T-PLANNED" }?.taskPlanRevision,
            1
        )
        let receiptsBeforeAdoption = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1
        }

        let defineAtomic = commandEnvelope(
            fixture,
            requestID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            command: .reviseTicketTaskPlan(
                ticketID: "T-ATOMIC",
                additions: [.init(
                    id: .init(rawValue: "atomic-delivery"),
                    label: "Task 1",
                    title: "Deliver the atomic ticket outcome",
                    sortOrder: 0
                )]
            ),
            reason: "Owner approved this exact Phase 6D reconciliation"
        )
        let defined = await fixture.commands.dispatch(defineAtomic)
        XCTAssertNil(defined.error)
        XCTAssertEqual(defined.ticketTaskPlanRevision, 1)
        let defineReplay = await fixture.commands.dispatch(defineAtomic)
        XCTAssertEqual(defineReplay, defined)

        let completePrior = commandEnvelope(
            fixture,
            requestID: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            command: .completeTicketTask(
                ticketID: "T-PLANNED",
                taskID: "already-delivered",
                expectedRevision: 1
            ),
            reason: "Owner approved this exact evidence-backed prior completion"
        )
        let completed = await fixture.commands.dispatch(completePrior)
        XCTAssertNil(completed.error)
        XCTAssertEqual(completed.ticketTaskPlanRevision, 2)
        let completionReplay = await fixture.commands.dispatch(completePrior)
        XCTAssertEqual(completionReplay, completed)

        let receiptsAfterAdoption = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1
        }
        XCTAssertEqual(receiptsAfterAdoption, receiptsBeforeAdoption + 2)

        let finalResult = await deliveryInventory(fixture)
        let final = try XCTUnwrap(finalResult.deliveryInventory)
        let atomic = try XCTUnwrap(final.tickets.first { $0.ticketID == "T-ATOMIC" })
        XCTAssertEqual(atomic.taskPlanRevision, 1)
        XCTAssertEqual(atomic.tasks.map(\.completion), [.pending])
        let planned = try XCTUnwrap(final.tickets.first { $0.ticketID == "T-PLANNED" })
        XCTAssertEqual(planned.taskPlanRevision, 2)
        XCTAssertEqual(planned.tasks.map(\.completion), [.completed])
        XCTAssertEqual(final.activeTaskCount, 2)
    }

    func testDeliveryInventoryRejectsAnOversizedReadWithoutWriting() async throws {
        let fixture = try await makeAuthorizedAdoptionFixture(atomicOutcome: String(repeating: "x", count: 132_000))
        let before = try await writeSensitiveCounts(fixture.store)
        let result = await deliveryInventory(fixture)
        XCTAssertEqual(result.error, .documentation(.inventoryTooLarge))
        XCTAssertNil(result.deliveryInventory)
        let after = try await writeSensitiveCounts(fixture.store)
        XCTAssertEqual(after, before)
    }

    private struct AdoptionFixture {
        let store: DeliveryStore
        let root: URL
        let registration: ProjectRegistration
        let commands: AgentCommandDispatcher
        let queries: AgentQueryDispatcher
    }

    private func makeAuthorizedAdoptionFixture(
        atomicOutcome: String = "Atomic change"
    ) async throws -> AdoptionFixture {
        let directory = URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
            .appendingPathComponent("release-radar-task-adoption-\(UUID().uuidString)", isDirectory: true)
        let root = directory.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid", isDirectory: true)
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: root.appendingPathComponent("AGENTS.md"))

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "phase6d-fixture"), reason: "Seed adoption workflow") { connection in
            try connection.execute("INSERT INTO projects (id,name) VALUES ('project-adoption','Adoption project')")
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('project-adoption','registration-adoption',7,'complete')")
            try connection.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root-adoption','project-adoption',?)", bindings: [.text(root.path)])
            try connection.execute("INSERT INTO project_bookmarks (project_id,path,bookmark_data,is_stale) VALUES ('project-adoption',?,?,0)", bindings: [.text(root.path), .blob(Data(root.path.utf8))])
            try connection.execute("INSERT INTO phases (id,project_id,name) VALUES ('phase-adoption','project-adoption','Adoption phase')")
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='in_delivery',revision=1 WHERE project_id='project-adoption' AND phase_id='phase-adoption'")
            try connection.execute(
                "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('T-ATOMIC','project-adoption','phase-adoption',?,'backlog'),('T-PLANNED','project-adoption','phase-adoption','Planned change','in_progress')",
                bindings: [.text(atomicOutcome)]
            )
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: .init(rawValue: "project-adoption"),
                ticketID: .init(rawValue: "T-PLANNED"),
                expectedRevision: nil,
                additions: [.init(
                    id: .init(rawValue: "already-delivered"),
                    label: "Task 1",
                    title: "Verify the already-delivered behavior",
                    sortOrder: 0
                )],
                definitionRevisions: [],
                supersededTaskIDs: [],
                connection: connection
            )
        }
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "project-adoption"),
            registrationID: "registration-adoption",
            requestGeneration: 7
        )
        let project = AuthorizedProject(registration: registration, canonicalRoot: root, authorizedRoots: [root])
        let bookmarks = ProjectBookmarkStore(
            resolver: { _ in .init(url: root, isStale: false) },
            startAccessing: { _ in true },
            stopAccessing: { _ in }
        )
        return .init(
            store: store,
            root: root,
            registration: registration,
            commands: AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]),
                bookmarkStore: bookmarks
            ),
            queries: AgentQueryDispatcher(store: store, bookmarkStore: bookmarks)
        )
    }

    private func commandEnvelope(
        _ fixture: AdoptionFixture,
        requestID: UUID = UUID(),
        command: AgentCommand,
        reason: String
    ) -> AgentCommandEnvelope {
        .init(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.root.path,
            assertedThreadID: "phase6d-owner-approved-adoption",
            expectedRegistration: fixture.registration,
            reason: reason,
            command: command
        )
    }

    private func deliveryInventory(_ fixture: AdoptionFixture) async -> AgentCommandResult {
        await fixture.queries.dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .deliveryInventory(
                projectID: fixture.registration.projectID.rawValue,
                rootID: "root-adoption"
            )
        ))
    }

    private func documentationTarget(projectID: String, root: URL) throws -> DocumentationTarget {
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        return .init(
            projectID: projectID,
            rootID: "root-adoption",
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest
        )
    }

    private func writeSensitiveCounts(_ store: DeliveryStore) async throws -> [String: Int64] {
        try await store.read { connection in
            try Dictionary(uniqueKeysWithValues: [
                "audit_events", "agent_command_requests", "ticket_task_plans", "ticket_tasks",
                "tickets", "phases", "phase_lifecycles", "ticket_retirements",
            ].map { table in
                (table, try connection.scalarInt("SELECT COUNT(*) FROM \(table)") ?? -1)
            })
        }
    }
}

private struct TaskAdoptionBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false)
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        try await body(resolve(bookmark))
    }
}

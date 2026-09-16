# RR-R9A task review package

- Task: RR-R9A typed active-phase authority
- Git base at dispatch: bcd108f3d1a95be7733a39f42d8b68c98748a30e
- Git head: unchanged by policy (no staging/commit authorized)
- Attribution basis: exact pre-edit blobs recorded before the serialized Implementer
- Scope: five owned implementation/test files only

## Attributable stat

- ReleaseRadarCore/AgentBridge/AgentCommand.swift: +1 / -0 against pre-RR-R9A blob e6641c8865f63cef78440e824e6e05d9faef0a02
- ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift: +15 / -0 against pre-RR-R9A blob a0a7cc5ffc84d82c6c5332ceaa2946c4cd10c9d3
- ReleaseRadarAgentTools/main.swift: +9 / -0 against pre-RR-R9A blob 5b1a06d69e59ac92e50339efb549d0715fc46107
- ReleaseRadarTests/AgentBridgeAcceptanceTests.swift: +303 / -0 against pre-RR-R9A blob 9e6c4f8a36783dedd788ee3d09b57d47361b619e
- ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift: +82 / -7 against pre-RR-R9A blob c4faa39505c951b939d07d454048d8fbf2b8b1c0

## Full attributable diff (10 lines of context)

--- a/ReleaseRadarCore/AgentBridge/AgentCommand.swift
+++ b/ReleaseRadarCore/AgentBridge/AgentCommand.swift
@@ -22,20 +22,21 @@
         self.assertedThreadID = assertedThreadID
         self.reason = reason
         self.command = command
     }
 }
 
 public enum AgentCommand: Codable, Equatable, Sendable {
     case upsertPhase(phaseID: String, name: String)
     case upsertTicket(ticketID: String, phaseID: String, outcome: String, lane: TicketLane)
     case transitionTicket(ticketID: String, lane: TicketLane)
+    case setActivePhase(phaseID: String)
     case setDependency(id: String, kind: DependencyKind, subjectID: String, dependsOnID: String)
     case recordBlocker(id: String, ticketID: String, summary: String)
     case resolveBlocker(blockerID: String)
     case addEvidence(id: String, ticketID: String?, path: String)
     case linkThread(id: String, ticketID: String, threadID: String)
     case linkGoal(id: String, ticketID: String, goalID: String)
     case requestReview(id: String, ticketID: String?, kind: String, summary: String)
     case recordCompletion(id: String, ticketID: String, summary: String)
     case resolveImportReview(reviewItemID: String)
     case dismissImportReview(reviewItemID: String)

--- a/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift
+++ b/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift
@@ -122,20 +122,22 @@
                 && value.utf8.count <= maximum
         }
         let commandFieldsAreValid: Bool
         switch envelope.command {
         case let .upsertPhase(phaseID, name):
             commandFieldsAreValid = valid(phaseID, maximum: 256) && valid(name)
         case let .upsertTicket(ticketID, phaseID, outcome, _):
             commandFieldsAreValid = valid(ticketID, maximum: 256) && valid(phaseID, maximum: 256) && valid(outcome)
         case let .transitionTicket(ticketID, _):
             commandFieldsAreValid = valid(ticketID, maximum: 256)
+        case let .setActivePhase(phaseID):
+            commandFieldsAreValid = valid(phaseID, maximum: 256)
         case let .setDependency(id, _, subjectID, dependsOnID):
             commandFieldsAreValid = valid(id, maximum: 256)
                 && valid(subjectID, maximum: 256)
                 && valid(dependsOnID, maximum: 256)
         case let .recordBlocker(id, ticketID, summary):
             commandFieldsAreValid = valid(id, maximum: 256) && valid(ticketID, maximum: 256) && valid(summary)
         case let .resolveBlocker(blockerID):
             commandFieldsAreValid = valid(blockerID, maximum: 256)
         case let .addEvidence(id, ticketID, path):
             commandFieldsAreValid = valid(id, maximum: 256)
@@ -186,38 +188,41 @@
     }
 
     private func resultForCommand(_ command: AgentCommand, auditEventID: AuditEventID) -> AgentCommandResult {
         switch command {
         case let .upsertPhase(phaseID, _):
             return .init(entityIDs: [phaseID], auditEventID: auditEventID, error: nil)
         case let .upsertTicket(ticketID, _, _, _):
             return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
         case let .transitionTicket(ticketID, _):
             return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
+        case let .setActivePhase(phaseID):
+            return .init(entityIDs: [phaseID], auditEventID: auditEventID, error: nil)
         case let .setDependency(id, _, _, _),
              let .recordBlocker(id, _, _),
              let .addEvidence(id, _, _),
              let .linkThread(id, _, _),
              let .linkGoal(id, _, _),
              let .requestReview(id, _, _, _),
              let .recordCompletion(id, _, _):
             return .init(entityIDs: [id], auditEventID: auditEventID, error: nil)
         case let .resolveBlocker(blockerID):
             return .init(entityIDs: [blockerID], auditEventID: auditEventID, error: nil)
         case let .resolveImportReview(reviewItemID), let .dismissImportReview(reviewItemID):
             return .init(entityIDs: [reviewItemID], auditEventID: auditEventID, error: nil)
         }
     }
 
     private static func auditScope(for command: AgentCommand, projectID: ProjectID) -> AuditScope {
         let entity: (AuditEntityType, String) = switch command {
         case let .upsertPhase(phaseID, _): (.phase, phaseID)
+        case let .setActivePhase(phaseID): (.phase, phaseID)
         case let .upsertTicket(ticketID, _, _, _), let .transitionTicket(ticketID, _): (.ticket, ticketID)
         case let .setDependency(id, kind, _, _):
             (kind == .ticket ? .ticketDependency : .phaseDependency, id)
         case let .recordBlocker(id, _, _), let .resolveBlocker(id): (.blocker, id)
         case let .addEvidence(id, _, _): (.evidence, id)
         case let .linkThread(id, _, _): (.threadLink, id)
         case let .linkGoal(_, ticketID, _): (.ticket, ticketID)
         case let .requestReview(id, _, _, _),
              let .resolveImportReview(id),
              let .dismissImportReview(id): (.reviewItem, id)
@@ -275,20 +280,30 @@
             try connection.execute(
                 "UPDATE tickets SET lane = ? WHERE project_id = ? AND id = ?",
                 bindings: [.text(lane.rawValue), .text(projectID.rawValue), .text(ticketID)]
             )
             try updateNeedsReviewOccurrence(
                 ticketID: ticketID,
                 lane: lane,
                 enteredNeedsReview: previousLane != TicketLane.needsReview.rawValue,
                 projectID: projectID,
                 connection: connection
+            )
+        case let .setActivePhase(phaseID):
+            try requireProjectEntity(phaseID, table: "phases", projectID: projectID, connection: connection)
+            try connection.execute(
+                """
+                INSERT INTO project_active_phases (project_id, phase_id)
+                VALUES (?, ?)
+                ON CONFLICT(project_id) DO UPDATE SET phase_id = excluded.phase_id;
+                """,
+                bindings: [.text(projectID.rawValue), .text(phaseID)]
             )
         case let .setDependency(id, kind, subjectID, dependsOnID):
             let table = kind == .ticket ? "tickets" : "phases"
             try requireProjectEntity(subjectID, table: table, projectID: projectID, connection: connection)
             try requireProjectEntity(dependsOnID, table: table, projectID: projectID, connection: connection)
             let dependencyTable = kind == .ticket ? "ticket_dependencies" : "phase_dependencies"
             let subjectColumn = kind == .ticket ? "ticket_id" : "phase_id"
             let dependencyColumn = kind == .ticket ? "depends_on_ticket_id" : "depends_on_phase_id"
             try requireWritableID(id, table: dependencyTable, projectID: projectID, connection: connection)
             try connection.execute(

--- a/ReleaseRadarAgentTools/main.swift
+++ b/ReleaseRadarAgentTools/main.swift
@@ -197,20 +197,24 @@
                 "ticketID": try string("ticketID", in: arguments),
                 "phaseID": try string("phaseID", in: arguments),
                 "outcome": try string("outcome", in: arguments),
                 "lane": try string("lane", in: arguments),
             ])
         case "release_radar_transition_ticket":
             return ("transitionTicket", [
                 "ticketID": try string("ticketID", in: arguments),
                 "lane": try string("lane", in: arguments),
             ])
+        case "release_radar_set_active_phase":
+            return ("setActivePhase", [
+                "phaseID": try string("phaseID", in: arguments),
+            ])
         case "release_radar_set_dependency":
             return ("setDependency", [
                 "id": try string("id", in: arguments),
                 "kind": try string("kind", in: arguments),
                 "subjectID": try string("subjectID", in: arguments),
                 "dependsOnID": try string("dependsOnID", in: arguments),
             ])
         case "release_radar_record_blocker":
             return ("recordBlocker", [
                 "id": try string("id", in: arguments),
@@ -295,20 +299,25 @@
             definition("release_radar_upsert_phase", required: ["phaseID", "name"], fields: ["phaseID": string, "name": string]),
             definition(
                 "release_radar_upsert_ticket",
                 required: ["ticketID", "phaseID", "outcome", "lane"],
                 fields: ["ticketID": string, "phaseID": string, "outcome": string, "lane": lane]
             ),
             definition(
                 "release_radar_transition_ticket",
                 required: ["ticketID", "lane"],
                 fields: ["ticketID": string, "lane": lane]
+            ),
+            definition(
+                "release_radar_set_active_phase",
+                required: ["phaseID"],
+                fields: ["phaseID": string]
             ),
             definition(
                 "release_radar_set_dependency",
                 required: ["id", "kind", "subjectID", "dependsOnID"],
                 fields: [
                     "id": string,
                     "kind": ["type": "string", "enum": ["phase", "ticket"]],
                     "subjectID": string,
                     "dependsOnID": string,
                 ]

--- a/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift
+++ b/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift
@@ -45,20 +45,244 @@
         }
         XCTAssertEqual(state.0, TicketLane.inProgress.rawValue)
         XCTAssertEqual(state.1, 1)
         XCTAssertEqual(state.2, 1)
         XCTAssertEqual(state.3, ThreadAttribution.asserted.rawValue)
         XCTAssertEqual(state.4, "project-1")
         XCTAssertEqual(state.5, AuditEntityType.ticket.rawValue)
         XCTAssertEqual(state.6, "RR-03")
     }
 
+    func testSetActivePhaseCommitsOnlyPointerAuditAndReceiptAndDurablyReplays() async throws {
+        let fixture = try await makeActivePhaseFixture()
+        let before = try await Self.activePhaseSnapshot(fixture.store)
+        let requestID = UUID(uuidString: "19191919-1919-4919-8919-191919191911")!
+        let envelope = AgentCommandEnvelope(
+            version: 1,
+            requestID: requestID,
+            projectRoot: fixture.projectRoot.path,
+            assertedThreadID: "asserted-phase-thread",
+            reason: "Select roadmap phase",
+            command: .setActivePhase(phaseID: "RR-ROADMAP")
+        )
+
+        let first = await fixture.dispatcher.dispatch(envelope)
+        XCTAssertNil(first.error)
+        XCTAssertEqual(first.entityIDs, ["RR-ROADMAP"])
+        let auditEventID = try XCTUnwrap(first.auditEventID)
+
+        let afterFirst = try await Self.activePhaseSnapshot(fixture.store)
+        XCTAssertEqual(afterFirst.activeRows, ["project-1|RR-ROADMAP"])
+        XCTAssertEqual(afterFirst.phases, before.phases)
+        XCTAssertEqual(afterFirst.tickets, before.tickets)
+        XCTAssertEqual(afterFirst.phaseDependencies, before.phaseDependencies)
+        XCTAssertEqual(afterFirst.ticketDependencies, before.ticketDependencies)
+        XCTAssertEqual(afterFirst.auditRows.count, before.auditRows.count + 1)
+        XCTAssertTrue(Set(afterFirst.auditRows).isSuperset(of: Set(before.auditRows)))
+        XCTAssertEqual(afterFirst.requestRows.count, before.requestRows.count + 1)
+        XCTAssertTrue(Set(afterFirst.requestRows).isSuperset(of: Set(before.requestRows)))
+
+        let auditMatches = try await fixture.store.read { connection in
+            try connection.scalarInt(
+                """
+                SELECT COUNT(*) FROM audit_events
+                WHERE id = ?
+                  AND actor_id = 'release-radar-agent'
+                  AND thread_id = 'asserted-phase-thread'
+                  AND thread_attribution = 'asserted'
+                  AND reason = 'Select roadmap phase'
+                  AND project_id = 'project-1'
+                  AND entity_type = 'phase'
+                  AND entity_id = 'RR-ROADMAP'
+                  AND created_at <> ''
+                """,
+                bindings: [.text(auditEventID.rawValue)]
+            )
+        }
+        XCTAssertEqual(auditMatches, 1)
+
+        let replay = await AgentCommandDispatcher(
+            store: DeliveryStore(databaseURL: fixture.databaseURL),
+            projectRegistry: fixture.registry
+        ).dispatch(envelope)
+        XCTAssertEqual(replay, first)
+        let afterReplay = try await Self.activePhaseSnapshot(fixture.store)
+        XCTAssertEqual(afterReplay, afterFirst)
+    }
+
+    func testSetActivePhaseOwnerOriginUsesOwnerAttributionWithoutAssertedThread() async throws {
+        let fixture = try await makeActivePhaseFixture()
+        let result = await fixture.dispatcher.dispatch(
+            .init(
+                version: 1,
+                requestID: UUID(uuidString: "19191919-1919-4919-8919-191919191912")!,
+                projectRoot: fixture.projectRoot.path,
+                assertedThreadID: "must-not-be-recorded-for-owner",
+                reason: "Owner selected roadmap phase",
+                command: .setActivePhase(phaseID: "RR-ROADMAP")
+            ),
+            origin: .ownerApp
+        )
+
+        XCTAssertNil(result.error)
+        XCTAssertEqual(result.entityIDs, ["RR-ROADMAP"])
+        let auditEventID = try XCTUnwrap(result.auditEventID)
+        let state = try await fixture.store.read { connection in
+            [
+                try connection.scalarInt(
+                    """
+                    SELECT COUNT(*) FROM audit_events
+                    WHERE id = ?
+                      AND actor_id = 'release-radar-owner'
+                      AND thread_id IS NULL
+                      AND thread_attribution = 'none'
+                      AND reason = 'Owner selected roadmap phase'
+                      AND project_id = 'project-1'
+                      AND entity_type = 'phase'
+                      AND entity_id = 'RR-ROADMAP'
+                      AND created_at <> ''
+                    """,
+                    bindings: [.text(auditEventID.rawValue)]
+                ) ?? -1,
+                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '19191919-1919-4919-8919-191919191912'") ?? -1,
+            ]
+        }
+        XCTAssertEqual(state, [1, 1])
+    }
+
+    func testSetActivePhaseRejectsMissingCrossProjectAndUnauthorizedTargetsWithoutWrites() async throws {
+        let fixture = try await makeActivePhaseFixture()
+        let baseline = try await Self.activePhaseSnapshot(fixture.store)
+        let cases: [(String, String, String, (AgentCommandError) -> Bool)] = [
+            (
+                "19191919-1919-4919-8919-191919191913",
+                fixture.projectRoot.path,
+                "missing-phase",
+                { if case .invalidReference = $0 { return true }; return false }
+            ),
+            (
+                "19191919-1919-4919-8919-191919191914",
+                fixture.projectRoot.path,
+                "other-project-phase",
+                { if case .crossProjectReference = $0 { return true }; return false }
+            ),
+            (
+                "19191919-1919-4919-8919-191919191915",
+                fixture.projectRoot.deletingLastPathComponent().path,
+                "RR-ROADMAP",
+                { $0 == .unauthorizedProjectRoot }
+            ),
+            (
+                "19191919-1919-4919-8919-191919191916",
+                fixture.projectRoot.path,
+                "",
+                { if case .invalidEnvelope = $0 { return true }; return false }
+            ),
+        ]
+
+        for (requestID, projectRoot, phaseID, matches) in cases {
+            let result = await fixture.dispatcher.dispatch(.init(
+                version: 1,
+                requestID: UUID(uuidString: requestID)!,
+                projectRoot: projectRoot,
+                reason: "Reject invalid active phase",
+                command: .setActivePhase(phaseID: phaseID)
+            ))
+            guard let error = result.error, matches(error) else {
+                return XCTFail("Unexpected active-phase validation result for \(phaseID): \(result)")
+            }
+            let after = try await Self.activePhaseSnapshot(fixture.store)
+            XCTAssertEqual(after, baseline)
+        }
+    }
+
+    func testSetActivePhaseRejects258ByteIdentifierBeforeAnyWrite() async throws {
+        let fixture = try await makeActivePhaseFixture()
+        let baseline = try await Self.activePhaseSnapshot(fixture.store)
+        let oversizedPhaseID = String(repeating: "é", count: 129)
+        XCTAssertEqual(oversizedPhaseID.utf8.count, 258)
+
+        let result = await fixture.dispatcher.dispatch(.init(
+            version: 1,
+            requestID: UUID(uuidString: "19191919-1919-4919-8919-191919191917")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Reject oversized phase identity",
+            command: .setActivePhase(phaseID: oversizedPhaseID)
+        ))
+
+        guard case .invalidEnvelope? = result.error else {
+            return XCTFail("Expected invalidEnvelope, got \(String(describing: result.error))")
+        }
+        let after = try await Self.activePhaseSnapshot(fixture.store)
+        XCTAssertEqual(after, baseline)
+    }
+
+    func testSetActivePhaseFreshAlreadyActiveIntentAuditsOnceAndReplayAddsNothing() async throws {
+        let fixture = try await makeActivePhaseFixture()
+        let before = try await Self.activePhaseSnapshot(fixture.store)
+        let envelope = AgentCommandEnvelope(
+            version: 1,
+            requestID: UUID(uuidString: "19191919-1919-4919-8919-191919191918")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Confirm current phase intent",
+            command: .setActivePhase(phaseID: "phase-current")
+        )
+
+        let first = await fixture.dispatcher.dispatch(envelope)
+        XCTAssertNil(first.error)
+        XCTAssertEqual(first.entityIDs, ["phase-current"])
+        XCTAssertNotNil(first.auditEventID)
+        let afterFirst = try await Self.activePhaseSnapshot(fixture.store)
+        XCTAssertEqual(afterFirst.activeRows, before.activeRows)
+        XCTAssertEqual(afterFirst.phases, before.phases)
+        XCTAssertEqual(afterFirst.tickets, before.tickets)
+        XCTAssertEqual(afterFirst.phaseDependencies, before.phaseDependencies)
+        XCTAssertEqual(afterFirst.ticketDependencies, before.ticketDependencies)
+        XCTAssertEqual(afterFirst.auditRows.count, before.auditRows.count + 1)
+        XCTAssertEqual(afterFirst.requestRows.count, before.requestRows.count + 1)
+
+        let replay = await AgentCommandDispatcher(
+            store: DeliveryStore(databaseURL: fixture.databaseURL),
+            projectRegistry: fixture.registry
+        ).dispatch(envelope)
+        XCTAssertEqual(replay, first)
+        let afterReplay = try await Self.activePhaseSnapshot(fixture.store)
+        XCTAssertEqual(afterReplay, afterFirst)
+    }
+
+    func testSetActivePhaseChangedBodyRequestIDReusePreservesOriginalSelection() async throws {
+        let fixture = try await makeActivePhaseFixture()
+        let requestID = UUID(uuidString: "19191919-1919-4919-8919-191919191919")!
+        let first = await fixture.dispatcher.dispatch(.init(
+            version: 1,
+            requestID: requestID,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Select active phase with stable request",
+            command: .setActivePhase(phaseID: "RR-ROADMAP")
+        ))
+        XCTAssertNil(first.error)
+        let afterFirst = try await Self.activePhaseSnapshot(fixture.store)
+
+        let reused = await fixture.dispatcher.dispatch(.init(
+            version: 1,
+            requestID: requestID,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Select active phase with stable request",
+            command: .setActivePhase(phaseID: "phase-historical")
+        ))
+
+        XCTAssertEqual(reused.error, .requestIDReused)
+        let afterReuse = try await Self.activePhaseSnapshot(fixture.store)
+        XCTAssertEqual(afterReuse, afterFirst)
+        XCTAssertEqual(afterFirst.activeRows, ["project-1|RR-ROADMAP"])
+    }
+
     func testLinkGoalPersistsTicketScopedAuditAndDurableReplay() async throws {
         let fixture = try await makeFixture()
         try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed approved goal candidate") { connection in
             try connection.execute(
                 "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-approved', 'project-1', 'verified-thread', 'active', 'Ship the approved identity', '2026-08-25T10:00:00Z')"
             )
             try connection.execute(
                 "INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('thread-link-approved', 'project-1', 'RR-03', 'verified-thread')"
             )
         }
@@ -577,20 +801,47 @@
     }
 
     private struct Fixture {
         let databaseURL: URL
         let projectRoot: URL
         let store: DeliveryStore
         let registry: InMemoryAuthorizedProjectRegistry
         let dispatcher: AgentCommandDispatcher
     }
 
+    private struct ActivePhaseSnapshot: Equatable {
+        let phases: [String]
+        let tickets: [String]
+        let phaseDependencies: [String]
+        let ticketDependencies: [String]
+        let activeRows: [String]
+        let auditRows: [String]
+        let requestRows: [String]
+    }
+
+    private func makeActivePhaseFixture() async throws -> Fixture {
+        let fixture = try await makeFixture()
+        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed active-phase history") { connection in
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-current', 'project-1', 'Current')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('RR-ROADMAP', 'project-1', 'Roadmap')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-historical', 'project-1', 'Historical')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-1', 'project-1', 'phase-current', 'Current delivery', 'in_progress')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROADMAP-1', 'project-1', 'RR-ROADMAP', 'Roadmap delivery', 'backlog')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('HISTORY-1', 'project-1', 'phase-historical', 'Historical delivery', 'accepted')")
+            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-history', 'project-1', 'RR-ROADMAP', 'phase-current')")
+            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('ticket-dependency-history', 'project-1', 'ROADMAP-1', 'CURRENT-1')")
+            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-current')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('other-project-phase', 'project-2', 'Other project')")
+        }
+        return fixture
+    }
+
     private func makeFixture(seedDelivery: Bool = true) async throws -> Fixture {
         let temporaryDirectory = FileManager.default.temporaryDirectory
             .appendingPathComponent("ReleaseRadar-AgentBridgeTests-\(UUID().uuidString)", isDirectory: true)
         let projectRoot = temporaryDirectory.appendingPathComponent("project", isDirectory: true)
         try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
         let databaseURL = temporaryDirectory.appendingPathComponent("store.sqlite")
         let store = DeliveryStore(databaseURL: databaseURL)
         try await store.transact(actor: .init(id: "fixture"), reason: "Seed bridge fixture") { connection in
             try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
             try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)", bindings: [.text(projectRoot.path)])
@@ -615,11 +866,63 @@
         try await store.read { connection in
             [
                 try connection.scalarInt("SELECT COUNT(*) FROM phases") ?? -1,
                 try connection.scalarInt("SELECT COUNT(*) FROM tickets") ?? -1,
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                 try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
             ]
         }
     }
 
+    private static func activePhaseSnapshot(_ store: DeliveryStore) async throws -> ActivePhaseSnapshot {
+        try await store.read { connection in
+            ActivePhaseSnapshot(
+                phases: try Self.textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || name AS value FROM phases ORDER BY project_id, id"
+                ),
+                tickets: try Self.textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || outcome || '|' || lane AS value FROM tickets ORDER BY project_id, id"
+                ),
+                phaseDependencies: try Self.textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || depends_on_phase_id AS value FROM phase_dependencies ORDER BY project_id, id"
+                ),
+                ticketDependencies: try Self.textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || ticket_id || '|' || depends_on_ticket_id AS value FROM ticket_dependencies ORDER BY project_id, id"
+                ),
+                activeRows: try Self.textRows(
+                    connection,
+                    sql: "SELECT project_id || '|' || phase_id AS value FROM project_active_phases ORDER BY project_id"
+                ),
+                auditRows: try Self.textRows(
+                    connection,
+                    sql: "SELECT id || '|' || actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') || '|' || created_at AS value FROM audit_events ORDER BY id"
+                ),
+                requestRows: try Self.textRows(
+                    connection,
+                    sql: "SELECT request_id || '|' || hex(request_body) || '|' || hex(result_data) || '|' || created_at AS value FROM agent_command_requests ORDER BY request_id"
+                )
+            )
+        }
+    }
+
+    private static func textRows(_ connection: SQLiteConnection, sql: String) throws -> [String] {
+        var values: [String] = []
+        var offset: Int64 = 0
+        while let row = try connection.row("\(sql) LIMIT 1 OFFSET ?", bindings: [.integer(offset)]) {
+            guard case let .text(value)? = row["value"] else {
+                throw ActivePhaseTestError.missingTextValue
+            }
+            values.append(value)
+            offset += 1
+        }
+        return values
+    }
+
+}
+
+private enum ActivePhaseTestError: Error {
+    case missingTextValue
 }

--- a/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
+++ b/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
@@ -305,20 +305,77 @@
         }
 
         let replay = try Self.runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
         XCTAssertEqual(try decodeCommandResult(replay), firstResult)
         let persistedStateBeforeRejectedPeer = try await exactPersistedState()
         XCTAssertEqual(
             persistedStateBeforeRejectedPeer,
             [.text("in_progress"), .integer(1), .integer(1), .integer(1)]
         )
 
+        let activePhaseRequestID = UUID(uuidString: "77777777-7777-4777-8777-777777777778")!
+        let activePhaseArguments: [String: Any] = [
+            "version": 1,
+            "requestID": activePhaseRequestID.uuidString,
+            "projectRoot": fixture.projectRoot.path,
+            "reason": "Select phase through the packaged signed transport",
+            "phaseID": "phase-2",
+        ]
+        let activePhaseFirst = try Self.runTool(
+            packagedTool,
+            tool: "release_radar_set_active_phase",
+            arguments: activePhaseArguments
+        )
+        let activePhaseFirstResult = try decodeCommandResult(activePhaseFirst)
+        XCTAssertNil(activePhaseFirstResult.error)
+        XCTAssertEqual(activePhaseFirstResult.entityIDs, ["phase-2"])
+        XCTAssertEqual(mcpIsError(activePhaseFirst), false)
+        let activePhaseAuditEventID = try XCTUnwrap(activePhaseFirstResult.auditEventID)
+
+        let activePhaseReplay = try Self.runTool(
+            packagedTool,
+            tool: "release_radar_set_active_phase",
+            arguments: activePhaseArguments
+        )
+        XCTAssertEqual(try decodeCommandResult(activePhaseReplay), activePhaseFirstResult)
+        XCTAssertEqual(mcpIsError(activePhaseReplay), false)
+        let activePhaseState: [SQLiteValue] = try await fixture.store.read { connection in
+            let phaseID = try connection.scalarText(
+                "SELECT phase_id FROM project_active_phases WHERE project_id = 'project-1'"
+            ) ?? "missing"
+            let requestCount = try connection.scalarInt(
+                "SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?",
+                bindings: [.text(activePhaseRequestID.uuidString)]
+            ) ?? -1
+            let auditCount = try connection.scalarInt(
+                "SELECT COUNT(*) FROM audit_events WHERE reason = 'Select phase through the packaged signed transport'"
+            ) ?? -1
+            let scopedAuditCount = try connection.scalarInt(
+                """
+                SELECT COUNT(*) FROM audit_events
+                WHERE id = ?
+                  AND actor_id = 'release-radar-agent'
+                  AND thread_id IS NULL
+                  AND thread_attribution = 'none'
+                  AND project_id = 'project-1'
+                  AND entity_type = 'phase'
+                  AND entity_id = 'phase-2'
+                  AND reason = 'Select phase through the packaged signed transport'
+                  AND created_at <> ''
+                """,
+                bindings: [.text(activePhaseAuditEventID.rawValue)]
+            ) ?? -1
+            return [.text(phaseID), .integer(requestCount), .integer(auditCount), .integer(scopedAuditCount)]
+        }
+        let expectedActivePhaseState: [SQLiteValue] = [.text("phase-2"), .integer(1), .integer(1), .integer(1)]
+        XCTAssertEqual(activePhaseState, expectedActivePhaseState)
+
         let rejectedPeer = try Self.runTool(wrongTool, tool: "release_radar_transition_ticket", arguments: arguments)
         XCTAssertEqual(try decodeCommandResult(rejectedPeer).error, .appUnavailable)
         XCTAssertEqual(mcpIsError(rejectedPeer), true)
         let persistedStateAfterRejectedPeer = try await exactPersistedState()
         XCTAssertEqual(persistedStateAfterRejectedPeer, persistedStateBeforeRejectedPeer)
 
         let wrongBridge = try Self.runTool(
             packagedTool,
             tool: "release_radar_transition_ticket",
             arguments: arguments,
@@ -575,20 +632,22 @@
         try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
         let databaseURL = directory.appendingPathComponent("store.sqlite")
         let store = DeliveryStore(databaseURL: databaseURL)
         try await store.transact(actor: .init(id: "fixture"), reason: "Seed transport fixture") { connection in
             try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
             try connection.execute(
                 "INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)",
                 bindings: [.text(projectRoot.path)]
             )
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-2', 'project-1', 'Launch')")
+            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-1')")
             try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Signed bridge', 'backlog')")
         }
         return .init(databaseURL: databaseURL, projectRoot: projectRoot, store: store)
     }
 
     nonisolated private static func runTool(
         _ executableURL: URL,
         tool: String,
         arguments: [String: Any],
         environment: [String: String] = [:]
@@ -686,29 +745,45 @@
     private static func decodeToolResponseData(_ data: Data) throws -> [String: Any] {
         guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
             throw TransportTestError.invalidResponse(String(decoding: data, as: UTF8.self))
         }
         return response
     }
 
     nonisolated private static func hasTypedToolSchema(_ response: [String: Any]) -> Bool {
         guard let result = response["result"] as? [String: Any],
               let tools = result["tools"] as? [[String: Any]],
-              tools.count == 12,
+              tools.count == 13,
               let transition = tools.first(where: { $0["name"] as? String == "release_radar_transition_ticket" }),
-              let schema = transition["inputSchema"] as? [String: Any],
-              let properties = schema["properties"] as? [String: Any],
-              let required = schema["required"] as? [String]
+              let transitionSchema = transition["inputSchema"] as? [String: Any],
+              let transitionProperties = transitionSchema["properties"] as? [String: Any],
+              let transitionRequired = transitionSchema["required"] as? [String],
+              let activePhase = tools.first(where: { $0["name"] as? String == "release_radar_set_active_phase" }),
+              let activePhaseSchema = activePhase["inputSchema"] as? [String: Any]
         else { return false }
-        return Set(properties.keys) == ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "ticketID", "lane"]
-            && Set(required) == ["version", "requestID", "projectRoot", "reason", "ticketID", "lane"]
-            && schema["additionalProperties"] as? Bool == false
+        let expectedActivePhaseSchema: [String: Any] = [
+            "type": "object",
+            "properties": [
+                "version": ["type": "integer", "const": 1],
+                "requestID": ["type": "string", "format": "uuid"],
+                "projectRoot": ["type": "string", "minLength": 1],
+                "assertedThreadID": ["type": "string", "minLength": 1],
+                "reason": ["type": "string", "minLength": 1],
+                "phaseID": ["type": "string", "minLength": 1],
+            ],
+            "required": ["version", "requestID", "projectRoot", "reason", "phaseID"],
+            "additionalProperties": false,
+        ]
+        return Set(transitionProperties.keys) == ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "ticketID", "lane"]
+            && Set(transitionRequired) == ["version", "requestID", "projectRoot", "reason", "ticketID", "lane"]
+            && transitionSchema["additionalProperties"] as? Bool == false
+            && NSDictionary(dictionary: activePhaseSchema).isEqual(to: expectedActivePhaseSchema)
     }
 
     private func decodeCommandResult(_ response: [String: Any]) throws -> AgentCommandResult {
         guard let result = response["result"] as? [String: Any],
               let content = result["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String,
               let data = text.data(using: .utf8)
         else {
             throw TransportTestError.invalidResponse(String(describing: response))
         }


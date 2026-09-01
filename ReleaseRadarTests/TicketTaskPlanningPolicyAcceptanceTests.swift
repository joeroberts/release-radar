import Foundation
import XCTest
@testable import ReleaseRadarCore

final class TicketTaskPlanningPolicyAcceptanceTests: XCTestCase {
    private let projectID = ProjectID(rawValue: "task-project")
    private let otherProjectID = ProjectID(rawValue: "other-project")
    private let actor = DeliveryActor(id: "ticket-task-policy-tests")

    func testAcceptanceRejectsMissingTicketWithoutEffects() async throws {
        let fixture = try await makeFixture()
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.ticketNotFound)
        ) {
            try await self.readAcceptance(fixture.store, ticket: "TASK-MISSING", expected: nil)
        }
    }

    func testAcceptanceReadsTransactionLocalStagedTicketAndCallerFinalizesLane() async throws {
        let fixture = try await makeFixture()
        let stagedProjectID = projectID
        try await fixture.store.transact(actor: actor, reason: "Stage and accept ticket") { connection in
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('TASK-STAGED', 'task-project', 'task-phase', 'Staged', 'backlog')"
            )
            try TicketTaskPlanningPolicy.assertCanAcceptTicket(
                projectID: stagedProjectID,
                ticketID: .init(rawValue: "TASK-STAGED"),
                expectedRevision: nil,
                connection: connection
            )
            try connection.execute(
                "UPDATE tickets SET lane = 'accepted' WHERE project_id = 'task-project' AND id = 'TASK-STAGED'"
            )
        }

        let lane = try await fixture.store.read { connection in
            try connection.scalarText(
                "SELECT lane FROM tickets WHERE project_id = 'task-project' AND id = 'TASK-STAGED'"
            )
        }
        XCTAssertEqual(lane, TicketLane.accepted.rawValue)
    }

    func testNoPlanAcceptanceRequiresNilRevisionAndHasNoEffects() async throws {
        let fixture = try await makeFixture()
        let before = try await snapshot(fixture.store)
        try await fixture.store.read { connection in
            try TicketTaskPlanningPolicy.assertCanAcceptTicket(
                projectID: .init(rawValue: "task-project"),
                ticketID: .init(rawValue: "TASK-ATOMIC"),
                expectedRevision: nil,
                connection: connection
            )
        }
        try await assertSnapshot(fixture.store, equals: before)
        try await assertRejected(fixture.store, equals: .ticketTaskPlanNotFound) {
            try await fixture.store.read { connection in
                try TicketTaskPlanningPolicy.assertCanAcceptTicket(
                    projectID: .init(rawValue: "task-project"),
                    ticketID: .init(rawValue: "TASK-ATOMIC"),
                    expectedRevision: 1,
                    connection: connection
                )
            }
        }
    }

    func testCreationRequiresNilRevisionAndReturnsRevisionOne() async throws {
        let fixture = try await makeFixture()
        let returned = try await revise(
            fixture.store,
            ticket: "TASK-CREATE",
            expected: nil,
            additions: [draft("task-b", "B", 1), draft("task-a", "A", 1)]
        )
        XCTAssertEqual(returned.revision, 1)
        XCTAssertEqual(returned.projectID, projectID)
        XCTAssertEqual(returned.ticketID, .init(rawValue: "TASK-CREATE"))
        XCTAssertEqual(returned.createdAt, returned.updatedAt)
        let rows = try await taskRows(fixture.store, ticket: "TASK-CREATE")
        XCTAssertEqual(rows.map(\.id.rawValue), ["task-a", "task-b"])
        XCTAssertTrue(rows.allSatisfy { $0.completion == .pending && $0.lifecycle == .active })
        XCTAssertTrue(rows.allSatisfy { $0.createdAt == returned.createdAt && $0.updatedAt == returned.updatedAt })
        let auditCount = try await planAuditCount(fixture.store, ticket: "TASK-CREATE")
        XCTAssertEqual(auditCount, 1)
    }

    func testCreationRejectsEmptyOrNonCreationOperationsWithoutEffects() async throws {
        let fixture = try await makeFixture()
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.emptyOperationSet)) {
            _ = try await self.revise(fixture.store, ticket: "TASK-CREATE", expected: nil)
        }
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.invalidCreationOperations)) {
            _ = try await self.revise(
                fixture.store,
                ticket: "TASK-CREATE",
                expected: nil,
                additions: [self.draft("new", "New", 0)],
                revisions: [.init(id: .init(rawValue: "missing"), title: "Changed", sortOrder: nil)]
            )
        }
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.invalidCreationOperations)) {
            _ = try await self.revise(
                fixture.store,
                ticket: "TASK-CREATE",
                expected: nil,
                additions: [self.draft("new", "New", 0)],
                superseded: [.init(rawValue: "other")]
            )
        }
    }

    func testPlanExistenceAndStaleRevisionErrorsReturnTypedCurrentState() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        try await assertRejected(fixture.store, equals: .ticketTaskPlanAlreadyExists) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [self.draft("b", "B", 1)])
        }
        try await assertRejected(
            fixture.store,
            equals: .ticketTaskPlanRevisionConflict(expected: 2, current: 1)
        ) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 2, additions: [self.draft("b", "B", 1)])
        }
        try await assertRejected(fixture.store, equals: .ticketTaskPlanNotFound) {
            _ = try await self.revise(fixture.store, ticket: "TASK-ATOMIC", expected: 1, additions: [self.draft("b", "B", 1)])
        }
        try await assertRejected(fixture.store, equals: .ticketTaskPlanNotFound) {
            _ = try await self.complete(fixture.store, ticket: "TASK-ATOMIC", task: "missing", expected: 1)
        }
    }

    func testMixedRevisionAdvancesExactlyOnceAndUsesCanonicalOrdering() async throws {
        let fixture = try await makeFixture()
        let initialPlan = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: nil,
            additions: [draft("c", "C", 2), draft("b", "B", 1), draft("a", "A", 1)]
        )
        let initialRows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        let initialByID = Dictionary(uniqueKeysWithValues: initialRows.map { ($0.id.rawValue, $0) })
        let adjacentBefore = try await adjacentSnapshot(fixture.store)
        let auditCountBefore = try await planAuditCount(fixture.store, ticket: "TASK-REVISE")
        let auditID = AuditEventID(rawValue: "mixed-revision-audit")
        let returned = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: 1,
            additions: [draft("aa", "AA", 1)],
            revisions: [.init(id: .init(rawValue: "c"), title: "C revised", sortOrder: 0)],
            superseded: [.init(rawValue: "b")],
            auditEventID: auditID
        )
        XCTAssertEqual(returned.revision, 2)
        XCTAssertEqual(returned.createdAt, initialPlan.createdAt)
        let persistedPlan = try await planRecord(fixture.store, ticket: "TASK-REVISE")
        XCTAssertEqual(persistedPlan, returned)

        let rows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id.rawValue, $0) })
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows.filter { $0.lifecycle == .active }.map(\.id.rawValue), ["c", "a", "aa"])
        XCTAssertEqual(byID["a"], initialByID["a"])

        let revised = try XCTUnwrap(byID["c"])
        let initialRevised = try XCTUnwrap(initialByID["c"])
        XCTAssertEqual(revised.label, initialRevised.label)
        XCTAssertEqual(revised.title, "C revised")
        XCTAssertEqual(revised.sortOrder, 0)
        XCTAssertEqual(revised.completion, .pending)
        XCTAssertEqual(revised.lifecycle, .active)
        XCTAssertEqual(revised.createdAt, initialRevised.createdAt)
        XCTAssertEqual(revised.updatedAt, returned.updatedAt)
        XCTAssertNil(revised.completedAt)
        XCTAssertNil(revised.supersededAt)

        let superseded = try XCTUnwrap(byID["b"])
        let initialSuperseded = try XCTUnwrap(initialByID["b"])
        XCTAssertEqual(superseded.label, initialSuperseded.label)
        XCTAssertEqual(superseded.title, initialSuperseded.title)
        XCTAssertEqual(superseded.sortOrder, initialSuperseded.sortOrder)
        XCTAssertEqual(superseded.completion, .pending)
        XCTAssertEqual(superseded.lifecycle, .superseded)
        XCTAssertEqual(superseded.createdAt, initialSuperseded.createdAt)
        XCTAssertEqual(superseded.updatedAt, returned.updatedAt)
        XCTAssertNil(superseded.completedAt)
        XCTAssertEqual(superseded.supersededAt, returned.updatedAt)

        let added = try XCTUnwrap(byID["aa"])
        XCTAssertEqual(added.label, "AA")
        XCTAssertEqual(added.title, "Title aa")
        XCTAssertEqual(added.sortOrder, 1)
        XCTAssertEqual(added.completion, .pending)
        XCTAssertEqual(added.lifecycle, .active)
        XCTAssertEqual(added.createdAt, returned.updatedAt)
        XCTAssertEqual(added.updatedAt, returned.updatedAt)
        XCTAssertNil(added.completedAt)
        XCTAssertNil(added.supersededAt)

        let auditCountAfter = try await planAuditCount(fixture.store, ticket: "TASK-REVISE")
        let persistedAudit = try await auditEvidence(fixture.store, id: auditID)
        XCTAssertEqual(auditCountAfter, auditCountBefore + 1)
        XCTAssertEqual(
            persistedAudit,
            [.text(auditID.rawValue), .text("task-project"), .text("ticket_task_plan"), .text("TASK-REVISE"), .text("Revise task plan")]
        )
        try await assertAdjacentSnapshot(fixture.store, equals: adjacentBefore)
    }

    func testDefinitionRevisionAllowsOnlyEffectiveActivePendingTitleOrOrderChanges() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 1), draft("b", "B", 2)])
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.emptyDefinitionRevision(.init(rawValue: "a")))
        ) {
            _ = try await self.revise(
                fixture.store,
                ticket: "TASK-REVISE",
                expected: 1,
                revisions: [.init(id: .init(rawValue: "a"), title: nil, sortOrder: nil)]
            )
        }
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.noEffectiveDefinitionRevision(.init(rawValue: "a")))
        ) {
            _ = try await self.revise(
                fixture.store,
                ticket: "TASK-REVISE",
                expected: 1,
                revisions: [.init(id: .init(rawValue: "a"), title: "Title a", sortOrder: 1)]
            )
        }
        let result = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: 1,
            revisions: [.init(id: .init(rawValue: "a"), title: "Changed", sortOrder: 0)]
        )
        XCTAssertEqual(result.revision, 2)
    }

    func testCompletionIsMonotonicAndAdvancesExactlyOnce() async throws {
        let fixture = try await makeFixture()
        let initialPlan = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        let initialRows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        let initialRow = try XCTUnwrap(initialRows.first)
        let adjacentBefore = try await adjacentSnapshot(fixture.store)
        let auditCountBefore = try await planAuditCount(fixture.store, ticket: "TASK-REVISE")
        let auditID = AuditEventID(rawValue: "complete-task-audit")
        let completed = try await complete(
            fixture.store,
            ticket: "TASK-REVISE",
            task: "a",
            expected: 1,
            auditEventID: auditID
        )
        XCTAssertEqual(completed.revision, 2)
        XCTAssertEqual(completed.createdAt, initialPlan.createdAt)
        let persistedPlan = try await planRecord(fixture.store, ticket: "TASK-REVISE")
        XCTAssertEqual(persistedPlan, completed)
        let completedRows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        XCTAssertEqual(completedRows.count, 1)
        let row = try XCTUnwrap(completedRows.first)
        XCTAssertEqual(row.projectID, initialRow.projectID)
        XCTAssertEqual(row.ticketID, initialRow.ticketID)
        XCTAssertEqual(row.id, initialRow.id)
        XCTAssertEqual(row.label, initialRow.label)
        XCTAssertEqual(row.title, initialRow.title)
        XCTAssertEqual(row.sortOrder, initialRow.sortOrder)
        XCTAssertEqual(row.completion, .completed)
        XCTAssertEqual(row.lifecycle, initialRow.lifecycle)
        XCTAssertEqual(row.createdAt, initialRow.createdAt)
        XCTAssertEqual(row.updatedAt, completed.updatedAt)
        XCTAssertEqual(row.completedAt, completed.updatedAt)
        XCTAssertNil(row.supersededAt)
        let auditCountAfter = try await planAuditCount(fixture.store, ticket: "TASK-REVISE")
        let persistedAudit = try await auditEvidence(fixture.store, id: auditID)
        XCTAssertEqual(auditCountAfter, auditCountBefore + 1)
        XCTAssertEqual(
            persistedAudit,
            [.text(auditID.rawValue), .text("task-project"), .text("ticket_task_plan"), .text("TASK-REVISE"), .text("Complete task")]
        )
        try await assertAdjacentSnapshot(fixture.store, equals: adjacentBefore)
        try await assertRejected(fixture.store, equals: .ticketTaskImmutable(.init(rawValue: "a"))) {
            _ = try await self.complete(fixture.store, ticket: "TASK-REVISE", task: "a", expected: 2)
        }
    }

    func testSupersessionPreservesCompletionAndCompletedTimestamp() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: nil,
            additions: [draft("a", "A", 0), draft("b", "B", 1), draft("c", "C", 2)]
        )
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: 1, superseded: [.init(rawValue: "a")])
        let supersededRows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        let pending = try XCTUnwrap(supersededRows.first { $0.id.rawValue == "a" })
        XCTAssertEqual(pending.completion, .pending)
        XCTAssertEqual(pending.lifecycle, .superseded)
        XCTAssertNil(pending.completedAt)
        XCTAssertEqual(pending.supersededAt, pending.updatedAt)

        try await assertRejected(fixture.store, equals: .ticketTaskImmutable(.init(rawValue: "a"))) {
            _ = try await self.revise(
                fixture.store,
                ticket: "TASK-REVISE",
                expected: 2,
                revisions: [.init(id: .init(rawValue: "a"), title: "Changed", sortOrder: nil)]
            )
        }
        try await assertRejected(fixture.store, equals: .ticketTaskImmutable(.init(rawValue: "a"))) {
            _ = try await self.complete(fixture.store, ticket: "TASK-REVISE", task: "a", expected: 2)
        }
        try await assertRejected(fixture.store, equals: .ticketTaskImmutable(.init(rawValue: "a"))) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 2, superseded: [.init(rawValue: "a")])
        }

        _ = try await complete(fixture.store, ticket: "TASK-REVISE", task: "b", expected: 2)
        let completedRows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        let completedAt = try XCTUnwrap(completedRows.first { $0.id.rawValue == "b" }?.completedAt)
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: 3, superseded: [.init(rawValue: "b")])
        let finalRows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        let completed = try XCTUnwrap(finalRows.first { $0.id.rawValue == "b" })
        XCTAssertEqual(completed.completion, .completed)
        XCTAssertEqual(completed.lifecycle, .superseded)
        XCTAssertEqual(completed.completedAt, completedAt)
        XCTAssertEqual(completed.supersededAt, completed.updatedAt)
    }

    func testLastActiveTaskRequiresAtomicReplacement() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        let before = try await snapshot(fixture.store)
        let error = await capturedError {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, superseded: [.init(rawValue: "a")])
        }
        XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .ticketTaskReplacementRequired)
        try await assertSnapshot(fixture.store, equals: before)
        let result = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: 1,
            additions: [draft("b", "B", 1)],
            superseded: [.init(rawValue: "a")]
        )
        XCTAssertEqual(result.revision, 2)
    }

    func testDuplicateIDsWithinAndAcrossOperationArraysRejectWithoutEffects() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0), draft("b", "B", 1)])
        let cases: [([TicketTaskDraft], [TicketTaskDefinitionRevision], [TicketTaskID], TicketTaskID)] = [
            ([draft("x", "X", 2), draft("x", "Y", 3)], [], [], .init(rawValue: "x")),
            ([], [.init(id: .init(rawValue: "a"), title: "One", sortOrder: nil), .init(id: .init(rawValue: "a"), title: "Two", sortOrder: nil)], [], .init(rawValue: "a")),
            ([], [], [.init(rawValue: "a"), .init(rawValue: "a")], .init(rawValue: "a")),
            ([draft("a", "X", 2)], [.init(id: .init(rawValue: "a"), title: "Changed", sortOrder: nil)], [], .init(rawValue: "a")),
            ([draft("a", "X", 2)], [], [.init(rawValue: "a")], .init(rawValue: "a")),
            ([], [.init(id: .init(rawValue: "a"), title: "Changed", sortOrder: nil)], [.init(rawValue: "a")], .init(rawValue: "a")),
        ]
        for item in cases {
            let before = try await snapshot(fixture.store)
            let error = await capturedError {
                _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, additions: item.0, revisions: item.1, superseded: item.2)
            }
            XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(.duplicateOperationTaskID(item.3)))
            try await assertSnapshot(fixture.store, equals: before)
        }
    }

    func testOperationIDsUseSQLiteBinaryByteSemantics() async throws {
        let fixture = try await makeFixture()
        let precomposed = "\u{00E9}"
        let decomposed = "e\u{0301}"
        XCTAssertEqual(precomposed, decomposed)
        XCTAssertNotEqual(Data(precomposed.utf8), Data(decomposed.utf8))

        let plan = try await revise(
            fixture.store,
            ticket: "TASK-CREATE",
            expected: nil,
            additions: [draft(precomposed, "Precomposed", 0), draft(decomposed, "Decomposed", 0)]
        )
        XCTAssertEqual(plan.revision, 1)
        let persistedIDBytes = try await taskRows(fixture.store, ticket: "TASK-CREATE")
            .map { Data($0.id.rawValue.utf8) }
        XCTAssertEqual(persistedIDBytes, [Data(decomposed.utf8), Data(precomposed.utf8)])
    }

    func testHistoricalIDsAndLabelsCannotBeReused() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0), draft("b", "B", 1)])
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.taskIDAlreadyUsed(.init(rawValue: "a")))
        ) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, additions: [self.draft("a", "New", 2)])
        }
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: 1, superseded: [.init(rawValue: "a")])
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.taskIDAlreadyUsed(.init(rawValue: "a")))
        ) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 2, additions: [self.draft("a", "New", 2)])
        }
    }

    func testOperationCountAcceptsSixtyThreeAndSixtyFourAndRejectsSixtyFive() async throws {
        try await assertOperationCount(63, succeeds: true)
        try await assertOperationCount(64, succeeds: true)
        try await assertOperationCount(65, succeeds: false)
    }

    func testASCIIAndMultibyteUTF8BoundariesRejectWithoutTruncation() async throws {
        let validValues = [
            String(repeating: "a", count: 255), String(repeating: "a", count: 256),
            String(repeating: "é", count: 127) + "a", String(repeating: "é", count: 128),
        ]
        for (index, value) in validValues.enumerated() {
            let fixture = try await makeFixture()
            let title = index < 2 ? String(repeating: "t", count: index == 0 ? 4_095 : 4_096) : String(repeating: "é", count: index == 2 ? 2_047 : 2_048) + (index == 2 ? "a" : "")
            _ = try await revise(fixture.store, ticket: "TASK-LIMIT", expected: nil, additions: [.init(id: .init(rawValue: value), label: value, title: title, sortOrder: 0)])
            let persistedRows = try await taskRows(fixture.store, ticket: "TASK-LIMIT")
            let row = try XCTUnwrap(persistedRows.first)
            XCTAssertEqual(row.id.rawValue, value)
            XCTAssertEqual(row.label, value)
            XCTAssertEqual(row.title, title)
        }
        let invalid: [(String, String, String, InvalidTicketTaskMutationReason)] = [
            (String(repeating: "i", count: 257), "L", "T", .invalidTaskID(.init(rawValue: String(repeating: "i", count: 257)))),
            ("id", String(repeating: "l", count: 257), "T", .invalidLabel(taskID: .init(rawValue: "id"))),
            ("id", "L", String(repeating: "t", count: 4_097), .invalidTitle(taskID: .init(rawValue: "id"))),
            (String(repeating: "é", count: 128) + "a", "L", "T", .invalidTaskID(.init(rawValue: String(repeating: "é", count: 128) + "a"))),
            ("id", String(repeating: "é", count: 128) + "a", "T", .invalidLabel(taskID: .init(rawValue: "id"))),
            ("id", "L", String(repeating: "é", count: 2_048) + "a", .invalidTitle(taskID: .init(rawValue: "id"))),
        ]
        for item in invalid {
            let fixture = try await makeFixture()
            let before = try await snapshot(fixture.store)
            let error = await capturedError {
                _ = try await self.revise(fixture.store, ticket: "TASK-LIMIT", expected: nil, additions: [.init(id: .init(rawValue: item.0), label: item.1, title: item.2, sortOrder: 0)])
            }
            XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(item.3))
            try await assertSnapshot(fixture.store, equals: before)
        }
    }

    func testInvalidEmptyWhitespaceNULAndSortOrderValuesRejectWithoutEffects() async throws {
        let cases: [(TicketTaskDraft, InvalidTicketTaskMutationReason)] = [
            (draft("", "L", 0), .invalidTaskID(.init(rawValue: ""))),
            (draft("   ", "L", 0), .invalidTaskID(.init(rawValue: "   "))),
            (draft("a\0b", "L", 0), .invalidTaskID(.init(rawValue: "a\0b"))),
            (.init(id: .init(rawValue: "empty-label"), label: "", title: "T", sortOrder: 0), .invalidLabel(taskID: .init(rawValue: "empty-label"))),
            (.init(id: .init(rawValue: "id"), label: "   ", title: "T", sortOrder: 0), .invalidLabel(taskID: .init(rawValue: "id"))),
            (.init(id: .init(rawValue: "id"), label: "L\0", title: "T", sortOrder: 0), .invalidLabel(taskID: .init(rawValue: "id"))),
            (.init(id: .init(rawValue: "empty-title"), label: "L", title: "", sortOrder: 0), .invalidTitle(taskID: .init(rawValue: "empty-title"))),
            (.init(id: .init(rawValue: "id"), label: "L", title: " \n", sortOrder: 0), .invalidTitle(taskID: .init(rawValue: "id"))),
            (.init(id: .init(rawValue: "id"), label: "L", title: "T\0", sortOrder: 0), .invalidTitle(taskID: .init(rawValue: "id"))),
            (draft("id", "L", -1), .invalidSortOrder(taskID: .init(rawValue: "id"))),
        ]
        for item in cases {
            let fixture = try await makeFixture()
            let before = try await snapshot(fixture.store)
            let error = await capturedError {
                _ = try await self.revise(fixture.store, ticket: "TASK-CREATE", expected: nil, additions: [item.0])
            }
            XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(item.1))
            try await assertSnapshot(fixture.store, equals: before)
        }

        let invalidID = TicketTaskID(rawValue: "")
        let definitionCases: [(TicketTaskDefinitionRevision, InvalidTicketTaskMutationReason)] = [
            (.init(id: invalidID, title: "Changed", sortOrder: nil), .invalidTaskID(invalidID)),
            (.init(id: .init(rawValue: "a"), title: "", sortOrder: nil), .invalidTitle(taskID: .init(rawValue: "a"))),
            (.init(id: .init(rawValue: "a"), title: "Changed", sortOrder: -1), .invalidSortOrder(taskID: .init(rawValue: "a"))),
        ]
        for item in definitionCases {
            let fixture = try await makeFixture()
            _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
            try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(item.1)) {
                _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, revisions: [item.0])
            }
        }

        let supersessionFixture = try await makeFixture()
        _ = try await revise(
            supersessionFixture.store,
            ticket: "TASK-REVISE",
            expected: nil,
            additions: [draft("a", "A", 0), draft("b", "B", 1)]
        )
        try await assertRejected(
            supersessionFixture.store,
            equals: .invalidTicketTaskMutation(.invalidTaskID(invalidID))
        ) {
            _ = try await self.revise(
                supersessionFixture.store,
                ticket: "TASK-REVISE",
                expected: 1,
                superseded: [invalidID]
            )
        }

        let completionFixture = try await makeFixture()
        _ = try await revise(completionFixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        try await assertRejected(
            completionFixture.store,
            equals: .invalidTicketTaskMutation(.invalidTaskID(invalidID))
        ) {
            _ = try await self.complete(completionFixture.store, ticket: "TASK-REVISE", task: "", expected: 1)
        }
    }

    func testAcceptedTicketPlanRejectsRevisionCompletionAndSupersession() async throws {
        let fixture = try await makeFixture()
        try await seedTerminalPlan(fixture.store)
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.acceptedTicket)) {
            _ = try await self.revise(fixture.store, ticket: "TASK-TERMINAL", expected: 1, additions: [self.draft("b", "B", 1)])
        }
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.acceptedTicket)) {
            _ = try await self.complete(fixture.store, ticket: "TASK-TERMINAL", task: "a", expected: 1)
        }
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.acceptedTicket)) {
            _ = try await self.revise(fixture.store, ticket: "TASK-TERMINAL", expected: 1, superseded: [.init(rawValue: "a")])
        }
    }

    func testAcceptanceRequiresExactRevisionAndEveryActiveTaskCompleted() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-ACCEPT", expected: nil, additions: [draft("a", "A", 0), draft("b", "B", 1)])
        try await assertRejected(
            fixture.store,
            equals: .ticketTaskPlanRevisionConflict(expected: nil, current: 1)
        ) {
            try await self.readAcceptance(fixture.store, ticket: "TASK-ACCEPT", expected: nil)
        }
        try await assertRejected(
            fixture.store,
            equals: .ticketTaskPlanRevisionConflict(expected: 2, current: 1)
        ) {
            try await self.readAcceptance(fixture.store, ticket: "TASK-ACCEPT", expected: 2)
        }
        try await assertRejected(
            fixture.store,
            equals: .ticketTaskIncomplete(pendingTaskIDs: [.init(rawValue: "a"), .init(rawValue: "b")])
        ) {
            try await self.readAcceptance(fixture.store, ticket: "TASK-ACCEPT", expected: 1)
        }
        _ = try await complete(fixture.store, ticket: "TASK-ACCEPT", task: "a", expected: 1)
        _ = try await complete(fixture.store, ticket: "TASK-ACCEPT", task: "b", expected: 2)
        let beforeAcceptance = try await snapshot(fixture.store)
        try await readAcceptance(fixture.store, ticket: "TASK-ACCEPT", expected: 3)
        try await assertSnapshot(fixture.store, equals: beforeAcceptance)
    }

    func testWrongProjectAndTicketOwnershipFailClosed() async throws {
        let fixture = try await makeFixture()
        let before = try await snapshot(fixture.store)
        let testActor = actor
        let addition = draft("a", "A", 0)
        let error = await capturedError {
            _ = try await fixture.store.transact(actor: testActor, reason: "wrong owner") { connection in
                try TicketTaskPlanningPolicy.revisePlan(
                    projectID: .init(rawValue: "other-project"), ticketID: .init(rawValue: "TASK-REVISE"),
                    expectedRevision: nil, additions: [addition], definitionRevisions: [], supersededTaskIDs: [], connection: connection
                )
            }
        }
        XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(.ticketNotFound))
        try await assertSnapshot(fixture.store, equals: before)
    }

    func testCompletionChecksOwnerTicketAndPlanBeforeTaskIDValidation() async throws {
        let fixture = try await makeFixture()
        let testActor = actor
        let invalidTaskID = TicketTaskID(rawValue: "")
        let cases: [(ProjectID, TicketID, Int64, TicketTaskPlanningPolicyError)] = [
            (projectID, .init(rawValue: "MISSING"), 1, .invalidTicketTaskMutation(.ticketNotFound)),
            (otherProjectID, .init(rawValue: "TASK-REVISE"), 1, .invalidTicketTaskMutation(.ticketNotFound)),
            (projectID, .init(rawValue: "TASK-TERMINAL-ATOMIC"), 1, .invalidTicketTaskMutation(.acceptedTicket)),
            (projectID, .init(rawValue: "TASK-ATOMIC"), 1, .ticketTaskPlanNotFound),
        ]
        for item in cases {
            try await assertRejected(fixture.store, equals: item.3) {
                _ = try await fixture.store.transact(
                    actor: testActor,
                    reason: "Complete invalid task",
                    auditScope: .init(projectID: item.0, entityType: .ticketTaskPlan, entityID: item.1.rawValue)
                ) { connection in
                    try TicketTaskPlanningPolicy.completeTask(
                        projectID: item.0,
                        ticketID: item.1,
                        taskID: invalidTaskID,
                        expectedRevision: item.2,
                        connection: connection
                    )
                }
            }
        }

        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        try await assertRejected(
            fixture.store,
            equals: .ticketTaskPlanRevisionConflict(expected: 2, current: 1)
        ) {
            _ = try await self.complete(fixture.store, ticket: "TASK-REVISE", task: "", expected: 2)
        }
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.invalidTaskID(invalidTaskID))
        ) {
            _ = try await self.complete(fixture.store, ticket: "TASK-REVISE", task: "", expected: 1)
        }
    }

    func testTaskOnlyMutationsPreserveTicketLanePhasePlanGoalsAndDeliveryEffects() async throws {
        let fixture = try await makeFixture()
        let before = try await adjacentSnapshot(fixture.store)
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0), draft("b", "B", 1)])
        _ = try await complete(fixture.store, ticket: "TASK-REVISE", task: "a", expected: 1)
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: 2, revisions: [.init(id: .init(rawValue: "b"), title: "Changed", sortOrder: 0)])
        try await assertAdjacentSnapshot(fixture.store, equals: before)
    }

    func testLateStoreAuditFailureRollsBackPlanTasksRevisionAndAuditAtomically() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        let duplicate = AuditEventID(rawValue: "duplicate-audit")
        try await fixture.store.transact(actor: actor, reason: "consume audit", auditEventID: duplicate) { _ in () }
        let before = try await snapshot(fixture.store)
        let testActor = actor
        let mainProjectID = projectID
        let addition = draft("b", "B", 1)
        let error = await capturedError {
            _ = try await fixture.store.transact(
                actor: testActor, reason: "late failure", auditEventID: duplicate,
                auditScope: .init(projectID: mainProjectID, entityType: .ticketTaskPlan, entityID: "TASK-REVISE")
            ) { connection in
                try TicketTaskPlanningPolicy.revisePlan(
                    projectID: mainProjectID, ticketID: .init(rawValue: "TASK-REVISE"), expectedRevision: 1,
                    additions: [addition], definitionRevisions: [], supersededTaskIDs: [], connection: connection
                )
            }
        }
        XCTAssertTrue(error is SQLiteError)
        try await assertSnapshot(fixture.store, equals: before)
    }

    func testProjectAndTicketEmbeddedNULRejectBeforeSQLAcrossEveryEntryPoint() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        let testActor = actor
        let addition = draft("b", "B", 1)
        for useBadProject in [true, false] {
            let project = ProjectID(rawValue: useBadProject ? "task\0-project" : "task-project")
            let ticket = TicketID(rawValue: useBadProject ? "TASK-REVISE" : "TASK\0-REVISE")
            try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.ticketNotFound)) {
                _ = try await fixture.store.transact(actor: testActor, reason: "nul revise") { connection in
                    try TicketTaskPlanningPolicy.revisePlan(projectID: project, ticketID: ticket, expectedRevision: 1, additions: [addition], definitionRevisions: [], supersededTaskIDs: [], connection: connection)
                }
            }
            try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.ticketNotFound)) {
                _ = try await fixture.store.transact(actor: testActor, reason: "nul complete") { connection in
                    try TicketTaskPlanningPolicy.completeTask(projectID: project, ticketID: ticket, taskID: .init(rawValue: "a"), expectedRevision: 1, connection: connection)
                }
            }
            try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.ticketNotFound)) {
                try await fixture.store.read { connection in
                    try TicketTaskPlanningPolicy.assertCanAcceptTicket(projectID: project, ticketID: ticket, expectedRevision: 1, connection: connection)
                }
            }
        }
    }

    func testAdditionLabelsPreflightBinaryDuplicatesAndAllowCaseDistinctValues() async throws {
        let fixture = try await makeFixture()
        let before = try await snapshot(fixture.store)
        let error = await capturedError {
            _ = try await self.revise(fixture.store, ticket: "TASK-CREATE", expected: nil, additions: [self.draft("a", "Same", 0), self.draft("b", "Same", 1)])
        }
        XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(.labelAlreadyUsed("Same")))
        try await assertSnapshot(fixture.store, equals: before)
        _ = try await revise(fixture.store, ticket: "TASK-CREATE", expected: nil, additions: [draft("a", "Task A", 0), draft("b", "task a", 1)])
        let labels = try await taskRows(fixture.store, ticket: "TASK-CREATE").map(\.label)
        XCTAssertEqual(labels, ["Task A", "task a"])
    }

    func testLabelReuseAgainstActiveAndSupersededHistoryRejectsWithoutEffects() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: nil,
            additions: [draft("active", "Active Label", 0), draft("old", "Old Label", 1)]
        )
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.labelAlreadyUsed("Active Label"))
        ) {
            _ = try await self.revise(
                fixture.store,
                ticket: "TASK-REVISE",
                expected: 1,
                additions: [self.draft("active-label-reuse", "Active Label", 2)]
            )
        }

        _ = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: 1,
            superseded: [.init(rawValue: "old")]
        )
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.labelAlreadyUsed("Old Label"))
        ) {
            _ = try await self.revise(
                fixture.store,
                ticket: "TASK-REVISE",
                expected: 2,
                additions: [self.draft("superseded-label-reuse", "Old Label", 2)]
            )
        }

        let result = try await revise(
            fixture.store,
            ticket: "TASK-REVISE",
            expected: 2,
            additions: [draft("case-distinct", "active label", 2)]
        )
        XCTAssertEqual(result.revision, 3)
        let rows = try await taskRows(fixture.store, ticket: "TASK-REVISE")
        XCTAssertEqual(rows.first { $0.id.rawValue == "case-distinct" }?.label, "active label")
    }

    func testCurrentRevisionRejectsEmptyLaterRevisionWithoutEffects() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        let before = try await snapshot(fixture.store)
        let error = await capturedError { _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1) }
        XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(.emptyOperationSet))
        try await assertSnapshot(fixture.store, equals: before)
    }

    func testNoEffectiveDefinitionRevisionRejectsEvenWithEffectiveAddition() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        let before = try await snapshot(fixture.store)
        let error = await capturedError {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, additions: [self.draft("b", "B", 1)], revisions: [.init(id: .init(rawValue: "a"), title: "Title a", sortOrder: 0)])
        }
        XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(.noEffectiveDefinitionRevision(.init(rawValue: "a"))))
        try await assertSnapshot(fixture.store, equals: before)
    }

    func testRevisionExhaustionRejectsReviseAndCompleteBeforeEffects() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        try await fixture.store.transact(actor: actor, reason: "seed max") { connection in
            try connection.execute("UPDATE ticket_task_plans SET revision = ? WHERE project_id = ? AND ticket_id = ?", bindings: [.integer(Int64.max), .text("task-project"), .text("TASK-REVISE")])
        }
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.revisionExhausted)) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: Int64.max, additions: [self.draft("b", "B", 1)])
        }
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.revisionExhausted)) {
            _ = try await self.complete(fixture.store, ticket: "TASK-REVISE", task: "a", expected: Int64.max)
        }
    }

    func testMissingDefinitionCompletionAndSupersessionTargetsReturnTypedErrors() async throws {
        let fixture = try await makeFixture()
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        let missing = TicketTaskID(rawValue: "missing")
        try await assertRejected(fixture.store, equals: .ticketTaskNotFound(missing)) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, revisions: [.init(id: missing, title: "Changed", sortOrder: nil)])
        }
        try await assertRejected(fixture.store, equals: .ticketTaskNotFound(missing)) {
            _ = try await self.complete(fixture.store, ticket: "TASK-REVISE", task: "missing", expected: 1)
        }
        try await assertRejected(fixture.store, equals: .ticketTaskNotFound(missing)) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, superseded: [missing])
        }
    }

    func testAcceptedNoPlanRejectsCreationAndAcceptedPlanRejectsAcceptanceAssertion() async throws {
        let fixture = try await makeFixture()
        try await assertRejected(fixture.store, equals: .invalidTicketTaskMutation(.acceptedTicket)) {
            _ = try await self.revise(fixture.store, ticket: "TASK-TERMINAL-ATOMIC", expected: nil, additions: [self.draft("a", "A", 0)])
        }
        try await seedTerminalPlan(fixture.store)
        let acceptedBefore = try await snapshot(fixture.store)
        let error = await acceptError(fixture.store, ticket: "TASK-TERMINAL", expected: 1)
        XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(.acceptedTicket))
        try await assertSnapshot(fixture.store, equals: acceptedBefore)
    }

    func testAdjacentDeliverySentinelsRemainByteExactAcrossSuccessAndRejection() async throws {
        let fixture = try await makeFixture()
        let before = try await adjacentSnapshot(fixture.store)
        _ = try await revise(fixture.store, ticket: "TASK-REVISE", expected: nil, additions: [draft("a", "A", 0)])
        try await assertRejected(
            fixture.store,
            equals: .invalidTicketTaskMutation(.taskIDAlreadyUsed(.init(rawValue: "a")))
        ) {
            _ = try await self.revise(fixture.store, ticket: "TASK-REVISE", expected: 1, additions: [self.draft("a", "New", 1)])
        }
        try await assertAdjacentSnapshot(fixture.store, equals: before)
    }

    private struct Fixture: Sendable {
        let store: DeliveryStore
    }

    private struct Snapshot: Equatable, Sendable {
        let rows: [[[SQLiteValue]]]
    }

    private func makeFixture() async throws -> Fixture {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-task3-\(UUID().uuidString).sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await store.availability else {
            throw StoreError.unavailable("Task 3 fixture store unavailable")
        }
        let seedAudit = AuditEventID(rawValue: "task-seed-audit")
        try await store.transact(actor: actor, reason: "Seed Task 3 fixture", auditEventID: seedAudit) { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('task-project', 'Task project', 0), ('other-project', 'Other project', 0)")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('task-phase', 'task-project', 'Task phase'), ('other-phase', 'other-project', 'Other phase')")
            try connection.execute(
                """
                INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
                    ('TASK-ATOMIC', 'task-project', 'task-phase', 'Atomic', 'backlog'),
                    ('TASK-CREATE', 'task-project', 'task-phase', 'Create', 'in_progress'),
                    ('TASK-REVISE', 'task-project', 'task-phase', 'Revise', 'in_progress'),
                    ('TASK-LIMIT', 'task-project', 'task-phase', 'Limit', 'in_progress'),
                    ('TASK-ACCEPT', 'task-project', 'task-phase', 'Accept', 'needs_review'),
                    ('TASK-TERMINAL', 'task-project', 'task-phase', 'Terminal', 'needs_review'),
                    ('TASK-TERMINAL-ATOMIC', 'task-project', 'task-phase', 'Terminal atomic', 'accepted'),
                    ('TASK-OTHER', 'other-project', 'other-phase', 'Other', 'backlog')
                """
            )
            let time = "2026-08-31T12:00:00.000Z"
            try connection.execute("INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('task-project', 'task-phase', 'task-sentinel-goal', 'Sentinel', 'Preserved', 'draft', 0, ?, ?)", bindings: [.text(time), .text(time)])
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('task-project', 'task-phase', 'task-sentinel-goal', 0, 'Remain byte exact')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('task-project', 'task-phase', 'task-sentinel-goal', 'TASK-REVISE')")
            try connection.execute("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES (?, 'task-project', 'task-phase', 'TASK-REVISE', NULL, 'task-sentinel-goal', 0, 'assigned')", bindings: [.text(seedAudit.rawValue)])
            try connection.execute("INSERT INTO blockers (id, project_id, ticket_id, summary, resolved_at) VALUES ('task-sentinel-blocker', 'task-project', 'TASK-REVISE', 'Open sentinel', NULL)")
            try connection.execute("INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('task-sentinel-review', 'task-project', 'TASK-REVISE', 'task', 'Open review', 'open')")
            try connection.execute("INSERT INTO notification_events (id, fingerprint, state, ticket_id, project_id, event_kind, subject_id, occurrence, title, message, created_at, attempt_count) VALUES ('task-sentinel-notification', 'task-project:sentinel', 'pending', 'TASK-REVISE', 'task-project', 'ticket', 'TASK-REVISE', 1, 'Sentinel', 'Preserve', ?, 0)", bindings: [.text(time)])
            try connection.execute("INSERT INTO notification_occurrences (subject_key, project_id, event_kind, subject_id, generation, is_active) VALUES ('task-project|task-sentinel-occurrence', 'task-project', 'ticket', 'TASK-REVISE', 1, 1)")
            try connection.execute("INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES ('task-sentinel-request', ?, ?, ?)", bindings: [.blob(Data([1, 2, 3])), .blob(Data([4, 5, 6])), .text(time)])
        }
        return Fixture(store: store)
    }

    private func draft(_ id: String, _ label: String, _ order: Int, title: String? = nil) -> TicketTaskDraft {
        .init(id: .init(rawValue: id), label: label, title: title ?? "Title \(id)", sortOrder: order)
    }

    private func revise(
        _ store: DeliveryStore,
        ticket: String,
        expected: Int64?,
        additions: [TicketTaskDraft] = [],
        revisions: [TicketTaskDefinitionRevision] = [],
        superseded: [TicketTaskID] = [],
        auditEventID: AuditEventID = .init(rawValue: UUID().uuidString)
    ) async throws -> TicketTaskPlanRecord {
        try await store.transact(
            actor: actor,
            reason: "Revise task plan",
            auditEventID: auditEventID,
            auditScope: .init(projectID: projectID, entityType: .ticketTaskPlan, entityID: ticket)
        ) { connection in
            try TicketTaskPlanningPolicy.revisePlan(
                projectID: .init(rawValue: "task-project"), ticketID: .init(rawValue: ticket),
                expectedRevision: expected, additions: additions, definitionRevisions: revisions,
                supersededTaskIDs: superseded, connection: connection
            )
        }
    }

    private func complete(
        _ store: DeliveryStore,
        ticket: String,
        task: String,
        expected: Int64,
        auditEventID: AuditEventID = .init(rawValue: UUID().uuidString)
    ) async throws -> TicketTaskPlanRecord {
        try await store.transact(
            actor: actor,
            reason: "Complete task",
            auditEventID: auditEventID,
            auditScope: .init(projectID: projectID, entityType: .ticketTaskPlan, entityID: ticket)
        ) { connection in
            try TicketTaskPlanningPolicy.completeTask(
                projectID: .init(rawValue: "task-project"), ticketID: .init(rawValue: ticket),
                taskID: .init(rawValue: task), expectedRevision: expected, connection: connection
            )
        }
    }

    private func acceptError(_ store: DeliveryStore, ticket: String, expected: Int64?) async -> Error? {
        await capturedError {
            try await self.readAcceptance(store, ticket: ticket, expected: expected)
        }
    }

    private func readAcceptance(_ store: DeliveryStore, ticket: String, expected: Int64?) async throws {
        try await store.read { connection in
            try TicketTaskPlanningPolicy.assertCanAcceptTicket(
                projectID: .init(rawValue: "task-project"), ticketID: .init(rawValue: ticket),
                expectedRevision: expected, connection: connection
            )
        }
    }

    private func capturedError(_ operation: () async throws -> Void) async -> Error? {
        do {
            try await operation()
            return nil
        } catch {
            return error
        }
    }

    private func assertRejected(
        _ store: DeliveryStore,
        equals expectedError: TicketTaskPlanningPolicyError,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void
    ) async throws {
        let before = try await snapshot(store)
        let error = await capturedError(operation)
        XCTAssertEqual(error as? TicketTaskPlanningPolicyError, expectedError, file: file, line: line)
        try await assertSnapshot(store, equals: before, file: file, line: line)
    }

    private func planRecord(_ store: DeliveryStore, ticket: String) async throws -> TicketTaskPlanRecord? {
        try await store.read { connection in
            guard let row = try connection.row(
                "SELECT project_id, ticket_id, revision, created_at, updated_at FROM ticket_task_plans WHERE project_id = ? AND ticket_id = ?",
                bindings: [.text("task-project"), .text(ticket)]
            ) else {
                return nil
            }
            guard case let .text(projectID)? = row["project_id"],
                  case let .text(ticketID)? = row["ticket_id"],
                  case let .integer(revision)? = row["revision"],
                  case let .text(createdAt)? = row["created_at"],
                  case let .text(updatedAt)? = row["updated_at"]
            else {
                throw SQLiteError(code: 20, message: "Invalid ticket task plan row")
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let createdDate = formatter.date(from: createdAt),
                  let updatedDate = formatter.date(from: updatedAt)
            else {
                throw SQLiteError(code: 20, message: "Invalid ticket task plan timestamp")
            }
            return .init(
                projectID: .init(rawValue: projectID),
                ticketID: .init(rawValue: ticketID),
                revision: revision,
                createdAt: createdDate,
                updatedAt: updatedDate
            )
        }
    }

    private func auditEvidence(_ store: DeliveryStore, id: AuditEventID) async throws -> [SQLiteValue]? {
        try await store.read { connection in
            guard let row = try connection.row(
                "SELECT id, project_id, entity_type, entity_id, reason FROM audit_events WHERE id = ?",
                bindings: [.text(id.rawValue)]
            ) else {
                return nil
            }
            return ["id", "project_id", "entity_type", "entity_id", "reason"].map { row[$0] ?? .null }
        }
    }

    private func taskRows(_ store: DeliveryStore, ticket: String, activeOnly: Bool = false) async throws -> [TicketTaskRecord] {
        try await store.read { connection in
            var records: [TicketTaskRecord] = []
            var offset: Int64 = 0
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            while let row = try connection.row(
                """
                SELECT project_id, ticket_id, id, label, title, sort_order, completion, lifecycle,
                       created_at, updated_at, completed_at, superseded_at
                FROM ticket_tasks
                WHERE project_id = ? AND ticket_id = ? \(activeOnly ? "AND lifecycle = 'active'" : "")
                ORDER BY sort_order, label COLLATE BINARY, id COLLATE BINARY LIMIT 1 OFFSET ?
                """,
                bindings: [.text("task-project"), .text(ticket), .integer(offset)]
            ) {
                guard case let .text(id)? = row["id"], case let .text(label)? = row["label"],
                      case let .text(title)? = row["title"], case let .integer(order)? = row["sort_order"],
                      case let .text(completion)? = row["completion"], case let .text(lifecycle)? = row["lifecycle"],
                      case let .text(created)? = row["created_at"], case let .text(updated)? = row["updated_at"]
                else { throw SQLiteError(code: 20, message: "Invalid task row") }
                records.append(.init(
                    projectID: .init(rawValue: "task-project"), ticketID: .init(rawValue: ticket), id: .init(rawValue: id),
                    label: label, title: title, sortOrder: Int(order), completion: .init(rawValue: completion)!, lifecycle: .init(rawValue: lifecycle)!,
                    createdAt: formatter.date(from: created)!, updatedAt: formatter.date(from: updated)!,
                    completedAt: Self.text(row["completed_at"]).flatMap(formatter.date(from:)),
                    supersededAt: Self.text(row["superseded_at"]).flatMap(formatter.date(from:))
                ))
                offset += 1
            }
            return records
        }
    }

    private func snapshot(_ store: DeliveryStore) async throws -> Snapshot {
        try await store.read { connection in
            Snapshot(rows: try Self.snapshotSections(connection, includeTaskState: true))
        }
    }

    private func adjacentSnapshot(_ store: DeliveryStore) async throws -> Snapshot {
        try await store.read { connection in
            Snapshot(rows: try Self.snapshotSections(connection, includeTaskState: false))
        }
    }

    private func assertSnapshot(
        _ store: DeliveryStore,
        equals expected: Snapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let actual = try await snapshot(store)
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertAdjacentSnapshot(
        _ store: DeliveryStore,
        equals expected: Snapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let actual = try await adjacentSnapshot(store)
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private static func snapshotSections(_ connection: SQLiteConnection, includeTaskState: Bool) throws -> [[[SQLiteValue]]] {
        var queries: [(String, [String])] = [
            ("SELECT id,project_id,phase_id,outcome,lane,plan_legacy_continuation FROM tickets ORDER BY project_id,id", ["id","project_id","phase_id","outcome","lane","plan_legacy_continuation"]),
            ("SELECT project_id,phase_id,state,revision,ready_revision,created_at,updated_at,finalized_at FROM phase_plans ORDER BY project_id,phase_id", ["project_id","phase_id","state","revision","ready_revision","created_at","updated_at","finalized_at"]),
            ("SELECT project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at,activated_at,accepted_at FROM delivery_goals ORDER BY project_id,id", ["project_id","phase_id","id","title","outcome","lifecycle","sort_order","created_at","updated_at","activated_at","accepted_at"]),
            ("SELECT project_id,phase_id,goal_id,sort_order,criterion FROM delivery_goal_done_criteria ORDER BY project_id,phase_id,goal_id,sort_order", ["project_id","phase_id","goal_id","sort_order","criterion"]),
            ("SELECT project_id,phase_id,goal_id,ticket_id FROM delivery_goal_ticket_assignments ORDER BY project_id,ticket_id", ["project_id","phase_id","goal_id","ticket_id"]),
            ("SELECT audit_event_id,project_id,phase_id,ticket_id,previous_goal_id,current_goal_id,revision,action FROM delivery_goal_assignment_events ORDER BY audit_event_id,ticket_id", ["audit_event_id","project_id","phase_id","ticket_id","previous_goal_id","current_goal_id","revision","action"]),
            ("SELECT id,project_id,ticket_id,summary,resolved_at FROM blockers ORDER BY id", ["id","project_id","ticket_id","summary","resolved_at"]),
            ("SELECT id,project_id,ticket_id,kind,summary,status FROM review_items ORDER BY id", ["id","project_id","ticket_id","kind","summary","status"]),
            ("SELECT id,fingerprint,state,ticket_id,goal_id,provider_receipt,acknowledged_at,project_id,event_kind,subject_id,occurrence,title,message,created_at,attempt_count,attempt_started_at,completed_at,failure_code FROM notification_events ORDER BY id", ["id","fingerprint","state","ticket_id","goal_id","provider_receipt","acknowledged_at","project_id","event_kind","subject_id","occurrence","title","message","created_at","attempt_count","attempt_started_at","completed_at","failure_code"]),
            ("SELECT subject_key,project_id,event_kind,subject_id,generation,is_active FROM notification_occurrences ORDER BY subject_key", ["subject_key","project_id","event_kind","subject_id","generation","is_active"]),
            ("SELECT request_id,request_body,result_data,created_at FROM agent_command_requests ORDER BY request_id", ["request_id","request_body","result_data","created_at"]),
        ]
        if includeTaskState {
            queries.append(("SELECT project_id,ticket_id,revision,created_at,updated_at FROM ticket_task_plans ORDER BY project_id,ticket_id", ["project_id","ticket_id","revision","created_at","updated_at"]))
            queries.append(("SELECT project_id,ticket_id,id,label,title,sort_order,completion,lifecycle,created_at,updated_at,completed_at,superseded_at FROM ticket_tasks ORDER BY project_id,ticket_id,id", ["project_id","ticket_id","id","label","title","sort_order","completion","lifecycle","created_at","updated_at","completed_at","superseded_at"]))
            queries.append(("SELECT id,actor_id,thread_id,thread_attribution,project_id,entity_type,entity_id,reason,created_at FROM audit_events ORDER BY id", ["id","actor_id","thread_id","thread_attribution","project_id","entity_type","entity_id","reason","created_at"]))
        }
        return try queries.map { try rows(connection, sql: $0.0, columns: $0.1) }
    }

    private static func rows(_ connection: SQLiteConnection, sql: String, columns: [String]) throws -> [[SQLiteValue]] {
        var result: [[SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try connection.row("SELECT * FROM (\(sql)) LIMIT 1 OFFSET ?", bindings: [.integer(offset)]) {
            result.append(columns.map { row[$0] ?? .null })
            offset += 1
        }
        return result
    }

    private func planAuditCount(_ store: DeliveryStore, ticket: String) async throws -> Int64 {
        try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE project_id = ? AND entity_type = 'ticket_task_plan' AND entity_id = ?", bindings: [.text("task-project"), .text(ticket)]) ?? -1
        }
    }

    private func seedTerminalPlan(_ store: DeliveryStore) async throws {
        _ = try await revise(store, ticket: "TASK-TERMINAL", expected: nil, additions: [draft("a", "A", 0)])
        try await store.transact(actor: actor, reason: "Seed terminal lane") { connection in
            try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE project_id = 'task-project' AND id = 'TASK-TERMINAL'")
        }
    }

    private func assertOperationCount(_ count: Int, succeeds: Bool) async throws {
        let fixture = try await makeFixture()
        let distribution: (additions: Int, revisions: Int, supersessions: Int)
        switch count {
        case 63: distribution = (21, 21, 21)
        case 64: distribution = (22, 21, 21)
        case 65: distribution = (22, 22, 21)
        default: throw SQLiteError(code: 20, message: "Unsupported operation-count fixture")
        }
        XCTAssertEqual(distribution.additions + distribution.revisions + distribution.supersessions, count)
        let existingCount = distribution.revisions + distribution.supersessions
        let existing = (0..<existingCount).map { draft("existing-\($0)", "Existing \($0)", $0) }
        _ = try await revise(fixture.store, ticket: "TASK-LIMIT", expected: nil, additions: existing)
        let additions = (0..<distribution.additions).map { draft("added-\($0)", "Added \($0)", 100 + $0) }
        let revisions = (0..<distribution.revisions).map {
            TicketTaskDefinitionRevision(id: .init(rawValue: "existing-\($0)"), title: "Revised \($0)", sortOrder: nil)
        }
        let superseded = (distribution.revisions..<existingCount).map { TicketTaskID(rawValue: "existing-\($0)") }
        let before = try await snapshot(fixture.store)
        let error = await capturedError {
            _ = try await self.revise(fixture.store, ticket: "TASK-LIMIT", expected: 1, additions: additions, revisions: revisions, superseded: superseded)
        }
        if succeeds {
            XCTAssertNil(error)
            let activeCount = try await taskRows(fixture.store, ticket: "TASK-LIMIT", activeOnly: true).count
            XCTAssertEqual(activeCount, distribution.revisions + distribution.additions)
        } else {
            XCTAssertEqual(error as? TicketTaskPlanningPolicyError, .invalidTicketTaskMutation(.operationLimitExceeded(actual: count, maximum: 64)))
            try await assertSnapshot(fixture.store, equals: before)
        }
    }

    private static func text(_ value: SQLiteValue?) -> String? {
        guard case let .text(text)? = value else { return nil }
        return text
    }
}

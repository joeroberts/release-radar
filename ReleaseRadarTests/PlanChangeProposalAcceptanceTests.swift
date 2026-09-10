import Foundation
import XCTest
@testable import ReleaseRadarCore

final class PlanChangeProposalAcceptanceTests: XCTestCase {
    func testSavingFirstVersionPersistsBaselineDiffAndRationaleWithoutChangingPlanningGraph() async throws {
        let fixture = try await makeFixture()
        let before = try await planningGraph(fixture.store)
        let result = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-1",
                    expectedPreviousVersion: nil,
                    rationale: "Add the next delivery slice without starting work.",
                    operations: [
                        .addPhase(id: .init(rawValue: "phase-next"), name: "Next"),
                        .addUnassignedTicket(
                            id: .init(rawValue: "ticket-next"),
                            outcome: "Deliver the next slice"
                        ),
                    ]
                )
            )
        )

        XCTAssertNil(result.error)
        XCTAssertEqual(result.planChangeProposalVersion, 1)
        let after = try await planningGraph(fixture.store)
        XCTAssertEqual(after, before)

        let proposals = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let version = try XCTUnwrap(proposals.first?.versions.first)
        XCTAssertEqual(proposals.first?.id.rawValue, "proposal-1")
        XCTAssertEqual(version.version, 1)
        XCTAssertEqual(version.registration, fixture.registration)
        XCTAssertEqual(version.rationale, "Add the next delivery slice without starting work.")
        XCTAssertEqual(version.operations.count, 2)
        XCTAssertEqual(version.diff.groups.map(\.kind), [.phases, .tickets])
        XCTAssertEqual(version.diff.groups.flatMap(\.items).map(\.summary), [
            "Add phase phase-next\nBefore: absent\nAfter:\nName: Next",
            "Add ticket ticket-next\nBefore: absent\nAfter:\nOutcome: Deliver the next slice\nPlacement: unassigned",
        ])
        XCTAssertEqual(version.baselineDigest.count, 64)
        XCTAssertFalse(version.baseline.isEmpty)
        XCTAssertNil(version.decision)
        XCTAssertNil(version.application)

        let queryResult = await AgentQueryDispatcher(store: fixture.store).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .planChangeProposals(projectID: fixture.registration.projectID.rawValue)
        ))
        XCTAssertNil(queryResult.error)
        XCTAssertEqual(queryResult.planChangeProposals, proposals)
        let unauthorizedQuery = await AgentQueryDispatcher(store: fixture.store).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.appendingPathComponent("other").path,
            query: .planChangeProposals(projectID: fixture.registration.projectID.rawValue)
        ))
        XCTAssertEqual(unauthorizedQuery.error, .unauthorizedProjectRoot)
        XCTAssertNil(unauthorizedQuery.planChangeProposals)
    }

    func testReadOnlyProposalQueryWithdrawsResultAfterProjectIsArchived() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            command: .savePlanChangeProposal(
                proposalID: "proposal-query-race",
                expectedPreviousVersion: nil,
                rationale: "Exercise authorization withdrawal.",
                operations: [.addPhase(id: .init(rawValue: "phase-query-race"), name: "Query race")]
            )
        ))
        let gate = PlanChangeProposalQueryGate()
        let dispatcher = AgentQueryDispatcher(
            store: fixture.store,
            afterPlanChangeAuthorization: { await gate.pause() }
        )
        let query = Task {
            await dispatcher.dispatch(.init(
                version: 1,
                projectRoot: fixture.root.path,
                query: .planChangeProposals(projectID: fixture.registration.projectID.rawValue)
            ))
        }
        await gate.waitUntilEntered()
        _ = try await ProjectLifecycleManager(store: fixture.store).apply(
            try await ProjectLifecycleManager(store: fixture.store).preview(
                projectID: fixture.registration.projectID,
                transition: .archive
            )
        )
        await gate.release()

        let result = await query.value
        XCTAssertEqual(result.error, .unauthorizedProjectRoot)
        XCTAssertNil(result.planChangeProposals)
    }

    func testOwnerApprovalBindsExactVersionAndApplyCommitsCompleteAdditiveWorkPackage() async throws {
        let fixture = try await makeFixture()
        let operations = completeWorkPackage()
        let save = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000010")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-package",
                    expectedPreviousVersion: nil,
                    rationale: "Create a bounded next-phase work package.",
                    operations: operations
                )
            )
        )
        XCTAssertNil(save.error)
        let savedProposals = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let saved = try XCTUnwrap(savedProposals.first?.versions.first)
        let graphBeforeApproval = try await planningGraph(fixture.store)

        let externalDecision = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000011")!,
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-package",
                    version: 1,
                    baselineDigest: saved.baselineDigest,
                    decisionID: "decision-package",
                    disposition: .approved
                )
            )
        )
        XCTAssertEqual(externalDecision.error, .planChangeProposalOwnerAuthorityRequired)

        let approvalEnvelope = envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000012")!,
            command: .decidePlanChangeProposal(
                proposalID: "proposal-package",
                version: 1,
                baselineDigest: saved.baselineDigest,
                decisionID: "decision-package",
                disposition: .approved
            )
        )
        let approval = await fixture.dispatcher.dispatch(approvalEnvelope, origin: .ownerApp)
        XCTAssertNil(approval.error)
        let graphAfterApproval = try await planningGraph(fixture.store)
        XCTAssertEqual(graphAfterApproval, graphBeforeApproval)

        let applyEnvelope = envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000013")!,
            command: .applyPlanChangeProposal(
                proposalID: "proposal-package",
                version: 1,
                baselineDigest: saved.baselineDigest,
                decisionID: "decision-package",
                applicationID: "application-package"
            )
        )
        let applied = await fixture.dispatcher.dispatch(applyEnvelope, origin: .ownerApp)
        XCTAssertNil(applied.error)
        XCTAssertEqual(applied.planChangeProposalApplicationID, "application-package")

        let replay = await fixture.dispatcher.dispatch(applyEnvelope, origin: .ownerApp)
        XCTAssertEqual(replay, applied)
        let facts = try await appliedWorkPackageFacts(fixture.store)
        XCTAssertEqual(facts, [
            "application|application-package",
            "assignment|goal-next|ticket-next",
            "goal|goal-next|draft",
            "phase|phase-next|Next",
            "phase-dependency|phase-next|phase-current",
            "task|task-next|pending",
            "ticket|ticket-next|phase-next|backlog",
            "ticket-dependency|ticket-next|ticket-existing",
        ])
        let applicationCount = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_applications")
        }
        XCTAssertEqual(applicationCount, 1)
    }

    func testStaleApprovedProposalChangesNothingAndRequiresRefreshAndReapproval() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000020")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-stale",
                    expectedPreviousVersion: nil,
                    rationale: "Add a future phase.",
                    operations: [.addPhase(id: .init(rawValue: "phase-future"), name: "Future")]
                )
            )
        )
        let firstLoad = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let first = try XCTUnwrap(firstLoad.first?.versions.first)
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000021")!,
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-stale", version: 1,
                    baselineDigest: first.baselineDigest,
                    decisionID: "decision-stale-1", disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Change baseline") {
            try $0.execute("UPDATE phases SET name = 'Current renamed' WHERE project_id = 'proposal-project' AND id = 'phase-current'")
        }
        let beforeApply = try await planningGraph(fixture.store)
        let stale = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000022")!,
                command: .applyPlanChangeProposal(
                    proposalID: "proposal-stale", version: 1,
                    baselineDigest: first.baselineDigest,
                    decisionID: "decision-stale-1", applicationID: "application-stale-1"
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(stale.error, .planChangeProposalStale([.phases]))
        let afterStaleApply = try await planningGraph(fixture.store)
        XCTAssertEqual(afterStaleApply, beforeApply)
        let staleApplicationCount = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_applications")
        }
        XCTAssertEqual(staleApplicationCount, 0)

        let refresh = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000023")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-stale",
                    expectedPreviousVersion: 1,
                    rationale: "Refresh after the phase name changed.",
                    operations: [.addPhase(id: .init(rawValue: "phase-future"), name: "Future")]
                )
            )
        )
        XCTAssertNil(refresh.error)
        XCTAssertEqual(refresh.planChangeProposalVersion, 2)
        let refreshedProposals = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let proposal = try XCTUnwrap(refreshedProposals.first)
        XCTAssertEqual(proposal.versions.map(\.version), [2, 1])
        XCTAssertNil(proposal.versions[0].decision)
        XCTAssertEqual(proposal.versions[1].decision?.id, "decision-stale-1")
    }

    func testDecisionRejectsActualInterveningPlanningChangesWithoutDecisionAuditOrReceipt() async throws {
        let cases: [(name: String, expected: [PlanChangeBaselineCategory])] = [
            ("phase", [.phases]),
            ("ticket", [.tickets]),
            ("task", [.taskPlans, .tasks]),
            ("dependency", [.phaseDependencies]),
            ("reference", [.referenceSets, .referenceLinks, .referenceVersions]),
        ]
        for testCase in cases {
            let fixture = try await makeFixture()
            if testCase.name == "dependency" {
                try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed dependency target") {
                    try DeliveryPlanningPolicy.upsertPhase(
                        projectID: fixture.registration.projectID,
                        phaseID: .init(rawValue: "phase-prerequisite"),
                        name: "Prerequisite",
                        mode: .governed,
                        connection: $0
                    )
                }
            }
            _ = await fixture.dispatcher.dispatch(envelope(
                fixture,
                requestID: UUID(),
                command: .savePlanChangeProposal(
                    proposalID: "proposal-stale-\(testCase.name)",
                    expectedPreviousVersion: nil,
                    rationale: "Reject approval after actual \(testCase.name) changes.",
                    operations: [.addPhase(
                        id: .init(rawValue: "phase-stale-\(testCase.name)"),
                        name: "Future"
                    )]
                )
            ))
            let proposals = try await PlanChangeProposalQuery.load(
                from: fixture.store,
                projectID: fixture.registration.projectID
            )
            let proposal = try XCTUnwrap(proposals.first?.versions.first)
            try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Change actual \(testCase.name)") { connection in
                switch testCase.name {
                case "phase":
                    try DeliveryPlanningPolicy.upsertPhase(
                        projectID: fixture.registration.projectID,
                        phaseID: .init(rawValue: "phase-current"),
                        name: "Current renamed before approval",
                        mode: .governed,
                        connection: connection
                    )
                case "ticket":
                    try DeliveryPlanningPolicy.upsertUnassignedTicket(
                        projectID: fixture.registration.projectID,
                        ticketID: .init(rawValue: "ticket-existing"),
                        outcome: "Changed ticket outcome before approval",
                        connection: connection
                    )
                case "task":
                    _ = try TicketTaskPlanningPolicy.revisePlan(
                        projectID: fixture.registration.projectID,
                        ticketID: .init(rawValue: "ticket-existing"),
                        expectedRevision: nil,
                        additions: [.init(
                            id: .init(rawValue: "task-intervening"),
                            label: "T1",
                            title: "Intervening task",
                            sortOrder: 0
                        )],
                        definitionRevisions: [],
                        supersededTaskIDs: [],
                        connection: connection
                    )
                case "dependency":
                    try connection.execute(
                        "INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('dependency-intervening', 'proposal-project', 'phase-current', 'phase-prerequisite')"
                    )
                default:
                    try connection.execute(
                        "INSERT INTO ticket_reference_link_sets (project_id,ticket_id,revision,created_at,updated_at) VALUES ('proposal-project','ticket-existing',1,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')"
                    )
                    try connection.execute(
                        "INSERT INTO ticket_reference_links (project_id,ticket_id,id,kind,repository_id,artifact_id,current_version,relationship,created_at,updated_at) VALUES ('proposal-project','ticket-existing','reference-intervening','requirement','9141d1ea-3342-4462-9e06-6934d816c03f','current',1,'current','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')"
                    )
                    try connection.execute(
                        "INSERT INTO ticket_reference_versions (project_id,ticket_id,link_id,version,content_digest,source_local_id,locator,catalog_version,catalog_digest,observed_path,observed_lifecycle,observed_authority,created_at) VALUES ('proposal-project','ticket-existing','reference-intervening',1,?,NULL,NULL,1,?,'docs/plans/current.md','active','controlling','2026-09-10T00:00:00Z')",
                        bindings: [.text(String(repeating: "a", count: 64)), .text(String(repeating: "b", count: 64))]
                    )
                }
            }
            let countsBefore = try await proposalRecordCounts(fixture.store)

            let decision = await fixture.dispatcher.dispatch(envelope(
                fixture,
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-stale-\(testCase.name)",
                    version: 1,
                    baselineDigest: proposal.baselineDigest,
                    decisionID: "decision-stale-\(testCase.name)",
                    disposition: .approved
                )
            ), origin: .ownerApp)

            XCTAssertEqual(decision.error, .planChangeProposalStale(testCase.expected), testCase.name)
            let countsAfter = try await proposalRecordCounts(fixture.store)
            XCTAssertEqual(countsAfter, countsBefore, testCase.name)
            let refresh = await fixture.dispatcher.dispatch(envelope(
                fixture,
                requestID: UUID(),
                command: .savePlanChangeProposal(
                    proposalID: "proposal-stale-\(testCase.name)",
                    expectedPreviousVersion: 1,
                    rationale: "Refresh after actual \(testCase.name) change.",
                    operations: [.addPhase(
                        id: .init(rawValue: "phase-stale-\(testCase.name)"),
                        name: "Future"
                    )]
                )
            ))
            XCTAssertEqual(refresh.planChangeProposalVersion, 2, testCase.name)
        }
    }

    func testSavedDiffShowsCompleteGoalAndTaskDefinitionsBeforeOwnerApproval() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000028")!,
            command: .savePlanChangeProposal(
                proposalID: "proposal-complete-diff",
                expectedPreviousVersion: nil,
                rationale: "Expose exact definitions for approval.",
                operations: completeWorkPackage()
            )
        ))
        let proposals = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let version = try XCTUnwrap(proposals.first?.versions.first)
        let phaseText = try XCTUnwrap(version.diff.groups.first { $0.kind == .phases }?.items.first?.summary)
        XCTAssertTrue(phaseText.contains("Before: absent"))
        XCTAssertTrue(phaseText.contains("Name: Next"))
        let goalText = try XCTUnwrap(version.diff.groups.first { $0.kind == .goals }?.items.first?.summary)
        XCTAssertTrue(goalText.contains("Before: absent"))
        XCTAssertTrue(goalText.contains("Outcome: The next slice is usable"))
        XCTAssertTrue(goalText.contains("Done criteria: The focused acceptance path passes"))
        XCTAssertTrue(goalText.contains("Sort order: 0"))
        let ticketText = try XCTUnwrap(version.diff.groups.first { $0.kind == .tickets }?.items.first?.summary)
        XCTAssertTrue(ticketText.contains("Before: absent"))
        XCTAssertTrue(ticketText.contains("Outcome: Deliver the next slice"))
        let taskText = try XCTUnwrap(version.diff.groups.first { $0.kind == .tasks }?.items.first?.summary)
        XCTAssertTrue(taskText.contains("task-next"))
        XCTAssertTrue(taskText.contains("Before: absent"))
        XCTAssertTrue(taskText.contains("Label: T1"))
        XCTAssertTrue(taskText.contains("Title: Implement the slice"))
        XCTAssertTrue(taskText.contains("Sort order: 0"))
        let assignmentText = try XCTUnwrap(version.diff.groups.first { $0.kind == .assignments }?.items.first?.summary)
        XCTAssertTrue(assignmentText.contains("Before: unassigned"))
        XCTAssertTrue(assignmentText.contains("After: goal-next in phase-next"))
        let dependencyText = version.diff.groups
            .first { $0.kind == .dependencies }?.items.map(\.summary).joined(separator: "\n") ?? ""
        XCTAssertTrue(dependencyText.contains("phase-dependency-next"))
        XCTAssertTrue(dependencyText.contains("ticket-dependency-next"))
        XCTAssertTrue(dependencyText.contains("Before: absent"))
    }

    func testDecisionApplyAuthorityReplayAndCompetingRequestsAreExactAndSingleUse() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000070")!,
            command: .savePlanChangeProposal(
                proposalID: "proposal-exact",
                expectedPreviousVersion: nil,
                rationale: "Exercise exact decision and application identity.",
                operations: [.addPhase(id: .init(rawValue: "phase-exact"), name: "Exact")]
            )
        ))
        let loaded = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let version = try XCTUnwrap(loaded.first?.versions.first)

        let wrongDigest = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000071")!,
            command: .decidePlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: String(repeating: "0", count: 64),
                decisionID: "decision-wrong-digest", disposition: .approved
            )
        ), origin: .ownerApp)
        XCTAssertEqual(wrongDigest.error, .planChangeProposalDecisionMismatch)

        let wrongRegistration = AgentCommandEnvelope(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000072")!,
            projectRoot: fixture.root.path,
            expectedRegistration: .init(
                projectID: fixture.registration.projectID,
                registrationID: "registration-wrong",
                requestGeneration: fixture.registration.requestGeneration
            ),
            reason: "Reject wrong registration",
            command: .decidePlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-wrong-registration", disposition: .approved
            )
        )
        let wrongRegistrationResult = await fixture.dispatcher.dispatch(wrongRegistration, origin: .ownerApp)
        XCTAssertEqual(wrongRegistrationResult.error, .staleProjectRegistration)

        let decisionEnvelope = envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000073")!,
            command: .decidePlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-exact", disposition: .approved
            )
        )
        let decision = await fixture.dispatcher.dispatch(decisionEnvelope, origin: .ownerApp)
        XCTAssertNil(decision.error)
        let decisionReplay = await fixture.dispatcher.dispatch(decisionEnvelope, origin: .ownerApp)
        XCTAssertEqual(decisionReplay, decision)
        let externalDecisionReplay = await fixture.dispatcher.dispatch(decisionEnvelope)
        XCTAssertEqual(externalDecisionReplay.error, .planChangeProposalOwnerAuthorityRequired)
        let conflictingReplay = envelope(
            fixture,
            requestID: decisionEnvelope.requestID,
            command: .decidePlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-conflicting-replay", disposition: .approved
            )
        )
        let conflictingReplayResult = await fixture.dispatcher.dispatch(conflictingReplay, origin: .ownerApp)
        XCTAssertEqual(conflictingReplayResult.error, .requestIDReused)
        let competingDecision = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000074")!,
            command: .decidePlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-competing", disposition: .rejected
            )
        ), origin: .ownerApp)
        XCTAssertEqual(competingDecision.error, .planChangeProposalDecisionConflict)

        let wrongDecision = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000075")!,
            command: .applyPlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-wrong", applicationID: "application-wrong"
            )
        ), origin: .ownerApp)
        XCTAssertEqual(wrongDecision.error, .planChangeProposalDecisionMismatch)

        let applyEnvelope = envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000076")!,
            command: .applyPlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-exact", applicationID: "application-exact"
            )
        )
        let application = await fixture.dispatcher.dispatch(applyEnvelope, origin: .ownerApp)
        XCTAssertNil(application.error)
        let applicationReplay = await fixture.dispatcher.dispatch(applyEnvelope, origin: .ownerApp)
        XCTAssertEqual(applicationReplay, application)
        let externalApplicationReplay = await fixture.dispatcher.dispatch(applyEnvelope)
        XCTAssertEqual(externalApplicationReplay.error, .planChangeProposalOwnerAuthorityRequired)
        let conflictingApplyReplay = envelope(
            fixture,
            requestID: applyEnvelope.requestID,
            command: .applyPlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-exact", applicationID: "application-conflicting-replay"
            )
        )
        let conflictingApplyReplayResult = await fixture.dispatcher.dispatch(conflictingApplyReplay, origin: .ownerApp)
        XCTAssertEqual(conflictingApplyReplayResult.error, .requestIDReused)
        let competingApply = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000077")!,
            command: .applyPlanChangeProposal(
                proposalID: "proposal-exact", version: 1,
                baselineDigest: version.baselineDigest,
                decisionID: "decision-exact", applicationID: "application-competing"
            )
        ), origin: .ownerApp)
        XCTAssertEqual(competingApply.error, .planChangeProposalAlreadyApplied)
        let counts = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_decisions"),
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_applications")
            )
        }
        XCTAssertEqual(counts.0, 1)
        XCTAssertEqual(counts.1, 1)
    }

    func testAdmissionRejectsStartedAcceptedAndExistingAssignmentTransfer() async throws {
        for lane in [TicketLane.inProgress, .accepted] {
            let fixture = try await makeFixture()
            try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed ineligible ticket") {
                try $0.execute(
                    "UPDATE tickets SET phase_id = 'phase-current', lane = ? WHERE project_id = 'proposal-project' AND id = 'ticket-existing'",
                    bindings: [.text(lane.rawValue)]
                )
            }
            let before = try await planningGraph(fixture.store)
            let result = await fixture.dispatcher.dispatch(envelope(
                fixture,
                requestID: UUID(),
                command: .savePlanChangeProposal(
                    proposalID: "proposal-ineligible-\(lane.rawValue)",
                    expectedPreviousVersion: nil,
                    rationale: "Must reject started or accepted work.",
                    operations: [.addPendingTicketTasks(
                        ticketID: .init(rawValue: "ticket-existing"),
                        tasks: [.init(id: .init(rawValue: "task-new"), label: "T1", title: "New task", sortOrder: 0)]
                    )]
                )
            ))
            guard case .invalidPlanChangeOperation = result.error else {
                return XCTFail("Expected invalid operation for \(lane.rawValue), got \(String(describing: result.error))")
            }
            let after = try await planningGraph(fixture.store)
            XCTAssertEqual(after, before)
        }

        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed existing goal assignment") { connection in
            let timestamp = "2026-09-10T00:00:00Z"
            try connection.execute("UPDATE tickets SET phase_id = 'phase-current', lane = 'backlog' WHERE project_id = 'proposal-project' AND id = 'ticket-existing'")
            try connection.execute(
                "INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('proposal-project','phase-current','goal-existing','Existing goal','Existing outcome','draft',0,?,?)",
                bindings: [.text(timestamp), .text(timestamp)]
            )
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion) VALUES ('proposal-project','phase-current','goal-existing',0,'Existing criterion')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('proposal-project','phase-current','goal-existing','ticket-existing')")
            try connection.execute(
                "INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('proposal-project','phase-current','goal-other','Other goal','Other outcome','draft',1,?,?)",
                bindings: [.text(timestamp), .text(timestamp)]
            )
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion) VALUES ('proposal-project','phase-current','goal-other',0,'Other criterion')")
        }
        let transfer = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(),
            command: .savePlanChangeProposal(
                proposalID: "proposal-transfer",
                expectedPreviousVersion: nil,
                rationale: "Must not transfer an existing assignment.",
                operations: [.assignTicketToGoal(
                    ticketID: .init(rawValue: "ticket-existing"),
                    phaseID: .init(rawValue: "phase-current"),
                    goalID: .init(rawValue: "goal-other")
                )]
            )
        ))
        guard case .invalidPlanChangeOperation = transfer.error else {
            return XCTFail("Expected existing assignment transfer rejection, got \(String(describing: transfer.error))")
        }
        let retainedGoal = try await fixture.store.read {
            try $0.scalarText("SELECT goal_id FROM delivery_goal_ticket_assignments WHERE ticket_id = 'ticket-existing'")
        }
        XCTAssertEqual(retainedGoal, "goal-existing")
    }

    func testBaselineRecordsAndComparesEveryDeclaredCategory() async throws {
        struct Section: Codable {
            let name: String
            var rows: [[String]]
        }
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(),
            command: .savePlanChangeProposal(
                proposalID: "proposal-baseline-categories", expectedPreviousVersion: nil,
                rationale: "Capture every planning baseline section.",
                operations: [.addPhase(id: .init(rawValue: "phase-baseline"), name: "Baseline")]
            )
        ))
        let loaded = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let baseline = try XCTUnwrap(loaded.first?.versions.first?.baseline)
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let sections = try decoder.decode([Section].self, from: baseline)
        XCTAssertEqual(Set(sections.map(\.name)), Set(PlanChangeBaselineCategory.allCases.map(\.rawValue)))
        for category in PlanChangeBaselineCategory.allCases {
            var changed = sections
            let index = try XCTUnwrap(changed.firstIndex(where: { $0.name == category.rawValue }))
            changed[index].rows.append(["synthetic=changed"])
            XCTAssertEqual(
                try PlanningBaseline.changedCategories(from: baseline, to: encoder.encode(changed)),
                [category],
                "Expected an isolated stale classification for \(category.rawValue)"
            )
        }
    }

    func testSourceImpactsPreserveExactRecordedVersionsForBothDependencyEnds() async throws {
        let fixture = try await makeFixture(withDocumentation: true)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed recorded reference impacts") { connection in
            try DeliveryPlanningPolicy.upsertUnassignedTicket(
                projectID: fixture.registration.projectID,
                ticketID: .init(rawValue: "ticket-dependent"),
                outcome: "Dependent recorded work",
                connection: connection
            )
        }
        _ = try await bindCurrentSource(to: "ticket-existing", fixture: fixture)
        _ = try await bindCurrentSource(
            to: "ticket-dependent",
            linkID: "decision-link",
            kind: .decision,
            fixture: fixture
        )
        _ = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(),
            command: .savePlanChangeProposal(
                proposalID: "proposal-source-impacts", expectedPreviousVersion: nil,
                rationale: "Record exact source versions for both dependency ends.",
                operations: [.addTicketDependency(
                    id: .init(rawValue: "dependency-source-impact"),
                    ticketID: .init(rawValue: "ticket-existing"),
                    dependsOnTicketID: .init(rawValue: "ticket-dependent")
                )]
            )
        ))
        let firstLoad = try await PlanChangeProposalQuery.load(from: fixture.store, projectID: fixture.registration.projectID)
        let impacts = try XCTUnwrap(firstLoad.first?.versions.first?.sourceImpacts)
        XCTAssertEqual(impacts.map(\.ticketID.rawValue), ["ticket-dependent", "ticket-existing"])
        XCTAssertEqual(impacts.map(\.version), [1, 1])
        XCTAssertEqual(Set(impacts.map(\.observedPath)), ["docs/plans/current.md"])

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Advance current source metadata") { connection in
            try connection.execute(
                "INSERT INTO ticket_reference_versions (project_id,ticket_id,link_id,version,content_digest,source_local_id,locator,catalog_version,catalog_digest,observed_path,observed_lifecycle,observed_authority,created_at) SELECT project_id,ticket_id,link_id,2,?,source_local_id,locator,catalog_version,catalog_digest,'docs/new-current.md',observed_lifecycle,observed_authority,'2026-09-10T00:01:00Z' FROM ticket_reference_versions WHERE ticket_id='ticket-existing' AND link_id='requirement-link' AND version=1",
                bindings: [.text(String(repeating: "d", count: 64))]
            )
            try connection.execute("UPDATE ticket_reference_links SET current_version=2,updated_at='2026-09-10T00:01:00Z' WHERE ticket_id='ticket-existing' AND id='requirement-link'")
        }
        let afterCurrentAdvance = try await PlanChangeProposalQuery.load(from: fixture.store, projectID: fixture.registration.projectID)
        XCTAssertEqual(afterCurrentAdvance.first?.versions.first?.sourceImpacts, impacts)
    }

    func testChangedReferencedSourceAfterApprovalRejectsApplyWithoutGraphApplicationAuditOrReceipt() async throws {
        let fixture = try await makeFixture(withDocumentation: true)
        let source = try await bindCurrentSource(to: "ticket-existing", fixture: fixture)
        _ = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000029")!,
            command: .savePlanChangeProposal(
                proposalID: "proposal-source-change",
                expectedPreviousVersion: nil,
                rationale: "Use the exact current requirement source.",
                operations: [.addPendingTicketTasks(
                    ticketID: .init(rawValue: "ticket-existing"),
                    tasks: [.init(
                        id: .init(rawValue: "task-source-change"),
                        label: "T1",
                        title: "Implement from current source",
                        sortOrder: 0
                    )]
                )]
            )
        ))
        let proposals = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let proposal = try XCTUnwrap(proposals.first?.versions.first)
        let approved = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-00000000002a")!,
            command: .decidePlanChangeProposal(
                proposalID: "proposal-source-change",
                version: 1,
                baselineDigest: proposal.baselineDigest,
                decisionID: "decision-source-change",
                disposition: .approved
            )
        ), origin: .ownerApp)
        XCTAssertNil(approved.error)
        let graphBefore = try await planningGraph(fixture.store)
        let recordsBefore = try await proposalRecordCounts(fixture.store)
        try Data("Changed requirement bytes\n".utf8).write(to: source)

        let applied = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-00000000002b")!,
            command: .applyPlanChangeProposal(
                proposalID: "proposal-source-change",
                version: 1,
                baselineDigest: proposal.baselineDigest,
                decisionID: "decision-source-change",
                applicationID: "application-source-change"
            )
        ), origin: .ownerApp)

        XCTAssertEqual(applied.error, .planChangeProposalStale([.referenceVersions]))
        let graphAfter = try await planningGraph(fixture.store)
        let recordsAfter = try await proposalRecordCounts(fixture.store)
        XCTAssertEqual(graphAfter, graphBefore)
        XCTAssertEqual(recordsAfter, recordsBefore)
    }

    func testUnavailableReferencedSourceOrAccessRejectsDecisionWithoutDecisionAuditOrReceipt() async throws {
        for invalidation in ["file", "access"] {
            let fixture = try await makeFixture(withDocumentation: true)
            let source = try await bindCurrentSource(to: "ticket-existing", fixture: fixture)
            _ = await fixture.dispatcher.dispatch(envelope(
                fixture,
                requestID: UUID(),
                command: .savePlanChangeProposal(
                    proposalID: "proposal-source-\(invalidation)",
                    expectedPreviousVersion: nil,
                    rationale: "Reject unavailable source before owner approval.",
                    operations: [.addPendingTicketTasks(
                        ticketID: .init(rawValue: "ticket-existing"),
                        tasks: [.init(
                            id: .init(rawValue: "task-source-\(invalidation)"),
                            label: "T1",
                            title: "Implement from available source",
                            sortOrder: 0
                        )]
                    )]
                )
            ))
            let proposals = try await PlanChangeProposalQuery.load(
                from: fixture.store,
                projectID: fixture.registration.projectID
            )
            let proposal = try XCTUnwrap(proposals.first?.versions.first)
            if invalidation == "file" {
                try FileManager.default.removeItem(at: source)
            } else {
                try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Withdraw root access") {
                    try $0.execute(
                        "UPDATE project_bookmarks SET is_stale = 1 WHERE project_id = 'proposal-project'"
                    )
                }
            }
            let countsBefore = try await proposalRecordCounts(fixture.store)

            let decision = await fixture.dispatcher.dispatch(envelope(
                fixture,
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-source-\(invalidation)",
                    version: 1,
                    baselineDigest: proposal.baselineDigest,
                    decisionID: "decision-source-\(invalidation)",
                    disposition: .approved
                )
            ), origin: .ownerApp)

            XCTAssertEqual(decision.error, .planChangeProposalStale([.referenceVersions]))
            let countsAfter = try await proposalRecordCounts(fixture.store)
            XCTAssertEqual(countsAfter, countsBefore)
        }
    }

    func testLateApplyFailureRollsBackEveryGraphChangeApplicationAndAudit() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000030")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-rollback",
                    expectedPreviousVersion: nil,
                    rationale: "Exercise atomic rollback.",
                    operations: completeWorkPackage()
                )
            )
        )
        let savedProposals = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let version = try XCTUnwrap(savedProposals.first?.versions.first)
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000031")!,
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-rollback", version: 1,
                    baselineDigest: version.baselineDigest,
                    decisionID: "decision-rollback", disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Inject late failure") {
            try $0.execute(
                "CREATE TRIGGER proposal_apply_late_failure BEFORE INSERT ON ticket_dependencies BEGIN SELECT RAISE(ABORT, 'injected late failure'); END;"
            )
        }
        let graphBeforeApply = try await planningGraph(fixture.store)
        let auditCountBefore = try await fixture.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let result = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000032")!,
                command: .applyPlanChangeProposal(
                    proposalID: "proposal-rollback", version: 1,
                    baselineDigest: version.baselineDigest,
                    decisionID: "decision-rollback", applicationID: "application-rollback"
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNotNil(result.error)
        let graphAfterFailure = try await planningGraph(fixture.store)
        XCTAssertEqual(graphAfterFailure, graphBeforeApply)
        let applicationCount = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_applications")
        }
        XCTAssertEqual(applicationCount, 0)
        let auditCountAfter = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events")
        }
        XCTAssertEqual(auditCountAfter, auditCountBefore)
    }

    func testSchemaTwentyMigrationCreatesEmptyProposalState() async throws {
        let cacheRoot = try XCTUnwrap(
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ).appendingPathComponent("ReleaseRadarPhase5CProposalTests", isDirectory: true)
        let root = cacheRoot
            .appendingPathComponent("migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let databaseURL = root.appendingPathComponent("store.sqlite")
        let current = DeliveryStore(databaseURL: databaseURL)
        let currentAvailability = await current.availability
        XCTAssertEqual(currentAvailability, .available)
        await current.close()
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        let legacy = try SQLiteConnection(url: databaseURL)
        try legacy.executeScript(
            """
            DROP TRIGGER phase_lifecycles_after_phase_insert;
            DROP TABLE retained_phase_lifecycle_events;
            DROP TABLE retained_phase_lifecycles;
            DROP TABLE phase_lifecycle_events;
            DROP TABLE phase_lifecycles;
            DROP TABLE retained_plan_change_proposal_applications;
            DROP TABLE retained_plan_change_proposal_decisions;
            DROP TABLE retained_plan_change_proposal_versions;
            DROP TABLE retained_plan_change_proposals;
            DROP TABLE plan_change_proposal_applications;
            DROP TABLE plan_change_proposal_decisions;
            DROP TABLE plan_change_proposal_versions;
            DROP TABLE plan_change_proposals;
            DROP TABLE retained_delivery_goal_obligation_lineage;
            DROP TABLE retained_delivery_goal_obligation_drops;
            DROP TABLE retained_ticket_successor_links;
            DROP TABLE retained_ticket_retirements;
            DROP TABLE retained_delivery_goal_obligations;
            DROP TABLE delivery_goal_obligation_drops;
            DROP TABLE delivery_goal_obligation_lineage;
            DROP TABLE ticket_successor_links;
            DROP TABLE ticket_retirements;
            DROP TABLE delivery_goal_obligations;
            PRAGMA user_version = 20;
            """
        )
        legacy.close()

        let migrated = DeliveryStore(databaseURL: databaseURL)
        let availability = await migrated.availability
        XCTAssertEqual(availability, .available)
        let migrationFacts = try await migrated.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposals")
            )
        }
        let verifier = try SQLiteConnection(url: databaseURL)
        XCTAssertEqual(try verifier.scalarInt("PRAGMA user_version"), 23)
        XCTAssertEqual(migrationFacts.0, 0)
        XCTAssertEqual(migrationFacts.1, 0)
    }

    func testProposalVersionAndDecisionSurviveRelaunchAndRejectMutation() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000040")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-relaunch", expectedPreviousVersion: nil,
                    rationale: "Persist across relaunch.",
                    operations: [.addPhase(id: .init(rawValue: "phase-relaunch"), name: "Relaunch")]
                )
            )
        )
        let loaded = try await PlanChangeProposalQuery.load(from: fixture.store, projectID: fixture.registration.projectID)
        let version = try XCTUnwrap(loaded.first?.versions.first)
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000041")!,
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-relaunch", version: 1,
                    baselineDigest: version.baselineDigest,
                    decisionID: "decision-relaunch", disposition: .rejected
                )
            ),
            origin: .ownerApp
        )
        let databaseURL = fixture.store.databaseURL
        await fixture.store.close()
        let reopened = DeliveryStore(databaseURL: databaseURL)
        let afterRelaunch = try await PlanChangeProposalQuery.load(from: reopened, projectID: fixture.registration.projectID)
        XCTAssertEqual(afterRelaunch.first?.versions.first?.decision?.id, "decision-relaunch")
        do {
            try await reopened.transact(actor: .init(id: "fixture"), reason: "Attempt history mutation") {
                try $0.execute("UPDATE plan_change_proposal_versions SET rationale = 'changed'")
            }
            XCTFail("Expected immutable proposal version")
        } catch {}
        do {
            try await reopened.transact(actor: .init(id: "fixture"), reason: "Attempt decision deletion") {
                try $0.execute("DELETE FROM plan_change_proposal_decisions")
            }
            XCTFail("Expected immutable proposal decision")
        } catch {}
        let afterRejectedMutations = try await PlanChangeProposalQuery.load(from: reopened, projectID: fixture.registration.projectID)
        XCTAssertEqual(afterRejectedMutations, afterRelaunch)
    }

    func testProjectRemovalRetainsProposalVersionAndDecisionHistory() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000050")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-remove", expectedPreviousVersion: nil,
                    rationale: "Retain after removal.",
                    operations: [.addPhase(id: .init(rawValue: "phase-remove"), name: "Remove")]
                )
            )
        )
        let loaded = try await PlanChangeProposalQuery.load(from: fixture.store, projectID: fixture.registration.projectID)
        let version = try XCTUnwrap(loaded.first?.versions.first)
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000051")!,
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-remove", version: 1,
                    baselineDigest: version.baselineDigest,
                    decisionID: "decision-remove", disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        let removal = ProjectRemovalManager(store: fixture.store)
        let removed = try await removal.apply(try await removal.preview(projectID: fixture.registration.projectID))
        let facts = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposals WHERE removal_id = ?", bindings: [.text(removed.id.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposal_versions WHERE removal_id = ?", bindings: [.text(removed.id.rawValue)]),
                try connection.scalarText("SELECT id FROM retained_plan_change_proposal_decisions WHERE removal_id = ?", bindings: [.text(removed.id.rawValue)])
            )
        }
        XCTAssertEqual(facts.0, 0)
        XCTAssertEqual(facts.1, 1)
        XCTAssertEqual(facts.2, 1)
        XCTAssertEqual(facts.3, "decision-remove")
    }

    func testRestoreMovesBackedUpApprovalToHistoryAndRotatesLiveAuthority() async throws {
        let fixture = try await makeFixture()
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000060")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-restore", expectedPreviousVersion: nil,
                    rationale: "Retain through recovery.",
                    operations: [.addPhase(id: .init(rawValue: "phase-restore"), name: "Restore")]
                )
            )
        )
        let loaded = try await PlanChangeProposalQuery.load(from: fixture.store, projectID: fixture.registration.projectID)
        let version = try XCTUnwrap(loaded.first?.versions.first)
        _ = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000061")!,
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-restore", version: 1,
                    baselineDigest: version.baselineDigest,
                    decisionID: "decision-restore", disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        let backupRoot = fixture.root.deletingLastPathComponent()
            .appendingPathComponent("release-radar-plan-change-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let packageURL = backupRoot.appendingPathComponent("proposal.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: fixture.store, databaseURL: fixture.store.databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))

        let refresh = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000062")!,
                command: .savePlanChangeProposal(
                    proposalID: "proposal-restore", expectedPreviousVersion: 1,
                    rationale: "Newer live version after the backup.",
                    operations: [.addPhase(id: .init(rawValue: "phase-restore"), name: "Restore")]
                )
            )
        )
        XCTAssertEqual(refresh.planChangeProposalVersion, 2)
        let refreshedVersions = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let refreshed = try XCTUnwrap(refreshedVersions.first?.versions.first)
        let newerDecision = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000063")!,
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-restore", version: 2,
                    baselineDigest: refreshed.baselineDigest,
                    decisionID: "decision-restore-newer", disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(newerDecision.error)
        let newerApplication = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000064")!,
                command: .applyPlanChangeProposal(
                    proposalID: "proposal-restore", version: 2,
                    baselineDigest: refreshed.baselineDigest,
                    decisionID: "decision-restore-newer",
                    applicationID: "application-restore-newer"
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(newerApplication.error)

        let recovery = ApplicationRecoveryManager(store: fixture.store, databaseURL: fixture.store.databaseURL)
        let restored = try await recovery.restore(try await recovery.previewRestore(packageURL: packageURL))
        let newRegistration = try await ProjectLifecycleManager(store: restored.store)
            .snapshot(projectID: fixture.registration.projectID).registration
        XCTAssertNotEqual(newRegistration, fixture.registration)
        let recoveryFacts = try await restored.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposals WHERE historical_project_id = 'proposal-project'"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposal_decisions WHERE id = 'decision-restore'"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposal_versions WHERE proposal_id = 'proposal-restore' AND version = 2"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposal_decisions WHERE id = 'decision-restore-newer'"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_plan_change_proposal_applications WHERE id = 'application-restore-newer'")
            )
        }
        XCTAssertEqual(recoveryFacts.0, 0)
        XCTAssertGreaterThanOrEqual(recoveryFacts.1 ?? 0, 1)
        XCTAssertGreaterThanOrEqual(recoveryFacts.2 ?? 0, 1)
        XCTAssertGreaterThanOrEqual(recoveryFacts.3 ?? 0, 1)
        XCTAssertGreaterThanOrEqual(recoveryFacts.4 ?? 0, 1)
        XCTAssertGreaterThanOrEqual(recoveryFacts.5 ?? 0, 1)
    }

    func testApprovedSplitRetainsOriginalAndCreatesIncompleteSuccessorsWithExplicitCarry() async throws {
        let fixture = try await makeFixture(withDocumentation: true)
        let seedAudit = AuditEventID(rawValue: "audit-seed-split")
        try await fixture.store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed the original planned ticket",
            auditEventID: seedAudit,
            auditScope: .init(
                projectID: fixture.registration.projectID,
                entityType: .phasePlan,
                entityID: "phase-current"
            )
        ) { connection in
            let placed = try DeliveryPlanningPolicy.placeUnassignedTicket(
                projectID: fixture.registration.projectID,
                ticketID: .init(rawValue: "ticket-existing"),
                phaseID: .init(rawValue: "phase-current"),
                expectedPlanRevision: 0,
                connection: connection
            )
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-current"),
                expectedRevision: placed.revision,
                goalUpserts: [.init(
                    id: .init(rawValue: "goal-current"),
                    title: "Deliver current scope",
                    outcome: "Current work remains covered",
                    doneCriteria: ["Required work is accepted"],
                    sortOrder: 0
                )],
                assignments: [.init(
                    goalID: .init(rawValue: "goal-current"),
                    ticketID: .init(rawValue: "ticket-existing")
                )],
                unassignedTicketIDs: [],
                supersededGoalIDs: [],
                auditEventID: seedAudit,
                connection: connection
            )
        }

        let operations: [PlanChangeOperation] = [
            .addUnassignedTicket(id: .init(rawValue: "ticket-successor-a"), outcome: "Deliver first split outcome"),
            .addUnassignedTicket(id: .init(rawValue: "ticket-successor-b"), outcome: "Deliver second split outcome"),
            .addPendingTicketTasks(
                ticketID: .init(rawValue: "ticket-successor-a"),
                tasks: [.init(id: .init(rawValue: "task-successor-a"), label: "A", title: "Implement first outcome", sortOrder: 0)]
            ),
            .addPendingTicketTasks(
                ticketID: .init(rawValue: "ticket-successor-b"),
                tasks: [.init(id: .init(rawValue: "task-successor-b"), label: "B", title: "Implement second outcome", sortOrder: 0)]
            ),
            .placeTicket(ticketID: .init(rawValue: "ticket-successor-a"), phaseID: .init(rawValue: "phase-current")),
            .placeTicket(ticketID: .init(rawValue: "ticket-successor-b"), phaseID: .init(rawValue: "phase-current")),
            .assignTicketToGoal(ticketID: .init(rawValue: "ticket-successor-a"), phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current")),
            .assignTicketToGoal(ticketID: .init(rawValue: "ticket-successor-b"), phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current")),
            .retireTicket(
                ticketID: .init(rawValue: "ticket-existing"),
                disposition: .split,
                reason: "Separate independently deliverable outcomes",
                successorTicketIDs: [.init(rawValue: "ticket-successor-a"), .init(rawValue: "ticket-successor-b")]
            ),
            .carryGoalObligation(
                source: .init(
                    phaseID: .init(rawValue: "phase-current"),
                    goalID: .init(rawValue: "goal-current"),
                    ticketID: .init(rawValue: "ticket-existing")
                ),
                descendants: [
                    .init(phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"), ticketID: .init(rawValue: "ticket-successor-a")),
                    .init(phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"), ticketID: .init(rawValue: "ticket-successor-b")),
                ],
                reason: "Both split outcomes retain the original goal scope"
            ),
        ]
        let save = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000071")!,
            command: .savePlanChangeProposal(
                proposalID: "proposal-split",
                expectedPreviousVersion: nil,
                rationale: "Split retained work into explicit successors.",
                operations: operations
            )
        ))
        XCTAssertNil(save.error)
        let loaded = try await PlanChangeProposalQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID
        )
        let proposal = try XCTUnwrap(loaded.first?.versions.first)
        XCTAssertTrue(proposal.diff.groups.flatMap(\.items).contains(where: {
            $0.summary == """
            Retire ticket ticket-existing as split
            Before: phase-current Backlog
            After: retained original; successors: ticket-successor-a, ticket-successor-b
            Reason: Separate independently deliverable outcomes
            """
        }))
        XCTAssertTrue(proposal.diff.groups.flatMap(\.items).contains(where: {
            $0.summary == """
            Carry obligation ticket-existing
            Before: goal-current in phase-current
            Original scope: Existing planned work
            After: ticket-successor-a → goal-current in phase-current; ticket-successor-b → goal-current in phase-current
            Reason: Both split outcomes retain the original goal scope
            """
        }))
        let decision = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000072")!,
            command: .decidePlanChangeProposal(
                proposalID: "proposal-split",
                version: 1,
                baselineDigest: proposal.baselineDigest,
                decisionID: "decision-split",
                disposition: .approved
            )
        ), origin: .ownerApp)
        XCTAssertNil(decision.error)
        let applied = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000073")!,
            command: .applyPlanChangeProposal(
                proposalID: "proposal-split",
                version: 1,
                baselineDigest: proposal.baselineDigest,
                decisionID: "decision-split",
                applicationID: "application-split"
            )
        ), origin: .ownerApp)
        XCTAssertNil(applied.error)

        let facts = try await fixture.store.read { connection in
            (
                try connection.rows("SELECT ticket_id,disposition,reason,last_phase_id,last_lane FROM ticket_retirements WHERE project_id='proposal-project'"),
                try connection.rows("SELECT original_ticket_id,successor_ticket_id,relation,sort_order FROM ticket_successor_links WHERE project_id='proposal-project' ORDER BY sort_order"),
                try connection.rows("SELECT id,phase_id,lane FROM tickets WHERE project_id='proposal-project' ORDER BY id"),
                try connection.rows("SELECT ticket_id,id,completion,lifecycle FROM ticket_tasks WHERE project_id='proposal-project' ORDER BY ticket_id,id"),
                try connection.rows("SELECT phase_id,goal_id,ticket_id FROM delivery_goal_obligations WHERE project_id='proposal-project' ORDER BY ticket_id"),
                try connection.rows("SELECT source_ticket_id,descendant_ticket_id,reason FROM delivery_goal_obligation_lineage WHERE project_id='proposal-project' ORDER BY descendant_ticket_id")
            )
        }
        XCTAssertEqual(facts.0.first?["ticket_id"], .text("ticket-existing"))
        XCTAssertEqual(facts.0.first?["disposition"], .text("split"))
        XCTAssertEqual(facts.0.first?["last_phase_id"], .text("phase-current"))
        XCTAssertEqual(facts.0.first?["last_lane"], .text("backlog"))
        XCTAssertEqual(facts.1.map { $0["successor_ticket_id"] }, [.text("ticket-successor-a"), .text("ticket-successor-b")])
        XCTAssertEqual(facts.1.map { $0["relation"] }, [.text("split"), .text("split")])
        XCTAssertEqual(facts.2.compactMap { $0["id"] }, [.text("ticket-existing"), .text("ticket-successor-a"), .text("ticket-successor-b")])
        XCTAssertEqual(facts.2.filter { $0["id"] != .text("ticket-existing") }.map { $0["lane"] }, [.text("backlog"), .text("backlog")])
        XCTAssertEqual(facts.3.map { $0["completion"] }, [.text("pending"), .text("pending")])
        XCTAssertEqual(facts.3.map { $0["lifecycle"] }, [.text("active"), .text("active")])
        XCTAssertEqual(facts.4.map { $0["ticket_id"] }, [.text("ticket-existing"), .text("ticket-successor-a"), .text("ticket-successor-b")])
        XCTAssertEqual(facts.5.map { $0["descendant_ticket_id"] }, [.text("ticket-successor-a"), .text("ticket-successor-b")])

        let auditCount = try await fixture.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let dependencyMutation = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .setDependency(
                id: "retired-dependency", kind: .ticket,
                subjectID: "ticket-successor-a", dependsOnID: "ticket-existing"
            )
        ))
        guard case .invalidReference = dependencyMutation.error else {
            return XCTFail("Expected retired dependency association rejection, got \(String(describing: dependencyMutation.error))")
        }
        let taskMutation = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .reviseTicketTaskPlan(
                ticketID: "ticket-existing", expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "late-task"), label: "Late", title: "Mutate retired work", sortOrder: 0)],
                definitionRevisions: [], supersededTaskIDs: []
            )
        ))
        XCTAssertEqual(taskMutation.error, .invalidTicketTaskMutation("retiredTicket"))
        let rejectedCounts = try await fixture.store.read {
            (try $0.scalarInt("SELECT COUNT(*) FROM audit_events"),
             try $0.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE id='retired-dependency'"),
             try $0.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE id='late-task'"))
        }
        XCTAssertEqual(rejectedCounts.0, auditCount)
        XCTAssertEqual(rejectedCounts.1, 0)
        XCTAssertEqual(rejectedCounts.2, 0)

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed association rehome guards") { connection in
            try connection.execute("INSERT INTO review_items (id,project_id,ticket_id,kind,summary,status) VALUES ('retired-owned-review','proposal-project','ticket-existing','agent_request','Retired owner','open')")
            try connection.execute("INSERT INTO review_items (id,project_id,ticket_id,kind,summary,status) VALUES ('active-owned-review','proposal-project','ticket-successor-a','agent_request','Active owner','open')")
        }
        let currentSource = try await bindCurrentSource(
            to: "ticket-successor-a", linkID: "active-reference", fixture: fixture
        )
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: fixture.root)
        let target = DocumentationTarget(
            projectID: fixture.registration.projectID.rawValue,
            rootID: "root-1",
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest
        )
        let artifact = try XCTUnwrap(snapshot.catalog.artifacts.first { $0.artifactID == "current" })
        let guardedStateBefore = try await fixture.store.read { connection in
            (
                try connection.rows("SELECT id,ticket_id FROM review_items WHERE id IN ('retired-owned-review','active-owned-review') ORDER BY id"),
                try connection.scalarInt("SELECT COUNT(*) FROM completion_records"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_links"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        let guardedMutations = [
            await fixture.dispatcher.dispatch(envelope(
                fixture, requestID: UUID(), command: .requestReview(
                    id: "retired-owned-review", ticketID: "ticket-successor-a",
                    kind: "agent_request", summary: "Must not rehome from retired work"
                )
            )),
            await fixture.dispatcher.dispatch(envelope(
                fixture, requestID: UUID(), command: .requestReview(
                    id: "active-owned-review", ticketID: "ticket-existing",
                    kind: "agent_request", summary: "Must not rehome onto retired work"
                )
            )),
            await fixture.dispatcher.dispatch(envelope(
                fixture, requestID: UUID(), command: .recordCompletion(
                    id: "retired-completion", ticketID: "ticket-existing",
                    summary: "Must not complete retained work"
                )
            )),
            await fixture.dispatcher.dispatch(envelope(
                fixture, requestID: UUID(), command: .upsertTicketReference(
                    target: target, ticketID: "ticket-existing", linkID: "retired-reference",
                    kind: .requirement, artifactID: artifact.artifactID,
                    sourceLocalID: nil, locator: nil,
                    expectedContentDigest: documentationDigest(try Data(contentsOf: currentSource)),
                    expectedLinkSetRevision: 0
                )
            )),
        ]
        XCTAssertTrue(guardedMutations.allSatisfy { $0.error != nil })
        let guardedStateAfter = try await fixture.store.read { connection in
            (
                try connection.rows("SELECT id,ticket_id FROM review_items WHERE id IN ('retired-owned-review','active-owned-review') ORDER BY id"),
                try connection.scalarInt("SELECT COUNT(*) FROM completion_records"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_reference_links"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(guardedStateAfter.0, guardedStateBefore.0)
        XCTAssertEqual(guardedStateAfter.1, guardedStateBefore.1)
        XCTAssertEqual(guardedStateAfter.2, guardedStateBefore.2)
        XCTAssertEqual(guardedStateAfter.3, guardedStateBefore.3)
    }

    func testApprovedReplacementMoveCarrySupersessionAndDependencyReconciliationAreAtomic() async throws {
        let fixture = try await makeFixture()
        let seedAudit = AuditEventID(rawValue: "audit-seed-reconciliation")
        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Seed reconciled planning graph",
            auditEventID: seedAudit,
            auditScope: .init(projectID: fixture.registration.projectID, entityType: .phasePlan, entityID: "phase-current")
        ) { connection in
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: fixture.registration.projectID, phaseID: .init(rawValue: "phase-next"),
                name: "Next", mode: .governed, connection: connection
            )
            try DeliveryPlanningPolicy.upsertUnassignedTicket(
                projectID: fixture.registration.projectID, ticketID: .init(rawValue: "ticket-move"),
                outcome: "Move retained scope", connection: connection
            )
            try DeliveryPlanningPolicy.upsertUnassignedTicket(
                projectID: fixture.registration.projectID, ticketID: .init(rawValue: "ticket-consumer"),
                outcome: "Consume successor", connection: connection
            )
            _ = try DeliveryPlanningPolicy.placeUnassignedTicket(
                projectID: fixture.registration.projectID, ticketID: .init(rawValue: "ticket-existing"),
                phaseID: .init(rawValue: "phase-current"), expectedPlanRevision: 0, connection: connection
            )
            let placed = try DeliveryPlanningPolicy.placeUnassignedTicket(
                projectID: fixture.registration.projectID, ticketID: .init(rawValue: "ticket-move"),
                phaseID: .init(rawValue: "phase-current"), expectedPlanRevision: 1, connection: connection
            )
            let consumerPlaced = try DeliveryPlanningPolicy.placeUnassignedTicket(
                projectID: fixture.registration.projectID, ticketID: .init(rawValue: "ticket-consumer"),
                phaseID: .init(rawValue: "phase-next"), expectedPlanRevision: 0, connection: connection
            )
            let consumerPlan = try DeliveryPlanningPolicy.applyRevision(
                projectID: fixture.registration.projectID, phaseID: .init(rawValue: "phase-next"),
                expectedRevision: consumerPlaced.revision,
                goalUpserts: [.init(id: .init(rawValue: "goal-consumer"), title: "Consumer", outcome: "Consume resolved scope", doneCriteria: ["Dependencies resolve"], sortOrder: 0)],
                assignments: [.init(goalID: .init(rawValue: "goal-consumer"), ticketID: .init(rawValue: "ticket-consumer"))],
                unassignedTicketIDs: [], supersededGoalIDs: [], auditEventID: seedAudit,
                connection: connection
            )
            _ = try DeliveryPlanningPolicy.finalizePlan(
                projectID: fixture.registration.projectID, phaseID: .init(rawValue: "phase-next"),
                expectedRevision: consumerPlan.revision, connection: connection
            )
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: fixture.registration.projectID, phaseID: .init(rawValue: "phase-current"),
                expectedRevision: placed.revision,
                goalUpserts: [.init(id: .init(rawValue: "goal-old"), title: "Old", outcome: "Old scope", doneCriteria: ["Accepted"], sortOrder: 0)],
                assignments: [
                    .init(goalID: .init(rawValue: "goal-old"), ticketID: .init(rawValue: "ticket-existing")),
                    .init(goalID: .init(rawValue: "goal-old"), ticketID: .init(rawValue: "ticket-move")),
                ], unassignedTicketIDs: [], supersededGoalIDs: [], auditEventID: seedAudit,
                connection: connection
            )
            try connection.execute("INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id) VALUES ('dep-retarget','proposal-project','ticket-consumer','ticket-existing')")
            try connection.execute("INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id) VALUES ('dep-remove','proposal-project','ticket-consumer','ticket-move')")
        }

        do {
            try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Verify retired prerequisite remains blocking") { connection in
                try DeliveryPlanningPolicy.transitionTicket(
                    projectID: fixture.registration.projectID,
                    ticketID: .init(rawValue: "ticket-consumer"),
                    to: .inProgress,
                    connection: connection
                )
            }
            XCTFail("An unresolved prerequisite must block the consumer before reconciliation.")
        } catch {
            guard case DeliveryPlanningPolicyError.invalidPlanMutation = error else { throw error }
        }

        let oldOriginal = DeliveryGoalObligationKey(
            phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-old"),
            ticketID: .init(rawValue: "ticket-existing")
        )
        let oldMoved = DeliveryGoalObligationKey(
            phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-old"),
            ticketID: .init(rawValue: "ticket-move")
        )
        let operations: [PlanChangeOperation] = [
            .addDeliveryGoal(
                phaseID: .init(rawValue: "phase-next"),
                goal: .init(id: .init(rawValue: "goal-next"), title: "Next", outcome: "Carried scope", doneCriteria: ["Accepted"], sortOrder: 0)
            ),
            .addUnassignedTicket(id: .init(rawValue: "ticket-successor"), outcome: "Replacement scope"),
            .addPendingTicketTasks(ticketID: .init(rawValue: "ticket-successor"), tasks: [
                .init(id: .init(rawValue: "task-successor"), label: "S", title: "Implement replacement", sortOrder: 0),
            ]),
            .placeTicket(ticketID: .init(rawValue: "ticket-successor"), phaseID: .init(rawValue: "phase-next")),
            .assignTicketToGoal(ticketID: .init(rawValue: "ticket-successor"), phaseID: .init(rawValue: "phase-next"), goalID: .init(rawValue: "goal-next")),
            .retireTicket(ticketID: .init(rawValue: "ticket-existing"), disposition: .replaced, reason: "Replace retained scope", successorTicketIDs: [.init(rawValue: "ticket-successor")]),
            .carryGoalObligation(
                source: oldOriginal,
                descendants: [.init(phaseID: .init(rawValue: "phase-next"), goalID: .init(rawValue: "goal-next"), ticketID: .init(rawValue: "ticket-successor"))],
                reason: "Replacement retains delivery scope"
            ),
            .moveBacklogTicket(ticketID: .init(rawValue: "ticket-move"), fromPhaseID: .init(rawValue: "phase-current"), toPhaseID: .init(rawValue: "phase-next")),
            .reassignTicketToGoal(ticketID: .init(rawValue: "ticket-move"), phaseID: .init(rawValue: "phase-next"), fromGoalID: .init(rawValue: "goal-old"), toGoalID: .init(rawValue: "goal-next")),
            .carryGoalObligation(
                source: oldMoved,
                descendants: [.init(phaseID: .init(rawValue: "phase-next"), goalID: .init(rawValue: "goal-next"), ticketID: .init(rawValue: "ticket-move"))],
                reason: "Move retains delivery scope"
            ),
            .supersedeDeliveryGoal(phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-old")),
            .retargetTicketDependency(id: .init(rawValue: "dep-retarget"), ticketID: .init(rawValue: "ticket-consumer"), fromDependsOnTicketID: .init(rawValue: "ticket-existing"), toDependsOnTicketID: .init(rawValue: "ticket-successor")),
            .removeTicketDependency(id: .init(rawValue: "dep-remove"), ticketID: .init(rawValue: "ticket-consumer"), dependsOnTicketID: .init(rawValue: "ticket-move")),
        ]
        let saved = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: "proposal-reconcile", expectedPreviousVersion: nil,
                rationale: "Reconcile successor and moved scope atomically.", operations: operations
            )
        ))
        XCTAssertNil(saved.error)
        let loaded = try await PlanChangeProposalQuery.load(
            from: fixture.store, projectID: fixture.registration.projectID
        )
        let proposal = try XCTUnwrap(loaded.first?.versions.first)
        let decision = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .decidePlanChangeProposal(
                proposalID: "proposal-reconcile", version: 1, baselineDigest: proposal.baselineDigest,
                decisionID: "decision-reconcile", disposition: .approved
            )
        ), origin: .ownerApp)
        XCTAssertNil(decision.error)
        let applied = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .applyPlanChangeProposal(
                proposalID: "proposal-reconcile", version: 1, baselineDigest: proposal.baselineDigest,
                decisionID: "decision-reconcile", applicationID: "application-reconcile"
            )
        ), origin: .ownerApp)
        XCTAssertNil(applied.error)

        let facts = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT lifecycle FROM delivery_goals WHERE project_id='proposal-project' AND id='goal-old'"),
                try connection.rows("SELECT ticket_id,goal_id,phase_id FROM delivery_goal_ticket_assignments WHERE project_id='proposal-project' ORDER BY ticket_id"),
                try connection.rows("SELECT id,depends_on_ticket_id FROM ticket_dependencies WHERE project_id='proposal-project' ORDER BY id"),
                try connection.scalarInt("SELECT COUNT(*) FROM delivery_goal_obligation_lineage WHERE project_id='proposal-project'"),
                try connection.scalarText("SELECT disposition FROM ticket_retirements WHERE project_id='proposal-project' AND ticket_id='ticket-existing'")
            )
        }
        XCTAssertEqual(facts.0, "superseded")
        XCTAssertEqual(facts.1.map { $0["ticket_id"] }, [.text("ticket-consumer"), .text("ticket-move"), .text("ticket-successor")])
        XCTAssertEqual(facts.1.map { $0["goal_id"] }, [.text("goal-consumer"), .text("goal-next"), .text("goal-next")])
        XCTAssertEqual(facts.1.map { $0["phase_id"] }, [.text("phase-next"), .text("phase-next"), .text("phase-next")])
        XCTAssertEqual(facts.2, [["id": .text("dep-retarget"), "depends_on_ticket_id": .text("ticket-successor")]])
        XCTAssertEqual(facts.3, 2)
        XCTAssertEqual(facts.4, "replaced")

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Re-finalize reconciled destination") { connection in
            let revision = try XCTUnwrap(connection.scalarInt("SELECT revision FROM phase_plans WHERE project_id='proposal-project' AND phase_id='phase-next'"))
            _ = try DeliveryPlanningPolicy.finalizePlan(
                projectID: fixture.registration.projectID, phaseID: .init(rawValue: "phase-next"),
                expectedRevision: revision, connection: connection
            )
        }
        do {
            try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Verify retargeted required work remains blocking") { connection in
                try DeliveryPlanningPolicy.transitionTicket(
                    projectID: fixture.registration.projectID,
                    ticketID: .init(rawValue: "ticket-consumer"),
                    to: .inProgress,
                    connection: connection
                )
            }
            XCTFail("Retargeting must not count an incomplete successor as delivered.")
        } catch {
            guard case DeliveryPlanningPolicyError.invalidPlanMutation = error else { throw error }
        }
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Complete the explicit successor prerequisite") { connection in
            try connection.execute("UPDATE tickets SET lane='accepted' WHERE project_id='proposal-project' AND id='ticket-successor'")
            try DeliveryPlanningPolicy.transitionTicket(
                projectID: fixture.registration.projectID,
                ticketID: .init(rawValue: "ticket-consumer"),
                to: .inProgress,
                connection: connection
            )
        }
        let consumerLane = try await fixture.store.read {
            try $0.scalarText("SELECT lane FROM tickets WHERE project_id='proposal-project' AND id='ticket-consumer'")
        }
        XCTAssertEqual(consumerLane, TicketLane.inProgress.rawValue)
    }

    func testApprovedWithdrawalDropsExactObligationWithoutInventingDelivery() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed exact withdrawal obligation") { connection in
            let timestamp = "2026-09-10T00:00:00Z"
            try connection.execute("UPDATE tickets SET phase_id='phase-current', lane='backlog' WHERE project_id='proposal-project' AND id='ticket-existing'")
            try connection.execute(
                "INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('proposal-project','phase-current','goal-current','Current','Current scope','draft',0,?,?)",
                bindings: [.text(timestamp), .text(timestamp)]
            )
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion) VALUES ('proposal-project','phase-current','goal-current',0,'Scope is resolved')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('proposal-project','phase-current','goal-current','ticket-existing')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('proposal-project','phase-current','goal-current','ticket-existing','Existing planned work','current',?)", bindings: [.text(timestamp)])
        }
        let key = DeliveryGoalObligationKey(
            phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"),
            ticketID: .init(rawValue: "ticket-existing")
        )
        let saved = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: "proposal-withdraw", expectedPreviousVersion: nil,
                rationale: "Withdraw owner-approved scope with an explicit reason.", operations: [
                    .retireTicket(
                        ticketID: key.ticketID, disposition: .withdrawn,
                        reason: "No longer part of the delivery outcome", successorTicketIDs: []
                    ),
                    .dropGoalObligation(obligation: key, reason: "Owner intentionally removed this scope"),
                ]
            )
        ))
        XCTAssertNil(saved.error)
        let loaded = try await PlanChangeProposalQuery.load(
            from: fixture.store, projectID: fixture.registration.projectID
        )
        let proposal = try XCTUnwrap(loaded.first?.versions.first)
        let decision = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .decidePlanChangeProposal(
                proposalID: "proposal-withdraw", version: 1, baselineDigest: proposal.baselineDigest,
                decisionID: "decision-withdraw", disposition: .approved
            )
        ), origin: .ownerApp)
        XCTAssertNil(decision.error)
        let applied = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .applyPlanChangeProposal(
                proposalID: "proposal-withdraw", version: 1, baselineDigest: proposal.baselineDigest,
                decisionID: "decision-withdraw", applicationID: "application-withdraw"
            )
        ), origin: .ownerApp)
        XCTAssertNil(applied.error)

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT disposition FROM ticket_retirements WHERE project_id='proposal-project' AND ticket_id='ticket-existing'"),
                try connection.scalarText("SELECT reason FROM delivery_goal_obligation_drops WHERE project_id='proposal-project' AND ticket_id='ticket-existing'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_successor_links WHERE project_id='proposal-project'"),
                try connection.scalarText("SELECT lane FROM tickets WHERE project_id='proposal-project' AND id='ticket-existing'"),
                try DeliveryGoalCoveragePolicy.assess(
                    projectID: fixture.registration.projectID, phaseID: key.phaseID,
                    goalID: key.goalID, connection: connection
                )
            )
        }
        XCTAssertEqual(state.0, "withdrawn")
        XCTAssertEqual(state.1, "Owner intentionally removed this scope")
        XCTAssertEqual(state.2, 0)
        XCTAssertEqual(state.3, TicketLane.backlog.rawValue)
        XCTAssertTrue(state.4.isResolved)
        XCTAssertFalse(state.4.hasDeliveredOutcome)
        XCTAssertFalse(state.4.isAcceptanceEligible)
    }

    func testSuccessorMustBeNewAndCreatedInSameProposal() async throws {
        let fixture = try await makeFixture()
        let result = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: "proposal-invalid-successor", expectedPreviousVersion: nil,
                rationale: "Reject reuse of an existing ticket.",
                operations: [.retireTicket(
                    ticketID: .init(rawValue: "ticket-existing"), disposition: .replaced,
                    reason: "Invalid replacement", successorTicketIDs: [.init(rawValue: "ticket-existing")]
                )]
            )
        ))
        guard case .invalidPlanChangeOperation = result.error else {
            return XCTFail("Expected invalid successor admission, got \(String(describing: result.error))")
        }
    }

    func testSuccessorRequiresNewPendingTasksInSameProposal() async throws {
        let fixture = try await makeFixture()
        let result = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: "proposal-successor-without-tasks", expectedPreviousVersion: nil,
                rationale: "Reject an incomplete successor package.", operations: [
                    .addUnassignedTicket(id: .init(rawValue: "new-successor"), outcome: "Replacement"),
                    .retireTicket(
                        ticketID: .init(rawValue: "ticket-existing"), disposition: .replaced,
                        reason: "Replace scope", successorTicketIDs: [.init(rawValue: "new-successor")]
                    ),
                ]
            )
        ))
        guard case .invalidPlanChangeOperation = result.error else {
            return XCTFail("Expected missing successor tasks to be rejected, got \(String(describing: result.error))")
        }
    }

    func testAcceptedTicketCannotBecomeARetiredOriginal() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed immutable accepted ticket") {
            try $0.execute("UPDATE tickets SET phase_id='phase-current', lane='accepted' WHERE project_id='proposal-project' AND id='ticket-existing'")
        }
        let result = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: "proposal-retire-accepted", expectedPreviousVersion: nil,
                rationale: "Reject mutation of Accepted history.", operations: [
                    .retireTicket(
                        ticketID: .init(rawValue: "ticket-existing"), disposition: .withdrawn,
                        reason: "Invalid retirement", successorTicketIDs: []
                    ),
                ]
            )
        ))
        guard case .invalidPlanChangeOperation = result.error else {
            return XCTFail("Expected Accepted retirement rejection, got \(String(describing: result.error))")
        }
    }

    func testAcceptedObligationsCannotBeCarriedDroppedOrUsedAsDescendants() async throws {
        let source = DeliveryGoalObligationKey(
            phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"),
            ticketID: .init(rawValue: "obligation-a")
        )
        let descendant = DeliveryGoalObligationKey(
            phaseID: source.phaseID, goalID: source.goalID, ticketID: .init(rawValue: "obligation-b")
        )
        let scenarios: [(String, @Sendable (SQLiteConnection) throws -> Void, [PlanChangeOperation])] = [
            ("accepted-source-carry", { connection in
                try connection.execute("UPDATE tickets SET lane='accepted' WHERE project_id='proposal-project' AND id='obligation-a'")
                try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('proposal-project','phase-current','goal-current','obligation-a')")
            }, [.carryGoalObligation(source: source, descendants: [descendant], reason: "Must reject delivered source")]),
            ("accepted-goal-drop", { connection in
                try connection.execute("UPDATE delivery_goals SET lifecycle='accepted' WHERE project_id='proposal-project' AND id='goal-current'")
            }, [.dropGoalObligation(obligation: source, reason: "Must reject accepted goal scope")]),
            ("accepted-descendant", { connection in
                try connection.execute("UPDATE tickets SET lane='accepted' WHERE project_id='proposal-project' AND id='obligation-b'")
                try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('proposal-project','phase-current','goal-current','obligation-b')")
            }, [.carryGoalObligation(source: source, descendants: [descendant], reason: "Must reject terminal descendant")]),
        ]

        for (name, mutate, operations) in scenarios {
            let fixture = try await makeCarryValidationFixture(persistedCycle: false)
            try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed \(name)") { connection in
                try mutate(connection)
            }
            let before = try await fixture.store.read {
                (try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
                 try $0.scalarInt("SELECT COUNT(*) FROM audit_events"))
            }
            let result = await fixture.dispatcher.dispatch(envelope(
                fixture, requestID: UUID(), command: .savePlanChangeProposal(
                    proposalID: "proposal-\(name)", expectedPreviousVersion: nil,
                    rationale: "Reject terminal obligation mutation.", operations: operations
                )
            ))
            guard case .invalidPlanChangeOperation = result.error else {
                XCTFail("Expected terminal obligation rejection for \(name), got \(String(describing: result.error))")
                continue
            }
            let after = try await fixture.store.read {
                (try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
                 try $0.scalarInt("SELECT COUNT(*) FROM audit_events"))
            }
            XCTAssertEqual(after.0, before.0, name)
            XCTAssertEqual(after.1, before.1, name)
        }
    }

    func testSplitRetirementRejectsCarryThatOmitsARequiredSuccessor() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed split source obligation") { connection in
            try connection.execute("UPDATE tickets SET phase_id='phase-current',lane='backlog' WHERE project_id='proposal-project' AND id='ticket-existing'")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('proposal-project','phase-current','goal-current','Goal','Outcome','draft',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('proposal-project','phase-current','goal-current','ticket-existing','Original split scope','current','2026-09-10T00:00:00Z')")
        }
        let successorA = TicketID(rawValue: "successor-a")
        let successorB = TicketID(rawValue: "successor-b")
        let operations: [PlanChangeOperation] = [
            .addUnassignedTicket(id: successorA, outcome: "First successor"),
            .addUnassignedTicket(id: successorB, outcome: "Second successor"),
            .addPendingTicketTasks(ticketID: successorA, tasks: [.init(id: .init(rawValue: "task-a"), label: "A", title: "First", sortOrder: 0)]),
            .addPendingTicketTasks(ticketID: successorB, tasks: [.init(id: .init(rawValue: "task-b"), label: "B", title: "Second", sortOrder: 0)]),
            .placeTicket(ticketID: successorA, phaseID: .init(rawValue: "phase-current")),
            .placeTicket(ticketID: successorB, phaseID: .init(rawValue: "phase-current")),
            .assignTicketToGoal(ticketID: successorA, phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current")),
            .assignTicketToGoal(ticketID: successorB, phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current")),
            .retireTicket(ticketID: .init(rawValue: "ticket-existing"), disposition: .split, reason: "Split all scope", successorTicketIDs: [successorA, successorB]),
            .carryGoalObligation(
                source: .init(phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"), ticketID: .init(rawValue: "ticket-existing")),
                descendants: [.init(phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"), ticketID: successorA)],
                reason: "Incomplete split carry"
            ),
        ]
        let before = try await fixture.store.read {
            (try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
             try $0.scalarInt("SELECT COUNT(*) FROM audit_events"))
        }
        let result = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: "proposal-incomplete-split", expectedPreviousVersion: nil,
                rationale: "Reject incomplete split coverage.", operations: operations
            )
        ))
        guard case .invalidPlanChangeOperation = result.error else {
            return XCTFail("Expected incomplete split carry rejection, got \(String(describing: result.error))")
        }
        let after = try await fixture.store.read {
            (try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
             try $0.scalarInt("SELECT COUNT(*) FROM audit_events"))
        }
        XCTAssertEqual(after.0, before.0)
        XCTAssertEqual(after.1, before.1)
    }

    func testDetachedHistoricalObligationCanBeDroppedOrCarriedAfterAcceptanceElsewhere() async throws {
        for reconciliation in ["drop", "carry"] {
            let (fixture, source) = try await makeAcceptedElsewhereFixture()
            let operations: [PlanChangeOperation]
            if reconciliation == "drop" {
                operations = [
                    .dropGoalObligation(
                        obligation: source,
                        reason: "Explicitly remove the uncovered historical scope"
                    )
                ]
            } else {
                let successor = TicketID(rawValue: "historical-successor")
                let descendant = DeliveryGoalObligationKey(
                    phaseID: source.phaseID, goalID: source.goalID, ticketID: successor
                )
                operations = [
                    .addUnassignedTicket(id: successor, outcome: "Carry historical scope"),
                    .addPendingTicketTasks(
                        ticketID: successor,
                        tasks: [.init(
                            id: .init(rawValue: "historical-successor-task"), label: "Carry",
                            title: "Complete historical scope", sortOrder: 0
                        )]
                    ),
                    .placeTicket(ticketID: successor, phaseID: source.phaseID),
                    .assignTicketToGoal(
                        ticketID: successor, phaseID: source.phaseID, goalID: source.goalID
                    ),
                    .carryGoalObligation(
                        source: source, descendants: [descendant],
                        reason: "Carry uncovered historical scope to new work"
                    ),
                ]
            }
            try await saveApproveAndApply(
                fixture, proposalID: "proposal-reconcile-\(reconciliation)", operations: operations
            )
            let coverage = try await fixture.store.read {
                try DeliveryGoalCoveragePolicy.assess(
                    projectID: fixture.registration.projectID,
                    phaseID: source.phaseID,
                    goalID: source.goalID,
                    connection: $0
                )
            }
            XCTAssertEqual(
                coverage.obligations.first(where: { $0.key == source })?.state,
                reconciliation == "drop" ? .dropped : .carried
            )
        }
    }

    func testExistingCarryCannotAuthorizeALaterSplitWithDifferentSuccessors() async throws {
        let fixture = try await makeFixture()
        let source = DeliveryGoalObligationKey(
            phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"),
            ticketID: .init(rawValue: "ticket-existing")
        )
        let earlierDescendant = DeliveryGoalObligationKey(
            phaseID: source.phaseID, goalID: source.goalID,
            ticketID: .init(rawValue: "earlier-descendant")
        )
        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Seed earlier carried scope",
            auditEventID: .init(rawValue: "earlier-carry-seed"),
            auditScope: .init(
                projectID: fixture.registration.projectID,
                entityType: .phasePlan,
                entityID: source.phaseID.rawValue
            )
        ) { connection in
            try connection.execute("UPDATE tickets SET phase_id='phase-current',lane='backlog' WHERE project_id='proposal-project' AND id='ticket-existing'")
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('earlier-descendant','proposal-project','phase-current','Earlier carried work','backlog')")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('proposal-project','phase-current','goal-current','Goal','Outcome','draft',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('proposal-project','phase-current','goal-current','ticket-existing'),('proposal-project','phase-current','goal-current','earlier-descendant')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('proposal-project','phase-current','goal-current','ticket-existing','Original scope','current','2026-09-10T00:00:00Z'),('proposal-project','phase-current','goal-current','earlier-descendant','Earlier scope','current','2026-09-10T00:00:00Z')")
        }
        try await saveApproveAndApply(
            fixture, proposalID: "proposal-earlier-carry",
            operations: [.carryGoalObligation(
                source: source, descendants: [earlierDescendant], reason: "Earlier approved carry"
            )]
        )

        let successorA = TicketID(rawValue: "later-successor-a")
        let successorB = TicketID(rawValue: "later-successor-b")
        let operations: [PlanChangeOperation] = [
            .addUnassignedTicket(id: successorA, outcome: "Later successor A"),
            .addUnassignedTicket(id: successorB, outcome: "Later successor B"),
            .addPendingTicketTasks(ticketID: successorA, tasks: [.init(id: .init(rawValue: "later-task-a"), label: "A", title: "A", sortOrder: 0)]),
            .addPendingTicketTasks(ticketID: successorB, tasks: [.init(id: .init(rawValue: "later-task-b"), label: "B", title: "B", sortOrder: 0)]),
            .retireTicket(
                ticketID: source.ticketID, disposition: .split,
                reason: "Later split must reconcile exact successors",
                successorTicketIDs: [successorA, successorB]
            ),
        ]
        let before = try await fixture.store.read {
            (try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
             try $0.scalarInt("SELECT COUNT(*) FROM audit_events"))
        }
        let result = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: "proposal-later-split", expectedPreviousVersion: nil,
                rationale: "Reject incompatible historical carry.", operations: operations
            )
        ))
        guard case .invalidPlanChangeOperation = result.error else {
            return XCTFail("Expected incompatible earlier carry rejection, got \(String(describing: result.error))")
        }
        let after = try await fixture.store.read {
            (try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
             try $0.scalarInt("SELECT COUNT(*) FROM audit_events"))
        }
        XCTAssertEqual(after.0, before.0)
        XCTAssertEqual(after.1, before.1)
    }

    func testInvalidCarryGraphsRejectBeforeProposalOrAuditWrites() async throws {
        let a = DeliveryGoalObligationKey(
            phaseID: .init(rawValue: "phase-current"), goalID: .init(rawValue: "goal-current"),
            ticketID: .init(rawValue: "obligation-a")
        )
        let b = DeliveryGoalObligationKey(
            phaseID: a.phaseID, goalID: a.goalID, ticketID: .init(rawValue: "obligation-b")
        )
        let c = DeliveryGoalObligationKey(
            phaseID: a.phaseID, goalID: a.goalID, ticketID: .init(rawValue: "obligation-c")
        )
        let foreign = DeliveryGoalObligationKey(
            phaseID: .init(rawValue: "foreign-phase"), goalID: .init(rawValue: "foreign-goal"),
            ticketID: .init(rawValue: "foreign-ticket")
        )
        let scenarios: [(String, Bool, [PlanChangeOperation])] = [
            ("proposed-cycle", false, [
                .carryGoalObligation(source: a, descendants: [b], reason: "A to B"),
                .carryGoalObligation(source: b, descendants: [a], reason: "B to A"),
            ]),
            ("persisted-cycle", true, [
                .carryGoalObligation(source: b, descendants: [a], reason: "Close the persisted cycle"),
            ]),
            ("reused-descendant", false, [
                .carryGoalObligation(source: a, descendants: [c], reason: "First source"),
                .carryGoalObligation(source: b, descendants: [c], reason: "Second source"),
            ]),
            ("conflicting-resolution", false, [
                .carryGoalObligation(source: a, descendants: [b], reason: "Carry scope"),
                .dropGoalObligation(obligation: a, reason: "Conflicting drop"),
            ]),
            ("cross-project", false, [
                .carryGoalObligation(source: a, descendants: [foreign], reason: "Invalid foreign carry"),
            ]),
        ]

        for (name, persistedCycle, operations) in scenarios {
            let fixture = try await makeCarryValidationFixture(persistedCycle: persistedCycle)
            let before = try await fixture.store.read { connection in
                (
                    try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
                )
            }
            let result = await fixture.dispatcher.dispatch(envelope(
                fixture, requestID: UUID(), command: .savePlanChangeProposal(
                    proposalID: "proposal-\(name)", expectedPreviousVersion: nil,
                    rationale: "Reject \(name).", operations: operations
                )
            ))
            guard case .invalidPlanChangeOperation = result.error else {
                XCTFail("Expected invalid carry graph for \(name), got \(String(describing: result.error))")
                continue
            }
            let after = try await fixture.store.read { connection in
                (
                    try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposals"),
                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
                )
            }
            XCTAssertEqual(after.0, before.0, name)
            XCTAssertEqual(after.1, before.1, name)
        }
    }

    private struct Fixture {
        let store: DeliveryStore
        let dispatcher: AgentCommandDispatcher
        let root: URL
        let registration: ProjectRegistration
    }

    private func makeAcceptedElsewhereFixture() async throws -> (Fixture, DeliveryGoalObligationKey) {
        let fixture = try await makeFixture()
        let projectID = fixture.registration.projectID
        let sourcePhase = PhaseID(rawValue: "phase-current")
        let destinationPhase = PhaseID(rawValue: "phase-destination")
        let sourceGoal = DeliveryGoalID(rawValue: "goal-current")
        let destinationGoal = DeliveryGoalID(rawValue: "goal-destination")
        let ticketID = TicketID(rawValue: "ticket-existing")
        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Seed actual move source",
            auditEventID: .init(rawValue: "accepted-elsewhere-seed"),
            auditScope: .init(
                projectID: projectID, entityType: .phasePlan, entityID: sourcePhase.rawValue
            )
        ) { connection in
            try connection.execute("UPDATE tickets SET phase_id='phase-current',lane='backlog' WHERE project_id='proposal-project' AND id='ticket-existing'")
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: projectID, phaseID: destinationPhase,
                name: "Destination", mode: .governed, connection: connection
            )
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: projectID, ticketID: ticketID, expectedRevision: nil,
                additions: [.init(
                    id: .init(rawValue: "accepted-elsewhere-task"), label: "Move",
                    title: "Complete moved scope", sortOrder: 0
                )],
                definitionRevisions: [], supersededTaskIDs: [], connection: connection
            )
            _ = try TicketTaskPlanningPolicy.completeTask(
                projectID: projectID, ticketID: ticketID,
                taskID: .init(rawValue: "accepted-elsewhere-task"),
                expectedRevision: 1, connection: connection
            )
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: sourcePhase, expectedRevision: 0,
                goalUpserts: [.init(
                    id: sourceGoal, title: "Historical", outcome: "Historical scope",
                    doneCriteria: ["Scope is reconciled"], sortOrder: 0
                )],
                assignments: [.init(goalID: sourceGoal, ticketID: ticketID)],
                unassignedTicketIDs: [], supersededGoalIDs: [],
                auditEventID: .init(rawValue: "accepted-elsewhere-seed"), connection: connection
            )
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: destinationPhase, expectedRevision: 0,
                goalUpserts: [.init(
                    id: destinationGoal, title: "Destination", outcome: "Moved scope",
                    doneCriteria: ["Ticket is Accepted"], sortOrder: 0
                )],
                assignments: [], unassignedTicketIDs: [], supersededGoalIDs: [],
                auditEventID: .init(rawValue: "accepted-elsewhere-seed"), connection: connection
            )
        }
        try await saveApproveAndApply(
            fixture, proposalID: "proposal-move-elsewhere", operations: [
                .moveBacklogTicket(
                    ticketID: ticketID, fromPhaseID: sourcePhase, toPhaseID: destinationPhase
                ),
                .reassignTicketToGoal(
                    ticketID: ticketID, phaseID: destinationPhase,
                    fromGoalID: sourceGoal, toGoalID: destinationGoal
                ),
            ]
        )
        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Accept moved scope elsewhere"
        ) { connection in
            let revision = try XCTUnwrap(connection.scalarInt(
                "SELECT revision FROM phase_plans WHERE project_id='proposal-project' AND phase_id='phase-destination'"
            ))
            _ = try DeliveryPlanningPolicy.finalizePlan(
                projectID: projectID, phaseID: destinationPhase,
                expectedRevision: revision, connection: connection
            )
            try DeliveryPlanningPolicy.transitionTicket(
                projectID: projectID, ticketID: ticketID, to: .inProgress, connection: connection
            )
            try DeliveryPlanningPolicy.transitionTicket(
                projectID: projectID, ticketID: ticketID, to: .needsReview, connection: connection
            )
            try DeliveryPlanningPolicy.transitionTicket(
                projectID: projectID, ticketID: ticketID, to: .accepted,
                ticketTaskPlanRevision: 2, connection: connection
            )
        }
        return (
            fixture,
            .init(phaseID: sourcePhase, goalID: sourceGoal, ticketID: ticketID)
        )
    }

    private func saveApproveAndApply(
        _ fixture: Fixture,
        proposalID: String,
        operations: [PlanChangeOperation]
    ) async throws {
        let saved = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .savePlanChangeProposal(
                proposalID: proposalID, expectedPreviousVersion: nil,
                rationale: "Exercise the exact approved proposal path.", operations: operations
            )
        ))
        XCTAssertNil(saved.error)
        let records = try await PlanChangeProposalQuery.load(
            from: fixture.store, projectID: fixture.registration.projectID
        )
        let version = try XCTUnwrap(
            records.first(where: { $0.id.rawValue == proposalID })?.versions.first
        )
        let decisionID = "decision-\(proposalID)"
        let decision = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .decidePlanChangeProposal(
                proposalID: proposalID, version: 1, baselineDigest: version.baselineDigest,
                decisionID: decisionID, disposition: .approved
            )
        ), origin: .ownerApp)
        XCTAssertNil(decision.error)
        let applied = await fixture.dispatcher.dispatch(envelope(
            fixture, requestID: UUID(), command: .applyPlanChangeProposal(
                proposalID: proposalID, version: 1, baselineDigest: version.baselineDigest,
                decisionID: decisionID, applicationID: "application-\(proposalID)"
            )
        ), origin: .ownerApp)
        XCTAssertNil(applied.error)
    }

    private func makeCarryValidationFixture(persistedCycle: Bool) async throws -> Fixture {
        let fixture = try await makeFixture()
        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Seed carry validation graph",
            auditEventID: .init(rawValue: "carry-validation-audit"),
            auditScope: .init(
                projectID: fixture.registration.projectID,
                entityType: .phasePlan,
                entityID: "phase-current"
            )
        ) { connection in
            for ticketID in ["obligation-a", "obligation-b", "obligation-c"] {
                try connection.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'proposal-project','phase-current',?,'backlog')",
                    bindings: [.text(ticketID), .text("Scope \(ticketID)")]
                )
            }
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('proposal-project','phase-current','goal-current','Goal','Outcome','draft',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            for ticketID in ["obligation-a", "obligation-b", "obligation-c"] {
                try connection.execute(
                    "INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('proposal-project','phase-current','goal-current',?,?,'current','2026-09-10T00:00:00Z')",
                    bindings: [.text(ticketID), .text("Scope \(ticketID)")]
                )
            }
            try connection.execute("INSERT INTO projects (id,name) VALUES ('foreign-project','Foreign')")
            try connection.execute("INSERT INTO phases (id,project_id,name) VALUES ('foreign-phase','foreign-project','Foreign')")
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('foreign-ticket','foreign-project','foreign-phase','Foreign','backlog')")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('foreign-project','foreign-phase','foreign-goal','Foreign','Foreign','draft',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('foreign-project','foreign-phase','foreign-goal','foreign-ticket','Foreign','current','2026-09-10T00:00:00Z')")
            if persistedCycle {
                try connection.execute("INSERT INTO delivery_goal_obligation_lineage (project_id,source_phase_id,source_goal_id,source_ticket_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id,reason,audit_event_id,created_at) VALUES ('proposal-project','phase-current','goal-current','obligation-a','phase-current','goal-current','obligation-b','Persisted edge','carry-validation-audit','2026-09-10T00:00:00Z')")
            }
        }
        return fixture
    }

    private func makeFixture(withDocumentation: Bool = false) async throws -> Fixture {
        let cacheRoot = try XCTUnwrap(
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ).appendingPathComponent("ReleaseRadarPhase5CProposalTests", isDirectory: true)
        let root = cacheRoot
            .appendingPathComponent("fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if withDocumentation {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
            try FileManager.default.copyItem(
                at: source.appendingPathComponent("docs"),
                to: root.appendingPathComponent("docs")
            )
            try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
                .write(to: root.appendingPathComponent("AGENTS.md"))
        }
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("store.sqlite"))
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "proposal-project"),
            registrationID: "registration-1",
            requestGeneration: 1
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed proposal fixture") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('proposal-project', 'Proposal Project', 1)"
            )
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'proposal-project', ?)",
                bindings: [.text(root.path)]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('proposal-project', 'registration-1', 1, 'complete')"
            )
            if withDocumentation {
                try connection.execute(
                    "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('proposal-project', ?, ?, 0)",
                    bindings: [.text(root.path), .blob(Data(root.path.utf8))]
                )
            }
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: registration.projectID,
                phaseID: .init(rawValue: "phase-current"),
                name: "Current",
                mode: .governed,
                connection: connection
            )
            try DeliveryPlanningPolicy.upsertUnassignedTicket(
                projectID: registration.projectID,
                ticketID: .init(rawValue: "ticket-existing"),
                outcome: "Existing planned work",
                connection: connection
            )
        }
        let project = AuthorizedProject(
            registration: registration,
            canonicalRoot: root,
            authorizedRoots: [root]
        )
        return Fixture(
            store: store,
            dispatcher: AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]),
                bookmarkStore: ProjectBookmarkStore(
                    resolver: { _ in .init(url: root, isStale: false) },
                    startAccessing: { _ in true },
                    stopAccessing: { _ in }
                )
            ),
            root: root,
            registration: registration
        )
    }

    private func envelope(
        _ fixture: Fixture,
        requestID: UUID,
        command: AgentCommand
    ) -> AgentCommandEnvelope {
        .init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: fixture.root.path,
            expectedRegistration: fixture.registration,
            reason: "Save plan-change proposal",
            command: command
        )
    }

    private func completeWorkPackage() -> [PlanChangeOperation] {
        [
            .addPhase(id: .init(rawValue: "phase-next"), name: "Next"),
            .addDeliveryGoal(
                phaseID: .init(rawValue: "phase-next"),
                goal: .init(
                    id: .init(rawValue: "goal-next"),
                    title: "Ship next",
                    outcome: "The next slice is usable",
                    doneCriteria: ["The focused acceptance path passes"],
                    sortOrder: 0
                )
            ),
            .addUnassignedTicket(id: .init(rawValue: "ticket-next"), outcome: "Deliver the next slice"),
            .addPendingTicketTasks(
                ticketID: .init(rawValue: "ticket-next"),
                tasks: [.init(id: .init(rawValue: "task-next"), label: "T1", title: "Implement the slice", sortOrder: 0)]
            ),
            .placeTicket(ticketID: .init(rawValue: "ticket-next"), phaseID: .init(rawValue: "phase-next")),
            .assignTicketToGoal(
                ticketID: .init(rawValue: "ticket-next"),
                phaseID: .init(rawValue: "phase-next"),
                goalID: .init(rawValue: "goal-next")
            ),
            .addPhaseDependency(
                id: .init(rawValue: "phase-dependency-next"),
                phaseID: .init(rawValue: "phase-next"),
                dependsOnPhaseID: .init(rawValue: "phase-current")
            ),
            .addTicketDependency(
                id: .init(rawValue: "ticket-dependency-next"),
                ticketID: .init(rawValue: "ticket-next"),
                dependsOnTicketID: .init(rawValue: "ticket-existing")
            ),
        ]
    }

    private func appliedWorkPackageFacts(_ store: DeliveryStore) async throws -> [String] {
        try await store.read { connection in
            try connection.rows(
                """
                SELECT 'phase' AS kind, id || '|' || name AS value FROM phases WHERE id = 'phase-next'
                UNION ALL SELECT 'goal', id || '|' || lifecycle FROM delivery_goals WHERE id = 'goal-next'
                UNION ALL SELECT 'ticket', id || '|' || phase_id || '|' || lane FROM tickets WHERE id = 'ticket-next'
                UNION ALL SELECT 'task', id || '|' || completion FROM ticket_tasks WHERE id = 'task-next'
                UNION ALL SELECT 'assignment', goal_id || '|' || ticket_id FROM delivery_goal_ticket_assignments WHERE ticket_id = 'ticket-next'
                UNION ALL SELECT 'phase-dependency', phase_id || '|' || depends_on_phase_id FROM phase_dependencies WHERE id = 'phase-dependency-next'
                UNION ALL SELECT 'ticket-dependency', ticket_id || '|' || depends_on_ticket_id FROM ticket_dependencies WHERE id = 'ticket-dependency-next'
                UNION ALL SELECT 'application', id FROM plan_change_proposal_applications WHERE id = 'application-package'
                ORDER BY kind, value
                """,
                maximum: 20
            ).map { row in
                guard case let .text(kind)? = row["kind"], case let .text(value)? = row["value"] else { return "invalid" }
                return "\(kind)|\(value)"
            }
        }
    }

    private func bindCurrentSource(
        to ticketID: String,
        linkID: String = "requirement-link",
        kind: TicketReferenceKind = .requirement,
        fixture: Fixture
    ) async throws -> URL {
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: fixture.root)
        let target = DocumentationTarget(
            projectID: fixture.registration.projectID.rawValue,
            rootID: "root-1",
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest
        )
        let bindingCount = try await fixture.store.read {
            try $0.scalarInt(
                "SELECT COUNT(*) FROM project_documentation_bindings WHERE project_id = 'proposal-project'"
            ) ?? 0
        }
        if bindingCount == 0 {
            let bound = await fixture.dispatcher.dispatch(envelope(
                fixture,
                requestID: UUID(),
                command: .bindDocumentationRepository(target: target)
            ))
            XCTAssertNil(bound.error)
        }
        let artifact = try XCTUnwrap(snapshot.catalog.artifacts.first { $0.artifactID == "current" })
        let source = fixture.root.appendingPathComponent(artifact.path)
        let linked = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(),
            command: .upsertTicketReference(
                target: target,
                ticketID: ticketID,
                linkID: linkID,
                kind: kind,
                artifactID: artifact.artifactID,
                sourceLocalID: "REQ-CURRENT",
                locator: nil,
                expectedContentDigest: documentationDigest(try Data(contentsOf: source)),
                expectedLinkSetRevision: 0
            )
        ))
        XCTAssertNil(linked.error)
        return source
    }

    private func proposalRecordCounts(_ store: DeliveryStore) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_decisions") ?? 0,
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_applications") ?? 0,
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? 0,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? 0,
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_tasks") ?? 0,
            ]
        }
    }

    private func planningGraph(_ store: DeliveryStore) async throws -> [[String: SQLiteValue]] {
        try await store.read { connection in
            try connection.rows(
                "SELECT 'phase' AS kind, id, name AS value FROM phases WHERE project_id = 'proposal-project' UNION ALL SELECT 'ticket', id, outcome FROM tickets WHERE project_id = 'proposal-project' ORDER BY kind, id",
                maximum: 100
            )
        }
    }
}

private actor PlanChangeProposalQueryGate {
    private var entered = false
    private var released = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func pause() async {
        entered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        guard !released else { return }
        await withCheckedContinuation { releaseContinuations.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func release() {
        released = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

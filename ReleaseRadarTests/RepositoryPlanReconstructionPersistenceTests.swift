import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RepositoryPlanReconstructionPersistenceTests: XCTestCase {
    func testPayloadAndReadbackBindImmutableCapturedProjectionWithoutLiveMutation() async throws {
        let fixture = try await ReconstructionFixture.make()
        let command = AgentCommand.saveRepositoryPlanReconstruction(
            proposalID: "proposal-101",
            expectedPreviousVersion: nil,
            rationale: "Capture an immutable reconstruction before owner application.",
            payload: fixture.payload
        )

        XCTAssertEqual(
            try JSONDecoder().decode(AgentCommand.self, from: JSONEncoder().encode(command)),
            command
        )
        XCTAssertEqual(fixture.payload.source.projectionBytes, fixture.projectionBytes)
        XCTAssertEqual(fixture.payload.source.projectionSHA256.count, 64)
    }

    func testApplicationAttemptPreservesExactEnvelopeIdentityForReplayAndRecovery() async throws {
        let fixture = try await ReconstructionFixture.make()
        let envelope = fixture.applyEnvelope(
            proposalID: "proposal-101",
            baselineDigest: String(repeating: "d", count: 64),
            decisionID: "decision-101",
            applicationID: "apply-101",
            requestID: UUID()
        )
        let bytes = try canonicalBytes(envelope)
        let attempt = RepositoryPlanReconstructionApplicationAttemptRecord(
            projectID: fixture.registration.projectID,
            proposalID: .init(rawValue: "proposal-101"),
            version: 1,
            applicationID: "apply-101",
            requestID: envelope.requestID,
            registration: fixture.registration,
            envelopeBytes: bytes,
            state: .pending,
            result: nil
        )

        XCTAssertEqual(attempt.requestID, envelope.requestID)
        XCTAssertEqual(attempt.envelopeBytes, bytes)
        XCTAssertEqual(attempt.state, .pending)
    }

    func testSuccessfulApplyCommitsOneHistoryEventAndExactReplayIsIdempotent() async throws {
        let fixture = try await ReconstructionFixture.make()
        let approved = try await fixture.saveAndApprove(proposalID: "proposal-success")
        let requestID = UUID()
        let envelope = fixture.applyEnvelope(
            proposalID: approved.proposalID,
            baselineDigest: approved.baselineDigest,
            decisionID: approved.decisionID,
            applicationID: "application-success",
            requestID: requestID
        )
        let before = try await fixture.counts(proposalID: approved.proposalID, requestID: requestID)

        let first = await fixture.dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        XCTAssertNil(first.error)
        let replay = await fixture.dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        XCTAssertEqual(replay, first)

        let destinationID = RepositoryPlanReconstructionIdentity.destinationID(
            source: fixture.payload.source,
            subject: fixture.payload.comparisons[0].subject
        )
        let after = try await fixture.counts(proposalID: approved.proposalID, requestID: requestID)
        XCTAssertEqual(after.auditEvents, before.auditEvents + 1)
        XCTAssertEqual(after.phases, before.phases + 1)
        XCTAssertEqual(after.provenance, before.provenance + 1)
        XCTAssertEqual(after.applications, before.applications + 1)
        XCTAssertEqual(after.attempts, before.attempts + 1)
        XCTAssertEqual(after.receipts, before.receipts + 1)
        let destinationCount = try await fixture.phaseCount(id: destinationID)
        XCTAssertEqual(destinationCount, 1)

        let readbacks = try await RepositoryPlanReconstructionQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID,
            proposalID: .init(rawValue: approved.proposalID)
        )
        let readback = try XCTUnwrap(readbacks.first)
        XCTAssertEqual(readback.payload, fixture.payload)
        XCTAssertEqual(readback.provenance.count, 1)
        XCTAssertEqual(readback.provenance.first?.comparison.destinationID, destinationID)
        XCTAssertEqual(readback.applicationAttempt?.state, .applied)
        XCTAssertEqual(readback.applicationAttempt?.requestID, requestID)
    }

    func testStaleDestinationRefusesApplyWithoutPartialGraphHistoryOrReceiptMutation() async throws {
        let fixture = try await ReconstructionFixture.make()
        let approved = try await fixture.saveAndApprove(proposalID: "proposal-stale-destination")
        try await fixture.store.transact(
            actor: .init(id: "fixture"),
            reason: "Advance the destination planning baseline after approval."
        ) { connection in
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "later-destination-phase"),
                name: "Later destination state",
                mode: .governed,
                connection: connection
            )
        }
        let requestID = UUID()
        let envelope = fixture.applyEnvelope(
            proposalID: approved.proposalID,
            baselineDigest: approved.baselineDigest,
            decisionID: approved.decisionID,
            applicationID: "application-stale-destination",
            requestID: requestID
        )
        let before = try await fixture.counts(proposalID: approved.proposalID, requestID: requestID)

        let result = await fixture.dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        guard case .planChangeProposalStale = result.error else {
            return XCTFail("Expected stale destination refusal, received \(String(describing: result.error))")
        }

        let after = try await fixture.counts(proposalID: approved.proposalID, requestID: requestID)
        XCTAssertEqual(after.auditEvents, before.auditEvents)
        XCTAssertEqual(after.phases, before.phases)
        XCTAssertEqual(after.provenance, before.provenance)
        XCTAssertEqual(after.applications, before.applications)
        XCTAssertEqual(after.receipts, before.receipts)
        XCTAssertEqual(after.attempts, before.attempts + 1)
        let attemptState = try await fixture.attemptState(proposalID: approved.proposalID)
        XCTAssertEqual(attemptState, .refused)
    }

    func testStaleSourceRefusesDecisionAndApplyWithoutPartialMutation() async throws {
        let fixture = try await ReconstructionFixture.make()
        let saved = try await fixture.save(proposalID: "proposal-stale-source")
        let sourceURL = fixture.root.appendingPathComponent("docs/plans/current.md")
        try Data("changed after capture".utf8).write(to: sourceURL)

        let decision = await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: saved.proposalID,
                    version: 1,
                    baselineDigest: saved.baselineDigest,
                    decisionID: "decision-stale-source",
                    disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(decision.error, .repositoryPlanReconstructionStaleSource)

        let requestID = UUID()
        let envelope = fixture.applyEnvelope(
            proposalID: saved.proposalID,
            baselineDigest: saved.baselineDigest,
            decisionID: "decision-stale-source",
            applicationID: "application-stale-source",
            requestID: requestID
        )
        let before = try await fixture.counts(proposalID: saved.proposalID, requestID: requestID)
        let applied = await fixture.dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        XCTAssertEqual(applied.error, .repositoryPlanReconstructionStaleSource)
        let after = try await fixture.counts(proposalID: saved.proposalID, requestID: requestID)

        XCTAssertEqual(after.auditEvents, before.auditEvents)
        XCTAssertEqual(after.phases, before.phases)
        XCTAssertEqual(after.provenance, before.provenance)
        XCTAssertEqual(after.applications, before.applications)
        XCTAssertEqual(after.receipts, before.receipts)
        XCTAssertEqual(after.attempts, before.attempts + 1)
        let decisionCount = try await fixture.decisionCount(proposalID: saved.proposalID)
        let attemptState = try await fixture.attemptState(proposalID: saved.proposalID)
        XCTAssertEqual(decisionCount, 0)
        XCTAssertEqual(attemptState, .refused)
    }

    func testDifferentApplyEnvelopeConflictsWithoutDuplicateRows() async throws {
        let fixture = try await ReconstructionFixture.make()
        let approved = try await fixture.saveAndApprove(proposalID: "proposal-conflict")
        let exact = fixture.applyEnvelope(
            proposalID: approved.proposalID,
            baselineDigest: approved.baselineDigest,
            decisionID: approved.decisionID,
            applicationID: "application-conflict",
            requestID: UUID()
        )
        let applied = await fixture.dispatcher.dispatchReconstructionApply(exact, origin: .ownerApp)
        XCTAssertNil(applied.error)
        let before = try await fixture.counts(proposalID: approved.proposalID, requestID: exact.requestID)
        let different = fixture.applyEnvelope(
            proposalID: approved.proposalID,
            baselineDigest: approved.baselineDigest,
            decisionID: approved.decisionID,
            applicationID: "different-application",
            requestID: UUID()
        )

        let conflict = await fixture.dispatcher.dispatchReconstructionApply(different, origin: .ownerApp)
        XCTAssertEqual(conflict.error, .repositoryPlanReconstructionApplicationAttemptConflict)
        let after = try await fixture.counts(proposalID: approved.proposalID, requestID: exact.requestID)
        XCTAssertEqual(after, before)
    }

    func testSourceMutationAtFinalScopedApplyBoundaryRollsBackAllDurableEffects() async throws {
        let fixture = try await ReconstructionFixture.make()
        let approved = try await fixture.saveAndApprove(proposalID: "proposal-final-source-race")
        let envelope = fixture.applyEnvelope(
            proposalID: approved.proposalID,
            baselineDigest: approved.baselineDigest,
            decisionID: approved.decisionID,
            applicationID: "application-final-source-race",
            requestID: UUID()
        )
        let before = try await fixture.counts(
            proposalID: approved.proposalID,
            requestID: envelope.requestID
        )
        let mutationStore = MutatingSecondAccessBookmarkStore(
            root: fixture.root,
            sourceURL: fixture.root.appendingPathComponent("docs/plans/current.md")
        )
        let dispatcher = fixture.dispatcher(bookmarkStore: mutationStore)

        let result = await dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)

        guard case .repositoryPlanReconstructionStaleSource = result.error else {
            return XCTFail("Expected final-boundary source mutation rejection, got \(String(describing: result.error))")
        }
        XCTAssertEqual(mutationStore.accessCount, 2)
        let after = try await fixture.counts(
            proposalID: approved.proposalID,
            requestID: envelope.requestID
        )
        XCTAssertEqual(after.auditEvents, before.auditEvents)
        XCTAssertEqual(after.phases, before.phases)
        XCTAssertEqual(after.provenance, before.provenance)
        XCTAssertEqual(after.applications, before.applications)
        XCTAssertEqual(after.receipts, before.receipts)
    }

    func testRelaunchRetriesExactPendingAttemptOnceAndThenReplaysDurableResult() async throws {
        let fixture = try await ReconstructionFixture.make()
        let approved = try await fixture.saveAndApprove(proposalID: "proposal-relaunch")
        let envelope = fixture.applyEnvelope(
            proposalID: approved.proposalID,
            baselineDigest: approved.baselineDigest,
            decisionID: approved.decisionID,
            applicationID: "application-relaunch",
            requestID: UUID()
        )
        try await fixture.insertPendingAttempt(envelope)
        let before = try await fixture.counts(proposalID: approved.proposalID, requestID: envelope.requestID)

        let relaunchedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let relaunchedDispatcher = fixture.dispatcher(store: relaunchedStore)
        let pendingReadbacks = try await RepositoryPlanReconstructionQuery.load(
            from: relaunchedStore,
            projectID: fixture.registration.projectID,
            proposalID: .init(rawValue: approved.proposalID)
        )
        let pendingReadback = try XCTUnwrap(pendingReadbacks.first)
        XCTAssertEqual(pendingReadback.applicationAttempt?.state, .pending)
        XCTAssertEqual(pendingReadback.payload, fixture.payload)

        let retry = await relaunchedDispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        XCTAssertNil(retry.error)
        let replay = await relaunchedDispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        XCTAssertEqual(replay, retry)

        let after = try await fixture.counts(proposalID: approved.proposalID, requestID: envelope.requestID)
        XCTAssertEqual(after.auditEvents, before.auditEvents + 1)
        XCTAssertEqual(after.phases, before.phases + 1)
        XCTAssertEqual(after.provenance, before.provenance + 1)
        XCTAssertEqual(after.applications, before.applications + 1)
        XCTAssertEqual(after.attempts, before.attempts)
        XCTAssertEqual(after.receipts, before.receipts + 1)
        let attemptState = try await fixture.attemptState(proposalID: approved.proposalID)
        XCTAssertEqual(attemptState, .applied)
    }

    func testCorrectedProjectionAppliesChosenValueAndRejectsStaleOrUnsupportedCorrections() async throws {
        let fixture = try await ReconstructionFixture.make()
        let subject = fixture.payload.comparisons[0].subject
        let correction = RepositoryPlanReconstructionCorrection(
            subject: subject,
            field: "name",
            sourceValue: try encoded("Imported phase"),
            chosenValue: try encoded("Owner-corrected phase")
        )
        let reviewed = fixture.projection(replacingPhaseName: "Owner-corrected phase")
        let source = try fixture.source(for: fixture.projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: reviewed,
            corrections: [correction],
            explicitMappings: [],
            from: fixture.store
        )
        XCTAssertEqual(preview.comparisons.map(\.disposition), [.new])
        XCTAssertTrue(preview.blockers.isEmpty)
        let payload = RepositoryPlanReconstructionPayload(
            source: source,
            reviewedProjection: reviewed,
            comparisons: preview.comparisons,
            corrections: [correction],
            exclusions: [],
            terminalEvidence: [],
            blockers: preview.blockers
        )
        let approved = try await fixture.saveAndApprove(
            proposalID: "proposal-corrected",
            payload: payload
        )
        let result = await fixture.dispatcher.dispatchReconstructionApply(
            fixture.applyEnvelope(
                proposalID: approved.proposalID,
                baselineDigest: approved.baselineDigest,
                decisionID: approved.decisionID,
                applicationID: "application-corrected",
                requestID: UUID()
            ),
            origin: .ownerApp
        )
        XCTAssertNil(result.error)
        let destinationID = try XCTUnwrap(preview.comparisons.first?.destinationID)
        let phaseName = try await fixture.phaseName(id: destinationID)
        XCTAssertEqual(phaseName, "Owner-corrected phase")

        for invalid in [
            RepositoryPlanReconstructionCorrection(
                subject: subject,
                field: "name",
                sourceValue: try encoded("stale source value"),
                chosenValue: try encoded("Owner-corrected phase")
            ),
            RepositoryPlanReconstructionCorrection(
                subject: subject,
                field: "unsupportedField",
                sourceValue: try encoded("Imported phase"),
                chosenValue: try encoded("Owner-corrected phase")
            ),
        ] {
            do {
                _ = try await RepositoryPlanReconstructionPreviewQuery.preview(
                    source: source,
                    reviewedProjection: reviewed,
                    corrections: [invalid],
                    explicitMappings: [],
                    from: fixture.store
                )
                XCTFail("Expected invalid correction rejection")
            } catch let error as RepositoryPlanReconstructionError {
                guard case .invalidPayload = error else {
                    return XCTFail("Unexpected correction error: \(error)")
                }
            }
        }
    }

    func testPreviewRequiresExplicitRawIDReuseAndClassifiesExactAndConflictingMappings() async throws {
        let absent = try await ReconstructionFixture.make()
        let absentPreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: absent.payload.source,
            reviewedProjection: absent.projection,
            corrections: [],
            explicitMappings: [],
            from: absent.store
        )
        XCTAssertEqual(absentPreview.comparisons.map(\.disposition), [.new])
        XCTAssertTrue(absentPreview.blockers.isEmpty)

        let fixture = try await ReconstructionFixture.make()
        try await fixture.seedPhase(id: "phase-101", name: "Imported phase")
        let rawCandidate = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: fixture.payload.source,
            reviewedProjection: fixture.projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        XCTAssertEqual(rawCandidate.comparisons.map(\.disposition), [.blocked])
        XCTAssertEqual(rawCandidate.blockers.map(\.code), ["raw_source_id_candidate"])

        let mapping = RepositoryPlanReconstructionMappingSelection(
            subject: fixture.payload.comparisons[0].subject,
            destinationID: "phase-101"
        )
        let exact = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: fixture.payload.source,
            reviewedProjection: fixture.projection,
            corrections: [],
            explicitMappings: [mapping],
            from: fixture.store
        )
        XCTAssertEqual(exact.comparisons.map(\.disposition), [.unchanged])
        XCTAssertTrue(exact.blockers.isEmpty)

        try await fixture.seedPhase(id: "phase-101", name: "Changed destination")
        let conflict = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: fixture.payload.source,
            reviewedProjection: fixture.projection,
            corrections: [],
            explicitMappings: [mapping],
            from: fixture.store
        )
        XCTAssertEqual(conflict.comparisons.map(\.disposition), [.conflicting])
        XCTAssertEqual(conflict.blockers.map(\.code), ["mapped_destination_conflict"])
    }

    func testOriginalTerminalEvidenceResolvesExactCapturedObjectAndRejectsFabricationOrBadJSON() async throws {
        let repositoryID = "9141d1ea-3342-4462-9e06-6934d816c03f"
        let goalRef = RepositoryPlanSourceReference.document(
            documentID: "state-document",
            locator: "/records/1"
        )
        let certificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [],
            goals: [.init(
                sourceGoalID: "goal-101",
                required: true,
                lifecycle: .accepted,
                remainingDebt: false
            )],
            obligations: [],
            deliveredBy: [.init(
                kind: .goal,
                phaseSourceID: "phase-101",
                sourceID: "goal-101",
                proofRef: goalRef
            )]
        )
        let record = RepositoryPlanStateRecord(
            recordID: "phase-completed-101",
            repositoryID: repositoryID,
            kind: .phaseLifecycle,
            subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
            state: .completed,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            actorID: "historical-owner",
            phaseCompletion: certificate
        )
        let goalRecord = RepositoryPlanStateRecord(
            recordID: "goal-accepted-101",
            repositoryID: repositoryID,
            kind: .goalAcceptance,
            subject: .goal(.init(phaseSourceID: "phase-101", sourceGoalID: "goal-101")),
            state: .accepted,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_001),
            actorID: "historical-owner",
            phaseCompletion: nil
        )
        let documentBytes = try stateRecordDocument([record, goalRecord])
        let fixture = try await ReconstructionFixture.make(capturedSourceBytes: documentBytes)
        let sourceRef = RepositoryPlanSourceReference.document(
            documentID: "state-document",
            locator: "/records/0"
        )
        let projection = fixture.projection(
            lifecycle: .completed,
            stateEvidence: [sourceRef],
            documentID: "state-document",
            documentDigest: sha256(documentBytes)
        )
        let source = try fixture.source(for: projection)
        let exact = try RepositoryPlanTerminalEvidenceResolver.original(
            sourceRef: sourceRef,
            source: source
        )
        XCTAssertEqual(exact, .original(sourceRef: sourceRef, record: record))
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let validPayload = RepositoryPlanReconstructionPayload(
            source: source,
            reviewedProjection: projection,
            comparisons: preview.comparisons,
            corrections: [],
            exclusions: [],
            terminalEvidence: [exact],
            blockers: preview.blockers
        )
        _ = try await fixture.save(proposalID: "proposal-exact-evidence", payload: validPayload)

        let fabricatedRecord = RepositoryPlanStateRecord(
            recordID: record.recordID,
            repositoryID: repositoryID,
            kind: .phaseLifecycle,
            subject: .phase(.init(sourceID: "phase-101", name: "Fabricated phase name")),
            state: .completed,
            occurredAt: record.occurredAt,
            actorID: record.actorID,
            phaseCompletion: certificate
        )
        let fabricated = RepositoryPlanReconstructionPayload(
            source: source,
            reviewedProjection: projection,
            comparisons: preview.comparisons,
            corrections: [],
            exclusions: [],
            terminalEvidence: [.original(sourceRef: sourceRef, record: fabricatedRecord)],
            blockers: preview.blockers
        )
        let rejected = await fixture.dispatcher.dispatch(fixture.envelope(
            requestID: UUID(),
            command: .saveRepositoryPlanReconstruction(
                proposalID: "proposal-fabricated-evidence",
                expectedPreviousVersion: nil,
                rationale: "Reject fabricated evidence.",
                payload: fabricated
            )
        ), origin: .ownerApp)
        guard case .invalidRepositoryPlanReconstruction = rejected.error else {
            return XCTFail("Expected fabricated evidence rejection, received \(String(describing: rejected.error))")
        }

        do {
            _ = try RepositoryPlanTerminalEvidenceResolver.original(
                sourceRef: .document(documentID: "state-document", locator: "/records/9"),
                source: source
            )
            XCTFail("Expected bad JSON pointer rejection")
        } catch let error as RepositoryPlanReconstructionError {
            guard case .invalidPayload = error else {
                return XCTFail("Unexpected pointer error: \(error)")
            }
        }

        let duplicateBytes = Data(
            "{\"records\":[{\"format\":\"release-radar.state-record\",\"format\":\"release-radar.state-record\"}]}".utf8
        )
        let duplicateFixture = try await ReconstructionFixture.make(
            capturedSourceBytes: duplicateBytes
        )
        let duplicateProjection = duplicateFixture.projection(
            lifecycle: .completed,
            stateEvidence: [sourceRef],
            documentID: "state-document",
            documentDigest: sha256(duplicateBytes)
        )
        let duplicateSource = try duplicateFixture.source(for: duplicateProjection)
        do {
            _ = try RepositoryPlanTerminalEvidenceResolver.original(
                sourceRef: sourceRef,
                source: duplicateSource
            )
            XCTFail("Expected duplicate-key JSON rejection")
        } catch let error as RepositoryPlanReconstructionError {
            guard case .invalidPayload = error else {
                return XCTFail("Unexpected duplicate-key error: \(error)")
            }
        }
    }

    func testTicketAcceptanceProofMatchesTaskDefinitionsAsUnorderedByteExactSet() async throws {
        let projectedTasks = [
            RepositoryPlanProjectionTask(
                sourceID: "task-a",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
                label: "A",
                title: "First task",
                sortOrder: 0,
                completion: .completed,
                lifecycle: .active,
                stateEvidence: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")]
            ),
            RepositoryPlanProjectionTask(
                sourceID: "task-b",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/1")],
                label: "B",
                title: "Second task",
                sortOrder: 1,
                completion: .completed,
                lifecycle: .active,
                stateEvidence: [.projection(pointer: "/tickets/0/taskPlan/tasks/1")]
            ),
        ]
        let snapshots = projectedTasks.map {
            RepositoryPlanStateTaskSnapshot(
                sourceID: $0.sourceID,
                label: $0.label,
                title: $0.title,
                sortOrder: $0.sortOrder,
                completion: $0.completion,
                lifecycle: $0.lifecycle
            )
        }

        let reversed = try await ticketAcceptanceEvidenceSave(
            proposalID: "proposal-reordered-task-proof",
            projectedTasks: projectedTasks,
            evidenceTasks: snapshots.reversed()
        )
        XCTAssertNil(reversed.error)

        let duplicate = try await ticketAcceptanceEvidenceSave(
            proposalID: "proposal-duplicate-task-proof",
            projectedTasks: projectedTasks,
            evidenceTasks: [snapshots[0], snapshots[0]]
        )
        guard case .invalidRepositoryPlanReconstruction = duplicate.error else {
            return XCTFail("Expected duplicate task proof rejection, got \(String(describing: duplicate.error))")
        }

        let composed = RepositoryPlanProjectionTask(
            sourceID: "task-\u{00e9}",
            authorityClass: .currentApproved,
            sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
            label: "Label \u{00e9}",
            title: "Title \u{00e9}",
            sortOrder: 0,
            completion: .completed,
            lifecycle: .active,
            stateEvidence: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")]
        )
        let byteDifferent = RepositoryPlanStateTaskSnapshot(
            sourceID: "task-e\u{0301}",
            label: "Label e\u{0301}",
            title: "Title e\u{0301}",
            sortOrder: 0,
            completion: .completed,
            lifecycle: .active
        )
        let unicode = try await ticketAcceptanceEvidenceSave(
            proposalID: "proposal-unicode-task-proof",
            projectedTasks: [composed],
            evidenceTasks: [byteDifferent]
        )
        guard case .invalidRepositoryPlanReconstruction = unicode.error else {
            return XCTFail("Expected byte-different Unicode task proof rejection, got \(String(describing: unicode.error))")
        }
    }

    func testOwnerAttestationRejectsClaimedOriginalMetadataAndMustMatchDecisionIdentity() async throws {
        let fixture = try await ReconstructionFixture.make()
        let evidenceRef = RepositoryPlanSourceReference.projection(pointer: "/phases/0")
        let projection = fixture.projection(
            from: fixture.projectionWithTicket(taskPlan: nil, lane: .accepted),
            lifecycle: .completed,
            stateEvidence: [evidenceRef]
        )
        let source = try fixture.source(for: projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let subject = RepositoryPlanStateSubject.phase(
            .init(sourceID: "phase-101", name: "Imported phase")
        )
        let certificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [.init(
                sourceTicketID: "ticket-101",
                lane: .accepted,
                acceptanceProof: nil
            )],
            goals: [],
            obligations: [],
            deliveredBy: [.init(
                kind: .ticket,
                phaseSourceID: "phase-101",
                sourceID: "ticket-101",
                proofRef: nil
            )]
        )
        func payload(_ attestation: RepositoryPlanOwnerAttestation) -> RepositoryPlanReconstructionPayload {
            let ticketAttestation = RepositoryPlanOwnerAttestation(
                id: "ticket-\(attestation.id)",
                subject: .ticket(.init(
                    sourceID: "ticket-101",
                    outcome: "Imported ticket",
                    phaseSourceID: "phase-101",
                    taskPlan: nil
                )),
                state: .accepted,
                phaseCompletion: nil,
                decisionID: attestation.decisionID,
                attestedAt: attestation.attestedAt,
                originalOccurredAt: nil,
                originalActorID: nil
            )
            return .init(
                source: source,
                reviewedProjection: projection,
                comparisons: preview.comparisons,
                corrections: [],
                exclusions: [],
                terminalEvidence: [
                    .ownerAttestation(attestation),
                    .ownerAttestation(ticketAttestation),
                ],
                blockers: preview.blockers
            )
        }

        let claimedOriginal = RepositoryPlanOwnerAttestation(
            id: "attestation-with-claimed-origin",
            subject: subject,
            state: .completed,
            phaseCompletion: certificate,
            decisionID: "decision-attestation",
            attestedAt: Date(),
            originalOccurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            originalActorID: "claimed-historical-actor"
        )
        let rejected = await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: "proposal-attestation-origin",
                    expectedPreviousVersion: nil,
                    rationale: "Reject owner claims about unavailable original metadata.",
                    payload: payload(claimedOriginal)
                )
            ),
            origin: .ownerApp
        )
        guard case .invalidRepositoryPlanReconstruction = rejected.error else {
            return XCTFail("Expected attestation metadata rejection, received \(String(describing: rejected.error))")
        }

        let mismatched = RepositoryPlanOwnerAttestation(
            id: "attestation-wrong-decision",
            subject: subject,
            state: .completed,
            phaseCompletion: certificate,
            decisionID: "different-decision",
            attestedAt: Date(),
            originalOccurredAt: nil,
            originalActorID: nil
        )
        let saved = try await fixture.save(
            proposalID: "proposal-attestation-decision",
            payload: payload(mismatched),
            origin: .ownerApp
        )
        let decision = await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: saved.proposalID,
                    version: 1,
                    baselineDigest: saved.baselineDigest,
                    decisionID: "actual-decision",
                    disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        guard case .invalidRepositoryPlanReconstruction = decision.error else {
            return XCTFail("Expected decision-bound attestation rejection, received \(String(describing: decision.error))")
        }
    }

    func testNonCurrentAuthorityCannotBecomeLiveWithoutExplicitEligibilityCorrection() async throws {
        let fixture = try await ReconstructionFixture.make()
        let historical = fixture.projection(authorityClass: .historical)
        let historicalSource = try fixture.source(for: historical)
        let historicalPreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: historicalSource,
            reviewedProjection: historical,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let historicalPayload = fixture.payload(
            source: historicalSource,
            reviewedProjection: historical,
            preview: historicalPreview
        )
        let historicalSave = await fixture.dispatcher.dispatch(fixture.envelope(
            requestID: UUID(),
            command: .saveRepositoryPlanReconstruction(
                proposalID: "proposal-historical-ordinary",
                expectedPreviousVersion: nil,
                rationale: "Historical context must not become live work automatically.",
                payload: historicalPayload
            )
        ))
        XCTAssertNotNil(
            historicalSave.error,
            "A historical phase classified as new must not enter the live plan through ordinary approval."
        )
        let historicalDestination = try XCTUnwrap(historicalPreview.comparisons[0].destinationID)
        let historicalDestinationCount = try await fixture.phaseCount(id: historicalDestination)
        XCTAssertEqual(historicalDestinationCount, 0)

        let subject = historicalPreview.comparisons[0].subject
        let correction = RepositoryPlanReconstructionCorrection(
            subject: subject,
            field: "authorityClass",
            sourceValue: try encoded(RepositoryPlanAuthorityClass.historical),
            chosenValue: try encoded(RepositoryPlanAuthorityClass.currentApproved)
        )
        let eligible = fixture.projection(authorityClass: .currentApproved)
        let eligiblePreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: historicalSource,
            reviewedProjection: eligible,
            corrections: [correction],
            explicitMappings: [],
            from: fixture.store
        )
        let eligiblePayload = fixture.payload(
            source: historicalSource,
            reviewedProjection: eligible,
            preview: eligiblePreview,
            corrections: [correction]
        )
        let approved = try await fixture.saveAndApprove(
            proposalID: "proposal-historical-corrected",
            payload: eligiblePayload
        )
        let applied = await fixture.dispatcher.dispatchReconstructionApply(
            fixture.applyEnvelope(
                proposalID: approved.proposalID,
                baselineDigest: approved.baselineDigest,
                decisionID: approved.decisionID,
                applicationID: "application-historical-corrected",
                requestID: UUID()
            ),
            origin: .ownerApp
        )
        XCTAssertNil(applied.error)
    }

    func testNewTaskPlanStartsAtRevisionOneWhileSourceRevisionRemainsInProvenance() async throws {
        let fixture = try await ReconstructionFixture.make()
        let projection = fixture.projectionWithTicketAndTasks(
            ticketLane: .backlog,
            sourceRevision: 42,
            tasks: [.init(
                sourceID: "task-101",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
                label: "Task 1",
                title: "Reconstruct the task",
                sortOrder: 0,
                completion: .pending,
                lifecycle: .active,
                stateEvidence: []
            )]
        )
        let source = try fixture.source(for: projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let payload = fixture.payload(source: source, reviewedProjection: projection, preview: preview)
        let approved = try await fixture.saveAndApprove(
            proposalID: "proposal-source-revision",
            payload: payload
        )
        let applied = await fixture.dispatcher.dispatchReconstructionApply(
            fixture.applyEnvelope(
                proposalID: approved.proposalID,
                baselineDigest: approved.baselineDigest,
                decisionID: approved.decisionID,
                applicationID: "application-source-revision",
                requestID: UUID()
            ),
            origin: .ownerApp
        )
        XCTAssertNil(applied.error)
        let ticketComparison = try XCTUnwrap(preview.comparisons.first { $0.kind == .ticket })
        let ticketID = try XCTUnwrap(ticketComparison.destinationID)
        let liveRevision = try await fixture.taskPlanRevision(ticketID: ticketID)
        XCTAssertEqual(liveRevision, 1)

        let readbacks = try await RepositoryPlanReconstructionQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID,
            proposalID: .init(rawValue: approved.proposalID)
        )
        let readback = try XCTUnwrap(readbacks.first)
        XCTAssertEqual(readback.payload.reviewedProjection.tickets[0].taskPlan?.sourceRevision, 42)
        let provenance = try XCTUnwrap(readback.provenance.first { $0.comparison.kind == .ticket })
        let retainedTicket = try JSONDecoder().decode(
            RepositoryPlanProjectionTicket.self,
            from: provenance.sourceFields
        )
        XCTAssertEqual(retainedTicket.taskPlan?.sourceRevision, 42)

        let repeatMappings = preview.comparisons.compactMap { comparison in
            comparison.destinationID.map {
                RepositoryPlanReconstructionMappingSelection(
                    subject: comparison.subject,
                    destinationID: $0
                )
            }
        }
        let repeated = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: repeatMappings,
            from: fixture.store
        )
        XCTAssertTrue(repeated.blockers.isEmpty)
        XCTAssertTrue(repeated.comparisons.allSatisfy { $0.disposition == .unchanged })
    }

    func testRepeatedReconstructionComparesMoreThanSixtyFourTasksWithoutTruncation() async throws {
        let fixture = try await ReconstructionFixture.make()
        let tasks = (0..<65).map { index in
            RepositoryPlanProjectionTask(
                sourceID: "task-\(index)",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/\(index)")],
                label: "T\(index)",
                title: "Task \(index)",
                sortOrder: index,
                completion: .pending,
                lifecycle: .active,
                stateEvidence: []
            )
        }
        let projection = fixture.projectionWithTicketAndTasks(
            ticketLane: .backlog,
            sourceRevision: 42,
            tasks: tasks
        )
        let source = try fixture.source(for: projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let approved = try await fixture.saveAndApprove(
            proposalID: "proposal-65-task-plan",
            payload: fixture.payload(source: source, reviewedProjection: projection, preview: preview)
        )
        let applied = await fixture.dispatcher.dispatchReconstructionApply(
            fixture.applyEnvelope(
                proposalID: approved.proposalID,
                baselineDigest: approved.baselineDigest,
                decisionID: approved.decisionID,
                applicationID: "application-65-task-plan",
                requestID: UUID()
            ),
            origin: .ownerApp
        )
        XCTAssertNil(applied.error)

        let mappings = preview.comparisons.compactMap { comparison in
            comparison.destinationID.map {
                RepositoryPlanReconstructionMappingSelection(
                    subject: comparison.subject,
                    destinationID: $0
                )
            }
        }
        let repeated = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: mappings,
            from: fixture.store
        )
        XCTAssertTrue(repeated.blockers.isEmpty)
        XCTAssertEqual(repeated.comparisons.filter { $0.kind == .task }.count, 65)
        XCTAssertTrue(repeated.comparisons.allSatisfy { $0.disposition == .unchanged })
    }

    func testBlockedDraftCanBeSavedAndRejectedAndExcludedHierarchyAppliesOnlyProvenance() async throws {
        let blockedFixture = try await ReconstructionFixture.make()
        let completed = blockedFixture.projection(
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")],
            documentID: nil,
            documentDigest: nil
        )
        let completedSource = try blockedFixture.source(for: completed)
        let subject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-101"
        )
        let blocker = RepositoryPlanReconstructionBlocker(
            code: "missing_terminal_proof",
            subject: subject,
            message: "Supply exact completion evidence before approval."
        )
        let blockedPayload = RepositoryPlanReconstructionPayload(
            source: completedSource,
            reviewedProjection: completed,
            comparisons: [.init(
                kind: .phase,
                parentSourceID: nil,
                sourceID: "phase-101",
                destinationID: nil,
                disposition: .blocked
            )],
            corrections: [],
            exclusions: [],
            terminalEvidence: [],
            blockers: [blocker]
        )
        let saved = await blockedFixture.dispatcher.dispatch(blockedFixture.envelope(
            requestID: UUID(),
            command: .saveRepositoryPlanReconstruction(
                proposalID: "proposal-blocked-draft",
                expectedPreviousVersion: nil,
                rationale: "Retain the blocked draft for owner resolution.",
                payload: blockedPayload
            )
        ), origin: .ownerApp)
        XCTAssertNil(saved.error)
        let baseline = try XCTUnwrap(saved.repositoryPlanReconstruction?.version.baselineDigest)
        let rejected = await blockedFixture.dispatcher.dispatch(
            blockedFixture.envelope(
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: "proposal-blocked-draft",
                    version: 1,
                    baselineDigest: baseline,
                    decisionID: "decision-reject-blocked",
                    disposition: .rejected
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(rejected.error)

        let excludedFixture = try await ReconstructionFixture.make()
        let excludedProjection = excludedFixture.projectionWithTicketAndTasks(
            ticketLane: .backlog,
            sourceRevision: 7,
            tasks: [.init(
                sourceID: "task-excluded",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
                label: "Excluded",
                title: "Excluded with its parent hierarchy",
                sortOrder: 0,
                completion: .pending,
                lifecycle: .active,
                stateEvidence: []
            )]
        )
        let excludedSource = try excludedFixture.source(for: excludedProjection)
        let subjects = [
            RepositoryPlanReconstructionSubject(kind: .phase, parentSourceID: nil, sourceID: "phase-101"),
            RepositoryPlanReconstructionSubject(kind: .ticket, parentSourceID: nil, sourceID: "ticket-101"),
            RepositoryPlanReconstructionSubject(kind: .task, parentSourceID: "ticket-101", sourceID: "task-excluded"),
        ]
        let comparisons = subjects.map {
            RepositoryPlanReconstructionComparison(
                kind: $0.kind,
                parentSourceID: $0.parentSourceID,
                sourceID: $0.sourceID,
                destinationID: nil,
                disposition: .excluded
            )
        }
        let excludedPayload = RepositoryPlanReconstructionPayload(
            source: excludedSource,
            reviewedProjection: excludedProjection,
            comparisons: comparisons,
            corrections: [],
            exclusions: subjects.map { .init(subject: $0, reason: "Owner excluded this context.") },
            terminalEvidence: [],
            blockers: []
        )
        let approved = try await excludedFixture.saveAndApprove(
            proposalID: "proposal-excluded-hierarchy",
            payload: excludedPayload
        )
        let applied = await excludedFixture.dispatcher.dispatchReconstructionApply(
            excludedFixture.applyEnvelope(
                proposalID: approved.proposalID,
                baselineDigest: approved.baselineDigest,
                decisionID: approved.decisionID,
                applicationID: "application-excluded-hierarchy",
                requestID: UUID()
            ),
            origin: .ownerApp
        )
        XCTAssertNil(applied.error)
        let graphCount = try await excludedFixture.graphRecordCount()
        let provenanceCount = try await excludedFixture.provenanceCount(
            proposalID: approved.proposalID
        )
        XCTAssertEqual(graphCount, 0)
        XCTAssertEqual(provenanceCount, 3)
    }

    func testExcludedParentCannotRetainIncludedChildTaskOrCreateProvenance() async throws {
        let fixture = try await ReconstructionFixture.make()
        let projection = fixture.projectionWithTicketAndTasks(
            ticketLane: .backlog,
            sourceRevision: 7,
            tasks: [.init(
                sourceID: "task-orphaned",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
                label: "Orphaned",
                title: "Must not outlive an excluded parent",
                sortOrder: 0,
                completion: .pending,
                lifecycle: .active,
                stateEvidence: []
            )]
        )
        let source = try fixture.source(for: projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let ticketSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-101"
        )
        let comparisons = preview.comparisons.map { comparison in
            comparison.subject == ticketSubject
                ? .init(
                    kind: comparison.kind,
                    parentSourceID: comparison.parentSourceID,
                    sourceID: comparison.sourceID,
                    destinationID: nil,
                    disposition: .excluded
                )
                : comparison
        }
        let payload = RepositoryPlanReconstructionPayload(
            source: source,
            reviewedProjection: projection,
            comparisons: comparisons,
            corrections: [],
            exclusions: [.init(
                subject: ticketSubject,
                reason: "Exclude only the parent to exercise graph coherence."
            )],
            terminalEvidence: [],
            blockers: preview.blockers
        )

        let save = await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: "proposal-orphaned-task",
                    expectedPreviousVersion: nil,
                    rationale: "An included task cannot survive an excluded parent ticket.",
                    payload: payload
                )
            ),
            origin: .ownerApp
        )
        guard case .invalidRepositoryPlanReconstruction = save.error else {
            return XCTFail("Expected orphaned task rejection, got \(String(describing: save.error))")
        }
        let graphCount = try await fixture.graphRecordCount()
        let provenanceCount = try await fixture.provenanceCount(
            proposalID: "proposal-orphaned-task"
        )
        XCTAssertEqual(graphCount, 0)
        XCTAssertEqual(provenanceCount, 0)
    }

    func testPreparationAcceptsImmediateReadyAdapterResult() async throws {
        let fixture = try await ReconstructionFixture.make()
        let request = fixture.preparationRequest(
            proposalID: "proposal-immediate-ready",
            attemptID: UUID()
        )
        let queued = try await RepositoryPlanPreparationPersistence.begin(
            request: request,
            requestID: UUID(),
            in: fixture.store
        )
        let ready = try await RepositoryPlanPreparationPersistence.record(
            identity: request.identity,
            expectedRevision: queued.revision,
            readback: .init(
                identity: request.identity,
                state: .readyForReview,
                threadID: "thread-immediate",
                turnID: "turn-immediate",
                draftBytes: fixture.projectionBytes,
                error: nil
            ),
            in: fixture.store
        )
        XCTAssertEqual(ready.state, .readyForReview)
        XCTAssertEqual(ready.revision, 2)
    }

    func testCompletedPhaseEvidenceRejectsEmptyOrFalseMembershipAndAcceptsDebtFreeSupersededGoal() async throws {
        let emptyFixture = try await ReconstructionFixture.make()
        let completed = emptyFixture.projection(
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")],
            documentID: nil,
            documentDigest: nil
        )
        let completedSource = try emptyFixture.source(for: completed)
        let completedPreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: completedSource,
            reviewedProjection: completed,
            corrections: [],
            explicitMappings: [],
            from: emptyFixture.store
        )
        let emptyCertificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [],
            goals: [],
            obligations: [],
            deliveredBy: []
        )
        let emptyAttestation = RepositoryPlanOwnerAttestation(
            id: "attestation-empty-completion",
            subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
            state: .completed,
            phaseCompletion: emptyCertificate,
            decisionID: "decision-empty-completion",
            attestedAt: Date(),
            originalOccurredAt: nil,
            originalActorID: nil
        )
        let emptyPayload = emptyFixture.payload(
            source: completedSource,
            reviewedProjection: completed,
            preview: completedPreview,
            terminalEvidence: [.ownerAttestation(emptyAttestation)]
        )
        let emptySave = await emptyFixture.dispatcher.dispatch(
            emptyFixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: "proposal-empty-completion",
                    expectedPreviousVersion: nil,
                    rationale: "Empty evidence must not prove a delivered phase.",
                    payload: emptyPayload
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNotNil(emptySave.error)

        let falseFixture = try await ReconstructionFixture.make()
        let backlogProjection = falseFixture.projectionWithTicket(taskPlan: nil, lane: .backlog)
        let falseCompleted = falseFixture.projection(
            from: backlogProjection,
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")]
        )
        let falseSource = try falseFixture.source(for: falseCompleted)
        let falsePreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: falseSource,
            reviewedProjection: falseCompleted,
            corrections: [],
            explicitMappings: [],
            from: falseFixture.store
        )
        let falseCertificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [.init(
                sourceTicketID: "ticket-101",
                lane: .accepted,
                acceptanceProof: .projection(pointer: "/does-not-prove-acceptance")
            )],
            goals: [],
            obligations: [],
            deliveredBy: []
        )
        let falseAttestation = RepositoryPlanOwnerAttestation(
            id: "attestation-false-member",
            subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
            state: .completed,
            phaseCompletion: falseCertificate,
            decisionID: "decision-false-member",
            attestedAt: Date(),
            originalOccurredAt: nil,
            originalActorID: nil
        )
        let falsePayload = falseFixture.payload(
            source: falseSource,
            reviewedProjection: falseCompleted,
            preview: falsePreview,
            terminalEvidence: [.ownerAttestation(falseAttestation)]
        )
        let falseSave = await falseFixture.dispatcher.dispatch(
            falseFixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: "proposal-false-member",
                    expectedPreviousVersion: nil,
                    rationale: "A certificate label cannot override the projected backlog lane.",
                    payload: falsePayload
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNotNil(falseSave.error)

        let supersededFixture = try await ReconstructionFixture.make()
        let supersededProjection = supersededFixture.projection(
            from: supersededFixture.projectionWithTicket(taskPlan: nil, lane: .accepted),
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")]
        )
        let supersededSource = try supersededFixture.source(for: supersededProjection)
        let supersededPreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: supersededSource,
            reviewedProjection: supersededProjection,
            corrections: [],
            explicitMappings: [],
            from: supersededFixture.store
        )
        let supersededCertificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [.init(
                sourceTicketID: "ticket-101",
                lane: .accepted,
                acceptanceProof: nil
            )],
            goals: [.init(
                sourceGoalID: "goal-superseded",
                required: true,
                lifecycle: .superseded,
                remainingDebt: false
            )],
            obligations: [],
            deliveredBy: [.init(
                kind: .ticket,
                phaseSourceID: "phase-101",
                sourceID: "ticket-101",
                proofRef: nil
            )]
        )
        let supersededDecisionID = "decision-superseded-goal"
        let supersededAttestation = RepositoryPlanOwnerAttestation(
            id: "attestation-superseded-goal",
            subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
            state: .completed,
            phaseCompletion: supersededCertificate,
            decisionID: supersededDecisionID,
            attestedAt: Date(),
            originalOccurredAt: nil,
            originalActorID: nil
        )
        let supersededPayload = supersededFixture.payload(
            source: supersededSource,
            reviewedProjection: supersededProjection,
            preview: supersededPreview,
            terminalEvidence: [
                .ownerAttestation(supersededAttestation),
                .ownerAttestation(.init(
                    id: "attestation-superseded-credit-ticket",
                    subject: .ticket(.init(
                        sourceID: "ticket-101",
                        outcome: "Imported ticket",
                        phaseSourceID: "phase-101",
                        taskPlan: nil
                    )),
                    state: .accepted,
                    phaseCompletion: nil,
                    decisionID: supersededDecisionID,
                    attestedAt: Date(),
                    originalOccurredAt: nil,
                    originalActorID: nil
                )),
            ]
        )
        let supersededSave = await supersededFixture.dispatcher.dispatch(
            supersededFixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: "proposal-superseded-goal",
                    expectedPreviousVersion: nil,
                    rationale: "A required superseded goal is complete when no debt remains.",
                    payload: supersededPayload
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(supersededSave.error)
    }

    func testCompletedPhaseAcceptsPolicyBAttestationCrossPhaseCreditAndDebtFreeSupersededGoal() async throws {
        let fixture = try await ReconstructionFixture.make()
        let accepted = fixture.projectionWithTicket(taskPlan: nil, lane: .accepted)
        let firstCompleted = fixture.projection(
            from: accepted,
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")]
        )
        let completed = RepositoryPlanProjection(
            format: firstCompleted.format,
            schemaVersion: firstCompleted.schemaVersion,
            repositoryID: firstCompleted.repositoryID,
            projectionID: firstCompleted.projectionID,
            projectionRevision: firstCompleted.projectionRevision,
            documents: firstCompleted.documents,
            phases: firstCompleted.phases + [.init(
                sourceID: "phase-202",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/phases/1")],
                name: "Follow-up phase",
                lifecycle: .upcoming,
                stateEvidence: []
            )],
            tickets: firstCompleted.tickets + [.init(
                sourceID: "ticket-202",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/1")],
                outcome: "Follow-up delivered ticket",
                phaseSourceID: "phase-202",
                lane: .accepted,
                taskPlan: nil,
                stateEvidence: [.projection(pointer: "/tickets/1")],
                evidenceRefs: []
            )],
            phaseDependencies: [],
            ticketDependencies: []
        )
        let source = try fixture.source(for: completed)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: completed,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let decisionID = "decision-policy-b-completion"
        let certificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [.init(
                sourceTicketID: "ticket-101",
                lane: .accepted,
                acceptanceProof: nil
            )],
            goals: [
                .init(
                    sourceGoalID: "goal-credit",
                    required: true,
                    lifecycle: .accepted,
                    remainingDebt: false
                ),
                .init(
                    sourceGoalID: "goal-superseded",
                    required: true,
                    lifecycle: .superseded,
                    remainingDebt: false
                ),
            ],
            obligations: [.init(
                sourceObligationID: "obligation-cross-phase",
                disposition: .fulfilled,
                descendants: [.init(
                    kind: .ticket,
                    phaseSourceID: "phase-202",
                    sourceID: "ticket-202",
                    proofRef: nil
                )]
            )],
            deliveredBy: [.init(
                kind: .goal,
                phaseSourceID: "phase-101",
                sourceID: "goal-credit",
                proofRef: nil
            )]
        )
        let terminalEvidence: [RepositoryPlanTerminalEvidence] = [
            .ownerAttestation(.init(
                id: "attestation-policy-b-phase",
                subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
                state: .completed,
                phaseCompletion: certificate,
                decisionID: decisionID,
                attestedAt: Date(),
                originalOccurredAt: nil,
                originalActorID: nil
            )),
            .ownerAttestation(.init(
                id: "attestation-policy-b-ticket",
                subject: .ticket(.init(
                    sourceID: "ticket-101",
                    outcome: "Imported ticket",
                    phaseSourceID: "phase-101",
                    taskPlan: nil
                )),
                state: .accepted,
                phaseCompletion: nil,
                decisionID: decisionID,
                attestedAt: Date(),
                originalOccurredAt: nil,
                originalActorID: nil
            )),
            .ownerAttestation(.init(
                id: "attestation-policy-b-descendant-ticket",
                subject: .ticket(.init(
                    sourceID: "ticket-202",
                    outcome: "Follow-up delivered ticket",
                    phaseSourceID: "phase-202",
                    taskPlan: nil
                )),
                state: .accepted,
                phaseCompletion: nil,
                decisionID: decisionID,
                attestedAt: Date(),
                originalOccurredAt: nil,
                originalActorID: nil
            )),
            .ownerAttestation(.init(
                id: "attestation-policy-b-goal-credit",
                subject: .goal(.init(
                    phaseSourceID: "phase-101",
                    sourceGoalID: "goal-credit"
                )),
                state: .accepted,
                phaseCompletion: nil,
                decisionID: decisionID,
                attestedAt: Date(),
                originalOccurredAt: nil,
                originalActorID: nil
            )),
        ]
        let saved = try await fixture.save(
            proposalID: "proposal-policy-b-completion",
            payload: fixture.payload(
                source: source,
                reviewedProjection: completed,
                preview: preview,
                terminalEvidence: terminalEvidence
            )
        )
        let decided = await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: saved.proposalID,
                    version: 1,
                    baselineDigest: saved.baselineDigest,
                    decisionID: decisionID,
                    disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(decided.error)
        let applied = await fixture.dispatcher.dispatchReconstructionApply(
            fixture.applyEnvelope(
                proposalID: saved.proposalID,
                baselineDigest: saved.baselineDigest,
                decisionID: decisionID,
                applicationID: "application-policy-b-completion",
                requestID: UUID()
            ),
            origin: .ownerApp
        )
        XCTAssertNil(applied.error)
    }

    func testCompletedPhaseRejectsInvalidNestedCreditAndIncompleteObligations() async throws {
        let goalRef = RepositoryPlanSourceReference.document(
            documentID: "goal-records",
            locator: "/records/0"
        )
        let invalidGoalRecord = RepositoryPlanStateRecord(
            format: "foreign.state-record",
            schemaVersion: 9,
            recordID: "foreign-goal",
            repositoryID: "00000000-0000-4000-8000-000000000999",
            kind: .goalAcceptance,
            subject: .goal(.init(phaseSourceID: "phase-101", sourceGoalID: "goal-101")),
            state: .accepted,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            actorID: "foreign-owner",
            phaseCompletion: nil
        )
        let invalidBytes = try stateRecordDocument(invalidGoalRecord)
        let invalidFixture = try await ReconstructionFixture.make(capturedSourceBytes: invalidBytes)
        let invalidProjection = invalidFixture.projection(
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")],
            documentID: "goal-records",
            documentDigest: sha256(invalidBytes)
        )
        let invalidSource = try invalidFixture.source(for: invalidProjection)
        let invalidPreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: invalidSource,
            reviewedProjection: invalidProjection,
            corrections: [],
            explicitMappings: [],
            from: invalidFixture.store
        )
        let invalidCertificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [],
            goals: [.init(
                sourceGoalID: "goal-101",
                required: true,
                lifecycle: .accepted,
                remainingDebt: false
            )],
            obligations: [],
            deliveredBy: [.init(
                kind: .goal,
                phaseSourceID: "phase-101",
                sourceID: "goal-101",
                proofRef: goalRef
            )]
        )
        let invalidPayload = invalidFixture.payload(
            source: invalidSource,
            reviewedProjection: invalidProjection,
            preview: invalidPreview,
            terminalEvidence: [.ownerAttestation(.init(
                id: "attestation-invalid-nested-proof",
                subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
                state: .completed,
                phaseCompletion: invalidCertificate,
                decisionID: "decision-invalid-nested-proof",
                attestedAt: Date(),
                originalOccurredAt: nil,
                originalActorID: nil
            ))]
        )
        let invalidSave = await invalidFixture.dispatcher.dispatch(
            invalidFixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: "proposal-invalid-nested-proof",
                    expectedPreviousVersion: nil,
                    rationale: "Reject foreign or unsupported nested goal proof.",
                    payload: invalidPayload
                )
            ),
            origin: .ownerApp
        )
        guard case .invalidRepositoryPlanReconstruction = invalidSave.error else {
            return XCTFail("Expected invalid nested proof rejection, got \(String(describing: invalidSave.error))")
        }

        let obligationFixture = try await ReconstructionFixture.make()
        let accepted = obligationFixture.projectionWithTicket(taskPlan: nil, lane: .accepted)
        let completed = obligationFixture.projection(
            from: accepted,
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")]
        )
        let source = try obligationFixture.source(for: completed)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: completed,
            corrections: [],
            explicitMappings: [],
            from: obligationFixture.store
        )
        let decisionID = "decision-empty-descendants"
        let incomplete = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [.init(sourceTicketID: "ticket-101", lane: .accepted, acceptanceProof: nil)],
            goals: [],
            obligations: [.init(
                sourceObligationID: "obligation-empty",
                disposition: .fulfilled,
                descendants: []
            )],
            deliveredBy: [.init(
                kind: .ticket,
                phaseSourceID: "phase-101",
                sourceID: "ticket-101",
                proofRef: nil
            )]
        )
        let evidence: [RepositoryPlanTerminalEvidence] = [
            .ownerAttestation(.init(
                id: "attestation-empty-descendants-phase",
                subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
                state: .completed,
                phaseCompletion: incomplete,
                decisionID: decisionID,
                attestedAt: Date(),
                originalOccurredAt: nil,
                originalActorID: nil
            )),
            .ownerAttestation(.init(
                id: "attestation-empty-descendants-ticket",
                subject: .ticket(.init(
                    sourceID: "ticket-101",
                    outcome: "Imported ticket",
                    phaseSourceID: "phase-101",
                    taskPlan: nil
                )),
                state: .accepted,
                phaseCompletion: nil,
                decisionID: decisionID,
                attestedAt: Date(),
                originalOccurredAt: nil,
                originalActorID: nil
            )),
        ]
        let incompleteSave = await obligationFixture.dispatcher.dispatch(
            obligationFixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: "proposal-empty-descendants",
                    expectedPreviousVersion: nil,
                    rationale: "Fulfilled obligations require delivered descendants.",
                    payload: obligationFixture.payload(
                        source: source,
                        reviewedProjection: completed,
                        preview: preview,
                        terminalEvidence: evidence
                    )
                )
            ),
            origin: .ownerApp
        )
        guard case .invalidRepositoryPlanReconstruction = incompleteSave.error else {
            return XCTFail("Expected empty descendant rejection, got \(String(describing: incompleteSave.error))")
        }
    }

    func testCompletedPhaseAcceptsExactDestinationGoalAndDirectDeliveredObligation() async throws {
        let fixture = try await ReconstructionFixture.make()
        try await fixture.seedExactCompletedDestination(.directDeliveredGoal)
        let projection = fixture.exactCompletedProjection(ticketIDs: ["ticket-101"])
        let source = try fixture.source(for: projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: fixture.exactMappings(ticketIDs: ["ticket-101"]),
            from: fixture.store
        )
        XCTAssertTrue(preview.blockers.isEmpty)
        XCTAssertTrue(preview.comparisons.allSatisfy { $0.disposition == .unchanged })

        let decisionID = "decision-exact-goal-direct-obligation"
        let certificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [.init(sourceTicketID: "ticket-101", lane: .accepted, acceptanceProof: nil)],
            goals: [.init(
                sourceGoalID: "goal-101",
                required: true,
                lifecycle: .accepted,
                remainingDebt: false
            )],
            obligations: [],
            deliveredBy: [.init(
                kind: .goal,
                phaseSourceID: "phase-101",
                sourceID: "goal-101",
                proofRef: nil
            )]
        )
        let phaseAttestation = RepositoryPlanOwnerAttestation(
            id: "attestation-exact-goal-direct-obligation",
            subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
            state: .completed,
            phaseCompletion: certificate,
            decisionID: decisionID,
            attestedAt: Date(),
            originalOccurredAt: nil,
            originalActorID: nil
        )
        let saved = try await fixture.save(
            proposalID: "proposal-exact-goal-direct-obligation",
            payload: fixture.payload(
                source: source,
                reviewedProjection: projection,
                preview: preview,
                terminalEvidence: [.ownerAttestation(phaseAttestation)]
            )
        )
        let approved = await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: saved.proposalID,
                    version: 1,
                    baselineDigest: saved.baselineDigest,
                    decisionID: decisionID,
                    disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(approved.error)
    }

    func testCompletedPhaseRejectsUnresolvedAndCyclicLiveObligations() async throws {
        for (seed, ticketIDs, goalIDs, suffix) in [
            (ExactCompletedDestinationSeed.unresolvedObligation, ["ticket-101"], ["goal-101"], "unresolved"),
            (.cyclicObligations, ["ticket-101", "ticket-202"], ["goal-101", "goal-202"], "cyclic"),
        ] {
            let fixture = try await ReconstructionFixture.make()
            try await fixture.seedExactCompletedDestination(seed)
            let projection = fixture.exactCompletedProjection(ticketIDs: ticketIDs)
            let source = try fixture.source(for: projection)
            let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
                source: source,
                reviewedProjection: projection,
                corrections: [],
                explicitMappings: fixture.exactMappings(ticketIDs: ticketIDs),
                from: fixture.store
            )
            let decisionID = "decision-\(suffix)-obligation"
            let certificate = RepositoryPlanPhaseCompletionCertificate(
                membershipComplete: true,
                tickets: ticketIDs.map {
                    .init(sourceTicketID: $0, lane: .accepted, acceptanceProof: nil)
                },
                goals: goalIDs.map {
                    .init(sourceGoalID: $0, required: true, lifecycle: .accepted, remainingDebt: false)
                },
                obligations: [],
                deliveredBy: [.init(
                    kind: .ticket,
                    phaseSourceID: "phase-101",
                    sourceID: "ticket-101",
                    proofRef: nil
                )]
            )
            let payload = fixture.payload(
                source: source,
                reviewedProjection: projection,
                preview: preview,
                terminalEvidence: [.ownerAttestation(.init(
                    id: "attestation-\(suffix)-obligation",
                    subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
                    state: .completed,
                    phaseCompletion: certificate,
                    decisionID: decisionID,
                    attestedAt: Date(),
                    originalOccurredAt: nil,
                    originalActorID: nil
                ))]
            )
            let saved = await fixture.dispatcher.dispatch(
                fixture.envelope(
                    requestID: UUID(),
                    command: .saveRepositoryPlanReconstruction(
                        proposalID: "proposal-\(suffix)-obligation",
                        expectedPreviousVersion: nil,
                        rationale: "Reject incomplete live obligation coverage.",
                        payload: payload
                    )
                ),
                origin: .ownerApp
            )
            guard case .invalidRepositoryPlanReconstruction = saved.error else {
                return XCTFail("Expected \(suffix) obligation rejection, got \(String(describing: saved.error))")
            }
        }
    }

    func testCompletedPhaseIgnoresRetiredDestinationTicketMembership() async throws {
        let fixture = try await ReconstructionFixture.make()
        try await fixture.seedExactCompletedDestination(.retiredExtraTicket)
        let projection = fixture.exactCompletedProjection(ticketIDs: ["ticket-101"])
        let source = try fixture.source(for: projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: fixture.exactMappings(ticketIDs: ["ticket-101"]),
            from: fixture.store
        )
        XCTAssertTrue(preview.blockers.isEmpty)
        let decisionID = "decision-retired-destination-member"
        let certificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [.init(sourceTicketID: "ticket-101", lane: .accepted, acceptanceProof: nil)],
            goals: [],
            obligations: [],
            deliveredBy: [.init(
                kind: .ticket,
                phaseSourceID: "phase-101",
                sourceID: "ticket-101",
                proofRef: nil
            )]
        )
        let saved = try await fixture.save(
            proposalID: "proposal-retired-destination-member",
            payload: fixture.payload(
                source: source,
                reviewedProjection: projection,
                preview: preview,
                terminalEvidence: [.ownerAttestation(.init(
                    id: "attestation-retired-destination-member",
                    subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
                    state: .completed,
                    phaseCompletion: certificate,
                    decisionID: decisionID,
                    attestedAt: Date(),
                    originalOccurredAt: nil,
                    originalActorID: nil
                ))]
            )
        )
        let approved = await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: saved.proposalID,
                    version: 1,
                    baselineDigest: saved.baselineDigest,
                    decisionID: decisionID,
                    disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(approved.error)
    }

    func testCompletedPhaseRejectsUndeclaredGoalCreditAndOptionalDebt() async throws {
        let fixture = try await ReconstructionFixture.make()
        let projection = fixture.projection(
            from: fixture.projectionWithTicket(taskPlan: nil, lane: .accepted),
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")]
        )
        let source = try fixture.source(for: projection)
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let credit = RepositoryPlanPhaseCompletionReference(
            kind: .goal,
            phaseSourceID: "phase-101",
            sourceID: "goal-credit",
            proofRef: nil
        )
        let cases: [(String, RepositoryPlanPhaseCompletionCertificate)] = [
            ("undeclared", .init(
                membershipComplete: true,
                tickets: [.init(sourceTicketID: "ticket-101", lane: .accepted, acceptanceProof: nil)],
                goals: [],
                obligations: [],
                deliveredBy: [credit]
            )),
            ("optional-debt", .init(
                membershipComplete: true,
                tickets: [.init(sourceTicketID: "ticket-101", lane: .accepted, acceptanceProof: nil)],
                goals: [
                    .init(sourceGoalID: "goal-credit", required: true, lifecycle: .accepted, remainingDebt: false),
                    .init(sourceGoalID: "goal-optional-debt", required: false, lifecycle: .superseded, remainingDebt: true),
                ],
                obligations: [],
                deliveredBy: [credit]
            )),
        ]
        for (suffix, certificate) in cases {
            let decisionID = "decision-\(suffix)-goal"
            let evidence: [RepositoryPlanTerminalEvidence] = [
                .ownerAttestation(.init(
                    id: "phase-\(suffix)",
                    subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
                    state: .completed,
                    phaseCompletion: certificate,
                    decisionID: decisionID,
                    attestedAt: Date(),
                    originalOccurredAt: nil,
                    originalActorID: nil
                )),
                .ownerAttestation(.init(
                    id: "ticket-\(suffix)",
                    subject: .ticket(.init(
                        sourceID: "ticket-101",
                        outcome: "Imported ticket",
                        phaseSourceID: "phase-101",
                        taskPlan: nil
                    )),
                    state: .accepted,
                    phaseCompletion: nil,
                    decisionID: decisionID,
                    attestedAt: Date(),
                    originalOccurredAt: nil,
                    originalActorID: nil
                )),
                .ownerAttestation(.init(
                    id: "goal-\(suffix)",
                    subject: .goal(.init(phaseSourceID: "phase-101", sourceGoalID: "goal-credit")),
                    state: .accepted,
                    phaseCompletion: nil,
                    decisionID: decisionID,
                    attestedAt: Date(),
                    originalOccurredAt: nil,
                    originalActorID: nil
                )),
            ]
            let result = await fixture.dispatcher.dispatch(
                fixture.envelope(
                    requestID: UUID(),
                    command: .saveRepositoryPlanReconstruction(
                        proposalID: "proposal-\(suffix)-goal",
                        expectedPreviousVersion: nil,
                        rationale: "Reject incomplete completed-phase goal evidence.",
                        payload: fixture.payload(
                            source: source,
                            reviewedProjection: projection,
                            preview: preview,
                            terminalEvidence: evidence
                        )
                    )
                ),
                origin: .ownerApp
            )
            guard case .invalidRepositoryPlanReconstruction = result.error else {
                return XCTFail("Expected \(suffix) goal rejection, got \(String(describing: result.error))")
            }
        }
    }

    func testMappedDestinationWithExtraTaskIsConflictingAndCompletedPhaseCannotReceiveNewTicket() async throws {
        let fixture = try await ReconstructionFixture.make()
        try await fixture.seedMappedTicketWithExtraTask()
        let projection = fixture.projectionWithTicket(taskPlan: nil, lane: .backlog)
        let source = try fixture.source(for: projection)
        let phaseSubject = RepositoryPlanReconstructionSubject(
            kind: .phase, parentSourceID: nil, sourceID: "phase-101"
        )
        let ticketSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket, parentSourceID: nil, sourceID: "ticket-101"
        )
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [
                .init(subject: phaseSubject, destinationID: "mapped-phase"),
                .init(subject: ticketSubject, destinationID: "mapped-ticket"),
            ],
            from: fixture.store
        )
        XCTAssertEqual(
            preview.comparisons.first { $0.kind == .ticket }?.disposition,
            .conflicting
        )
        XCTAssertTrue(preview.blockers.contains { $0.code == "mapped_destination_conflict" })

        try await fixture.markPhaseCompleted(id: "mapped-phase")
        let newTicketProjection = fixture.projectionWithTicket(taskPlan: nil, lane: .backlog)
        let completedProjection = fixture.projection(
            from: newTicketProjection,
            lifecycle: .completed,
            stateEvidence: [.projection(pointer: "/phases/0")]
        )
        let completedSource = try fixture.source(for: completedProjection)
        let completedPreview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: completedSource,
            reviewedProjection: completedProjection,
            corrections: [],
            explicitMappings: [.init(subject: phaseSubject, destinationID: "mapped-phase")],
            from: fixture.store
        )
        XCTAssertEqual(
            completedPreview.comparisons.first { $0.kind == .ticket }?.disposition,
            .blocked
        )
    }

    func testPreparationRevisionCASAndTerminalReplacementOwnership() async throws {
        let fixture = try await ReconstructionFixture.make()
        let request = fixture.preparationRequest(
            proposalID: "proposal-preparation-cas",
            attemptID: UUID()
        )
        let queued = try await RepositoryPlanPreparationPersistence.begin(
            request: request,
            requestID: UUID(),
            in: fixture.store
        )
        XCTAssertEqual(queued.revision, 1)
        XCTAssertEqual(queued.state, .queued)
        let running = try await RepositoryPlanPreparationPersistence.record(
            identity: request.identity,
            expectedRevision: 1,
            readback: .init(
                identity: request.identity,
                state: .running,
                threadID: "thread-101",
                turnID: "turn-101",
                draftBytes: nil,
                error: nil
            ),
            in: fixture.store
        )
        XCTAssertEqual(running.revision, 2)

        do {
            _ = try await RepositoryPlanPreparationPersistence.record(
                identity: request.identity,
                expectedRevision: 1,
                readback: .init(
                    identity: request.identity,
                    state: .failed,
                    threadID: nil,
                    turnID: nil,
                    draftBytes: nil,
                    error: "late failure"
                ),
                in: fixture.store
            )
            XCTFail("Expected revision conflict")
        } catch let error as RepositoryPlanReconstructionError {
            XCTAssertEqual(error, .preparationRevisionConflict(expected: 1, current: 2))
        }

        let unknown = try await RepositoryPlanPreparationPersistence.record(
            identity: request.identity,
            expectedRevision: 2,
            readback: .init(
                identity: request.identity,
                state: .outcomeUnknown,
                threadID: "thread-101",
                turnID: "turn-101",
                draftBytes: nil,
                error: "Interrupted before a durable outcome was observed."
            ),
            in: fixture.store
        )
        XCTAssertEqual(unknown.revision, 3)
        XCTAssertEqual(unknown.state, .outcomeUnknown)

        do {
            _ = try await RepositoryPlanPreparationPersistence.begin(
                request: fixture.preparationRequest(
                    proposalID: "proposal-preparation-cas",
                    attemptID: UUID()
                ),
                requestID: UUID(),
                in: fixture.store
            )
            XCTFail("Expected outcome-unknown replacement refusal")
        } catch let error as RepositoryPlanReconstructionError {
            XCTAssertEqual(error, .preparationConflict)
        }

        let reconciled = try await RepositoryPlanPreparationPersistence.record(
            identity: request.identity,
            expectedRevision: 3,
            readback: .init(
                identity: request.identity,
                state: .failed,
                threadID: nil,
                turnID: nil,
                draftBytes: nil,
                error: "Reconciliation confirmed that the attempt ended without a draft."
            ),
            in: fixture.store
        )
        XCTAssertEqual(reconciled.revision, 4)
        XCTAssertEqual(reconciled.state, .failed)

        let reconciledReplacement = try await RepositoryPlanPreparationPersistence.begin(
            request: fixture.preparationRequest(
                proposalID: "proposal-preparation-cas",
                attemptID: UUID()
            ),
            requestID: UUID(),
            in: fixture.store
        )
        XCTAssertEqual(reconciledReplacement.state, .queued)
        XCTAssertTrue(reconciledReplacement.isCurrent)

        for (index, terminal) in [
            RepositoryPlanPreparationState.readyForReview,
            .failed,
            .cancelled,
        ].enumerated() {
            let proposalID = "proposal-terminal-\(index)"
            let original = fixture.preparationRequest(proposalID: proposalID, attemptID: UUID())
            _ = try await RepositoryPlanPreparationPersistence.begin(
                request: original,
                requestID: UUID(),
                in: fixture.store
            )
            var expectedRevision: Int64 = 1
            if terminal == .readyForReview {
                _ = try await RepositoryPlanPreparationPersistence.record(
                    identity: original.identity,
                    expectedRevision: expectedRevision,
                    readback: .init(
                        identity: original.identity,
                        state: .running,
                        threadID: "thread-ready",
                        turnID: "turn-ready",
                        draftBytes: nil,
                        error: nil
                    ),
                    in: fixture.store
                )
                expectedRevision = 2
            }
            _ = try await RepositoryPlanPreparationPersistence.record(
                identity: original.identity,
                expectedRevision: expectedRevision,
                readback: .init(
                    identity: original.identity,
                    state: terminal,
                    threadID: nil,
                    turnID: nil,
                    draftBytes: terminal == .readyForReview ? fixture.projectionBytes : nil,
                    error: terminal == .failed ? "bounded failure" : nil
                ),
                in: fixture.store
            )
            let replacement = fixture.preparationRequest(proposalID: proposalID, attemptID: UUID())
            let replacementRecord = try await RepositoryPlanPreparationPersistence.begin(
                request: replacement,
                requestID: UUID(),
                in: fixture.store
            )
            XCTAssertEqual(replacementRecord.state, .queued)
            XCTAssertTrue(replacementRecord.isCurrent)

            do {
                _ = try await RepositoryPlanPreparationPersistence.record(
                    identity: original.identity,
                    expectedRevision: expectedRevision + 2,
                    readback: .init(
                        identity: original.identity,
                        state: terminal,
                        threadID: nil,
                        turnID: nil,
                        draftBytes: terminal == .readyForReview ? fixture.projectionBytes : nil,
                        error: terminal == .failed ? "late failure" : nil
                    ),
                    in: fixture.store
                )
                XCTFail("Expected replaced-attempt ownership conflict")
            } catch let error as RepositoryPlanReconstructionError {
                XCTAssertEqual(error, .preparationConflict)
            }
        }
    }

    private func canonicalBytes(_ envelope: AgentCommandEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func stateRecordDocument(_ record: RepositoryPlanStateRecord) throws -> Data {
        try stateRecordDocument([record])
    }

    private func stateRecordDocument(_ records: [RepositoryPlanStateRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let objects = try records.map { record -> [String: Any] in
            guard var object = try JSONSerialization.jsonObject(with: encoder.encode(record))
                as? [String: Any] else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "The test state record did not encode as an object."
                )
            }
            if object["phaseCompletion"] == nil {
                object["phaseCompletion"] = NSNull()
            }
            return object
        }
        return try JSONSerialization.data(
            withJSONObject: ["records": objects],
            options: [.sortedKeys]
        )
    }

    private func ticketAcceptanceEvidenceSave(
        proposalID: String,
        projectedTasks: [RepositoryPlanProjectionTask],
        evidenceTasks: some Sequence<RepositoryPlanStateTaskSnapshot>
    ) async throws -> AgentCommandResult {
        let sourceRef = RepositoryPlanSourceReference.document(
            documentID: "ticket-state-document",
            locator: "/records/0"
        )
        let record = RepositoryPlanStateRecord(
            recordID: "accepted-\(proposalID)",
            repositoryID: "9141d1ea-3342-4462-9e06-6934d816c03f",
            kind: .ticketAcceptance,
            subject: .ticket(.init(
                sourceID: "ticket-101",
                outcome: "Imported ticket",
                phaseSourceID: "phase-101",
                taskPlan: .init(sourceRevision: 7, tasks: Array(evidenceTasks))
            )),
            state: .accepted,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            actorID: "owner",
            phaseCompletion: nil
        )
        let documentBytes = try stateRecordDocument(record)
        let fixture = try await ReconstructionFixture.make(capturedSourceBytes: documentBytes)
        let projection = fixture.projectionWithAcceptedTicketAndTasks(
            tasks: projectedTasks,
            stateEvidence: [sourceRef],
            documentID: "ticket-state-document",
            documentDigest: sha256(documentBytes)
        )
        let source = try fixture.source(for: projection)
        let evidence = try RepositoryPlanTerminalEvidenceResolver.original(
            sourceRef: sourceRef,
            source: source
        )
        let preview = try await RepositoryPlanReconstructionPreviewQuery.preview(
            source: source,
            reviewedProjection: projection,
            corrections: [],
            explicitMappings: [],
            from: fixture.store
        )
        let payload = fixture.payload(
            source: source,
            reviewedProjection: projection,
            preview: preview,
            terminalEvidence: [evidence]
        )
        return await fixture.dispatcher.dispatch(
            fixture.envelope(
                requestID: UUID(),
                command: .saveRepositoryPlanReconstruction(
                    proposalID: proposalID,
                    expectedPreviousVersion: nil,
                    rationale: "Verify exact accepted-ticket task proof.",
                    payload: payload
                )
            ),
            origin: .ownerApp
        )
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct ReconstructionCounts: Equatable {
    let auditEvents: Int64
    let phases: Int64
    let provenance: Int64
    let applications: Int64
    let attempts: Int64
    let receipts: Int64
}

private enum ExactCompletedDestinationSeed: Equatable {
    case directDeliveredGoal
    case unresolvedObligation
    case cyclicObligations
    case retiredExtraTicket
}

struct ReconstructionFixture {
    let root: URL
    let databaseURL: URL
    let store: DeliveryStore
    let dispatcher: AgentCommandDispatcher
    let registration: ProjectRegistration
    let projectionBytes: Data
    let projection: RepositoryPlanProjection
    let payload: RepositoryPlanReconstructionPayload

    static func make(capturedSourceBytes: Data? = nil) async throws -> Self {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadarReconstructionTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(
            at: source.appendingPathComponent("docs"),
            to: root.appendingPathComponent("docs")
        )
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: root.appendingPathComponent("AGENTS.md"))
        if let capturedSourceBytes {
            try capturedSourceBytes.write(
                to: root.appendingPathComponent("docs/plans/current.md")
            )
        }

        let catalog = try DocumentationCatalogContext(root: root).managedSnapshot()
        let databaseURL = root.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "project-101"),
            registrationID: "registration-101",
            requestGeneration: 1
        )
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed reconstruction fixture"
        ) { connection in
            try connection.execute(
                "INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('project-101','Project 101',1)"
            )
            try connection.execute(
                "INSERT INTO project_roots (id,project_id,path) VALUES ('root-101','project-101',?)",
                bindings: [.text(root.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id,path,bookmark_data,is_stale) VALUES ('project-101',?,?,0)",
                bindings: [.text(root.path), .blob(Data(root.path.utf8))]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('project-101','registration-101',1,'complete')"
            )
            try connection.execute(
                """
                INSERT INTO project_documentation_bindings (
                    project_id,root_id,repository_id,accepted_catalog_version,
                    accepted_catalog_digest,accepted_catalog
                ) VALUES ('project-101','root-101',?,?,?,?)
                """,
                bindings: [
                    .text(catalog.catalog.repositoryID.lowercased()),
                    .integer(Int64(catalog.version)),
                    .text(catalog.digest),
                    .blob(catalog.canonicalCatalog),
                ]
            )
        }

        let sourceBytes = try Data(contentsOf: root.appendingPathComponent("docs/plans/current.md"))
        let captured = RepositoryPlanCapturedSource(
            artifactID: "current",
            path: "docs/plans/current.md",
            contentSHA256: digest(sourceBytes),
            lifecycle: .active,
            authority: .controlling,
            bytes: sourceBytes
        )
        let manifest = RepositoryPlanSourceManifest(
            projectID: registration.projectID,
            rootID: "root-101",
            rootPath: root.path,
            registration: registration,
            repositoryID: catalog.catalog.repositoryID.lowercased(),
            acceptedCatalogVersion: catalog.version,
            acceptedCatalogDigest: catalog.digest,
            sources: [captured]
        )
        let projectionID = "00000000-0000-4000-8000-000000000101"
        let projection = RepositoryPlanProjection(
            format: "release-radar.repository-plan",
            schemaVersion: 1,
            repositoryID: catalog.catalog.repositoryID.lowercased(),
            projectionID: projectionID,
            projectionRevision: 1,
            documents: [],
            phases: [.init(
                sourceID: "phase-101",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/phases/0")],
                name: "Imported phase",
                lifecycle: .upcoming,
                stateEvidence: []
            )],
            tickets: [],
            phaseDependencies: [],
            ticketDependencies: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let projectionBytes = try encoder.encode(projection)
        _ = try RepositoryPlanProjectionValidator.validate(projectionBytes, against: manifest)
        let sourceSnapshot = RepositoryPlanReconstructionSourceSnapshot(
            projectID: registration.projectID,
            rootID: "root-101",
            registration: registration,
            repositoryID: catalog.catalog.repositoryID.lowercased(),
            projectionID: UUID(uuidString: projectionID)!,
            projectionRevision: 1,
            projectionBytes: projectionBytes,
            projectionSHA256: digest(projectionBytes),
            acceptedCatalogVersion: catalog.version,
            acceptedCatalogDigest: catalog.digest,
            capturedSourceManifest: manifest,
            observedGitHEAD: nil
        )
        let payload = RepositoryPlanReconstructionPayload(
            source: sourceSnapshot,
            reviewedProjection: projection,
            comparisons: [.init(
                kind: .phase,
                parentSourceID: nil,
                sourceID: "phase-101",
                destinationID: nil,
                disposition: .new
            )],
            corrections: [],
            exclusions: [],
            terminalEvidence: [],
            blockers: []
        )
        let project = AuthorizedProject(
            registration: registration,
            canonicalRoot: root,
            authorizedRoots: [root]
        )
        return Self(
            root: root,
            databaseURL: databaseURL,
            store: store,
            dispatcher: AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]),
                bookmarkStore: bookmarkStore(root: root)
            ),
            registration: registration,
            projectionBytes: projectionBytes,
            projection: projection,
            payload: payload
        )
    }

    func dispatcher(store: DeliveryStore) -> AgentCommandDispatcher {
        let project = AuthorizedProject(
            registration: registration,
            canonicalRoot: root,
            authorizedRoots: [root]
        )
        return AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]),
            bookmarkStore: Self.bookmarkStore(root: root)
        )
    }

    func dispatcher(bookmarkStore: any ProjectBookmarkStoring) -> AgentCommandDispatcher {
        let project = AuthorizedProject(
            registration: registration,
            canonicalRoot: root,
            authorizedRoots: [root]
        )
        return AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]),
            bookmarkStore: bookmarkStore
        )
    }

    func envelope(requestID: UUID, command: AgentCommand) -> AgentCommandEnvelope {
        .init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: root.path,
            expectedRegistration: registration,
            reason: "Exercise repository reconstruction persistence.",
            command: command
        )
    }

    func applyEnvelope(
        proposalID: String,
        baselineDigest: String,
        decisionID: String,
        applicationID: String,
        requestID: UUID
    ) -> AgentCommandEnvelope {
        envelope(
            requestID: requestID,
            command: .applyPlanChangeProposal(
                proposalID: proposalID,
                version: 1,
                baselineDigest: baselineDigest,
                decisionID: decisionID,
                applicationID: applicationID
            )
        )
    }

    func save(proposalID: String) async throws -> (proposalID: String, baselineDigest: String) {
        try await save(proposalID: proposalID, payload: payload)
    }

    func save(
        proposalID: String,
        payload: RepositoryPlanReconstructionPayload,
        origin: AgentCommandOrigin = .ownerApp
    ) async throws -> (proposalID: String, baselineDigest: String) {
        let saved = await dispatcher.dispatch(envelope(
            requestID: UUID(),
            command: .saveRepositoryPlanReconstruction(
                proposalID: proposalID,
                expectedPreviousVersion: nil,
                rationale: "Review the captured repository plan before application.",
                payload: payload
            )
        ), origin: origin)
        XCTAssertNil(saved.error)
        XCTAssertEqual(saved.planChangeProposalVersion, 1)
        let readback = try XCTUnwrap(saved.repositoryPlanReconstruction)
        return (proposalID, readback.version.baselineDigest)
    }

    func saveAndApprove(
        proposalID: String,
        payload: RepositoryPlanReconstructionPayload? = nil
    ) async throws -> (proposalID: String, baselineDigest: String, decisionID: String) {
        let saved = try await save(proposalID: proposalID, payload: payload ?? self.payload)
        let decisionID = "decision-\(proposalID)"
        let decided = await dispatcher.dispatch(
            envelope(
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: proposalID,
                    version: 1,
                    baselineDigest: saved.baselineDigest,
                    decisionID: decisionID,
                    disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(decided.error)
        return (proposalID, saved.baselineDigest, decisionID)
    }

    fileprivate func counts(proposalID: String, requestID: UUID) async throws -> ReconstructionCounts {
        try await store.read { connection in
            ReconstructionCounts(
                auditEvents: try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE project_id=? AND entity_type='plan_change_proposal' AND entity_id=?",
                    bindings: [.text(registration.projectID.rawValue), .text(proposalID)]
                ) ?? 0,
                phases: try connection.scalarInt(
                    "SELECT COUNT(*) FROM phases WHERE project_id=?",
                    bindings: [.text(registration.projectID.rawValue)]
                ) ?? 0,
                provenance: try connection.scalarInt(
                    "SELECT COUNT(*) FROM repository_plan_reconstruction_provenance WHERE project_id=? AND proposal_id=?",
                    bindings: [.text(registration.projectID.rawValue), .text(proposalID)]
                ) ?? 0,
                applications: try connection.scalarInt(
                    "SELECT COUNT(*) FROM plan_change_proposal_applications WHERE project_id=? AND proposal_id=?",
                    bindings: [.text(registration.projectID.rawValue), .text(proposalID)]
                ) ?? 0,
                attempts: try connection.scalarInt(
                    "SELECT COUNT(*) FROM repository_plan_reconstruction_application_attempts WHERE project_id=? AND proposal_id=?",
                    bindings: [.text(registration.projectID.rawValue), .text(proposalID)]
                ) ?? 0,
                receipts: try connection.scalarInt(
                    "SELECT COUNT(*) FROM agent_command_requests WHERE request_id=?",
                    bindings: [.text(requestID.uuidString)]
                ) ?? 0
            )
        }
    }

    func phaseCount(id: String) async throws -> Int64 {
        try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM phases WHERE project_id=? AND id=?",
                bindings: [.text(registration.projectID.rawValue), .text(id)]
            ) ?? 0
        }
    }

    func phaseName(id: String) async throws -> String? {
        try await store.read { connection in
            try connection.scalarText(
                "SELECT name FROM phases WHERE project_id=? AND id=?",
                bindings: [.text(registration.projectID.rawValue), .text(id)]
            )
        }
    }

    func seedPhase(id: String, name: String) async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed preview candidate") {
            connection in
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: registration.projectID,
                phaseID: .init(rawValue: id),
                name: name,
                mode: .governed,
                connection: connection
            )
            try connection.execute(
                "UPDATE phase_lifecycles SET lifecycle='upcoming' WHERE project_id=? AND phase_id=?",
                bindings: [.text(registration.projectID.rawValue), .text(id)]
            )
        }
    }

    fileprivate func seedExactCompletedDestination(_ seed: ExactCompletedDestinationSeed) async throws {
        let auditID = AuditEventID(rawValue: "seed-exact-completed-destination")
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed exact completed reconstruction destination",
            auditEventID: auditID
        ) { connection in
            let project = registration.projectID.rawValue
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: registration.projectID,
                phaseID: .init(rawValue: "phase-101"),
                name: "Imported phase",
                mode: .governed,
                connection: connection
            )
            try connection.execute(
                "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('ticket-101',?,'phase-101','Imported ticket','accepted')",
                bindings: [.text(project)]
            )
            if seed == .cyclicObligations {
                try connection.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('ticket-202',?,'phase-101','Second imported ticket','accepted')",
                    bindings: [.text(project)]
                )
            }
            if seed == .retiredExtraTicket {
                try connection.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('retired-ticket',?,'phase-101','Retired ticket','backlog')",
                    bindings: [.text(project)]
                )
                try connection.execute(
                    "INSERT INTO ticket_retirements (project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at) VALUES (?,'retired-ticket','withdrawn','No longer retained','phase-101','backlog',?,'2026-10-18T00:00:00Z')",
                    bindings: [.text(project), .text(auditID.rawValue)]
                )
            }
            if seed != .retiredExtraTicket {
                let goalIDs = seed == .cyclicObligations ? ["goal-101", "goal-202"] : ["goal-101"]
                for (index, goalID) in goalIDs.enumerated() {
                    try connection.execute(
                        "INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,accepted_at,created_at,updated_at) VALUES (?,'phase-101',?,?,?,'accepted',?,'2026-10-18T00:00:00Z','2026-10-18T00:00:00Z','2026-10-18T00:00:00Z')",
                        bindings: [
                            .text(project), .text(goalID), .text("Goal \(index + 1)"),
                            .text("Delivered outcome \(index + 1)"), .integer(Int64(index)),
                        ]
                    )
                }
                let secondTicket = seed == .cyclicObligations ? "ticket-202" : "ticket-101"
                try connection.execute(
                    "INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES (?,'phase-101','goal-101','ticket-101','Primary scope','current','2026-10-18T00:00:00Z')",
                    bindings: [.text(project)]
                )
                if seed == .cyclicObligations {
                    try connection.execute(
                        "INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES (?,'phase-101','goal-202',?,'Second scope','current','2026-10-18T00:00:00Z')",
                        bindings: [.text(project), .text(secondTicket)]
                    )
                    try connection.execute(
                        "INSERT INTO delivery_goal_obligation_lineage (project_id,source_phase_id,source_goal_id,source_ticket_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id,reason,audit_event_id,created_at) VALUES (?,'phase-101','goal-101','ticket-101','phase-101','goal-202','ticket-202','Carry forward',?,'2026-10-18T00:00:00Z'),(?,'phase-101','goal-202','ticket-202','phase-101','goal-101','ticket-101','Cycle back',?,'2026-10-18T00:00:00Z')",
                        bindings: [
                            .text(project), .text(auditID.rawValue),
                            .text(project), .text(auditID.rawValue),
                        ]
                    )
                } else if seed == .directDeliveredGoal {
                    try connection.execute(
                        "INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES (?,'phase-101','goal-101','ticket-101')",
                        bindings: [.text(project)]
                    )
                }
            }
            try connection.execute(
                "UPDATE phase_lifecycles SET lifecycle='completed',record_origin='reconstruction' WHERE project_id=? AND phase_id='phase-101'",
                bindings: [.text(project)]
            )
        }
    }

    func exactCompletedProjection(ticketIDs: [String]) -> RepositoryPlanProjection {
        .init(
            format: projection.format,
            schemaVersion: projection.schemaVersion,
            repositoryID: projection.repositoryID,
            projectionID: projection.projectionID,
            projectionRevision: projection.projectionRevision,
            documents: projection.documents,
            phases: [.init(
                sourceID: "phase-101",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/phases/0")],
                name: "Imported phase",
                lifecycle: .completed,
                stateEvidence: [.projection(pointer: "/phases/0")]
            )],
            tickets: ticketIDs.enumerated().map { index, ticketID in
                .init(
                    sourceID: ticketID,
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/tickets/\(index)")],
                    outcome: ticketID == "ticket-101" ? "Imported ticket" : "Second imported ticket",
                    phaseSourceID: "phase-101",
                    lane: .accepted,
                    taskPlan: nil,
                    stateEvidence: [.projection(pointer: "/tickets/\(index)")],
                    evidenceRefs: []
                )
            },
            phaseDependencies: [],
            ticketDependencies: []
        )
    }

    func exactMappings(ticketIDs: [String]) -> [RepositoryPlanReconstructionMappingSelection] {
        [.init(
            subject: .init(kind: .phase, parentSourceID: nil, sourceID: "phase-101"),
            destinationID: "phase-101"
        )] + ticketIDs.map { ticketID in
            .init(
                subject: .init(kind: .ticket, parentSourceID: nil, sourceID: ticketID),
                destinationID: ticketID
            )
        }
    }

    func projection(replacingPhaseName name: String) -> RepositoryPlanProjection {
        .init(
            format: projection.format,
            schemaVersion: projection.schemaVersion,
            repositoryID: projection.repositoryID,
            projectionID: projection.projectionID,
            projectionRevision: projection.projectionRevision,
            documents: projection.documents,
            phases: projection.phases.map {
                .init(
                    sourceID: $0.sourceID,
                    authorityClass: $0.authorityClass,
                    sourceRefs: $0.sourceRefs,
                    name: name,
                    lifecycle: $0.lifecycle,
                    stateEvidence: $0.stateEvidence
                )
            },
            tickets: projection.tickets,
            phaseDependencies: projection.phaseDependencies,
            ticketDependencies: projection.ticketDependencies
        )
    }

    func projection(authorityClass: RepositoryPlanAuthorityClass) -> RepositoryPlanProjection {
        .init(
            format: projection.format,
            schemaVersion: projection.schemaVersion,
            repositoryID: projection.repositoryID,
            projectionID: projection.projectionID,
            projectionRevision: projection.projectionRevision,
            documents: projection.documents,
            phases: projection.phases.map {
                .init(
                    sourceID: $0.sourceID,
                    authorityClass: authorityClass,
                    sourceRefs: $0.sourceRefs,
                    name: $0.name,
                    lifecycle: $0.lifecycle,
                    stateEvidence: $0.stateEvidence
                )
            },
            tickets: projection.tickets,
            phaseDependencies: projection.phaseDependencies,
            ticketDependencies: projection.ticketDependencies
        )
    }

    func projectionWithTicketAndTasks(
        ticketLane: TicketLane,
        sourceRevision: Int,
        tasks: [RepositoryPlanProjectionTask]
    ) -> RepositoryPlanProjection {
        .init(
            format: projection.format,
            schemaVersion: projection.schemaVersion,
            repositoryID: projection.repositoryID,
            projectionID: projection.projectionID,
            projectionRevision: projection.projectionRevision,
            documents: projection.documents,
            phases: projection.phases,
            tickets: [.init(
                sourceID: "ticket-101",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0")],
                outcome: "Imported ticket",
                phaseSourceID: "phase-101",
                lane: ticketLane,
                taskPlan: .init(sourceRevision: sourceRevision, tasks: tasks),
                stateEvidence: [],
                evidenceRefs: []
            )],
            phaseDependencies: [],
            ticketDependencies: []
        )
    }

    func projectionWithAcceptedTicketAndTasks(
        tasks: [RepositoryPlanProjectionTask],
        stateEvidence: [RepositoryPlanSourceReference],
        documentID: String,
        documentDigest: String
    ) -> RepositoryPlanProjection {
        .init(
            format: projection.format,
            schemaVersion: projection.schemaVersion,
            repositoryID: projection.repositoryID,
            projectionID: projection.projectionID,
            projectionRevision: projection.projectionRevision,
            documents: [.init(
                id: documentID,
                artifactID: "current",
                contentSHA256: documentDigest
            )],
            phases: projection.phases,
            tickets: [.init(
                sourceID: "ticket-101",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0")],
                outcome: "Imported ticket",
                phaseSourceID: "phase-101",
                lane: .accepted,
                taskPlan: .init(sourceRevision: 7, tasks: tasks),
                stateEvidence: stateEvidence,
                evidenceRefs: []
            )],
            phaseDependencies: [],
            ticketDependencies: []
        )
    }

    func projectionWithTicket(
        taskPlan: RepositoryPlanProjectionTaskPlan?,
        lane: TicketLane
    ) -> RepositoryPlanProjection {
        .init(
            format: projection.format,
            schemaVersion: projection.schemaVersion,
            repositoryID: projection.repositoryID,
            projectionID: projection.projectionID,
            projectionRevision: projection.projectionRevision,
            documents: projection.documents,
            phases: projection.phases,
            tickets: [.init(
                sourceID: "ticket-101",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/tickets/0")],
                outcome: "Imported ticket",
                phaseSourceID: "phase-101",
                lane: lane,
                taskPlan: taskPlan,
                stateEvidence: lane == .accepted ? [.projection(pointer: "/tickets/0")] : [],
                evidenceRefs: []
            )],
            phaseDependencies: [],
            ticketDependencies: []
        )
    }

    func projection(
        from base: RepositoryPlanProjection,
        lifecycle: PhaseLifecycle,
        stateEvidence: [RepositoryPlanSourceReference]
    ) -> RepositoryPlanProjection {
        .init(
            format: base.format,
            schemaVersion: base.schemaVersion,
            repositoryID: base.repositoryID,
            projectionID: base.projectionID,
            projectionRevision: base.projectionRevision,
            documents: base.documents,
            phases: base.phases.map {
                .init(
                    sourceID: $0.sourceID,
                    authorityClass: $0.authorityClass,
                    sourceRefs: $0.sourceRefs,
                    name: $0.name,
                    lifecycle: lifecycle,
                    stateEvidence: stateEvidence
                )
            },
            tickets: base.tickets,
            phaseDependencies: base.phaseDependencies,
            ticketDependencies: base.ticketDependencies
        )
    }

    func payload(
        source: RepositoryPlanReconstructionSourceSnapshot,
        reviewedProjection: RepositoryPlanProjection,
        preview: RepositoryPlanReconstructionPreview,
        corrections: [RepositoryPlanReconstructionCorrection] = [],
        terminalEvidence: [RepositoryPlanTerminalEvidence] = []
    ) -> RepositoryPlanReconstructionPayload {
        .init(
            source: source,
            reviewedProjection: reviewedProjection,
            comparisons: preview.comparisons,
            corrections: corrections,
            exclusions: [],
            terminalEvidence: terminalEvidence,
            blockers: preview.blockers
        )
    }

    func projection(
        lifecycle: PhaseLifecycle,
        stateEvidence: [RepositoryPlanSourceReference],
        documentID: String?,
        documentDigest: String?
    ) -> RepositoryPlanProjection {
        let documents: [RepositoryPlanProjectionDocument]
        if let documentID, let documentDigest {
            documents = [.init(
                id: documentID,
                artifactID: "current",
                contentSHA256: documentDigest
            )]
        } else {
            documents = []
        }
        return .init(
            format: projection.format,
            schemaVersion: projection.schemaVersion,
            repositoryID: projection.repositoryID,
            projectionID: projection.projectionID,
            projectionRevision: projection.projectionRevision,
            documents: documents,
            phases: projection.phases.map {
                .init(
                    sourceID: $0.sourceID,
                    authorityClass: $0.authorityClass,
                    sourceRefs: $0.sourceRefs,
                    name: $0.name,
                    lifecycle: lifecycle,
                    stateEvidence: stateEvidence
                )
            },
            tickets: projection.tickets,
            phaseDependencies: projection.phaseDependencies,
            ticketDependencies: projection.ticketDependencies
        )
    }

    func source(
        for originalProjection: RepositoryPlanProjection
    ) throws -> RepositoryPlanReconstructionSourceSnapshot {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(originalProjection)
        _ = try RepositoryPlanProjectionValidator.validate(
            bytes,
            against: payload.source.capturedSourceManifest
        )
        return .init(
            projectID: registration.projectID,
            rootID: payload.source.rootID,
            registration: registration,
            repositoryID: payload.source.repositoryID,
            projectionID: UUID(uuidString: originalProjection.projectionID)!,
            projectionRevision: originalProjection.projectionRevision,
            projectionBytes: bytes,
            projectionSHA256: Self.digest(bytes),
            acceptedCatalogVersion: payload.source.acceptedCatalogVersion,
            acceptedCatalogDigest: payload.source.acceptedCatalogDigest,
            capturedSourceManifest: payload.source.capturedSourceManifest,
            observedGitHEAD: nil
        )
    }

    func taskPlanRevision(ticketID: String) async throws -> Int64? {
        try await store.read { connection in
            try connection.scalarInt(
                "SELECT revision FROM ticket_task_plans WHERE project_id=? AND ticket_id=?",
                bindings: [.text(registration.projectID.rawValue), .text(ticketID)]
            )
        }
    }

    func seedMappedTicketWithExtraTask() async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed mapped task graph") {
            connection in
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: registration.projectID,
                phaseID: .init(rawValue: "mapped-phase"),
                name: "Imported phase",
                mode: .governed,
                connection: connection
            )
            try DeliveryPlanningPolicy.upsertTicket(
                projectID: registration.projectID,
                ticketID: .init(rawValue: "mapped-ticket"),
                phaseID: .init(rawValue: "mapped-phase"),
                outcome: "Imported ticket",
                lane: .backlog,
                auditEventID: .init(rawValue: "seed-mapped-task"),
                connection: connection
            )
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: registration.projectID,
                ticketID: .init(rawValue: "mapped-ticket"),
                expectedRevision: nil,
                additions: [.init(
                    id: .init(rawValue: "destination-extra-task"),
                    label: "Extra",
                    title: "Destination-only task",
                    sortOrder: 0
                )],
                definitionRevisions: [],
                supersededTaskIDs: [],
                connection: connection
            )
        }
    }

    func markPhaseCompleted(id: String) async throws {
        try await store.transactRepositoryPlanRecovery { connection in
            try connection.execute(
                "UPDATE phase_lifecycles SET lifecycle='completed',record_origin='reconstruction' WHERE project_id=? AND phase_id=?",
                bindings: [.text(registration.projectID.rawValue), .text(id)]
            )
        }
    }

    func graphRecordCount() async throws -> Int64 {
        try await store.read { connection in
            let phases = try connection.scalarInt(
                "SELECT COUNT(*) FROM phases WHERE project_id=?",
                bindings: [.text(registration.projectID.rawValue)]
            ) ?? 0
            let tickets = try connection.scalarInt(
                "SELECT COUNT(*) FROM tickets WHERE project_id=?",
                bindings: [.text(registration.projectID.rawValue)]
            ) ?? 0
            let tasks = try connection.scalarInt(
                "SELECT COUNT(*) FROM ticket_tasks WHERE project_id=?",
                bindings: [.text(registration.projectID.rawValue)]
            ) ?? 0
            return phases + tickets + tasks
        }
    }

    func provenanceCount(proposalID: String) async throws -> Int64 {
        try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM repository_plan_reconstruction_provenance WHERE project_id=? AND proposal_id=?",
                bindings: [.text(registration.projectID.rawValue), .text(proposalID)]
            ) ?? 0
        }
    }

    func decisionCount(proposalID: String) async throws -> Int64 {
        try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM plan_change_proposal_decisions WHERE project_id=? AND proposal_id=?",
                bindings: [.text(registration.projectID.rawValue), .text(proposalID)]
            ) ?? 0
        }
    }

    func attemptState(
        proposalID: String
    ) async throws -> RepositoryPlanReconstructionApplicationAttemptState? {
        try await store.read { connection in
            guard let raw = try connection.scalarText(
                "SELECT state FROM repository_plan_reconstruction_application_attempts WHERE project_id=? AND proposal_id=?",
                bindings: [.text(registration.projectID.rawValue), .text(proposalID)]
            ) else { return nil }
            return RepositoryPlanReconstructionApplicationAttemptState(rawValue: raw)
        }
    }

    func insertPendingAttempt(_ envelope: AgentCommandEnvelope) async throws {
        guard case let .applyPlanChangeProposal(proposalID, version, _, _, applicationID) = envelope.command else {
            throw RepositoryPlanReconstructionError.applicationAttemptConflict
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(envelope)
        try await store.transactRepositoryPlanRecovery { connection in
            let now = ISO8601DateFormatter().string(from: Date())
            try connection.execute(
                """
                INSERT INTO repository_plan_reconstruction_application_attempts (
                    project_id,proposal_id,version,application_id,request_id,
                    registration_id,request_generation,envelope_data,state,result_data,
                    created_at,updated_at
                ) VALUES (?,?,?,?,?,?,?,?,'pending',NULL,?,?)
                """,
                bindings: [
                    .text(registration.projectID.rawValue), .text(proposalID), .integer(version),
                    .text(applicationID), .text(envelope.requestID.uuidString),
                    .text(registration.registrationID), .integer(registration.requestGeneration),
                    .blob(bytes), .text(now), .text(now),
                ]
            )
        }
    }

    func preparationRequest(
        proposalID: String,
        attemptID: UUID
    ) -> RepositoryPlanPreparationRequest {
        let snapshotRoot = root.appendingPathComponent("preparation-snapshot", isDirectory: true)
        return .init(
            identity: .init(
                registration: registration,
                rootID: "root-101",
                proposalID: .init(rawValue: proposalID),
                attemptID: attemptID
            ),
            sourceManifest: payload.source.capturedSourceManifest,
            snapshot: .init(
                rootPath: snapshotRoot.path,
                workingPath: snapshotRoot.appendingPathComponent("work", isDirectory: true).path,
                manifestSHA256: payload.source.projectionSHA256
            ),
            projectionID: payload.source.projectionID,
            projectionRevision: payload.source.projectionRevision,
            codexContextID: UUID(),
            model: "test-model",
            effort: "test-effort"
        )
    }

    private static func bookmarkStore(root: URL) -> ProjectBookmarkStore {
        ProjectBookmarkStore(
            resolver: { _ in .init(url: root, isStale: false) },
            startAccessing: { _ in true },
            stopAccessing: { _ in }
        )
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private final class MutatingSecondAccessBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
    private let root: URL
    private let sourceURL: URL
    private let lock = NSLock()
    private var accesses = 0

    init(root: URL, sourceURL: URL) {
        self.root = root
        self.sourceURL = sourceURL
    }

    var accessCount: Int { lock.withLock { accesses } }

    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: root, isStale: false)
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        let access = lock.withLock {
            accesses += 1
            return accesses
        }
        if access == 2 {
            try Data("source changed at final apply boundary".utf8).write(to: sourceURL)
        }
        return try await body(.init(url: root, isStale: false))
    }
}

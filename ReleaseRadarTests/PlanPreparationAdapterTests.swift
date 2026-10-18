import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class PlanPreparationAdapterTests: XCTestCase {
    func testSetupClientPrepareCleanupCloseFailureRetainsPreparationOwnership() async throws {
        let fixture = try PreparationAdapterFixture()
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let home = root.appendingPathComponent("selected-codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("selected global instructions".utf8).write(to: home.appendingPathComponent("AGENTS.md"))
        let context = try CodexExecutionContext(home: home, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let matching = RepositoryPlanPreparationRequest(identity: fixture.request.identity, sourceManifest: fixture.request.sourceManifest,
            snapshot: fixture.request.snapshot, projectionID: fixture.request.projectionID, projectionRevision: fixture.request.projectionRevision,
            codexContextID: context.id, model: fixture.request.model, effort: fixture.request.effort)
        let service = AppPreparationService()
        let factoryUses = PreparationCounter()
        let stopCount = PreparationCounter()
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root }, contextAccessFactory: { selected, files in
            try CodexExecutionContextLease(context: selected, current: { try files.codexContext() },
                resolve: { _ in .init(url: home, isStale: false) }, start: { _ in true }, stop: { _ in stopCount.increment() })
        }, planPreparationFactory: {
            factoryUses.increment()
            return service
        })

        await service.setPrepareCleanupCloseFailure(true)
        try await client.useCodexContext(context.id)
        await XCTAssertThrowsErrorAsync(try await client.preparePlanDraft(matching))
        XCTAssertEqual(stopCount.value, 0)
        var retained: RepositoryPlanPreparationReadback?
        do {
            retained = try await client.planDraftStatus(matching.identity)
        } catch {
            XCTFail("Preparation identity and status must survive unknown setup cleanup close")
        }
        XCTAssertEqual(retained?.identity, matching.identity)
        XCTAssertEqual(retained?.state, .outcomeUnknown)

        let secondIdentity = RepositoryPlanPreparationIdentity(registration: matching.identity.registration,
            rootID: matching.identity.rootID, proposalID: matching.identity.proposalID, attemptID: UUID())
        let secondAttempt = RepositoryPlanPreparationRequest(identity: secondIdentity, sourceManifest: matching.sourceManifest,
            snapshot: matching.snapshot, projectionID: matching.projectionID, projectionRevision: matching.projectionRevision,
            codexContextID: matching.codexContextID, model: matching.model, effort: matching.effort)
        await XCTAssertThrowsErrorAsync(try await client.preparePlanDraft(secondAttempt))
        XCTAssertEqual(factoryUses.value, 1)
        XCTAssertEqual(stopCount.value, 0)
        guard retained != nil else { return }

        await service.setPrepareCleanupCloseFailure(false)
        try await client.closePlanDraft(matching.identity)
        XCTAssertEqual(stopCount.value, 1)
    }
    func testSetupClientTransfersOnlySelectedContextToOnePreparationAdapter() async throws {
        let fixture = try PreparationAdapterFixture()
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let home = root.appendingPathComponent("selected-codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("selected global instructions".utf8).write(to: home.appendingPathComponent("AGENTS.md"))
        let context = try CodexExecutionContext(home: home, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let matching = RepositoryPlanPreparationRequest(identity: fixture.request.identity, sourceManifest: fixture.request.sourceManifest,
            snapshot: fixture.request.snapshot, projectionID: fixture.request.projectionID, projectionRevision: fixture.request.projectionRevision,
            codexContextID: context.id, model: fixture.request.model, effort: fixture.request.effort)
        let service = AppPreparationService(); let factoryUses = PreparationCounter()
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root }, contextAccessFactory: { selected, files in
            try CodexExecutionContextLease(context: selected, current: { try files.codexContext() },
                resolve: { _ in .init(url: home, isStale: false) }, start: { _ in true }, stop: { _ in })
        }, planPreparationFactory: {
            factoryUses.increment()
            return service
        })

        var mismatched = matching
        mismatched = .init(identity: mismatched.identity, sourceManifest: mismatched.sourceManifest, snapshot: mismatched.snapshot,
            projectionID: mismatched.projectionID, projectionRevision: mismatched.projectionRevision,
            codexContextID: UUID(), model: mismatched.model, effort: mismatched.effort)
        await XCTAssertThrowsErrorAsync(try await client.preparePlanDraft(mismatched))
        XCTAssertEqual(factoryUses.value, 0)

        try await client.useCodexContext(context.id)
        let readback = try await client.preparePlanDraft(matching)
        XCTAssertEqual(readback.state, .running)
        XCTAssertEqual(readback.threadID, "thread-101")
        XCTAssertEqual(readback.turnID, "turn-101")
        XCTAssertEqual(factoryUses.value, 1)
        let receivedContextID = await service.contextID
        let receivedSources = await service.instructionSources
        let receivedIdentity = await service.requestIdentity
        XCTAssertEqual(receivedContextID, context.id)
        XCTAssertEqual(receivedSources, [home.appendingPathComponent("AGENTS.md").path])
        XCTAssertEqual(receivedIdentity, matching.identity)
        let initialStatus = try await client.planDraftStatus(matching.identity)
        XCTAssertEqual(initialStatus.identity, matching.identity)
        let interrupted = try await client.cancelPlanDraft(matching.identity)
        XCTAssertEqual(interrupted.state, .running)
        await service.finishCancelled()
        var terminal = try await client.planDraftStatus(matching.identity)
        for _ in 0..<20 where terminal.state != .cancelled {
            try await Task.sleep(for: .milliseconds(10))
            terminal = try await client.planDraftStatus(matching.identity)
        }
        XCTAssertEqual(terminal.state, .cancelled)
        try await client.closePlanDraft(matching.identity)
        let closed = await service.closed
        XCTAssertTrue(closed)
    }

    func testPrepareUsesBoundedSetupBeforeExactlyOneTurn() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = PreparationPeer(request: fixture.request)
        let lease = PreparationLease()
        let adapter = PlanPreparationAdapter(serverFactory: { executable, arguments, receivedLease, onMessage in
            XCTAssertEqual(executable, CodexExecutionIdentity.executable)
            XCTAssertTrue(arguments.starts(with: AppServerTransport.executionSetupArguments))
            XCTAssertTrue(receivedLease === lease)
            peer.onMessage = onMessage
            return peer
        })

        let readback = try await adapter.prepare(fixture.request, context: lease, allowedInstructionSources: fixture.allowedSources)

        XCTAssertEqual(readback.identity, fixture.request.identity)
        XCTAssertEqual(readback.state, .running)
        XCTAssertEqual(readback.threadID, "thread-101")
        XCTAssertEqual(readback.turnID, "turn-101")
        XCTAssertEqual(peer.calls, ["initialize", "account/read", "config/read", "thread/start", "mcpServerStatus/list", "turn/start"])
        XCTAssertEqual(peer.turnStarts, 1)
        XCTAssertEqual(lease.validations, 1)
    }

    func testTurnInputCarriesCapturedSourceBytesAndTypedProjectionContract() async throws {
        let fixture = try PreparationAdapterFixture(); let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
        _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
        let turn = try XCTUnwrap(peer.parameters(for: "turn/start"))
        let input = try XCTUnwrap(((try turn.object())["input"] as? [[String: Any]])?.first?["text"] as? String)
        XCTAssertTrue(input.contains("approved source"))
        XCTAssertTrue(input.contains("release-radar.repository-plan"))
        XCTAssertTrue(input.contains("projectionID"))
        XCTAssertTrue(input.contains("projectionRevision"))
    }

    func testRejectsSetupFailureAndCapabilitiesBeforeTurn() async throws {
        let fixture = try PreparationAdapterFixture()
        for mode in [PreparationPeer.Mode.nonChatGPT, .invalidConfig, .capability] {
            let peer = PreparationPeer(request: fixture.request, mode: mode)
            let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
            await XCTAssertThrowsErrorAsync(try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources))
            XCTAssertEqual(peer.turnStarts, 0, "Setup failure must stop before turn/start")
        }
    }

    func testIgnoresWrongAndLateEventsAndAcceptsOneCorrelatedDraft() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
        _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)

        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": [
            "threadId": "wrong", "turnId": "turn-101", "item": ["type": "agentMessage", "text": fixture.projectionText],
        ]]))
        let wrongEvent = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(wrongEvent.state, .running)

        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": [
            "threadId": "thread-101", "turnId": "turn-101", "item": ["type": "agentMessage", "text": fixture.projectionText],
        ]]))
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "turn/completed", "params": [
            "threadId": "thread-101", "turn": ["id": "turn-101", "status": "completed"],
        ]]))
        let complete = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(complete.state, .readyForReview)
        XCTAssertEqual(complete.draftBytes, Data(fixture.projectionText.utf8))
    }

    func testRejectsOverLimitOutput() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
        _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
        let oversized = String(repeating: " ", count: RepositoryPlanProjectionValidator.maximumProjectionBytes + 1)
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": [
            "threadId": "thread-101", "turnId": "turn-101", "item": ["type": "agentMessage", "text": fixture.projectionText + oversized],
        ]]))
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "turn/completed", "params": [
            "threadId": "thread-101", "turn": ["id": "turn-101", "status": "completed"],
        ]]))
        let failed = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(failed.state, .failed)
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "adapter/connectionLost", "params": [:]]))
        let afterLoss = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(afterLoss.state, .failed)
    }

    func testAcceptsExactlyOneMiBOfOneCompleteProjectionMessage() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
        _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
        let payload = fixture.projectionText + String(repeating: " ", count: RepositoryPlanProjectionValidator.maximumProjectionBytes - fixture.projectionText.utf8.count)
        XCTAssertEqual(payload.utf8.count, RepositoryPlanProjectionValidator.maximumProjectionBytes)
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": [
            "threadId": "thread-101", "turnId": "turn-101", "item": ["type": "agentMessage", "text": payload],
        ]]))
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "turn/completed", "params": [
            "threadId": "thread-101", "turn": ["id": "turn-101", "status": "completed"],
        ]]))
        let readback = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(readback.state, .readyForReview)
        XCTAssertEqual(readback.draftBytes?.count, RepositoryPlanProjectionValidator.maximumProjectionBytes)
    }

    func testRejectsMultipleOrExplicitlyTruncatedAgentMessages() async throws {
        let fixture = try PreparationAdapterFixture()
        for truncated in [false, true] {
            let peer = PreparationPeer(request: fixture.request)
            let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
            _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
            let item: [String: Any] = ["type": "agentMessage", "text": fixture.projectionText, "truncated": truncated, "textTruncated": truncated]
            await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": [
                "threadId": "thread-101", "turnId": "turn-101", "item": item,
            ]]))
            if !truncated {
                await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": [
                    "threadId": "thread-101", "turnId": "turn-101", "item": item,
                ]]))
            }
            await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "turn/completed", "params": [
                "threadId": "thread-101", "turn": ["id": "turn-101", "status": "completed"],
            ]]))
            let failed = try await adapter.status(fixture.request.identity)
            XCTAssertEqual(failed.state, .failed)
        }
    }

    func testRejectsMissingOrNonStringAgentMessageText() async throws {
        let fixture = try PreparationAdapterFixture()
        for item in [["type": "agentMessage"], ["type": "agentMessage", "text": 1]] as [[String: Any]] {
            let peer = PreparationPeer(request: fixture.request)
            let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
            _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
            await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": ["threadId": "thread-101", "turnId": "turn-101", "item": item]]))
            await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "turn/completed", "params": ["threadId": "thread-101", "turn": ["id": "turn-101", "status": "completed"]]]))
            let failed = try await adapter.status(fixture.request.identity)
            XCTAssertEqual(failed.state, .failed)
        }
    }

    func testConnectionLossIsTerminalUnknownAndLateSuccessCannotRewriteIt() async throws {
        let fixture = try PreparationAdapterFixture(); let peer = PreparationPeer(request: fixture.request); let counter = PreparationCounter()
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in counter.increment(); peer.onMessage = message; return peer })
        _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "adapter/connectionLost", "params": [:]]))
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "item/completed", "params": ["threadId": "thread-101", "turnId": "turn-101", "item": ["type": "agentMessage", "text": fixture.projectionText]]]))
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "turn/completed", "params": ["threadId": "thread-101", "turn": ["id": "turn-101", "status": "completed"]]]))
        let uncertain = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(uncertain.state, .outcomeUnknown)
        XCTAssertEqual(counter.value, 1)
    }

    func testCancellationRequiresCorrelatedInterruptedCompletion() async throws {
        let fixture = try PreparationAdapterFixture(); let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
        _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
        let interruptAcknowledged = try await adapter.cancel(fixture.request.identity)
        XCTAssertEqual(interruptAcknowledged.state, .running)
        await adapter.event(fixture.request.identity.attemptID, try RPCObject(["method": "turn/completed", "params": ["threadId": "thread-101", "turn": ["id": "turn-101", "status": "interrupted"]]]))
        let cancelled = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(cancelled.state, .cancelled)
    }

    func testSnapshotSourceMismatchFailsBeforeFactoryCreation() async throws {
        let fixture = try PreparationAdapterFixture(); try FileManager.default.removeItem(at: fixture.materializedSource)
        let counter = PreparationCounter(); let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in counter.increment(); peer.onMessage = message; return peer })
        await XCTAssertThrowsErrorAsync(try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources))
        XCTAssertEqual(counter.value, 0)
    }

    func testSnapshotRejectsUnselectedFileBeforeFactoryCreation() async throws {
        let fixture = try PreparationAdapterFixture()
        let extraSource = URL(fileURLWithPath: fixture.request.snapshot.rootPath)
            .appendingPathComponent("input/docs/unselected.md")
        try Data("unselected source".utf8).write(to: extraSource)
        let counter = PreparationCounter()
        let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in
            counter.increment(); peer.onMessage = message; return peer
        })

        await XCTAssertThrowsErrorAsync(try await adapter.prepare(
            fixture.request,
            context: PreparationLease(),
            allowedInstructionSources: fixture.allowedSources
        ))
        XCTAssertEqual(counter.value, 0)
        XCTAssertEqual(peer.turnStarts, 0)
    }

    func testSnapshotRejectsNonemptySessionDotDSStoreBeforeFactoryCreation() async throws {
        let fixture = try PreparationAdapterFixture()
        let unexpectedSource = URL(fileURLWithPath: fixture.request.snapshot.workingPath)
            .appendingPathComponent(".DS_Store")
        try Data("unexpected session bytes".utf8).write(to: unexpectedSource)
        let counter = PreparationCounter()
        let peer = PreparationPeer(request: fixture.request)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in
            counter.increment(); peer.onMessage = message; return peer
        })

        await XCTAssertThrowsErrorAsync(try await adapter.prepare(
            fixture.request,
            context: PreparationLease(),
            allowedInstructionSources: fixture.allowedSources
        ))
        XCTAssertEqual(counter.value, 0)
        XCTAssertEqual(peer.turnStarts, 0)
    }

    func testSnapshotChangeDuringSetupFailsBeforeTurnDispatch() async throws {
        let fixture = try PreparationAdapterFixture()
        let gate = PreparationRPCGate()
        let peer = PreparationPeer(request: fixture.request, mode: .suspendedCapabilityInventory, gate: gate)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in
            peer.onMessage = message
            return peer
        })
        let preparation = Task {
            try await adapter.prepare(
                fixture.request,
                context: PreparationLease(),
                allowedInstructionSources: fixture.allowedSources
            )
        }

        guard await gate.waitUntilSuspended() else {
            do {
                _ = try await preparation.value
                XCTFail("Preparation completed before reaching the capability inventory gate")
            } catch {
                XCTFail("Preparation failed before reaching the capability inventory gate: \(error)")
            }
            return
        }
        do {
            try Data("changed during setup".utf8).write(to: fixture.materializedSource)
        } catch {
            await gate.resume()
            throw error
        }
        await gate.resume()

        await XCTAssertThrowsErrorAsync(try await preparation.value)
        XCTAssertEqual(peer.turnStarts, 0)
    }

    func testUncertainTurnStartIsOutcomeUnknownWithoutRedispatch() async throws {
        let fixture = try PreparationAdapterFixture(); let peer = PreparationPeer(request: fixture.request, mode: .lostTurnStart); let counter = PreparationCounter()
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in counter.increment(); peer.onMessage = message; return peer })
        let readback = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
        XCTAssertEqual(readback.state, .outcomeUnknown)
        XCTAssertEqual(counter.value, 1)
        let uncertain = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(uncertain.state, .outcomeUnknown)
    }

    func testSameProposalCannotRedispatchUntilPriorAttemptCloses() async throws {
        let fixture = try PreparationAdapterFixture()
        let firstPeer = PreparationPeer(request: fixture.request, mode: .lostTurnStart)
        let secondIdentity = RepositoryPlanPreparationIdentity(registration: fixture.request.identity.registration,
            rootID: fixture.request.identity.rootID, proposalID: fixture.request.identity.proposalID, attemptID: UUID())
        let secondRequest = RepositoryPlanPreparationRequest(identity: secondIdentity,
            sourceManifest: fixture.request.sourceManifest, snapshot: fixture.request.snapshot,
            projectionID: fixture.request.projectionID, projectionRevision: fixture.request.projectionRevision,
            codexContextID: fixture.request.codexContextID, model: fixture.request.model, effort: fixture.request.effort)
        let secondPeer = PreparationPeer(request: secondRequest)
        let factoryUses = PreparationCounter()
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in
            factoryUses.increment()
            if factoryUses.value == 1 {
                firstPeer.onMessage = message
                return firstPeer
            }
            secondPeer.onMessage = message
            return secondPeer
        })

        let first = try await adapter.prepare(fixture.request, context: PreparationLease(),
            allowedInstructionSources: fixture.allowedSources)
        XCTAssertEqual(first.state, .outcomeUnknown)
        XCTAssertEqual(factoryUses.value, 1)

        var blocked = false
        do {
            _ = try await adapter.prepare(secondRequest, context: PreparationLease(),
                allowedInstructionSources: fixture.allowedSources)
        } catch {
            blocked = true
        }
        XCTAssertTrue(blocked)
        XCTAssertEqual(factoryUses.value, 1)
        XCTAssertEqual(secondPeer.turnStarts, 0)
        guard blocked else { return }

        try await adapter.close(fixture.request.identity)
        let second = try await adapter.prepare(secondRequest, context: PreparationLease(),
            allowedInstructionSources: fixture.allowedSources)
        XCTAssertEqual(second.state, .running)
        XCTAssertEqual(factoryUses.value, 2)
        XCTAssertEqual(secondPeer.turnStarts, 1)
    }

    func testEventsDeliveredBeforeTurnStartResponseRemainTerminal() async throws {
        let fixture = try PreparationAdapterFixture()
        for mode in [PreparationPeer.Mode.raceCompletion, .raceConnectionLost] {
            let peer = PreparationPeer(request: fixture.request, mode: mode)
            let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
            let readback = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
            let expected: RepositoryPlanPreparationState = mode == .raceCompletion ? .readyForReview : .outcomeUnknown
            XCTAssertEqual(readback.state, expected)
            let status = try await adapter.status(fixture.request.identity)
            XCTAssertEqual(status.state, expected)
        }
    }

    func testCancelRequiresCompletionAndUnknownInterruptRemainsOutcomeUnknown() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = PreparationPeer(request: fixture.request, mode: .lostInterrupt)
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in peer.onMessage = message; return peer })
        _ = try await adapter.prepare(fixture.request, context: PreparationLease(), allowedInstructionSources: fixture.allowedSources)
        let cancelled = try await adapter.cancel(fixture.request.identity)
        XCTAssertEqual(cancelled.state, .outcomeUnknown)
        XCTAssertEqual(peer.interrupts, 1)
        let status = try await adapter.status(fixture.request.identity)
        XCTAssertEqual(status.threadID, "thread-101")
    }
}

private actor AppPreparationService: PlanPreparationServicing {
    private var readback: RepositoryPlanPreparationReadback?
    private var contextLease: CodexExecutionContextLease?
    private(set) var contextID: UUID?
    private(set) var instructionSources: [String] = []
    private(set) var requestIdentity: RepositoryPlanPreparationIdentity?
    private(set) var closed = false
    private var failPrepareCleanupClose = false

    func prepare(_ request: RepositoryPlanPreparationRequest, context: CodexExecutionContextLease,
                 allowedInstructionSources: [String]) async throws -> RepositoryPlanPreparationReadback {
        contextLease = context
        contextID = context.context.id; instructionSources = allowedInstructionSources; requestIdentity = request.identity
        let value = RepositoryPlanPreparationReadback(identity: request.identity,
            state: failPrepareCleanupClose ? .outcomeUnknown : .running,
            threadID: "thread-101", turnID: "turn-101", draftBytes: nil,
            error: failPrepareCleanupClose ? "setup cleanup close failed" : nil)
        readback = value
        if failPrepareCleanupClose {
            throw RepositoryPlanPreparationError(code: .outcomeUnknown)
        }
        return value
    }
    func status(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback {
        guard let readback, readback.identity == identity else { throw RepositoryPlanPreparationError(code: .identityMismatch) }
        return readback
    }
    func cancel(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback { try await status(identity) }
    func close(_ identity: RepositoryPlanPreparationIdentity) async throws { _ = try await status(identity); contextLease?.release(); contextLease = nil; closed = true }
    func setPrepareCleanupCloseFailure(_ value: Bool) { failPrepareCleanupClose = value }
    func seed(_ identity: RepositoryPlanPreparationIdentity) { readback = .init(identity: identity, state: .running, threadID: "thread", turnID: "turn", draftBytes: nil, error: nil) }
    func finishCancelled() { guard let readback else { return }; self.readback = .init(identity: readback.identity, state: .cancelled,
        threadID: readback.threadID, turnID: readback.turnID, draftBytes: nil, error: nil) }
}

private final class PreparationLease: ExecutionContextLease, @unchecked Sendable {
    var homePath: String { "/selected-codex" }
    private(set) var validations = 0
    func validate() throws { validations += 1 }
    func physicallyClosed() throws {}
    func onInvalidation(_ handler: @escaping @Sendable () -> Void) {}
}

private final class PreparationCounter: @unchecked Sendable {
    private let lock = NSLock(); private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private final class PreparationPeer: ExecutionPeer, @unchecked Sendable {
    enum Mode { case valid, nonChatGPT, invalidConfig, capability, lostInterrupt, lostTurnStart, raceCompletion, raceConnectionLost, suspendedCapabilityInventory }
    let request: RepositoryPlanPreparationRequest; let mode: Mode
    let gate: PreparationRPCGate?
    var onMessage: (@Sendable (RPCObject) -> Void)?
    var instructionSources: [String]?
    private(set) var calls: [String] = []; private var callParameters: [String: RPCObject] = [:]; private(set) var turnStarts = 0; private(set) var interrupts = 0; private(set) var factoryUses = 1
    init(request: RepositoryPlanPreparationRequest, mode: Mode = .valid, gate: PreparationRPCGate? = nil) {
        self.request = request; self.mode = mode; self.gate = gate
    }
    func send(_ message: [String: Any]) throws { if message["method"] as? String == "initialized" { return } }
    func parameters(for method: String) -> RPCObject? { callParameters[method] }
    func close() throws {}
    func call(_ method: String, _ parameters: RPCObject) async throws -> RPCObject {
        calls.append(method); callParameters[method] = parameters
        switch method {
        case "initialize": return try RPCObject([:])
        case "account/read": return try RPCObject(["account": ["type": mode == .nonChatGPT ? "apiKey" : "chatgpt"]])
        case "config/read": return try RPCObject(["config": mode == .invalidConfig ? [:] : config()])
        case "thread/start": return try RPCObject(["thread": ["id": "thread-101", "modelProvider": "openai"],
            "cwd": request.snapshot.workingPath, "runtimeWorkspaceRoots": [request.snapshot.workingPath], "model": request.model,
            "reasoningEffort": request.effort, "activePermissionProfile": ["id": PlanPreparationPolicy.permissionProfileID],
            "sandbox": ["networkAccess": false], "approvalPolicy": "never", "instructionSources": instructionSources ?? ["/selected-codex/AGENTS.md"]])
        case "mcpServerStatus/list":
            if mode == .suspendedCapabilityInventory { await gate?.suspend() }
            return try RPCObject(["data": mode == .capability ? [["tools": ["unsafe": [:]]]] : []])
        case "turn/start":
            turnStarts += 1
            if mode == .lostTurnStart { throw AppServerTransportError(message: "lost", outcomeUnknown: true) }
            if mode == .raceCompletion {
                onMessage?(try RPCObject(["method": "item/completed", "params": ["threadId": "thread-101", "turnId": "turn-101", "item": ["type": "agentMessage", "text": projectionText]]]))
                onMessage?(try RPCObject(["method": "turn/completed", "params": ["threadId": "thread-101", "turn": ["id": "turn-101", "status": "completed"]]]))
                try await Task.sleep(for: .milliseconds(25))
            }
            if mode == .raceConnectionLost { onMessage?(try RPCObject(["method": "adapter/connectionLost", "params": [:]])); try await Task.sleep(for: .milliseconds(25)) }
            return try RPCObject(["turn": ["id": "turn-101", "status": "inProgress"]])
        case "turn/interrupt": interrupts += 1; if mode == .lostInterrupt { throw AppServerTransportError(message: "lost", outcomeUnknown: true) }; return try RPCObject([:])
        default: return try RPCObject([:])
        }
    }
    private func config() -> [String: Any] { ["permissions": [PlanPreparationPolicy.permissionProfileID: ["filesystem": [":root": "deny", ":minimal": "read", ":workspace_roots": [".": "read"]], "network": ["enabled": false]]]] }
    private var projectionText: String { "{\"documents\":[],\"format\":\"release-radar.repository-plan\",\"phaseDependencies\":[],\"phases\":[],\"projectionID\":\"00000000-0000-4000-8000-000000000102\",\"projectionRevision\":1,\"repositoryID\":\"repository-101\",\"schemaVersion\":1,\"ticketDependencies\":[],\"tickets\":[]}" }
}

private actor PreparationRPCGate {
    private var suspended = false
    private var resumed = false
    private var suspensionWaiters: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private var resumeWaiters: [CheckedContinuation<Void, Never>] = []

    func suspend() async {
        suspended = true
        let waiters = suspensionWaiters.values
        suspensionWaiters.removeAll()
        waiters.forEach { $0.resume(returning: true) }
        guard !resumed else { return }
        await withCheckedContinuation { continuation in
            resumeWaiters.append(continuation)
        }
    }

    func waitUntilSuspended() async -> Bool {
        guard !suspended else { return true }
        let waiterID = UUID()
        return await withCheckedContinuation { continuation in
            suspensionWaiters[waiterID] = continuation
            Task {
                try? await Task.sleep(for: .seconds(5))
                await self.timeout(waiterID)
            }
        }
    }

    private func timeout(_ waiterID: UUID) {
        suspensionWaiters.removeValue(forKey: waiterID)?.resume(returning: false)
    }

    func resume() {
        resumed = true
        let waiters = resumeWaiters
        resumeWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private struct PreparationAdapterFixture {
    let request: RepositoryPlanPreparationRequest; let projectionText: String; let materializedSource: URL; let allowedSources = ["/selected-codex/AGENTS.md"]
    init() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source"); let snapshot = root.appendingPathComponent("snapshot")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true); try FileManager.default.createDirectory(at: snapshot.appendingPathComponent("session"), withIntermediateDirectories: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-101"), registrationID: "registration-101", requestGeneration: 1)
        projectionText = "{\"documents\":[],\"format\":\"release-radar.repository-plan\",\"phaseDependencies\":[],\"phases\":[],\"projectionID\":\"00000000-0000-4000-8000-000000000102\",\"projectionRevision\":1,\"repositoryID\":\"repository-101\",\"schemaVersion\":1,\"ticketDependencies\":[],\"tickets\":[]}"
        let bytes = Data("approved source".utf8); let sourceRecord = RepositoryPlanCapturedSource(artifactID: "source-101", path: "docs/current.md", contentSHA256: Self.digest(bytes), lifecycle: .active, authority: .controlling, bytes: bytes)
        materializedSource = snapshot.appendingPathComponent("input/docs/current.md")
        try FileManager.default.createDirectory(at: materializedSource.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: materializedSource)
        let manifest = RepositoryPlanSourceManifest(projectID: registration.projectID, rootID: "root-101", rootPath: source.path, registration: registration, repositoryID: "repository-101", acceptedCatalogVersion: 1, acceptedCatalogDigest: String(repeating: "a", count: 64), sources: [sourceRecord])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        request = .init(identity: .init(registration: registration, rootID: "root-101", proposalID: .init(rawValue: "proposal-101"), attemptID: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!), sourceManifest: manifest, snapshot: .init(rootPath: snapshot.path, workingPath: snapshot.appendingPathComponent("session").path, manifestSHA256: Self.digest(try encoder.encode(manifest))), projectionID: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!, projectionRevision: 1, codexContextID: UUID(uuidString: "00000000-0000-4000-8000-000000000203")!, model: "gpt-6-astra", effort: "high")
    }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

private func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T, file: StaticString = #filePath, line: UInt = #line) async {
    do { _ = try await expression(); XCTFail("Expected error", file: file, line: line) } catch {}
}

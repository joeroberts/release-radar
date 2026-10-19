import CryptoKit
import Darwin
import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class PlanPreparationAdapterTests: XCTestCase {
    func testRegistryMissRecoversExactStoredTerminalTurnWithoutStartingWork() async throws {
        for terminal in [
            StoredPreparationRecoveryPeer.Terminal.completed,
            .failed,
            .interrupted,
        ] {
            let fixture = try PreparationAdapterFixture()
            let peer = StoredPreparationRecoveryPeer(
                request: fixture.request,
                terminal: terminal,
                projectionText: fixture.projectionText
            )
            let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, onMessage in
                peer.onMessage = onMessage
                return peer
            })
            let saved = RepositoryPlanPreparationReadback(
                identity: fixture.request.identity,
                state: .outcomeUnknown,
                threadID: "thread-101",
                turnID: "turn-101",
                draftBytes: nil,
                error: "The original preparation connection was lost."
            )

            let recovered = try await adapter.restore(
                fixture.request,
                from: saved,
                context: PreparationLease(),
                allowedInstructionSources: fixture.allowedSources
            )

            let expected: RepositoryPlanPreparationState = switch terminal {
            case .completed: .readyForReview
            case .failed: .failed
            case .interrupted: .cancelled
            }
            XCTAssertEqual(recovered.state, expected)
            XCTAssertEqual(recovered.threadID, "thread-101")
            XCTAssertEqual(recovered.turnID, "turn-101")
            XCTAssertEqual(
                recovered.draftBytes,
                terminal == .completed ? Data(fixture.projectionText.utf8) : nil
            )
            XCTAssertTrue(peer.calls.contains("thread/read"))
            XCTAssertTrue(peer.calls.contains("thread/turns/list"))
            if terminal == .completed {
                XCTAssertTrue(peer.calls.contains("thread/items/list"))
            }
            XCTAssertTrue(Set(peer.calls).isDisjoint(with: [
                "thread/start", "turn/start", "thread/fork", "thread/resume", "turn/interrupt",
            ]))

            try await adapter.close(fixture.request.identity)
            XCTAssertEqual(peer.closeCount, 1)
        }
    }

    func testRegistryMissKeepsUnresolvedStoredTurnUnknownAndFreshPeerCloseCannotEndIt() async throws {
        for mode in [
            StoredPreparationRecoveryPeer.Mode.inProgress,
            .missingTurn,
            .mismatchedThread,
            .mismatchedTurn,
            .mismatchedWorkingDirectory,
            .notLoaded,
            .incompletePagination,
        ] {
            let fixture = try PreparationAdapterFixture()
            let peer = StoredPreparationRecoveryPeer(
                request: fixture.request,
                mode: mode,
                projectionText: fixture.projectionText
            )
            let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, onMessage in
                peer.onMessage = onMessage
                return peer
            })
            let saved = RepositoryPlanPreparationReadback(
                identity: fixture.request.identity,
                state: .outcomeUnknown,
                threadID: "thread-101",
                turnID: "turn-101",
                draftBytes: nil,
                error: "The exact stored turn still needs reconciliation."
            )

            let recovered = try await adapter.restore(
                fixture.request,
                from: saved,
                context: PreparationLease(),
                allowedInstructionSources: fixture.allowedSources
            )

            XCTAssertEqual(recovered.state, .outcomeUnknown, "mode: \(mode)")
            XCTAssertEqual(recovered.identity, fixture.request.identity)
            XCTAssertEqual(recovered.threadID, "thread-101")
            XCTAssertEqual(recovered.turnID, "turn-101")
            XCTAssertNil(recovered.draftBytes)
            XCTAssertTrue(Set(peer.calls).isDisjoint(with: [
                "thread/start", "turn/start", "thread/fork", "thread/resume", "turn/interrupt",
            ]))

            await XCTAssertThrowsErrorAsync(
                try await adapter.close(fixture.request.identity)
            )
            let retained = try await adapter.status(fixture.request.identity)
            XCTAssertEqual(retained.state, .outcomeUnknown)
            XCTAssertEqual(retained.identity, fixture.request.identity)
        }
    }

    func testRecoverySetupFailureCannotBeBypassedByStatusHistoryQuery() async throws {
        for failure in StoredPreparationRecoveryPeer.SetupFailure.allCases {
            let fixture = try PreparationAdapterFixture()
            let peer = StoredPreparationRecoveryPeer(
                request: fixture.request,
                terminal: .completed,
                projectionText: fixture.projectionText,
                setupFailure: failure
            )
            let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, onMessage in
                peer.onMessage = onMessage
                return peer
            })
            let saved = RepositoryPlanPreparationReadback(
                identity: fixture.request.identity,
                state: .outcomeUnknown,
                threadID: "thread-101",
                turnID: "turn-101",
                draftBytes: nil,
                error: "The selected recovery setup is unavailable."
            )

            let initiallyRejected = try await adapter.restore(
                fixture.request,
                from: saved,
                context: PreparationLease(),
                allowedInstructionSources: fixture.allowedSources
            )
            XCTAssertEqual(initiallyRejected.state, .outcomeUnknown, "failure: \(failure)")
            XCTAssertFalse(peer.calls.contains("thread/read"), "failure: \(failure)")
            XCTAssertFalse(peer.calls.contains("thread/turns/list"), "failure: \(failure)")
            XCTAssertFalse(peer.calls.contains("thread/items/list"), "failure: \(failure)")

            let stillRejected = try await adapter.status(fixture.request.identity)
            let queriedHistory = peer.calls.contains(where: {
                ["thread/read", "thread/turns/list", "thread/items/list"].contains($0)
            })
            guard stillRejected.state == .outcomeUnknown, !queriedHistory else {
                XCTFail(
                    "Rejected \(failure) setup must remain unknown without querying history."
                )
                continue
            }

            peer.acceptSetup()
            let recovered = try await adapter.status(fixture.request.identity)
            XCTAssertEqual(recovered.state, .readyForReview, "failure: \(failure)")
            XCTAssertEqual(recovered.draftBytes, Data(fixture.projectionText.utf8))
            let firstHistoryQuery = try XCTUnwrap(peer.calls.firstIndex(of: "thread/read"))
            let lastConfiguration = try XCTUnwrap(peer.calls.lastIndex(of: "config/read"))
            XCTAssertGreaterThan(firstHistoryQuery, lastConfiguration, "failure: \(failure)")
            XCTAssertTrue(Set(peer.calls).isDisjoint(with: [
                "thread/start", "turn/start", "thread/fork", "thread/resume", "turn/interrupt",
            ]))
        }
    }

    func testRegistryMissRejectsMismatchedSelectedContextBeforeCreatingRecoveryPeer() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = StoredPreparationRecoveryPeer(
            request: fixture.request,
            terminal: .completed,
            projectionText: fixture.projectionText
        )
        let harness = try makeStoredRecoveryHarness(fixture: fixture)
        let mismatched = RepositoryPlanPreparationRequest(
            identity: harness.request.identity,
            sourceManifest: harness.request.sourceManifest,
            snapshot: harness.request.snapshot,
            projectionID: harness.request.projectionID,
            projectionRevision: harness.request.projectionRevision,
            codexContextID: UUID(),
            model: harness.request.model,
            effort: harness.request.effort
        )
        let saved = RepositoryPlanPreparationReadback(
            identity: mismatched.identity,
            state: .outcomeUnknown,
            threadID: "thread-101",
            turnID: "turn-101",
            draftBytes: nil,
            error: nil
        )

        await XCTAssertThrowsErrorAsync(
            try await harness.client.restorePlanDraft(mismatched, readback: saved)
        )
        XCTAssertEqual(harness.factoryUses.value, 0)
        XCTAssertTrue(peer.calls.isEmpty)
    }

    func testSetupClientRegistryMissCreatesRecoveryServiceAndBindsRecoveredReadback() async throws {
        let fixture = try PreparationAdapterFixture()
        let service = AppPreparationService()
        let harness = try makeStoredRecoveryHarness(
            fixture: fixture,
            recoveryService: service
        )
        let saved = RepositoryPlanPreparationReadback(
            identity: harness.request.identity,
            state: .outcomeUnknown,
            threadID: "thread-101",
            turnID: "turn-101",
            draftBytes: nil,
            error: "The original preparation connection was lost."
        )
        let recovered = RepositoryPlanPreparationReadback(
            identity: harness.request.identity,
            state: .failed,
            threadID: "thread-101",
            turnID: "turn-101",
            draftBytes: nil,
            error: "The exact stored turn failed."
        )
        await service.setRestoreResult(recovered)

        try await harness.client.restorePlanDraft(harness.request, readback: saved)
        let observed = try await harness.client.planDraftStatus(harness.request.identity)
        let restoreCalls = await service.restoreCalls
        let prepareCalls = await service.prepareCalls

        XCTAssertEqual(observed, recovered)
        XCTAssertEqual(harness.factoryUses.value, 1)
        XCTAssertEqual(restoreCalls, 1)
        XCTAssertEqual(prepareCalls, 0)
    }

    func testSetupClientRelaunchRestoresExactPreparationForStatusCancelAndClose() async throws {
        let fixture = try PreparationAdapterFixture()
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let home = root.appendingPathComponent("selected-codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("selected global instructions".utf8).write(to: home.appendingPathComponent("AGENTS.md"))
        let context = try CodexExecutionContext(home: home, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let request = RepositoryPlanPreparationRequest(
            identity: fixture.request.identity,
            sourceManifest: fixture.request.sourceManifest,
            snapshot: fixture.request.snapshot,
            projectionID: fixture.request.projectionID,
            projectionRevision: fixture.request.projectionRevision,
            codexContextID: context.id,
            model: fixture.request.model,
            effort: fixture.request.effort
        )
        let service = AppPreparationService()
        let first = ProjectExecutionSetupClient(
            plugin: nil,
            executionRoot: { root },
            contextAccessFactory: { selected, files in
                try CodexExecutionContextLease(
                    context: selected,
                    current: { try files.codexContext() },
                    resolve: { _ in .init(url: home, isStale: false) },
                    start: { _ in true },
                    stop: { _ in }
                )
            },
            planPreparationFactory: { service }
        )
        try await first.useCodexContext(context.id)
        let running = try await first.preparePlanDraft(request)

        let replacementFactoryUses = PreparationCounter()
        let relaunched = ProjectExecutionSetupClient(
            plugin: nil,
            executionRoot: { root },
            contextAccessFactory: { selected, files in
                try CodexExecutionContextLease(
                    context: selected,
                    current: { try files.codexContext() },
                    resolve: { _ in .init(url: home, isStale: false) },
                    start: { _ in true },
                    stop: { _ in }
                )
            },
            planPreparationFactory: {
                replacementFactoryUses.increment()
                return AppPreparationService()
            }
        )

        try await relaunched.restorePlanDraft(request, readback: running)
        let restoredStatus = try await relaunched.planDraftStatus(request.identity)
        XCTAssertEqual(restoredStatus, running)
        let interrupted = try await relaunched.cancelPlanDraft(request.identity)
        XCTAssertEqual(interrupted, running)
        await service.finishCancelled()
        let cancelled = try await relaunched.planDraftStatus(request.identity)
        XCTAssertEqual(cancelled.state, .cancelled)
        try await relaunched.closePlanDraft(request.identity)

        let closed = await service.closed
        XCTAssertTrue(closed)
        XCTAssertEqual(replacementFactoryUses.value, 0)
    }

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

    func testPreparePublishesLearnedThreadBeforeTurnDispatchAndTurnImmediatelyAfterResponse() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = PreparationPeer(request: fixture.request)
        let progress = PreparationProgressRecorder()
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, message in
            peer.onMessage = message
            return peer
        })

        let readback = try await adapter.prepare(
            fixture.request,
            context: PreparationLease(),
            allowedInstructionSources: fixture.allowedSources,
            onProgress: { value in
                await progress.record(value, calls: peer.calls)
            }
        )

        let observations = await progress.values
        guard observations.count == 2 else {
            XCTFail("Expected thread and turn identity progress before return; got \(observations.count).")
            return
        }
        XCTAssertEqual(observations.map(\.readback.threadID), ["thread-101", "thread-101"])
        XCTAssertEqual(observations.map(\.readback.turnID), [nil, "turn-101"])
        XCTAssertFalse(observations[0].calls.contains("turn/start"))
        XCTAssertEqual(observations[1].calls.last, "turn/start")
        XCTAssertEqual(readback.turnID, "turn-101")
    }

    func testStoredThreadWithoutExactTurnStaysUnknownAndNeverSelectsLatestTurn() async throws {
        let fixture = try PreparationAdapterFixture()
        let peer = StoredPreparationRecoveryPeer(
            request: fixture.request,
            terminal: .completed,
            projectionText: fixture.projectionText
        )
        let adapter = PlanPreparationAdapter(serverFactory: { _, _, _, onMessage in
            peer.onMessage = onMessage
            return peer
        })
        let saved = RepositoryPlanPreparationReadback(
            identity: fixture.request.identity,
            state: .outcomeUnknown,
            threadID: "thread-101",
            turnID: nil,
            draftBytes: nil,
            error: "Turn dispatch may have occurred before its identity was persisted."
        )

        let recovered = try await adapter.restore(
            fixture.request,
            from: saved,
            context: PreparationLease(),
            allowedInstructionSources: fixture.allowedSources
        )

        XCTAssertEqual(recovered.state, .outcomeUnknown)
        XCTAssertEqual(recovered.threadID, "thread-101")
        XCTAssertNil(recovered.turnID)
        XCTAssertFalse(peer.calls.contains("thread/turns/list"))
        XCTAssertFalse(peer.calls.contains("thread/items/list"))
        XCTAssertTrue(Set(peer.calls).isDisjoint(with: [
            "thread/start", "turn/start", "thread/fork", "thread/resume", "turn/interrupt",
        ]))
    }

    func testCodexExecutableResolverPrefersVerifiedNestedNativeBinaryAndNeverWrapper() throws {
        let fixture = try CodexExecutableLayoutFixture()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let nested = try fixture.createNestedExecutable()
        _ = try fixture.createLegacyExecutable()
        _ = try fixture.createWrapper()
        var verifications: [(String, String)] = []

        let resolved = try CodexExecutionIdentity.resolveExecutable(
            applicationPath: fixture.application.path,
            codeVerifier: { verifications.append(($0, $1)) }
        )

        XCTAssertEqual(resolved, nested.path)
        XCTAssertEqual(verifications.map(\.0), [fixture.application.path, nested.path])
        XCTAssertEqual(verifications.map(\.1), ["com.openai.codex", "codex"])
        XCTAssertFalse(resolved.contains("/bin/codex"))
    }

    func testCodexExecutableResolverUsesVerifiedLegacyOnlyWhenNestedIsAbsent() throws {
        let fixture = try CodexExecutableLayoutFixture()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let legacy = try fixture.createLegacyExecutable()
        _ = try fixture.createWrapper()
        var verifications: [(String, String)] = []

        let resolved = try CodexExecutionIdentity.resolveExecutable(
            applicationPath: fixture.application.path,
            codeVerifier: { verifications.append(($0, $1)) }
        )

        XCTAssertEqual(resolved, legacy.path)
        XCTAssertEqual(verifications.map(\.0), [fixture.application.path, legacy.path])
        XCTAssertEqual(verifications.map(\.1), ["com.openai.codex", "codex"])
    }

    func testCodexExecutableResolverRejectsWrapperUnsafeComponentsAndInvalidExecutableKinds() throws {
        for defect in CodexExecutableLayoutFixture.Defect.allCases {
            let fixture = try CodexExecutableLayoutFixture()
            addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
            try fixture.install(defect)
            XCTAssertThrowsError(
                try CodexExecutionIdentity.resolveExecutable(
                    applicationPath: fixture.application.path,
                    codeVerifier: { _, _ in }
                ),
                "defect: \(defect)"
            )
        }
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

    private func makeStoredRecoveryHarness(
        fixture: PreparationAdapterFixture,
        recoveryService: AppPreparationService? = nil
    ) throws -> StoredPreparationRecoveryHarness {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let home = root.appendingPathComponent("selected-codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("selected global instructions".utf8).write(
            to: home.appendingPathComponent("AGENTS.md")
        )
        let context = try CodexExecutionContext(home: home, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.request.identity.registration,
            rootID: fixture.request.identity.rootID,
            proposalID: fixture.request.identity.proposalID,
            attemptID: UUID()
        )
        let request = RepositoryPlanPreparationRequest(
            identity: identity,
            sourceManifest: fixture.request.sourceManifest,
            snapshot: fixture.request.snapshot,
            projectionID: fixture.request.projectionID,
            projectionRevision: fixture.request.projectionRevision,
            codexContextID: context.id,
            model: fixture.request.model,
            effort: fixture.request.effort
        )
        let factoryUses = PreparationCounter()
        let client = ProjectExecutionSetupClient(
            plugin: nil,
            executionRoot: { root },
            contextAccessFactory: { selected, files in
                try CodexExecutionContextLease(
                    context: selected,
                    current: { try files.codexContext() },
                    resolve: { _ in .init(url: home, isStale: false) },
                    start: { _ in true },
                    stop: { _ in }
                )
            },
            planPreparationFactory: {
                factoryUses.increment()
                return recoveryService ?? AppPreparationService()
            }
        )
        return .init(
            client: client,
            request: request,
            factoryUses: factoryUses
        )
    }
}

private struct StoredPreparationRecoveryHarness {
    let client: ProjectExecutionSetupClient
    let request: RepositoryPlanPreparationRequest
    let factoryUses: PreparationCounter
}

private actor PreparationProgressRecorder {
    struct Observation: Sendable {
        let readback: RepositoryPlanPreparationReadback
        let calls: [String]
    }

    private(set) var values: [Observation] = []

    func record(
        _ readback: RepositoryPlanPreparationReadback,
        calls: [String]
    ) {
        values.append(.init(readback: readback, calls: calls))
    }
}

private struct CodexExecutableLayoutFixture {
    enum Defect: CaseIterable, CustomStringConvertible {
        case wrapperOnly
        case symlinkComponent
        case groupWritableComponent
        case worldWritableComponent
        case executableDirectory
        case nonExecutableFile

        var description: String {
            switch self {
            case .wrapperOnly: "wrapper-only"
            case .symlinkComponent: "symlink-component"
            case .groupWritableComponent: "group-writable-component"
            case .worldWritableComponent: "world-writable-component"
            case .executableDirectory: "executable-directory"
            case .nonExecutableFile: "non-executable-file"
            }
        }
    }

    let root: URL
    let application: URL

    private var resources: URL {
        application.appendingPathComponent("Contents/Resources", isDirectory: true)
    }

    private var nestedExecutable: URL {
        resources.appendingPathComponent(
            "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            isDirectory: false
        )
    }

    private var legacyExecutable: URL {
        resources.appendingPathComponent("codex", isDirectory: false)
    }

    private var wrapper: URL {
        resources.appendingPathComponent("codex-cli/bin/codex", isDirectory: false)
    }

    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        application = root.appendingPathComponent("ChatGPT.app", isDirectory: true)
        try FileManager.default.createDirectory(
            at: resources,
            withIntermediateDirectories: true
        )
        guard chmod(root.path, 0o700) == 0,
              chmod(application.path, 0o755) == 0,
              chmod(application.appendingPathComponent("Contents").path, 0o755) == 0,
              chmod(resources.path, 0o755) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func createNestedExecutable() throws -> URL {
        try createExecutable(at: nestedExecutable)
    }

    func createLegacyExecutable() throws -> URL {
        try createExecutable(at: legacyExecutable)
    }

    func createWrapper() throws -> URL {
        try createExecutable(at: wrapper)
    }

    func install(_ defect: Defect) throws {
        switch defect {
        case .wrapperOnly:
            _ = try createWrapper()
        case .symlinkComponent:
            let target = root.appendingPathComponent("linked-codex-cli", isDirectory: true)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(
                at: resources.appendingPathComponent("codex-cli", isDirectory: true),
                withDestinationURL: target
            )
            _ = try createNestedExecutable()
        case .groupWritableComponent:
            _ = try createNestedExecutable()
            guard chmod(resources.appendingPathComponent("codex-cli").path, 0o775) == 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
        case .worldWritableComponent:
            _ = try createNestedExecutable()
            guard chmod(resources.appendingPathComponent("codex-cli").path, 0o777) == 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
        case .executableDirectory:
            try FileManager.default.createDirectory(
                at: nestedExecutable,
                withIntermediateDirectories: true
            )
        case .nonExecutableFile:
            _ = try createExecutable(at: nestedExecutable)
            guard chmod(nestedExecutable.path, 0o644) == 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
    }

    private func createExecutable(at url: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("fixture".utf8).write(to: url)
        guard chmod(url.path, 0o755) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }
}

private actor AppPreparationService: PlanPreparationServicing {
    private var readback: RepositoryPlanPreparationReadback?
    private var contextLease: CodexExecutionContextLease?
    private(set) var contextID: UUID?
    private(set) var instructionSources: [String] = []
    private(set) var requestIdentity: RepositoryPlanPreparationIdentity?
    private(set) var closed = false
    private(set) var prepareCalls = 0
    private(set) var restoreCalls = 0
    private var failPrepareCleanupClose = false
    private var restoreResult: RepositoryPlanPreparationReadback?

    func prepare(_ request: RepositoryPlanPreparationRequest, context: CodexExecutionContextLease,
                 allowedInstructionSources: [String]) async throws -> RepositoryPlanPreparationReadback {
        prepareCalls += 1
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
    func restore(
        _ request: RepositoryPlanPreparationRequest,
        from readback: RepositoryPlanPreparationReadback,
        context: CodexExecutionContextLease,
        allowedInstructionSources: [String]
    ) async throws -> RepositoryPlanPreparationReadback {
        restoreCalls += 1
        contextLease = context
        contextID = context.context.id
        instructionSources = allowedInstructionSources
        requestIdentity = request.identity
        guard readback.identity == request.identity,
              let restoreResult,
              restoreResult.identity == request.identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        self.readback = restoreResult
        return restoreResult
    }
    func status(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback {
        guard let readback, readback.identity == identity else { throw RepositoryPlanPreparationError(code: .identityMismatch) }
        return readback
    }
    func cancel(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback { try await status(identity) }
    func close(_ identity: RepositoryPlanPreparationIdentity) async throws { _ = try await status(identity); contextLease?.release(); contextLease = nil; closed = true }
    func setPrepareCleanupCloseFailure(_ value: Bool) { failPrepareCleanupClose = value }
    func setRestoreResult(_ value: RepositoryPlanPreparationReadback) { restoreResult = value }
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

private final class StoredPreparationRecoveryPeer: ExecutionPeer, @unchecked Sendable {
    enum Terminal: Equatable {
        case completed
        case failed
        case interrupted
    }

    enum Mode {
        case terminal(Terminal)
        case inProgress
        case missingTurn
        case mismatchedThread
        case mismatchedTurn
        case mismatchedWorkingDirectory
        case notLoaded
        case incompletePagination
    }

    enum SetupFailure: CaseIterable, Equatable, CustomStringConvertible {
        case rejectedAccount
        case rejectedConfiguration

        var description: String {
            switch self {
            case .rejectedAccount: "rejected-account"
            case .rejectedConfiguration: "rejected-configuration"
            }
        }
    }

    var request: RepositoryPlanPreparationRequest
    let mode: Mode
    let projectionText: String
    let setupFailure: SetupFailure?
    var onMessage: (@Sendable (RPCObject) -> Void)?
    private(set) var calls: [String] = []
    private(set) var closeCount = 0
    private var setupAccepted = false

    init(
        request: RepositoryPlanPreparationRequest,
        terminal: Terminal,
        projectionText: String,
        setupFailure: SetupFailure? = nil
    ) {
        self.request = request
        mode = .terminal(terminal)
        self.projectionText = projectionText
        self.setupFailure = setupFailure
    }

    init(
        request: RepositoryPlanPreparationRequest,
        mode: Mode,
        projectionText: String
    ) {
        self.request = request
        self.mode = mode
        self.projectionText = projectionText
        setupFailure = nil
    }

    func acceptSetup() {
        setupAccepted = true
    }

    func send(_ message: [String: Any]) throws {}

    func close() throws {
        closeCount += 1
    }

    func call(_ method: String, _ parameters: RPCObject) async throws -> RPCObject {
        calls.append(method)
        switch method {
        case "initialize":
            return try RPCObject([:])
        case "account/read":
            return try RPCObject([
                "account": [
                    "type": setupFailure == .rejectedAccount && !setupAccepted
                        ? "apiKey"
                        : "chatgpt"
                ]
            ])
        case "config/read":
            return try RPCObject([
                "config": setupFailure == .rejectedConfiguration && !setupAccepted
                    ? [:]
                    : configuration()
            ])
        case "thread/read":
            return try RPCObject(["thread": thread()])
        case "thread/turns/list":
            return try RPCObject(turnsPage())
        case "thread/items/list":
            return try itemsPage(parameters)
        default:
            throw RepositoryPlanPreparationError(
                code: .invalidRequest,
                detail: "Unexpected recovery RPC \(method)."
            )
        }
    }

    private func configuration() -> [String: Any] {
        [
            "permissions": [
                PlanPreparationPolicy.permissionProfileID: [
                    "filesystem": [
                        ":root": "deny",
                        ":minimal": "read",
                        ":workspace_roots": [".": "read"],
                    ],
                    "network": ["enabled": false],
                ]
            ]
        ]
    }

    private func thread() -> [String: Any] {
        [
            "id": mode.isMismatchedThread ? "thread-other" : "thread-101",
            "cwd": mode.isMismatchedWorkingDirectory
                ? request.snapshot.rootPath
                : request.snapshot.workingPath,
            "modelProvider": "openai",
            "model": request.model,
            "reasoningEffort": request.effort,
            "status": ["type": "idle"],
            "turns": [],
        ]
    }

    private func turnsPage() -> [String: Any] {
        switch mode {
        case .missingTurn:
            return ["data": [], "nextCursor": NSNull()]
        case .mismatchedTurn:
            return ["data": [[
                "id": "turn-other",
                "status": "completed",
                "items": [],
                "itemsView": "notLoaded",
            ]], "nextCursor": NSNull()]
        default:
            return ["data": [[
                "id": "turn-101",
                "status": turnStatus,
                "items": [],
                "itemsView": itemsView,
            ]], "nextCursor": NSNull()]
        }
    }

    private func itemsPage(_ parameters: RPCObject) throws -> RPCObject {
        let object = try parameters.object()
        let cursor = object["cursor"] as? String
        switch mode {
        case .terminal(.completed):
            if cursor == nil {
                return try RPCObject(["data": [], "nextCursor": "items-page-2"])
            }
            return try RPCObject(["data": [[
                "turnId": "turn-101",
                "item": [
                    "id": "item-101",
                    "type": "agentMessage",
                    "text": projectionText,
                    "phase": "final_answer",
                ],
            ]], "nextCursor": NSNull()])
        case .notLoaded:
            return try RPCObject(["data": [], "nextCursor": "items-still-not-loaded"])
        case .incompletePagination:
            if cursor == nil {
                return try RPCObject(["data": [[
                    "turnId": "turn-101",
                    "item": [
                        "id": "item-101",
                        "type": "agentMessage",
                        "text": projectionText,
                        "phase": "final_answer",
                    ],
                ]], "nextCursor": "items-page-2"])
            }
            throw AppServerTransportError(
                message: "The remaining exact item page is unavailable.",
                outcomeUnknown: true
            )
        default:
            return try RPCObject(["data": [], "nextCursor": NSNull()])
        }
    }

    private var turnStatus: String {
        switch mode {
        case .terminal(.completed), .notLoaded, .incompletePagination:
            "completed"
        case .terminal(.failed):
            "failed"
        case .terminal(.interrupted):
            "interrupted"
        case .inProgress:
            "inProgress"
        case .missingTurn, .mismatchedThread, .mismatchedTurn,
                .mismatchedWorkingDirectory:
            "completed"
        }
    }

    private var itemsView: String {
        switch mode {
        case .terminal(.completed), .notLoaded, .incompletePagination:
            "notLoaded"
        default:
            "full"
        }
    }
}

private extension StoredPreparationRecoveryPeer.Mode {
    var isMismatchedThread: Bool {
        if case .mismatchedThread = self { return true }
        return false
    }

    var isMismatchedWorkingDirectory: Bool {
        if case .mismatchedWorkingDirectory = self { return true }
        return false
    }
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

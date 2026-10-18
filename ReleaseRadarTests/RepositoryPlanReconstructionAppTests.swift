import CryptoKit
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

@MainActor
final class RepositoryPlanReconstructionAppTests: XCTestCase {
    func testOnboardingCompletionRoutesToDiscoverableRepositoryPlanPreparation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ReleaseRadar-ReconstructionApp-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let model = AppModel(store: store)
        try await DashboardSampleData.seedIfNeeded(in: store)
        await model.loadDashboard()

        await model.reloadAfterOnboarding(projectID: DashboardSampleData.projectID)

        XCTAssertEqual(model.selection, .projectPlan(DashboardSampleData.projectID))
        await model.openRepositoryPlanReconstruction(projectID: DashboardSampleData.projectID)
        XCTAssertNotNil(
            model.repositoryPlanReconstruction(for: DashboardSampleData.projectID),
            "The project-plan destination must expose its source-selection preparation state."
        )
    }

    func testSelectedSourcesStartOnceAndPreparationStagesRemainObservable() async throws {
        let projectID = ProjectID(rawValue: "project-preparation")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(1))
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(identity: identity, state: .queued)],
            statusResponses: [
                readback(identity: identity, state: .running),
                readback(identity: identity, state: .readyForReview, draftBytes: Data("draft".utf8)),
            ]
        )
        let model = try makeModel(projectID: projectID, service: service)

        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-b",
            selected: true
        )
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )

        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.queued))
        let initialStarts = await service.startInvocations()
        let expectedInventory = inventory(projectID: projectID)
        XCTAssertEqual(
            initialStarts,
            [.init(consent: .init(
                inventory: expectedInventory,
                selectedSources: expectedInventory.sources.sorted {
                    Data($0.artifactID.utf8).lexicographicallyPrecedes(Data($1.artifactID.utf8))
                },
                target: target
            ))]
        )

        await model.refreshRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.running))
        await model.refreshRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.stage,
            .preparing(.readyForReview)
        )
        let statuses = await service.statusInvocations()
        let completedStarts = await service.startInvocations()
        XCTAssertEqual(statuses, [identity, identity])
        XCTAssertEqual(completedStarts.count, 1)
    }

    func testCancelUsesSameIdentityOnceAndAllowsFreshAttempt() async throws {
        let projectID = ProjectID(rawValue: "project-cancel")
        let firstIdentity = preparationIdentity(projectID: projectID, attemptID: uuid(2))
        let secondIdentity = preparationIdentity(projectID: projectID, attemptID: uuid(3))
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [
                readback(identity: firstIdentity, state: .queued),
                readback(identity: secondIdentity, state: .queued),
            ],
            cancelResponses: [readback(identity: firstIdentity, state: .cancelled)]
        )
        let model = try makeModel(projectID: projectID, service: service)
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )

        await model.startRepositoryPlanPreparation(projectID: projectID)
        await model.cancelRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.stage,
            .preparing(.cancelled)
        )
        let initialCancellations = await service.cancelInvocations()
        XCTAssertEqual(initialCancellations, [firstIdentity])

        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.queued))
        let starts = await service.startInvocations()
        let completedCancellations = await service.cancelInvocations()
        XCTAssertEqual(starts.count, 2)
        XCTAssertEqual(completedCancellations, [firstIdentity])
    }

    func testOutcomeUnknownCannotRedispatchAndStatusReconciliationAllowsFreshAttemptAfterFailure() async throws {
        let projectID = ProjectID(rawValue: "project-outcome-unknown")
        let unknownIdentity = preparationIdentity(projectID: projectID, attemptID: uuid(4))
        let retryIdentity = preparationIdentity(projectID: projectID, attemptID: uuid(5))
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [
                readback(identity: unknownIdentity, state: .outcomeUnknown),
                readback(identity: retryIdentity, state: .queued),
            ],
            statusResponses: [
                readback(identity: unknownIdentity, state: .failed, error: "Preparation failed")
            ]
        )
        let model = try makeModel(projectID: projectID, service: service)
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )

        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .outcomeUnknown)
        await model.startRepositoryPlanPreparation(projectID: projectID)
        let unknownStarts = await service.startInvocations()
        XCTAssertEqual(unknownStarts.count, 1)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .outcomeUnknown)

        await model.refreshRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.failed))
        let statuses = await service.statusInvocations()
        XCTAssertEqual(statuses, [unknownIdentity])

        await model.startRepositoryPlanPreparation(projectID: projectID)
        let completedStarts = await service.startInvocations()
        XCTAssertEqual(completedStarts.count, 2)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.queued))
    }

    func testOverlappingStartPublishesStartingAndDispatchesOneConsent() async throws {
        let projectID = ProjectID(rawValue: "project-overlap")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(6))
        let gate = RepositoryPlanPreparationStartGate()
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(identity: identity, state: .queued)],
            startGate: gate
        )
        let model = try makeModel(projectID: projectID, service: service)
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )

        let first = Task { await model.startRepositoryPlanPreparation(projectID: projectID) }
        await gate.waitUntilEntered()
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .starting)

        await model.startRepositoryPlanPreparation(projectID: projectID)
        let startsWhileSuspended = await service.startInvocations()
        XCTAssertEqual(startsWhileSuspended.count, 1)

        await gate.release()
        await first.value
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.queued))
        let completedStarts = await service.startInvocations()
        XCTAssertEqual(completedStarts.count, 1)
    }

    func testReopeningPreservesRunningReadyAndUnknownAttempts() async throws {
        let projectID = ProjectID(rawValue: "project-reopen")
        for (index, state) in [
            RepositoryPlanPreparationState.running,
            .readyForReview,
            .outcomeUnknown,
        ].enumerated() {
            let identity = preparationIdentity(
                projectID: projectID,
                attemptID: uuid(UInt8(10 + index))
            )
            let service = RepositoryPlanPreparationServiceSpy(
                startResponses: [readback(
                    identity: identity,
                    state: state,
                    draftBytes: state == .readyForReview ? Data("draft".utf8) : nil
                )]
            )
            let loader = RepositoryPlanSourceInventoryLoaderSpy(
                responses: [inventory(projectID: projectID)]
            )
            let model = try makeModel(
                projectID: projectID,
                service: service,
                inventoryLoader: loader
            )
            await model.openRepositoryPlanReconstruction(projectID: projectID)
            model.setRepositoryPlanSourceSelected(
                projectID: projectID,
                artifactID: "source-a",
                selected: true
            )
            await model.startRepositoryPlanPreparation(projectID: projectID)
            let before = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))

            await model.openRepositoryPlanReconstruction(projectID: projectID)

            XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID), before)
            XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.preparation?.identity, identity)
            let loadCount = await loader.invocationCount()
            let targetCount = await service.targetInvocationCount()
            XCTAssertEqual(loadCount, 1)
            XCTAssertEqual(targetCount, 1)
        }
    }

    func testUnknownReconciliationClosesExactAttemptOrRetainsItOnFailure() async throws {
        let projectID = ProjectID(rawValue: "project-reconcile")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(20))
        let replacement = preparationIdentity(projectID: projectID, attemptID: uuid(21))
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [
                readback(identity: identity, state: .outcomeUnknown),
                readback(identity: replacement, state: .queued),
            ],
            reconcileResponses: [
                readback(identity: identity, state: .failed, error: "Attempt closure confirmed.")
            ]
        )
        let model = try makeModel(projectID: projectID, service: service)
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(projectID: projectID, artifactID: "source-a", selected: true)
        await model.startRepositoryPlanPreparation(projectID: projectID)

        await model.reconcileRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.failed))
        let reconciliations = await service.reconcileInvocations()
        XCTAssertEqual(reconciliations, [identity])
        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.preparation?.identity, replacement)

        let uncertainProjectID = ProjectID(rawValue: "project-reconcile-failure")
        let uncertainIdentity = preparationIdentity(projectID: uncertainProjectID, attemptID: uuid(22))
        let failingService = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(identity: uncertainIdentity, state: .outcomeUnknown)],
            reconcileErrorCodes: [.outcomeUnknown]
        )
        let failingModel = try makeModel(projectID: uncertainProjectID, service: failingService)
        await failingModel.openRepositoryPlanReconstruction(projectID: uncertainProjectID)
        failingModel.setRepositoryPlanSourceSelected(
            projectID: uncertainProjectID,
            artifactID: "source-a",
            selected: true
        )
        await failingModel.startRepositoryPlanPreparation(projectID: uncertainProjectID)
        await failingModel.reconcileRepositoryPlanPreparation(projectID: uncertainProjectID)

        XCTAssertEqual(failingModel.repositoryPlanReconstruction(for: uncertainProjectID)?.stage, .outcomeUnknown)
        XCTAssertEqual(
            failingModel.repositoryPlanReconstruction(for: uncertainProjectID)?.preparation?.identity,
            uncertainIdentity
        )
        await failingModel.startRepositoryPlanPreparation(projectID: uncertainProjectID)
        let failedReconciliationStarts = await failingService.startInvocations()
        XCTAssertEqual(failedReconciliationStarts.count, 1)
    }

    func testTerminalAttemptThenPredispatchFailureCanReloadDisclosureAndRetry() async throws {
        let projectID = ProjectID(rawValue: "project-terminal-retry")
        let terminalIdentity = preparationIdentity(projectID: projectID, attemptID: uuid(23))
        let retryIdentity = preparationIdentity(projectID: projectID, attemptID: uuid(24))
        let displayed = inventory(projectID: projectID)
        let loader = RepositoryPlanSourceInventoryLoaderSpy(responses: [displayed, displayed])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [
                readback(identity: terminalIdentity, state: .cancelled),
                readback(identity: retryIdentity, state: .queued),
            ]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            inventoryLoader: loader
        )
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(projectID: projectID, artifactID: "source-a", selected: true)
        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.cancelled))

        await service.failNextStart(.invalidRequest)
        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .failed)
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.preparation?.identity,
            terminalIdentity
        )

        await model.openRepositoryPlanReconstruction(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .selectingSources)
        XCTAssertNil(model.repositoryPlanReconstruction(for: projectID)?.preparation)
        let loadCount = await loader.invocationCount()
        XCTAssertEqual(loadCount, 2)

        model.setRepositoryPlanSourceSelected(projectID: projectID, artifactID: "source-a", selected: true)
        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.preparation?.identity,
            retryIdentity
        )
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.queued))
    }

    func testStartConsentMatchesDisplayedInventorySourcesAndTarget() async throws {
        let projectID = ProjectID(rawValue: "project-consent")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(30))
        let displayed = inventory(projectID: projectID)
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(identity: identity, state: .queued)]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            inventoryLoader: .init(responses: [displayed])
        )
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.inventory, displayed)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.target, target)
        model.setRepositoryPlanSourceSelected(projectID: projectID, artifactID: "source-a", selected: true)

        await model.startRepositoryPlanPreparation(projectID: projectID)

        let startInvocations = await service.startInvocations()
        let consent = try XCTUnwrap(startInvocations.first?.consent)
        XCTAssertEqual(consent.inventory, displayed)
        XCTAssertEqual(consent.selectedSources, [displayed.sources[1]])
        XCTAssertEqual(consent.target, target)
    }

    func testSourceChangeRequiresFreshUnselectedDisclosureAndUnavailableTargetBlocksStart() async throws {
        let projectID = ProjectID(rawValue: "project-source-change")
        let original = inventory(projectID: projectID)
        let changed = inventory(
            projectID: projectID,
            sourceADigest: String(repeating: "d", count: 64)
        )
        let loader = RepositoryPlanSourceInventoryLoaderSpy(responses: [original, changed])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [],
            startErrorCodes: [.sourceChanged]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            inventoryLoader: loader
        )
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(projectID: projectID, artifactID: "source-a", selected: true)

        await model.startRepositoryPlanPreparation(projectID: projectID)

        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.inventory, changed)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.selectedArtifactIDs, [])
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .selectingSources)
        let changedSourceStarts = await service.startInvocations()
        XCTAssertEqual(changedSourceStarts.count, 1)

        let unavailableProjectID = ProjectID(rawValue: "project-target-unavailable")
        let unavailableService = RepositoryPlanPreparationServiceSpy(
            startResponses: [],
            targetUnavailable: true
        )
        let unavailableModel = try makeModel(
            projectID: unavailableProjectID,
            service: unavailableService
        )
        await unavailableModel.openRepositoryPlanReconstruction(projectID: unavailableProjectID)
        XCTAssertEqual(
            unavailableModel.repositoryPlanReconstruction(for: unavailableProjectID)?.stage,
            .failed
        )
        let unavailableStarts = await unavailableService.startInvocations()
        XCTAssertTrue(unavailableStarts.isEmpty)
    }

    func testProductionServiceReservesBeforeCaptureAndRejectsOverlappingStart() async throws {
        let fixture = try serviceFixture(projectID: .init(rawValue: "service-overlap"))
        let captureGate = RepositoryPlanPreparationStartGate()
        let capture = RepositoryPlanSourceCaptureSpy(
            manifest: fixture.manifest,
            gate: captureGate
        )
        let identity = preparationIdentity(
            projectID: fixture.consent.inventory.projectID,
            attemptID: uuid(41)
        )
        let client = RepositoryPlanPreparationClientSpy(
            target: fixture.consent.target,
            prepareResponses: [readback(identity: identity, state: .queued)],
            statusResponses: [readback(identity: identity, state: .running)],
            cancelResponses: [readback(identity: identity, state: .cancelled)]
        )
        let service = RepositoryPlanPreparationService(
            client: client,
            sourceCapture: { consent in try await capture.capture(consent) },
            snapshotRoot: { fixture.snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                identity.attemptID,
                uuid(42),
                uuid(43),
                uuid(44),
            ]).next
        )

        let first = Task { try await service.start(consent: fixture.consent) }
        await captureGate.waitUntilEntered()
        do {
            _ = try await service.start(consent: fixture.consent)
            XCTFail("Expected overlapping start rejection")
        } catch let error as RepositoryPlanPreparationError {
            XCTAssertEqual(error.code, .invalidRequest)
        }
        let capturesWhileSuspended = await capture.invocationCount()
        let preparesWhileSuspended = await client.prepareInvocationCount()
        XCTAssertEqual(capturesWhileSuspended, 1)
        XCTAssertEqual(preparesWhileSuspended, 0)

        await captureGate.release()
        let firstReadback = try await first.value
        XCTAssertEqual(firstReadback.identity, identity)
        let completedCaptures = await capture.invocationCount()
        let completedPrepares = await client.prepareInvocationCount()
        XCTAssertEqual(completedCaptures, 1)
        XCTAssertEqual(completedPrepares, 1)
        _ = try await service.status(identity: identity)
        _ = try await service.cancel(identity: identity)
        let statuses = await client.statusInvocations()
        let cancellations = await client.cancelInvocations()
        XCTAssertEqual(statuses, [identity])
        XCTAssertEqual(cancellations, [identity])
    }

    func testProductionServiceReconcilesUnknownOnlyAfterExactClose() async throws {
        let fixture = try serviceFixture(projectID: .init(rawValue: "service-reconcile"))
        let identity = preparationIdentity(
            projectID: fixture.consent.inventory.projectID,
            attemptID: uuid(50)
        )
        let replacement = preparationIdentity(
            projectID: fixture.consent.inventory.projectID,
            attemptID: uuid(53)
        )
        let unknown = readback(identity: identity, state: .outcomeUnknown, error: "Connection lost")
        let client = RepositoryPlanPreparationClientSpy(
            target: fixture.consent.target,
            prepareResponses: [unknown, readback(identity: replacement, state: .queued)],
            statusResponses: [unknown]
        )
        let service = RepositoryPlanPreparationService(
            client: client,
            sourceCapture: { _ in fixture.manifest },
            snapshotRoot: { fixture.snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                identity.attemptID, uuid(51),
                replacement.attemptID, uuid(54),
            ]).next
        )
        let initial = try await service.start(consent: fixture.consent)
        XCTAssertEqual(initial.state, .outcomeUnknown)

        let reconciled = try await service.reconcile(identity: identity)
        XCTAssertEqual(reconciled.identity, identity)
        XCTAssertEqual(reconciled.state, .failed)
        let successfulCloses = await client.closeInvocations()
        XCTAssertEqual(successfulCloses, [identity])
        let restarted = try await service.start(consent: fixture.consent)
        XCTAssertEqual(restarted.identity, replacement)

        let retainedIdentity = preparationIdentity(
            projectID: fixture.consent.inventory.projectID,
            attemptID: uuid(60)
        )
        let retainedUnknown = readback(
            identity: retainedIdentity,
            state: .outcomeUnknown,
            error: "Connection lost"
        )
        let failingClient = RepositoryPlanPreparationClientSpy(
            target: fixture.consent.target,
            prepareResponses: [retainedUnknown],
            statusResponses: [retainedUnknown],
            closeError: RepositoryPlanPreparationError(code: .outcomeUnknown)
        )
        let failingService = RepositoryPlanPreparationService(
            client: failingClient,
            sourceCapture: { _ in fixture.manifest },
            snapshotRoot: { fixture.snapshotRoot.appendingPathComponent("failing") },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                retainedIdentity.attemptID, uuid(61), uuid(62), uuid(63),
            ]).next
        )
        _ = try await failingService.start(consent: fixture.consent)
        await XCTAssertThrowsErrorAsync { try await failingService.reconcile(identity: retainedIdentity) }
        await XCTAssertThrowsErrorAsync { try await failingService.start(consent: fixture.consent) }
        let failedClosePrepares = await failingClient.prepareInvocationCount()
        let failedCloses = await failingClient.closeInvocations()
        XCTAssertEqual(failedClosePrepares, 1)
        XCTAssertEqual(failedCloses, [retainedIdentity])
    }

    func testProductionServiceRetainsExactIdentityWhenTerminalCloseFailsThenReconciles() async throws {
        let fixture = try serviceFixture(projectID: .init(rawValue: "service-terminal-close-retry"))
        let identity = preparationIdentity(
            projectID: fixture.consent.inventory.projectID,
            attemptID: uuid(48)
        )
        let client = RepositoryPlanPreparationClientSpy(
            target: fixture.consent.target,
            prepareResponses: [readback(identity: identity, state: .running)],
            statusResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: Data("draft".utf8)
            )],
            closeErrorCodes: [.outcomeUnknown]
        )
        let service = RepositoryPlanPreparationService(
            client: client,
            sourceCapture: { _ in fixture.manifest },
            snapshotRoot: { fixture.snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                identity.attemptID, uuid(49), uuid(50),
            ]).next
        )

        _ = try await service.start(consent: fixture.consent)
        do {
            _ = try await service.status(identity: identity)
            XCTFail("Expected physical-close uncertainty")
        } catch let error as RepositoryPlanPreparationError {
            XCTAssertEqual(error.code, .outcomeUnknown)
        }

        let reconciled = try await service.reconcile(identity: identity)
        XCTAssertEqual(reconciled.identity, identity)
        XCTAssertEqual(reconciled.state, .failed)
        let closes = await client.closeInvocations()
        XCTAssertEqual(closes, [identity, identity])
    }

    func testProductionServiceDefinitiveCancelErrorReconcilesRunningIdentityWithoutClose() async throws {
        let fixture = try serviceFixture(projectID: .init(rawValue: "service-cancel-reconcile"))
        let identity = preparationIdentity(
            projectID: fixture.consent.inventory.projectID,
            attemptID: uuid(51)
        )
        let client = RepositoryPlanPreparationClientSpy(
            target: fixture.consent.target,
            prepareResponses: [readback(identity: identity, state: .running)],
            statusResponses: [readback(identity: identity, state: .running)],
            cancelErrorCodes: [.invalidRequest],
            closeErrorCodes: [.identityMismatch]
        )
        let service = RepositoryPlanPreparationService(
            client: client,
            sourceCapture: { _ in fixture.manifest },
            snapshotRoot: { fixture.snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                identity.attemptID, uuid(52), uuid(53),
            ]).next
        )

        _ = try await service.start(consent: fixture.consent)
        do {
            _ = try await service.cancel(identity: identity)
            XCTFail("Expected definitive cancellation failure")
        } catch let error as RepositoryPlanPreparationError {
            XCTAssertEqual(error.code, .invalidRequest)
        }

        let reconciled = try await service.reconcile(identity: identity)
        XCTAssertEqual(reconciled.identity, identity)
        XCTAssertEqual(reconciled.state, .running)
        let cancellations = await client.cancelInvocations()
        let statuses = await client.statusInvocations()
        let closes = await client.closeInvocations()
        XCTAssertEqual(cancellations, [identity])
        XCTAssertEqual(statuses, [identity])
        XCTAssertTrue(closes.isEmpty)
    }

    func testProductionServiceRejectsRecapturedSourceOrTargetChangeBeforePrepare() async throws {
        let fixture = try serviceFixture(projectID: .init(rawValue: "service-source-change"))
        let changedManifest = RepositoryPlanSourceManifest(
            projectID: fixture.manifest.projectID,
            rootID: fixture.manifest.rootID,
            rootPath: fixture.manifest.rootPath,
            registration: fixture.manifest.registration,
            repositoryID: fixture.manifest.repositoryID,
            acceptedCatalogVersion: fixture.manifest.acceptedCatalogVersion,
            acceptedCatalogDigest: fixture.manifest.acceptedCatalogDigest,
            sources: fixture.manifest.sources.map {
                let bytes = Data("changed bytes".utf8)
                return .init(
                    artifactID: $0.artifactID,
                    path: $0.path,
                    contentSHA256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
                    lifecycle: $0.lifecycle,
                    authority: $0.authority,
                    bytes: bytes
                )
            }
        )
        let client = RepositoryPlanPreparationClientSpy(
            target: fixture.consent.target,
            prepareResponses: []
        )
        let service = RepositoryPlanPreparationService(
            client: client,
            sourceCapture: { _ in changedManifest },
            snapshotRoot: { fixture.snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                uuid(70), uuid(71), uuid(72),
            ]).next
        )
        await XCTAssertThrowsErrorAsync { try await service.start(consent: fixture.consent) }
        let changedSourcePrepares = await client.prepareInvocationCount()
        XCTAssertEqual(changedSourcePrepares, 0)

        let changedTarget = RepositoryPlanPreparationTarget(
            codexContextID: uuid(201),
            destinationLabel: "Changed context",
            model: fixture.consent.target.model,
            effort: fixture.consent.target.effort
        )
        let targetClient = RepositoryPlanPreparationClientSpy(
            target: changedTarget,
            prepareResponses: []
        )
        let targetService = RepositoryPlanPreparationService(
            client: targetClient,
            sourceCapture: { _ in fixture.manifest },
            snapshotRoot: { fixture.snapshotRoot.appendingPathComponent("target") },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                uuid(73), uuid(74), uuid(75),
            ]).next
        )
        await XCTAssertThrowsErrorAsync { try await targetService.start(consent: fixture.consent) }
        let changedTargetPrepares = await targetClient.prepareInvocationCount()
        XCTAssertEqual(changedTargetPrepares, 0)
    }

    private func makeModel(
        projectID: ProjectID,
        service: RepositoryPlanPreparationServiceSpy,
        inventoryLoader: RepositoryPlanSourceInventoryLoaderSpy? = nil
    ) throws -> AppModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ReleaseRadar-ReconstructionApp-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let defaultInventory = inventory(projectID: projectID)
        let loader = inventoryLoader ?? RepositoryPlanSourceInventoryLoaderSpy(
            responses: [defaultInventory]
        )
        return AppModel(
            store: store,
            externalServicesSuppressed: true,
            repositoryPlanSourceLoader: { _, _, loadedProjectID in
                XCTAssertEqual(loadedProjectID, projectID)
                return try await loader.load(projectID: loadedProjectID)
            },
            repositoryPlanPreparationService: service
        )
    }

    private func inventory(
        projectID: ProjectID,
        sourceADigest: String = String(repeating: "a", count: 64)
    ) -> RepositoryPlanSourceInventory {
        let sources = [
            RepositoryPlanSourceOption(
                artifactID: "source-b",
                path: "docs/plan-b.md",
                contentSHA256: String(repeating: "b", count: 64),
                lifecycle: .active,
                authority: .supporting
            ),
            RepositoryPlanSourceOption(
                artifactID: "source-a",
                path: "docs/plan-a.md",
                contentSHA256: sourceADigest,
                lifecycle: .active,
                authority: .controlling
            ),
        ]
        return .init(
            projectID: projectID,
            rootID: "root-\(projectID.rawValue)",
            registration: .init(
                projectID: projectID,
                registrationID: "registration-\(projectID.rawValue)",
                requestGeneration: 1
            ),
            repositoryID: "9141d1ea-3342-4462-9e06-6934d816c03f",
            acceptedCatalogVersion: 7,
            acceptedCatalogDigest: String(repeating: "c", count: 64),
            sources: sources
        )
    }

    private var target: RepositoryPlanPreparationTarget {
        .init(
            codexContextID: uuid(200),
            destinationLabel: "Selected Codex context",
            model: "gpt-6-astra",
            effort: "high"
        )
    }

    private func serviceFixture(
        projectID: ProjectID
    ) throws -> (
        consent: RepositoryPlanPreparationConsent,
        manifest: RepositoryPlanSourceManifest,
        snapshotRoot: URL
    ) {
        let snapshotRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ReleaseRadar-PreparationService-\(UUID().uuidString)",
                isDirectory: true
            )
        addTeardownBlock { try? FileManager.default.removeItem(at: snapshotRoot) }
        let bytes = Data("selected source bytes".utf8)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-\(projectID.rawValue)",
            requestGeneration: 1
        )
        let source = RepositoryPlanCapturedSource(
            artifactID: "source-a",
            path: "docs/plan-a.md",
            contentSHA256: digest,
            lifecycle: .active,
            authority: .controlling,
            bytes: bytes
        )
        let manifest = RepositoryPlanSourceManifest(
            projectID: projectID,
            rootID: "root-\(projectID.rawValue)",
            rootPath: "/fixture/\(projectID.rawValue)",
            registration: registration,
            repositoryID: "9141d1ea-3342-4462-9e06-6934d816c03f",
            acceptedCatalogVersion: 7,
            acceptedCatalogDigest: String(repeating: "c", count: 64),
            sources: [source]
        )
        let inventory = RepositoryPlanSourceInventory(
            projectID: projectID,
            rootID: manifest.rootID,
            registration: registration,
            repositoryID: manifest.repositoryID,
            acceptedCatalogVersion: manifest.acceptedCatalogVersion,
            acceptedCatalogDigest: manifest.acceptedCatalogDigest,
            sources: [.init(
                artifactID: source.artifactID,
                path: source.path,
                contentSHA256: source.contentSHA256,
                lifecycle: source.lifecycle,
                authority: source.authority
            )]
        )
        return (
            RepositoryPlanPreparationConsent(
                inventory: inventory,
                selectedSources: inventory.sources,
                target: target
            ),
            manifest,
            snapshotRoot
        )
    }

    private func preparationIdentity(
        projectID: ProjectID,
        attemptID: UUID
    ) -> RepositoryPlanPreparationIdentity {
        .init(
            registration: .init(
                projectID: projectID,
                registrationID: "registration-\(projectID.rawValue)",
                requestGeneration: 1
            ),
            rootID: "root-\(projectID.rawValue)",
            proposalID: .init(rawValue: "proposal-\(projectID.rawValue)"),
            attemptID: attemptID
        )
    }

    private func readback(
        identity: RepositoryPlanPreparationIdentity,
        state: RepositoryPlanPreparationState,
        draftBytes: Data? = nil,
        error: String? = nil
    ) -> RepositoryPlanPreparationReadback {
        .init(
            identity: identity,
            state: state,
            threadID: state == .queued ? nil : "thread-\(identity.attemptID.uuidString)",
            turnID: state == .queued ? nil : "turn-\(identity.attemptID.uuidString)",
            draftBytes: draftBytes,
            error: error
        )
    }

    private func uuid(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private actor RepositoryPlanPreparationServiceSpy: RepositoryPlanPreparationServicing {
    struct StartInvocation: Equatable {
        let consent: RepositoryPlanPreparationConsent
    }

    private var starts: [StartInvocation] = []
    private var statuses: [RepositoryPlanPreparationIdentity] = []
    private var cancellations: [RepositoryPlanPreparationIdentity] = []
    private var reconciliations: [RepositoryPlanPreparationIdentity] = []
    private var targetCalls = 0
    private var startResponses: [RepositoryPlanPreparationReadback]
    private var statusResponses: [RepositoryPlanPreparationReadback]
    private var cancelResponses: [RepositoryPlanPreparationReadback]
    private var reconcileResponses: [RepositoryPlanPreparationReadback]
    private var startErrorCodes: [RepositoryPlanPreparationError.Code]
    private var reconcileErrorCodes: [RepositoryPlanPreparationError.Code]
    private let startGate: RepositoryPlanPreparationStartGate?
    private let targetUnavailable: Bool

    init(
        startResponses: [RepositoryPlanPreparationReadback],
        statusResponses: [RepositoryPlanPreparationReadback] = [],
        cancelResponses: [RepositoryPlanPreparationReadback] = [],
        reconcileResponses: [RepositoryPlanPreparationReadback] = [],
        startErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        reconcileErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        startGate: RepositoryPlanPreparationStartGate? = nil,
        targetUnavailable: Bool = false
    ) {
        self.startResponses = startResponses
        self.statusResponses = statusResponses
        self.cancelResponses = cancelResponses
        self.reconcileResponses = reconcileResponses
        self.startErrorCodes = startErrorCodes
        self.reconcileErrorCodes = reconcileErrorCodes
        self.startGate = startGate
        self.targetUnavailable = targetUnavailable
    }

    func target() async throws -> RepositoryPlanPreparationTarget {
        targetCalls += 1
        if targetUnavailable {
            throw CodexExecutionContextError.selectionRequired
        }
        return .init(
            codexContextID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 200)),
            destinationLabel: "Selected Codex context",
            model: "gpt-6-astra",
            effort: "high"
        )
    }

    func start(consent: RepositoryPlanPreparationConsent) async throws -> RepositoryPlanPreparationReadback {
        starts.append(.init(consent: consent))
        if let startGate { await startGate.suspend() }
        if !startErrorCodes.isEmpty {
            throw RepositoryPlanPreparationError(code: startErrorCodes.removeFirst())
        }
        return startResponses.removeFirst()
    }

    func status(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        statuses.append(identity)
        return statusResponses.removeFirst()
    }

    func cancel(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        cancellations.append(identity)
        return cancelResponses.removeFirst()
    }

    func reconcile(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        reconciliations.append(identity)
        if !reconcileErrorCodes.isEmpty {
            throw RepositoryPlanPreparationError(code: reconcileErrorCodes.removeFirst())
        }
        return reconcileResponses.removeFirst()
    }

    func startInvocations() -> [StartInvocation] { starts }
    func statusInvocations() -> [RepositoryPlanPreparationIdentity] { statuses }
    func cancelInvocations() -> [RepositoryPlanPreparationIdentity] { cancellations }
    func reconcileInvocations() -> [RepositoryPlanPreparationIdentity] { reconciliations }
    func targetInvocationCount() -> Int { targetCalls }

    func failNextStart(_ code: RepositoryPlanPreparationError.Code) {
        startErrorCodes.append(code)
    }
}

private actor RepositoryPlanSourceInventoryLoaderSpy {
    private var responses: [RepositoryPlanSourceInventory]
    private var calls = 0

    init(responses: [RepositoryPlanSourceInventory]) {
        self.responses = responses
    }

    func load(projectID: ProjectID) throws -> RepositoryPlanSourceInventory {
        calls += 1
        guard !responses.isEmpty else {
            throw RepositoryPlanPreparationError(code: .invalidRequest)
        }
        let response = responses.removeFirst()
        guard response.projectID == projectID else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        return response
    }

    func invocationCount() -> Int { calls }
}

private actor RepositoryPlanPreparationStartGate {
    private var entered = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func suspend() async {
        entered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { continuation in
            enteredContinuations.append(continuation)
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor RepositoryPlanSourceCaptureSpy {
    private let manifest: RepositoryPlanSourceManifest
    private let gate: RepositoryPlanPreparationStartGate?
    private var calls = 0

    init(
        manifest: RepositoryPlanSourceManifest,
        gate: RepositoryPlanPreparationStartGate? = nil
    ) {
        self.manifest = manifest
        self.gate = gate
    }

    func capture(
        _ consent: RepositoryPlanPreparationConsent
    ) async throws -> RepositoryPlanSourceManifest {
        calls += 1
        if let gate { await gate.suspend() }
        guard consent.inventory.projectID == manifest.projectID else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        return manifest
    }

    func invocationCount() -> Int { calls }
}

private actor RepositoryPlanPreparationClientSpy: RepositoryPlanPreparationClienting {
    private let selectedTarget: RepositoryPlanPreparationTarget
    private var prepareResponses: [RepositoryPlanPreparationReadback]
    private var statusResponses: [RepositoryPlanPreparationReadback]
    private var cancelResponses: [RepositoryPlanPreparationReadback]
    private var cancelErrorCodes: [RepositoryPlanPreparationError.Code]
    private var closeErrorCodes: [RepositoryPlanPreparationError.Code]
    private var prepares: [RepositoryPlanPreparationRequest] = []
    private var statuses: [RepositoryPlanPreparationIdentity] = []
    private var cancellations: [RepositoryPlanPreparationIdentity] = []
    private var closes: [RepositoryPlanPreparationIdentity] = []

    init(
        target: RepositoryPlanPreparationTarget,
        prepareResponses: [RepositoryPlanPreparationReadback],
        statusResponses: [RepositoryPlanPreparationReadback] = [],
        cancelResponses: [RepositoryPlanPreparationReadback] = [],
        cancelErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        closeError: RepositoryPlanPreparationError? = nil,
        closeErrorCodes: [RepositoryPlanPreparationError.Code] = []
    ) {
        selectedTarget = target
        self.prepareResponses = prepareResponses
        self.statusResponses = statusResponses
        self.cancelResponses = cancelResponses
        self.cancelErrorCodes = cancelErrorCodes
        self.closeErrorCodes = closeError.map { [$0.code] } ?? closeErrorCodes
    }

    func target(model: String, effort: String) async throws -> RepositoryPlanPreparationTarget {
        guard selectedTarget.model == model, selectedTarget.effort == effort else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        return selectedTarget
    }

    func prepare(
        _ request: RepositoryPlanPreparationRequest
    ) async throws -> RepositoryPlanPreparationReadback {
        prepares.append(request)
        return prepareResponses.removeFirst()
    }

    func status(
        _ identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        statuses.append(identity)
        return statusResponses.removeFirst()
    }

    func cancel(
        _ identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        cancellations.append(identity)
        if !cancelErrorCodes.isEmpty {
            throw RepositoryPlanPreparationError(code: cancelErrorCodes.removeFirst())
        }
        return cancelResponses.removeFirst()
    }

    func close(_ identity: RepositoryPlanPreparationIdentity) async throws {
        closes.append(identity)
        if !closeErrorCodes.isEmpty {
            throw RepositoryPlanPreparationError(code: closeErrorCodes.removeFirst())
        }
    }

    func prepareInvocationCount() -> Int { prepares.count }
    func statusInvocations() -> [RepositoryPlanPreparationIdentity] { statuses }
    func cancelInvocations() -> [RepositoryPlanPreparationIdentity] { cancellations }
    func closeInvocations() -> [RepositoryPlanPreparationIdentity] { closes }
}

private final class RepositoryPlanPreparationIdentityGenerator: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UUID]

    init(values: [UUID]) {
        self.values = values
    }

    func next() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        precondition(!values.isEmpty, "The identity fixture exhausted its deterministic values.")
        return values.removeFirst()
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @Sendable () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {}
}

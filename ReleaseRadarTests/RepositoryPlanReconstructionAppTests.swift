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
        let draft = preparedDraft(projectID: projectID)
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(identity: identity, state: .queued)],
            statusResponses: [
                readback(identity: identity, state: .running),
                readback(
                    identity: identity,
                    state: .readyForReview,
                    draftBytes: draft.source.projectionBytes
                ),
            ],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: .init(responses: [preview(for: draft.originalProjection)])
        )

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
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .reviewing)
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
            let draft = preparedDraft(projectID: projectID)
            let service = RepositoryPlanPreparationServiceSpy(
                startResponses: [readback(
                    identity: identity,
                    state: state,
                    draftBytes: state == .readyForReview ? draft.source.projectionBytes : nil
                )],
                reviewDraftResponses: state == .readyForReview
                    ? [draft]
                    : []
            )
            let loader = RepositoryPlanSourceInventoryLoaderSpy(
                responses: [inventory(projectID: projectID)]
            )
            let model = try makeModel(
                projectID: projectID,
                service: service,
                inventoryLoader: loader,
                previewSpy: state == .readyForReview
                    ? .init(responses: [preview(for: draft.originalProjection)])
                    : nil
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

    func testReadyPreparationLoadsExactDraftAndEntersReviewWithoutMutatingLivePlan() async throws {
        let projectID = ProjectID(rawValue: "project-ready-review")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(80))
        let draft = preparedDraft(projectID: projectID)
        let expectedPreview = preview(for: draft.originalProjection)
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let previewSpy = RepositoryPlanPreviewSpy(responses: [expectedPreview])
        let model = try makeModel(projectID: projectID, service: service, previewSpy: previewSpy)
        let before = try await liveGraphCounts(model.onboardingStore)

        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)

        let presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        let review = try XCTUnwrap(presentation.review)
        XCTAssertEqual(presentation.stage, .reviewing)
        XCTAssertEqual(review.source, draft.source)
        XCTAssertEqual(review.originalProjection, draft.originalProjection)
        XCTAssertEqual(review.reviewedProjection, draft.originalProjection)
        XCTAssertEqual(review.comparisons, expectedPreview.comparisons)
        XCTAssertEqual(review.blockers, expectedPreview.blockers)
        XCTAssertTrue(review.corrections.isEmpty)
        XCTAssertTrue(review.exclusions.isEmpty)
        XCTAssertFalse(review.authorityConfirmed)
        XCTAssertNil(review.savedReadback)
        let reviewDraftInvocations = await service.reviewDraftInvocations()
        XCTAssertEqual(reviewDraftInvocations, [identity])
        let previewInvocations = await previewSpy.invocations()
        XCTAssertEqual(previewInvocations.count, 1)
        XCTAssertEqual(previewInvocations[0].source, draft.source)
        XCTAssertEqual(previewInvocations[0].reviewedProjection, draft.originalProjection)
        XCTAssertTrue(previewInvocations[0].corrections.isEmpty)
        XCTAssertTrue(previewInvocations[0].explicitMappings.isEmpty)
        let after = try await liveGraphCounts(model.onboardingStore)
        XCTAssertEqual(after, before)
    }

    func testReadyReviewLoadFailureRetainsExactDraftAndRetriesWithoutRedispatch() async throws {
        let projectID = ProjectID(rawValue: "project-review-retry")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(97))
        let draft = preparedDraft(projectID: projectID)
        let ready = readback(
            identity: identity,
            state: .readyForReview,
            draftBytes: draft.source.projectionBytes
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(identity: identity, state: .running)],
            statusResponses: [ready],
            reviewDraftResponses: [draft, draft]
        )
        let previewSpy = RepositoryPlanPreviewSpy(
            responses: [preview(for: draft.originalProjection)],
            failureCodes: [.sourceChanged]
        )
        let model = try makeModel(projectID: projectID, service: service, previewSpy: previewSpy)
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .preparing(.running))

        await model.refreshRepositoryPlanPreparation(projectID: projectID)

        var presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .reviewLoadFailed)
        XCTAssertEqual(presentation.preparation, ready)
        XCTAssertNil(presentation.review)
        XCTAssertTrue(presentation.message?.lowercased().contains("review") == true)
        let startsBeforeRetry = await service.startInvocations()
        let statusesBeforeRetry = await service.statusInvocations()
        let draftsBeforeRetry = await service.reviewDraftInvocations()
        XCTAssertEqual(startsBeforeRetry.count, 1)
        XCTAssertEqual(statusesBeforeRetry, [identity])
        XCTAssertEqual(draftsBeforeRetry, [identity])

        await model.retryRepositoryPlanReview(projectID: projectID)

        presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .reviewing)
        XCTAssertEqual(presentation.preparation, ready)
        XCTAssertNotNil(presentation.review)
        let starts = await service.startInvocations()
        let statuses = await service.statusInvocations()
        let draftLoads = await service.reviewDraftInvocations()
        XCTAssertEqual(starts.count, 1)
        XCTAssertEqual(statuses, [identity])
        XCTAssertEqual(draftLoads, [identity, identity])
    }

    func testStaleReadyReviewCanRestartWithFreshDisclosureWithoutRedispatchingOldAttempt() async throws {
        let projectID = ProjectID(rawValue: "project-review-stale-restart")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(111))
        let draft = preparedDraft(projectID: projectID)
        let initialInventory = inventory(projectID: projectID)
        let changedInventory = RepositoryPlanSourceInventory(
            projectID: projectID,
            rootID: initialInventory.rootID,
            registration: .init(
                projectID: projectID,
                registrationID: initialInventory.registration.registrationID,
                requestGeneration: 2
            ),
            repositoryID: initialInventory.repositoryID,
            acceptedCatalogVersion: initialInventory.acceptedCatalogVersion + 1,
            acceptedCatalogDigest: String(repeating: "d", count: 64),
            sources: initialInventory.sources.map { source in
                RepositoryPlanSourceOption(
                    artifactID: source.artifactID,
                    path: source.path,
                    contentSHA256: source.artifactID == "source-a"
                        ? String(repeating: "e", count: 64)
                        : source.contentSHA256,
                    lifecycle: source.lifecycle,
                    authority: source.authority
                )
            }
        )
        let ready = readback(
            identity: identity,
            state: .readyForReview,
            draftBytes: draft.source.projectionBytes
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [ready],
            reviewDraftResponses: [draft]
        )
        let inventoryLoader = RepositoryPlanSourceInventoryLoaderSpy(
            responses: [initialInventory, changedInventory]
        )
        let previewSpy = RepositoryPlanPreviewSpy(
            responses: [],
            failureCodes: [.sourceChanged]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            inventoryLoader: inventoryLoader,
            previewSpy: previewSpy
        )
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)

        var presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .reviewLoadFailed)
        XCTAssertEqual(presentation.preparation, ready)
        XCTAssertNil(presentation.review)

        await model.restartRepositoryPlanPreparation(projectID: projectID)

        presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .selectingSources)
        XCTAssertEqual(presentation.inventory, changedInventory)
        XCTAssertTrue(presentation.selectedArtifactIDs.isEmpty)
        XCTAssertNil(presentation.preparation)
        XCTAssertNil(presentation.review)
        let loads = await inventoryLoader.invocationCount()
        let starts = await service.startInvocations()
        let statuses = await service.statusInvocations()
        let reconciliations = await service.reconcileInvocations()
        let draftLoads = await service.reviewDraftInvocations()
        let targetLoads = await service.targetInvocationCount()
        XCTAssertEqual(loads, 2)
        XCTAssertEqual(starts.count, 1)
        XCTAssertTrue(statuses.isEmpty)
        XCTAssertTrue(reconciliations.isEmpty)
        XCTAssertEqual(draftLoads, [identity])
        XCTAssertEqual(targetLoads, 2)
    }

    func testCorrectionAndExplicitExclusionRecomputeReviewAndPreserveCapturedSource() async throws {
        let projectID = ProjectID(rawValue: "project-review-edits")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(81))
        let draft = preparedDraft(projectID: projectID)
        let phaseSubject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-current"
        )
        let historicalSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let previewSpy = RepositoryPlanPreviewSpy(responses: [
            preview(for: draft.originalProjection),
            preview(for: draft.originalProjection),
            preview(for: draft.originalProjection),
        ])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(projectID: projectID, service: service, previewSpy: previewSpy)
        await openReadyReview(model, projectID: projectID)
        let originalSource = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.source
        )
        let chosenName = try JSONEncoder().encode("Reviewed current phase")

        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: phaseSubject,
            field: "name",
            chosenValue: chosenName
        )

        var review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.reviewedProjection.phases.first?.name, "Reviewed current phase")
        XCTAssertEqual(review.corrections.count, 1)
        XCTAssertEqual(review.corrections[0].subject, phaseSubject)
        XCTAssertEqual(review.corrections[0].chosenValue, chosenName)
        XCTAssertEqual(review.source, originalSource)
        XCTAssertEqual(review.source.projectionBytes, draft.source.projectionBytes)
        XCTAssertEqual(review.originalProjection.phases.first?.name, "Current phase")

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: ""
        )
        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertTrue(review.exclusions.isEmpty, "An empty reason must not create an exclusion.")
        let previewCountAfterEmptyExclusion = await previewSpy.invocationCount()
        XCTAssertEqual(previewCountAfterEmptyExclusion, 2)

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: "Historical context is not part of the current plan."
        )

        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.exclusions, [.init(
            subject: historicalSubject,
            reason: "Historical context is not part of the current plan."
        )])
        XCTAssertTrue(review.reviewedProjection.tickets.contains {
            $0.sourceID == historicalSubject.sourceID
        })
        XCTAssertEqual(
            review.comparisons.first(where: { comparison in
                comparison.kind == historicalSubject.kind &&
                    comparison.parentSourceID == historicalSubject.parentSourceID &&
                    comparison.sourceID == historicalSubject.sourceID
            })?.disposition,
            .excluded
        )
        XCTAssertEqual(review.source, originalSource)
        let invocations = await previewSpy.invocations()
        XCTAssertEqual(invocations.count, 3)
        XCTAssertEqual(invocations[1].corrections, review.corrections)
        XCTAssertEqual(invocations[1].reviewedProjection.phases.first?.name, "Reviewed current phase")
        XCTAssertEqual(invocations[2].reviewedProjection.phases.first?.name, "Reviewed current phase")
        XCTAssertTrue(invocations[2].reviewedProjection.tickets.contains {
            $0.sourceID == historicalSubject.sourceID
        })
    }

    func testParentExclusionKeepsRowsVisibleAndBlocksIncludedChildUntilExplicitlyExcluded() async throws {
        let projectID = ProjectID(rawValue: "project-exclusion-graph")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(98))
        let draft = preparedDraft(
            projectID: projectID,
            includeTask: true,
            includeHistorical: false
        )
        let ticketSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-current"
        )
        let taskSubject = RepositoryPlanReconstructionSubject(
            kind: .task,
            parentSourceID: "ticket-current",
            sourceID: "task-current"
        )
        let basePreview = preview(for: draft.originalProjection)
        let previewSpy = RepositoryPlanPreviewSpy(responses: [
            basePreview,
            basePreview,
            basePreview,
        ])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(projectID: projectID, service: service, previewSpy: previewSpy)
        await openReadyReview(model, projectID: projectID)

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: ticketSubject,
            reason: "Exclude the parent ticket only."
        )

        var review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertTrue(review.reviewedProjection.tickets.contains { $0.sourceID == ticketSubject.sourceID })
        XCTAssertTrue(review.reviewedProjection.tickets.first {
            $0.sourceID == ticketSubject.sourceID
        }?.taskPlan?.tasks.contains { $0.sourceID == taskSubject.sourceID } == true)
        XCTAssertEqual(
            review.comparisons.first { $0.subject == ticketSubject }?.disposition,
            .excluded
        )
        XCTAssertEqual(
            review.comparisons.first { $0.subject == taskSubject }?.disposition,
            .blocked
        )
        let childBlocker = try XCTUnwrap(review.blockers.first { $0.subject == taskSubject })
        XCTAssertTrue(childBlocker.message.lowercased().contains("parent"))
        XCTAssertEqual(review.exclusions.map(\.subject), [ticketSubject])

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: taskSubject,
            reason: "Explicitly exclude the dependent child task."
        )

        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(
            review.comparisons.first { $0.subject == ticketSubject }?.disposition,
            .excluded
        )
        XCTAssertEqual(
            review.comparisons.first { $0.subject == taskSubject }?.disposition,
            .excluded
        )
        XCTAssertTrue(review.blockers.isEmpty)
        XCTAssertEqual(Set(review.exclusions.map(\.subject)), Set([ticketSubject, taskSubject]))
    }

    func testRealStoreSavesPhaseExclusionWithTransitiveTaskAndDependencyBlockers() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let projectionID = uuid(107)
        let projection = RepositoryPlanProjection(
            format: "release-radar.repository-plan",
            schemaVersion: 1,
            repositoryID: fixture.projection.repositoryID,
            projectionID: projectionID.uuidString.lowercased(),
            projectionRevision: 1,
            documents: [],
            phases: [
                .init(
                    sourceID: "phase-parent",
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/phases/0")],
                    name: "Excluded parent phase",
                    lifecycle: .upcoming,
                    stateEvidence: []
                ),
                .init(
                    sourceID: "phase-dependent",
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/phases/1")],
                    name: "Included dependent phase",
                    lifecycle: .upcoming,
                    stateEvidence: []
                ),
            ],
            tickets: [
                .init(
                    sourceID: "ticket-parent",
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/tickets/0")],
                    outcome: "Ticket inside the excluded phase.",
                    phaseSourceID: "phase-parent",
                    lane: .backlog,
                    taskPlan: .init(
                        sourceRevision: 1,
                        tasks: [.init(
                            sourceID: "task-child",
                            authorityClass: .currentApproved,
                            sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
                            label: "Task 1",
                            title: "Child task inside the parent ticket.",
                            sortOrder: 0,
                            completion: .pending,
                            lifecycle: .active,
                            stateEvidence: []
                        )]
                    ),
                    stateEvidence: [],
                    evidenceRefs: []
                ),
                .init(
                    sourceID: "ticket-dependent",
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/tickets/1")],
                    outcome: "Included ticket with a dependency on the parent ticket.",
                    phaseSourceID: "phase-dependent",
                    lane: .backlog,
                    taskPlan: nil,
                    stateEvidence: [],
                    evidenceRefs: []
                ),
            ],
            phaseDependencies: [.init(
                sourceID: "phase-dependency",
                subjectSourceID: "phase-dependent",
                dependsOnSourceID: "phase-parent",
                sourceRefs: [.projection(pointer: "/phaseDependencies/0")]
            )],
            ticketDependencies: [.init(
                sourceID: "ticket-dependency",
                subjectSourceID: "ticket-dependent",
                dependsOnSourceID: "ticket-parent",
                sourceRefs: [.projection(pointer: "/ticketDependencies/0")]
            )]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let projectionBytes = try encoder.encode(projection)
        let projectionDigest = SHA256.hash(data: projectionBytes)
            .map { String(format: "%02x", $0) }
            .joined()
        let baseSource = fixture.payload.source
        let source = RepositoryPlanReconstructionSourceSnapshot(
            projectID: projectID,
            rootID: baseSource.rootID,
            registration: fixture.registration,
            repositoryID: projection.repositoryID,
            projectionID: projectionID,
            projectionRevision: projection.projectionRevision,
            projectionBytes: projectionBytes,
            projectionSHA256: projectionDigest,
            acceptedCatalogVersion: baseSource.acceptedCatalogVersion,
            acceptedCatalogDigest: baseSource.acceptedCatalogDigest,
            capturedSourceManifest: baseSource.capturedSourceManifest,
            observedGitHEAD: baseSource.observedGitHEAD
        )
        let draft = RepositoryPlanPreparedDraft(
            source: source,
            originalProjection: projection
        )
        let proposalID = PlanChangeProposalID(rawValue: "proposal-transitive-exclusion")
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: baseSource.rootID,
            proposalID: proposalID,
            attemptID: uuid(108)
        )
        let manifest = baseSource.capturedSourceManifest
        let inventory = RepositoryPlanSourceInventory(
            projectID: projectID,
            rootID: manifest.rootID,
            registration: fixture.registration,
            repositoryID: manifest.repositoryID,
            acceptedCatalogVersion: manifest.acceptedCatalogVersion,
            acceptedCatalogDigest: manifest.acceptedCatalogDigest,
            sources: manifest.sources.map {
                RepositoryPlanSourceOption(
                    artifactID: $0.artifactID,
                    path: $0.path,
                    contentSHA256: $0.contentSHA256,
                    lifecycle: $0.lifecycle,
                    authority: $0.authority
                )
            }
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let store = fixture.store
        let dispatcher = fixture.dispatcher
        let projectRoot = fixture.root.path
        let registration = fixture.registration
        let model = try makeModel(
            projectID: projectID,
            service: service,
            store: store,
            inventoryLoader: .init(responses: [inventory]),
            previewer: { source, reviewedProjection, corrections, explicitMappings in
                try await RepositoryPlanReconstructionPreviewQuery.preview(
                    source: source,
                    reviewedProjection: reviewedProjection,
                    corrections: corrections,
                    explicitMappings: explicitMappings,
                    from: store
                )
            },
            commandDispatch: { _, _, requestID, command in
                await dispatcher.dispatch(.init(
                    version: AgentCommandDispatcher.commandEnvelopeVersion,
                    requestID: requestID,
                    projectRoot: projectRoot,
                    expectedRegistration: registration,
                    reason: "Exercise transitive reconstruction exclusion coherence.",
                    command: command
                ), origin: .ownerApp)
            },
            requestIDs: [uuid(109), uuid(110)]
        )
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "current",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)

        let phaseSubject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-parent"
        )
        let ticketSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-parent"
        )
        let taskSubject = RepositoryPlanReconstructionSubject(
            kind: .task,
            parentSourceID: "ticket-parent",
            sourceID: "task-child"
        )
        let phaseDependencySubject = RepositoryPlanReconstructionSubject(
            kind: .phaseDependency,
            parentSourceID: "phase-dependent",
            sourceID: "phase-dependency"
        )
        let ticketDependencySubject = RepositoryPlanReconstructionSubject(
            kind: .ticketDependency,
            parentSourceID: "ticket-dependent",
            sourceID: "ticket-dependency"
        )
        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: phaseSubject,
            reason: "Exclude the parent phase explicitly."
        )

        var review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.comparisons.first { $0.subject == phaseSubject }?.disposition, .excluded)
        for subject in [ticketSubject, taskSubject, phaseDependencySubject, ticketDependencySubject] {
            XCTAssertEqual(review.comparisons.first { $0.subject == subject }?.disposition, .blocked)
            XCTAssertNotNil(review.blockers.first { $0.subject == subject })
        }
        XCTAssertEqual(review.comparisons.count, 7, "Every source row must remain reviewable.")

        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the coherent blocked reconstruction."
        )
        let blockedSave = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        XCTAssertEqual(blockedSave.version.version, 1)
        XCTAssertEqual(Set(blockedSave.payload.blockers.compactMap(\.subject)), Set([
            ticketSubject, taskSubject, phaseDependencySubject, ticketDependencySubject,
        ]))

        for (subject, reason) in [
            (ticketSubject, "Explicitly exclude the ticket inside the excluded phase."),
            (taskSubject, "Explicitly exclude the task inside the excluded ticket."),
            (phaseDependencySubject, "Explicitly exclude the phase dependency."),
            (ticketDependencySubject, "Explicitly exclude the ticket dependency."),
        ] {
            await model.setRepositoryPlanExclusion(
                projectID: projectID,
                subject: subject,
                reason: reason
            )
        }

        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertTrue(review.blockers.isEmpty)
        XCTAssertEqual(Set(review.exclusions.map(\.subject)), Set([
            phaseSubject, ticketSubject, taskSubject, phaseDependencySubject, ticketDependencySubject,
        ]))
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the fully excluded reconstruction."
        )
        let resolvedSave = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        XCTAssertEqual(resolvedSave.version.version, 2)
        XCTAssertTrue(resolvedSave.payload.blockers.isEmpty)
    }

    func testSaveRequiresAuthorityButPersistsStructurallyValidBlockedDraft() async throws {
        let projectID = ProjectID(rawValue: "project-save-gates")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(82))
        let draft = preparedDraft(projectID: projectID)
        let blockedSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-current"
        )
        let blocker = RepositoryPlanReconstructionBlocker(
            code: "conflicting_source_authority",
            subject: blockedSubject,
            message: "Resolve the conflicting current source before saving."
        )
        let initialPreview = preview(for: draft.originalProjection, blockers: [blocker])
        let expectedPayload = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: draft.originalProjection,
            comparisons: initialPreview.comparisons,
            corrections: [],
            exclusions: [],
            terminalEvidence: [],
            blockers: initialPreview.blockers
        )
        let saved = savedReadback(proposalID: identity.proposalID, payload: expectedPayload)
        let previewSpy = RepositoryPlanPreviewSpy(responses: [initialPreview])
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(responses: [.init(
            entityIDs: [identity.proposalID.rawValue],
            auditEventID: nil,
            error: nil,
            planChangeProposalVersion: 1,
            repositoryPlanReconstruction: saved
        )])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: previewSpy,
            commandDispatchSpy: dispatchSpy
        )
        await openReadyReview(model, projectID: projectID)

        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Save the reviewed reconstruction."
        )
        let dispatchCount = await dispatchSpy.invocationCount()
        XCTAssertEqual(dispatchCount, 0)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .reviewing)

        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Save the reviewed reconstruction."
        )
        let invocations = await dispatchSpy.invocations()
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations[0].command, .saveRepositoryPlanReconstruction(
            proposalID: identity.proposalID.rawValue,
            expectedPreviousVersion: nil,
            rationale: "Save the reviewed reconstruction.",
            payload: expectedPayload
        ))
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback,
            saved
        )
    }

    func testSuccessfulSaveDispatchesExactPayloadOnceAndKeepsLiveGraphUnchanged() async throws {
        let projectID = ProjectID(rawValue: "project-save-success")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(83))
        let draft = preparedDraft(projectID: projectID)
        let historicalSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let exclusion = RepositoryPlanReconstructionExclusion(
            subject: historicalSubject,
            reason: "Historical context must remain visible but not enter the live plan."
        )
        let expectedPreview = preview(for: draft.originalProjection)
        let expectedComparisons = expectedPreview.comparisons.map { comparison in
            comparison.subject == historicalSubject
                ? .init(
                    kind: comparison.kind,
                    parentSourceID: comparison.parentSourceID,
                    sourceID: comparison.sourceID,
                    destinationID: comparison.destinationID,
                    disposition: .excluded
                )
                : comparison
        }
        let expectedPayload = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: draft.originalProjection,
            comparisons: expectedComparisons,
            corrections: [],
            exclusions: [exclusion],
            terminalEvidence: [],
            blockers: []
        )
        let saved = savedReadback(
            proposalID: identity.proposalID,
            payload: expectedPayload
        )
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(responses: [.init(
            entityIDs: [identity.proposalID.rawValue],
            auditEventID: nil,
            error: nil,
            planChangeProposalVersion: 1,
            repositoryPlanReconstruction: saved
        )])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let requestID = uuid(90)
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: .init(responses: [expectedPreview, expectedPreview]),
            commandDispatchSpy: dispatchSpy,
            requestIDs: [requestID]
        )
        let before = try await liveGraphCounts(model.onboardingStore)
        await openReadyReview(model, projectID: projectID)
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: exclusion.reason
        )

        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Save the exact reviewed reconstruction."
        )

        let invocations = await dispatchSpy.invocations()
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations[0].projectID, projectID)
        XCTAssertEqual(invocations[0].registration, draft.source.registration)
        XCTAssertEqual(invocations[0].requestID, requestID)
        XCTAssertEqual(invocations[0].command, .saveRepositoryPlanReconstruction(
            proposalID: identity.proposalID.rawValue,
            expectedPreviousVersion: nil,
            rationale: "Save the exact reviewed reconstruction.",
            payload: expectedPayload
        ))
        let presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .reviewing)
        XCTAssertEqual(presentation.review?.savedReadback, saved)
        let after = try await liveGraphCounts(model.onboardingStore)
        XCTAssertEqual(after, before)
    }

    func testSavedVersionSurvivesCorrectionAndExclusionEditsForExactResaveCAS() async throws {
        let projectID = ProjectID(rawValue: "project-save-versions")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(91))
        let draft = preparedDraft(projectID: projectID)
        let phaseSubject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-current"
        )
        let historicalSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let initialExclusion = RepositoryPlanReconstructionExclusion(
            subject: historicalSubject,
            reason: "Keep historical context out of the operational plan."
        )
        let revisedExclusion = RepositoryPlanReconstructionExclusion(
            subject: historicalSubject,
            reason: "Owner confirmed this remains historical context only."
        )
        let initialPreview = preview(for: draft.originalProjection)
        let initialExcluded = excluding([historicalSubject], from: initialPreview)
        let payloadV1 = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: draft.originalProjection,
            comparisons: initialExcluded.comparisons,
            corrections: [],
            exclusions: [initialExclusion],
            terminalEvidence: [],
            blockers: initialExcluded.blockers
        )
        let encoder = JSONEncoder()
        let correction = RepositoryPlanReconstructionCorrection(
            subject: phaseSubject,
            field: "name",
            sourceValue: try encoder.encode("Current phase"),
            chosenValue: try encoder.encode("Reviewed phase version two")
        )
        let correctedProjection = try RepositoryPlanReconstructionCorrections.apply(
            [correction],
            to: draft.originalProjection
        )
        let correctedPreview = preview(for: correctedProjection)
        let correctedExcluded = excluding([historicalSubject], from: correctedPreview)
        let payloadV2 = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: correctedProjection,
            comparisons: correctedExcluded.comparisons,
            corrections: [correction],
            exclusions: [initialExclusion],
            terminalEvidence: [],
            blockers: correctedExcluded.blockers
        )
        let payloadV3 = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: correctedProjection,
            comparisons: correctedExcluded.comparisons,
            corrections: [correction],
            exclusions: [revisedExclusion],
            terminalEvidence: [],
            blockers: correctedExcluded.blockers
        )
        let savedV1 = savedReadback(proposalID: identity.proposalID, payload: payloadV1, version: 1)
        let savedV2 = savedReadback(proposalID: identity.proposalID, payload: payloadV2, version: 2)
        let savedV3 = savedReadback(proposalID: identity.proposalID, payload: payloadV3, version: 3)
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(responses: [
            .init(
                entityIDs: [identity.proposalID.rawValue],
                auditEventID: nil,
                error: nil,
                planChangeProposalVersion: 1,
                repositoryPlanReconstruction: savedV1
            ),
            .init(
                entityIDs: [identity.proposalID.rawValue],
                auditEventID: nil,
                error: nil,
                planChangeProposalVersion: 2,
                repositoryPlanReconstruction: savedV2
            ),
            .init(
                entityIDs: [identity.proposalID.rawValue],
                auditEventID: nil,
                error: nil,
                planChangeProposalVersion: 3,
                repositoryPlanReconstruction: savedV3
            ),
        ])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: .init(responses: [
                initialPreview,
                initialPreview,
                correctedPreview,
                correctedPreview,
            ]),
            commandDispatchSpy: dispatchSpy,
            requestIDs: [uuid(92), uuid(93), uuid(94)]
        )
        await openReadyReview(model, projectID: projectID)
        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: initialExclusion.reason
        )
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(projectID: projectID, rationale: "Save version one.")

        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: phaseSubject,
            field: correction.field,
            chosenValue: correction.chosenValue
        )
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(projectID: projectID, rationale: "Save version two.")

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: revisedExclusion.reason
        )
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(projectID: projectID, rationale: "Save version three.")

        let invocations = await dispatchSpy.invocations()
        XCTAssertEqual(invocations.count, 3)
        XCTAssertEqual(invocations[0].command, .saveRepositoryPlanReconstruction(
            proposalID: identity.proposalID.rawValue,
            expectedPreviousVersion: nil,
            rationale: "Save version one.",
            payload: payloadV1
        ))
        XCTAssertEqual(invocations[1].command, .saveRepositoryPlanReconstruction(
            proposalID: identity.proposalID.rawValue,
            expectedPreviousVersion: 1,
            rationale: "Save version two.",
            payload: payloadV2
        ))
        XCTAssertEqual(invocations[2].command, .saveRepositoryPlanReconstruction(
            proposalID: identity.proposalID.rawValue,
            expectedPreviousVersion: 2,
            rationale: "Save version three.",
            payload: payloadV3
        ))
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback,
            savedV3
        )
    }

    func testRealStoreResavesCorrectionAndExclusionAgainstPersistedVersions() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let proposalID = PlanChangeProposalID(rawValue: "proposal-app-real-version")
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: "root-101",
            proposalID: proposalID,
            attemptID: uuid(101)
        )
        let draft = RepositoryPlanPreparedDraft(
            source: fixture.payload.source,
            originalProjection: fixture.projection
        )
        let manifest = fixture.payload.source.capturedSourceManifest
        let inventory = RepositoryPlanSourceInventory(
            projectID: projectID,
            rootID: manifest.rootID,
            registration: fixture.registration,
            repositoryID: manifest.repositoryID,
            acceptedCatalogVersion: manifest.acceptedCatalogVersion,
            acceptedCatalogDigest: manifest.acceptedCatalogDigest,
            sources: manifest.sources.map {
                RepositoryPlanSourceOption(
                    artifactID: $0.artifactID,
                    path: $0.path,
                    contentSHA256: $0.contentSHA256,
                    lifecycle: $0.lifecycle,
                    authority: $0.authority
                )
            }
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let store = fixture.store
        let dispatcher = fixture.dispatcher
        let projectRoot = fixture.root.path
        let registration = fixture.registration
        let model = try makeModel(
            projectID: projectID,
            service: service,
            store: store,
            inventoryLoader: .init(responses: [inventory]),
            previewer: { source, reviewedProjection, corrections, explicitMappings in
                try await RepositoryPlanReconstructionPreviewQuery.preview(
                    source: source,
                    reviewedProjection: reviewedProjection,
                    corrections: corrections,
                    explicitMappings: explicitMappings,
                    from: store
                )
            },
            commandDispatch: { _, _, requestID, command in
                await dispatcher.dispatch(.init(
                    version: AgentCommandDispatcher.commandEnvelopeVersion,
                    requestID: requestID,
                    projectRoot: projectRoot,
                    expectedRegistration: registration,
                    reason: "Exercise AppModel reconstruction version evolution.",
                    command: command
                ), origin: .ownerApp)
            },
            requestIDs: [uuid(102), uuid(103), uuid(104)]
        )
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "current",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)

        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the reviewed reconstruction."
        )

        let savedV1 = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        XCTAssertEqual(savedV1.version.version, 1)

        let subject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-101"
        )
        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: subject,
            field: "name",
            chosenValue: try JSONEncoder().encode("Reviewed real phase")
        )
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the corrected reconstruction."
        )

        let savedV2 = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        XCTAssertEqual(savedV2.version.version, 2)
        XCTAssertEqual(savedV2.payload.corrections.count, 1)

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: subject,
            reason: "Owner excludes this phase from the operational plan."
        )
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the explicitly excluded reconstruction."
        )

        let savedV3 = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        XCTAssertEqual(savedV3.version.version, 3)
        XCTAssertEqual(savedV3.payload.exclusions.count, 1)
        XCTAssertEqual(savedV3.payload.exclusions.first?.subject, subject)
    }

    func testLaterCorrectionWinsWhenEarlierPreviewCompletesLast() async throws {
        let projectID = ProjectID(rawValue: "project-review-race")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(95))
        let draft = preparedDraft(projectID: projectID)
        let subject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-current"
        )
        let firstValue = try JSONEncoder().encode("First slow correction")
        let secondValue = try JSONEncoder().encode("Second current correction")
        let firstProjection = try RepositoryPlanReconstructionCorrections.apply([.init(
            subject: subject,
            field: "name",
            sourceValue: try JSONEncoder().encode("Current phase"),
            chosenValue: firstValue
        )], to: draft.originalProjection)
        let secondProjection = try RepositoryPlanReconstructionCorrections.apply([.init(
            subject: subject,
            field: "name",
            sourceValue: try JSONEncoder().encode("Current phase"),
            chosenValue: secondValue
        )], to: draft.originalProjection)
        let firstGate = RepositoryPlanPreparationStartGate()
        let previewSpy = RepositoryPlanPreviewSpy(
            responses: [
                preview(for: draft.originalProjection),
                preview(for: firstProjection),
                preview(for: secondProjection),
            ],
            gates: [nil, firstGate, nil]
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(projectID: projectID, service: service, previewSpy: previewSpy)
        await openReadyReview(model, projectID: projectID)

        let first = Task {
            await model.setRepositoryPlanCorrection(
                projectID: projectID,
                subject: subject,
                field: "name",
                chosenValue: firstValue
            )
        }
        await firstGate.waitUntilEntered()
        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: subject,
            field: "name",
            chosenValue: secondValue
        )
        await firstGate.release()
        await first.value

        let review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.reviewedProjection.phases.first?.name, "Second current correction")
        XCTAssertEqual(review.corrections.count, 1)
        XCTAssertEqual(review.corrections[0].chosenValue, secondValue)
        XCTAssertFalse(review.authorityConfirmed)
    }

    func testAuthorityConfirmationDoesNotPermitSaveUntilPendingExclusionPreviewCompletes() async throws {
        let projectID = ProjectID(rawValue: "project-preview-confirm-race")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(105))
        let draft = preparedDraft(projectID: projectID)
        let subject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let exclusion = RepositoryPlanReconstructionExclusion(
            subject: subject,
            reason: "Exclude historical context from the operational plan."
        )
        let initialPreview = preview(for: draft.originalProjection)
        let excludedPreview = excluding([subject], from: initialPreview)
        let payload = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: draft.originalProjection,
            comparisons: excludedPreview.comparisons,
            corrections: [],
            exclusions: [exclusion],
            terminalEvidence: [],
            blockers: excludedPreview.blockers
        )
        let saved = savedReadback(proposalID: identity.proposalID, payload: payload)
        let gate = RepositoryPlanPreparationStartGate()
        let previewSpy = RepositoryPlanPreviewSpy(
            responses: [initialPreview, initialPreview],
            gates: [nil, gate]
        )
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(responses: [.init(
            entityIDs: [identity.proposalID.rawValue],
            auditEventID: nil,
            error: nil,
            planChangeProposalVersion: 1,
            repositoryPlanReconstruction: saved
        )])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: previewSpy,
            commandDispatchSpy: dispatchSpy
        )
        await openReadyReview(model, projectID: projectID)

        let edit = Task {
            await model.setRepositoryPlanExclusion(
                projectID: projectID,
                subject: subject,
                reason: exclusion.reason
            )
        }
        await gate.waitUntilEntered()
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Save only after the exact preview is ready."
        )

        let dispatchesWhilePending = await dispatchSpy.invocationCount()
        XCTAssertEqual(dispatchesWhilePending, 0)
        XCTAssertTrue(model.repositoryPlanReconstruction(for: projectID)?.review?.isUpdating == true)

        await gate.release()
        await edit.value
        let completedReview = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review
        )
        XCTAssertTrue(completedReview.authorityConfirmed)
        XCTAssertFalse(completedReview.isUpdating)
        XCTAssertEqual(
            completedReview.comparisons.first { $0.subject == subject }?.disposition,
            .excluded
        )

        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Save only after the exact preview is ready."
        )
        let completedDispatches = await dispatchSpy.invocations()
        XCTAssertEqual(completedDispatches.count, 1)
        XCTAssertEqual(completedDispatches[0].command, .saveRepositoryPlanReconstruction(
            proposalID: identity.proposalID.rawValue,
            expectedPreviousVersion: nil,
            rationale: "Save only after the exact preview is ready.",
            payload: payload
        ))
    }

    func testFailedEditPreviewCannotSaveStaleComparisonsAndCanRetryExactEdit() async throws {
        let projectID = ProjectID(rawValue: "project-preview-failure-gate")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(106))
        let draft = preparedDraft(projectID: projectID)
        let subject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let reason = "Exclude historical context from the operational plan."
        let initialPreview = preview(for: draft.originalProjection)
        let excludedPreview = excluding([subject], from: initialPreview)
        let exclusion = RepositoryPlanReconstructionExclusion(subject: subject, reason: reason)
        let payload = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: draft.originalProjection,
            comparisons: excludedPreview.comparisons,
            corrections: [],
            exclusions: [exclusion],
            terminalEvidence: [],
            blockers: excludedPreview.blockers
        )
        let saved = savedReadback(proposalID: identity.proposalID, payload: payload)
        let previewSpy = RepositoryPlanPreviewSpy(
            responses: [initialPreview, initialPreview],
            failureCodes: [nil, .invalidRequest, nil]
        )
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(responses: [.init(
            entityIDs: [identity.proposalID.rawValue],
            auditEventID: nil,
            error: nil,
            planChangeProposalVersion: 1,
            repositoryPlanReconstruction: saved
        )])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: previewSpy,
            commandDispatchSpy: dispatchSpy
        )
        await openReadyReview(model, projectID: projectID)
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: subject,
            reason: reason
        )
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Do not save stale comparisons."
        )

        let dispatchesAfterFailure = await dispatchSpy.invocationCount()
        XCTAssertEqual(dispatchesAfterFailure, 0)
        XCTAssertTrue(model.repositoryPlanReconstruction(for: projectID)?.review?.isUpdating == true)
        XCTAssertNotNil(model.repositoryPlanReconstruction(for: projectID)?.message)

        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: subject,
            reason: reason
        )
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Do not save stale comparisons."
        )

        let completedDispatches = await dispatchSpy.invocations()
        XCTAssertEqual(completedDispatches.count, 1)
        XCTAssertEqual(completedDispatches[0].command, .saveRepositoryPlanReconstruction(
            proposalID: identity.proposalID.rawValue,
            expectedPreviousVersion: nil,
            rationale: "Do not save stale comparisons.",
            payload: payload
        ))
    }

    func testOverlappingSaveDispatchesOnceAndPublishesExactCompletion() async throws {
        let projectID = ProjectID(rawValue: "project-save-overlap")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(96))
        let draft = preparedDraft(projectID: projectID)
        let historicalSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let exclusion = RepositoryPlanReconstructionExclusion(
            subject: historicalSubject,
            reason: "Historical context remains excluded."
        )
        let initialPreview = preview(for: draft.originalProjection)
        let excluded = excluding([historicalSubject], from: initialPreview)
        let payload = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: draft.originalProjection,
            comparisons: excluded.comparisons,
            corrections: [],
            exclusions: [exclusion],
            terminalEvidence: [],
            blockers: excluded.blockers
        )
        let saved = savedReadback(proposalID: identity.proposalID, payload: payload)
        let dispatchGate = RepositoryPlanPreparationStartGate()
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(
            responses: [
                .init(
                    entityIDs: [identity.proposalID.rawValue],
                    auditEventID: nil,
                    error: nil,
                    planChangeProposalVersion: 1,
                    repositoryPlanReconstruction: saved
                ),
                .init(
                    entityIDs: [identity.proposalID.rawValue],
                    auditEventID: nil,
                    error: nil,
                    planChangeProposalVersion: 1,
                    repositoryPlanReconstruction: saved
                ),
            ],
            gates: [dispatchGate, nil]
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: .init(responses: [initialPreview, initialPreview]),
            commandDispatchSpy: dispatchSpy
        )
        await openReadyReview(model, projectID: projectID)
        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: exclusion.reason
        )
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)

        let first = Task {
            await model.saveRepositoryPlanReconstruction(projectID: projectID, rationale: "Save once.")
        }
        await dispatchGate.waitUntilEntered()
        await model.saveRepositoryPlanReconstruction(projectID: projectID, rationale: "Duplicate save.")
        let countWhileFirstIsPending = await dispatchSpy.invocationCount()
        XCTAssertEqual(countWhileFirstIsPending, 1)
        await dispatchGate.release()
        await first.value

        let invocations = await dispatchSpy.invocations()
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback,
            saved
        )
    }

    func testEditStartedDuringSaveIsNotOverwrittenByOlderSaveCompletion() async throws {
        let projectID = ProjectID(rawValue: "project-save-edit-race")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(99))
        let draft = preparedDraft(projectID: projectID)
        let historicalSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let phaseSubject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-current"
        )
        let exclusion = RepositoryPlanReconstructionExclusion(
            subject: historicalSubject,
            reason: "Historical context remains excluded."
        )
        let initialPreview = preview(for: draft.originalProjection)
        let excluded = excluding([historicalSubject], from: initialPreview)
        let savedPayload = RepositoryPlanReconstructionPayload(
            source: draft.source,
            reviewedProjection: draft.originalProjection,
            comparisons: excluded.comparisons,
            corrections: [],
            exclusions: [exclusion],
            terminalEvidence: [],
            blockers: excluded.blockers
        )
        let saved = savedReadback(proposalID: identity.proposalID, payload: savedPayload)
        let chosenValue = try JSONEncoder().encode("Edit made while Save was pending")
        let correctedProjection = try RepositoryPlanReconstructionCorrections.apply([.init(
            subject: phaseSubject,
            field: "name",
            sourceValue: try JSONEncoder().encode("Current phase"),
            chosenValue: chosenValue
        )], to: draft.originalProjection)
        let dispatchGate = RepositoryPlanPreparationStartGate()
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(
            responses: [.init(
                entityIDs: [identity.proposalID.rawValue],
                auditEventID: nil,
                error: nil,
                planChangeProposalVersion: 1,
                repositoryPlanReconstruction: saved
            )],
            gates: [dispatchGate]
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: .init(responses: [
                initialPreview,
                initialPreview,
                preview(for: correctedProjection),
            ]),
            commandDispatchSpy: dispatchSpy
        )
        await openReadyReview(model, projectID: projectID)
        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: exclusion.reason
        )
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)

        let save = Task {
            await model.saveRepositoryPlanReconstruction(projectID: projectID, rationale: "Save older review.")
        }
        await dispatchGate.waitUntilEntered()
        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: phaseSubject,
            field: "name",
            chosenValue: chosenValue
        )
        await dispatchGate.release()
        await save.value

        let review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.reviewedProjection.phases.first?.name, "Edit made while Save was pending")
        XCTAssertEqual(review.corrections.first?.chosenValue, chosenValue)
        XCTAssertFalse(review.authorityConfirmed)
        XCTAssertNil(review.savedReadback, "The current edited review has not itself been saved.")
        let dispatchCount = await dispatchSpy.invocationCount()
        XCTAssertEqual(dispatchCount, 1)
    }

    func testStaleSourceSaveKeepsExactReviewAndExplainsRecovery() async throws {
        let projectID = ProjectID(rawValue: "project-save-stale")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(84))
        let draft = preparedDraft(projectID: projectID)
        let historicalSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-historical"
        )
        let expectedPreview = preview(for: draft.originalProjection)
        let dispatchSpy = RepositoryPlanOwnerCommandDispatchSpy(responses: [.init(
            entityIDs: [],
            auditEventID: nil,
            error: .repositoryPlanReconstructionStaleSource
        )])
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: draft.source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: .init(responses: [expectedPreview, expectedPreview]),
            commandDispatchSpy: dispatchSpy
        )
        await openReadyReview(model, projectID: projectID)
        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.setRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject,
            reason: "Historical context must remain visible but not enter the live plan."
        )
        let reviewBefore = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review
        )

        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Attempt to save a stale source."
        )

        let presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .reviewing)
        XCTAssertEqual(presentation.review?.source, reviewBefore.source)
        XCTAssertEqual(presentation.review?.reviewedProjection, reviewBefore.reviewedProjection)
        XCTAssertNil(presentation.review?.savedReadback)
        let message = try XCTUnwrap(presentation.message?.lowercased())
        XCTAssertTrue(message.contains("source"), "Recovery message: \(message)")
        XCTAssertTrue(
            message.contains("review") || message.contains("prepare"),
            "Recovery must explain how to obtain a fresh reviewed source: \(message)"
        )
        let dispatchCount = await dispatchSpy.invocationCount()
        XCTAssertEqual(dispatchCount, 1)
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
        store providedStore: DeliveryStore? = nil,
        inventoryLoader: RepositoryPlanSourceInventoryLoaderSpy? = nil,
        previewSpy: RepositoryPlanPreviewSpy? = nil,
        commandDispatchSpy: RepositoryPlanOwnerCommandDispatchSpy? = nil,
        previewer providedPreviewer: (@Sendable (
            RepositoryPlanReconstructionSourceSnapshot,
            RepositoryPlanProjection,
            [RepositoryPlanReconstructionCorrection],
            [RepositoryPlanReconstructionMappingSelection]
        ) async throws -> RepositoryPlanReconstructionPreview)? = nil,
        commandDispatch providedCommandDispatch: (@Sendable (
            ProjectID,
            ProjectRegistration,
            UUID,
            AgentCommand
        ) async -> AgentCommandResult)? = nil,
        requestIDs: [UUID] = []
    ) throws -> AppModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ReleaseRadar-ReconstructionApp-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = providedStore
            ?? DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let defaultInventory = inventory(projectID: projectID)
        let loader = inventoryLoader ?? RepositoryPlanSourceInventoryLoaderSpy(
            responses: [defaultInventory]
        )
        let previews = previewSpy ?? RepositoryPlanPreviewSpy(responses: [])
        let commands = commandDispatchSpy ?? RepositoryPlanOwnerCommandDispatchSpy(responses: [])
        let requestIDGenerator = RepositoryPlanRequestIDGenerator(values: requestIDs)
        let previewer = providedPreviewer ?? { source, reviewedProjection, corrections, explicitMappings in
            try await previews.preview(
                source: source,
                reviewedProjection: reviewedProjection,
                corrections: corrections,
                explicitMappings: explicitMappings
            )
        }
        let commandDispatch = providedCommandDispatch ?? { projectID, registration, requestID, command in
            await commands.dispatch(
                projectID: projectID,
                registration: registration,
                requestID: requestID,
                command: command
            )
        }
        return AppModel(
            store: store,
            requestIDGenerator: requestIDGenerator.next,
            externalServicesSuppressed: true,
            repositoryPlanSourceLoader: { _, _, loadedProjectID in
                XCTAssertEqual(loadedProjectID, projectID)
                return try await loader.load(projectID: loadedProjectID)
            },
            repositoryPlanPreparationService: service,
            repositoryPlanPreviewer: previewer,
            repositoryPlanOwnerCommandDispatch: commandDispatch
        )
    }

    private func openReadyReview(_ model: AppModel, projectID: ProjectID) async {
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "source-a",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)
    }

    private func preparedDraft(
        projectID: ProjectID,
        includeTask: Bool = false,
        includeHistorical: Bool = true
    ) -> RepositoryPlanPreparedDraft {
        let sourceBytes = Data("selected source bytes".utf8)
        let sourceDigest = SHA256.hash(data: sourceBytes)
            .map { String(format: "%02x", $0) }
            .joined()
        let projectionID = uuid(100)
        var tickets = [RepositoryPlanProjectionTicket(
            sourceID: "ticket-current",
            authorityClass: .currentApproved,
            sourceRefs: [.projection(pointer: "/tickets/0")],
            outcome: "Deliver the current approved outcome.",
            phaseSourceID: "phase-current",
            lane: .backlog,
            taskPlan: includeTask ? .init(
                sourceRevision: 1,
                tasks: [.init(
                    sourceID: "task-current",
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
                    label: "Task 1",
                    title: "Deliver the current task.",
                    sortOrder: 0,
                    completion: .pending,
                    lifecycle: .active,
                    stateEvidence: []
                )]
            ) : nil,
            stateEvidence: [],
            evidenceRefs: []
        )]
        if includeHistorical {
            tickets.append(.init(
                sourceID: "ticket-historical",
                authorityClass: .historical,
                sourceRefs: [.projection(pointer: "/tickets/1")],
                outcome: "Retain historical context without applying it.",
                phaseSourceID: nil,
                lane: nil,
                taskPlan: nil,
                stateEvidence: [],
                evidenceRefs: []
            ))
        }
        let projection = RepositoryPlanProjection(
            format: "release-radar.repository-plan",
            schemaVersion: 1,
            repositoryID: "9141d1ea-3342-4462-9e06-6934d816c03f",
            projectionID: projectionID.uuidString.lowercased(),
            projectionRevision: 1,
            documents: [.init(
                id: "document-current",
                artifactID: "source-a",
                contentSHA256: sourceDigest
            )],
            phases: [.init(
                sourceID: "phase-current",
                authorityClass: .currentApproved,
                sourceRefs: [.projection(pointer: "/phases/0")],
                name: "Current phase",
                lifecycle: .upcoming,
                stateEvidence: []
            )],
            tickets: tickets,
            phaseDependencies: [],
            ticketDependencies: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let projectionBytes = try! encoder.encode(projection)
        let projectionDigest = SHA256.hash(data: projectionBytes)
            .map { String(format: "%02x", $0) }
            .joined()
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-\(projectID.rawValue)",
            requestGeneration: 1
        )
        let manifest = RepositoryPlanSourceManifest(
            projectID: projectID,
            rootID: "root-\(projectID.rawValue)",
            rootPath: "/fixture/\(projectID.rawValue)",
            registration: registration,
            repositoryID: projection.repositoryID,
            acceptedCatalogVersion: 7,
            acceptedCatalogDigest: String(repeating: "c", count: 64),
            sources: [.init(
                artifactID: "source-a",
                path: "docs/plan-a.md",
                contentSHA256: sourceDigest,
                lifecycle: .active,
                authority: .controlling,
                bytes: sourceBytes
            )]
        )
        return .init(
            source: .init(
                projectID: projectID,
                rootID: manifest.rootID,
                registration: registration,
                repositoryID: projection.repositoryID,
                projectionID: projectionID,
                projectionRevision: projection.projectionRevision,
                projectionBytes: projectionBytes,
                projectionSHA256: projectionDigest,
                acceptedCatalogVersion: manifest.acceptedCatalogVersion,
                acceptedCatalogDigest: manifest.acceptedCatalogDigest,
                capturedSourceManifest: manifest,
                observedGitHEAD: "0123456789abcdef0123456789abcdef01234567"
            ),
            originalProjection: projection
        )
    }

    private func preview(
        for projection: RepositoryPlanProjection,
        blockers: [RepositoryPlanReconstructionBlocker] = []
    ) -> RepositoryPlanReconstructionPreview {
        var authorityBlockers: [RepositoryPlanReconstructionBlocker] = []
        let phaseComparisons = projection.phases.map { phase in
            let subject = RepositoryPlanReconstructionSubject(
                kind: .phase,
                parentSourceID: nil,
                sourceID: phase.sourceID
            )
            if phase.authorityClass != .currentApproved {
                authorityBlockers.append(.init(
                    code: "source_authority_unresolved",
                    subject: subject,
                    message: "Only source records explicitly resolved as current approved may enter the live plan."
                ))
            }
            return RepositoryPlanReconstructionComparison(
                kind: .phase,
                parentSourceID: nil,
                sourceID: phase.sourceID,
                destinationID: "destination-\(phase.sourceID)",
                disposition: phase.authorityClass == .currentApproved ? .new : .blocked
            )
        }
        let ticketComparisons = projection.tickets.map { ticket in
            let subject = RepositoryPlanReconstructionSubject(
                kind: .ticket,
                parentSourceID: nil,
                sourceID: ticket.sourceID
            )
            if ticket.authorityClass != .currentApproved {
                authorityBlockers.append(.init(
                    code: "source_authority_unresolved",
                    subject: subject,
                    message: "Only source records explicitly resolved as current approved may enter the live plan."
                ))
            }
            return RepositoryPlanReconstructionComparison(
                kind: .ticket,
                parentSourceID: nil,
                sourceID: ticket.sourceID,
                destinationID: "destination-\(ticket.sourceID)",
                disposition: ticket.authorityClass != .currentApproved || blockers.contains(where: {
                    $0.subject == subject
                }) ? .blocked : .new
            )
        }
        let taskComparisons = projection.tickets.flatMap { ticket in
            (ticket.taskPlan?.tasks ?? []).map { task in
                let subject = RepositoryPlanReconstructionSubject(
                    kind: .task,
                    parentSourceID: ticket.sourceID,
                    sourceID: task.sourceID
                )
                if task.authorityClass != .currentApproved {
                    authorityBlockers.append(.init(
                        code: "source_authority_unresolved",
                        subject: subject,
                        message: "Only source records explicitly resolved as current approved may enter the live plan."
                    ))
                }
                return RepositoryPlanReconstructionComparison(
                    kind: .task,
                    parentSourceID: ticket.sourceID,
                    sourceID: task.sourceID,
                    destinationID: "destination-\(task.sourceID)",
                    disposition: task.authorityClass == .currentApproved ? .new : .blocked
                )
            }
        }
        return .init(
            comparisons: phaseComparisons + ticketComparisons + taskComparisons,
            blockers: blockers + authorityBlockers
        )
    }

    private func excluding(
        _ subjects: Set<RepositoryPlanReconstructionSubject>,
        from preview: RepositoryPlanReconstructionPreview
    ) -> RepositoryPlanReconstructionPreview {
        .init(
            comparisons: preview.comparisons.map { comparison in
                guard subjects.contains(comparison.subject) else { return comparison }
                return .init(
                    kind: comparison.kind,
                    parentSourceID: comparison.parentSourceID,
                    sourceID: comparison.sourceID,
                    destinationID: comparison.destinationID,
                    disposition: .excluded
                )
            },
            blockers: preview.blockers.filter { blocker in
                blocker.subject.map { !subjects.contains($0) } ?? true
            }
        )
    }

    private func savedReadback(
        proposalID: PlanChangeProposalID,
        payload: RepositoryPlanReconstructionPayload,
        version: Int64 = 1
    ) -> RepositoryPlanReconstructionReadback {
        .init(
            proposalID: proposalID,
            version: .init(
                version: version,
                registration: payload.source.registration,
                baselineDigest: String(repeating: "d", count: 64),
                baseline: Data("baseline".utf8),
                operations: [.reconstructRepositoryPlan(payload)],
                diff: .init(groups: []),
                sourceImpacts: [],
                rationale: "Save the exact reviewed reconstruction.",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                decision: nil,
                application: nil
            ),
            payload: payload,
            applicationAttempt: nil,
            provenance: [],
            remainingSetup: []
        )
    }

    private func liveGraphCounts(_ store: DeliveryStore) async throws -> RepositoryPlanLiveGraphCounts {
        try await store.read { connection in
            .init(
                phases: try connection.scalarInt("SELECT COUNT(*) FROM phases") ?? 0,
                tickets: try connection.scalarInt("SELECT COUNT(*) FROM tickets") ?? 0,
                history: try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? 0
            )
        }
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

private struct RepositoryPlanLiveGraphCounts: Equatable {
    let phases: Int64
    let tickets: Int64
    let history: Int64
}

private actor RepositoryPlanPreviewSpy {
    struct Invocation: Equatable {
        let source: RepositoryPlanReconstructionSourceSnapshot
        let reviewedProjection: RepositoryPlanProjection
        let corrections: [RepositoryPlanReconstructionCorrection]
        let explicitMappings: [RepositoryPlanReconstructionMappingSelection]
    }

    private var calls: [Invocation] = []
    private var responses: [RepositoryPlanReconstructionPreview]
    private var failureCodes: [RepositoryPlanPreparationError.Code?]
    private var gates: [RepositoryPlanPreparationStartGate?]

    init(
        responses: [RepositoryPlanReconstructionPreview],
        failureCodes: [RepositoryPlanPreparationError.Code?] = [],
        gates: [RepositoryPlanPreparationStartGate?] = []
    ) {
        self.responses = responses
        self.failureCodes = failureCodes
        self.gates = gates
    }

    func preview(
        source: RepositoryPlanReconstructionSourceSnapshot,
        reviewedProjection: RepositoryPlanProjection,
        corrections: [RepositoryPlanReconstructionCorrection],
        explicitMappings: [RepositoryPlanReconstructionMappingSelection]
    ) async throws -> RepositoryPlanReconstructionPreview {
        calls.append(.init(
            source: source,
            reviewedProjection: reviewedProjection,
            corrections: corrections,
            explicitMappings: explicitMappings
        ))
        if !failureCodes.isEmpty, let failureCode = failureCodes.removeFirst() {
            throw RepositoryPlanPreparationError(code: failureCode)
        }
        guard !responses.isEmpty else {
            throw RepositoryPlanPreparationError(code: .invalidRequest)
        }
        let response = responses.removeFirst()
        if !gates.isEmpty, let gate = gates.removeFirst() {
            await gate.suspend()
        }
        return response
    }

    func invocations() -> [Invocation] { calls }
    func invocationCount() -> Int { calls.count }
}

private actor RepositoryPlanOwnerCommandDispatchSpy {
    struct Invocation: Equatable {
        let projectID: ProjectID
        let registration: ProjectRegistration
        let requestID: UUID
        let command: AgentCommand
    }

    private var calls: [Invocation] = []
    private var responses: [AgentCommandResult]
    private var gates: [RepositoryPlanPreparationStartGate?]

    init(
        responses: [AgentCommandResult],
        gates: [RepositoryPlanPreparationStartGate?] = []
    ) {
        self.responses = responses
        self.gates = gates
    }

    func dispatch(
        projectID: ProjectID,
        registration: ProjectRegistration,
        requestID: UUID,
        command: AgentCommand
    ) async -> AgentCommandResult {
        calls.append(.init(
            projectID: projectID,
            registration: registration,
            requestID: requestID,
            command: command
        ))
        guard !responses.isEmpty else {
            return .init(
                entityIDs: [],
                auditEventID: nil,
                error: .internalFailure("Unexpected reconstruction command dispatch.")
            )
        }
        let response = responses.removeFirst()
        if !gates.isEmpty, let gate = gates.removeFirst() {
            await gate.suspend()
        }
        return response
    }

    func invocations() -> [Invocation] { calls }
    func invocationCount() -> Int { calls.count }
}

private final class RepositoryPlanRequestIDGenerator: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UUID]

    init(values: [UUID]) {
        self.values = values
    }

    func next() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        return values.isEmpty ? UUID() : values.removeFirst()
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
    private var reviewDraftResponses: [RepositoryPlanPreparedDraft]
    private var startErrorCodes: [RepositoryPlanPreparationError.Code]
    private var reconcileErrorCodes: [RepositoryPlanPreparationError.Code]
    private var reviewDrafts: [RepositoryPlanPreparationIdentity] = []
    private let startGate: RepositoryPlanPreparationStartGate?
    private let targetUnavailable: Bool

    init(
        startResponses: [RepositoryPlanPreparationReadback],
        statusResponses: [RepositoryPlanPreparationReadback] = [],
        cancelResponses: [RepositoryPlanPreparationReadback] = [],
        reconcileResponses: [RepositoryPlanPreparationReadback] = [],
        reviewDraftResponses: [RepositoryPlanPreparedDraft] = [],
        startErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        reconcileErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        startGate: RepositoryPlanPreparationStartGate? = nil,
        targetUnavailable: Bool = false
    ) {
        self.startResponses = startResponses
        self.statusResponses = statusResponses
        self.cancelResponses = cancelResponses
        self.reconcileResponses = reconcileResponses
        self.reviewDraftResponses = reviewDraftResponses
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

    func reviewDraft(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparedDraft {
        reviewDrafts.append(identity)
        guard !reviewDraftResponses.isEmpty else {
            throw RepositoryPlanPreparationError(code: .invalidRequest)
        }
        return reviewDraftResponses.removeFirst()
    }

    func startInvocations() -> [StartInvocation] { starts }
    func statusInvocations() -> [RepositoryPlanPreparationIdentity] { statuses }
    func cancelInvocations() -> [RepositoryPlanPreparationIdentity] { cancellations }
    func reconcileInvocations() -> [RepositoryPlanPreparationIdentity] { reconciliations }
    func reviewDraftInvocations() -> [RepositoryPlanPreparationIdentity] { reviewDrafts }
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

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

        await model.removeRepositoryPlanExclusion(
            projectID: projectID,
            subject: historicalSubject
        )
        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertTrue(review.exclusions.isEmpty)
        XCTAssertEqual(
            review.comparisons.first { $0.subject == historicalSubject }?.disposition,
            .blocked
        )
        XCTAssertFalse(review.authorityConfirmed)
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

        await model.approveRepositoryPlanReconstruction(projectID: projectID)
        let dispatchCountAfterBlockedApproval = await dispatchSpy.invocationCount()
        XCTAssertEqual(
            dispatchCountAfterBlockedApproval,
            1,
            "A structurally valid blocked Save must remain review-only and never dispatch approval."
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

    func testProductionServiceRelaunchRecoversQueuedRunningUnknownAndReadyWithoutReplacementStart() async throws {
        let recoverableStates: [RepositoryPlanPreparationState] = [
            .queued,
            .running,
            .outcomeUnknown,
            .readyForReview,
        ]

        for (index, state) in recoverableStates.enumerated() {
            let fixture = try await ReconstructionFixture.make()
            addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
            let projectID = fixture.registration.projectID
            let manifest = fixture.payload.source.capturedSourceManifest
            let inventory = sourceInventory(for: fixture)
            let consent = RepositoryPlanPreparationConsent(
                inventory: inventory,
                selectedSources: inventory.sources,
                target: target
            )
            let attemptID = uuid(UInt8(140 + index))
            let projectionID = try XCTUnwrap(UUID(uuidString: fixture.projection.projectionID))
            let identity = RepositoryPlanPreparationIdentity(
                registration: fixture.registration,
                rootID: manifest.rootID,
                proposalID: .init(rawValue: "proposal-\(projectID.rawValue)"),
                attemptID: attemptID
            )
            let draftBytes = state == .readyForReview
                ? fixture.payload.source.projectionBytes
                : nil
            let expected = readback(
                identity: identity,
                state: state,
                draftBytes: draftBytes,
                error: state == .outcomeUnknown ? "Preparation outcome is unknown." : nil
            )
            let snapshotRoot = fixture.root.appendingPathComponent("preparation-snapshots")
            let firstPersistenceRequestID = uuid(UInt8(160 + index))
            let relaunchPersistenceRequestID = uuid(UInt8(190 + index))
            let firstClient = RepositoryPlanPreparationClientSpy(
                target: target,
                prepareResponses: [expected]
            )
            let firstService = RepositoryPlanPreparationService(
                client: firstClient,
                sourceCapture: { _ in manifest },
                snapshotRoot: { snapshotRoot },
                identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                    attemptID,
                    projectionID,
                ]).next,
                persistenceStore: fixture.store,
                persistenceRequestIDGenerator: { firstPersistenceRequestID }
            )

            let started = try await firstService.start(consent: consent)
            XCTAssertEqual(started, expected)

            let relaunchedClient = RepositoryPlanPreparationClientSpy(
                target: target,
                prepareResponses: []
            )
            let relaunchedService = RepositoryPlanPreparationService(
                client: relaunchedClient,
                sourceCapture: { _ in manifest },
                snapshotRoot: { snapshotRoot },
                identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                    uuid(UInt8(170 + index)),
                    uuid(UInt8(180 + index)),
                ]).next,
                persistenceStore: fixture.store,
                persistenceRequestIDGenerator: { relaunchPersistenceRequestID }
            )

            let recovered = try await relaunchedService.recover(projectID: projectID)
            XCTAssertEqual(recovered, [expected], "\(state) must survive service recreation exactly.")

            if state == .readyForReview {
                let recoveredDraft = try await relaunchedService.reviewDraft(identity: identity)
                XCTAssertEqual(recoveredDraft.source, fixture.payload.source)
                XCTAssertEqual(recoveredDraft.originalProjection, fixture.projection)
            } else {
                await XCTAssertThrowsErrorAsync {
                    try await relaunchedService.start(consent: consent)
                }
                let replacementPrepareCount = await relaunchedClient.prepareInvocationCount()
                XCTAssertEqual(replacementPrepareCount, 0)
            }

            let inventoryLoader = RepositoryPlanSourceInventoryLoaderSpy(
                responses: [inventory]
            )
            let store = fixture.store
            let model = try makeModel(
                projectID: projectID,
                service: relaunchedService,
                store: store,
                inventoryLoader: inventoryLoader,
                previewer: { source, reviewedProjection, corrections, explicitMappings in
                    try await RepositoryPlanReconstructionPreviewQuery.preview(
                        source: source,
                        reviewedProjection: reviewedProjection,
                        corrections: corrections,
                        explicitMappings: explicitMappings,
                        from: store
                    )
                }
            )

            await model.openRepositoryPlanReconstruction(projectID: projectID)

            let presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
            switch state {
            case .queued, .running, .awaitingResolution:
                XCTAssertEqual(presentation.stage, .preparing(state))
                XCTAssertEqual(presentation.preparation, expected)
            case .outcomeUnknown:
                XCTAssertEqual(presentation.stage, .outcomeUnknown)
                XCTAssertEqual(presentation.preparation, expected)
            case .readyForReview:
                XCTAssertEqual(presentation.stage, .reviewing)
                XCTAssertEqual(presentation.preparation, expected)
                XCTAssertEqual(presentation.review?.source, fixture.payload.source)
            case .failed, .cancelled:
                XCTFail("Terminal non-review state \(state) is not part of this recovery fixture.")
            }
            let inventoryLoadCount = await inventoryLoader.invocationCount()
            XCTAssertEqual(inventoryLoadCount, 0)
            await model.startRepositoryPlanPreparation(projectID: projectID)
            let relaunchedPrepareCount = await relaunchedClient.prepareInvocationCount()
            XCTAssertEqual(relaunchedPrepareCount, 0)
        }
    }

    func testProductionServicePersistsLearnedThreadAndTurnBeforeRelaunchRecovery() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let manifest = fixture.payload.source.capturedSourceManifest
        let inventory = sourceInventory(for: fixture)
        let consent = RepositoryPlanPreparationConsent(
            inventory: inventory,
            selectedSources: inventory.sources,
            target: target
        )
        let attemptID = uuid(230)
        let projectionID = try XCTUnwrap(UUID(uuidString: fixture.projection.projectionID))
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: manifest.rootID,
            proposalID: .init(rawValue: "proposal-\(projectID.rawValue)"),
            attemptID: attemptID
        )
        let threadProgress = RepositoryPlanPreparationReadback(
            identity: identity,
            state: .queued,
            threadID: "thread-durable-101",
            turnID: nil,
            draftBytes: nil,
            error: nil
        )
        let turnProgress = RepositoryPlanPreparationReadback(
            identity: identity,
            state: .running,
            threadID: "thread-durable-101",
            turnID: "turn-durable-101",
            draftBytes: nil,
            error: nil
        )
        let progressRecords = RepositoryPlanPreparationProgressRecordSpy()
        let persistenceRequestID = uuid(231)
        let client = RepositoryPlanPreparationClientSpy(
            target: target,
            prepareResponses: [turnProgress],
            progressResponses: [threadProgress, turnProgress],
            progressObservation: { _ in
                let records = try await RepositoryPlanPreparationPersistence.load(
                    projectID: projectID,
                    from: fixture.store
                )
                guard let record = records.first(where: {
                    $0.request.identity == identity && $0.isCurrent
                }) else {
                    throw RepositoryPlanPreparationError(code: .identityMismatch)
                }
                await progressRecords.append(record)
            }
        )
        let snapshotRoot = fixture.root.appendingPathComponent("preparation-snapshots")
        let service = RepositoryPlanPreparationService(
            client: client,
            sourceCapture: { _ in manifest },
            snapshotRoot: { snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                attemptID,
                projectionID,
            ]).next,
            persistenceStore: fixture.store,
            persistenceRequestIDGenerator: { persistenceRequestID }
        )

        let started = try await service.start(consent: consent)

        XCTAssertEqual(started, turnProgress)
        let recordedProgress = await progressRecords.values
        XCTAssertEqual(recordedProgress.count, 2)
        if recordedProgress.count == 2 {
            XCTAssertEqual(recordedProgress[0].revision, 2)
            XCTAssertEqual(recordedProgress[0].state, .queued)
            XCTAssertEqual(recordedProgress[0].threadID, "thread-durable-101")
            XCTAssertNil(recordedProgress[0].turnID)
            XCTAssertEqual(recordedProgress[1].revision, 3)
            XCTAssertEqual(recordedProgress[1].state, .running)
            XCTAssertEqual(recordedProgress[1].threadID, "thread-durable-101")
            XCTAssertEqual(recordedProgress[1].turnID, "turn-durable-101")
        }

        let relaunchedClient = RepositoryPlanPreparationClientSpy(
            target: target,
            prepareResponses: [],
            statusResponses: [turnProgress]
        )
        let relaunchPersistenceRequestID = uuid(234)
        let relaunched = RepositoryPlanPreparationService(
            client: relaunchedClient,
            sourceCapture: { _ in manifest },
            snapshotRoot: { snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                uuid(232),
                uuid(233),
            ]).next,
            persistenceStore: fixture.store,
            persistenceRequestIDGenerator: { relaunchPersistenceRequestID }
        )

        let recovered = try await relaunched.recover(projectID: projectID)
        let restores = await relaunchedClient.restoreInvocations()
        let replacementPrepareCount = await relaunchedClient.prepareInvocationCount()

        XCTAssertEqual(recovered, [turnProgress])
        XCTAssertEqual(restores.count, 1)
        XCTAssertEqual(restores.first?.request.identity, identity)
        XCTAssertEqual(restores.first?.readback, turnProgress)
        XCTAssertEqual(replacementPrepareCount, 0)
    }

    func testProductionServiceRetriesExactRestoreAfterRecoverySetupReturns() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let manifest = fixture.payload.source.capturedSourceManifest
        let inventory = sourceInventory(for: fixture)
        let consent = RepositoryPlanPreparationConsent(
            inventory: inventory,
            selectedSources: inventory.sources,
            target: target
        )
        let attemptID = uuid(235)
        let projectionID = try XCTUnwrap(UUID(uuidString: fixture.projection.projectionID))
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: manifest.rootID,
            proposalID: .init(rawValue: "proposal-\(projectID.rawValue)"),
            attemptID: attemptID
        )
        let storedUnknown = RepositoryPlanPreparationReadback(
            identity: identity,
            state: .outcomeUnknown,
            threadID: "thread-retry-101",
            turnID: "turn-retry-101",
            draftBytes: nil,
            error: "The exact stored attempt still needs reconciliation."
        )
        let terminalFailure = RepositoryPlanPreparationReadback(
            identity: identity,
            state: .failed,
            threadID: "thread-retry-101",
            turnID: "turn-retry-101",
            draftBytes: nil,
            error: "The exact stored turn failed."
        )
        let snapshotRoot = fixture.root.appendingPathComponent("preparation-snapshots")
        let firstPersistenceRequestID = uuid(236)
        let firstService = RepositoryPlanPreparationService(
            client: RepositoryPlanPreparationClientSpy(
                target: target,
                prepareResponses: [storedUnknown]
            ),
            sourceCapture: { _ in manifest },
            snapshotRoot: { snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                attemptID,
                projectionID,
            ]).next,
            persistenceStore: fixture.store,
            persistenceRequestIDGenerator: { firstPersistenceRequestID }
        )
        let started = try await firstService.start(consent: consent)
        XCTAssertEqual(started, storedUnknown)

        let retryClient = RepositoryPlanPreparationClientSpy(
            target: target,
            prepareResponses: [],
            statusResponses: [terminalFailure],
            restoreErrorCodes: [.outcomeUnknown],
            requireSuccessfulRestoreBeforeStatus: true
        )
        let relaunchPersistenceRequestID = uuid(237)
        let relaunched = RepositoryPlanPreparationService(
            client: retryClient,
            sourceCapture: { _ in manifest },
            snapshotRoot: { snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                uuid(238),
                uuid(239),
            ]).next,
            persistenceStore: fixture.store,
            persistenceRequestIDGenerator: { relaunchPersistenceRequestID }
        )

        let initiallyRecovered = try await relaunched.recover(projectID: projectID)
        XCTAssertEqual(initiallyRecovered.count, 1)
        XCTAssertEqual(initiallyRecovered.first?.state, .outcomeUnknown)
        XCTAssertEqual(initiallyRecovered.first?.threadID, "thread-retry-101")
        XCTAssertEqual(initiallyRecovered.first?.turnID, "turn-retry-101")

        let reconciled = try await relaunched.reconcile(identity: identity)
        let restores = await retryClient.restoreInvocations()
        let statuses = await retryClient.statusInvocations()
        let closes = await retryClient.closeInvocations()
        let replacementPrepareCount = await retryClient.prepareInvocationCount()

        XCTAssertEqual(reconciled, terminalFailure)
        XCTAssertEqual(restores.count, 2)
        XCTAssertTrue(restores.allSatisfy { $0.request.identity == identity })
        XCTAssertTrue(restores.allSatisfy {
            $0.readback.threadID == "thread-retry-101"
                && $0.readback.turnID == "turn-retry-101"
        })
        XCTAssertEqual(statuses, [identity])
        XCTAssertEqual(closes, [identity])
        XCTAssertEqual(replacementPrepareCount, 0)
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

    func testProductionServiceRelaunchKeepsTerminalCloseFailureNonreplaceable() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let inventory = sourceInventory(for: fixture)
        let consent = RepositoryPlanPreparationConsent(
            inventory: inventory,
            selectedSources: inventory.sources,
            target: target
        )
        let attemptID = uuid(215)
        let projectionID = try XCTUnwrap(UUID(uuidString: fixture.projection.projectionID))
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: fixture.payload.source.rootID,
            proposalID: .init(rawValue: "proposal-\(projectID.rawValue)"),
            attemptID: attemptID
        )
        let firstClient = RepositoryPlanPreparationClientSpy(
            target: target,
            prepareResponses: [readback(identity: identity, state: .running)],
            statusResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: fixture.payload.source.projectionBytes
            )],
            closeErrorCodes: [.outcomeUnknown]
        )
        let snapshotRoot = fixture.root.appendingPathComponent("preparation-close-failure")
        let firstPersistenceID = uuid(216)
        let firstService = RepositoryPlanPreparationService(
            client: firstClient,
            sourceCapture: { _ in fixture.payload.source.capturedSourceManifest },
            snapshotRoot: { snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                attemptID,
                projectionID,
            ]).next,
            persistenceStore: fixture.store,
            persistenceRequestIDGenerator: { firstPersistenceID }
        )
        _ = try await firstService.start(consent: consent)
        await XCTAssertThrowsErrorAsync {
            try await firstService.status(identity: identity)
        }

        let replacement = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: fixture.payload.source.rootID,
            proposalID: identity.proposalID,
            attemptID: uuid(217)
        )
        let relaunchedClient = RepositoryPlanPreparationClientSpy(
            target: target,
            prepareResponses: [readback(identity: replacement, state: .queued)]
        )
        let relaunchPersistenceID = uuid(219)
        let relaunched = RepositoryPlanPreparationService(
            client: relaunchedClient,
            sourceCapture: { _ in fixture.payload.source.capturedSourceManifest },
            snapshotRoot: { snapshotRoot },
            identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                replacement.attemptID,
                uuid(218),
            ]).next,
            persistenceStore: fixture.store,
            persistenceRequestIDGenerator: { relaunchPersistenceID }
        )

        let recovered = try await relaunched.recover(projectID: projectID)
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(recovered.first?.identity, identity)
        XCTAssertEqual(recovered.first?.state, .outcomeUnknown)
        await XCTAssertThrowsErrorAsync {
            try await relaunched.start(consent: consent)
        }
        let replacementPrepareCount = await relaunchedClient.prepareInvocationCount()
        XCTAssertEqual(replacementPrepareCount, 0)
    }

    func testProductionServicePrepareFailureRetainedTerminalStillRequiresPhysicalClose() async throws {
        for (index, retainedState) in [
            RepositoryPlanPreparationState.readyForReview,
            .failed,
            .cancelled,
        ].enumerated() {
            let fixture = try await ReconstructionFixture.make()
            addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
            let projectID = fixture.registration.projectID
            let inventory = sourceInventory(for: fixture)
            let consent = RepositoryPlanPreparationConsent(
                inventory: inventory,
                selectedSources: inventory.sources,
                target: target
            )
            let attemptID = uuid(UInt8(220 + index * 4))
            let projectionID = try XCTUnwrap(UUID(uuidString: fixture.projection.projectionID))
            let identity = RepositoryPlanPreparationIdentity(
                registration: fixture.registration,
                rootID: fixture.payload.source.rootID,
                proposalID: .init(rawValue: "proposal-\(projectID.rawValue)"),
                attemptID: attemptID
            )
            let retained = readback(
                identity: identity,
                state: retainedState,
                draftBytes: retainedState == .readyForReview
                    ? fixture.payload.source.projectionBytes
                    : nil
            )
            let client = RepositoryPlanPreparationClientSpy(
                target: target,
                prepareResponses: [],
                statusResponses: [retained],
                closeErrorCodes: [.outcomeUnknown],
                prepareErrorCodes: [.outcomeUnknown]
            )
            let snapshotRoot = fixture.root.appendingPathComponent(
                "prepare-retained-terminal-\(retainedState.rawValue)"
            )
            let persistenceID = uuid(UInt8(221 + index * 4))
            let service = RepositoryPlanPreparationService(
                client: client,
                sourceCapture: { _ in fixture.payload.source.capturedSourceManifest },
                snapshotRoot: { snapshotRoot },
                identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                    attemptID,
                    projectionID,
                ]).next,
                persistenceStore: fixture.store,
                persistenceRequestIDGenerator: { persistenceID }
            )

            await XCTAssertThrowsErrorAsync {
                try await service.start(consent: consent)
            }
            let closes = await client.closeInvocations()
            XCTAssertEqual(closes, [identity], "\(retainedState) must require exact physical close.")

            let replacement = RepositoryPlanPreparationIdentity(
                registration: fixture.registration,
                rootID: fixture.payload.source.rootID,
                proposalID: identity.proposalID,
                attemptID: uuid(UInt8(222 + index * 4))
            )
            let relaunchedClient = RepositoryPlanPreparationClientSpy(
                target: target,
                prepareResponses: [readback(identity: replacement, state: .queued)]
            )
            let relaunchPersistenceID = uuid(UInt8(223 + index * 4))
            let relaunched = RepositoryPlanPreparationService(
                client: relaunchedClient,
                sourceCapture: { _ in fixture.payload.source.capturedSourceManifest },
                snapshotRoot: { snapshotRoot },
                identityGenerator: RepositoryPlanPreparationIdentityGenerator(values: [
                    replacement.attemptID,
                    uuid(UInt8(224 + index * 4)),
                ]).next,
                persistenceStore: fixture.store,
                persistenceRequestIDGenerator: { relaunchPersistenceID }
            )

            let recovered = try await relaunched.recover(projectID: projectID)
            XCTAssertEqual(recovered.first?.identity, identity)
            XCTAssertEqual(recovered.first?.state, .outcomeUnknown)
            await XCTAssertThrowsErrorAsync {
                try await relaunched.start(consent: consent)
            }
            let replacementPrepareCount = await relaunchedClient.prepareInvocationCount()
            XCTAssertEqual(replacementPrepareCount, 0)
        }
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

    func testRealStoreApprovesAndAppliesExactSavedReconstructionIntoPlanBoardAndHistory() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let proposalID = PlanChangeProposalID(rawValue: "proposal-app-final-journey")
        let model = try makeRealReviewModel(fixture: fixture, proposalID: proposalID)

        await model.openRepositoryPlanReconstruction(projectID: fixture.registration.projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: fixture.registration.projectID,
            artifactID: "current",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: fixture.registration.projectID)
        model.setRepositoryPlanAuthorityConfirmed(
            projectID: fixture.registration.projectID,
            confirmed: true
        )
        await model.saveRepositoryPlanReconstruction(
            projectID: fixture.registration.projectID,
            rationale: "Save the owner-reviewed repository plan before approval."
        )

        let saved = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: fixture.registration.projectID)?.review?.savedReadback
        )
        let decisionID = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: fixture.registration.projectID)?.review?.decisionID
        )
        XCTAssertNil(saved.version.decision)
        XCTAssertNil(saved.applicationAttempt)
        let phaseCountBeforeApproval = try await fixture.phaseCount(id: "phase-101")
        XCTAssertEqual(phaseCountBeforeApproval, 0)

        await model.approveRepositoryPlanReconstruction(projectID: fixture.registration.projectID)

        let approved = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: fixture.registration.projectID)?.review?.savedReadback
        )
        XCTAssertEqual(approved.version.version, saved.version.version)
        XCTAssertEqual(approved.version.baselineDigest, saved.version.baselineDigest)
        XCTAssertEqual(approved.version.decision?.id, decisionID)
        XCTAssertEqual(approved.version.decision?.disposition, .approved)
        XCTAssertNil(approved.applicationAttempt)
        let phaseCountBeforeApply = try await fixture.phaseCount(id: "phase-101")
        XCTAssertEqual(phaseCountBeforeApply, 0)

        await model.applyRepositoryPlanReconstruction(projectID: fixture.registration.projectID)

        let presentation = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: fixture.registration.projectID)
        )
        XCTAssertEqual(presentation.stage, .applied)
        let applied = try XCTUnwrap(presentation.review?.savedReadback)
        XCTAssertEqual(applied.proposalID, proposalID)
        XCTAssertEqual(applied.version.version, saved.version.version)
        XCTAssertEqual(applied.version.baselineDigest, saved.version.baselineDigest)
        XCTAssertEqual(applied.version.decision?.id, decisionID)
        XCTAssertNotNil(applied.version.application)
        XCTAssertEqual(applied.applicationAttempt?.state, .applied)
        XCTAssertEqual(applied.provenance.count, 1)
        XCTAssertTrue(applied.remainingSetup.isEmpty)

        let exactReadbacks = try await RepositoryPlanReconstructionQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID,
            proposalID: proposalID
        )
        let exactReadback = try XCTUnwrap(exactReadbacks.first)
        XCTAssertEqual(applied, exactReadback)
        let destinationPhaseID = try XCTUnwrap(applied.provenance.first?.comparison.destinationID)
        let phaseCountAfterApply = try await fixture.phaseCount(id: destinationPhaseID)
        XCTAssertEqual(phaseCountAfterApply, 1)

        let plan = try XCTUnwrap(model.dashboard?.plan(for: fixture.registration.projectID))
        XCTAssertEqual(plan.phases.map(\.id), [.init(rawValue: destinationPhaseID)])
        XCTAssertEqual(plan.proposals.first?.id, proposalID)
        XCTAssertNotNil(model.dashboard?.allPhaseBoard(for: fixture.registration.projectID))
        let history = try XCTUnwrap(model.activity(for: fixture.registration.projectID))
        XCTAssertTrue(history.items.contains {
            $0.source == .audit
                && $0.detail == "Exercise the complete repository plan owner journey."
        })

        await model.navigate(to: .projectPlan(fixture.registration.projectID))
        XCTAssertEqual(model.selection, .projectPlan(fixture.registration.projectID))
        XCTAssertEqual(
            model.dashboard?.plan(for: fixture.registration.projectID)?.phases.map(\.id),
            [.init(rawValue: destinationPhaseID)]
        )

        model.viewAllPhases(projectID: fixture.registration.projectID)
        await model.navigate(to: .phaseBoard(fixture.registration.projectID))
        XCTAssertEqual(model.selection, .phaseBoard(fixture.registration.projectID))
        XCTAssertNotNil(model.dashboard?.allPhaseBoard(for: fixture.registration.projectID))

        await model.navigate(to: .activity(fixture.registration.projectID))
        XCTAssertEqual(model.selection, .activity(fixture.registration.projectID))
        XCTAssertTrue(model.activity(for: fixture.registration.projectID)?.items.contains {
            $0.source == .audit
                && $0.detail == "Exercise the complete repository plan owner journey."
        } == true)
    }

    func testPolicyBEvidenceEditsRetainDecisionIdentityInvalidateSaveAndRejectMixedAttestations() async throws {
        let projectID = ProjectID(rawValue: "project-policy-b-evidence")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(111))
        let draft = preparedDraft(projectID: projectID)
        let initialPreview = preview(for: draft.originalProjection)
        let previewSpy = RepositoryPlanPreviewSpy(responses: [
            initialPreview,
            initialPreview,
            initialPreview,
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
            previewSpy: previewSpy
        )
        await openReadyReview(model, projectID: projectID)
        let initial = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        let decisionID = initial.decisionID
        let evidence = RepositoryPlanTerminalEvidence.ownerAttestation(.init(
            id: "attestation-policy-b-owner",
            subject: .ticket(.init(
                sourceID: "ticket-historical",
                outcome: "Historical ticket",
                phaseSourceID: "phase-historical",
                taskPlan: nil
            )),
            state: .accepted,
            phaseCompletion: nil,
            decisionID: decisionID,
            attestedAt: Date(timeIntervalSince1970: 1_700_000_000),
            originalOccurredAt: nil,
            originalActorID: nil
        ))

        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.setRepositoryPlanTerminalEvidence(projectID: projectID, evidence: [evidence])

        var review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.decisionID, decisionID)
        XCTAssertEqual(review.terminalEvidence, [evidence])
        XCTAssertFalse(review.authorityConfirmed)
        XCTAssertNil(review.savedReadback)
        XCTAssertEqual(review.revision, initial.revision + 1)

        let mismatched = RepositoryPlanTerminalEvidence.ownerAttestation(.init(
            id: "attestation-policy-b-wrong-decision",
            subject: .ticket(.init(
                sourceID: "ticket-historical",
                outcome: "Historical ticket",
                phaseSourceID: "phase-historical",
                taskPlan: nil
            )),
            state: .accepted,
            phaseCompletion: nil,
            decisionID: "decision-from-another-review",
            attestedAt: Date(timeIntervalSince1970: 1_700_000_001),
            originalOccurredAt: nil,
            originalActorID: nil
        ))
        await model.setRepositoryPlanTerminalEvidence(
            projectID: projectID,
            evidence: [evidence, mismatched]
        )

        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.terminalEvidence, [evidence])
        XCTAssertEqual(review.revision, initial.revision + 1)
        XCTAssertNotNil(model.repositoryPlanReconstruction(for: projectID)?.message)
        let previewCountAfterMismatch = await previewSpy.invocationCount()
        XCTAssertEqual(previewCountAfterMismatch, 2)

        await model.setRepositoryPlanTerminalEvidence(projectID: projectID, evidence: [])
        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.decisionID, decisionID)
        XCTAssertTrue(review.terminalEvidence.isEmpty)
        XCTAssertEqual(review.revision, initial.revision + 2)
        let finalPreviewCount = await previewSpy.invocationCount()
        XCTAssertEqual(finalPreviewCount, 3)
    }

    func testCompletedAndSupersededAttestationsForOneTaskSurviveIndependentRemoval() async throws {
        let projectID = ProjectID(rawValue: "project-policy-b-task-states")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(227))
        let draft = preparedDraft(
            projectID: projectID,
            includeTask: true,
            includeHistorical: false
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
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: previewSpy
        )
        await openReadyReview(model, projectID: projectID)
        let decisionID = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.decisionID
        )
        let taskSubject = RepositoryPlanStateSubject.task(.init(
            ticketSourceID: "ticket-current",
            sourceID: "task-current",
            label: "Task 1",
            title: "Implement the approved work",
            sortOrder: 0
        ))
        let completed = RepositoryPlanTerminalEvidence.ownerAttestation(.init(
            id: "attestation-task-completed",
            subject: taskSubject,
            state: .completed,
            phaseCompletion: nil,
            decisionID: decisionID,
            attestedAt: Date(timeIntervalSince1970: 1_700_000_010),
            originalOccurredAt: nil,
            originalActorID: nil
        ))
        let superseded = RepositoryPlanTerminalEvidence.ownerAttestation(.init(
            id: "attestation-task-superseded",
            subject: taskSubject,
            state: .superseded,
            phaseCompletion: nil,
            decisionID: decisionID,
            attestedAt: Date(timeIntervalSince1970: 1_700_000_011),
            originalOccurredAt: nil,
            originalActorID: nil
        ))

        await model.setRepositoryPlanTerminalEvidence(
            projectID: projectID,
            evidence: [completed, superseded]
        )
        var review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.terminalEvidence, [completed, superseded])

        await model.setRepositoryPlanTerminalEvidence(
            projectID: projectID,
            evidence: [superseded]
        )
        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.terminalEvidence, [superseded])
        XCTAssertEqual(review.decisionID, decisionID)
        XCTAssertFalse(review.authorityConfirmed)
    }

    func testTypedTaskOrderAndNullableTicketCorrectionsReachTheReviewedProjection() async throws {
        let projectID = ProjectID(rawValue: "project-typed-corrections")
        let identity = preparationIdentity(projectID: projectID, attemptID: uuid(228))
        let draft = preparedDraft(
            projectID: projectID,
            includeTask: true,
            includeHistorical: false
        )
        let basePreview = preview(for: draft.originalProjection)
        let previewSpy = RepositoryPlanPreviewSpy(responses: [
            basePreview,
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
        let model = try makeModel(
            projectID: projectID,
            service: service,
            previewSpy: previewSpy
        )
        await openReadyReview(model, projectID: projectID)
        let taskSubject = RepositoryPlanReconstructionSubject(
            kind: .task,
            parentSourceID: "ticket-current",
            sourceID: "task-current"
        )
        let ticketSubject = RepositoryPlanReconstructionSubject(
            kind: .ticket,
            parentSourceID: nil,
            sourceID: "ticket-current"
        )
        let encoder = JSONEncoder()

        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: taskSubject,
            field: "sortOrder",
            chosenValue: try encoder.encode(7)
        )
        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: ticketSubject,
            field: "phaseSourceID",
            chosenValue: try encoder.encode(Optional<String>.none)
        )
        await model.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: ticketSubject,
            field: "lane",
            chosenValue: try encoder.encode(Optional<String>.none)
        )

        let review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        let ticket = try XCTUnwrap(review.reviewedProjection.tickets.first)
        XCTAssertEqual(ticket.taskPlan?.tasks.first?.sortOrder, 7)
        XCTAssertNil(ticket.phaseSourceID)
        XCTAssertNil(ticket.lane)
        XCTAssertEqual(review.corrections.count, 3)
    }

    func testRelaunchHydratesUnknownApplyAndRecoversByReplayingExactRecordedEnvelopeOnce() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let proposalID = "proposal-app-unknown-recovery"
        let approved = try await fixture.saveAndApprove(proposalID: proposalID)
        let envelope = fixture.applyEnvelope(
            proposalID: approved.proposalID,
            baselineDigest: approved.baselineDigest,
            decisionID: approved.decisionID,
            applicationID: "application-app-unknown-recovery",
            requestID: uuid(113)
        )
        try await fixture.insertPendingAttempt(envelope)
        let pendingReadbacks = try await RepositoryPlanReconstructionQuery.load(
            from: fixture.store,
            projectID: fixture.registration.projectID,
            proposalID: .init(rawValue: proposalID)
        )
        let recordedBytes = try XCTUnwrap(pendingReadbacks.first?.applicationAttempt?.envelopeBytes)
        let replayer = RepositoryPlanApplyReplaySpy(dispatcher: fixture.dispatcher)
        let service = RepositoryPlanPreparationServiceSpy(startResponses: [])
        let model = try makeModel(
            projectID: fixture.registration.projectID,
            service: service,
            store: fixture.store,
            inventoryLoader: .init(responses: [sourceInventory(for: fixture)]),
            readbackLoader: { store, projectID, proposalID in
                try await RepositoryPlanReconstructionQuery.load(
                    from: store,
                    projectID: projectID,
                    proposalID: proposalID
                )
            },
            applyReconciler: { attempt in
                try await fixture.dispatcher.reconcileReconstructionApply(
                    projectID: attempt.projectID,
                    proposalID: attempt.proposalID,
                    version: attempt.version,
                    applicationID: attempt.applicationID,
                    requestID: attempt.requestID
                )
            },
            applyReplayer: { attempt in
                await replayer.replay(attempt)
            }
        )

        await model.openRepositoryPlanReconstruction(projectID: fixture.registration.projectID)

        var presentation = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: fixture.registration.projectID)
        )
        XCTAssertEqual(presentation.stage, .outcomeUnknown)
        XCTAssertEqual(presentation.review?.savedReadback?.applicationAttempt?.state, .pending)
        XCTAssertEqual(presentation.review?.savedReadback?.applicationAttempt?.envelopeBytes, recordedBytes)
        let preparationStartsAfterRelaunch = await service.startInvocations()
        XCTAssertTrue(preparationStartsAfterRelaunch.isEmpty)

        await model.recoverRepositoryPlanReconstructionApply(
            projectID: fixture.registration.projectID
        )

        presentation = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: fixture.registration.projectID)
        )
        XCTAssertEqual(presentation.stage, .applied)
        XCTAssertEqual(presentation.review?.savedReadback?.applicationAttempt?.state, .applied)
        let replayedAttempts = await replayer.invocations()
        XCTAssertEqual(replayedAttempts.count, 1)
        XCTAssertEqual(replayedAttempts.first?.envelopeBytes, recordedBytes)
        XCTAssertEqual(replayedAttempts.first?.applicationID, "application-app-unknown-recovery")
        XCTAssertEqual(replayedAttempts.first?.requestID, envelope.requestID)

        await model.recoverRepositoryPlanReconstructionApply(
            projectID: fixture.registration.projectID
        )
        let finalReplayCount = await replayer.invocationCount()
        XCTAssertEqual(finalReplayCount, 1)
    }

    func testOverlappingApproveAndApplyEachDispatchOnceWithStableExactIdentities() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let approvalGate = RepositoryPlanPreparationStartGate()
        let applyGate = RepositoryPlanPreparationStartGate()
        let dispatch = RepositoryPlanJourneyDispatchSpy(
            dispatcher: fixture.dispatcher,
            projectRoot: fixture.root.path,
            approvalGate: approvalGate,
            applyGate: applyGate
        )
        let model = try makeRealReviewModel(
            fixture: fixture,
            proposalID: .init(rawValue: "proposal-app-overlap"),
            commandDispatch: { projectID, registration, requestID, command in
                await dispatch.dispatch(
                    projectID: projectID,
                    registration: registration,
                    requestID: requestID,
                    command: command
                )
            }
        )
        let projectID = fixture.registration.projectID
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
            rationale: "Save before exercising duplicate owner actions."
        )
        let decisionID = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.decisionID
        )

        let firstApproval = Task {
            await model.approveRepositoryPlanReconstruction(projectID: projectID)
        }
        await approvalGate.waitUntilEntered()
        await model.approveRepositoryPlanReconstruction(projectID: projectID)
        let approvalsWhilePending = await dispatch.approvalInvocations()
        XCTAssertEqual(approvalsWhilePending.count, 1)
        await approvalGate.release()
        await firstApproval.value
        let approvedReadback = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        XCTAssertEqual(approvedReadback.version.decision?.id, decisionID)

        let firstApply = Task {
            await model.applyRepositoryPlanReconstruction(projectID: projectID)
        }
        await applyGate.waitUntilEntered()
        await model.applyRepositoryPlanReconstruction(projectID: projectID)
        let appliesWhilePending = await dispatch.applyInvocations()
        XCTAssertEqual(appliesWhilePending.count, 1)
        await applyGate.release()
        await firstApply.value

        let approvalCommands = await dispatch.approvalInvocations()
        let applyCommands = await dispatch.applyInvocations()
        XCTAssertEqual(approvalCommands.count, 1)
        XCTAssertEqual(applyCommands.count, 1)
        guard case let .decidePlanChangeProposal(
            approvedProposalID,
            approvedVersion,
            approvedBaseline,
            approvedDecisionID,
            .approved
        ) = approvalCommands[0] else {
            return XCTFail("Expected one exact approval command.")
        }
        guard case let .applyPlanChangeProposal(
            appliedProposalID,
            appliedVersion,
            appliedBaseline,
            appliedDecisionID,
            _
        ) = applyCommands[0] else {
            return XCTFail("Expected one exact Apply command.")
        }
        XCTAssertEqual(appliedProposalID, approvedProposalID)
        XCTAssertEqual(appliedVersion, approvedVersion)
        XCTAssertEqual(appliedBaseline, approvedBaseline)
        XCTAssertEqual(approvedDecisionID, decisionID)
        XCTAssertEqual(appliedDecisionID, decisionID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .applied)
    }

    func testStaleApplyPreservesExactApprovedReadbackAndDoesNotCreateAnotherAttempt() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let proposalID = PlanChangeProposalID(rawValue: "proposal-app-stale")
        let model = try makeRealReviewModel(fixture: fixture, proposalID: proposalID)
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
            rationale: "Save before exercising stale Apply recovery."
        )
        await model.approveRepositoryPlanReconstruction(projectID: projectID)
        let approved = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        try await fixture.seedPhase(id: "later-destination-phase", name: "Later destination state")

        await model.applyRepositoryPlanReconstruction(projectID: projectID)

        var presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .reviewing)
        let refused = try XCTUnwrap(presentation.review?.savedReadback)
        XCTAssertEqual(refused.proposalID, approved.proposalID)
        XCTAssertEqual(refused.version.version, approved.version.version)
        XCTAssertEqual(refused.version.baselineDigest, approved.version.baselineDigest)
        XCTAssertEqual(refused.version.decision, approved.version.decision)
        XCTAssertEqual(refused.applicationAttempt?.state, .refused)
        XCTAssertNotNil(presentation.message)
        let expectedDestinationID = RepositoryPlanReconstructionIdentity.destinationID(
            source: refused.payload.source,
            subject: refused.payload.comparisons[0].subject
        )
        let refusedDestinationCount = try await fixture.phaseCount(id: expectedDestinationID)
        XCTAssertEqual(refusedDestinationCount, 0)
        let firstAttempt = try XCTUnwrap(refused.applicationAttempt)

        await model.applyRepositoryPlanReconstruction(projectID: projectID)

        presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        let retainedAttempt = try XCTUnwrap(
            presentation.review?.savedReadback?.applicationAttempt
        )
        XCTAssertEqual(retainedAttempt, firstAttempt)
        XCTAssertEqual(presentation.stage, .reviewing)

        await model.beginFreshRepositoryPlanPreparation(projectID: projectID)

        presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .selectingSources)
        XCTAssertTrue(presentation.selectedArtifactIDs.isEmpty)
        XCTAssertNil(presentation.preparation)
        XCTAssertNil(presentation.review)
    }

    func testAppliedReconstructionReportsProjectionRefreshFailureWithoutClaimingRefreshedSuccess() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let dashboardLoads = RepositoryPlanDashboardLoadGate(failures: 1)
        let model = try makeRealReviewModel(
            fixture: fixture,
            proposalID: .init(rawValue: "proposal-app-refresh-failure"),
            dashboardLoader: { store in
                try await dashboardLoads.load(from: store)
            }
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
            rationale: "Apply while the post-commit projection refresh fails."
        )
        await model.approveRepositoryPlanReconstruction(projectID: projectID)

        await model.applyRepositoryPlanReconstruction(projectID: projectID)

        let presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .applied)
        let message = try XCTUnwrap(presentation.message)
        XCTAssertTrue(message.localizedCaseInsensitiveContains("applied"))
        XCTAssertTrue(
            message.localizedCaseInsensitiveContains("could not refresh")
                || message.localizedCaseInsensitiveContains("reload")
        )
        XCTAssertFalse(message.localizedCaseInsensitiveContains("have been refreshed"))

        await model.retryRepositoryPlanProjectionRefresh(projectID: projectID)

        let refreshed = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(refreshed.stage, .applied)
        let refreshedMessage = try XCTUnwrap(refreshed.message)
        XCTAssertTrue(refreshedMessage.localizedCaseInsensitiveContains("reloaded successfully"))
        let dashboardLoadCount = await dashboardLoads.invocationCount()
        XCTAssertEqual(dashboardLoadCount, 2)
    }

    func testRelaunchHydratedSavedReviewCanEditAndSaveTheExactProposalAsVersionTwo() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let proposalID = PlanChangeProposalID(rawValue: "proposal-app-relaunch-resave")
        let firstModel = try makeRealReviewModel(fixture: fixture, proposalID: proposalID)
        await firstModel.openRepositoryPlanReconstruction(projectID: projectID)
        firstModel.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "current",
            selected: true
        )
        await firstModel.startRepositoryPlanPreparation(projectID: projectID)
        firstModel.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await firstModel.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the first exact version before relaunch."
        )
        XCTAssertEqual(
            firstModel.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback?.version.version,
            1
        )

        let store = fixture.store
        let dispatcher = fixture.dispatcher
        let registration = fixture.registration
        let projectRoot = fixture.root.path
        let relaunchedService = RepositoryPlanPreparationServiceSpy(startResponses: [])
        let relaunched = try makeModel(
            projectID: projectID,
            service: relaunchedService,
            store: store,
            inventoryLoader: .init(responses: [sourceInventory(for: fixture)]),
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
                    reason: "Resave the exact persisted reconstruction after relaunch.",
                    command: command
                ), origin: .ownerApp)
            },
            requestIDs: [uuid(133)]
        )
        await relaunched.openRepositoryPlanReconstruction(projectID: projectID)

        let subject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-101"
        )
        await relaunched.setRepositoryPlanCorrection(
            projectID: projectID,
            subject: subject,
            field: "name",
            chosenValue: try JSONEncoder().encode("Reviewed after relaunch")
        )
        relaunched.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await relaunched.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the reviewed relaunch edit."
        )

        let saved = try XCTUnwrap(
            relaunched.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        XCTAssertEqual(saved.proposalID, proposalID)
        XCTAssertEqual(saved.version.version, 2)
        XCTAssertEqual(saved.payload.corrections.map(\.subject), [subject])
        let relaunchStarts = await relaunchedService.startInvocations()
        XCTAssertEqual(relaunchStarts.count, 0)
    }

    func testRelaunchPrioritizesNewerActivePreparationOverOlderSavedProposal() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let first = try makeRealReviewModel(
            fixture: fixture,
            proposalID: .init(rawValue: "proposal-app-older-saved")
        )
        await first.openRepositoryPlanReconstruction(projectID: projectID)
        first.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "current",
            selected: true
        )
        await first.startRepositoryPlanPreparation(projectID: projectID)
        first.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await first.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the older proposal before a newer preparation begins."
        )

        let activeIdentity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: fixture.payload.source.rootID,
            proposalID: .init(rawValue: "proposal-app-newer-active"),
            attemptID: uuid(214)
        )
        let activeDraft = RepositoryPlanPreparedDraft(
            source: fixture.payload.source,
            originalProjection: fixture.projection
        )
        let active = readback(
            identity: activeIdentity,
            state: .readyForReview,
            draftBytes: activeDraft.source.projectionBytes
        )
        let recoveringService = RepositoryPlanPreparationServiceSpy(
            startResponses: [],
            recoverResponses: [[active]],
            reviewDraftResponses: [activeDraft]
        )
        let relaunched = try makeModel(
            projectID: projectID,
            service: recoveringService,
            store: fixture.store,
            inventoryLoader: .init(responses: [sourceInventory(for: fixture)]),
            previewSpy: .init(responses: [preview(for: activeDraft.originalProjection)])
        )

        await relaunched.openRepositoryPlanReconstruction(projectID: projectID)

        let presentation = try XCTUnwrap(
            relaunched.repositoryPlanReconstruction(for: projectID)
        )
        XCTAssertEqual(presentation.stage, .reviewing)
        XCTAssertEqual(presentation.preparation, active)
        XCTAssertEqual(presentation.review?.source, activeDraft.source)
        XCTAssertNil(presentation.review?.savedReadback)
        let recoveryProjects = await recoveringService.recoverInvocations()
        XCTAssertEqual(recoveryProjects, [projectID])
    }

    func testApplyReadbackFailureRetainsOneExactAttemptAndRecoveryUsesItAfterReadbackReturns() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let proposalID = PlanChangeProposalID(rawValue: "proposal-app-apply-readback-unavailable")
        let store = fixture.store
        let dispatcher = fixture.dispatcher
        let registration = fixture.registration
        let projectRoot = fixture.root.path
        let applyCounter = RepositoryPlanApplyDispatchCounter()
        let readbacks = RepositoryPlanReadbackAvailabilityGate(failExactLoads: 0)
        let model = try makeRealReviewModel(
            fixture: fixture,
            proposalID: proposalID,
            commandDispatch: { _, _, requestID, command in
                let envelope = AgentCommandEnvelope(
                    version: AgentCommandDispatcher.commandEnvelopeVersion,
                    requestID: requestID,
                    projectRoot: projectRoot,
                    expectedRegistration: registration,
                    reason: "Exercise unavailable authoritative Apply readback.",
                    command: command
                )
                if case .applyPlanChangeProposal = command {
                    await applyCounter.record(envelope)
                    do {
                        try await fixture.insertPendingAttempt(envelope)
                    } catch {
                        return .init(
                            entityIDs: [],
                            auditEventID: nil,
                            error: .internalFailure("The pending Apply fixture could not be recorded.")
                        )
                    }
                    return .init(
                        entityIDs: [],
                        auditEventID: nil,
                        error: .internalFailure("The committed Apply result could not be read back.")
                    )
                }
                return await dispatcher.dispatch(envelope, origin: .ownerApp)
            },
            readbackLoader: { loadedStore, loadedProjectID, loadedProposalID in
                try await readbacks.load(
                    store: loadedStore,
                    projectID: loadedProjectID,
                    proposalID: loadedProposalID
                )
            }
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
            rationale: "Save before exact Apply recovery."
        )
        await model.approveRepositoryPlanReconstruction(projectID: projectID)

        await readbacks.failNextExactLoad()
        await model.applyRepositoryPlanReconstruction(projectID: projectID)

        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .outcomeUnknown)
        let persistedAfterDispatch = try await RepositoryPlanReconstructionQuery.load(
            from: store,
            projectID: projectID,
            proposalID: proposalID
        )
        let recorded = try XCTUnwrap(
            persistedAfterDispatch.first?.applicationAttempt
        )
        let retainedPreparation = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.preparation
        )
        XCTAssertEqual(retainedPreparation.state, .readyForReview)
        var applyInvocationCount = await applyCounter.invocationCount()
        XCTAssertEqual(applyInvocationCount, 1)

        let retainedDraft = RepositoryPlanPreparedDraft(
            source: fixture.payload.source,
            originalProjection: fixture.projection
        )
        let relaunched = try makeModel(
            projectID: projectID,
            service: RepositoryPlanPreparationServiceSpy(
                startResponses: [],
                recoverResponses: [[retainedPreparation]],
                reviewDraftResponses: [retainedDraft]
            ),
            store: store,
            inventoryLoader: .init(responses: [sourceInventory(for: fixture)]),
            previewSpy: .init(responses: [], failureCodes: [.sourceChanged])
        )
        await relaunched.openRepositoryPlanReconstruction(projectID: projectID)

        let relaunchedPresentation = try XCTUnwrap(
            relaunched.repositoryPlanReconstruction(for: projectID)
        )
        XCTAssertEqual(relaunchedPresentation.stage, .outcomeUnknown)
        let relaunchedAttempt = try XCTUnwrap(
            relaunchedPresentation.review?.savedReadback?.applicationAttempt
        )
        XCTAssertEqual(relaunchedAttempt, recorded)
        XCTAssertEqual(
            relaunchedPresentation.review?.pendingApplyIdentity?.applicationID,
            recorded.applicationID
        )
        XCTAssertTrue(
            relaunchedPresentation.message?.localizedCaseInsensitiveContains("source") == true
                || relaunchedPresentation.message?.localizedCaseInsensitiveContains("review") == true
        )

        await model.applyRepositoryPlanReconstruction(projectID: projectID)
        applyInvocationCount = await applyCounter.invocationCount()
        XCTAssertEqual(applyInvocationCount, 1)

        let recordedEnvelope = try JSONDecoder().decode(
            AgentCommandEnvelope.self,
            from: recorded.envelopeBytes
        )
        let completed = await dispatcher.dispatchReconstructionApply(
            recordedEnvelope,
            origin: .ownerApp
        )
        XCTAssertNil(completed.error)
        await model.recoverRepositoryPlanReconstructionApply(projectID: projectID)

        let recovered = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback?.applicationAttempt
        )
        XCTAssertEqual(recovered.applicationID, recorded.applicationID)
        XCTAssertEqual(recovered.requestID, recorded.requestID)
        XCTAssertEqual(recovered.state, .applied)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .applied)
        applyInvocationCount = await applyCounter.invocationCount()
        XCTAssertEqual(applyInvocationCount, 1)
    }

    func testStartupReadbackFailureDoesNotFallThroughToSourceSelectionOrPreparation() async throws {
        let projectID = ProjectID(rawValue: "project-readback-unavailable")
        let inventoryLoader = RepositoryPlanSourceInventoryLoaderSpy(
            responses: [inventory(projectID: projectID)]
        )
        let service = RepositoryPlanPreparationServiceSpy(startResponses: [])
        let model = try makeModel(
            projectID: projectID,
            service: service,
            inventoryLoader: inventoryLoader,
            readbackLoader: { _, _, _ in
                throw RepositoryPlanReadbackTestError.unavailable
            }
        )

        await model.openRepositoryPlanReconstruction(projectID: projectID)
        await model.startRepositoryPlanPreparation(projectID: projectID)

        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .failed)
        XCTAssertNotNil(model.repositoryPlanReconstruction(for: projectID)?.message)
        let inventoryLoadCount = await inventoryLoader.invocationCount()
        let preparationStarts = await service.startInvocations()
        XCTAssertEqual(inventoryLoadCount, 0)
        XCTAssertEqual(preparationStarts.count, 0)
    }

    func testExactPartialPlanMappingClearsRawIDBlockerPersistsThroughHydrationAndCanBeRemoved() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        try await fixture.seedPhase(id: "phase-101", name: "Imported phase")
        let projectID = fixture.registration.projectID
        let proposalID = PlanChangeProposalID(rawValue: "proposal-app-partial-mapping")
        let model = try makeRealReviewModel(fixture: fixture, proposalID: proposalID)
        await model.openRepositoryPlanReconstruction(projectID: projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "current",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)

        let subject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: "phase-101"
        )
        var review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.blockers.map(\.code), ["raw_source_id_candidate"])

        await model.setRepositoryPlanMapping(
            projectID: projectID,
            subject: subject,
            destinationID: "phase-101"
        )

        review = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.explicitMappings, [.init(subject: subject, destinationID: "phase-101")])
        XCTAssertEqual(review.comparisons.first?.disposition, .unchanged)
        XCTAssertTrue(review.blockers.isEmpty)
        XCTAssertFalse(review.authorityConfirmed)
        XCTAssertNil(review.savedReadback)

        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the exact owner-selected partial-plan mapping."
        )
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback?.version.version,
            1
        )

        let store = fixture.store
        let relaunched = try makeModel(
            projectID: projectID,
            service: RepositoryPlanPreparationServiceSpy(startResponses: []),
            store: store,
            inventoryLoader: .init(responses: [sourceInventory(for: fixture)]),
            previewer: { source, reviewedProjection, corrections, explicitMappings in
                try await RepositoryPlanReconstructionPreviewQuery.preview(
                    source: source,
                    reviewedProjection: reviewedProjection,
                    corrections: corrections,
                    explicitMappings: explicitMappings,
                    from: store
                )
            }
        )
        await relaunched.openRepositoryPlanReconstruction(projectID: projectID)

        review = try XCTUnwrap(relaunched.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertEqual(review.explicitMappings, [.init(subject: subject, destinationID: "phase-101")])
        XCTAssertEqual(review.comparisons.first?.disposition, .unchanged)
        XCTAssertTrue(review.blockers.isEmpty)

        await relaunched.setRepositoryPlanMapping(
            projectID: projectID,
            subject: subject,
            destinationID: nil
        )

        review = try XCTUnwrap(relaunched.repositoryPlanReconstruction(for: projectID)?.review)
        XCTAssertTrue(review.explicitMappings.isEmpty)
        XCTAssertEqual(review.comparisons.first?.disposition, .blocked)
        XCTAssertEqual(review.blockers.map(\.code), ["raw_source_id_candidate"])
        XCTAssertNil(review.savedReadback)
    }

    func testAppliedPlanRequiresExplicitFreshDisclosureAndRepeatPreparationReusesExactDestination() async throws {
        let fixture = try await ReconstructionFixture.make()
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projectID = fixture.registration.projectID
        let draft = RepositoryPlanPreparedDraft(
            source: fixture.payload.source,
            originalProjection: fixture.projection
        )
        let firstIdentity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: draft.source.rootID,
            proposalID: .init(rawValue: "proposal-app-repeat-1"),
            attemptID: uuid(210)
        )
        let secondIdentity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: draft.source.rootID,
            proposalID: firstIdentity.proposalID,
            attemptID: uuid(211)
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [
                readback(
                    identity: firstIdentity,
                    state: .readyForReview,
                    draftBytes: draft.source.projectionBytes
                ),
                readback(
                    identity: secondIdentity,
                    state: .readyForReview,
                    draftBytes: draft.source.projectionBytes
                ),
            ],
            reviewDraftResponses: [draft, draft]
        )
        let store = fixture.store
        let dispatcher = fixture.dispatcher
        let registration = fixture.registration
        let projectRoot = fixture.root.path
        let inventory = sourceInventory(for: fixture)
        let model = try makeModel(
            projectID: projectID,
            service: service,
            store: store,
            inventoryLoader: .init(responses: [inventory, inventory]),
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
                let envelope = AgentCommandEnvelope(
                    version: AgentCommandDispatcher.commandEnvelopeVersion,
                    requestID: requestID,
                    projectRoot: projectRoot,
                    expectedRegistration: registration,
                    reason: "Exercise explicit repeat repository-plan preparation.",
                    command: command
                )
                if case .applyPlanChangeProposal = command {
                    return await dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
                }
                return await dispatcher.dispatch(envelope, origin: .ownerApp)
            },
            requestIDs: (212...225).map { uuid(UInt8($0)) }
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
            rationale: "Persist the first reconstruction."
        )
        await model.approveRepositoryPlanReconstruction(projectID: projectID)
        await model.applyRepositoryPlanReconstruction(projectID: projectID)
        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .applied)
        let applied = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback
        )
        let exactDestinationID = try XCTUnwrap(applied.payload.comparisons.first?.destinationID)
        var destinationPhaseCount = try await fixture.phaseCount(id: exactDestinationID)
        XCTAssertEqual(destinationPhaseCount, 1)

        await model.beginFreshRepositoryPlanPreparation(projectID: projectID)

        var presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        XCTAssertEqual(presentation.stage, .selectingSources)
        XCTAssertTrue(presentation.selectedArtifactIDs.isEmpty)
        var starts = await service.startInvocations()
        XCTAssertEqual(starts.count, 1)

        model.setRepositoryPlanSourceSelected(
            projectID: projectID,
            artifactID: "current",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: projectID)

        presentation = try XCTUnwrap(model.repositoryPlanReconstruction(for: projectID))
        let repeatedReview = try XCTUnwrap(presentation.review)
        let subject = try XCTUnwrap(repeatedReview.comparisons.first?.subject)
        XCTAssertEqual(presentation.stage, .reviewing)
        XCTAssertEqual(repeatedReview.comparisons.first?.disposition, .unchanged)
        XCTAssertEqual(
            repeatedReview.explicitMappings,
            [.init(subject: subject, destinationID: exactDestinationID)]
        )
        XCTAssertTrue(repeatedReview.blockers.isEmpty)
        starts = await service.startInvocations()
        XCTAssertEqual(starts.count, 2)

        model.setRepositoryPlanAuthorityConfirmed(projectID: projectID, confirmed: true)
        await model.saveRepositoryPlanReconstruction(
            projectID: projectID,
            rationale: "Persist the repeat reconstruction without duplicating the graph."
        )
        XCTAssertEqual(
            model.repositoryPlanReconstruction(for: projectID)?.review?.savedReadback?.version.version,
            2
        )
        await model.approveRepositoryPlanReconstruction(projectID: projectID)
        await model.applyRepositoryPlanReconstruction(projectID: projectID)

        XCTAssertEqual(model.repositoryPlanReconstruction(for: projectID)?.stage, .applied)
        destinationPhaseCount = try await fixture.phaseCount(id: exactDestinationID)
        XCTAssertEqual(destinationPhaseCount, 1)
    }

    func testOriginalEvidenceImportResolvesCapturedStructuredRecordAndDeduplicatesExactReference() async throws {
        let repositoryID = "9141d1ea-3342-4462-9e06-6934d816c03f"
        let sourceRef = RepositoryPlanSourceReference.document(
            documentID: "state-document",
            locator: "/records/0"
        )
        let certificate = RepositoryPlanPhaseCompletionCertificate(
            membershipComplete: true,
            tickets: [],
            goals: [],
            obligations: [],
            deliveredBy: []
        )
        let record = RepositoryPlanStateRecord(
            recordID: "phase-completed-app-import",
            repositoryID: repositoryID,
            kind: .phaseLifecycle,
            subject: .phase(.init(sourceID: "phase-101", name: "Imported phase")),
            state: .completed,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            actorID: "historical-owner",
            phaseCompletion: certificate
        )
        let documentBytes = try stateRecordDocument([record])
        let fixture = try await ReconstructionFixture.make(capturedSourceBytes: documentBytes)
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }
        let projection = fixture.projection(
            lifecycle: .completed,
            stateEvidence: [sourceRef],
            documentID: "state-document",
            documentDigest: sha256(documentBytes)
        )
        let source = try fixture.source(for: projection)
        let draft = RepositoryPlanPreparedDraft(
            source: source,
            originalProjection: projection
        )
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: source.rootID,
            proposalID: .init(rawValue: "proposal-app-original-evidence"),
            attemptID: uuid(226)
        )
        let service = RepositoryPlanPreparationServiceSpy(
            startResponses: [readback(
                identity: identity,
                state: .readyForReview,
                draftBytes: source.projectionBytes
            )],
            reviewDraftResponses: [draft]
        )
        let store = fixture.store
        let model = try makeModel(
            projectID: fixture.registration.projectID,
            service: service,
            store: store,
            inventoryLoader: .init(responses: [sourceInventory(for: fixture)]),
            previewer: { source, reviewedProjection, corrections, explicitMappings in
                try await RepositoryPlanReconstructionPreviewQuery.preview(
                    source: source,
                    reviewedProjection: reviewedProjection,
                    corrections: corrections,
                    explicitMappings: explicitMappings,
                    from: store
                )
            }
        )
        await model.openRepositoryPlanReconstruction(projectID: fixture.registration.projectID)
        model.setRepositoryPlanSourceSelected(
            projectID: fixture.registration.projectID,
            artifactID: "current",
            selected: true
        )
        await model.startRepositoryPlanPreparation(projectID: fixture.registration.projectID)
        let expected = try RepositoryPlanTerminalEvidenceResolver.original(
            sourceRef: sourceRef,
            source: source
        )

        await model.addRepositoryPlanOriginalEvidence(
            projectID: fixture.registration.projectID,
            sourceRef: sourceRef
        )
        await model.addRepositoryPlanOriginalEvidence(
            projectID: fixture.registration.projectID,
            sourceRef: sourceRef
        )

        let review = try XCTUnwrap(
            model.repositoryPlanReconstruction(for: fixture.registration.projectID)?.review
        )
        XCTAssertEqual(review.terminalEvidence, [expected])
        XCTAssertFalse(review.authorityConfirmed)
        XCTAssertNil(review.savedReadback)
    }

    private func makeModel(
        projectID: ProjectID,
        service: any RepositoryPlanPreparationServicing,
        store providedStore: DeliveryStore? = nil,
        inventoryLoader: RepositoryPlanSourceInventoryLoaderSpy? = nil,
        dashboardLoader providedDashboardLoader: (@Sendable (
            DeliveryStore
        ) async throws -> DashboardProjection)? = nil,
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
        readbackLoader providedReadbackLoader: (@Sendable (
            DeliveryStore,
            ProjectID,
            PlanChangeProposalID?
        ) async throws -> [RepositoryPlanReconstructionReadback])? = nil,
        applyReconciler providedApplyReconciler: (@Sendable (
            RepositoryPlanReconstructionApplicationAttemptRecord
        ) async throws -> RepositoryPlanReconstructionApplicationAttemptRecord)? = nil,
        applyReplayer providedApplyReplayer: (@Sendable (
            RepositoryPlanReconstructionApplicationAttemptRecord
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
        let readbackLoader = providedReadbackLoader ?? { store, projectID, proposalID in
            try await RepositoryPlanReconstructionQuery.load(
                from: store,
                projectID: projectID,
                proposalID: proposalID
            )
        }
        let applyReconciler = providedApplyReconciler ?? { $0 }
        let applyReplayer = providedApplyReplayer ?? { attempt in
            .init(
                entityIDs: [attempt.proposalID.rawValue],
                auditEventID: nil,
                error: .internalFailure("Unexpected reconstruction Apply replay.")
            )
        }
        return AppModel(
            store: store,
            dashboardLoader: providedDashboardLoader,
            requestIDGenerator: requestIDGenerator.next,
            externalServicesSuppressed: true,
            repositoryPlanSourceLoader: { _, _, loadedProjectID in
                XCTAssertEqual(loadedProjectID, projectID)
                return try await loader.load(projectID: loadedProjectID)
            },
            repositoryPlanPreparationService: service,
            repositoryPlanPreviewer: previewer,
            repositoryPlanOwnerCommandDispatch: commandDispatch,
            repositoryPlanReadbackLoader: readbackLoader,
            repositoryPlanApplyReconciler: applyReconciler,
            repositoryPlanApplyReplayer: applyReplayer
        )
    }

    private func makeRealReviewModel(
        fixture: ReconstructionFixture,
        proposalID: PlanChangeProposalID,
        commandDispatch providedCommandDispatch: (@Sendable (
            ProjectID,
            ProjectRegistration,
            UUID,
            AgentCommand
        ) async -> AgentCommandResult)? = nil,
        dashboardLoader providedDashboardLoader: (@Sendable (
            DeliveryStore
        ) async throws -> DashboardProjection)? = nil,
        readbackLoader providedReadbackLoader: (@Sendable (
            DeliveryStore,
            ProjectID,
            PlanChangeProposalID?
        ) async throws -> [RepositoryPlanReconstructionReadback])? = nil
    ) throws -> AppModel {
        let projectID = fixture.registration.projectID
        let identity = RepositoryPlanPreparationIdentity(
            registration: fixture.registration,
            rootID: fixture.payload.source.rootID,
            proposalID: proposalID,
            attemptID: uuid(112)
        )
        let draft = RepositoryPlanPreparedDraft(
            source: fixture.payload.source,
            originalProjection: fixture.projection
        )
        let sourceInventory = sourceInventory(for: fixture)
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
        let commandDispatch = providedCommandDispatch ?? { _, _, requestID, command in
            let envelope = AgentCommandEnvelope(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: requestID,
                projectRoot: projectRoot,
                expectedRegistration: registration,
                reason: "Exercise the complete repository plan owner journey.",
                command: command
            )
            if case .applyPlanChangeProposal = command {
                return await dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
            }
            return await dispatcher.dispatch(envelope, origin: .ownerApp)
        }
        return try makeModel(
            projectID: projectID,
            service: service,
            store: store,
            inventoryLoader: .init(responses: [sourceInventory, sourceInventory]),
            dashboardLoader: providedDashboardLoader,
            previewer: { source, reviewedProjection, corrections, explicitMappings in
                try await RepositoryPlanReconstructionPreviewQuery.preview(
                    source: source,
                    reviewedProjection: reviewedProjection,
                    corrections: corrections,
                    explicitMappings: explicitMappings,
                    from: store
                )
            },
            commandDispatch: commandDispatch,
            readbackLoader: providedReadbackLoader,
            requestIDs: (120...132).map { uuid(UInt8($0)) }
        )
    }

    private func sourceInventory(for fixture: ReconstructionFixture) -> RepositoryPlanSourceInventory {
        let manifest = fixture.payload.source.capturedSourceManifest
        return .init(
            projectID: fixture.registration.projectID,
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

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func stateRecordDocument(
        _ records: [RepositoryPlanStateRecord]
    ) throws -> Data {
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

private actor RepositoryPlanApplyReplaySpy {
    private var calls: [RepositoryPlanReconstructionApplicationAttemptRecord] = []
    private let dispatcher: AgentCommandDispatcher

    init(dispatcher: AgentCommandDispatcher) {
        self.dispatcher = dispatcher
    }

    func replay(
        _ attempt: RepositoryPlanReconstructionApplicationAttemptRecord
    ) async -> AgentCommandResult {
        calls.append(attempt)
        do {
            let envelope = try JSONDecoder().decode(
                AgentCommandEnvelope.self,
                from: attempt.envelopeBytes
            )
            return await dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        } catch {
            return .init(
                entityIDs: [attempt.proposalID.rawValue],
                auditEventID: nil,
                error: .internalFailure(error.localizedDescription)
            )
        }
    }

    func invocations() -> [RepositoryPlanReconstructionApplicationAttemptRecord] { calls }
    func invocationCount() -> Int { calls.count }
}

private actor RepositoryPlanJourneyDispatchSpy {
    private let dispatcher: AgentCommandDispatcher
    private let projectRoot: String
    private let approvalGate: RepositoryPlanPreparationStartGate
    private let applyGate: RepositoryPlanPreparationStartGate
    private var approvals: [AgentCommand] = []
    private var applies: [AgentCommand] = []

    init(
        dispatcher: AgentCommandDispatcher,
        projectRoot: String,
        approvalGate: RepositoryPlanPreparationStartGate,
        applyGate: RepositoryPlanPreparationStartGate
    ) {
        self.dispatcher = dispatcher
        self.projectRoot = projectRoot
        self.approvalGate = approvalGate
        self.applyGate = applyGate
    }

    func dispatch(
        projectID: ProjectID,
        registration: ProjectRegistration,
        requestID: UUID,
        command: AgentCommand
    ) async -> AgentCommandResult {
        let envelope = AgentCommandEnvelope(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: projectRoot,
            expectedRegistration: registration,
            reason: "Exercise duplicate owner-action suppression.",
            command: command
        )
        switch command {
        case .decidePlanChangeProposal:
            approvals.append(command)
            await approvalGate.suspend()
            return await dispatcher.dispatch(envelope, origin: .ownerApp)
        case .applyPlanChangeProposal:
            applies.append(command)
            await applyGate.suspend()
            return await dispatcher.dispatchReconstructionApply(envelope, origin: .ownerApp)
        default:
            return await dispatcher.dispatch(envelope, origin: .ownerApp)
        }
    }

    func approvalInvocations() -> [AgentCommand] { approvals }
    func applyInvocations() -> [AgentCommand] { applies }
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
    private var recoverResponses: [[RepositoryPlanPreparationReadback]]
    private var reviewDraftResponses: [RepositoryPlanPreparedDraft]
    private var startErrorCodes: [RepositoryPlanPreparationError.Code]
    private var reconcileErrorCodes: [RepositoryPlanPreparationError.Code]
    private var reviewDrafts: [RepositoryPlanPreparationIdentity] = []
    private var recoveredProjects: [ProjectID] = []
    private let startGate: RepositoryPlanPreparationStartGate?
    private let targetUnavailable: Bool

    init(
        startResponses: [RepositoryPlanPreparationReadback],
        statusResponses: [RepositoryPlanPreparationReadback] = [],
        cancelResponses: [RepositoryPlanPreparationReadback] = [],
        reconcileResponses: [RepositoryPlanPreparationReadback] = [],
        recoverResponses: [[RepositoryPlanPreparationReadback]] = [],
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
        self.recoverResponses = recoverResponses
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

    func recover(projectID: ProjectID) async throws -> [RepositoryPlanPreparationReadback] {
        recoveredProjects.append(projectID)
        return recoverResponses.isEmpty ? [] : recoverResponses.removeFirst()
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
    func recoverInvocations() -> [ProjectID] { recoveredProjects }
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

private enum RepositoryPlanReadbackTestError: Error {
    case unavailable
}

private actor RepositoryPlanDashboardLoadGate {
    private var remainingFailures: Int
    private var calls = 0

    init(failures: Int) {
        remainingFailures = failures
    }

    func load(from store: DeliveryStore) async throws -> DashboardProjection {
        calls += 1
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw RepositoryPlanReadbackTestError.unavailable
        }
        return try await DashboardProjection.load(from: store)
    }

    func invocationCount() -> Int { calls }
}

private actor RepositoryPlanApplyDispatchCounter {
    private var envelopes: [AgentCommandEnvelope] = []

    func record(_ envelope: AgentCommandEnvelope) {
        envelopes.append(envelope)
    }

    func invocationCount() -> Int { envelopes.count }
}

private actor RepositoryPlanReadbackAvailabilityGate {
    private var remainingExactLoadFailures: Int

    init(failExactLoads: Int) {
        remainingExactLoadFailures = failExactLoads
    }

    func failNextExactLoad() {
        remainingExactLoadFailures += 1
    }

    func load(
        store: DeliveryStore,
        projectID: ProjectID,
        proposalID: PlanChangeProposalID?
    ) async throws -> [RepositoryPlanReconstructionReadback] {
        if proposalID != nil, remainingExactLoadFailures > 0 {
            remainingExactLoadFailures -= 1
            throw RepositoryPlanReadbackTestError.unavailable
        }
        return try await RepositoryPlanReconstructionQuery.load(
            from: store,
            projectID: projectID,
            proposalID: proposalID
        )
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
    struct RestoreInvocation: Equatable {
        let request: RepositoryPlanPreparationRequest
        let readback: RepositoryPlanPreparationReadback
    }

    private let selectedTarget: RepositoryPlanPreparationTarget
    private var prepareResponses: [RepositoryPlanPreparationReadback]
    private var progressResponses: [RepositoryPlanPreparationReadback]
    private let progressObservation: @Sendable (Int) async throws -> Void
    private var statusResponses: [RepositoryPlanPreparationReadback]
    private var cancelResponses: [RepositoryPlanPreparationReadback]
    private var prepareErrorCodes: [RepositoryPlanPreparationError.Code]
    private var cancelErrorCodes: [RepositoryPlanPreparationError.Code]
    private var closeErrorCodes: [RepositoryPlanPreparationError.Code]
    private var restoreErrorCodes: [RepositoryPlanPreparationError.Code]
    private let requireSuccessfulRestoreBeforeStatus: Bool
    private var hasSuccessfulRestore = false
    private var prepares: [RepositoryPlanPreparationRequest] = []
    private var statuses: [RepositoryPlanPreparationIdentity] = []
    private var cancellations: [RepositoryPlanPreparationIdentity] = []
    private var closes: [RepositoryPlanPreparationIdentity] = []
    private var restores: [RestoreInvocation] = []

    init(
        target: RepositoryPlanPreparationTarget,
        prepareResponses: [RepositoryPlanPreparationReadback],
        progressResponses: [RepositoryPlanPreparationReadback] = [],
        progressObservation: @escaping @Sendable (Int) async throws -> Void = { _ in },
        statusResponses: [RepositoryPlanPreparationReadback] = [],
        cancelResponses: [RepositoryPlanPreparationReadback] = [],
        cancelErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        closeError: RepositoryPlanPreparationError? = nil,
        closeErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        prepareErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        restoreErrorCodes: [RepositoryPlanPreparationError.Code] = [],
        requireSuccessfulRestoreBeforeStatus: Bool = false
    ) {
        selectedTarget = target
        self.prepareResponses = prepareResponses
        self.progressResponses = progressResponses
        self.progressObservation = progressObservation
        self.statusResponses = statusResponses
        self.cancelResponses = cancelResponses
        self.cancelErrorCodes = cancelErrorCodes
        self.closeErrorCodes = closeError.map { [$0.code] } ?? closeErrorCodes
        self.prepareErrorCodes = prepareErrorCodes
        self.restoreErrorCodes = restoreErrorCodes
        self.requireSuccessfulRestoreBeforeStatus = requireSuccessfulRestoreBeforeStatus
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
        if !prepareErrorCodes.isEmpty {
            throw RepositoryPlanPreparationError(code: prepareErrorCodes.removeFirst())
        }
        return prepareResponses.removeFirst()
    }

    func prepare(
        _ request: RepositoryPlanPreparationRequest,
        onProgress: @escaping @Sendable (
            RepositoryPlanPreparationReadback
        ) async throws -> Void
    ) async throws -> RepositoryPlanPreparationReadback {
        prepares.append(request)
        if !prepareErrorCodes.isEmpty {
            throw RepositoryPlanPreparationError(code: prepareErrorCodes.removeFirst())
        }
        for (index, progress) in progressResponses.enumerated() {
            try await onProgress(progress)
            try await progressObservation(index)
        }
        return prepareResponses.removeFirst()
    }

    func restore(
        request: RepositoryPlanPreparationRequest,
        readback: RepositoryPlanPreparationReadback
    ) async throws {
        restores.append(.init(request: request, readback: readback))
        if !restoreErrorCodes.isEmpty {
            throw RepositoryPlanPreparationError(code: restoreErrorCodes.removeFirst())
        }
        hasSuccessfulRestore = true
    }

    func status(
        _ identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        statuses.append(identity)
        if requireSuccessfulRestoreBeforeStatus, !hasSuccessfulRestore {
            throw RepositoryPlanPreparationError(code: .outcomeUnknown)
        }
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
    func restoreInvocations() -> [RestoreInvocation] { restores }
}

private actor RepositoryPlanPreparationProgressRecordSpy {
    private(set) var values: [RepositoryPlanPreparationRecord] = []

    func append(_ value: RepositoryPlanPreparationRecord) {
        values.append(value)
    }
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

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
}

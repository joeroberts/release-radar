import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class AppRouteTests: XCTestCase {
    func testPrimaryRoutesExposeTheExpectedAccessibleLabelsAndSymbols() {
        let routes = AppRoute.primaryRoutes

        XCTAssertEqual(routes.map(\.title), [
            "Projects",
            "Needs Review",
            "Notifications",
            "Settings",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "folder",
            "checkmark.bubble",
            "bell",
            "gearshape",
        ])
    }

    func testProjectRoutesRetainTheirProjectAndExposeExpectedLabels() {
        let projectID = ProjectID(rawValue: "project-42")
        let routes = AppRoute.projectRoutes(for: projectID)

        XCTAssertEqual(routes, [
            .projectOverview(projectID),
            .phaseBoard(projectID),
            .dependencies(projectID),
            .activity(projectID),
        ])
        XCTAssertEqual(routes.map(\.title), [
            "Overview",
            "Phase Board",
            "Dependencies",
            "Activity",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "rectangle.grid.1x2",
            "rectangle.split.3x1",
            "arrow.triangle.branch",
            "clock.arrow.circlepath",
        ])
    }

    @MainActor
    func testOpeningNonFirstProjectKeepsEveryProjectRouteInThatContext() {
        let first = ProjectDashboardProjection(
            id: ProjectID(rawValue: "project-a"),
            name: "Alpha",
            activePhaseName: "Alpha phase",
            goalContext: GoalContextProjection(
                linkQuality: .unavailable,
                text: nil,
                status: nil,
                lastObservedAt: nil
            ),
            currentWorkCount: 1,
            attentionCount: 0
        )
        let second = ProjectDashboardProjection(
            id: ProjectID(rawValue: "project-b"),
            name: "Beta",
            activePhaseName: "Beta phase",
            goalContext: GoalContextProjection(
                linkQuality: .verified,
                text: "Ship Beta",
                status: "In progress",
                lastObservedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            currentWorkCount: 2,
            attentionCount: 1
        )
        let model = AppModel()
        model.dashboard = DashboardProjection(projects: [first, second], boards: [:])

        XCTAssertEqual(model.currentProjectID, first.id)

        model.openProject(second.id)

        XCTAssertEqual(model.currentProjectID, second.id)
        XCTAssertEqual(model.currentProject?.name, "Beta")
        XCTAssertEqual(AppRoute.projectRoutes(for: model.currentProjectID), [
            .projectOverview(second.id),
            .phaseBoard(second.id),
            .dependencies(second.id),
            .activity(second.id),
        ])

        for route in [
            AppRoute.phaseBoard(second.id),
            .dependencies(second.id),
            .activity(second.id),
        ] {
            model.selection = route
            XCTAssertEqual(model.currentProjectID, second.id)
            XCTAssertEqual(model.currentProject?.name, "Beta")
        }

        model.selection = .projects
        XCTAssertEqual(model.currentProjectID, second.id)
    }
}

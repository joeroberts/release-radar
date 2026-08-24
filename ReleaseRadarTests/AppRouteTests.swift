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
}

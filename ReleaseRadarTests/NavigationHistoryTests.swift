import XCTest
@testable import ReleaseRadar
import ReleaseRadarCore

final class NavigationHistoryTests: XCTestCase {
    func testNewNavigationAfterBackDiscardsForwardContext() {
        var history = NavigationHistory(initial: .projects)
        history.navigate(to: .projectOverview(.init(rawValue: "project-a")))
        history.navigate(to: .phaseBoard(.init(rawValue: "project-a")), phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-1"))
        XCTAssertTrue(history.goBack())

        history.navigate(to: .dependencies(.init(rawValue: "project-a")), phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-1"))

        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.current.route, .dependencies(.init(rawValue: "project-a")))
    }

    func testUpdatingCurrentContextDoesNotCreateBackStep() {
        var history = NavigationHistory(initial: .projects)
        history.navigate(to: .phaseBoard(.init(rawValue: "project-a")), phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-1"))
        history.updateCurrent(phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-2"))

        XCTAssertEqual(history.entries.count, 2)
        XCTAssertTrue(history.goBack())
        XCTAssertEqual(history.current.route, .projects)
    }
}

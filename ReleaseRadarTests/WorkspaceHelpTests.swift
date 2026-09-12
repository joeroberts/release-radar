import XCTest
@testable import ReleaseRadar

final class WorkspaceHelpTests: XCTestCase {
    func testTopicsAreGroupedForProjectsSettingsAndGoalsWithoutLosingTheirDestinations() {
        let groups = WorkspaceHelpContent.groups(filteredBy: "")

        XCTAssertEqual(groups.map(\.title), ["Projects", "Settings", "Goals"])
        XCTAssertEqual(groups[0].topics.map(\.id), [
            "setup-handoff", "active-viewed", "navigation-validation", "planning-unplaced",
            "task-adoption", "proposal-approval", "search-navigation",
        ])
        XCTAssertEqual(groups[1].topics.map(\.id), [
            "recovery", "plugin-helper-restart", "saved-query-recovery",
        ])
        XCTAssertEqual(groups[2].topics.map(\.id), ["readiness-acceptance"])
        XCTAssertEqual(groups[0].topics.last?.destination, .history)
        XCTAssertEqual(groups[1].topics.last?.destination, .search)
        XCTAssertEqual(groups[2].topics.first?.destination, .goals)
    }

    func testFilteringHidesEmptyHelpGroups() {
        let groups = WorkspaceHelpContent.groups(filteredBy: "restart helper")

        XCTAssertEqual(groups.map(\.title), ["Settings"])
        XCTAssertEqual(groups.first?.topics.map(\.id), ["plugin-helper-restart"])
    }

    func testSharedHelpCatalogCoversEverySelectedJourneyAndHasActionableDestinations() {
        let topics = WorkspaceHelpContent.topics

        XCTAssertEqual(Set(topics.map(\.id)), [
            "setup-handoff", "recovery", "active-viewed", "planning-unplaced",
            "task-adoption", "proposal-approval", "readiness-acceptance",
            "saved-query-recovery", "search-navigation", "plugin-helper-restart",
            "navigation-validation",
        ])
        XCTAssertTrue(topics.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
        XCTAssertTrue(topics.allSatisfy { $0.destination != nil })
        XCTAssertEqual(WorkspaceHelpContent.filtered(by: "saved query").map(\.id), ["saved-query-recovery"])
        XCTAssertEqual(WorkspaceHelpContent.filtered(by: "proposal apply").map(\.id), ["proposal-approval"])

        let history = try? XCTUnwrap(WorkspaceHelpContent.filtered(by: "source provenance retained observations").first)
        XCTAssertEqual(history?.id, "search-navigation")
        XCTAssertEqual(history?.destination, .history)
        XCTAssertTrue(history?.detail.contains("Audit, review, completion, observation, and notification") == true)

        let evidence = try? XCTUnwrap(WorkspaceHelpContent.filtered(by: "delivery evidence applicability").first)
        XCTAssertEqual(evidence?.id, "readiness-acceptance")
        XCTAssertEqual(evidence?.destination, .goals)
        XCTAssertTrue(evidence?.detail.contains("Recorded evidence is not live evidence") == true)
        XCTAssertTrue(evidence?.detail.contains("owner acceptance") == true)

        let newerVersion = try? XCTUnwrap(WorkspaceHelpContent.filtered(by: "newer version reset working search").first)
        XCTAssertEqual(newerVersion?.id, "saved-query-recovery")
        XCTAssertEqual(newerVersion?.destination, .search)
        XCTAssertTrue(newerVersion?.detail.contains("Reset to a new search") == true)
        XCTAssertTrue(newerVersion?.detail.contains("toolbar") == true)

        let searchNavigation = try? XCTUnwrap(WorkspaceHelpContent.filtered(by: "toolbar draft submit").first)
        XCTAssertEqual(searchNavigation?.id, "search-navigation")
        XCTAssertTrue(searchNavigation?.detail.contains("Typing") == true)
        XCTAssertTrue(searchNavigation?.detail.contains("Return") == true)

        let helper = try? XCTUnwrap(WorkspaceHelpContent.filtered(by: "restart helper Login Items").first)
        XCTAssertEqual(helper?.id, "plugin-helper-restart")
        XCTAssertEqual(helper?.destination, .settings)
        XCTAssertTrue(helper?.detail.contains("does not reinstall or remove the plugin") == true)
        XCTAssertTrue(helper?.detail.contains("projects remain unchanged") == true)

        let navigation = try? XCTUnwrap(WorkspaceHelpContent.filtered(by: "navigation checking spinner").first)
        XCTAssertEqual(navigation?.id, "navigation-validation")
        XCTAssertEqual(navigation?.destination, .projectOverview)
        XCTAssertTrue(navigation?.detail.contains("destination opens immediately") == true)
        XCTAssertTrue(navigation?.detail.contains("actions remain unavailable") == true)
    }
}

import XCTest
@testable import ReleaseRadar

final class WorkspaceHelpTests: XCTestCase {
    func testSharedHelpCatalogCoversEverySelectedJourneyAndHasActionableDestinations() {
        let topics = WorkspaceHelpContent.topics

        XCTAssertEqual(Set(topics.map(\.id)), [
            "setup-handoff", "recovery", "active-viewed", "planning-unplaced",
            "task-adoption", "proposal-approval", "readiness-acceptance",
            "saved-query-recovery", "search-navigation",
        ])
        XCTAssertTrue(topics.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
        XCTAssertTrue(topics.allSatisfy { $0.destination != nil })
        XCTAssertEqual(WorkspaceHelpContent.filtered(by: "saved query").map(\.id), ["saved-query-recovery"])
        XCTAssertEqual(WorkspaceHelpContent.filtered(by: "proposal apply").map(\.id), ["proposal-approval"])
    }
}

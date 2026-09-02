import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class DocumentationMaintenanceTests: XCTestCase {
    func testMaintenanceLaunchParsingFailsClosedAndXCTestTakesPrecedence() {
        let root = URL(fileURLWithPath: "/existing/store.sqlite")
        XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app"], environment: [:]), .application)
        XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app", "--documentation-maintenance=read-only", "--documentation-maintenance-store=/existing/store.sqlite"], environment: [:]), .maintenance(mode: .readOnly, databaseURL: root))
        for args in [["--documentation-maintenance=no"], ["--documentation-maintenance=commands", "--documentation-maintenance=read-only"], ["--documentation-maintenance-store=/x"], ["--documentation-maintenance=commands", "--documentation-maintenance-store=relative"], ["--documentation-maintenance=commands", "--documentation-maintenance-other=x"]] {
            XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app"] + args, environment: [:]), .invalid)
        }
        XCTAssertEqual(DocumentationMaintenanceLaunch.parse(arguments: ["app", "--documentation-maintenance=no"], environment: ["XCTestConfigurationFilePath": "test"]), .application)
    }
}

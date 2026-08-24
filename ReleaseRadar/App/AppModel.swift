import Observation
import ReleaseRadarCore

@MainActor
@Observable
final class AppModel {
    var selection: AppRoute = .projects
    var isSidebarCompact = false

    let currentProjectID = ProjectID(rawValue: "release-radar")
}

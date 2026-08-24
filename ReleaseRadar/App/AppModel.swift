import Observation
import ReleaseRadarCore

@MainActor
@Observable
final class AppModel {
    var selection: AppRoute = .projects {
        didSet {
            if let projectID = selection.projectID {
                selectedProjectID = projectID
            }
        }
    }
    var isSidebarCompact = false
    var dashboard: DashboardProjection?
    var selectedTicketID = TicketID(rawValue: "VD2-07c")
    var dashboardError: String?

    private let store = DeliveryStore()
    private(set) var selectedProjectID: ProjectID?

    var currentProjectID: ProjectID {
        selection.projectID
            ?? selectedProjectID
            ?? dashboard?.projects.first?.id
            ?? DashboardSampleData.projectID
    }

    var currentProject: ProjectDashboardProjection? {
        dashboard?.projects.first { $0.id == currentProjectID }
    }

    var needsReviewCount: Int {
        dashboard?.board(for: currentProjectID)?.lane(.needsReview)?.count ?? 0
    }

    var notificationCount: Int {
        dashboard?.board(for: currentProjectID)?.details.values
            .reduce(0) { $0 + $1.notificationHistory.count } ?? 0
    }

    func openProject(_ projectID: ProjectID) {
        selectedProjectID = projectID
        selection = .projectOverview(projectID)
    }

    func loadDashboard() async {
        do {
            try await DashboardSampleData.seedIfNeeded(in: store)
            dashboard = try await DashboardProjection.load(from: store)
            dashboardError = nil
        } catch {
            dashboardError = error.localizedDescription
        }
    }
}

import Observation
import ReleaseRadarCore

@MainActor
@Observable
final class AppModel {
    var selection: AppRoute = .projects
    var isSidebarCompact = false
    var dashboard: DashboardProjection?
    var selectedTicketID = TicketID(rawValue: "VD2-07c")
    var dashboardError: String?

    private let store = DeliveryStore()

    var currentProjectID: ProjectID {
        dashboard?.projects.first?.id ?? DashboardSampleData.projectID
    }

    var needsReviewCount: Int {
        dashboard?.board(for: currentProjectID)?.lane(.needsReview)?.count ?? 0
    }

    var notificationCount: Int {
        dashboard?.board(for: currentProjectID)?.details.values
            .reduce(0) { $0 + $1.notificationHistory.count } ?? 0
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

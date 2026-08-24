import ReleaseRadarCore

enum AppRoute: Hashable, Sendable {
    case projects
    case needsReview
    case notifications
    case settings
    case projectOverview(ProjectID)
    case phaseBoard(ProjectID)
    case dependencies(ProjectID)
    case activity(ProjectID)

    static let primaryRoutes: [AppRoute] = [
        .projects,
        .needsReview,
        .notifications,
        .settings,
    ]

    static func projectRoutes(for projectID: ProjectID) -> [AppRoute] {
        [
            .projectOverview(projectID),
            .phaseBoard(projectID),
            .dependencies(projectID),
            .activity(projectID),
        ]
    }

    var title: String {
        switch self {
        case .projects: "Projects"
        case .needsReview: "Needs Review"
        case .notifications: "Notifications"
        case .settings: "Settings"
        case .projectOverview: "Overview"
        case .phaseBoard: "Phase Board"
        case .dependencies: "Dependencies"
        case .activity: "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .projects: "folder"
        case .needsReview: "checkmark.bubble"
        case .notifications: "bell"
        case .settings: "gearshape"
        case .projectOverview: "rectangle.grid.1x2"
        case .phaseBoard: "rectangle.split.3x1"
        case .dependencies: "arrow.triangle.branch"
        case .activity: "clock.arrow.circlepath"
        }
    }
}

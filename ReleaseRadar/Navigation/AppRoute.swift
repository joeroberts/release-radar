import ReleaseRadarCore

enum AppRoute: Hashable, Sendable {
    case projects
    case search
    case goals
    case needsReview
    case notifications
    case settings
    case help
    case projectOverview(ProjectID)
    case projectPlan(ProjectID)
    case archivedProject(ProjectID)
    case removedProject(ProjectRemovalID)
    case phaseBoard(ProjectID)
    case dependencies(ProjectID)
    case activity(ProjectID)
    case referenceSource(projectID: ProjectID, ticketID: TicketID, linkID: String, version: Int64)
    case recordedImpacts(projectID: ProjectID, repositoryID: String, artifactID: String)

    static let primaryRoutes: [AppRoute] = [
        .projects,
        .search,
        .goals,
        .needsReview,
        .notifications,
        .settings,
        .help,
    ]

    static func projectRoutes(for projectID: ProjectID) -> [AppRoute] {
        [
            .projectOverview(projectID),
            .projectPlan(projectID),
            .phaseBoard(projectID),
            .dependencies(projectID),
            .activity(projectID),
        ]
    }

    var title: String {
        switch self {
        case .projects: "Projects"
        case .search: "Search"
        case .goals: "Goals"
        case .needsReview: "Needs Review"
        case .notifications: "Notifications"
        case .settings: "Settings"
        case .help: "Help"
        case .projectOverview: "Overview"
        case .projectPlan: "Project Plan"
        case .archivedProject: "Archived Project"
        case .removedProject: "Removed Project"
        case .phaseBoard: "Phase Board"
        case .dependencies: "Dependencies"
        case .activity: "History"
        case .referenceSource: "Reference source"
        case .recordedImpacts: "Recorded impacts"
        }
    }

    var systemImage: String {
        switch self {
        case .projects: "folder"
        case .search: "magnifyingglass"
        case .goals: "target"
        case .needsReview: "checkmark.bubble"
        case .notifications: "bell"
        case .settings: "gearshape"
        case .help: "questionmark.circle"
        case .projectOverview: "rectangle.grid.1x2"
        case .projectPlan: "list.bullet.rectangle.portrait"
        case .archivedProject: "archivebox"
        case .removedProject: "clock.badge.xmark"
        case .phaseBoard: "rectangle.split.3x1"
        case .dependencies: "arrow.triangle.branch"
        case .activity: "clock"
        case .referenceSource: "doc.text.magnifyingglass"
        case .recordedImpacts: "arrow.triangle.branch"
        }
    }

    var projectID: ProjectID? {
        switch self {
        case let .projectOverview(projectID),
             let .projectPlan(projectID),
             let .archivedProject(projectID),
             let .phaseBoard(projectID),
             let .dependencies(projectID),
             let .activity(projectID),
             let .referenceSource(projectID, _, _, _),
             let .recordedImpacts(projectID, _, _):
            projectID
        case .projects, .search, .goals, .needsReview, .notifications, .settings, .help, .removedProject:
            nil
        }
    }
}

enum SidebarBadgePolicy {
    static let badgedRoutes: [AppRoute] = [.needsReview, .notifications]
    static let notificationBadgeSurfaceCount = badgedRoutes.filter { $0 == .notifications }.count
}

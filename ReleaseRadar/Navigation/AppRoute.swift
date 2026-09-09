import ReleaseRadarCore

enum AppRoute: Hashable, Sendable {
    case projects
    case needsReview
    case notifications
    case settings
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
        .needsReview,
        .notifications,
        .settings,
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
        case .needsReview: "Needs Review"
        case .notifications: "Notifications"
        case .settings: "Settings"
        case .projectOverview: "Overview"
        case .projectPlan: "Project Plan"
        case .archivedProject: "Archived Project"
        case .removedProject: "Removed Project"
        case .phaseBoard: "Phase Board"
        case .dependencies: "Dependencies"
        case .activity: "Activity"
        case .referenceSource: "Reference source"
        case .recordedImpacts: "Recorded impacts"
        }
    }

    var systemImage: String {
        switch self {
        case .projects: "folder"
        case .needsReview: "checkmark.bubble"
        case .notifications: "bell"
        case .settings: "gearshape"
        case .projectOverview: "rectangle.grid.1x2"
        case .projectPlan: "list.bullet.rectangle.portrait"
        case .archivedProject: "archivebox"
        case .removedProject: "clock.badge.xmark"
        case .phaseBoard: "rectangle.split.3x1"
        case .dependencies: "arrow.triangle.branch"
        case .activity: "clock.arrow.circlepath"
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
        case .projects, .needsReview, .notifications, .settings, .removedProject:
            nil
        }
    }
}

enum SidebarBadgePolicy {
    static let badgedRoutes: [AppRoute] = [.needsReview, .notifications]
    static let notificationBadgeSurfaceCount = badgedRoutes.filter { $0 == .notifications }.count
}

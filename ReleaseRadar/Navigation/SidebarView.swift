import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: DashboardLayout.sidebarWidth(isCompact: model.isSidebarCompact))
                .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .task {
            await model.loadCodexRuntime()
            if model.dashboard == nil {
                await model.loadDashboard()
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if !model.isSidebarCompact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delivery")
                            .font(.headline)
                        Text("Local agent workspace")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        model.isSidebarCompact.toggle()
                    }
                } label: {
                    Image(systemName: model.isSidebarCompact ? "chevron.right" : "chevron.left")
                        .font(.system(size: 15, weight: .light))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help(model.isSidebarCompact ? "Expand Sidebar" : "Collapse Sidebar")
                .accessibilityIdentifier("sidebar-collapse")
            }
            .padding(.horizontal, model.isSidebarCompact ? 12 : 16)
            .padding(.top, 16)

            VStack(spacing: 4) {
                ForEach(AppRoute.primaryRoutes, id: \.self) { route in
                    if route == .settings {
                        sidebarButton(route: route, count: nil) {
                            openSettings()
                        }
                    } else {
                        sidebarButton(route: route, count: primaryCount(for: route)) {
                            Task { await model.navigate(to: route) }
                        }
                    }
                }
            }

            Divider()
                .padding(.horizontal, 12)

            if !model.isSidebarCompact {
                Text(model.currentProject?.name ?? "Current project")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .padding(.horizontal, 18)
            }

            VStack(spacing: 4) {
                ForEach(AppRoute.projectRoutes(for: model.currentProjectID), id: \.self) { route in
                    sidebarButton(route: route, count: nil) {
                        Task { await model.navigate(to: route) }
                    }
                }
            }

            Spacer(minLength: 12)

            if !model.isSidebarCompact {
                Text("Persisted locally")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    private func sidebarButton(
        route: AppRoute,
        count: Int?,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = route != .settings && model.selection == route
        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    Image(systemName: route.systemImage)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 24, weight: .light))
                        .frame(width: 34, height: 34)

                    if !model.isSidebarCompact {
                        Text(route.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: model.isSidebarCompact ? .center : .leading)
                .frame(height: 46)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .padding(.horizontal, count > 9 ? 5 : 0)
                        .frame(minWidth: 19, minHeight: 19)
                        .background(Color(nsColor: .systemRed).opacity(0.14), in: Capsule())
                        .offset(x: model.isSidebarCompact ? -2 : -4, y: 1)
                        .accessibilityLabel("\(count) items")
                }
            }
            .padding(.horizontal, model.isSidebarCompact ? 10 : 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear)
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.72))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .accessibilityLabel(route.title)
        .accessibilityIdentifier("sidebar-\(route.accessibilityID)")
    }

    private func primaryCount(for route: AppRoute) -> Int? {
        switch route {
        case .needsReview: model.needsReviewCount
        case .notifications: model.notificationCount
        default: nil
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let error = model.dashboardError {
            ContentUnavailableView(
                "Delivery data unavailable",
                systemImage: "externaldrive.badge.exclamationmark",
                description: Text(error)
            )
        } else if let dashboard = model.dashboard {
            switch model.selection {
            case .projects:
                ProjectsView(projection: dashboard) { projectID in
                    Task { await model.openProject(projectID) }
                }
            case .needsReview:
                if let inbox = model.reviewInbox(for: model.currentProjectID) {
                    NeedsReviewView(
                        inbox: inbox,
                        selectedItemID: $model.selectedReviewItemID,
                        isPerformingAction: model.isPerformingReviewAction,
                        actionError: model.reviewActionError
                    ) { decision, item in
                        await model.performReviewDecision(decision, item: item)
                    }
                } else {
                    DetailUnavailableView(title: "Needs Review", image: "checkmark.bubble")
                }
            case .notifications:
                if let activity = model.activity(for: model.currentProjectID),
                   let project = dashboard.projects.first(where: { $0.id == model.currentProjectID }) {
                    NotificationsView(activity: activity, projectName: project.name)
                } else {
                    DetailUnavailableView(title: "Notifications", image: "bell")
                }
            case let .projectOverview(projectID):
                if let board = dashboard.board(for: projectID) {
                    ProjectOverviewView(board: board) {
                        Task { await model.navigate(to: .phaseBoard(projectID)) }
                    }
                }
            case let .phaseBoard(projectID):
                if let board = dashboard.board(for: projectID) {
                    PhaseBoardView(board: board, selectedTicketID: $model.selectedTicketID)
                }
            case let .dependencies(projectID):
                if let graph = model.dependencyGraph(for: projectID) {
                    DependencyGraphView(
                        graph: graph,
                        selectedTicketID: $model.selectedTicketID,
                        freshness: model.codexSnapshot.freshness
                    )
                } else {
                    DetailUnavailableView(title: "Dependencies", image: "arrow.triangle.branch")
                }
            case let .activity(projectID):
                if let activity = model.activity(for: projectID),
                   let project = dashboard.projects.first(where: { $0.id == projectID }) {
                    ActivityView(
                        activity: activity,
                        projectName: project.name,
                        freshness: model.codexSnapshot.freshness
                    )
                } else {
                    DetailUnavailableView(title: "Activity", image: "clock.arrow.circlepath")
                }
            case .settings:
                DetailUnavailableView(title: "Settings", image: "gearshape")
            }
        } else {
            ProgressView("Loading local delivery data…")
                .controlSize(.large)
        }
    }
}

private struct DetailUnavailableView: View {
    let title: String
    let image: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: image,
            description: Text("Persisted project data is unavailable for this section.")
        )
        .navigationTitle(title)
    }
}

private extension AppRoute {
    var accessibilityID: String {
        switch self {
        case .projects: "projects"
        case .needsReview: "needs-review"
        case .notifications: "notifications"
        case .settings: "settings"
        case .projectOverview: "project-overview"
        case .phaseBoard: "phase-board"
        case .dependencies: "dependencies"
        case .activity: "activity"
        }
    }
}

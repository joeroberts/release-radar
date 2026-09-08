import AppKit
import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct SidebarView: View {
    @Bindable var model: AppModel
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                sidebar
                    .frame(
                        width: DashboardLayout.sidebarWidth(isCompact: model.isSidebarCompact),
                        height: geometry.size.height
                    )
                    .background(RekonTheme.backgroundRaised)

                RekonSeparator(.vertical)
                    .frame(height: geometry.size.height)

                detail
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height)
                    .background(RekonTheme.background)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .foregroundStyle(RekonTheme.primaryText)
        .task {
            await model.initializeForLaunch()
            model.startDocumentationMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.recheckDocumentationAfterActivation() }
        }
        .onDisappear { model.stopDocumentationMonitoring() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if !model.isSidebarCompact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delivery")
                            .font(RekonTypography.compactTitle)
                            .foregroundStyle(RekonTheme.primaryText)
                        Text("Local agent workspace")
                            .font(RekonTypography.metadata)
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                    .transition(.opacity)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        model.isSidebarCompact.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15, weight: .light))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .help(model.isSidebarCompact ? "Expand navigation sidebar" : "Collapse navigation sidebar")
                .accessibilityLabel(model.isSidebarCompact ? "Expand navigation sidebar" : "Collapse navigation sidebar")
                .accessibilityHint(model.isSidebarCompact
                    ? "Shows navigation labels beside their icons."
                    : "Hides navigation labels and keeps their icons visible.")
                .accessibilityIdentifier("sidebar-collapse")
            }
            .padding(.horizontal, model.isSidebarCompact ? 12 : 16)
            .padding(.top, 16)

            VStack(spacing: 4) {
                ForEach(AppRoute.primaryRoutes, id: \.self) { route in
                    sidebarButton(route: route, count: primaryCount(for: route)) {
                        Task { await model.navigate(to: route) }
                    }
                }
            }

            if let currentProject = model.currentProject {
                RekonSeparator()
                    .padding(.horizontal, 12)

                if !model.isSidebarCompact {
                    Text(currentProject.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .padding(.horizontal, 18)
                }

                VStack(spacing: 4) {
                    ForEach(AppRoute.projectRoutes(for: currentProject.id), id: \.self) { route in
                        sidebarButton(route: route, count: nil) {
                            Task { await model.navigate(to: route) }
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            if !model.isSidebarCompact {
                Text("Persisted locally")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText.opacity(0.7))
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
        let isSelected = model.selection == route
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
                        .foregroundStyle(RekonTheme.danger)
                        .padding(.horizontal, count > 9 ? 5 : 0)
                        .frame(minWidth: 19, minHeight: 19)
                        .background(RekonTheme.danger.opacity(0.14), in: Capsule())
                        .offset(x: model.isSidebarCompact ? -2 : -4, y: 1)
                        .accessibilityLabel("\(count) items")
                }
            }
            .padding(.horizontal, model.isSidebarCompact ? 10 : 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? RekonTheme.elevatedSurface : .clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule().fill(RekonTheme.accent).frame(width: 3).padding(.vertical, 8)
                }
            }
            .foregroundStyle(isSelected ? RekonTheme.accent : RekonTheme.primaryText.opacity(0.78))
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
        if model.selection == .settings {
            SettingsView(model: model)
        } else if let error = model.dashboardError {
            FailureStateView(
                presentation: .init(
                    title: "Delivery data unavailable",
                    detail: error,
                    systemImage: "externaldrive.badge.exclamationmark",
                    tone: .error,
                    accessibilityID: "failure-delivery-data"
                ),
                style: .full,
                actionTitle: "Reload dashboard",
                action: {
                    Task { await model.reloadDashboardAfterCommittedAgentCommand() }
                }
            )
        } else if let dashboard = model.dashboard {
            switch model.selection {
            case .projects:
                ProjectsView(
                    projection: dashboard,
                    onboardingStore: model.onboardingStore,
                    codexTasks: model.codexTasksForOnboarding(),
                    openProject: { projectID in
                        Task { await model.openProject(projectID) }
                    },
                    openArchivedProject: { projectID in
                        Task { await model.navigate(to: .archivedProject(projectID)) }
                    },
                    openRemovedProject: { removalID in
                        Task { await model.navigate(to: .removedProject(removalID)) }
                    },
                    onboardingFinished: {
                        await model.reloadAfterOnboarding()
                    }
                )
            case .needsReview:
                if let inbox = model.reviewInbox(for: model.currentProjectID) {
                    NeedsReviewView(
                        inbox: inbox,
                        selectedItemID: $model.selectedReviewItemID,
                        isPerformingAction: model.scopedIsPerformingReviewAction(for: inbox.projectID),
                        actionFailure: model.scopedReviewActionFailure(for: inbox.projectID),
                        projectName: model.currentProject?.name ?? "this project",
                        authorizationRecovery: model.scopedReviewAuthorizationRecovery(for: inbox.projectID),
                        onDecision: { decision, item in
                            await model.performReviewDecision(decision, item: item)
                        },
                        onRecoverAuthorization: { folder, projectID in
                            await model.recoverReviewAuthorization(at: folder, for: projectID)
                        },
                        onAcceptDeliveryGoal: { await model.acceptDeliveryGoal($0) },
                        onReload: { await model.reloadDeliveryGoalAcceptance(projectID: inbox.projectID) },
                        acceptanceNeedsReload: model.deliveryGoalAcceptanceNeedsReload(for: inbox.projectID)
                    )
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
                if let project = dashboard.projects.first(where: { $0.id == projectID }) {
                    ProjectOverviewView(
                        project: project,
                        board: dashboard.board(for: projectID),
                        documentationState: model.projectDocumentationState(for: projectID),
                        documentationStatus: model.documentationObservationStatus(for: projectID),
                        projectRoot: model.projectRoot(for: projectID),
                        phaseSelectionStatus: model.activePhaseSelectionStatus(for: projectID),
                        openBoard: {
                            Task { await model.navigate(to: .phaseBoard(projectID)) }
                        },
                        selectActivePhase: { phaseID in
                            await model.setActivePhase(projectID: projectID, phaseID: phaseID)
                        },
                        reloadActivePhase: {
                            await model.reloadAfterActivePhaseSelection(projectID: projectID)
                        },
                        reauthorizeActivePhase: { folder in
                            await model.reauthorizeActivePhaseProject(at: folder, projectID: projectID)
                        },
                        repositoryRecovery: model.repositoryRecovery(for: projectID),
                        onRepositoryRelocated: { await model.reloadAfterRepositoryRelocation() },
                        loadProjectSettings: { try await model.projectSettings(for: projectID) },
                        saveProjectSettings: { registration, name, exclusions in
                            try await model.updateProjectSettings(
                                registration: registration,
                                projectName: name,
                                excludedTaskIDs: exclusions
                            )
                        },
                        availableCodexTasks: model.codexTasks(for: projectID),
                        loadProjectHealth: { await model.projectHealth(for: projectID) },
                        reauthorizeProjectHealth: { folder, identity in
                            try await model.restoreDocumentationFolderAccess(
                                at: folder,
                                identity: identity
                            )
                        },
                        loadEvidencePreview: { evidenceID in
                            await model.previewEvidence(projectID: projectID, evidenceID: evidenceID)
                        },
                        previewDocumentationSetup: { try await model.previewDocumentationSetup(registration: $0) },
                        performDocumentationSetup: { try await model.performDocumentationSetup($0) },
                        previewArchive: { try await model.previewProjectLifecycle(projectID: projectID, transition: .archive) },
                        archive: { try await model.applyProjectLifecycle($0) },
                        previewRemoval: { try await model.previewProjectRemoval(projectID: projectID) },
                        remove: { _ = try await model.applyProjectRemoval($0) }
                    )
                } else {
                    ProjectEmptyStateView(presentation: .phaseBoard)
                }
            case let .archivedProject(projectID):
                if let project = dashboard.archivedProjects.first(where: { $0.id == projectID }) {
                    ArchivedProjectView(
                        project: project,
                        loadHealth: { await model.projectHealth(for: projectID) },
                        previewRestore: { try await model.previewProjectLifecycle(projectID: projectID, transition: .restore) },
                        restore: { try await model.applyProjectLifecycle($0) },
                        previewRemoval: { try await model.previewProjectRemoval(projectID: projectID) },
                        remove: { _ = try await model.applyProjectRemoval($0) }
                    )
                } else {
                    DetailUnavailableView(title: "Archived Project", image: "archivebox")
                }
            case let .removedProject(removalID):
                if let project = dashboard.removedProjects.first(where: { $0.id == removalID }),
                   let activity = model.removedActivity(for: removalID) {
                    RemovedProjectView(project: project, activity: activity)
                } else {
                    DetailUnavailableView(title: "Removed Project", image: "clock.badge.xmark")
                }
            case let .phaseBoard(projectID):
                if let board = model.viewedBoard(for: projectID) {
                    PhaseBoardView(
                        board: board,
                        selectedTicketID: $model.selectedTicketID,
                        phaseSelectionStatus: model.activePhaseSelectionStatus(for: projectID),
                        selectActivePhase: { phaseID in
                            await model.setActivePhase(projectID: projectID, phaseID: phaseID)
                        },
                        reloadActivePhase: {
                            await model.reloadAfterActivePhaseSelection(projectID: projectID)
                        },
                        reauthorizeActivePhase: { folder in
                            await model.reauthorizeActivePhaseProject(at: folder, projectID: projectID)
                        },
                        documentationStatus: model.documentationObservationStatus(for: projectID),
                        restoreDocumentationFolderAccess: { folder, identity in
                            _ = try await model.restoreDocumentationFolderAccess(
                                at: folder,
                                identity: identity
                            )
                        },
                        openWorktreeRecovery: {
                            Task { await model.navigate(to: .projectOverview(projectID)) }
                        },
                        loadEvidencePreview: { evidenceID in
                            await model.previewEvidence(projectID: projectID, evidenceID: evidenceID)
                        },
                        viewPhase: { model.viewPhase(projectID: projectID, phaseID: $0) }
                    )
                } else if let project = dashboard.projects.first(where: { $0.id == projectID }),
                          !project.phases.isEmpty {
                    ActivePhaseBoardRecoveryView(
                        project: project,
                        status: model.activePhaseSelectionStatus(for: projectID),
                        onSelect: { phaseID in
                            await model.setActivePhase(projectID: projectID, phaseID: phaseID)
                        },
                        onReload: {
                            await model.reloadAfterActivePhaseSelection(projectID: projectID)
                        },
                        onReauthorize: { folder in
                            await model.reauthorizeActivePhaseProject(at: folder, projectID: projectID)
                        }
                    )
                } else {
                    ProjectEmptyStateView(presentation: .phaseBoard)
                }
            case let .dependencies(projectID):
                if let graph = model.dependencyGraph(for: projectID) {
                    DependencyGraphView(
                        graph: graph,
                        selectedTicketID: $model.selectedTicketID,
                        freshness: model.codexSnapshot.freshness
                    )
                } else {
                    if let project = dashboard.projects.first(where: { $0.id == projectID }), project.phases.isEmpty {
                        ProjectEmptyStateView(presentation: .dependencies)
                    } else {
                        DetailUnavailableView(title: "Dependencies", image: "arrow.triangle.branch")
                    }
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
                EmptyView()
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
        ProjectEmptyStateView(presentation: .init(
            title: title,
            detail: "Persisted project data is unavailable for this section.",
            systemImage: image,
            accessibilityID: "empty-section-unavailable"
        ))
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
        case .archivedProject: "archived-project"
        case .removedProject: "removed-project"
        case .phaseBoard: "phase-board"
        case .dependencies: "dependencies"
        case .activity: "activity"
        }
    }
}

struct RekonScreenHeader: View {
    let title: String
    let subtitle: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(RekonTypography.screenTitle)
                    .foregroundStyle(RekonTheme.primaryText)
                Text(subtitle)
                    .font(RekonTypography.secondaryBody)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 20)
    }
}

import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct ProjectsView: View {
    @Environment(\.openWindow) private var openWindow
    let projection: DashboardProjection
    let onboardingStore: DeliveryStore
    var codexTasks: [CodexTaskDescriptor] = []
    let openProject: (ProjectID) -> Void
    let openArchivedProject: (ProjectID) -> Void
    let onboardingFinished: @MainActor () async -> Void
    @State private var scope = ProjectListScope.active

    var body: some View {
        if projection.projects.isEmpty && projection.archivedProjects.isEmpty {
            OnboardingView(
                store: onboardingStore,
                codexTasks: codexTasks,
                onOpenExisting: openProject
            ) { _ in
                await onboardingFinished()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    RekonScreenHeader(title: "Projects", subtitle: "Local delivery structure and owner attention at a glance")

                    ViewThatFits(in: .horizontal) {
                        HStack { scopePicker; Spacer(); addButton }
                        VStack(alignment: .leading, spacing: 12) { scopePicker; addButton }
                    }
                    .padding(.horizontal, 28)

                    if scope == .active {
                        if projection.projects.isEmpty {
                            projectListEmptyState(
                                title: "No active projects",
                                detail: "Restore an archived project or add a new one to resume delivery work."
                            )
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                                ForEach(projection.projects) { project in
                                    Button {
                                        openProject(project.id)
                                    } label: {
                                        RekonCard {
                                            VStack(alignment: .leading, spacing: 18) {
                                                HStack(alignment: .top) {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(project.name)
                                                            .font(RekonTypography.cardTitle)
                                                        Text("Active phase")
                                                            .font(RekonTypography.metadata)
                                                            .foregroundStyle(RekonTheme.secondaryText)
                                                        if project.activePhaseName == "No active phase" {
                                                            Text("Ready for planning")
                                                                .foregroundStyle(RekonTheme.secondaryText)
                                                        } else {
                                                            Text(project.activePhaseName)
                                                                .font(RekonTypography.secondaryBody)
                                                                .foregroundStyle(RekonTheme.secondaryText)
                                                        }
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 14, weight: .light))
                                                        .foregroundStyle(RekonTheme.secondaryText)
                                                }

                                                ProjectGoalSummaryView(context: project.goalContext)

                                                HStack(spacing: 26) {
                                                    projectMetric(value: project.currentWorkCount, label: "Current work")
                                                    projectMetric(value: project.attentionCount, label: "Needs attention")
                                                }
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("project-\(project.id.rawValue)")
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    } else if projection.archivedProjects.isEmpty {
                        projectListEmptyState(
                            title: "No archived projects",
                            detail: "Archived projects remain preserved here until you restore them."
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                            ForEach(projection.archivedProjects) { project in
                                Button { openArchivedProject(project.id) } label: {
                                    RekonCard {
                                        VStack(alignment: .leading, spacing: 16) {
                                            HStack(alignment: .top) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(project.name).font(RekonTypography.cardTitle)
                                                    Label("Archived · Read-only", systemImage: "archivebox")
                                                        .font(RekonTypography.metadata)
                                                        .foregroundStyle(RekonTheme.secondaryText)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right").foregroundStyle(RekonTheme.secondaryText)
                                            }
                                            HStack(spacing: 24) {
                                                projectMetric(value: Int(project.counts.phases), label: "Phases")
                                                projectMetric(value: Int(project.counts.tickets), label: "Tickets")
                                                projectMetric(value: Int(project.counts.evidence), label: "Evidence")
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("archived-project-\(project.id.rawValue)")
                            }
                        }
                        .padding(.horizontal, 28)
                    }
                }
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Projects")
            .background(RekonTheme.background)
        }
    }

    private var scopePicker: some View {
        Picker("Project status", selection: $scope) {
            Text("Active (\(projection.projects.count))").tag(ProjectListScope.active)
            Text("Archived (\(projection.archivedProjects.count))").tag(ProjectListScope.archived)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 360)
        .accessibilityIdentifier("projects-status-scope")
    }

    private var addButton: some View {
        Button("Add Project…") { openWindow(id: "add-project") }
            .buttonStyle(RekonPrimaryButtonStyle())
            .accessibilityIdentifier("projects-add")
    }

    private func projectListEmptyState(title: String, detail: String) -> some View {
        RekonCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(RekonTypography.cardTitle)
                Text(detail).foregroundStyle(RekonTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        }
        .padding(.horizontal, 28)
    }

    private func projectMetric(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(RekonTypography.sectionTitle)
                .foregroundStyle(RekonTheme.primaryText)
            Text(label)
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
        }
    }
}

private enum ProjectListScope: Hashable {
    case active
    case archived
}

struct ProjectGoalSummaryView: View {
    let context: GoalContextProjection

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: context.linkQuality == .verified ? "checkmark.seal" : "questionmark.circle")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(context.linkQuality == .verified ? RekonTheme.success : RekonTheme.secondaryText)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.linkQuality == .verified ? "Verified last-known goal" : "Last-known goal unavailable")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RekonTheme.secondaryText)

                if let status = context.status {
                    Text(status)
                        .font(.subheadline.weight(.semibold))
                }

                if let text = context.text {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .lineLimit(2)
                } else {
                    Text("No persisted goal observation")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                }

                if let observedAt = context.lastObservedAt {
                    Text("Observed \(observedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(RekonTypography.metadata)
                        .foregroundStyle(RekonTheme.secondaryText)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct ProjectsView: View {
    @Environment(\.openWindow) private var openWindow
    let projection: DashboardProjection
    let onboardingStore: DeliveryStore
    var codexTasks: [CodexTaskDescriptor] = []
    let openProject: (ProjectID) -> Void
    let onboardingFinished: @MainActor () async -> Void

    var body: some View {
        if projection.projects.isEmpty {
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
                    RekonScreenHeader(
                        title: "Projects",
                        subtitle: "Local delivery structure and owner attention at a glance",
                        trailing: AnyView(Button("Add Project…") {
                            openWindow(id: "add-project")
                        }
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("projects-add"))
                    )

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
                                                .font(.title3.weight(.semibold))
                                            Text("Active phase")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                            if project.activePhaseName == "No active phase" {
                                                Text("Ready for planning")
                                                    .foregroundStyle(RekonTheme.secondaryText)
                                            } else {
                                                Text(project.activePhaseName)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .light))
                                            .foregroundStyle(.tertiary)
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
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Projects")
            .background(RekonTheme.background)
        }
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

struct ProjectGoalSummaryView: View {
    let context: GoalContextProjection

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: context.linkQuality == .verified ? "checkmark.seal" : "questionmark.circle")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(context.linkQuality == .verified ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.linkQuality == .verified ? "Verified last-known goal" : "Last-known goal unavailable")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if let status = context.status {
                    Text(status)
                        .font(.subheadline.weight(.semibold))
                }

                if let text = context.text {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No persisted goal observation")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let observedAt = context.lastObservedAt {
                    Text("Observed \(observedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

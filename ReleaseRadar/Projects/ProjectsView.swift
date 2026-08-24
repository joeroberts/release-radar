import SwiftUI
import ReleaseRadarCore

struct ProjectsView: View {
    let projection: DashboardProjection
    let onboardingStore: DeliveryStore
    let openProject: (ProjectID) -> Void

    var body: some View {
        if projection.projects.isEmpty {
            OnboardingView(store: onboardingStore)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Projects")
                            .font(.largeTitle.weight(.semibold))
                        Text("Local delivery structure and owner attention at a glance")
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                        ForEach(projection.projects) { project in
                            Button {
                                openProject(project.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 18) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(project.name)
                                                .font(.title3.weight(.semibold))
                                            Text("Active phase")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                            if project.activePhaseName == "No active phase" {
                                                FailureStateView(
                                                    presentation: .firstPhaseRequired,
                                                    style: .compact
                                                )
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
                                .padding(20)
                                .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("project-\(project.id.rawValue)")
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Projects")
        }
    }

    private func projectMetric(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.medium))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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

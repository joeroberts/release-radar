import SwiftUI
import ReleaseRadarCore

struct ProjectsView: View {
    let projection: DashboardProjection
    let openProject: (ProjectID) -> Void

    var body: some View {
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
                                        Text(project.activePhaseName)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .light))
                                        .foregroundStyle(.tertiary)
                                }

                                HStack(spacing: 26) {
                                    projectMetric(value: project.currentWorkCount, label: "Current work")
                                    projectMetric(value: project.attentionCount, label: "Needs attention")
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
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

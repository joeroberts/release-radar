import SwiftUI
import ReleaseRadarCore

struct ProjectOverviewView: View {
    let board: PhaseBoardProjection
    let openBoard: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(board.project.name)
                        .font(.largeTitle.weight(.semibold))
                    Text("Project overview")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    summaryCard("Active phase", value: board.project.activePhaseName, systemImage: "flag")
                    summaryCard("Current work", value: "\(board.project.currentWorkCount)", systemImage: "rectangle.stack")
                    summaryCard("Owner attention", value: "\(board.project.attentionCount)", systemImage: "person.crop.circle.badge.exclamationmark")
                }

                ProjectGoalSummaryView(context: board.project.goalContext)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(board.project.activePhaseName)
                                .font(.title2.weight(.semibold))
                            Text("Delivery state is derived from persisted lane membership.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open phase board", action: openBoard)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("open-phase-board")
                    }

                    HStack(spacing: 10) {
                        ForEach(board.lanes) { lane in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(lane.lane.dashboardTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(lane.count)")
                                    .font(.title2.weight(.medium))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(lane.lane.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryCard(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
}

extension TicketLane {
    var tint: Color {
        switch self {
        case .backlog: .secondary
        case .inProgress: .cyan
        case .needsReview: .orange
        case .blocked: .red
        case .accepted: .green
        }
    }
}

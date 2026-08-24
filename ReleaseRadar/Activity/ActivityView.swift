import SwiftUI
import ReleaseRadarCore

struct ActivityView: View {
    let activity: ProjectActivityProjection
    let projectName: String
    let freshness: CodexObservationFreshness

    var body: some View {
        let connection = CodexConnectionPresentation(freshness: freshness)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity")
                            .font(.largeTitle.weight(.semibold))
                        Text("Persisted delivery history for \(projectName)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Codex \(connection.status)")
                            .font(.subheadline.weight(.medium))
                        Text(connection.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Runtime state is last-observed context. Delivery lane remains the persisted formal state.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(activity.items) { item in
                        activityRow(item)
                    }
                }
            }
            .padding(24)
        }
        .accessibilityIdentifier("content-activity")
    }

    private func activityRow(_ item: ProjectActivityItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.source.systemImage)
                .foregroundStyle(item.source.tint)
                .frame(width: 28, height: 28)
                .background(item.source.tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.title).font(.headline)
                    if let ticketID = item.ticketID {
                        Text(ticketID.rawValue)
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let freshnessText = item.freshnessText {
                        Text(freshnessText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(item.detail)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let lane = item.deliveryLane {
                        Text("Lane · \(lane.dashboardTitle)")
                            .font(.caption)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                    if let runtime = item.runtimeState {
                        Text("Runtime · \(runtime.title)")
                            .font(.caption)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.35)) }
        .accessibilityElement(children: .combine)
    }
}

private extension ActivitySource {
    var systemImage: String {
        switch self {
        case .audit: "checkmark.seal"
        case .runtime: "clock.arrow.circlepath"
        case .review: "checkmark.bubble"
        case .completion: "flag.checkered"
        case .notification: "bell"
        }
    }

    var tint: Color {
        switch self {
        case .audit: .purple
        case .runtime: .blue
        case .review: .orange
        case .completion: .green
        case .notification: .red
        }
    }
}

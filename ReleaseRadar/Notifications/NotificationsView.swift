import SwiftUI
import ReleaseRadarCore

struct NotificationsView: View {
    let activity: ProjectActivityProjection
    let projectName: String

    private var notifications: [ProjectActivityItem] {
        activity.items.filter { $0.source == .notification }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.largeTitle.weight(.semibold))
                    Text("Durable Pushover delivery history for \(projectName)")
                        .foregroundStyle(.secondary)
                }

                if notifications.isEmpty {
                    ContentUnavailableView(
                        "No notification history",
                        systemImage: "tray",
                        description: Text("Meaningful blocks, completions, and review entries will appear here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(notifications) { item in
                            notificationRow(item)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("content-notifications")
    }

    private func notificationRow(_ item: ProjectActivityItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            statusMark(item.notificationState)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
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
                Text(item.detail).foregroundStyle(.secondary)
                if let failure = FailureStatePresentation(
                    notificationState: item.notificationState,
                    statusText: item.notificationStatusText
                ) {
                    FailureStateView(presentation: failure, style: .compact)
                } else {
                    Text(item.notificationStatusText ?? "Persisted delivery status")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor(item.notificationState))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.separator.opacity(0.35))
        }
        .accessibilityElement(children: .combine)
    }

    private func statusMark(_ state: NotificationDeliveryState?) -> some View {
        Circle()
            .fill(statusColor(state).opacity(0.18))
            .frame(width: 30, height: 30)
            .overlay { Circle().fill(statusColor(state)).frame(width: 8, height: 8) }
            .accessibilityHidden(true)
    }

    private func statusColor(_ state: NotificationDeliveryState?) -> Color {
        switch state {
        case .sent: .green
        case .failed, .unknown: .red
        case .attemptStarted: .blue
        case .queued: .orange
        case nil: .secondary
        }
    }
}

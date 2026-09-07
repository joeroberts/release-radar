import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct NotificationsView: View {
    let activity: ProjectActivityProjection
    let projectName: String

    private var notifications: [ProjectActivityItem] {
        activity.items.filter { $0.source == .notification }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RekonScreenHeader(title: "Notifications", subtitle: "Durable Pushover delivery history for \(projectName)")

                if notifications.isEmpty {
                    ProjectEmptyStateView(presentation: .init(
                        title: "No notification history",
                        detail: "Meaningful blocks, completions, and review entries will appear here.",
                        systemImage: "tray",
                        accessibilityID: "empty-notifications"
                    ))
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .padding(.horizontal, 28)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(notifications) { item in
                            notificationRow(item)
                        }
                    }
                    .padding(.horizontal, 28)
                }
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RekonTheme.background)
        .accessibilityIdentifier("content-notifications")
    }

    private func notificationRow(_ item: ProjectActivityItem) -> some View {
        RekonCard {
            HStack(alignment: .top, spacing: 16) {
                statusMark(item.notificationState)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title).font(.headline)
                        if let ticketID = item.ticketID {
                            Text(ticketID.rawValue)
                                .font(.system(.caption, design: .monospaced, weight: .medium))
                                .foregroundStyle(RekonTheme.secondaryText)
                        }
                        Spacer()
                        if let freshnessText = item.freshnessText {
                            Text(freshnessText)
                                .font(.caption)
                                .foregroundStyle(RekonTheme.secondaryText)
                        }
                    }
                    Text(item.detail).foregroundStyle(RekonTheme.secondaryText)
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
        case .sent: RekonTheme.success
        case .failed, .unknown: RekonTheme.danger
        case .attemptStarted: RekonTheme.accent
        case .queued: RekonTheme.warning
        case nil: RekonTheme.secondaryText
        }
    }
}

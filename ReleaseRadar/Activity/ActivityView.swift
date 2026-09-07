import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct ActivityView: View {
    let activity: ProjectActivityProjection
    let projectName: String
    let freshness: CodexObservationFreshness
    var showsFreshness = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RekonScreenHeader(title: "Activity", subtitle: "Persisted delivery history for \(projectName)")

                if showsFreshness, let codexFailure = FailureStatePresentation(freshness: freshness) {
                    FailureStateView(presentation: codexFailure)
                        .padding(.horizontal, 28)
                }

                Text("Runtime state is last-observed context. Delivery lane remains the persisted formal state.")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .padding(.horizontal, 28)

                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(activity.items) { item in
                        activityRow(item)
                    }
                }
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 24)
        }
        .background(RekonTheme.background)
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
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                    Spacer()
                    if let freshnessText = item.freshnessText {
                            Text(freshnessText)
                            .font(RekonTypography.metadata)
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                }
                Text(item.detail)
                    .foregroundStyle(RekonTheme.secondaryText)
                HStack(spacing: 8) {
                    if let lane = item.deliveryLane {
                        Text("Lane · \(lane.dashboardTitle)")
                            .font(.caption)
                            .foregroundStyle(RekonTheme.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RekonTheme.elevatedSurface, in: Capsule())
                    }
                    if let runtime = item.runtimeState {
                        Text("Runtime · \(runtime.title)")
                            .font(.caption)
                            .foregroundStyle(RekonTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RekonTheme.accent.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(RekonTheme.border.opacity(0.82), lineWidth: RekonBorder.hairline)
        }
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
        case .audit: RekonTheme.violet
        case .runtime: RekonTheme.accent
        case .review: RekonTheme.warning
        case .completion: RekonTheme.success
        case .notification: RekonTheme.danger
        }
    }
}

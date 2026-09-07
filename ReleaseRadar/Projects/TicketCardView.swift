import SwiftUI
import RekonDesignSystem

struct TicketCardView: View {
    let card: TicketCardProjection
    let presentation: DashboardCardPresentation
    let isSelected: Bool
    let select: () -> Void
    @ScaledMetric(relativeTo: .caption2) private var metadataFontSize = 11

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 7) {
                Text(card.id.rawValue)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .lineLimit(1)

                if presentation == .fullOutcome {
                    Text(card.outcome)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ticket-outcome-\(card.id.rawValue)")
                }

                if card.activeTaskCount != nil || card.dependencyCount > 0 || card.blockerCount > 0 {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { metadata(separated: true) }
                            .fixedSize()
                        VStack(alignment: .leading, spacing: 8) { metadata(separated: false) }
                    }
                    .frame(minHeight: 17)
                    .accessibilityHidden(true)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: presentation == .fullOutcome ? 78 : 48, alignment: .topLeading)
            .foregroundStyle(RekonTheme.primaryText)
            .background(
                isSelected ? RekonTheme.elevatedSurface : RekonTheme.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RekonTheme.accent.opacity(isSelected ? 1 : 0.46), lineWidth: isSelected ? 1.5 : 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(card.id.rawValue), \(card.outcome), "
                + (card.taskCountAnnouncement.map { $0 + ", " } ?? "")
                + "\(card.dependencyCount) dependencies, \(card.blockerCount) blockers\(isSelected ? ", selected" : "")"
        )
        .accessibilityIdentifier("ticket-\(card.id.rawValue)")
    }

    @ViewBuilder
    private func metadata(separated: Bool) -> some View {
        if let count = card.activeTaskCount {
            signal(systemImage: "checklist", count: count, color: RekonTheme.secondaryText)
        }
        if card.dependencyCount > 0 {
            if separated && card.activeTaskCount != nil { metadataSeparator }
            signal(systemImage: "point.3.connected.trianglepath.dotted", count: card.dependencyCount, color: RekonTheme.secondaryText)
        }
        if card.blockerCount > 0 {
            if separated && (card.activeTaskCount != nil || card.dependencyCount > 0) { metadataSeparator }
            signal(systemImage: "exclamationmark.octagon", count: card.blockerCount, color: RekonTheme.danger)
        }
    }

    private var metadataSeparator: some View {
        Divider().releaseRadarSeparator().frame(height: metadataFontSize * 1.25)
    }

    private func signal(systemImage: String, count: Int, color: Color) -> some View {
        Label {
            Text("\(count)")
                .font(.system(size: metadataFontSize).monospacedDigit())
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: metadataFontSize + 1, weight: .light))
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(color)
        .fixedSize()
    }
}

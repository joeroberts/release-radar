import SwiftUI

struct TicketCardView: View {
    let card: TicketCardProjection
    let presentation: DashboardCardPresentation
    let isSelected: Bool
    let select: () -> Void

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

                if card.dependencyCount > 0 || card.blockerCount > 0 {
                    HStack(spacing: 11) {
                        if card.dependencyCount > 0 {
                            signal(
                                systemImage: "point.3.connected.trianglepath.dotted",
                                count: card.dependencyCount,
                                color: .secondary,
                                label: "\(card.dependencyCount) dependencies"
                            )
                        }
                        if card.blockerCount > 0 {
                            signal(
                                systemImage: "exclamationmark.octagon",
                                count: card.blockerCount,
                                color: .red,
                                label: "\(card.blockerCount) blockers"
                            )
                        }
                    }
                    .frame(minHeight: 17)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: presentation == .fullOutcome ? 78 : 48, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.5 : 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.id.rawValue), \(card.outcome)")
        .accessibilityIdentifier("ticket-\(card.id.rawValue)")
    }

    private func signal(systemImage: String, count: Int, color: Color, label: String) -> some View {
        Label {
            Text("\(count)")
                .font(.caption2.monospacedDigit())
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .light))
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(color)
        .accessibilityLabel(label)
    }
}

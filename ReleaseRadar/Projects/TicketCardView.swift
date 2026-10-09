import Foundation
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

                if let phaseName = card.phaseName {
                    Label(phaseName, systemImage: "square.stack.3d.up")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .lineLimit(1)
                        .accessibilityIdentifier("ticket-phase-\(card.id.rawValue)")
                }

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
                    .stroke(
                        isSelected ? RekonTheme.accent : RekonTheme.border.opacity(0.82),
                        lineWidth: isSelected ? 1.5 : RekonBorder.hairline
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(card.id.rawValue), \(card.phaseName.map { $0 + ", " } ?? "")\(card.outcome), "
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
        RekonSeparator(.vertical).frame(height: metadataFontSize * 1.25)
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

enum TicketOrderingDirection {
    case earlier
    case later
}

enum TicketOrderingActionState {
    case idle
    case saving(Data)
    case failed(FailureStatePresentation, offersReload: Bool)
    case savedNeedsReload(TicketOrderingContext)

    var isSaving: Bool {
        if case .saving = self { return true }
        return false
    }
}

struct TicketOrderingMoveControls: View {
    var moveEarlier: (() -> Void)?
    var moveLater: (() -> Void)?
    let isDisabled: Bool
    let ticketID: TicketID

    var body: some View {
        if moveEarlier != nil || moveLater != nil {
            HStack(spacing: 6) {
                if let moveEarlier {
                    Button(action: moveEarlier) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .controlSize(.small)
                    .disabled(isDisabled)
                    .accessibilityLabel("Move earlier")
                    .accessibilityIdentifier("move-ticket-earlier-\(ticketID.rawValue)")
                }
                if let moveLater {
                    Button(action: moveLater) {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .controlSize(.small)
                    .disabled(isDisabled)
                    .accessibilityLabel("Move later")
                    .accessibilityIdentifier("move-ticket-later-\(ticketID.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct TicketOrderingStatusView: View {
    let state: TicketOrderingActionState
    let isReloading: Bool
    let reload: () -> Void

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .saving:
            ProgressView("Saving ticket order…")
                .controlSize(.small)
                .accessibilityIdentifier("ticket-ordering-progress")
        case let .failed(presentation, offersReload):
            if offersReload {
                FailureStateView(
                    presentation: presentation,
                    style: .compact,
                    actionTitle: "Reload ordering",
                    action: reload
                )
                .disabled(isReloading)
            } else {
                FailureStateView(presentation: presentation, style: .compact)
            }
        case .savedNeedsReload:
            FailureStateView(
                presentation: .init(
                    title: "Ticket order saved",
                    detail: "Ticket order saved. Reload to show the committed sequence.",
                    systemImage: "arrow.clockwise",
                    tone: .warning,
                    accessibilityID: "ticket-ordering-saved-needs-reload"
                ),
                style: .compact,
                actionTitle: "Reload ordering",
                action: reload
            )
            .disabled(isReloading)
        }
    }
}

func ticketOrderingAnchor(
    for ticketID: TicketID,
    direction: TicketOrderingDirection,
    lane: TicketLane,
    snapshots: [TicketLaneOrderSnapshot]
) -> TicketOrderAnchor? {
    guard let ticketIDs = snapshots.first(where: { $0.lane == lane })?.ticketIDs else { return nil }
    let identity = Data(ticketID.rawValue.utf8)
    guard let index = ticketIDs.firstIndex(where: {
        Data($0.rawValue.utf8) == identity
    }) else { return nil }
    switch direction {
    case .earlier:
        guard index > ticketIDs.startIndex else { return nil }
        return .before(ticketIDs[ticketIDs.index(before: index)])
    case .later:
        let next = ticketIDs.index(after: index)
        guard next < ticketIDs.endIndex else { return nil }
        return .after(ticketIDs[next])
    }
}

func ticketOrderingContextsMatch(
    _ lhs: TicketOrderingContext,
    _ rhs: TicketOrderingContext
) -> Bool {
    Data(lhs.projectID.rawValue.utf8) == Data(rhs.projectID.rawValue.utf8)
        && lhs.digest == rhs.digest
}

func ticketOrderingFailureOffersReload(_ error: AgentCommandError) -> Bool {
    switch error {
    case .ticketOrdering(.staleContext), .ticketOrdering(.unavailable(_)): true
    default: false
    }
}

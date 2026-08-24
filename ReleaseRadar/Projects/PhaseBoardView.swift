import ReleaseRadarCore
import SwiftUI

struct PhaseBoardView: View {
    let board: PhaseBoardProjection
    @Binding var selectedTicketID: TicketID

    var body: some View {
        GeometryReader { geometry in
            let showsSideInspector = geometry.size.width >= 1_260
            let boardWidth = geometry.size.width - (showsSideInspector ? 346 : 0) - 48
            let laneWidth = max(112, (boardWidth - 32) / 5)
            let presentation = DashboardLayout.presentation(forLaneWidth: laneWidth)

            VStack(alignment: .leading, spacing: 16) {
                boardHeader(presentation: presentation)

                if showsSideInspector {
                    HStack(alignment: .top, spacing: 16) {
                        lanes(presentation: presentation, laneWidth: laneWidth)

                        Divider()

                        detail
                            .frame(width: 314)
                    }
                } else {
                    VStack(spacing: 12) {
                        lanes(presentation: presentation, laneWidth: laneWidth)
                            .frame(minHeight: 390)

                        Divider()

                        detail
                            .frame(maxHeight: 260)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("phase-board")
    }

    private func boardHeader(presentation: DashboardCardPresentation) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(board.project.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(board.project.activePhaseName)
                    .font(.title2.weight(.semibold))
                Text("Lane position communicates delivery state; cards show work and constraints.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(presentation == .fullOutcome ? "Full outcomes" : "Compact IDs")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
                .accessibilityIdentifier("board-presentation")
        }
    }

    private func lanes(
        presentation: DashboardCardPresentation,
        laneWidth: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(board.lanes) { lane in
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text(lane.lane.dashboardTitle)
                                .lineLimit(1)
                            Spacer(minLength: 5)
                            laneCount(lane.count)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(lane.lane.dashboardTitle)
                                .lineLimit(1)
                            laneCount(lane.count)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 35, alignment: .topLeading)

                    ScrollView(.vertical) {
                        LazyVStack(spacing: 7) {
                            ForEach(lane.cards) { card in
                                cardView(card, presentation: presentation)
                            }
                        }
                    }
                    .scrollIndicators(.automatic)
                }
                .padding(10)
                .frame(width: laneWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(lane.lane.tint)
                        .frame(height: 2)
                        .clipShape(.rect(topLeadingRadius: 11, topTrailingRadius: 11))
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(lane.lane.dashboardTitle), \(lane.count) tickets")
                .accessibilityIdentifier("lane-\(lane.lane.rawValue)")
            }
        }
    }

    private func cardView(
        _ card: TicketCardProjection,
        presentation: DashboardCardPresentation
    ) -> some View {
        TicketCardView(
            card: card,
            presentation: presentation,
            isSelected: selectedTicketID == card.id
        ) {
            selectedTicketID = card.id
        }
    }

    private func laneCount(_ count: Int) -> some View {
        Text("\(count)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    @ViewBuilder
    private var detail: some View {
        if let selected = board.detail(for: selectedTicketID)
            ?? board.details.values.sorted(by: { $0.id.rawValue < $1.id.rawValue }).first {
            TicketDetailView(detail: selected)
        } else {
            ContentUnavailableView("Select a ticket", systemImage: "rectangle.on.rectangle")
        }
    }
}

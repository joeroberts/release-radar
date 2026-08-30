import ReleaseRadarCore
import SwiftUI

enum BoardDensity: String, CaseIterable, Identifiable {
    case fullOutcomes
    case compact

    var id: Self { self }

    var displayName: String {
        switch self {
        case .fullOutcomes: "Full outcomes"
        case .compact: "Compact density"
        }
    }

    func presentation(forLaneWidth laneWidth: CGFloat) -> DashboardCardPresentation {
        guard self == .fullOutcomes, laneWidth > 180 else { return .compactID }
        return .fullOutcome
    }

    func accessibilityValue(forLaneWidth laneWidth: CGFloat) -> String {
        if self == .fullOutcomes, presentation(forLaneWidth: laneWidth) == .compactID {
            return "Full outcomes requested; showing Compact density at the current width"
        }
        return displayName
    }

    func accessibilityOptionLabel(isSelected: Bool, forLaneWidth laneWidth: CGFloat) -> String {
        isSelected ? accessibilityValue(forLaneWidth: laneWidth) : displayName
    }

    func accessibilityHelp(forLaneWidth laneWidth: CGFloat) -> String {
        if self == .fullOutcomes, presentation(forLaneWidth: laneWidth) == .compactID {
            return "Full outcomes remains selected and restores automatically when the window is wide enough."
        }
        return "Choose whether cards show full outcomes or use compact density."
    }
}

enum PhaseBoardLayout {
    private static let sideInspectorMinimumWidth: CGFloat = 1_260

    static func usesVerticallyScrollableStack(forWidth width: CGFloat) -> Bool {
        width < sideInspectorMinimumWidth
    }
}

struct PhaseBoardView: View {
    let board: PhaseBoardProjection
    @Binding var selectedTicketID: TicketID
    let phaseSelectionStatus: ActivePhaseSelectionStatus
    let selectActivePhase: (PhaseID) async -> Void
    let reloadActivePhase: () async -> Void
    let reauthorizeActivePhase: (URL) async -> Void
    @State private var density: BoardDensity = .fullOutcomes

    private let minimumLaneWidth: CGFloat = 112
    private let laneSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let showsSideInspector = !PhaseBoardLayout.usesVerticallyScrollableStack(
                forWidth: geometry.size.width
            )
            let boardWidth = geometry.size.width - (showsSideInspector ? 346 : 0) - 48
            let requiredLaneWidth = minimumLaneWidth * 5 + laneSpacing * 4
            let needsHorizontalRecovery = boardWidth < requiredLaneWidth
            let laneWidth = needsHorizontalRecovery
                ? minimumLaneWidth
                : (boardWidth - laneSpacing * 4) / 5
            let presentation = density.presentation(forLaneWidth: laneWidth)

            VStack(alignment: .leading, spacing: 16) {
                boardHeader(laneWidth: laneWidth)

                if showsSideInspector {
                    HStack(alignment: .top, spacing: 16) {
                        laneWorkspace(
                            presentation: presentation,
                            laneWidth: laneWidth,
                            needsHorizontalRecovery: needsHorizontalRecovery
                        )

                        Divider()

                        detail
                            .frame(width: 314)
                    }
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 12) {
                            laneWorkspace(
                                presentation: presentation,
                                laneWidth: laneWidth,
                                needsHorizontalRecovery: needsHorizontalRecovery
                            )
                                .frame(height: 390)

                            Divider()

                            detail
                                .frame(height: 260)
                        }
                    }
                    .scrollIndicators(.automatic)
                    .accessibilityIdentifier("phase-board-vertical-recovery")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("phase-board")
    }

    private func boardHeader(laneWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                boardContext
                Spacer(minLength: 12)
                boardControls(laneWidth: laneWidth)
            }
            VStack(alignment: .leading, spacing: 12) {
                boardContext
                boardControls(laneWidth: laneWidth)
            }
        }
    }

    private var boardContext: some View {
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
    }

    private func boardControls(laneWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ActivePhaseSelector(
                project: board.project,
                surface: .board,
                status: phaseSelectionStatus,
                onSelect: selectActivePhase,
                onReload: reloadActivePhase,
                onReauthorize: reauthorizeActivePhase
            )
            Picker("Card density", selection: $density) {
                ForEach(BoardDensity.allCases) { option in
                    Text(option.displayName)
                        .accessibilityLabel(
                            option.accessibilityOptionLabel(
                                isSelected: density == option,
                                forLaneWidth: laneWidth
                            )
                        )
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityIdentifier("board-density")
            .accessibilityValue(density.accessibilityValue(forLaneWidth: laneWidth))
            .accessibilityHint(density.accessibilityHelp(forLaneWidth: laneWidth))
        }
    }

    @ViewBuilder
    private func laneWorkspace(
        presentation: DashboardCardPresentation,
        laneWidth: CGFloat,
        needsHorizontalRecovery: Bool
    ) -> some View {
        if needsHorizontalRecovery {
            ScrollView(.horizontal) {
                lanes(presentation: presentation, laneWidth: laneWidth)
            }
            .scrollIndicators(.automatic)
            .accessibilityLabel("Phase board lanes; scroll horizontally for all five lanes")
        } else {
            lanes(presentation: presentation, laneWidth: laneWidth)
        }
    }

    private func lanes(
        presentation: DashboardCardPresentation,
        laneWidth: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: laneSpacing) {
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

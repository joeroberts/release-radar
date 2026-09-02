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
    var viewPhase: (PhaseID) -> Void = { _ in }
    @State private var density: BoardDensity = .fullOutcomes
    @State var filter: DeliveryGoalFilter = .all
    @State private var selectionOutsideFilter = false
    @FocusState private var filterSummaryFocused: Bool
    @AccessibilityFocusState private var filterSummaryAccessibilityFocused: Bool

    private var filteredBoard: PhaseBoardProjection { board.filtered(by: filter) }

    private var filterSummary: String {
        let name: String = switch filter {
        case .all: "All goals"
        case .unassigned: "Unassigned upcoming tickets"
        case let .goal(id): "Delivery Goal \(id.rawValue)"
        }
        return "\(name): \(filteredBoard.lanes.reduce(0) { $0 + $1.count }) tickets"
            + (selectionOutsideFilter ? ". Prior selection is outside the current filter." : "")
    }

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
                PhaseBoardPlanningControls(board: board, filter: $filter,
                    phaseSelectionStatus: phaseSelectionStatus, viewPhase: viewPhase,
                    makeActive: selectActivePhase, reload: reloadActivePhase, reauthorize: reauthorizeActivePhase)
                HStack {
                    Text(filterSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("board-filter-summary")
                        .focusable()
                        .focused($filterSummaryFocused)
                        .accessibilityFocused($filterSummaryAccessibilityFocused)
                    Spacer()
                    densityPicker(laneWidth: laneWidth)
                }

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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("phase-board")
        .onChange(of: filter) { _, _ in reconcileFilteredSelection() }
        .onChange(of: board) { previous, current in
            guard PhaseBoardKey(projectID: previous.project.id, phaseID: previous.phaseID)
                == PhaseBoardKey(projectID: current.project.id, phaseID: current.phaseID) else { return }
            reconcileFilteredSelection()
        }
        .onChange(of: PhaseBoardKey(projectID: board.project.id, phaseID: board.phaseID)) { _, _ in
            filter = .all
            selectionOutsideFilter = false
        }
        .onChange(of: selectedTicketID) { _, _ in
            if filteredBoard.detail(for: selectedTicketID) != nil { selectionOutsideFilter = false }
        }
    }

    private func boardHeader(laneWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                boardContext
                Spacer(minLength: 12)
            }
            VStack(alignment: .leading, spacing: 12) {
                boardContext
            }
        }
    }

    private var boardContext: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(board.project.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(board.phaseName)
                .font(.title2.weight(.semibold))
            Text("Lane position communicates delivery state; cards show work and constraints.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func densityPicker(laneWidth: CGFloat) -> some View {
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

    private func reconcileFilteredSelection() {
        guard !selectedTicketID.rawValue.isEmpty,
              filteredBoard.detail(for: selectedTicketID) == nil else { return }
        selectionOutsideFilter = true
        selectedTicketID = TicketID(rawValue: "")
        filterSummaryFocused = true
        filterSummaryAccessibilityFocused = true
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
            ForEach(filteredBoard.lanes) { lane in
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
        if let selected = filteredBoard.detail(for: selectedTicketID)
            ?? (selectionOutsideFilter ? nil : filteredBoard.details.values.sorted(by: { $0.id.rawValue < $1.id.rawValue }).first) {
            TicketDetailView(detail: selected, reload: reloadActivePhase)
        } else {
            ContentUnavailableView("Select a ticket", systemImage: "rectangle.on.rectangle")
        }
    }
}

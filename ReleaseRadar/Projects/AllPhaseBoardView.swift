import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

enum AllPhaseBoardLayout {
    static func usesStackedInspector(forWidth width: CGFloat) -> Bool { width < 1_260 }
}

struct AllPhaseBoardView: View {
    let board: AllPhaseBoardProjection
    @Binding var selectedTicketID: TicketID
    @Binding var filter: DeliveryGoalFilter
    let viewPhase: (PhaseID) -> Void
    var documentationStatus: DocumentationObservationStatus? = nil
    var loadEvidencePreview: ((EvidenceID) async -> EvidencePreview)? = nil
    var requestedFocus: NavigationFocus? = nil
    var focusChanged: (NavigationFocus?) -> Void = { _ in }
    @State private var density: BoardDensity = .fullOutcomes
    @FocusState private var focusedTicketID: TicketID?

    private var filtered: AllPhaseBoardProjection { board.filtered(by: filter) }
    private let laneSpacing: CGFloat = 8
    private let minimumLaneWidth: CGFloat = 112

    var body: some View {
        GeometryReader { geometry in
            let sideInspector = !AllPhaseBoardLayout.usesStackedInspector(forWidth: geometry.size.width)
            let boardWidth = geometry.size.width - (sideInspector ? 346 : 0) - 48
            let requiredWidth = minimumLaneWidth * 5 + laneSpacing * 4
            let scrollsHorizontally = boardWidth < requiredWidth
            let laneWidth = scrollsHorizontally ? minimumLaneWidth : (boardWidth - laneSpacing * 4) / 5
            let presentation = density.presentation(forLaneWidth: laneWidth)
            VStack(alignment: .leading, spacing: 16) {
                header
                controls
                HStack {
                    Text(filterSummary).font(.caption).foregroundStyle(RekonTheme.secondaryText)
                        .accessibilityIdentifier("all-phase-board-filter-summary")
                    Spacer()
                    densityPicker(laneWidth: laneWidth)
                }
                if sideInspector {
                    HStack(alignment: .top, spacing: 16) {
                        laneWorkspace(laneWidth: laneWidth, presentation: presentation, scrolls: scrollsHorizontally)
                        RekonSeparator(.vertical)
                        detail.frame(width: 314)
                    }
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 12) {
                            laneWorkspace(laneWidth: laneWidth, presentation: presentation, scrolls: scrollsHorizontally)
                                .frame(height: 390)
                            RekonSeparator()
                            detail.frame(minHeight: 420, alignment: .top)
                        }
                    }
                    .accessibilityIdentifier("all-phase-board-vertical-recovery")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("all-phase-board")
        .onChange(of: filter) { _, _ in
            if filtered.detail(for: selectedTicketID) == nil { selectedTicketID = TicketID(rawValue: "") }
            focusChanged(.filterSummary)
        }
        .onChange(of: requestedFocus) { _, _ in applyRequestedFocus() }
        .task { applyRequestedFocus() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(board.project.name).font(RekonTypography.metadata.weight(.medium)).foregroundStyle(RekonTheme.secondaryText)
            Text("All phases").font(RekonTypography.screenTitle)
            Text("Five delivery lanes across every recorded phase. Unassigned tickets remain in Project Plan.")
                .font(.subheadline).foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { scopePicker; goalPicker }
            VStack(alignment: .leading, spacing: 8) { scopePicker; goalPicker }
        }
    }

    private var scopePicker: some View {
        HStack(spacing: 12) {
            Text("Board scope").font(RekonTypography.controlLabel)
            RekonPicker(
                selection: Binding(
                    get: { scopeOptions[0].selection },
                    set: { selection in
                        guard let option = scopeOptions.first(where: { $0.selection == selection }),
                              let phaseID = option.value else { return }
                        viewPhase(phaseID)
                    }
                ),
                options: scopeOptions.map(\.selection),
                accessibilityLabel: "Board scope",
                accessibilityIdentifier: "board-scope-selector"
            )
            .frame(minWidth: 260, idealWidth: 420, maxWidth: 520).frame(height: 42)
        }
    }

    private var scopeOptions: [ByteStablePickerOption<PhaseID?>] {
        ByteStablePickerOption.disambiguating(
            [(label: "All phases", byteIdentity: "reserved:all-phases", value: nil)]
                + board.project.phases.map { phase in
                    (label: "\(phase.name) · \(phase.id.rawValue)", byteIdentity: phase.id.rawValue, value: Optional(phase.id))
                }
        )
    }

    private var goalPicker: some View {
        HStack(spacing: 12) {
            Text("Delivery Goal").font(RekonTypography.controlLabel)
            RekonPicker(
                selection: Binding(
                    get: { goalOptions.first(where: { $0.value == filter })?.selection ?? "All goals" },
                    set: { selection in if let option = goalOptions.first(where: { $0.selection == selection }) { filter = option.value } }
                ),
                options: goalOptions.map(\.selection),
                accessibilityLabel: "Delivery Goal",
                accessibilityIdentifier: "all-phase-delivery-goal-filter"
            )
            .frame(minWidth: 260, idealWidth: 420, maxWidth: 520).frame(height: 42)
        }
    }

    private var goalOptions: [ByteStablePickerOption<DeliveryGoalFilter>] {
        var candidates: [(label: String, byteIdentity: String, value: DeliveryGoalFilter)] = [
            ("All goals", "reserved:all", .all),
            ("No Delivery Goal", "reserved:unassigned", .unassigned),
        ]
        candidates += board.filterableDeliveryGoals.map {
            ("\($0.title) · \($0.goalID.rawValue)", $0.goalID.rawValue, .goal($0.goalID))
        }
        return ByteStablePickerOption.disambiguating(candidates)
    }

    private var filterSummary: String {
        let title = switch filter {
        case .all: "All goals"
        case .unassigned: "No Delivery Goal"
        case let .goal(id): "Delivery Goal \(id.rawValue)"
        }
        return "\(title): \(filtered.lanes.reduce(0) { $0 + $1.count }) tickets"
    }

    @ViewBuilder private func laneWorkspace(laneWidth: CGFloat, presentation: DashboardCardPresentation, scrolls: Bool) -> some View {
        if scrolls {
            ScrollView(.horizontal) { lanes(laneWidth: laneWidth, presentation: presentation) }
                .accessibilityLabel("All-phase board lanes; scroll horizontally for all five lanes")
        } else {
            lanes(laneWidth: laneWidth, presentation: presentation)
        }
    }

    private func lanes(laneWidth: CGFloat, presentation: DashboardCardPresentation) -> some View {
        HStack(alignment: .top, spacing: laneSpacing) {
            ForEach(filtered.lanes) { lane in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(lane.lane.dashboardTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(lane.count)").font(.caption).monospacedDigit()
                    }
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 7) {
                            ForEach(lane.cards) { card in
                                TicketCardView(card: card, presentation: presentation, isSelected: selectedTicketID == card.id) {
                                    selectedTicketID = card.id
                                    focusChanged(.ticket(card.id))
                                }
                                .focusable().focused($focusedTicketID, equals: card.id)
                            }
                        }
                    }
                }
                .padding(10).frame(width: laneWidth, alignment: .topLeading).frame(maxHeight: .infinity, alignment: .topLeading)
                .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 11))
                .overlay { RoundedRectangle(cornerRadius: 11).stroke(RekonTheme.border, lineWidth: RekonBorder.hairline) }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(lane.lane.dashboardTitle), \(lane.count) tickets")
                .accessibilityIdentifier("all-phase-lane-\(lane.lane.rawValue)")
            }
        }
    }

    private func densityPicker(laneWidth: CGFloat) -> some View {
        RekonPicker(
            selection: Binding(get: { density.displayName }, set: { name in
                if let value = BoardDensity.allCases.first(where: { $0.displayName == name }) { density = value }
            }),
            options: BoardDensity.allCases.map(\.displayName),
            accessibilityLabel: "Card density",
            accessibilityIdentifier: "all-phase-board-density"
        )
        .frame(width: 190, height: 38)
    }

    @ViewBuilder private var detail: some View {
        if let selected = filtered.detail(for: selectedTicketID) ?? filtered.details.values.sorted(by: { $0.id.rawValue < $1.id.rawValue }).first {
            TicketDetailView(detail: selected, documentationStatus: documentationStatus, loadEvidencePreview: loadEvidencePreview)
        } else {
            ContentUnavailableView("Select a ticket", systemImage: "rectangle.on.rectangle")
        }
    }

    private func applyRequestedFocus() {
        if case let .ticket(ticketID) = requestedFocus, filtered.detail(for: ticketID) != nil {
            focusedTicketID = ticketID
        }
    }
}

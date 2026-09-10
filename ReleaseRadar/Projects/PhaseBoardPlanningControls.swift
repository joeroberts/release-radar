import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

extension DeliveryGoalLifecycle {
    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .planned: "Planned"
        case .active: "Active"
        case .awaitingAcceptance: "Awaiting acceptance"
        case .accepted: "Accepted"
        case .superseded: "Superseded"
        }
    }
}

extension PhaseLifecycle {
    var displayName: String {
        switch self {
        case .unassessed: "Unassessed"
        case .upcoming: "Upcoming"
        case .inDelivery: "In delivery"
        case .completed: "Completed"
        }
    }
}

struct ByteStablePickerOption<Value> {
    let selection: String
    let value: Value

    static func disambiguating(_ candidates: [(label: String, byteIdentity: String, value: Value)]) -> [Self] {
        candidates.map { candidate in
            let labelCollides = candidates.filter { $0.label == candidate.label }.count > 1
            let selection = labelCollides
                ? "\(candidate.label) · ID bytes \(utf8Hex(candidate.byteIdentity))"
                : candidate.label
            return Self(selection: selection, value: candidate.value)
        }
    }

    private static func utf8Hex(_ value: String) -> String {
        value.utf8.map { byte in
            let hex = String(byte, radix: 16, uppercase: true)
            return hex.count == 1 ? "0\(hex)" : hex
        }.joined()
    }
}

func hasSameUTF8Identity(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf8.elementsEqual(rhs.utf8)
}

struct PhaseBoardPlanningControls: View {
    let board: PhaseBoardProjection
    @Binding var filter: DeliveryGoalFilter
    let phaseSelectionStatus: ActivePhaseSelectionStatus
    let viewPhase: (PhaseID) -> Void
    var viewAllPhases: () -> Void = {}
    let makeActive: (PhaseID) async -> Void
    let reload: () async -> Void
    let reauthorize: (URL) async -> Void

    private var planSummary: String {
        let plan = board.phasePlan
        if plan.isDeliveryComplete {
            return "Ready · revision \(plan.revision) · no upcoming work · 0 unassigned"
        }
        let state = switch plan.state {
        case .legacyUnassessed: "Legacy unassessed"
        case .draft: "Draft"
        case .ready: "Ready"
        }
        return "\(state) · revision \(plan.revision) · \(plan.coveredUpcomingCount)/\(plan.upcomingCount) covered · \(plan.unassignedUpcomingCount) unassigned"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) { phasePicker; activePhase }
                VStack(alignment: .leading, spacing: 8) { phasePicker; activePhase }
            }
            Text("Plan: \(planSummary)")
                .font(.subheadline)
                .foregroundStyle(RekonTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("phase-plan-summary")
                .focusable()
            Text("Lifecycle: \(board.phaseLifecycle?.lifecycle.displayName ?? "Unavailable")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RekonTheme.primaryText)
                .accessibilityIdentifier("phase-lifecycle-summary")
                .accessibilityHint("Persisted phase lifecycle; independent of readiness and active or viewed phase.")
            if board.phasePlan.state != .ready {
                Label("Backlog and Blocked work cannot start until coverage is finalized.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { goalPicker; unassignedFilter }
                VStack(alignment: .leading, spacing: 8) { goalPicker; unassignedFilter }
            }
            if board.filterableDeliveryGoals.isEmpty {
                Text("No Delivery Goals recorded · \(board.phasePlan.unassignedUpcomingCount) unassigned upcoming tickets")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
    }

    private var phasePicker: some View {
        HStack(spacing: 12) {
            Text("Viewed phase")
                .font(RekonTypography.controlLabel)
                .foregroundStyle(RekonTheme.primaryText)
            RekonPicker(
                selection: Binding(
                    get: {
                        phasePickerOptions.first {
                            hasSameUTF8Identity($0.value.id.rawValue, board.phaseID.rawValue)
                        }?.selection ?? "\(board.phaseName) · \(board.phaseID.rawValue)"
                    },
                    set: { selection in
                        guard let option = phasePickerOptions.first(where: { $0.selection == selection }) else { return }
                        viewPhase(option.value.id)
                    }
                ),
                options: phasePickerOptions.map(\.selection),
                accessibilityLabel: "Viewed phase",
                accessibilityIdentifier: "viewed-phase-selector"
            )
            .frame(minWidth: 280, idealWidth: 520, maxWidth: 620)
            .frame(height: 42)
            Button("All phases", action: viewAllPhases)
                .accessibilityIdentifier("view-all-phases")
        }
        .accessibilityValue("\(board.phaseName), \(board.isActivePhase ? "active phase" : "not the active phase")")
        .accessibilityHint("Browse without changing the persisted active phase or delivery state.")
    }

    private var activePhase: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !board.isActivePhase {
                ActivePhaseSelector(project: board.project, surface: .board, status: phaseSelectionStatus,
                    onSelect: makeActive, onReload: reload, onReauthorize: reauthorize,
                    phaseToActivate: .init(id: board.phaseID, name: board.phaseName))
            }
            Text("Active phase: \(board.project.activePhaseName)")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("board-active-phase")
        }
    }

    private var goalPicker: some View {
        HStack(spacing: 12) {
            Text("Delivery Goal")
                .font(RekonTypography.controlLabel)
                .foregroundStyle(RekonTheme.primaryText)
            RekonPicker(
                selection: Binding(
                    get: {
                        goalPickerOptions.first(where: { $0.value == filter })?.selection
                            ?? unavailableGoalOption(for: filter)
                    },
                    set: { selection in
                        guard let option = goalPickerOptions.first(where: { $0.selection == selection }) else { return }
                        filter = option.value
                    }
                ),
                options: goalPickerOptions.map(\.selection),
                accessibilityLabel: "Delivery Goal",
                accessibilityIdentifier: "delivery-goal-filter"
            )
            .frame(minWidth: 280, idealWidth: 520, maxWidth: 620)
            .frame(height: 42)
        }
        .accessibilityHint("Filter cards without changing their lanes or persisted state.")
    }

    private var phasePickerOptions: [ByteStablePickerOption<ProjectPhaseProjection>] {
        ByteStablePickerOption.disambiguating(board.project.phases.map { phase in
            (label: "\(phase.name) · \(phase.id.rawValue)", byteIdentity: phase.id.rawValue, value: phase)
        })
    }

    private var goalPickerOptions: [ByteStablePickerOption<DeliveryGoalFilter>] {
        var candidates: [(label: String, byteIdentity: String, value: DeliveryGoalFilter)] = [
            (label: "All goals", byteIdentity: "reserved:all", value: .all)
        ]
        candidates += board.filterableDeliveryGoals.map { goal in
            (label: "\(goal.title) · \(goal.goalID.rawValue)", byteIdentity: goal.goalID.rawValue, value: .goal(goal.goalID))
        }
        if filter == .unassigned {
            candidates.append((label: "Unassigned", byteIdentity: "reserved:unassigned", value: .unassigned))
        }
        if case let .goal(id) = filter,
           !board.filterableDeliveryGoals.contains(where: {
               hasSameUTF8Identity($0.goalID.rawValue, id.rawValue)
           }) {
            candidates.append((
                label: "Unavailable Delivery Goal · \(id.rawValue)",
                byteIdentity: id.rawValue,
                value: .goal(id)
            ))
        }
        return ByteStablePickerOption.disambiguating(candidates)
    }

    private func unavailableGoalOption(for filter: DeliveryGoalFilter) -> String {
        switch filter {
        case .all:
            return "All goals"
        case .unassigned:
            return "Unassigned"
        case let .goal(id):
            return "Unavailable Delivery Goal · \(id.rawValue)"
        }
    }

    private var unassignedFilter: some View {
        RekonCheckbox(
            isOn: Binding(get: { filter == .unassigned }, set: { filter = $0 ? .unassigned : .all }),
            title: "Show unassigned",
            accessibilityLabel: "Show unassigned",
            accessibilityIdentifier: "delivery-goal-unassigned"
        )
            .frame(width: 220, height: 42, alignment: .leading)
            .accessibilityHint("Show upcoming tickets without a Delivery Goal. Accepted history is excluded.")
    }
}

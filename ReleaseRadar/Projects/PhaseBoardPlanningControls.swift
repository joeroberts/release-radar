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

struct PhaseBoardPlanningControls: View {
    let board: PhaseBoardProjection
    @Binding var filter: DeliveryGoalFilter
    let phaseSelectionStatus: ActivePhaseSelectionStatus
    let viewPhase: (PhaseID) -> Void
    let makeActive: (PhaseID) async -> Void
    let reload: () async -> Void
    let reauthorize: (URL) async -> Void

    private var planSummary: String {
        let plan = board.phasePlan
        if plan.isDeliveryComplete {
            return "Ready · delivery complete · revision \(plan.revision) · 0 upcoming · 0 unassigned"
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
                    get: { phaseOption(for: board.project.phases.first(where: { $0.id == board.phaseID })) },
                    set: { selection in
                        guard let phase = board.project.phases.first(where: { phaseOption(for: $0) == selection }) else { return }
                        viewPhase(phase.id)
                    }
                ),
                options: board.project.phases.map(phaseOption(for:)),
                accessibilityLabel: "Viewed phase",
                accessibilityIdentifier: "viewed-phase-selector"
            )
            .frame(minWidth: 280, idealWidth: 520, maxWidth: 620)
            .frame(height: 42)
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
                    get: { goalOption(for: filter) },
                    set: { selection in
                        if selection == "All goals" {
                            filter = .all
                        } else if selection == "Unassigned" {
                            filter = .unassigned
                        } else if let goal = board.filterableDeliveryGoals.first(where: { goalOption(for: .goal($0.goalID)) == selection }) {
                            filter = .goal(goal.goalID)
                        }
                    }
                ),
                options: goalOptions,
                accessibilityLabel: "Delivery Goal",
                accessibilityIdentifier: "delivery-goal-filter"
            )
            .frame(minWidth: 280, idealWidth: 520, maxWidth: 620)
            .frame(height: 42)
        }
        .accessibilityHint("Filter cards without changing their lanes or persisted state.")
    }

    private var goalOptions: [String] {
        var options = ["All goals"] + board.filterableDeliveryGoals.map { goalOption(for: .goal($0.goalID)) }
        if filter == .unassigned {
            options.append("Unassigned")
        }
        if case let .goal(id) = filter,
           !board.filterableDeliveryGoals.contains(where: { $0.goalID == id }) {
            options.append("Unavailable Delivery Goal · \(id.rawValue)")
        }
        return options
    }

    private func phaseOption(for phase: ProjectPhaseProjection?) -> String {
        if let phase {
            return "\(phase.name) · \(phase.id.rawValue)"
        }
        return "\(board.phaseName) · \(board.phaseID.rawValue)"
    }

    private func goalOption(for filter: DeliveryGoalFilter) -> String {
        switch filter {
        case .all:
            return "All goals"
        case .unassigned:
            return "Unassigned"
        case let .goal(id):
            if let goal = board.filterableDeliveryGoals.first(where: { $0.goalID == id }) {
                return "\(goal.title) · \(goal.goalID.rawValue)"
            }
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

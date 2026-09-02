import ReleaseRadarCore
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
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("phase-plan-summary")
                .focusable()
            if board.phasePlan.state != .ready {
                Label("Backlog and Blocked work cannot start until coverage is finalized.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { goalPicker; unassignedFilter }
                VStack(alignment: .leading, spacing: 8) { goalPicker; unassignedFilter }
            }
            if board.filterableDeliveryGoals.isEmpty {
                Text("No Delivery Goals recorded · \(board.phasePlan.unassignedUpcomingCount) unassigned upcoming tickets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var phasePicker: some View {
        Picker("Viewed phase", selection: Binding(
            get: { Data(board.phaseID.rawValue.utf8) },
            set: { viewPhase(PhaseID(rawValue: String(decoding: $0, as: UTF8.self))) }
        )) {
            ForEach(board.project.phases, id: \.byteIdentity) { phase in
                Text("\(phase.name) · \(phase.id.rawValue)").tag(phase.byteIdentity)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .accessibilityIdentifier("viewed-phase-selector")
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
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("board-active-phase")
        }
    }

    private var goalPicker: some View {
        Picker("Delivery Goal", selection: $filter) {
            Text("All goals").tag(DeliveryGoalFilter.all)
            ForEach(board.filterableDeliveryGoals) { goal in
                Text("\(goal.title) · \(goal.goalID.rawValue)").tag(DeliveryGoalFilter.goal(goal.goalID))
            }
            if filter == .unassigned { Text("Unassigned").tag(DeliveryGoalFilter.unassigned) }
            if case let .goal(id) = filter,
               !board.filterableDeliveryGoals.contains(where: { $0.id == Data(id.rawValue.utf8) }) {
                Text("Unavailable Delivery Goal · \(id.rawValue)").tag(filter)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .accessibilityIdentifier("delivery-goal-filter")
        .accessibilityHint("Filter cards without changing their lanes or persisted state.")
    }

    private var unassignedFilter: some View {
        Toggle("Show unassigned", isOn: Binding(get: { filter == .unassigned },
            set: { filter = $0 ? .unassigned : .all }))
            .toggleStyle(.checkbox)
            .accessibilityIdentifier("delivery-goal-unassigned")
            .accessibilityHint("Show upcoming tickets without a Delivery Goal. Accepted history is excluded.")
    }
}

private extension ProjectPhaseProjection {
    var byteIdentity: Data { Data(id.rawValue.utf8) }
}

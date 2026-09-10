import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

extension PhaseLifecycleAction {
    var displayName: String {
        switch self {
        case .moveToUpcoming: "Move to Upcoming"
        case .beginDelivery: "Begin delivery"
        case .complete: "Complete phase"
        case .reopenInDelivery: "Reopen in delivery"
        case .reopenUpcoming: "Reopen as Upcoming"
        }
    }
}

struct PhaseLifecycleControls: View {
    let phase: ProjectPlanPhaseProjection
    let transition: (PhaseLifecycleAction, String?, String) async -> AgentCommandResult
    let reload: () async -> Void

    @State private var selectedAction: PhaseLifecycleAction
    @State private var reason = ""
    @State private var failure: FailureStatePresentation?
    @State private var committedStatus: String?
    @State private var isPerforming = false
    @FocusState private var reasonFocused: Bool
    @AccessibilityFocusState private var reasonAccessibilityFocused: Bool

    init(
        phase: ProjectPlanPhaseProjection,
        transition: @escaping (PhaseLifecycleAction, String?, String) async -> AgentCommandResult,
        reload: @escaping () async -> Void
    ) {
        self.phase = phase
        self.transition = transition
        self.reload = reload
        _selectedAction = State(initialValue: Self.defaultAction(for: phase.lifecycle.lifecycle))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 14) { stateSummary; intendedSummary }
                VStack(alignment: .leading, spacing: 4) { stateSummary; intendedSummary }
            }

            RekonPicker(
                selection: Binding(
                    get: { selectedAction.displayName },
                    set: { label in
                        guard let action = availableActions.first(where: { $0.displayName == label }) else { return }
                        selectedAction = action
                        failure = nil
                        committedStatus = nil
                    }
                ),
                options: availableActions.map(\.displayName),
                accessibilityLabel: "Lifecycle action for \(phase.name)",
                accessibilityIdentifier: "phase-lifecycle-action-\(phase.id.rawValue)"
            )
            .frame(maxWidth: 420)
            .frame(height: 42)

            TextField("Reason for this lifecycle decision", text: $reason)
                .textFieldStyle(.roundedBorder)
                .focused($reasonFocused)
                .accessibilityFocused($reasonAccessibilityFocused)
                .accessibilityIdentifier("phase-lifecycle-reason-\(phase.id.rawValue)")
                .accessibilityHint("Required owner reason recorded in immutable lifecycle history.")

            if selectedAction == .complete {
                completionEligibility
            }
            if phase.lifecycle.lifecycle == .completed {
                Text("Completed delivery work is read-only. Reopen this phase or create a new phase before adding or revising work.")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("phase-completed-read-only-\(phase.id.rawValue)")
            }
            if let failure {
                FailureStateView(presentation: failure, style: .inline)
            }
            if let committedStatus {
                Label(committedStatus, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.success)
                    .accessibilityIdentifier("phase-lifecycle-committed-\(phase.id.rawValue)")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actionButton; reloadButton }
                VStack(alignment: .leading, spacing: 8) { actionButton; reloadButton }
            }
        }
        .padding(12)
        .background(RekonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("phase-lifecycle-controls-\(phase.id.rawValue)")
        .onChange(of: phase.lifecycle.revision) { _, newRevision in
            selectedAction = Self.defaultAction(for: phase.lifecycle.lifecycle)
            failure = nil
            if committedStatus != nil {
                committedStatus = "Lifecycle saved at revision \(newRevision)."
            }
            reason = ""
        }
    }

    private var stateSummary: some View {
        Text("Exact phase: \(phase.name) · \(phase.id.rawValue)")
            .font(.caption.weight(.medium))
            .foregroundStyle(RekonTheme.primaryText)
            .accessibilityIdentifier("phase-lifecycle-exact-phase-\(phase.id.rawValue)")
    }

    private var intendedSummary: some View {
        Text("Current: \(phase.lifecycle.lifecycle.displayName) · Intended: \(selectedAction.intendedLifecycle.displayName)")
            .font(.caption)
            .foregroundStyle(RekonTheme.secondaryText)
            .accessibilityIdentifier("phase-lifecycle-intended-\(phase.id.rawValue)")
    }

    @ViewBuilder
    private var completionEligibility: some View {
        if phase.completionAssessment.blockers.isEmpty {
            Label("Eligible using the current planning and obligation baseline.", systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(RekonTheme.success)
                .accessibilityIdentifier("phase-completion-eligible-\(phase.id.rawValue)")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("Completion is blocked", systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RekonTheme.warning)
                ForEach(phase.completionAssessment.blockers) { blocker in
                    Text("• \(blocker.message)")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier("phase-completion-blockers-\(phase.id.rawValue)")
        }
    }

    private var actionButton: some View {
        Button(selectedAction.displayName) {
            performTransition()
        }
        .buttonStyle(RekonPrimaryButtonStyle())
        .disabled(isPerforming || trimmedReason.isEmpty || completionIsBlocked)
        .accessibilityIdentifier("commit-phase-lifecycle-\(phase.id.rawValue)")
        .accessibilityHint(completionIsBlocked
            ? "Resolve every listed completion blocker before completing the phase."
            : "Records this explicit owner lifecycle decision.")
    }

    private var reloadButton: some View {
        Button("Reload lifecycle") {
            Task { await reload() }
        }
        .buttonStyle(RekonSecondaryButtonStyle())
        .disabled(isPerforming)
        .accessibilityIdentifier("reload-phase-lifecycle-\(phase.id.rawValue)")
    }

    private var completionIsBlocked: Bool {
        selectedAction == .complete && !phase.completionAssessment.blockers.isEmpty
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableActions: [PhaseLifecycleAction] {
        switch phase.lifecycle.lifecycle {
        case .unassessed: [.moveToUpcoming, .beginDelivery, .complete]
        case .upcoming: [.beginDelivery, .complete]
        case .inDelivery: [.moveToUpcoming, .complete]
        case .completed: [.reopenInDelivery, .reopenUpcoming]
        }
    }

    private func performTransition() {
        guard !isPerforming, !trimmedReason.isEmpty, !completionIsBlocked else { return }
        isPerforming = true
        failure = nil
        committedStatus = nil
        let action = selectedAction
        let baseline = action == .complete ? phase.completionAssessment.planningBaselineDigest : nil
        Task { @MainActor in
            let result = await transition(action, baseline, trimmedReason)
            if let error = result.error {
                failure = FailureStatePresentation(agentError: error)
                isPerforming = false
                reasonFocused = true
                reasonAccessibilityFocused = true
                return
            }
            committedStatus = "Lifecycle saved. Reloading persisted state…"
            await reload()
            isPerforming = false
            reasonFocused = true
            reasonAccessibilityFocused = true
        }
    }

    private static func defaultAction(for lifecycle: PhaseLifecycle) -> PhaseLifecycleAction {
        switch lifecycle {
        case .unassessed: .moveToUpcoming
        case .upcoming: .beginDelivery
        case .inDelivery: .moveToUpcoming
        case .completed: .reopenInDelivery
        }
    }
}

import AppKit
import ReleaseRadarCore
import SwiftUI

enum ActivePhaseSelectorSurface: String, Sendable {
    case overview
    case board

    var accessibilityIdentifier: String {
        "active-phase-selector-\(rawValue)"
    }
}

struct ActivePhaseSelectorPresentation: Equatable, Sendable {
    let project: ProjectDashboardProjection
    let status: ActivePhaseSelectionStatus

    var isSaving: Bool {
        if case .saving = status { return true }
        return false
    }

    var isDisabled: Bool {
        if project.phases.isEmpty { return true }
        switch status {
        case .saving, .savedNeedsReload:
            return true
        case .idle, .mutationFailed:
            return project.phases.count == 1 && project.phases.first?.id == project.activePhaseID
        }
    }

    var accessibilityValue: String {
        if isSaving { return "Saving active phase" }
        guard let activePhaseID = project.activePhaseID,
              let phase = project.phases.first(where: { $0.id == activePhaseID }) else {
            return "No active phase"
        }
        return "\(phase.name) (\(phase.id.rawValue))"
    }

    var accessibilityHelp: String {
        if project.phases.count == 1, project.phases.first?.id == project.activePhaseID {
            return "No other phases are available for this project."
        }
        switch status {
        case .saving:
            return "Wait for the active phase change and dashboard refresh to finish."
        case .savedNeedsReload:
            return "The phase was saved. Reload the dashboard before making another selection."
        case .idle, .mutationFailed:
            return "Choose the persisted phase shown on this project's active board."
        }
    }
}

struct ActivePhaseSelector: View {
    let project: ProjectDashboardProjection
    let surface: ActivePhaseSelectorSurface
    let status: ActivePhaseSelectionStatus
    let onSelect: (PhaseID) async -> Void
    let onReload: () async -> Void
    let onReauthorize: (URL) async -> Void

    private var presentation: ActivePhaseSelectorPresentation {
        ActivePhaseSelectorPresentation(project: project, status: status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Active phase", selection: selection) {
                Text("No active phase")
                    .tag(Optional<PhaseID>.none)
                    .disabled(true)
                ForEach(project.phases) { phase in
                    Text(optionLabel(for: phase))
                        .tag(Optional(phase.id))
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .disabled(presentation.isDisabled)
            .accessibilityIdentifier(surface.accessibilityIdentifier)
            .accessibilityValue(presentation.accessibilityValue)
            .accessibilityHint(presentation.accessibilityHelp)

            statusView
        }
    }

    private var selection: Binding<PhaseID?> {
        Binding(
            get: { project.activePhaseID },
            set: { phaseID in
                guard let phaseID, phaseID != project.activePhaseID else { return }
                Task { await onSelect(phaseID) }
            }
        )
    }

    private func optionLabel(for phase: ProjectPhaseProjection) -> String {
        let duplicateName = project.phases.filter {
            $0.name.compare(phase.name, options: .caseInsensitive) == .orderedSame
        }.count > 1
        return duplicateName ? "\(phase.name) · \(phase.id.rawValue)" : phase.name
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            EmptyView()
        case .saving:
            ProgressView("Saving active phase")
                .controlSize(.small)
                .accessibilityIdentifier("active-phase-saving")
        case let .mutationFailed(failure, canReauthorize):
            if canReauthorize {
                FailureStateView(
                    presentation: failure,
                    style: .inline,
                    actionTitle: "Locate / Reauthorize…",
                    action: locateAndReauthorize
                )
            } else {
                FailureStateView(presentation: failure, style: .inline)
            }
        case let .savedNeedsReload(_, phaseName):
            FailureStateView(
                presentation: FailureStatePresentation(
                    title: "Active phase saved; refresh needed",
                    detail: "\(phaseName) was saved as the active phase, but the visible dashboard has not refreshed. Reload the dashboard; do not select the phase again.",
                    systemImage: "arrow.clockwise.circle",
                    tone: .warning,
                    accessibilityID: "active-phase-saved-refresh-needed"
                ),
                style: .inline,
                actionTitle: "Reload dashboard",
                action: { Task { await onReload() } }
            )
        }
    }

    private func locateAndReauthorize() {
        let panel = NSOpenPanel()
        panel.title = "Locate Project Folder"
        panel.prompt = "Reauthorize"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        Task { await onReauthorize(folder) }
    }
}

struct ActivePhaseBoardRecoveryView: View {
    let project: ProjectDashboardProjection
    let status: ActivePhaseSelectionStatus
    let onSelect: (PhaseID) async -> Void
    let onReload: () async -> Void
    let onReauthorize: (URL) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(project.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text("No active phase")
                .font(.title2.weight(.semibold))
            Text("Choose an existing phase to establish this project's active board. No phase or ticket history will be changed.")
                .foregroundStyle(.secondary)
            ActivePhaseSelector(
                project: project,
                surface: .board,
                status: status,
                onSelect: onSelect,
                onReload: onReload,
                onReauthorize: onReauthorize
            )
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("active-phase-board-recovery")
    }
}

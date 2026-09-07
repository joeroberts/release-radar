import AppKit
import ReleaseRadarCore
import RekonDesignSystem
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
            guard project.phases.count == 1, let activePhaseID = project.activePhaseID else { return false }
            return project.phases.first.map {
                hasSameUTF8Identity($0.id.rawValue, activePhaseID.rawValue)
            } == true
        }
    }

    var accessibilityValue: String {
        if isSaving { return "Saving active phase" }
        guard let activePhaseID = project.activePhaseID,
              let phase = project.phases.first(where: {
                  hasSameUTF8Identity($0.id.rawValue, activePhaseID.rawValue)
              }) else {
            return "No active phase"
        }
        return "\(phase.name) (\(phase.id.rawValue))"
    }

    var accessibilityHelp: String {
        if project.phases.count == 1,
           let phaseID = project.phases.first?.id,
           let activePhaseID = project.activePhaseID,
           hasSameUTF8Identity(phaseID.rawValue, activePhaseID.rawValue) {
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
    var phaseToActivate: ProjectPhaseProjection? = nil
    @State private var confirmingActivePhase = false

    private var presentation: ActivePhaseSelectorPresentation {
        ActivePhaseSelectorPresentation(project: project, status: status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let phaseToActivate {
                Button("Make active phase") { confirmingActivePhase = true }
                    .disabled(presentation.isSaving || isWaitingForReload)
                    .accessibilityIdentifier("make-active-phase")
                    .accessibilityHint("Explicitly make \(phaseToActivate.name) the project's active working context.")
                    .confirmationDialog("Make \(phaseToActivate.name) the active phase?", isPresented: $confirmingActivePhase, titleVisibility: .visible) {
                        Button("Make active phase") { Task { await onSelect(phaseToActivate.id) } }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This changes the persisted active phase from \(project.activePhaseName). Ticket lanes and history are unchanged.")
                    }
            } else {
                HStack(spacing: 12) {
                    Text("Active phase")
                        .font(RekonTypography.controlLabel)
                        .foregroundStyle(RekonTheme.primaryText)
                    RekonPicker(
                        selection: selection,
                        options: activePhaseOptions,
                        accessibilityLabel: "Active phase",
                        accessibilityIdentifier: surface.accessibilityIdentifier
                    )
                    .frame(minWidth: 180, idealWidth: 260, maxWidth: 360)
                    .frame(height: 42)
                }
                .disabled(presentation.isDisabled)
                .accessibilityValue(presentation.accessibilityValue)
                .accessibilityHint(presentation.accessibilityHelp)
            }

            statusView
        }
    }

    private var isWaitingForReload: Bool {
        if case .savedNeedsReload = status { return true }
        return false
    }

    private var selection: Binding<String> {
        Binding(
            get: {
                guard let activePhaseID = project.activePhaseID,
                      let option = activePhasePickerOptions.first(where: {
                          hasSameUTF8Identity($0.value.rawValue, activePhaseID.rawValue)
                      }) else {
                    return "No active phase"
                }
                return option.selection
            },
            set: { selection in
                guard !presentation.isDisabled,
                      let option = activePhasePickerOptions.first(where: { $0.selection == selection }),
                      project.activePhaseID.map({
                          !hasSameUTF8Identity(option.value.rawValue, $0.rawValue)
                      }) ?? true else { return }
                Task { await onSelect(option.value) }
            }
        )
    }

    private var activePhaseOptions: [String] {
        let options = activePhasePickerOptions.map(\.selection)
        return project.activePhaseID == nil ? ["No active phase"] + options : options
    }

    private var activePhasePickerOptions: [ByteStablePickerOption<PhaseID>] {
        ByteStablePickerOption.disambiguating(project.phases.map { phase in
            (label: optionLabel(for: phase), byteIdentity: phase.id.rawValue, value: phase.id)
        })
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
                .font(RekonTypography.metadata.weight(.medium))
                .foregroundStyle(RekonTheme.secondaryText)
            Text("No active phase")
                .font(RekonTypography.sectionTitle)
                .foregroundStyle(RekonTheme.primaryText)
            Text("Choose an existing phase to establish this project's active board. No phase or ticket history will be changed.")
                .foregroundStyle(RekonTheme.secondaryText)
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
        .background(RekonTheme.background)
        .accessibilityIdentifier("active-phase-board-recovery")
    }
}

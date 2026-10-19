import Foundation
import RekonDesignSystem
import ReleaseRadarCore
import SwiftUI

/// Read-only data prepared from a fresh, selected-context observation. The
/// producer owns provenance and freshness; this presentation never reads
/// configuration or treats an empty result as an unavailable observation.
struct ProjectExecutionProfileCleanupPreview: Equatable {
    struct ObservationIdentity: Equatable {
        let selectedCodexContextID: UUID
        let configurationVersion: String
        let observedAt: Date
    }

    struct Row: Identifiable, Equatable {
        let profileID: String
        let assignmentID: String?
        let role: String?
        let category: ProjectExecutionProfileCleanupClassification.Category
        let reason: ProjectExecutionProfileCleanupClassification.Reason?
        let configurationBaseline: ProjectExecutionProfileCleanupClassification.ConfigurationBaseline?
        let assignmentBaseline: ProjectExecutionAssignment?
        let evidence: String

        var id: String { profileID }

        init(profileID: String, assignmentID: String?, role: String?,
             category: ProjectExecutionProfileCleanupClassification.Category,
             reason: ProjectExecutionProfileCleanupClassification.Reason?,
             configurationBaseline: ProjectExecutionProfileCleanupClassification.ConfigurationBaseline?,
             assignmentBaseline: ProjectExecutionAssignment? = nil, evidence: String) {
            self.profileID = profileID
            self.assignmentID = assignmentID
            self.role = role
            self.category = category
            self.reason = reason
            self.configurationBaseline = configurationBaseline
            self.assignmentBaseline = assignmentBaseline
            self.evidence = evidence
        }
    }

    let observationIdentity: ObservationIdentity
    let rows: [Row]
}

enum ProjectExecutionProfileCleanupPreviewLoadState: Equatable {
    case idle
    case loading
    case loaded(ProjectExecutionProfileCleanupPreview)
    case empty
    case failed(String)
}

struct ProjectExecutionProfileCleanupPreviewPresentation: Equatable {
    struct Selection: Hashable {
        let profileID: String
        let assignmentID: String
        let configurationBaseline: ProjectExecutionProfileCleanupClassification.ConfigurationBaseline
        let assignmentBaseline: ProjectExecutionAssignment

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.profileID == rhs.profileID
                && lhs.assignmentID == rhs.assignmentID
                && lhs.configurationBaseline == rhs.configurationBaseline
                && lhs.assignmentBaseline == rhs.assignmentBaseline
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(profileID)
            hasher.combine(assignmentID)
            hasher.combine(configurationBaseline.candidateProfileID)
            hasher.combine(configurationBaseline.selectedCodexContextID)
            hasher.combine(configurationBaseline.observedDefinition)
            hasher.combine(String(describing: assignmentBaseline))
        }
    }

    let rows: [ProjectExecutionProfileCleanupPreview.Row]
    let selected: Set<Selection>
    let selectedEligibleRows: [ProjectExecutionProfileCleanupPreview.Row]
    let exclusionRows: [ProjectExecutionProfileCleanupPreview.Row]

    static func make(snapshot: ProjectExecutionProfileCleanupPreview, selection: Set<Selection>) -> Self {
        let retainedSelection = reconciling(selection: selection, with: snapshot)
        let selectedEligibleRows = snapshot.rows.filter { row in
            guard row.category == .cleanupEligible,
                  let assignmentID = row.assignmentID,
                  let configurationBaseline = row.configurationBaseline,
                  let assignmentBaseline = row.assignmentBaseline else { return false }
            return retainedSelection.contains(.init(profileID: row.profileID,
                                                    assignmentID: assignmentID,
                                                    configurationBaseline: configurationBaseline,
                                                    assignmentBaseline: assignmentBaseline))
        }
        return .init(rows: snapshot.rows, selected: retainedSelection,
                     selectedEligibleRows: selectedEligibleRows,
                     exclusionRows: snapshot.rows.filter { $0.category != .cleanupEligible })
    }

    static func reconciling(selection: Set<Selection>, with snapshot: ProjectExecutionProfileCleanupPreview) -> Set<Selection> {
        Set(snapshot.rows.compactMap { row in
            guard row.category == .cleanupEligible,
                  let assignmentID = row.assignmentID,
                  let configurationBaseline = row.configurationBaseline,
                  let assignmentBaseline = row.assignmentBaseline else { return nil }
            let candidate = Selection(profileID: row.profileID, assignmentID: assignmentID,
                                      configurationBaseline: configurationBaseline,
                                      assignmentBaseline: assignmentBaseline)
            return selection.contains(candidate) ? candidate : nil
        })
    }

    static func reselectMessage(previous: Set<Selection>, current: Set<Selection>) -> String? {
        previous.subtracting(current).isEmpty
            ? nil
            : "Profile evidence changed. Re-select eligible profiles before previewing cleanup."
    }
}

struct ExecutionProfileCleanupPreviewView: View {
    let registration: ProjectRegistration
    let loadPreview: () async throws -> ProjectExecutionProfileCleanupPreview

    @State private var loadState: ProjectExecutionProfileCleanupPreviewLoadState = .idle
    @State private var selection: Set<ProjectExecutionProfileCleanupPreviewPresentation.Selection> = []
    @State private var previewPresentation: ProjectExecutionProfileCleanupPreviewPresentation?
    @State private var selectionChangedMessage: String?

    var body: some View {
        RekonSectionPanel {
            VStack(alignment: .leading, spacing: 14) {
                header
                content
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("project-execution-profile-cleanup-preview")
        }
        .task(id: registration) {
            selection = []
            previewPresentation = nil
            selectionChangedMessage = nil
            await refresh()
        }
        .sheet(item: $previewPresentation) { presentation in
            selectedPreview(presentation)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) { heading; Spacer(); refreshButton }
            VStack(alignment: .leading, spacing: 8) { heading; refreshButton }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Generated profile cleanup")
                .font(.headline)
            Text("Review the current profile evidence before any cleanup. This preview does not remove profiles, worktrees, branches, or task records.")
                .font(.subheadline)
                .foregroundStyle(RekonTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var refreshButton: some View {
        Button("Refresh profile evidence") { Task { await refresh() } }
            .buttonStyle(RekonSecondaryButtonStyle())
            .disabled(loadState == .loading)
            .accessibilityIdentifier("project-execution-profile-cleanup-refresh")
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .idle, .loading:
            ProgressView("Reading current profile evidence…")
                .accessibilityIdentifier("project-execution-profile-cleanup-loading")
        case .empty:
            Text("No generated or reserved profiles were found in the selected Codex context.")
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("project-execution-profile-cleanup-empty")
        case let .failed(message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile evidence needs attention")
                    .font(.headline)
                Text(message).fixedSize(horizontal: false, vertical: true)
                Button("Try again") { Task { await refresh() } }
                    .buttonStyle(RekonSecondaryButtonStyle())
            }
            .foregroundStyle(RekonTheme.warning)
            .accessibilityIdentifier("project-execution-profile-cleanup-error")
        case let .loaded(snapshot):
            loadedContent(snapshot)
        }
    }

    private func loadedContent(_ snapshot: ProjectExecutionProfileCleanupPreview) -> some View {
        let presentation = ProjectExecutionProfileCleanupPreviewPresentation.make(snapshot: snapshot, selection: selection)
        let categories: [ProjectExecutionProfileCleanupClassification.Category] = [
            .active, .recoveryRetained, .cleanupEligible, .unknown,
            .alreadyRemoved, .outsideAssignmentCleanup,
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("Observed \(snapshot.observationIdentity.observedAt.formatted(date: .abbreviated, time: .shortened)) · configuration \(snapshot.observationIdentity.configurationVersion)")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
                .textSelection(.enabled)

            ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                let rows = presentation.rows.filter { $0.category == category }
                if !rows.isEmpty {
                    Text(categoryTitle(category))
                        .font(.subheadline.weight(.semibold))
                    ForEach(rows) { row in
                        rowView(row, selected: selection(for: row).map { presentation.selected.contains($0) } ?? false)
                    }
                }
            }

            if !presentation.selectedEligibleRows.isEmpty {
                Button("Preview selected cleanup") {
                    Task {
                        await refresh()
                        guard selectionChangedMessage == nil else { return }
                        if case let .loaded(refreshed) = loadState {
                            let refreshedPresentation = ProjectExecutionProfileCleanupPreviewPresentation.make(snapshot: refreshed, selection: selection)
                            guard !refreshedPresentation.selectedEligibleRows.isEmpty else { return }
                            previewPresentation = refreshedPresentation
                        }
                    }
                }
                .buttonStyle(RekonPrimaryButtonStyle())
                .accessibilityIdentifier("project-execution-profile-cleanup-preview-selected")
            }
            if let selectionChangedMessage {
                Text(selectionChangedMessage)
                    .font(.caption)
                    .foregroundStyle(RekonTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("project-execution-profile-cleanup-selection-changed")
            }
        }
    }

    private func rowView(_ row: ProjectExecutionProfileCleanupPreview.Row, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let candidate = selection(for: row) {
                    Toggle("Select \(row.profileID) for a read-only cleanup preview", isOn: Binding(
                        get: { selected },
                        set: { isSelected in updateSelection(candidate, isSelected: isSelected) }
                    ))
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("project-execution-profile-cleanup-select-\(row.profileID)")
                } else {
                    Label(categoryTitle(row.category), systemImage: "lock.fill")
                        .foregroundStyle(RekonTheme.secondaryText)
                }
            }
            Text(row.profileID).font(.body.monospaced()).textSelection(.enabled)
            if let assignmentID = row.assignmentID {
                Text("Assignment \(assignmentID)\(row.role.map { " · role \($0)" } ?? "")")
                    .font(.caption).foregroundStyle(RekonTheme.secondaryText).textSelection(.enabled)
            }
            if let assignment = row.assignmentBaseline {
                Text("Project \(assignment.registration.projectID.rawValue) · registration \(assignment.registration.registrationID) · generation \(assignment.registration.requestGeneration)")
                    .font(.caption).foregroundStyle(RekonTheme.secondaryText).textSelection(.enabled)
                Text("Worker attempt \(assignment.workerAttemptID?.uuidString ?? "unavailable") · session \(assignment.sessionID ?? "unavailable") · connection \(connectionLabel(assignment.connectionClosed))")
                    .font(.caption).foregroundStyle(RekonTheme.secondaryText).textSelection(.enabled)
                if let worktree = assignment.worktree {
                    Text("Worktree \(worktree.checkout) · root \(worktree.primaryRoot)")
                        .font(.caption.monospaced()).foregroundStyle(RekonTheme.secondaryText)
                        .textSelection(.enabled)
                }
            }
            Text(row.evidence).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if let reason = row.reason {
                Text(reasonText(reason)).font(.caption).foregroundStyle(RekonTheme.warning).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-execution-profile-cleanup-row-\(row.profileID)")
    }

    private func selectedPreview(_ presentation: ProjectExecutionProfileCleanupPreviewPresentation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup preview").font(.title2.weight(.semibold))
            Text("This is a read-only preview. No profile or project data has been changed.")
                .foregroundStyle(RekonTheme.secondaryText)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(presentation.selectedEligibleRows) { row in
                        Text(row.profileID).font(.body.monospaced()).textSelection(.enabled)
                    }
                    if !presentation.exclusionRows.isEmpty {
                        Text("Excluded profiles").font(.headline)
                        ForEach(presentation.exclusionRows) { row in
                            Text("\(row.profileID): \(row.reason.map(reasonText) ?? categoryTitle(row.category))")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxHeight: 420)
            Button("Done") { previewPresentation = nil }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("project-execution-profile-cleanup-sheet-done")
        }
        .padding(24)
        .frame(minWidth: 440)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-execution-profile-cleanup-sheet")
        .onExitCommand { previewPresentation = nil }
    }

    private func refresh() async {
        loadState = .loading
        do {
            let snapshot = try await loadPreview()
            let previousSelection = selection
            selection = ProjectExecutionProfileCleanupPreviewPresentation.reconciling(selection: previousSelection, with: snapshot)
            selectionChangedMessage = ProjectExecutionProfileCleanupPreviewPresentation.reselectMessage(
                previous: previousSelection, current: selection
            )
            loadState = snapshot.rows.isEmpty ? .empty : .loaded(snapshot)
        } catch {
            selectionChangedMessage = nil
            loadState = .failed(error.localizedDescription)
        }
    }

    private func selection(for row: ProjectExecutionProfileCleanupPreview.Row) -> ProjectExecutionProfileCleanupPreviewPresentation.Selection? {
        guard row.category == .cleanupEligible,
              let assignmentID = row.assignmentID,
              let configurationBaseline = row.configurationBaseline,
              let assignmentBaseline = row.assignmentBaseline else { return nil }
        return .init(profileID: row.profileID, assignmentID: assignmentID,
                     configurationBaseline: configurationBaseline, assignmentBaseline: assignmentBaseline)
    }

    private func updateSelection(_ candidate: ProjectExecutionProfileCleanupPreviewPresentation.Selection, isSelected: Bool) {
        if isSelected { selection.insert(candidate) } else { selection.remove(candidate) }
        selectionChangedMessage = nil
    }

    private func connectionLabel(_ value: Bool?) -> String {
        switch value {
        case true: "closed"
        case false: "open"
        case nil: "unknown"
        }
    }

    private func categoryTitle(_ category: ProjectExecutionProfileCleanupClassification.Category) -> String {
        switch category {
        case .active: "Active"
        case .recoveryRetained: "Retained for recovery"
        case .cleanupEligible: "Eligible for cleanup preview"
        case .unknown: "Unknown"
        case .alreadyRemoved: "Already removed"
        case .outsideAssignmentCleanup: "Outside assignment cleanup"
        }
    }

    private func reasonText(_ reason: ProjectExecutionProfileCleanupClassification.Reason) -> String {
        switch reason {
        case .association(.reservedProfile): "This reusable or probe profile is outside assignment cleanup."
        case .association(.profileMissing): "The profile is missing from the current observation."
        case .association(.missingAssignmentDefinition): "No protected assignment definition was found."
        case .association(.missingProvisioningReceipt): "The profile provisioning receipt is unavailable."
        case .association(.configurationUnavailable): "The current configuration observation is unavailable."
        case .association(.definitionMismatch): "The observed definition does not match the protected assignment record."
        case .association(.selectedContextMismatch): "The observed profile belongs to a different Codex context."
        case .association(.duplicateOwnership): "The profile has conflicting assignment claims."
        case .association(.missingWorktreeIdentity): "The protected assignment record has incomplete worktree identity."
        case .association(.legacyWorkerIdentityUnavailable): "Legacy worker identity is insufficient for safe cleanup."
        case .activeAssignment: "The assignment is still active."
        case .pendingApproval: "A current approval is pending."
        case .identityMismatch: "The profile or configuration evidence no longer matches this assignment."
        case .incompleteProvisioning: "Profile provisioning is incomplete."
        case .uncertainOutcome: "The assignment outcome remains uncertain."
        case .finalizationFailed: "Finalization failed and the assignment remains retained."
        case .lostWorkerRecovery: "Lost-worker recovery remains required."
        case .incompleteRetirement: "Resource retirement is incomplete."
        case .profileReappearedAfterRemoval: "A previously removed profile reappeared and needs investigation."
        case .missingTerminalClosure: "Positive terminal worker-closure evidence is missing."
        }
    }
}

extension ProjectExecutionProfileCleanupPreviewPresentation: Identifiable {
    var id: String { selected.map(\.profileID).sorted().joined(separator: "|") }
}

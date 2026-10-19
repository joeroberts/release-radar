import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

struct RepositoryPlanReconstructionView: View {
    @Environment(\.dismiss) private var dismiss

    let presentation: RepositoryPlanReconstructionPresentation?
    let retry: () -> Void
    let setSourceSelected: (String, Bool) -> Void
    let startPreparation: () -> Void
    let refreshPreparation: () -> Void
    let cancelPreparation: () -> Void
    let reconcilePreparation: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch presentation?.stage {
                case nil, .loadingSources:
                    ProgressView("Reading the accepted documentation catalog…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("repository-plan-source-loading")
                case .selectingSources:
                    sourceSelection
                case .starting:
                    ProgressView("Capturing the authorized source snapshot…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("repository-plan-preparation-starting")
                case .failed, .reviewLoadFailed:
                    failure
                case .preparing:
                    preparationStatus
                case .outcomeUnknown:
                    outcomeUnknown
                case .reviewing, .applying, .applied:
                    ProgressView("Loading repository plan review…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(24)
            .frame(minWidth: 540, minHeight: 480)
            .background(RekonTheme.background)
            .navigationTitle("Prepare Project Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("repository-plan-reconstruction")
    }

    private var sourceSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose repository sources")
                .font(RekonTypography.sectionTitle)
            Text("Release Radar will copy only the documents you select into a read-only preparation snapshot. Review lifecycle, authority, and digest before continuing.")
                .foregroundStyle(RekonTheme.secondaryText)
            if let target = presentation?.target {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Send selected contents to")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RekonTheme.secondaryText)
                    Text(target.destinationLabel)
                        .font(.body.weight(.medium))
                    Text("\(target.model) · \(target.effort) reasoning · context \(target.codexContextID.uuidString.lowercased())")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("repository-plan-preparation-target")
            }
            if let message = presentation?.message, !message.isEmpty {
                Text(message)
                    .foregroundStyle(RekonTheme.warning)
            }
            if presentation?.sources.isEmpty == true {
                ContentUnavailableView(
                    "No accepted sources",
                    systemImage: "doc.badge.questionmark",
                    description: Text("Accept a managed documentation catalog with at least one source, then retry.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(presentation?.sources ?? []) { source in
                            sourceRow(source)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Prepare selected sources", action: startPreparation)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .disabled(presentation?.selectedArtifactIDs.isEmpty != false)
                    .accessibilityIdentifier("repository-plan-prepare-selected")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sourceRow(_ source: RepositoryPlanSourceOption) -> some View {
        let selected = presentation?.selectedArtifactIDs.contains(source.artifactID) == true
        return Button {
            setSourceSelected(source.artifactID, !selected)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? RekonTheme.accent : RekonTheme.secondaryText)
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.path)
                        .font(.body.weight(.medium))
                        .foregroundStyle(RekonTheme.primaryText)
                    Text("\(source.lifecycle.rawValue) · \(source.authority.rawValue)")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                    Text(source.contentSHA256)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? RekonTheme.accent : RekonTheme.border)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("repository-plan-source-\(source.artifactID)")
        .accessibilityLabel("\(source.path), \(source.lifecycle.rawValue), \(source.authority.rawValue)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var failure: some View {
        ContentUnavailableView {
            Label("Repository sources unavailable", systemImage: "doc.badge.ellipsis")
        } description: {
            Text(presentation?.message ?? "Release Radar could not read the accepted repository sources.")
        } actions: {
            Button("Retry", action: retry)
                .accessibilityIdentifier("repository-plan-source-retry")
        }
    }

    private var preparationStatus: some View {
        let state = presentation?.preparation?.state
        return VStack(alignment: .leading, spacing: 16) {
            Label(preparationTitle(state), systemImage: preparationImage(state))
                .font(RekonTypography.sectionTitle)
            Text(preparationDetail(state))
                .foregroundStyle(RekonTheme.secondaryText)
            if let message = presentation?.message, !message.isEmpty {
                Text(message)
                    .foregroundStyle(RekonTheme.warning)
            }
            HStack {
                if state == .queued || state == .running || state == .awaitingResolution {
                    Button("Cancel preparation", action: cancelPreparation)
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("repository-plan-prepare-cancel")
                }
                Spacer()
                if state == .failed || state == .cancelled {
                    Button("Prepare again", action: startPreparation)
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("repository-plan-prepare-again")
                } else if state != .readyForReview {
                    Button("Refresh status", action: refreshPreparation)
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("repository-plan-prepare-refresh")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("repository-plan-preparation-status")
    }

    private var outcomeUnknown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Preparation outcome unknown", systemImage: "questionmark.diamond")
                .font(RekonTypography.sectionTitle)
            Text("Release Radar will not start another preparation. Reconcile the recorded attempt before continuing.")
                .foregroundStyle(RekonTheme.secondaryText)
            if let message = presentation?.message, !message.isEmpty {
                Text(message).foregroundStyle(RekonTheme.warning)
            }
            Button("End uncertain attempt and reconcile", action: reconcilePreparation)
                .buttonStyle(RekonPrimaryButtonStyle())
                .accessibilityIdentifier("repository-plan-prepare-reconcile")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("repository-plan-preparation-unknown")
    }

    private func preparationTitle(_ state: RepositoryPlanPreparationState?) -> String {
        switch state {
        case .queued: "Preparation queued"
        case .running: "Preparing project plan"
        case .awaitingResolution: "Preparation needs resolution"
        case .readyForReview: "Prepared plan ready for review"
        case .failed: "Preparation failed"
        case .cancelled: "Preparation cancelled"
        case .outcomeUnknown: "Preparation outcome unknown"
        case nil: "Preparation status unavailable"
        }
    }

    private func preparationImage(_ state: RepositoryPlanPreparationState?) -> String {
        switch state {
        case .readyForReview: "checkmark.circle"
        case .failed: "xmark.octagon"
        case .cancelled: "stop.circle"
        case .outcomeUnknown: "questionmark.diamond"
        case .queued, .running, .awaitingResolution, nil: "doc.badge.clock"
        }
    }

    private func preparationDetail(_ state: RepositoryPlanPreparationState?) -> String {
        switch state {
        case .queued: "The exact source snapshot is recorded and waiting for the selected Codex context."
        case .running: "The isolated read-only preparation is producing a proposed plan."
        case .awaitingResolution: "Resolve the recorded preparation condition before review can continue."
        case .readyForReview: "Review every proposed phase, ticket, dependency, task, source reference, and comparison before deciding."
        case .failed: "No plan change was applied. You may start a fresh attempt from the selected sources."
        case .cancelled: "The attempt ended without applying a plan change. You may start a fresh attempt."
        case .outcomeUnknown: "Do not start another attempt until this exact identity is reconciled."
        case nil: "Refresh the recorded attempt before continuing."
        }
    }
}

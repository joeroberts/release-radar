import SwiftUI
import ReleaseRadarCore

struct ProjectOverviewView: View {
    let project: ProjectDashboardProjection
    let board: PhaseBoardProjection?
    let documentationState: ProjectDocumentationState
    let projectRoot: URL?
    let phaseSelectionStatus: ActivePhaseSelectionStatus
    let openBoard: () -> Void
    let selectActivePhase: (PhaseID) async -> Void
    let reloadActivePhase: () async -> Void
    let reauthorizeActivePhase: (URL) async -> Void
    var repositoryRecovery: RepositoryRecoveryModel? = nil
    var onRepositoryRelocated: () async -> Void = {}
    @State private var promptCopyResult: CodexPromptCopyResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.name)
                        .font(.largeTitle.weight(.semibold))
                    Text("Project overview")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    summaryCard("Active phase", value: project.activePhaseName, systemImage: "flag")
                    summaryCard("Current work", value: "\(project.currentWorkCount)", systemImage: "rectangle.stack")
                    summaryCard("Owner attention", value: "\(project.attentionCount)", systemImage: "person.crop.circle.badge.exclamationmark")
                }

                ProjectGoalSummaryView(context: project.goalContext)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))

                if project.phases.isEmpty {
                    FailureStateView(presentation: .firstPhaseRequired, style: .inline)
                }
                guidanceCard
                if let repositoryRecovery {
                    RepositoryRecoveryView(model: repositoryRecovery, onCommitted: onRepositoryRelocated)
                }
                if !project.evidence.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Project evidence").font(.headline)
                        ForEach(project.evidence) { EvidenceDetailView(evidence: $0) }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 14) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 16) {
                            deliveryHeading
                            Spacer()
                            phaseControls
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            deliveryHeading
                            phaseControls
                        }
                    }

                    if let board {
                        HStack(spacing: 10) {
                            ForEach(board.lanes) { lane in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(lane.lane.dashboardTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(lane.count)")
                                        .font(.title2.weight(.medium))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(lane.lane.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    } else {
                        Text("Choose an existing active phase to load its five-lane board. The persisted phase and ticket history remains unchanged.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var deliveryHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(project.activePhaseName)
                .font(.title2.weight(.semibold))
            Text("Delivery state is derived from persisted lane membership.")
                .foregroundStyle(.secondary)
        }
    }

    private var phaseControls: some View {
        HStack(alignment: .top, spacing: 12) {
            ActivePhaseSelector(
                project: project,
                surface: .overview,
                status: phaseSelectionStatus,
                onSelect: selectActivePhase,
                onReload: reloadActivePhase,
                onReauthorize: reauthorizeActivePhase
            )
            if board != nil {
                Button("Open phase board", action: openBoard)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("open-phase-board")
            }
        }
    }

    private var guidanceCard: some View {
        let presentation = ProjectGuidancePresentation(documentationState: documentationState)
        return VStack(alignment: .leading, spacing: 8) {
            Label(presentation.status, systemImage: presentation.systemImage)
                .font(.headline)
            Text(presentation.detail)
                .foregroundStyle(.secondary)
            if let actionTitle = presentation.actionTitle, let projectRoot {
                Text(projectRoot.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("project-guidance-authorized-root")
                Button(actionTitle) {
                    promptCopyResult = CodexPromptHandoff.copy(
                        prompt: CodexPromptHandoff.prompt(for: documentationState.guidanceState, projectRoot: projectRoot),
                        using: CodexPromptHandoff.writeToGeneralPasteboard
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("project-guidance-copy-prompt")
            }
            if let promptCopyResult {
                Text(promptCopyResult.announcement)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(promptCopyResult == .copied ? .green : .red)
                    .accessibilityIdentifier("project-guidance-copy-result")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("project-guidance-status")
    }

    private func summaryCard(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ProjectGuidancePresentation: Equatable, Sendable {
    let status: String
    let detail: String
    let systemImage: String
    let actionTitle: String?

    init(documentationState: ProjectDocumentationState) {
        guard case let .stagedCatalog(audited, preview) = documentationState else {
            let legacy = Self(state: documentationState.guidanceState)
            status = legacy.status
            detail = legacy.detail
            systemImage = legacy.systemImage
            actionTitle = legacy.actionTitle
            return
        }
        let version = RepositoryDocumentContract.legacyGuidanceVersion
        let guidance = audited ? "Guidance v\(version) remains current." : "Guidance v\(version) still needs its audited handoff. Use the repair prompt to complete it."
        switch preview {
        case let .valid(version, _):
            status = "Release Radar catalog staged · v\(version)"
            detail = "\(guidance) The catalog passed read-only validation. Import, evidence, and delivery state are unchanged."
            systemImage = "doc.text.magnifyingglass"
        case let .invalid(error):
            status = "Release Radar staged catalog needs repair"
            detail = "\(guidance) \(error.localizedDescription) Import, evidence, and delivery state are unchanged."
            systemImage = "exclamationmark.triangle"
        }
        actionTitle = audited ? nil : "Copy repair prompt"
    }

    init(state: ProjectGuidanceState) {
        switch state {
        case let .current(version):
            status = "Release Radar guidance current · v\(version)"
            detail = "This repository has the guidance version shipped with Release Radar."
            systemImage = "checkmark.circle"
            actionTitle = nil
        case let .handoffIncomplete(version):
            status = "Release Radar guidance handoff incomplete · v\(version)"
            detail = "The guidance block is present, but Release Radar has no audited handoff evidence. Use Codex to complete the handoff without changing delivery state."
            systemImage = "exclamationmark.arrow.triangle.2.circlepath"
            actionTitle = "Copy repair prompt"
        case .missing:
            status = "Release Radar guidance not installed"
            detail = "Use the owner-authorized Codex handoff to add Release Radar guidance without replacing existing repository instructions."
            systemImage = "doc.badge.plus"
            actionTitle = "Copy setup prompt"
        case let .outdated(installed, current):
            status = "Release Radar guidance update required · v\(installed) → v\(current)"
            detail = "Use Codex to replace only the managed Release Radar block and preserve every other repository instruction."
            systemImage = "arrow.triangle.2.circlepath"
            actionTitle = "Copy update prompt"
        case .needsRepair:
            status = "Release Radar guidance needs repair"
            detail = "The managed Release Radar guidance block is incomplete or modified. Use Codex to repair only that block."
            systemImage = "wrench.and.screwdriver"
            actionTitle = "Copy repair prompt"
        case .unavailable:
            status = "Release Radar guidance unavailable"
            detail = "Release Radar could not read this repository's guidance. Restore folder access and reload the project."
            systemImage = "folder.badge.questionmark"
            actionTitle = nil
        }
    }
}

extension TicketLane {
    var tint: Color {
        switch self {
        case .backlog: .secondary
        case .inProgress: .cyan
        case .needsReview: .orange
        case .blocked: .red
        case .accepted: .green
        }
    }
}

import SwiftUI
import RekonDesignSystem

struct WorkspaceHelpTopic: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let keywords: String
    let actionTitle: String
    let destination: WorkspaceHelpDestination?
}

enum WorkspaceHelpDestination: Equatable, Sendable {
    case projects
    case settings
    case search
    case projectOverview
    case projectPlan
    case phaseBoard
    case history
    case goals
}

enum WorkspaceHelpContent {
    static let historyProvenance = "Audit, review, completion, observation, and notification records keep their own provenance. Observation rows are latest persisted snapshots, not an invented timeline."
    static let deliveryEvidenceBoundary = "Recorded evidence is not live evidence. Applicability follows the exact recorded target identity, and evidence remains separate from owner acceptance. Reading or recording evidence does not change tasks, lanes, phase lifecycle, or owner acceptance."

    static let topics: [WorkspaceHelpTopic] = [
        .init(
            id: "setup-handoff",
            title: "Set up a project and hand off documentation",
            detail: "Attach the repository folder, review its identity, then finish the generated documentation handoff. Release Radar keeps setup pending until the required managed guidance and catalog are verified.",
            keywords: "setup onboarding documentation handoff catalog guidance attach folder",
            actionTitle: "Open Projects",
            destination: .projects
        ),
        .init(
            id: "recovery",
            title: "Recover folder access and application data",
            detail: "Use the project recovery controls when a bookmark is stale or a repository moved. Full restore rotates project authority, so commands and saved searches must be deliberately reauthorized afterward.",
            keywords: "recovery restore backup folder access bookmark authorization",
            actionTitle: "Open Settings",
            destination: .settings
        ),
        .init(
            id: "plugin-helper-restart",
            title: "Restart the Codex lifecycle helper",
            detail: "In Settings > Connections, use Restart helper when plugin status looks stale after replacing Release Radar. The action re-registers the helper and refreshes status; it does not reinstall or remove the plugin, Codex configuration stays intact, and projects remain unchanged. If macOS requests permission, allow the Release Radar helper in Login Items and retry. If it still fails, update or reinstall Release Radar before retrying.",
            keywords: "plugin helper restart re-register stale status Login Items permission Codex",
            actionTitle: "Open Settings",
            destination: .settings
        ),
        .init(
            id: "active-viewed",
            title: "Active phase versus viewed phase",
            detail: "The active phase is shared delivery state. Choosing a phase to inspect changes only your view until you explicitly use the active-phase control.",
            keywords: "active viewed phase shared state filter",
            actionTitle: "Open Phase Board",
            destination: .phaseBoard
        ),
        .init(
            id: "navigation-validation",
            title: "Navigate while documentation is checked",
            detail: "When you choose Overview, Project Plan, or Phase Board, the destination opens immediately. An animated checking status remains visible while Release Radar validates current project documentation, and verified-evidence actions remain unavailable until the current check finishes. If the dashboard-open audit fails, the selected page stays visible with a reload action.",
            keywords: "navigation checking spinner progress documentation validation overview project plan phase board",
            actionTitle: "Open Overview",
            destination: .projectOverview
        ),
        .init(
            id: "planning-unplaced",
            title: "Planning and unplaced work",
            detail: "Project Plan shows delivery structure and unplaced tickets. A ticket is not active delivery work until it is placed in a phase and lane through an approved change.",
            keywords: "planning unplaced backlog project plan ticket",
            actionTitle: "Open Project Plan",
            destination: .projectPlan
        ),
        .init(
            id: "task-adoption",
            title: "Adopt generic agent tasks",
            detail: "\(TaskAdoptionHelpContent.introduction) \(TaskAdoptionHelpContent.classifications) \(TaskAdoptionHelpContent.evidence) \(TaskAdoptionHelpContent.recovery)",
            keywords: "task adoption generic agent atomic non-atomic receipt evidence",
            actionTitle: "Open Project Plan",
            destination: .projectPlan
        ),
        .init(
            id: "proposal-approval",
            title: "Proposal approval versus apply",
            detail: "Approval records the owner decision for an exact proposal version and baseline. Apply is a separate audited action; approval alone never mutates the delivery plan.",
            keywords: "proposal approval approve apply plan change baseline",
            actionTitle: "Open Project Plan",
            destination: .projectPlan
        ),
        .init(
            id: "readiness-acceptance",
            title: "Readiness versus acceptance",
            detail: "Readiness is computed from recorded planning and delivery evidence. Acceptance is an explicit owner decision and remains separate from checks passing or a phase being ready. \(deliveryEvidenceBoundary)",
            keywords: "readiness acceptance delivery evidence applicability owner decision goals phase",
            actionTitle: "Open Goals",
            destination: .goals
        ),
        .init(
            id: "saved-query-recovery",
            title: "Recover a saved query after restore",
            detail: "Saved filters remain visible after recovery, but Release Radar will not silently substitute new project registrations. Rechoose the exact current project scope, run the query, and resave it under the new authority. If the working search was created by a newer version, use Reset to a new search or open a supported saved query; Search will not interpret or overwrite the opaque filters before that explicit choice.",
            keywords: "saved query recovery restore authorization registration scope filters newer version reset working search",
            actionTitle: "Open Search",
            destination: .search
        ),
        .init(
            id: "search-navigation",
            title: "Navigate exact search results",
            detail: "Search uses recorded identities rather than names. Back and Forward restore the query, filters, selected result, scroll position and focus; archived or removed destinations open their safe read-only recovery surface. \(historyProvenance)",
            keywords: "search navigation exact identity back forward archived removed history source provenance retained observations",
            actionTitle: "Open History",
            destination: .history
        ),
    ]

    static func filtered(by query: String) -> [WorkspaceHelpTopic] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return topics }
        let terms = needle.split(whereSeparator: \Character.isWhitespace).map(String.init)
        return topics.filter { topic in
            let haystack = "\(topic.title) \(topic.detail) \(topic.keywords)"
            return terms.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
        }
    }
}

struct WorkspaceHelpView: View {
    let open: (WorkspaceHelpDestination) -> Void
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Help")
                        .font(RekonTypography.screenTitle)
                    Text("Find the safe next step without leaving your delivery context.")
                        .font(RekonTypography.body)
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                Spacer()
            }

            TextField("Search help", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("help-search-field")

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(WorkspaceHelpContent.filtered(by: query)) { topic in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(topic.title)
                                .font(RekonTypography.compactTitle)
                            Text(topic.detail)
                                .font(RekonTypography.body)
                                .foregroundStyle(RekonTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if let destination = topic.destination {
                                Button(topic.actionTitle) { open(destination) }
                                    .buttonStyle(RekonSecondaryButtonStyle())
                                    .accessibilityIdentifier("help-action-\(topic.id)")
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if WorkspaceHelpContent.filtered(by: query).isEmpty {
                        ContentUnavailableView.search(text: query)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    }
                }
            }
        }
        .padding(24)
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace-help")
    }
}

import Foundation
import Observation
import ReleaseRadarCore

@MainActor
@Observable
final class AppModel {
    var selection: AppRoute = .projects {
        didSet {
            if let projectID = selection.projectID {
                selectedProjectID = projectID
            }
        }
    }
    var isSidebarCompact = false
    var dashboard: DashboardProjection?
    var selectedTicketID = TicketID(rawValue: "VD2-08")
    var dashboardError: String?
    var codexSnapshot = CodexSnapshot.unavailable(reason: UnavailableCodexObserver.defaultReason)
    var selectedReviewItemID: ReviewItemID?
    var reviewActionError: String?
    var isPerformingReviewAction = false

    private let store: DeliveryStore
    private let codexObserver: any CodexObserver
    private(set) var selectedProjectID: ProjectID?
    private var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
    private var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
    private var projectActivities: [ProjectID: ProjectActivityProjection] = [:]

    init(
        store: DeliveryStore = DeliveryStore(),
        codexObserver: any CodexObserver = UnavailableCodexObserver()
    ) {
        self.store = store
        self.codexObserver = codexObserver
    }

    var currentProjectID: ProjectID {
        selection.projectID
            ?? selectedProjectID
            ?? dashboard?.projects.first?.id
            ?? DashboardSampleData.projectID
    }

    var currentProject: ProjectDashboardProjection? {
        dashboard?.projects.first { $0.id == currentProjectID }
    }

    var needsReviewCount: Int {
        reviewInbox(for: currentProjectID)?.openItems.count ?? 0
    }

    var notificationCount: Int {
        dashboard?.board(for: currentProjectID)?.details.values
            .reduce(0) { $0 + $1.notificationHistory.count } ?? 0
    }

    func openProject(_ projectID: ProjectID) {
        selectedProjectID = projectID
        selection = .projectOverview(projectID)
    }

    func loadDashboard() async {
        do {
            try await DashboardSampleData.seedIfNeeded(in: store)
            let loadedDashboard = try await DashboardProjection.load(from: store)
            dashboard = loadedDashboard
            try await loadWorkspace(for: loadedDashboard)
            dashboardError = nil
        } catch {
            dashboardError = error.localizedDescription
        }
    }

    func reviewInbox(for projectID: ProjectID) -> ReviewInboxProjection? {
        reviewInboxes[projectID]
    }

    func dependencyGraph(for projectID: ProjectID) -> DependencyGraphProjection? {
        dependencyGraphs[projectID]
    }

    func activity(for projectID: ProjectID) -> ProjectActivityProjection? {
        projectActivities[projectID]
    }

    func performReviewDecision(_ decision: ReviewDecision, item: ReviewItemProjection) async {
        isPerformingReviewAction = true
        reviewActionError = nil
        defer { isPerformingReviewAction = false }
        do {
            let rootPaths = try await store.read { connection in
                var paths: [String] = []
                var offset: Int64 = 0
                while let path = try connection.scalarText(
                    "SELECT path FROM project_roots WHERE project_id = ? ORDER BY rowid LIMIT 1 OFFSET ?",
                    bindings: [.text(item.projectID.rawValue), .integer(offset)]
                ) {
                    paths.append(path)
                    offset += 1
                }
                return paths
            }
            guard let selectedRootPath = rootPaths.first else {
                reviewActionError = "Review action failed: no authorized project root is available."
                return
            }
            let selectedRoot = URL(fileURLWithPath: selectedRootPath)
            let project = AuthorizedProject(
                projectID: item.projectID,
                canonicalRoot: selectedRoot,
                authorizedRoots: rootPaths.map { URL(fileURLWithPath: $0) }
            )
            let dispatcher = AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
            )
            let command: AgentCommand = switch decision {
            case .resolve: .resolveImportReview(reviewItemID: item.id.rawValue)
            case .dismiss: .dismissImportReview(reviewItemID: item.id.rawValue)
            }
            let verb = decision == .resolve ? "Resolve" : "Dismiss"
            let result = await dispatcher.dispatch(AgentCommandEnvelope(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: UUID(),
                projectRoot: selectedRootPath,
                reason: "\(verb) review \(item.id.rawValue)",
                command: command
            ))
            if let error = result.error {
                reviewActionError = "Review action failed: \(String(describing: error))"
                return
            }
            reviewInboxes[item.projectID] = try await ReviewInboxProjection.load(
                from: store,
                projectID: item.projectID
            )
            projectActivities[item.projectID] = try await ProjectActivityProjection.load(
                from: store,
                projectID: item.projectID
            )
            selectedReviewItemID = reviewInboxes[item.projectID]?.openItems.first?.id
        } catch {
            reviewActionError = "Review action failed: \(error.localizedDescription)"
        }
    }

    private func loadWorkspace(for dashboard: DashboardProjection) async throws {
        for project in dashboard.projects {
            reviewInboxes[project.id] = try await ReviewInboxProjection.load(from: store, projectID: project.id)
            projectActivities[project.id] = try await ProjectActivityProjection.load(from: store, projectID: project.id)
            guard let board = dashboard.board(for: project.id) else { continue }
            let preferredID = board.detail(for: selectedTicketID) == nil
                ? board.lanes.flatMap(\.cards).first?.id
                : selectedTicketID
            guard let preferredID else { continue }
            dependencyGraphs[project.id] = try await DependencyGraphProjection.load(
                from: store,
                projectID: project.id,
                phaseID: board.phaseID,
                selectedTicketID: preferredID
            )
        }
        selectedReviewItemID = reviewInboxes[currentProjectID]?.openItems.first?.id
    }

    func loadCodexRuntime() async {
        do {
            codexSnapshot = try await codexObserver.snapshot()
        } catch {
            codexSnapshot = .unavailable(reason: error.localizedDescription)
        }
    }
}

enum ReviewDecision: Equatable, Sendable {
    case resolve
    case dismiss
}

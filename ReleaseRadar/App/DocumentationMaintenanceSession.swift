import Observation
import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

/// A single explicitly opened existing store, shared by owner readback/recovery
/// and the optional restricted bridge. No normal app services are constructed.
@MainActor
@Observable
final class DocumentationMaintenanceSession {
    struct Project: Identifiable { let id: ProjectID; let name: String }
    let mode: DocumentationMaintenanceMode
    let store: DeliveryStore
    private(set) var projects: [Project] = []
    private(set) var recovery: RepositoryRecoveryModel?
    private(set) var message: String?
    private var bridge: AgentBridgeApplicationHost?
    private let previewLoader: @Sendable (ProjectID, EvidenceID) async -> EvidencePreview
    private let documentationObserver: DocumentationObservationCoordinator
    private let monitoringInterval: Duration
    @ObservationIgnored private var documentationMonitoringTask: Task<Void, Never>?
    var selectedProjectID: ProjectID?
    private(set) var evidenceObservationGeneration: UInt64 = 0
    private(set) var documentationObservationStatus: ProjectDocumentationObservation?

    init(databaseURL: URL, mode: DocumentationMaintenanceMode,
         previewLoader: (@Sendable (ProjectID, EvidenceID) async -> EvidencePreview)? = nil,
         documentationObserver: DocumentationObservationCoordinator? = nil,
         monitoringInterval: Duration = .seconds(1)) throws {
        self.mode = mode
        let openedStore = try mode == .readOnly ? DeliveryStore(existingReadOnlyDatabaseURL: databaseURL)
            : DeliveryStore.documentationMaintenance(databaseURL: databaseURL)
        store = openedStore
        self.previewLoader = previewLoader ?? { projectID, evidenceID in
            await openedStore.previewEvidence(projectID: projectID, evidenceID: evidenceID)
        }
        let onboarding = FolderProjectOnboarding(store: openedStore)
        self.documentationObserver = documentationObserver ?? DocumentationObservationCoordinator { projectID in
            for _ in 0..<2 {
                do {
                    return DocumentationObservationPayload(
                        try await onboarding.inspectProjectDocumentation(projectID: projectID)
                    )
                } catch ProjectDocumentationObservationError.staleContext {
                    continue
                } catch {
                    break
                }
            }
            return .init(
                identity: .init(projectID: projectID, registration: nil, rootID: nil, rootPath: nil, binding: nil),
                checkedAt: Date(),
                documentationState: .legacy(.unavailable),
                evidence: []
            )
        }
        self.monitoringInterval = monitoringInterval
    }
    func load() async {
        evidenceObservationGeneration &+= 1
        let generation = evidenceObservationGeneration
        recovery = nil
        documentationObservationStatus = nil
        do {
            let nextProjects = try await store.read { c in
                var rows: [Project] = [], offset: Int64 = 0
                while let row = try c.row("SELECT id, name FROM projects ORDER BY name, id LIMIT 1 OFFSET ?", bindings: [.integer(offset)]) {
                    guard case let .text(id) = row["id"], case let .text(name) = row["name"] else { throw StoreError.unavailable("Invalid project metadata") }
                    rows.append(.init(id: .init(rawValue: id), name: name)); offset += 1
                }
                return rows
            }
            guard generation == evidenceObservationGeneration else { return }
            projects = nextProjects
            if selectedProjectID == nil { selectedProjectID = projects.first?.id }
            await loadSelectedProject(generation: generation)
        } catch { message = "Documentation maintenance could not read the selected store." }
    }
    func selectProject() async {
        evidenceObservationGeneration &+= 1
        let generation = evidenceObservationGeneration
        recovery = nil
        documentationObservationStatus = nil
        await loadSelectedProject(generation: generation)
    }
    private func loadSelectedProject(generation: UInt64) async {
        guard let selectedProjectID else {
            documentationObserver.retain(projectIDs: [])
            documentationObservationStatus = nil
            return
        }
        documentationObserver.retain(projectIDs: [selectedProjectID])
        guard let observation = await documentationObserver.refresh(
            projectID: selectedProjectID,
            withdrawCurrent: true
        ) else { return }
        let model = RepositoryRecoveryModel(store: store, projectID: selectedProjectID, allowsRelocation: mode == .commands)
        await model.load()
        guard generation == evidenceObservationGeneration,
              selectedProjectID == self.selectedProjectID,
              documentationObserver.status(for: selectedProjectID) == .observed(observation) else { return }
        documentationObservationStatus = observation
        recovery = model
    }
    func startDocumentationMonitoring() {
        guard documentationMonitoringTask == nil else { return }
        documentationMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do { try await Task.sleep(for: self.monitoringInterval) }
                catch { return }
                await self.refreshSelectedProjectObservation()
            }
        }
    }
    func stopDocumentationMonitoring() {
        documentationMonitoringTask?.cancel()
        documentationMonitoringTask = nil
    }
    private func refreshSelectedProjectObservation() async {
        guard selectedProjectID != nil else { return }
        evidenceObservationGeneration &+= 1
        let generation = evidenceObservationGeneration
        documentationObservationStatus = nil
        await loadSelectedProject(generation: generation)
    }
    func connectExistingBridge() async {
        do { bridge = try await AgentBridgeApplicationHost.startDocumentationMaintenance(store: store, mode: mode) }
        catch { message = "Agent bridge unavailable. Owner evidence readback and folder recovery remain available in this window." }
    }
    func disconnect() { bridge?.disconnectCallback(); bridge = nil }
    func previewEvidence(_ evidenceID: EvidenceID, projectID: ProjectID) async -> EvidencePreview {
        let generation = evidenceObservationGeneration
        guard projectID == selectedProjectID,
              recovery?.evidence.contains(where: { $0.id == evidenceID }) == true,
              case let .observed(observation) = documentationObserver.status(for: projectID),
              observation.evidence.contains(where: { $0.evidence.id == evidenceID }) else {
            return .init(identity: .filePath(""), path: nil, status: .rejected, content: nil)
        }
        let preview = await previewLoader(projectID, evidenceID)
        guard generation == evidenceObservationGeneration, projectID == selectedProjectID,
              recovery?.evidence.contains(where: { $0.id == evidenceID }) == true,
              documentationObserver.status(for: projectID) == .observed(observation) else {
            return .init(identity: preview.identity, path: nil, status: .rejected, content: nil)
        }
        return preview
    }
}

struct DocumentationMaintenanceView: View {
    @Bindable var session: DocumentationMaintenanceSession
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Documentation maintenance").font(.largeTitle.weight(.semibold))
                    Text(session.mode == .readOnly ? "Read-only evidence inspection" : "Owner-confirmed repository recovery")
                        .foregroundStyle(.secondary)
                    Picker("Project", selection: $session.selectedProjectID) {
                        ForEach(session.projects) { project in Text(project.name).tag(Optional(project.id)) }
                    }.frame(maxWidth: 420).accessibilityIdentifier("maintenance-project")
                    if let recovery = session.recovery {
                        RepositoryRecoveryView(model: recovery)
                            .id("maintenance-repository-recovery")
                        Text("Evidence").font(.title2.weight(.semibold))
                        if recovery.evidence.isEmpty { Text("No evidence recorded").foregroundStyle(.secondary) }
                        ForEach(recovery.evidence) { row in
                            EvidenceDetailView(
                                evidence: row,
                                documentationStatus: session.documentationObservationStatus.map(
                                    DocumentationObservationStatus.observed
                                ),
                                freshnessGeneration: session.evidenceObservationGeneration,
                                restoreFolderAccess: {
                                    withAnimation {
                                        proxy.scrollTo("maintenance-repository-recovery", anchor: .top)
                                    }
                                },
                                openWorktreeRecovery: {
                                    withAnimation {
                                        proxy.scrollTo("maintenance-repository-recovery", anchor: .top)
                                    }
                                },
                                loadPreview: {
                                    guard let projectID = session.selectedProjectID else {
                                        return .init(identity: row.locator, path: nil, status: .rejected, content: nil)
                                    }
                                    return await session.previewEvidence(row.id, projectID: projectID)
                                }
                            )
                            .id("\(session.selectedProjectID?.rawValue ?? "none")-\(row.id.rawValue)")
                            .padding(.vertical, 6)
                            RekonSeparator()
                        }
                    }
                    if let message = session.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                    Button("Reload readback") { Task { await session.load() } }.accessibilityIdentifier("maintenance-reload")
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            await session.load()
            session.startDocumentationMonitoring()
        }
        .task(id: session.selectedProjectID) { await session.selectProject() }
        .onDisappear { session.stopDocumentationMonitoring() }
    }
}

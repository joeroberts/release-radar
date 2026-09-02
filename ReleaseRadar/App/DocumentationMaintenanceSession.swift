import Observation
import ReleaseRadarCore
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
    var selectedProjectID: ProjectID?

    init(databaseURL: URL, mode: DocumentationMaintenanceMode) throws {
        self.mode = mode
        store = try mode == .readOnly ? DeliveryStore(existingReadOnlyDatabaseURL: databaseURL)
            : DeliveryStore.documentationMaintenance(databaseURL: databaseURL)
    }
    func load() async {
        do {
            projects = try await store.read { c in
                var rows: [Project] = [], offset: Int64 = 0
                while let row = try c.row("SELECT id, name FROM projects ORDER BY name, id LIMIT 1 OFFSET ?", bindings: [.integer(offset)]) {
                    guard case let .text(id) = row["id"], case let .text(name) = row["name"] else { throw StoreError.unavailable("Invalid project metadata") }
                    rows.append(.init(id: .init(rawValue: id), name: name)); offset += 1
                }
                return rows
            }
            if selectedProjectID == nil { selectedProjectID = projects.first?.id }
            await selectProject()
        } catch { message = "Documentation maintenance could not read the selected store." }
    }
    func selectProject() async {
        guard let selectedProjectID else { recovery = nil; return }
        let model = RepositoryRecoveryModel(store: store, projectID: selectedProjectID, allowsRelocation: mode == .commands)
        recovery = model
        await model.load()
    }
    func connectExistingBridge() async {
        do { bridge = try await AgentBridgeApplicationHost.startDocumentationMaintenance(store: store, mode: mode) }
        catch { message = "Agent bridge unavailable. Owner evidence readback and folder recovery remain available in this window." }
    }
    func disconnect() { bridge?.disconnectCallback(); bridge = nil }
}

struct DocumentationMaintenanceView: View {
    @Bindable var session: DocumentationMaintenanceSession
    var body: some View {
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
                    Text("Evidence").font(.title2.weight(.semibold))
                    if recovery.evidence.isEmpty { Text("No evidence recorded").foregroundStyle(.secondary) }
                    ForEach(recovery.evidence) { row in
                        EvidenceDetailView(evidence: row).padding(.vertical, 6)
                        Divider()
                    }
                }
                if let message = session.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                Button("Reload readback") { Task { await session.load() } }.accessibilityIdentifier("maintenance-reload")
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await session.load() }
        .task(id: session.selectedProjectID) { await session.selectProject() }
    }
}

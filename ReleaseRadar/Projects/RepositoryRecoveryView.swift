import AppKit
import Observation
import ReleaseRadarCore
import SwiftUI

@MainActor
@Observable
final class RepositoryRecoveryModel {
    let projectID: ProjectID
    let allowsRelocation: Bool
    private let store: DeliveryStore
    private let service: RepositoryRootRelocation
    private let bookmarkStore: any ProjectBookmarkStoring
    var recoveryTokenText = ""
    private(set) var prepared: PreparedRepositoryRootRelocation?
    private(set) var binding: ProjectDocumentationBinding?
    private(set) var savedRoot: String?
    private(set) var evidence: [EvidenceProjection] = []
    private(set) var isBusy = false
    private(set) var message: String?

    init(store: DeliveryStore, projectID: ProjectID, allowsRelocation: Bool,
         bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) {
        self.store = store; self.projectID = projectID; self.allowsRelocation = allowsRelocation
        self.bookmarkStore = bookmarkStore
        service = RepositoryRootRelocation(store: store, bookmarkStore: bookmarkStore)
    }
    func load() async {
        message = nil
        do {
            let version = await store.schemaVersionForDocumentation
            do { binding = version >= 13 ? try await store.documentationBinding(projectID: projectID) : nil }
            catch {
                binding = nil
                message = "The accepted repository binding is invalid. Managed evidence remains unavailable until the binding is recovered."
            }
            let project = projectID.rawValue
            savedRoot = try await store.read { c in
                let filter = version >= 13 ? " AND (NOT EXISTS (SELECT 1 FROM project_documentation_bindings WHERE project_id = project_roots.project_id) OR id = (SELECT root_id FROM project_documentation_bindings WHERE project_id = project_roots.project_id))" : ""
                return try c.scalarText("SELECT path FROM project_roots WHERE project_id = ?\(filter) ORDER BY rowid LIMIT 1", bindings: [.text(project)])
            }
            evidence = try await store.evidenceReadback(projectID: projectID, bookmarkStore: bookmarkStore).map(EvidenceProjection.init)
        } catch {
            evidence = []; savedRoot = nil; binding = nil
            message = "Repository readback could not be loaded. Reload and check folder authorization."
        }
    }
    func prepare(folder: URL) async {
        guard allowsRelocation else { message = "This maintenance session is read-only."; return }
        guard !isBusy else { return }
        isBusy = true; prepared = nil; message = nil
        defer { isBusy = false }
        do {
            let request = try await service.prepare(projectID: projectID, folder: folder)
            prepared = request
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            recoveryTokenText = String(decoding: try encoder.encode(request.recoveryToken), as: UTF8.self)
        }
        catch { message = error.localizedDescription }
    }
    @discardableResult
    func confirm() async -> Bool {
        guard allowsRelocation else { message = "This maintenance session is read-only."; return false }
        guard !isBusy, let prepared else { return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            _ = try await service.confirm(prepared)
            self.prepared = nil
            await load()
            message = "Repository relocated. Managed evidence identity is preserved."
            return true
        } catch {
            // Retain the exact prepared request for an uncertain outcome/retry.
            message = error.localizedDescription
            return false
        }
    }
    func recoverReceipt() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard recoveryTokenText.utf8.count <= 4096 else { throw RepositoryRootRelocationError.requestIDReused }
            let token = try JSONDecoder().decode(RepositoryRootRelocationRecoveryToken.self, from: Data(recoveryTokenText.utf8))
            guard token.projectID == projectID else { throw RepositoryRootRelocationError.requestIDReused }
            if try await service.recover(token) != nil {
                prepared = nil
                await load()
                message = "The exact relocation committed. The saved repository binding is shown above."
            } else { message = "No committed receipt exists for this token in the selected store. Relocation has not been confirmed by readback." }
        } catch { message = "The recovery token does not match an exact relocation receipt for this project." }
    }
    func cancel() { guard !isBusy else { return }; prepared = nil; message = nil }
}

struct RepositoryRecoveryView: View {
    @Bindable var model: RepositoryRecoveryModel
    var onCommitted: () async -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Repository folder", systemImage: "folder").font(.headline)
            if let root = model.savedRoot { Text(root).font(.caption.monospaced()).textSelection(.enabled) }
            if let binding = model.binding {
                Text("Accepted repository \(binding.repositoryID)").font(.caption).foregroundStyle(.secondary)
                if model.allowsRelocation {
                    Text("If the repository moved, select its new location and confirm the exact accepted catalog.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Select relocated repository…", action: chooseFolder)
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("repository-relocation-select")
                } else {
                    Text("Read-only maintenance. Folder relocation is disabled.").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("No accepted managed repository binding.").font(.subheadline).foregroundStyle(.secondary)
            }
            if let prepared = model.prepared {
                Divider()
                Text("Confirm repository relocation").font(.headline)
                Text("From: \(prepared.oldRoot.path)").font(.caption.monospaced())
                Text("To: \(prepared.selectedRoot.path)").font(.caption.monospaced())
                Text("Repository: \(prepared.repositoryID)").font(.caption)
                Text("Accepted catalog v\(prepared.catalogVersion) · \(prepared.catalogDigest)").font(.caption.monospaced())
                Text("The saved folder authorization will be replaced. Managed evidence IDs and other legacy paths stay unchanged.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Save the recovery token below before confirming if you need to check the result after restarting the app.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Confirm relocation") {
                        Task { if await model.confirm() { await onCommitted() } }
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("repository-relocation-confirm")
                    Button("Cancel") { model.cancel() }.accessibilityIdentifier("repository-relocation-cancel")
                }.disabled(model.isBusy)
            }
            DisclosureGroup("Recover an interrupted confirmation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Retain this token to read the exact confirmation receipt after a restart. It contains no bookmark or folder path.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Saved recovery token", text: $model.recoveryTokenText, axis: .vertical)
                        .font(.caption.monospaced()).lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("repository-relocation-token")
                    Button("Check exact receipt") { Task { await model.recoverReceipt() } }
                        .disabled(model.isBusy || model.recoveryTokenText.isEmpty)
                        .accessibilityIdentifier("repository-relocation-recover")
                }
            }
            if model.isBusy { ProgressView().controlSize(.small).accessibilityLabel("Checking repository relocation") }
            if let message = model.message {
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("repository-relocation-result")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .task { await model.load() }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Relocated Repository"
        panel.prompt = "Check Repository"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        Task { await model.prepare(folder: folder) }
    }
}

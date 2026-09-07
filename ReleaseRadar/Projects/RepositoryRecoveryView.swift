import AppKit
import Observation
import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

@MainActor
@Observable
final class RepositoryRecoveryModel {
    let projectID: ProjectID
    let allowsRelocation: Bool
    private let store: DeliveryStore
    private let rootsService: ProjectRootManagement
    private let service: RepositoryRootRelocation
    private let bookmarkStore: any ProjectBookmarkStoring
    var recoveryTokenText = ""
    private(set) var rootSnapshot: ProjectRootSnapshot?
    private(set) var rootAction: PreparedProjectRootAction?
    private var loadGeneration: UInt64 = 0
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
        rootsService = ProjectRootManagement(store: store, bookmarkStore: bookmarkStore)
    }
    @discardableResult
    func load() async -> Bool {
        loadGeneration &+= 1
        let generation = loadGeneration
        do {
            let version = await store.schemaVersionForDocumentation
            let nextRoots: ProjectRootSnapshot?
            if version >= 15 {
                nextRoots = try await rootsService.snapshot(projectID: projectID)
            } else { nextRoots = nil }
            var nextBinding: ProjectDocumentationBinding?
            var bindingMessage: String?
            do { nextBinding = version >= 13 ? try await store.documentationBinding(projectID: projectID) : nil }
            catch { bindingMessage = "The accepted repository binding is invalid. Managed evidence remains unavailable until the binding is recovered." }
            let project = projectID.rawValue
            let nextRoot = try await store.read { c in
                let filter = version >= 13 ? " AND (NOT EXISTS (SELECT 1 FROM project_documentation_bindings WHERE project_id = project_roots.project_id) OR id = (SELECT root_id FROM project_documentation_bindings WHERE project_id = project_roots.project_id))" : ""
                return try c.scalarText("SELECT path FROM project_roots WHERE project_id = ?\(filter) ORDER BY rowid LIMIT 1", bindings: [.text(project)])
            }
            let nextEvidence = try await store.evidenceReadback(projectID: projectID, bookmarkStore: bookmarkStore).map(EvidenceProjection.init)
            if let nextRoots, try await !rootsService.isCurrent(nextRoots) { throw ProjectRootManagementError.stale }
            guard generation == loadGeneration else { return false }
            if let previous = rootSnapshot, previous.registration != nextRoots?.registration {
                prepared = nil; rootAction = nil; recoveryTokenText = ""
            }
            rootSnapshot = nextRoots; binding = nextBinding; savedRoot = nextRoot; evidence = nextEvidence
            message = bindingMessage
            return bindingMessage == nil
        } catch {
            guard generation == loadGeneration else { return false }
            evidence = []; savedRoot = nil; binding = nil; rootSnapshot = nil
            prepared = nil; rootAction = nil
            message = "Repository readback could not be loaded. Reload and check the saved registration and folder authorization."
            return false
        }
    }

    func prepareRootAction(_ action: ProjectRootAction, folder: URL, expectedPath: String? = nil) async {
        guard expectedPath == nil || expectedPath == folder.path else {
            message = "Select the exact saved worktree: \(expectedPath ?? "")"; return
        }
        guard allowsRelocation, !isBusy, let snapshot = rootSnapshot else { return }
        isBusy = true; prepared = nil; rootAction = nil; message = nil
        defer { isBusy = false }
        do {
            let request = try await rootsService.prepare(action, folder: folder, snapshot: snapshot)
            guard rootSnapshot?.registration == snapshot.registration else { throw ProjectRootManagementError.stale }
            rootAction = request
        } catch { message = error.localizedDescription }
    }

    @discardableResult
    func confirmRootAction() async -> Bool {
        guard allowsRelocation, !isBusy, let request = rootAction else { return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            _ = try await rootsService.confirm(request)
            rootAction = nil
            if await load() {
                message = "\(request.action.title) committed. Saved roots were read back. Repository files and history are unchanged."
            } else { message = "The root action committed, but current readback is unavailable. Reload before relying on the displayed state." }
            return true
        } catch { message = error.localizedDescription; return false }
    }

    func prepare(folder: URL, expectedPath: String? = nil) async {
        guard expectedPath == nil || expectedPath == folder.path else {
            message = "Select the exact worktree chosen for the primary repository: \(expectedPath ?? "")"; return
        }
        guard allowsRelocation else { message = "This maintenance session is read-only."; return }
        guard !isBusy, let snapshot = rootSnapshot else { return }
        isBusy = true; prepared = nil; rootAction = nil; message = nil
        defer { isBusy = false }
        do {
            let request = try await service.prepare(projectID: projectID, folder: folder, expectedRegistration: snapshot.registration)
            guard try await rootsService.isCurrent(snapshot), rootSnapshot?.registration == snapshot.registration else { throw ProjectRootManagementError.stale }
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
            if await load() {
                message = "Repository relocated. Managed evidence identity is preserved."
            } else { message = "Relocation committed, but current readback is unavailable. Reload before relying on the displayed repository." }
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
                if await load() {
                    message = "The exact relocation committed. The saved repository binding is shown above."
                } else { message = "The exact receipt confirms relocation, but current readback is unavailable. Reload to check the saved repository." }
            } else { message = "No committed receipt exists for this token in the selected store. Relocation has not been confirmed by readback." }
        } catch { message = "The recovery token does not match an exact relocation receipt for this project." }
    }
    func cancel() { guard !isBusy else { return }; prepared = nil; rootAction = nil; message = nil }
}

struct RepositoryRecoveryView: View {
    @Bindable var model: RepositoryRecoveryModel
    var onCommitted: () async -> Void = {}

    var body: some View {
        RekonSectionPanel {
            ViewThatFits(in: .horizontal) {
                HStack { heading; Spacer(); reloadButton }
                VStack(alignment: .leading, spacing: 10) { heading; reloadButton }
            }
            Text("Primary repository root").font(.headline)
            Text("The primary folder holds project documentation. Worktrees have separate folder permissions.")
                .font(.caption).foregroundStyle(RekonTheme.secondaryText)
            if let root = model.savedRoot { Text(root).font(.caption.monospaced()).textSelection(.enabled) }
            if let binding = model.binding {
                Text("Accepted repository \(binding.repositoryID)").font(.caption).foregroundStyle(RekonTheme.secondaryText)
                if model.allowsRelocation {
                    Text("If the repository moved, select its new location and confirm the exact accepted catalog.")
                        .font(.subheadline).foregroundStyle(RekonTheme.secondaryText)
                    Button("Select relocated repository…") { chooseFolder() }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("repository-relocation-select")
                } else {
                    Text("Read-only maintenance. Folder relocation is disabled.").font(.caption).foregroundStyle(RekonTheme.secondaryText)
                }
            } else {
                Text("No accepted managed repository binding.").font(.subheadline).foregroundStyle(RekonTheme.secondaryText)
            }
            worktreeRoots
            if let action = model.rootAction {
                RekonSeparator()
                Text("Confirm \(action.action.title.lowercased())").font(.headline)
                Text(action.folder.path).font(.caption.monospaced()).textSelection(.enabled)
                Text(action.action == .revoke
                    ? "Only this worktree’s local root and folder authorization will be removed. Repository files, evidence paths and history remain unchanged."
                    : "Authorize only this worktree. The primary repository and accepted catalog remain unchanged.")
                    .font(.subheadline).foregroundStyle(RekonTheme.secondaryText)
                ViewThatFits(in: .horizontal) {
                    HStack { rootConfirmation; cancelButton }
                    VStack(alignment: .leading) { rootConfirmation; cancelButton }
                }.disabled(model.isBusy)
            }
            if let prepared = model.prepared {
                RekonSeparator()
                Text("Confirm repository relocation").font(.headline)
                Text("From: \(prepared.oldRoot.path)").font(.caption.monospaced())
                Text("To: \(prepared.selectedRoot.path)").font(.caption.monospaced())
                Text("Repository: \(prepared.repositoryID)").font(.caption)
                Text("Accepted catalog v\(prepared.catalogVersion) · \(prepared.catalogDigest)").font(.caption.monospaced())
                Text("This becomes the primary repository root. The previous primary authorization is revoked; other worktree authorizations remain. Repository files, managed evidence IDs and other legacy paths stay unchanged.")
                    .font(.subheadline).foregroundStyle(RekonTheme.secondaryText)
                Text("Save the recovery token below before confirming if you need to check the result after restarting the app.")
                    .font(.caption).foregroundStyle(RekonTheme.secondaryText)
                HStack {
                    Button("Confirm relocation") {
                        Task { if await model.confirm() { await onCommitted() } }
                    }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("repository-relocation-confirm")
                    Button("Cancel") { model.cancel() }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("repository-relocation-cancel")
                }.disabled(model.isBusy)
            }
            DisclosureGroup("Recover an interrupted confirmation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Retain this token to read the exact confirmation receipt after a restart. It contains no bookmark or folder path.")
                        .font(.caption).foregroundStyle(RekonTheme.secondaryText)
                    TextField("Saved recovery token", text: $model.recoveryTokenText, axis: .vertical)
                        .font(.caption.monospaced()).lineLimit(3...6)
                        .textFieldStyle(RekonQuietTextFieldStyle())
                        .accessibilityIdentifier("repository-relocation-token")
                    Button("Check exact receipt") { Task { await model.recoverReceipt() } }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .disabled(model.isBusy || model.recoveryTokenText.isEmpty)
                        .accessibilityIdentifier("repository-relocation-recover")
                }
            }
            if model.isBusy { ProgressView().controlSize(.small).accessibilityLabel("Checking repository relocation") }
            if let message = model.message {
                Text(message).font(.subheadline).foregroundStyle(RekonTheme.secondaryText)
                    .accessibilityIdentifier("repository-relocation-result")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(RekonTheme.primaryText)
        .task { await model.load() }
    }
    private var heading: some View { Label("Repository folder", systemImage: "folder").font(.title2.weight(.semibold)) }
    private var reloadButton: some View {
        Button("Reload roots") { Task { await model.load() } }
            .buttonStyle(RekonSecondaryButtonStyle()).disabled(model.isBusy)
            .accessibilityIdentifier("repository-roots-reload")
    }
    private var cancelButton: some View {
        Button("Cancel") { model.cancel() }.buttonStyle(RekonSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
    }
    private var rootConfirmation: some View {
        Button("Confirm root action") { Task { if await model.confirmRootAction() { await onCommitted() } } }
            .buttonStyle(RekonPrimaryButtonStyle()).accessibilityIdentifier("repository-root-confirm")
    }
    @ViewBuilder private var worktreeRoots: some View {
        if let snapshot = model.rootSnapshot {
            ForEach(snapshot.roots) { root in
                VStack(alignment: .leading, spacing: 8) {
                    RekonSeparator()
                    Text(root.role == .primary ? "Primary root access" : "Authorized worktree").font(.headline)
                    if root.role == .worktree { Text(root.path).font(.caption.monospaced()).textSelection(.enabled) }
                    Text(root.accessDetail).font(.caption)
                        .foregroundStyle(root.isAccessible ? RekonTheme.secondaryText : RekonTheme.warning)
                    if root.role == .worktree && model.allowsRelocation {
                        ViewThatFits(in: .horizontal) {
                            HStack { worktreeActions(root) }
                            VStack(alignment: .leading, spacing: 8) { worktreeActions(root) }
                        }.disabled(model.isBusy)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("repository-root-\(root.id.rawValue)")
            }
            Text("Access checked \(snapshot.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2).foregroundStyle(RekonTheme.secondaryText)
            if model.allowsRelocation {
                Button("Authorize worktree…") { chooseWorktree() }
                    .buttonStyle(RekonSecondaryButtonStyle()).disabled(model.isBusy)
                    .accessibilityIdentifier("repository-worktree-authorize")
            }
        }
    }
    @ViewBuilder private func worktreeActions(_ root: ProjectRootSnapshot.Root) -> some View {
        Button("Reconnect…") { chooseWorktree(savedPath: root.path) }
            .buttonStyle(RekonSecondaryButtonStyle())
            .accessibilityLabel("Reconnect worktree \(root.path)")
        Button("Revoke authorization…") { Task { await model.prepareRootAction(.revoke, folder: URL(fileURLWithPath: root.path)) } }
            .buttonStyle(RekonSecondaryButtonStyle())
            .accessibilityLabel("Revoke authorization for worktree \(root.path)")
        if model.binding != nil {
            Button("Use as primary…") { chooseFolder(savedPath: root.path) }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityLabel("Use worktree as primary repository \(root.path)")
        }
    }
    private func chooseWorktree(savedPath: String? = nil) {
        let panel = NSOpenPanel()
        panel.title = savedPath == nil ? "Authorize Git Worktree" : "Reconnect Saved Worktree"
        panel.message = savedPath.map { "Select this exact saved folder: \($0)" } ?? "Select a worktree of the primary repository. Access is saved only after confirmation."
        panel.prompt = "Preview"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        if let savedPath { panel.directoryURL = URL(fileURLWithPath: savedPath) }
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        Task { await model.prepareRootAction(savedPath == nil ? .authorize : .reconnect, folder: folder, expectedPath: savedPath) }
    }
    private func chooseFolder(savedPath: String? = nil) {
        let panel = NSOpenPanel()
        panel.title = "Select Primary Repository Location"
        if let savedPath {
            panel.directoryURL = URL(fileURLWithPath: savedPath)
            panel.message = "Select this exact worktree to authorize it as the primary repository: \(savedPath)"
        }
        panel.prompt = "Check Repository"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        Task { await model.prepare(folder: folder, expectedPath: savedPath) }
    }
}

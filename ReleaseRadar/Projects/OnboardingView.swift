import AppKit
import ReleaseRadarCore
import SwiftUI

struct OnboardingView: View {
    @State private var onboarding = FolderProjectOnboarding(store: DeliveryStore())
    @State private var preview: OnboardingPreview?
    @State private var projectID: ProjectID?
    @State private var projectName = ""
    @State private var phaseID = ""
    @State private var phaseName = ""
    @State private var excludedTaskIDs: Set<String> = []
    @State private var statusMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ContentUnavailableView(
                "Add a folder-backed project",
                systemImage: "folder.badge.plus",
                description: Text("Release Radar stores a read-only bookmark to the folder you select.")
            )

            Button("Choose Project Folder…", action: chooseFolder)
                .disabled(isWorking)

            if let preview {
                Form {
                    TextField("Project name", text: $projectName)
                    TextField("First phase ID", text: $phaseID)
                    TextField("First phase name", text: $phaseName)
                }
                .frame(maxWidth: 440)

                if !preview.worktreesRequiringAuthorization.isEmpty {
                    HStack {
                        Text("Worktrees outside the selected folder need separate owner authorization before they can be included.")
                            .foregroundStyle(.secondary)
                        Button("Authorize Worktree…", action: authorizeWorktree)
                            .disabled(isWorking)
                    }
                }

                if !preview.includedTaskDescriptors.isEmpty {
                    Text("Matching Codex tasks")
                        .font(.headline)
                    ForEach(preview.includedTaskDescriptors, id: \.id) { task in
                        Toggle(task.title, isOn: Binding(
                            get: { !excludedTaskIDs.contains(task.id) },
                            set: { included in
                                if included { excludedTaskIDs.remove(task.id) }
                                else { excludedTaskIDs.insert(task.id) }
                            }
                        ))
                    }
                }

                HStack {
                    Button("Ask agent to define first phase", action: askAgentToDefineFirstPhase)
                        .disabled(isWorking || phaseID.isEmpty || phaseName.isEmpty)
                    Button("Finish with review inbox", action: finish)
                        .disabled(isWorking || projectID == nil)
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(statusMessage)
            }
        }
        .padding(32)
        .navigationTitle("Projects")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Project"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let result = try await onboarding.inspect(folder: folder)
                preview = result
                projectName = result.selectedFolder.lastPathComponent
                projectID = nil
                excludedTaskIDs = []
                statusMessage = result.includedTaskDescriptors.isEmpty
                    ? "No delivery structure found. Ask an agent to define the first phase."
                    : "Matching tasks are included; uncertain mappings will appear in Needs Review."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func askAgentToDefineFirstPhase() {
        guard let decision = decision() else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let preparedID = try await onboarding.prepare(decision)
                let result = await onboarding.askAgentToDefineFirstPhase(
                    projectID: preparedID,
                    phaseID: phaseID,
                    name: phaseName
                )
                if let error = result.error {
                    statusMessage = "Agent request failed: \(String(describing: error))"
                } else {
                    projectID = preparedID
                    statusMessage = "The agent-defined first phase is ready. Finish onboarding when you are ready."
                }
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func authorizeWorktree() {
        guard let preview else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Authorize Worktree"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await onboarding.authorizeWorktree(folder, for: preview)
                self.preview = try await onboarding.inspect(folder: preview.selectedFolder)
                statusMessage = "The separately selected worktree is authorized for this project."
            } catch {
                statusMessage = "Choose one of the discovered worktrees to authorize it."
            }
        }
    }

    private func finish() {
        guard let decision = decision() else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                _ = try await onboarding.finish(decision)
                statusMessage = "Project onboarded. Uncertain tasks are in Needs Review."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func decision() -> OnboardingDecision? {
        guard let preview else {
            statusMessage = "Choose a project folder first."
            return nil
        }
        return .init(preview: preview, projectName: projectName, excludedTaskIDs: excludedTaskIDs)
    }
}

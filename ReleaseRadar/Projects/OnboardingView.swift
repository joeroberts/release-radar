import AppKit
import ReleaseRadarCore
import SwiftUI

struct OnboardingView: View {
    @State private var onboarding: FolderProjectOnboarding
    @State private var preview: OnboardingPreview?
    @State private var projectID: ProjectID?
    @State private var projectName = ""
    @State private var excludedTaskIDs: Set<String> = []
    @State private var importRecognizedArtifacts = false
    @State private var hasFirstPhase = false
    @State private var statusMessage: String?
    @State private var failurePresentation: FailureStatePresentation?
    @State private var isWorking = false
    let onFinished: @MainActor (ProjectID) async -> Void

    init(store: DeliveryStore, onFinished: @escaping @MainActor (ProjectID) async -> Void) {
        _onboarding = State(initialValue: FolderProjectOnboarding(store: store))
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if preview == nil {
                FailureStateView(presentation: .noDeliveryStructure, style: .full)
            }

            Button("Choose Project Folder…", action: chooseFolder)
                .disabled(isWorking)

            if let preview {
                Form {
                    TextField("Project name", text: $projectName)
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

                if let importPreview = preview.recognizedArtifactPreview {
                    recognizedArtifactPreview(importPreview)
                }

                HStack {
                    Button(preparationButtonTitle, action: requestFirstPhaseDefinition)
                        .disabled(isWorking)
                    Button("Check for agent phase") {
                        Task { await refreshFirstPhaseAvailability() }
                    }
                        .disabled(isWorking || projectID == nil)
                    Button("Finish with review inbox", action: finish)
                        .disabled(isWorking || projectID == nil || !hasFirstPhase)
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(statusMessage)
            }

            if let failurePresentation {
                FailureStateView(presentation: failurePresentation)
            }
        }
        .padding(32)
        .navigationTitle("Projects")
        .task(id: projectID) {
            guard projectID != nil else { return }
            while !Task.isCancelled && !hasFirstPhase {
                await refreshFirstPhaseAvailability()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Project"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        isWorking = true
        failurePresentation = nil
        statusMessage = nil
        Task {
            defer { isWorking = false }
            do {
                let result = try await onboarding.inspect(folder: folder)
                let resumedProjectID = result.pendingProjectID
                let resumedHasFirstPhase: Bool
                if let resumedProjectID {
                    resumedHasFirstPhase = try await onboarding.hasFirstPhase(projectID: resumedProjectID)
                } else {
                    resumedHasFirstPhase = false
                }
                preview = result
                projectName = result.selectedFolder.lastPathComponent
                projectID = resumedProjectID
                excludedTaskIDs = []
                importRecognizedArtifacts = false
                hasFirstPhase = resumedHasFirstPhase
                if resumedProjectID != nil {
                    statusMessage = resumedHasFirstPhase
                        ? "Pending onboarding has a persisted first phase and can be finished."
                        : "Pending onboarding is waiting for an agent-defined first phase."
                    failurePresentation = resumedHasFirstPhase ? nil : .firstPhaseRequired
                } else {
                    statusMessage = result.recognizedArtifactPreview == nil
                        ? (result.includedTaskDescriptors.isEmpty
                            ? nil
                            : "Matching tasks are included; uncertain mappings will appear in Needs Review.")
                        : "Review the recognized delivery records and choose whether to import them."
                    failurePresentation = result.includedTaskDescriptors.isEmpty
                        && result.recognizedArtifactPreview == nil
                        ? .noDeliveryStructure
                        : nil
                }
            } catch {
                failurePresentation = failure(for: error)
            }
        }
    }

    private func requestFirstPhaseDefinition() {
        guard let decision = decision() else { return }
        isWorking = true
        failurePresentation = nil
        Task {
            defer { isWorking = false }
            do {
                let preparedID = try await onboarding.prepare(decision)
                projectID = preparedID
                hasFirstPhase = try await onboarding.hasFirstPhase(projectID: preparedID)
                if !hasFirstPhase {
                    try await onboarding.requestFirstPhaseDefinition(projectID: preparedID)
                    hasFirstPhase = try await onboarding.hasFirstPhase(projectID: preparedID)
                }
                statusMessage = hasFirstPhase
                    ? "A persisted first phase is ready."
                    : nil
                failurePresentation = hasFirstPhase ? nil : .firstPhaseRequired
            } catch {
                failurePresentation = failure(for: error)
            }
        }
    }

    private func refreshFirstPhaseAvailability() async {
        guard let projectID else { return }
        do {
            hasFirstPhase = try await onboarding.hasFirstPhase(projectID: projectID)
            if hasFirstPhase {
                statusMessage = "An agent-defined first phase is ready."
                failurePresentation = nil
            }
        } catch {
            failurePresentation = failure(for: error)
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
        failurePresentation = nil
        Task {
            defer { isWorking = false }
            do {
                try await onboarding.authorizeWorktree(folder, for: preview)
                self.preview = try await onboarding.inspect(folder: preview.selectedFolder)
                statusMessage = "The separately selected worktree is authorized for this project."
            } catch {
                failurePresentation = failure(for: error)
            }
        }
    }

    private func finish() {
        guard let decision = decision() else { return }
        isWorking = true
        failurePresentation = nil
        Task {
            defer { isWorking = false }
            do {
                let finishedProjectID = try await onboarding.finish(decision)
                await onFinished(finishedProjectID)
            } catch {
                failurePresentation = failure(for: error)
            }
        }
    }

    private func decision() -> OnboardingDecision? {
        guard let preview else {
            failurePresentation = .noDeliveryStructure
            return nil
        }
        return .init(
            preview: preview,
            projectName: projectName,
            excludedTaskIDs: excludedTaskIDs,
            importRecognizedArtifacts: importRecognizedArtifacts
        )
    }

    private var preparationButtonTitle: String {
        preview?.recognizedArtifactPreview != nil && importRecognizedArtifacts
            ? "Import and prepare project"
            : "Ask agent to define first phase"
    }

    @ViewBuilder
    private func recognizedArtifactPreview(_ preview: ImportPreview) -> some View {
        GroupBox("Recognized delivery artifact") {
            VStack(alignment: .leading, spacing: 10) {
                Text(preview.artifactURL.lastPathComponent)
                    .font(.headline)
                Text("\(preview.phases.count) phases · \(preview.tickets.count) tickets · \(preview.phaseDependencies.count + preview.ticketDependencies.count) dependencies · \(preview.evidence.count) evidence records · \(preview.reviewItems.count) Needs Review items")
                    .foregroundStyle(.secondary)

                DisclosureGroup("Review recognized records") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            previewSection("Phases", rows: preview.phases.map {
                                "\($0.id.rawValue) · \($0.name)"
                            })
                            previewSection("Tickets", rows: preview.tickets.map {
                                "\($0.id.rawValue) · \($0.outcome) · \($0.lane.rawValue)"
                            })
                            previewSection("Dependencies", rows:
                                preview.phaseDependencies.map {
                                    "Phase \($0.phaseID.rawValue) requires \($0.dependsOnPhaseID.rawValue)"
                                }
                                + preview.ticketDependencies.map {
                                    "Ticket \($0.ticketID.rawValue) requires \($0.dependsOnTicketID.rawValue)"
                                }
                            )
                            previewSection("Evidence", rows: preview.evidence.map {
                                "\($0.label) · \($0.path)"
                            })
                            previewSection("Needs Review", rows: preview.reviewItems.map(\.summary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 240)
                }

                Toggle("Import these reviewed delivery records", isOn: $importRecognizedArtifacts)
                    .accessibilityIdentifier("onboarding-import-recognized")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func previewSection(_ title: String, rows: [String]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Text(row)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func failure(for error: Error) -> FailureStatePresentation {
        if let onboardingError = error as? OnboardingError,
           let presentation = FailureStatePresentation(onboardingError: onboardingError) {
            return presentation
        }
        if error is ProjectBookmarkError {
            return FailureStatePresentation(
                title: "Project folder unavailable",
                detail: error.localizedDescription,
                systemImage: "folder.badge.questionmark",
                tone: .warning,
                accessibilityID: "failure-project-folder"
            )
        }
        return FailureStatePresentation(
            title: "Project setup unavailable",
            detail: error.localizedDescription,
            systemImage: "exclamationmark.triangle",
            tone: .error,
            accessibilityID: "failure-project-setup"
        )
    }
}

import AppKit
import ReleaseRadarCore
import SwiftUI

enum OnboardingWorkflow: Sendable {
    case landing
    case initialize
    case attach
}

struct OnboardingWorkflowPresentation: Equatable, Sendable {
    static let initializeTitle = "Initialize Project Tracking"
    static let attachTitle = AttachFolderConfirmation.workflowLabel
    static let landingActionTitles = [initializeTitle, attachTitle]
}

struct InitializeProjectConfirmation: Equatable, Sendable {
    let projectName: String
    let folder: URL

    var title: String {
        "Initialize \u{201c}\(projectName)\u{201d} from \u{201c}\(folder.lastPathComponent)\u{201d}?"
    }

    var detail: String {
        "Release Radar tracking state and folder authorization will be saved locally. Initialization does not modify repository files."
    }
}

enum CodexPromptCopyResult: Equatable, Sendable {
    case copied
    case failed

    var announcement: String {
        switch self {
        case .copied: "Codex prompt copied"
        case .failed: "Codex prompt could not be copied"
        }
    }

    var accessibilityAnnouncement: String { announcement }
}

struct CodexPromptHandoff: Sendable {
    private static let setupPrompt = "Explicitly invoke and follow the installed $release-radar:release-radar skill. You are authorizing this task to create or update only the exact Release Radar guidance v2 managed block in the authorized repository's root \(RepositoryDocumentContract.guidancePath), while preserving every other instruction and all existing delivery content. Require an existing catalogued \(RepositoryDocumentContract.progressPath), preserve it byte-for-byte, and validate the existing \(RepositoryDocumentContract.catalogPath) and generated indexes with the repository documentation check; stop before any handoff write and report missing or invalid prerequisites for separately authorized preparation, without creating a ledger or catalog, moving documents, binding a repository, or accepting a catalog. Use the supported read-only inventory to preserve the exact existing handoff evidence ID when one matches this project's ticketless root \(RepositoryDocumentContract.guidancePath); reject incomplete, ambiguous, or mismatched results. Follow the skill's repository handoff: write and read back the permitted guidance, record that exact file with the existing ticketless evidence mutation, retain the complete request across uncertain outcomes, and report pending audit or discrepancies."
    private static func auditRepairPrompt(version: Int) -> String {
        "Explicitly invoke and follow the installed $release-radar:release-radar skill. Release Radar reports this repository's guidance handoff incomplete: the v\(version) managed block already matches, but its required ticketless evidence record is absent. You are authorizing this task to read back the exact root \(RepositoryDocumentContract.guidancePath) and complete the handoff through the skill's audited repair path without changing unrelated repository instructions, delivery documentation, or delivery state. Preserve the complete request across uncertain outcomes and report any pending audit or discrepancy instead of guessing."
    }
    static let copyButtonAccessibilityLabel = "Copy Codex prompt"
    static let copyButtonAccessibilityIdentifier = "onboarding-copy-codex-prompt"
    static let clipboardDisclosure = "Only the prompt is copied. It remains on the clipboard until replaced."

    static func prompt(for state: ProjectGuidanceState, projectRoot: URL) -> String {
        let root = projectRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let rootBinding = "The exact Release Radar-authorized repository root is `\(root)`. Confirm that this Codex task's canonical repository root exactly matches it. If it does not match, stop before writing any file or calling Release Radar and tell the owner to open a task rooted at that exact folder."
        let handoff = if case let .handoffIncomplete(version) = state { auditRepairPrompt(version: version) } else { setupPrompt }
        let contents = Bundle.main.bundleURL.appendingPathComponent("Contents")
        let tooling = """
        Documentation checker: \(contents.appendingPathComponent("Helpers/ReleaseRadarDocumentationTool").path)
        Catalog v1 reference: \(contents.appendingPathComponent("Resources/catalog-v1.md").path)
        Use the checker with `check --root <exact authorized root>` (quote paths). Its `--help` describes usage. These installed resources require no Release Radar source checkout. They do not authorize preparation, guidance changes, binding or catalog acceptance beyond the handoff above.
        """
        return rootBinding + "\n\n" + handoff + "\n\n" + tooling
    }

    @MainActor
    static func copy(
        prompt: String,
        using writer: @MainActor (String) -> Bool
    ) -> CodexPromptCopyResult {
        writer(prompt) ? .copied : .failed
    }

    @MainActor
    static func copy(
        for state: ProjectGuidanceState,
        projectRoot: URL,
        using writer: @MainActor (String) -> Bool
    ) -> CodexPromptCopyResult {
        copy(prompt: prompt(for: state, projectRoot: projectRoot), using: writer)
    }

    @MainActor
    static func writeToGeneralPasteboard(_ prompt: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(prompt, forType: .string)
    }
}

struct AttachFolderConfirmation: Equatable, Sendable {
    static let workflowLabel = "Attach Folder to Existing Project"
    static let savedNeedsReload = FailureStatePresentation(
        title: "Folder attached; refresh needed",
        detail: "The folder attachment was saved. Do not retry it; reload the Projects view.",
        systemImage: "arrow.clockwise.circle",
        tone: .warning,
        accessibilityID: "attachment-refresh-failed"
    )

    let project: ProjectRecord
    let folder: URL

    var title: String {
        "Attach \u{201c}\(folder.lastPathComponent)\u{201d} to \u{201c}\(project.name)\u{201d}?"
    }

    var detail: String {
        "Existing delivery records and history will be preserved. The folder authorization will be saved locally."
    }
}

struct AddProjectWindowView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Bindable var model: AppModel

    var body: some View {
        OnboardingView(
            store: model.onboardingStore,
            navigationTitle: "Add Project",
            onCancel: close,
            onOpenExisting: { projectID in
                Task {
                    await model.openProject(projectID)
                    close()
                }
            },
            loadAttachableProjects: {
                try await model.eligibleProjectsForFolderAttachment()
            },
            onAttachFolder: { folder, projectID in
                try await model.attachFolder(folder, to: projectID)
            },
            onReloadAfterFolderAttachment: { projectID in
                await model.reloadAfterFolderAttachment(projectID)
            }
        ) { _ in
            await model.reloadAfterOnboarding()
            close()
        }
    }

    private func close() {
        dismissWindow(id: "add-project")
    }
}

struct OnboardingView: View {
    @State private var onboarding: FolderProjectOnboarding
    @State private var workflow: OnboardingWorkflow = .landing
    @State private var preview: OnboardingPreview?
    @State private var projectID: ProjectID?
    @State private var projectName = ""
    @State private var excludedTaskIDs: Set<String> = []
    @State private var importRecognizedArtifacts = false
    @State private var hasFirstPhase = false
    @State private var statusMessage: String?
    @State private var failurePresentation: FailureStatePresentation?
    @State private var isWorking = false
    @State private var isAttachingExistingProject = false
    @State private var attachableProjects: [ProjectRecord] = []
    @State private var selectedAttachableProjectID: ProjectID?
    @State private var attachmentFolder: URL?
    @State private var attachmentCommittedNeedsReload = false
    @State private var isAttachmentCommitInFlight = false
    @State private var isInitializeCommitInFlight = false
    @State private var promptCopyResult: CodexPromptCopyResult?
    let navigationTitle: String
    let onCancel: (() -> Void)?
    let onOpenExisting: (ProjectID) -> Void
    let loadAttachableProjects: (@MainActor () async throws -> [ProjectRecord])?
    let onAttachFolder: (@MainActor (URL, ProjectID) async throws -> AttachFolderOutcome)?
    let onReloadAfterFolderAttachment: (@MainActor (ProjectID) async -> Bool)?
    let pasteboardWriter: @MainActor (String) -> Bool
    let onFinished: @MainActor (ProjectID) async -> Void

    init(
        store: DeliveryStore,
        navigationTitle: String = "Projects",
        onCancel: (() -> Void)? = nil,
        onOpenExisting: @escaping (ProjectID) -> Void,
        loadAttachableProjects: (@MainActor () async throws -> [ProjectRecord])? = nil,
        onAttachFolder: (@MainActor (URL, ProjectID) async throws -> AttachFolderOutcome)? = nil,
        onReloadAfterFolderAttachment: (@MainActor (ProjectID) async -> Bool)? = nil,
        pasteboardWriter: @escaping @MainActor (String) -> Bool = CodexPromptHandoff.writeToGeneralPasteboard,
        initialPreview: OnboardingPreview? = nil,
        onFinished: @escaping @MainActor (ProjectID) async -> Void
    ) {
        _onboarding = State(initialValue: FolderProjectOnboarding(store: store))
        if let initialPreview {
            _preview = State(initialValue: initialPreview)
            _workflow = State(initialValue: .initialize)
            _projectName = State(initialValue: initialPreview.selectedFolder.lastPathComponent)
        }
        self.navigationTitle = navigationTitle
        self.onCancel = onCancel
        self.onOpenExisting = onOpenExisting
        self.loadAttachableProjects = loadAttachableProjects
        self.onAttachFolder = onAttachFolder
        self.onReloadAfterFolderAttachment = onReloadAfterFolderAttachment
        self.pasteboardWriter = pasteboardWriter
        self.onFinished = onFinished
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if onCancel != nil {
                    HStack {
                        Spacer()
                        Button("Cancel", action: cancel)
                            .keyboardShortcut(.cancelAction)
                            .disabled(isInitializeCommitInFlight || isAttachmentCommitInFlight)
                            .accessibilityIdentifier("onboarding-cancel")
                    }
                }

                switch workflow {
                case .landing:
                    landing
                case .initialize:
                    newProjectWorkflow
                case .attach:
                    attachmentWorkflow
                }

                if let statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(statusMessage)
                }

                if let failurePresentation {
                    if attachmentCommittedNeedsReload {
                        FailureStateView(
                            presentation: failurePresentation,
                            actionTitle: "Reload",
                            action: reloadAttachedProject
                        )
                    } else {
                        FailureStateView(presentation: failurePresentation)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(navigationTitle)
        .interactiveDismissDisabled(isInitializeCommitInFlight || isAttachmentCommitInFlight)
    }

    private var landing: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add a project")
                    .font(.largeTitle.weight(.semibold))
                Text("Choose how this folder-backed project should join Release Radar.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Button(OnboardingWorkflowPresentation.initializeTitle) {
                    workflow = .initialize
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding-initialize-project")

                if loadAttachableProjects != nil {
                    Button(OnboardingWorkflowPresentation.attachTitle) {
                        workflow = .attach
                        beginAttachmentWorkflow()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding-attach-existing")
                }
            }
        }
    }

    @ViewBuilder
    private var newProjectWorkflow: some View {
        if projectID == nil {
            Button("Back", action: backToLanding)
                .disabled(isInitializeCommitInFlight)
                .accessibilityIdentifier("onboarding-back")
        }

        VStack(alignment: .leading, spacing: 6) {
            Text(OnboardingWorkflowPresentation.initializeTitle)
                .font(.title2.weight(.semibold))
            Text("Choose a folder, review what Release Radar found, and confirm before anything is saved.")
                .foregroundStyle(.secondary)
        }

        if preview == nil {
            Button("Choose Project Folder…", action: chooseFolder)
                .disabled(isWorking)
        }

        if let completedProjectID = preview?.completedProjectID {
            Button("Open existing project") {
                openExisting(completedProjectID)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isWorking)
            .accessibilityIdentifier("onboarding-open-existing")
        } else if let preview, projectID == nil {
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

            let guidance = ProjectGuidancePresentation(documentationState: preview.documentationState)
            LabeledContent("Release Radar guidance", value: guidance.status)
                .accessibilityIdentifier("onboarding-project-guidance-status")
            if preview.documentationState != .legacy(preview.projectGuidanceState) {
                Text(guidance.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboarding-documentation-detail")
            }

            let confirmation = InitializeProjectConfirmation(
                projectName: projectName,
                folder: preview.selectedFolder
            )
            GroupBox("Confirm initialization") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(confirmation.title)
                        .font(.headline)
                    Text(preview.selectedFolder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text(confirmation.detail)
                        .foregroundStyle(.secondary)
                    Button(OnboardingWorkflowPresentation.initializeTitle, action: initializeProject)
                        .keyboardShortcut(.defaultAction)
                        .disabled(isWorking)
                        .accessibilityIdentifier("onboarding-initialize-confirm")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("onboarding-initialize-confirmation")
        } else if projectID != nil {
            codexHandoff
        }
    }

    private var codexHandoff: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Continue in Codex") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project tracking is saved. Paste this prompt into a Codex task rooted at this exact project folder.")
                        .foregroundStyle(.secondary)
                    if let projectRoot = preview?.selectedFolder {
                        Text(projectRoot.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("onboarding-authorized-project-root")
                        Text(CodexPromptHandoff.prompt(for: projectGuidanceState, projectRoot: projectRoot))
                            .font(.callout)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("onboarding-codex-prompt")
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Button(action: copyCodexPrompt) {
                            Image(systemName: "square.on.square")
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(CodexPromptHandoff.copyButtonAccessibilityLabel)
                        .accessibilityIdentifier(CodexPromptHandoff.copyButtonAccessibilityIdentifier)
                        .help(CodexPromptHandoff.copyButtonAccessibilityLabel)

                        Text(CodexPromptHandoff.clipboardDisclosure)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let promptCopyResult {
                        Text(promptCopyResult.announcement)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(promptCopyResult == .copied ? .green : .red)
                            .accessibilityLabel(promptCopyResult.accessibilityAnnouncement)
                            .accessibilityIdentifier("onboarding-codex-copy-result")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Check Tracking Status") {
                    Task { await refreshFirstPhaseAvailability() }
                }
                .disabled(isWorking)
                .accessibilityIdentifier("onboarding-check-tracking-status")

                Button("Finish Initialization", action: finish)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isWorking || !hasFirstPhase)
                    .accessibilityIdentifier("onboarding-finish-initialization")
            }
        }
    }

    @ViewBuilder
    private var attachmentWorkflow: some View {
        Button("Back", action: backToLanding)
            .disabled(isInitializeCommitInFlight || isAttachmentCommitInFlight)
            .accessibilityIdentifier("onboarding-back")

        VStack(alignment: .leading, spacing: 8) {
            Text(AttachFolderConfirmation.workflowLabel)
                .font(.title2.weight(.semibold))
            Text("Select a saved project first, then choose the folder that belongs to it.")
                .foregroundStyle(.secondary)
        }

        if attachableProjects.isEmpty, !isWorking {
            FailureStateView(presentation: .init(
                title: "No projects available to attach",
                detail: "Eligible projects must have no open onboarding step and no saved folder or bookmark.",
                systemImage: "folder.badge.questionmark",
                tone: .neutral,
                accessibilityID: "attachment-no-eligible-projects"
            ))
        } else {
            Picker("Project", selection: $selectedAttachableProjectID) {
                Text("Select a project").tag(ProjectID?.none)
                ForEach(attachableProjects, id: \.id) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
            .frame(maxWidth: 440)
            .disabled(isWorking || attachmentFolder != nil)
            .accessibilityIdentifier("onboarding-attach-project")

            Button("Choose Folder…", action: chooseAttachmentFolder)
                .disabled(isWorking || selectedAttachableProjectID == nil || attachmentCommittedNeedsReload)
                .accessibilityIdentifier("onboarding-attach-folder")
        }

        if let confirmation = attachmentConfirmation {
            GroupBox("Confirm folder attachment") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(confirmation.title)
                        .font(.headline)
                    Text(confirmation.folder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text(confirmation.detail)
                        .foregroundStyle(.secondary)

                    if !attachmentCommittedNeedsReload {
                        Button("Attach Folder", action: confirmFolderAttachment)
                            .keyboardShortcut(.defaultAction)
                            .disabled(isWorking)
                            .accessibilityIdentifier("onboarding-attach-confirm")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("onboarding-attach-confirmation")
        }
    }

    private var attachmentConfirmation: AttachFolderConfirmation? {
        guard
            let projectID = selectedAttachableProjectID,
            let project = attachableProjects.first(where: { $0.id == projectID }),
            let attachmentFolder
        else { return nil }
        return AttachFolderConfirmation(project: project, folder: attachmentFolder)
    }

    private func beginAttachmentWorkflow() {
        guard let loadAttachableProjects else { return }
        isAttachingExistingProject = true
        attachableProjects = []
        selectedAttachableProjectID = nil
        attachmentFolder = nil
        attachmentCommittedNeedsReload = false
        statusMessage = nil
        failurePresentation = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                attachableProjects = try await loadAttachableProjects()
            } catch {
                failurePresentation = FailureStatePresentation(
                    title: "Saved projects unavailable",
                    detail: "Release Radar could not load projects eligible for folder attachment. Cancel and reload Projects before trying again.",
                    systemImage: "folder.badge.questionmark",
                    tone: .error,
                    accessibilityID: "attachment-projects-unavailable"
                )
            }
        }
    }

    private func chooseAttachmentFolder() {
        guard selectedAttachableProjectID != nil else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.begin { response in
            guard response == .OK, let folder = panel.url else { return }
            Task { @MainActor in
                attachmentFolder = folder.standardizedFileURL.resolvingSymlinksInPath()
                statusMessage = nil
                failurePresentation = nil
            }
        }
    }

    private func confirmFolderAttachment() {
        guard
            let onAttachFolder,
            let projectID = selectedAttachableProjectID,
            let attachmentFolder,
            !attachmentCommittedNeedsReload
        else { return }
        isWorking = true
        isAttachmentCommitInFlight = true
        statusMessage = nil
        failurePresentation = nil
        Task {
            defer {
                isWorking = false
                isAttachmentCommitInFlight = false
            }
            do {
                switch try await onAttachFolder(attachmentFolder, projectID) {
                case .attached:
                    completeAttachmentAndDismiss()
                case .attachedNeedsReload:
                    attachmentCommittedNeedsReload = true
                    failurePresentation = AttachFolderConfirmation.savedNeedsReload
                }
            } catch {
                failurePresentation = failure(for: error)
            }
        }
    }

    private func reloadAttachedProject() {
        guard
            let onReloadAfterFolderAttachment,
            let projectID = selectedAttachableProjectID,
            attachmentCommittedNeedsReload
        else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            if await onReloadAfterFolderAttachment(projectID) {
                completeAttachmentAndDismiss()
            } else {
                failurePresentation = AttachFolderConfirmation.savedNeedsReload
            }
        }
    }

    private func completeAttachmentAndDismiss() {
        let dismiss = onCancel
        reset()
        dismiss?()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Project"
        panel.begin { response in
            guard response == .OK, let folder = panel.url else { return }
            Task { @MainActor in
                isWorking = true
                failurePresentation = nil
                statusMessage = nil
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
                    if result.completedProjectID != nil {
                        statusMessage = "This folder already belongs to an active project."
                        failurePresentation = nil
                    } else if resumedProjectID != nil {
                        statusMessage = resumedHasFirstPhase
                            ? "Saved tracking state is ready. Finish Initialization to open the project."
                            : "Project tracking is saved and waiting for the current tracking state."
                        failurePresentation = resumedHasFirstPhase ? nil : .trackingStateRequired
                    } else {
                        statusMessage = result.recognizedArtifactPreview == nil
                            ? (result.includedTaskDescriptors.isEmpty
                                ? nil
                                : "Matching tasks are included; uncertain mappings will appear in Needs Review.")
                            : "Review the recognized seed records and choose whether to apply them to this new project."
                        failurePresentation = result.includedTaskDescriptors.isEmpty
                            && result.recognizedArtifactPreview == nil
                            ? FailureStatePresentation(
                                title: "No tracking structure found",
                                detail: "You can still initialize this project, then use the Codex prompt to define its current tracking state.",
                                systemImage: "folder.badge.plus",
                                tone: .neutral,
                                accessibilityID: "onboarding-no-tracking-structure"
                            )
                            : nil
                    }
                } catch {
                    failurePresentation = failure(for: error)
                }
            }
        }
    }

    private func initializeProject() {
        guard let decision = decision() else { return }
        isWorking = true
        isInitializeCommitInFlight = true
        failurePresentation = nil
        promptCopyResult = nil
        Task {
            defer {
                isWorking = false
                isInitializeCommitInFlight = false
            }
            do {
                let preparedID = try await onboarding.prepare(decision)
                projectID = preparedID
                hasFirstPhase = try await onboarding.hasFirstPhase(projectID: preparedID)
                statusMessage = hasFirstPhase
                    ? "Project tracking is saved and ready to finish."
                    : "Project tracking is saved and waiting for the current tracking state."
                failurePresentation = hasFirstPhase ? nil : .trackingStateRequired
            } catch let preparationError as OnboardingPreparationError {
                switch preparationError {
                case let .seedApplicationFailedAfterSave(savedProjectID):
                    projectID = savedProjectID
                    hasFirstPhase = (try? await onboarding.hasFirstPhase(projectID: savedProjectID)) ?? false
                    statusMessage = "Project tracking is saved and can be resumed."
                    failurePresentation = FailureStatePresentation(
                        title: "Tracking initialized; seed incomplete",
                        detail: "The folder authorization and pending project were saved, but the recognized seed was not applied. Do not initialize again; continue with the Codex prompt or reopen this folder to resume.",
                        systemImage: "exclamationmark.triangle",
                        tone: .warning,
                        accessibilityID: "onboarding-seed-incomplete"
                    )
                }
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
                statusMessage = "Persisted tracking state is ready. Finish Initialization to open the project."
                failurePresentation = nil
            } else {
                statusMessage = "Project tracking is saved and still waiting for the current tracking state."
                failurePresentation = .trackingStateRequired
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
        panel.begin { response in
            guard response == .OK, let folder = panel.url else { return }
            Task { @MainActor in
                isWorking = true
                failurePresentation = nil
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

    private func cancel() {
        guard !isInitializeCommitInFlight, !isAttachmentCommitInFlight, let onCancel else { return }
        reset()
        onCancel()
    }

    private func backToLanding() {
        guard !isInitializeCommitInFlight, !isAttachmentCommitInFlight else { return }
        reset()
    }

    private func copyCodexPrompt() {
        promptCopyResult = nil
        guard let projectRoot = preview?.selectedFolder else {
            promptCopyResult = .failed
            AccessibilityNotification.Announcement(CodexPromptCopyResult.failed.accessibilityAnnouncement).post()
            return
        }
        let result = CodexPromptHandoff.copy(
            for: projectGuidanceState,
            projectRoot: projectRoot,
            using: pasteboardWriter
        )
        promptCopyResult = result
        AccessibilityNotification.Announcement(result.accessibilityAnnouncement).post()
    }

    private var projectGuidanceState: ProjectGuidanceState {
        preview?.projectGuidanceState ?? .missing
    }

    private func openExisting(_ projectID: ProjectID) {
        reset()
        onOpenExisting(projectID)
    }

    private func reset() {
        workflow = .landing
        preview = nil
        projectID = nil
        projectName = ""
        excludedTaskIDs = []
        importRecognizedArtifacts = false
        hasFirstPhase = false
        statusMessage = nil
        failurePresentation = nil
        isWorking = false
        isAttachingExistingProject = false
        attachableProjects = []
        selectedAttachableProjectID = nil
        attachmentFolder = nil
        attachmentCommittedNeedsReload = false
        isAttachmentCommitInFlight = false
        isInitializeCommitInFlight = false
        promptCopyResult = nil
    }

    private func decision() -> OnboardingDecision? {
        guard let preview else {
            failurePresentation = FailureStatePresentation(
                title: "Project folder required",
                detail: "Choose a project folder and review the confirmation before initializing tracking.",
                systemImage: "folder.badge.plus",
                tone: .neutral,
                accessibilityID: "onboarding-folder-required"
            )
            return nil
        }
        return .init(
            preview: preview,
            projectName: projectName,
            excludedTaskIDs: excludedTaskIDs,
            importRecognizedArtifacts: importRecognizedArtifacts
        )
    }

    @ViewBuilder
    private func recognizedArtifactPreview(_ preview: ImportPreview) -> some View {
        GroupBox("Recognized new-project seed artifact") {
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

                Toggle("Apply these reviewed records to the new project", isOn: $importRecognizedArtifacts)
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
        if let authorizationError = error as? ProjectAuthorizationError {
            return attachmentFailure(for: authorizationError)
        }
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

    private func attachmentFailure(for error: ProjectAuthorizationError) -> FailureStatePresentation {
        let title: String
        let detail: String
        let accessibilityID: String
        switch error {
        case .rootAlreadyOwned:
            title = "Folder belongs to another project"
            detail = "Choose a different folder. Release Radar did not transfer or change the existing folder ownership."
            accessibilityID = "attachment-folder-owned"
        case .projectRootAlreadyAssociated:
            title = "Project already has folder authorization"
            detail = "Attach is unavailable because this project already has a root or saved bookmark. Use its existing Locate / Reauthorize recovery instead; inconsistent authorization data was left unchanged."
            accessibilityID = "attachment-project-associated"
        case .projectNotFound:
            title = "Project no longer available"
            detail = "Cancel and reload Projects, then select a currently saved project. Nothing was attached."
            accessibilityID = "attachment-project-missing"
        case .invalidFolder:
            title = "Folder unavailable"
            detail = "Choose an existing local folder. Nothing was attached."
            accessibilityID = "attachment-folder-invalid"
        case .securityScopeAccessDenied:
            title = "Folder access denied"
            detail = "macOS did not grant access to that folder. Choose it again or select another folder; nothing was attached."
            accessibilityID = "attachment-folder-denied"
        case .bookmarkStale, .bookmarkResolutionFailed, .bookmarkRootMismatch:
            title = "Folder authorization unavailable"
            detail = "The selected folder authorization could not be validated. Choose the folder again; nothing was attached."
            accessibilityID = "attachment-folder-authorization"
        case .projectRootMissing, .bookmarkMissing, .projectRootMismatch:
            title = "Project authorization changed"
            detail = "The saved project authorization changed while this sheet was open. Cancel and reload Projects before continuing; nothing was attached."
            accessibilityID = "attachment-project-authorization-changed"
        }
        return FailureStatePresentation(
            title: title,
            detail: detail,
            systemImage: "folder.badge.questionmark",
            tone: .warning,
            accessibilityID: accessibilityID
        )
    }
}

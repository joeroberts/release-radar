import AppKit
import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct ProjectOverviewView: View {
    let project: ProjectDashboardProjection
    let board: PhaseBoardProjection?
    let documentationState: ProjectDocumentationState
    var documentationStatus: DocumentationObservationStatus? = nil
    let projectRoot: URL?
    let phaseSelectionStatus: ActivePhaseSelectionStatus
    var openPlan: () -> Void = {}
    let openBoard: () -> Void
    let selectActivePhase: (PhaseID) async -> Void
    let reloadActivePhase: () async -> Void
    let reauthorizeActivePhase: (URL) async -> Void
    var refreshDocumentation: () async -> Void = {}
    var repositoryRecovery: RepositoryRecoveryModel? = nil
    var onRepositoryRelocated: () async -> Void = {}
    var loadProjectSettings: (() async throws -> ProjectSettingsSnapshot)? = nil
    var saveProjectSettings: ((ProjectRegistration, String, Set<String>) async throws -> ProjectSettingsSnapshot)? = nil
    var availableCodexTasks: [CodexTaskDescriptor] = []
    var loadProjectHealth: (() async -> ProjectHealthSnapshot)? = nil
    var reauthorizeProjectHealth: ((URL, DocumentationObservationIdentity) async throws -> ProjectHealthSnapshot)? = nil
    var documentationFolderChooser: @MainActor () -> URL? = { ProjectFolderAccessPanel.choose() }
    var loadEvidencePreview: ((EvidenceID) async -> EvidencePreview)? = nil
    var previewDocumentationSetup: ((ProjectRegistration) async throws -> ProjectDocumentationSetupPreview)? = nil
    var performDocumentationSetup: ((ProjectDocumentationSetupPreview) async throws -> AuditEventID?)? = nil
    var previewArchive: (() async throws -> ProjectLifecyclePreview)? = nil
    var archive: ((ProjectLifecyclePreview) async throws -> Void)? = nil
    var previewRemoval: (() async throws -> ProjectRemovalPreview)? = nil
    var remove: ((ProjectRemovalPreview) async throws -> Void)? = nil
    @State private var promptCopyResult: CodexPromptCopyResult?
    @State private var settings: ProjectSettingsSnapshot?
    @State private var health: ProjectHealthSnapshot?
    @State private var isLoadingSettings = false
    @State private var isRefreshingHealth = false
    @State private var healthRecoveryMessage: String?
    @State private var healthGeneration: UInt64 = 0
    @State private var showsSettings = false
    @State private var showsHelp = false
    @State private var showsRootManagement = false
    @State private var documentationSetupPreview: ProjectDocumentationSetupPreview?
    @State private var documentationSetupMessage: String?
    @State private var isPerformingDocumentationSetup = false
    @State private var lifecyclePreview: ProjectLifecyclePreview?
    @State private var lifecyclePreviewError: String?
    @State private var isLoadingLifecyclePreview = false
    @State private var showsLifecycleConfirmation = false
    @State private var removalPreview: ProjectRemovalPreview?
    @State private var showsRemovalConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) { projectHeading; Spacer(); projectActions }
                    VStack(alignment: .leading, spacing: 12) { projectHeading; projectActions }
                }
                if let lifecyclePreviewError {
                    RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                        Text("Project action unavailable").font(.headline)
                        Text(lifecyclePreviewError).foregroundStyle(RekonTheme.secondaryText)
                    }
                }

                HStack(spacing: 14) {
                    summaryCard("Active phase", value: project.activePhaseName, systemImage: "flag")
                    summaryCard("Current work", value: "\(project.currentWorkCount)", systemImage: "rectangle.stack")
                    summaryCard("Owner attention", value: "\(project.attentionCount)", systemImage: "person.crop.circle.badge.exclamationmark")
                }

                ProjectGoalSummaryView(context: project.goalContext)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(RekonTheme.border.opacity(0.82), lineWidth: RekonBorder.hairline)
                    }

                if project.phases.isEmpty {
                    RekonCallout(tone: .information, systemImage: "flag.badge.plus") {
                        Text("Ready for a first phase").font(.headline)
                        Text("This project is usable now. Add a phase when delivery planning begins.")
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                }
                guidanceCard
                documentationSetupControls
                SharedExecutionCompatibilityView(
                    documentationStatus: documentationStatus,
                    refresh: refreshDocumentation
                )
                if loadProjectHealth != nil {
                    ProjectHealthView(
                        snapshot: health,
                        isRefreshing: isRefreshingHealth,
                        refresh: refreshHealth,
                        reauthorize: healthReauthorizationAction,
                        manageRoots: repositoryRecovery == nil ? nil : { showsRootManagement = true }
                    )
                    if let healthRecoveryMessage {
                        Text(healthRecoveryMessage)
                            .font(.caption)
                            .foregroundStyle(RekonTheme.warning)
                            .accessibilityIdentifier("project-health-recovery-result")
                    }
                }
                if let repositoryRecovery {
                    RepositoryRecoveryView(model: repositoryRecovery, onCommitted: rootActionCommitted)
                }
                if !project.evidence.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Project evidence").font(.headline)
                        ForEach(project.evidence) { evidence in
                            EvidenceDetailView(
                                evidence: evidence,
                                documentationStatus: documentationStatus,
                                restoreFolderAccess: healthReauthorizationAction,
                                openWorktreeRecovery: repositoryRecovery == nil ? nil : { showsRootManagement = true },
                                loadPreview: loadEvidencePreview.map { loader in
                                    { await loader(evidence.id) }
                                }
                            )
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(RekonTheme.border.opacity(0.82), lineWidth: RekonBorder.hairline)
                        }
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
                                .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 10))
                                .overlay { RoundedRectangle(cornerRadius: 10).stroke(lane.lane.tint.opacity(0.6)) }
                            }
                        }
                    } else {
                        Text("Choose an existing active phase to load its five-lane board. The persisted phase and ticket history remains unchanged.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(RekonTheme.border.opacity(0.82), lineWidth: RekonBorder.hairline)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RekonTheme.background)
        .task { if health == nil { refreshHealth() } }
        .sheet(isPresented: $showsRootManagement) {
            if let repositoryRecovery {
                VStack(alignment: .trailing) {
                    ScrollView { RepositoryRecoveryView(model: repositoryRecovery, onCommitted: rootActionCommitted).padding(24) }
                    Button("Done") { showsRootManagement = false }
                        .buttonStyle(RekonSecondaryButtonStyle()).padding([.bottom, .trailing], 24)
                }
                .frame(minWidth: 520, idealWidth: 720, minHeight: 500, idealHeight: 750)
                .background(RekonTheme.background)
            }
        }
        .sheet(isPresented: $showsHelp) { ProjectLifecycleHelpView() }
        .sheet(isPresented: $showsLifecycleConfirmation) {
            if let lifecyclePreview, let archive {
                ProjectLifecycleConfirmationView(preview: lifecyclePreview) {
                    try await archive(lifecyclePreview)
                }
            }
        }
        .sheet(isPresented: $showsRemovalConfirmation) {
            if let removalPreview, let remove {
                ProjectRemovalConfirmationView(preview: removalPreview) {
                    try await remove(removalPreview)
                }
            }
        }
        .sheet(isPresented: $showsSettings) {
            if let settings, let saveProjectSettings {
                ProjectSettingsEditor(initial: settings, tasks: availableCodexTasks) { name, excluded in
                    let updated = try await saveProjectSettings(settings.registration, name, excluded)
                    self.settings = updated
                    refreshHealth()
                    return updated
                }
            }
        }
    }

    private var projectHeading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name).font(.largeTitle.weight(.semibold))
            Text("Project overview").foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private var projectActions: some View {
        HStack {
            if loadProjectSettings != nil {
                Button(isLoadingSettings ? "Loading…" : "Manage Project", action: openSettings)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(isLoadingSettings)
                    .accessibilityIdentifier("project-manage")
            }
            Button("Help") { showsHelp = true }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("project-help")
            if previewArchive != nil, archive != nil {
                Button(isLoadingLifecyclePreview ? "Preparing…" : "Archive…") { prepareArchive() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(isLoadingLifecyclePreview)
                    .accessibilityIdentifier("project-archive")
            }
            if previewRemoval != nil, remove != nil {
                Button(isLoadingLifecyclePreview ? "Preparing…" : "Remove…") { prepareRemoval() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(isLoadingLifecyclePreview)
                    .accessibilityIdentifier("project-remove")
            }
        }
    }

    private func prepareArchive() {
        guard let previewArchive else { return }
        isLoadingLifecyclePreview = true
        lifecyclePreviewError = nil
        Task {
            defer { isLoadingLifecyclePreview = false }
            do {
                lifecyclePreview = try await previewArchive()
                showsLifecycleConfirmation = true
            } catch {
                lifecyclePreviewError = error.localizedDescription
            }
        }
    }

    private func prepareRemoval() {
        guard let previewRemoval else { return }
        isLoadingLifecyclePreview = true
        lifecyclePreviewError = nil
        Task {
            defer { isLoadingLifecyclePreview = false }
            do {
                removalPreview = try await previewRemoval()
                showsRemovalConfirmation = true
            } catch {
                lifecyclePreviewError = error.localizedDescription
            }
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
                Button("Open project plan", action: openPlan)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("open-project-plan")
                Button("Open phase board", action: openBoard)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("open-phase-board")
            }
        }
    }

    private var guidanceCard: some View {
        let presentation = if case .checking = documentationStatus {
            ProjectGuidancePresentation.checking
        } else {
            ProjectGuidancePresentation(documentationState: documentationState)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label(presentation.status, systemImage: presentation.systemImage)
                .font(.headline)
            Text(presentation.detail)
                .foregroundStyle(.secondary)
            if canRestoreDocumentationFolder, let healthReauthorizationAction {
                Button("Restore folder access", action: healthReauthorizationAction)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("project-guidance-restore-folder")
            }
            if let actionTitle = presentation.actionTitle, let projectRoot {
                Text(projectRoot.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("project-guidance-authorized-root")
                Button(actionTitle) {
                    promptCopyResult = CodexPromptHandoff.copy(
                        prompt: CodexPromptHandoff.prompt(
                            for: documentationState,
                            projectRoot: projectRoot,
                            registration: health?.registration ?? settings?.registration
                        ),
                        using: CodexPromptHandoff.writeToGeneralPasteboard
                    )
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("project-guidance-copy-prompt")
            }
            if let promptCopyResult {
                Text(promptCopyResult.announcement)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(promptCopyResult == .copied ? .green : .red)
                    .accessibilityIdentifier("project-guidance-copy-result")
            }
        }
        .accessibilityElement(children: .contain)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("project-guidance-status")
    }

    @ViewBuilder
    private var documentationSetupControls: some View {
        if let registration = health?.registration ?? settings?.registration,
           previewDocumentationSetup != nil {
            RekonSectionPanel {
                Text("Documentation activation").font(.title2.weight(.semibold))
                Text("Preview the exact project, root, repository, catalog, and registration before a separate owner-confirmed binding or acceptance.")
                    .foregroundStyle(RekonTheme.secondaryText)
                Button("Preview Documentation Action") { loadDocumentationPreview(registration) }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(isPerformingDocumentationSetup)
                    .accessibilityIdentifier("project-documentation-preview")
                if let preview = documentationSetupPreview {
                    Text("\(preview.target.projectID) · root \(preview.target.rootID)")
                        .font(.caption.monospaced()).textSelection(.enabled)
                    Text("repository \(preview.target.repositoryID) · catalog v\(preview.target.catalogVersion) · \(preview.target.catalogDigest)")
                        .font(.caption.monospaced()).textSelection(.enabled)
                    switch preview.action {
                    case .bind:
                        Button("Bind This Repository", action: performPreviewedDocumentationAction)
                            .buttonStyle(RekonPrimaryButtonStyle())
                            .accessibilityIdentifier("project-documentation-bind")
                    case .accept:
                        Button("Accept This Catalog", action: performPreviewedDocumentationAction)
                            .buttonStyle(RekonPrimaryButtonStyle())
                            .accessibilityIdentifier("project-documentation-accept")
                    case .current:
                        Label("Binding and catalog acceptance are current", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(RekonTheme.success)
                    }
                }
                if let documentationSetupMessage {
                    Text(documentationSetupMessage).font(.caption).foregroundStyle(RekonTheme.secondaryText)
                }
            }
        }
    }

    private func summaryCard(_ title: String, value: String, systemImage: String) -> some View {
        RekonCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(RekonTheme.accent)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                Text(value)
                    .font(.headline)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        }
    }

    private func openSettings() {
        guard let loadProjectSettings else { return }
        isLoadingSettings = true
        Task {
            defer { isLoadingSettings = false }
            do {
                settings = try await loadProjectSettings()
                showsSettings = true
            } catch {
                health = .init(
                    projectID: project.id,
                    registration: nil,
                    rootPath: projectRoot?.path,
                    checkedAt: Date(),
                    checks: [.init(id: "settings", title: "Project settings unavailable", detail: error.localizedDescription, state: .unavailable)]
                )
            }
        }
    }

    private func rootActionCommitted() async {
        await onRepositoryRelocated()
        refreshHealth()
    }

    private func refreshHealth() {
        guard let loadProjectHealth else { return }
        healthGeneration &+= 1
        let generation = healthGeneration
        isRefreshingHealth = true
        Task {
            let result = await loadProjectHealth()
            guard generation == healthGeneration else { return }
            health = result
            isRefreshingHealth = false
        }
    }

    private func chooseAndReauthorizeProjectHealthRoot() {
        guard let reauthorizeProjectHealth, let identity = documentationStatus?.identity else {
            healthRecoveryMessage = "Reload this project before restoring its saved folder access."
            return
        }
        guard let folder = documentationFolderChooser() else {
            healthRecoveryMessage = "Folder access was not changed."
            return
        }
        healthRecoveryMessage = nil
        Task {
            do {
                health = try await reauthorizeProjectHealth(folder, identity)
            } catch {
                healthRecoveryMessage = error.localizedDescription
            }
        }
    }

    private var healthReauthorizationAction: (() -> Void)? {
        guard reauthorizeProjectHealth != nil else { return nil }
        return { chooseAndReauthorizeProjectHealthRoot() }
    }

    private var canRestoreDocumentationFolder: Bool {
        if case .checking = documentationStatus { return false }
        return switch documentationState {
        case .managedUnavailable(_, .rootUnavailable, _), .managedUnavailable(_, .staleRoot, _): true
        case .legacy(.unavailable): documentationStatus?.identity?.rootPath != nil
        default: false
        }
    }

    private func loadDocumentationPreview(_ registration: ProjectRegistration) {
        guard let previewDocumentationSetup else { return }
        isPerformingDocumentationSetup = true
        documentationSetupMessage = nil
        Task {
            defer { isPerformingDocumentationSetup = false }
            do {
                documentationSetupPreview = try await previewDocumentationSetup(registration)
            } catch {
                documentationSetupPreview = nil
                documentationSetupMessage = error.localizedDescription
            }
        }
    }

    private func performPreviewedDocumentationAction() {
        guard let preview = documentationSetupPreview, let performDocumentationSetup else { return }
        isPerformingDocumentationSetup = true
        documentationSetupMessage = nil
        Task {
            defer { isPerformingDocumentationSetup = false }
            do {
                let audit = try await performDocumentationSetup(preview)
                documentationSetupMessage = audit.map { "Owner action committed and audited as \($0.rawValue)." }
                    ?? "The accepted documentation state is already current."
                documentationSetupPreview = nil
                refreshHealth()
            } catch {
                documentationSetupMessage = error.localizedDescription
            }
        }
    }
}

struct ProjectGuidancePresentation: Equatable, Sendable {
    let status: String
    let detail: String
    let systemImage: String
    let actionTitle: String?

    static let checking = Self(
        status: "Checking documentation…",
        detail: "Validating the saved folder, accepted catalog, and evidence without changing repository or delivery state.",
        systemImage: "arrow.triangle.2.circlepath",
        actionTitle: nil
    )

    private init(status: String, detail: String, systemImage: String, actionTitle: String?) {
        self.status = status
        self.detail = detail
        self.systemImage = systemImage
        self.actionTitle = actionTitle
    }

    init(documentationState: ProjectDocumentationState) {
        switch documentationState {
        case .legacy:
            let legacy = Self(state: documentationState.guidanceState)
            status = legacy.status
            detail = legacy.detail
            systemImage = legacy.systemImage
            actionTitle = legacy.actionTitle
        case let .stagedCatalog(_, preview):
            switch preview {
            case let .valid(version, _):
                status = "Release Radar catalog staged · v\(version)"
                detail = "Legacy guidance v1 remains supported and can be upgraded to v2. The catalog passed read-only validation. Import, evidence, and delivery state are unchanged."
                systemImage = "doc.text.magnifyingglass"
            case let .invalid(error):
                status = "Release Radar staged catalog needs repair"
                detail = "Legacy guidance v1 remains supported. \(error.localizedDescription) Repair the catalog before upgrading to v2. Import, evidence, and delivery state are unchanged."
                systemImage = "exclamationmark.triangle"
            }
            actionTitle = "Copy update prompt"
        case let .managed(audited, _, _):
            let version = RepositoryDocumentContract.guidanceVersion
            status = audited ? "Release Radar managed documentation current · v\(version)" : "Release Radar managed documentation handoff incomplete · v\(version)"
            detail = "Catalog v\(version) matches this project's accepted repository and authorized root." + (audited ? " The exact guidance and audited handoff are present." : " Complete the audited guidance handoff without changing delivery state.")
            systemImage = audited ? "checkmark.circle" : "exclamationmark.arrow.triangle.2.circlepath"
            actionTitle = audited ? nil : "Copy repair prompt"
        case let .managedUnavailable(audited, reason, validationError):
            status = "Release Radar managed documentation unavailable"
            let recovery: String
            switch reason {
            case .bindingMissing:
                recovery = "Use the owner-authorized repository binding operation to bind this exact root and validated catalog."
            case .catalogUnaccepted:
                recovery = "The catalog has changed. Use the owner-authorized catalog acceptance operation to validate and accept its transition."
            case .bindingMismatch, .bindingConflict, .rootMismatch:
                recovery = "The repository or root does not match the accepted binding. Restore the accepted repository or use owner-confirmed repository recovery."
            case .rootUnavailable, .staleRoot:
                recovery = "Restore folder access or use owner-confirmed repository recovery, then reload the project."
            case .guidanceUnavailable:
                recovery = "The managed guidance changed during inspection. Restore the exact guidance block and reload the project."
            default:
                recovery = "Repair the catalog, files, indexes, and applicable checksums, then run the repository documentation check and reload." + (validationError.map { " Validation: \($0.rawValue)." } ?? "")
            }
            detail = "Guidance v2 is readable, but managed operations are closed. " + recovery + (audited ? "" : " The guidance handoff also still needs its audited evidence.")
            systemImage = "exclamationmark.triangle"
            switch reason {
            case .catalogInvalid, .guidanceUnavailable, .invalidTransition, .missingFile:
                actionTitle = "Copy repair prompt"
            default:
                actionTitle = nil
            }
        }
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
            detail = "Legacy guidance remains supported. Validate the repository catalog and indexes before using Codex to upgrade only the managed block to v2."
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

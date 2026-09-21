import RekonDesignSystem
import ReleaseRadarCore
import SwiftUI

struct ProjectHealthSnapshot: Equatable, Sendable {
    struct Check: Equatable, Identifiable, Sendable {
        enum State: Equatable, Sendable { case ready, attention, unavailable }
        let id: String
        let title: String
        let detail: String
        let state: State
    }

    let projectID: ProjectID
    let registration: ProjectRegistration?
    let rootPath: String?
    let checkedAt: Date
    let checks: [Check]

    var attentionCount: Int { checks.filter { $0.state != .ready }.count }
}

struct ApplicationHealthSnapshot: Equatable, Sendable {
    let projectTarget: ProjectRegistration?
    let rootPath: String?
    let checkedAt: Date
    let checks: [ProjectHealthSnapshot.Check]
}

struct ProjectHealthView: View {
    let snapshot: ProjectHealthSnapshot?
    let isRefreshing: Bool
    let refresh: () -> Void
    var reauthorize: (() -> Void)? = nil
    var manageRoots: (() -> Void)? = nil

    var body: some View {
        RekonSectionPanel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { heading; Spacer(); refreshButton }
                VStack(alignment: .leading, spacing: 10) { heading; refreshButton }
            }
            if let snapshot {
                Text(target(snapshot))
                    .font(.caption.monospaced())
                    .foregroundStyle(RekonTheme.secondaryText)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("project-health-target")
                ForEach(snapshot.checks) { check in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(check.state))
                            .foregroundStyle(color(check.state))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title).font(.headline)
                            Text(check.detail).font(.caption).foregroundStyle(RekonTheme.secondaryText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("project-health-\(check.id)")
                }
                if snapshot.checks.contains(where: { $0.id == "folder" && $0.state != .ready }),
                   let reauthorize {
                    Button("Restore folder access", action: reauthorize)
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("project-health-reauthorize")
                }
                if let manageRoots {
                    Button("Manage Repository Roots", action: manageRoots)
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("project-health-manage-roots")
                }
                Text("Checked \(snapshot.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Run a health check to verify local storage, folder access, documentation, Codex observation, and the installed workflow.")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
        .accessibilityIdentifier("project-health")
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Project health").font(.title2.weight(.semibold))
            Text("Read-only checks for this exact project registration")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private var refreshButton: some View {
        Button(isRefreshing ? "Checking…" : "Check Health", action: refresh)
            .buttonStyle(RekonSecondaryButtonStyle())
            .disabled(isRefreshing)
            .accessibilityIdentifier("project-health-refresh")
    }

    private func target(_ snapshot: ProjectHealthSnapshot) -> String {
        let registration = snapshot.registration.map {
            "registration \($0.registrationID) · generation \($0.requestGeneration)"
        } ?? "registration unavailable"
        return "\(snapshot.projectID.rawValue) · \(registration)\(snapshot.rootPath.map { " · \($0)" } ?? "")"
    }

    private func icon(_ state: ProjectHealthSnapshot.Check.State) -> String {
        switch state { case .ready: "checkmark.circle.fill"; case .attention: "exclamationmark.triangle.fill"; case .unavailable: "xmark.circle.fill" }
    }

    private func color(_ state: ProjectHealthSnapshot.Check.State) -> Color {
        switch state { case .ready: RekonTheme.success; case .attention: RekonTheme.warning; case .unavailable: RekonTheme.danger }
    }
}

struct ManageProjectView: View {
    @Environment(\.dismiss) private var dismiss
    let registration: ProjectRegistration
    let projectName: String
    let tasks: [CodexTaskDescriptor]
    let loadSettings: () async throws -> ProjectSettingsSnapshot
    let saveSettings: ((String, Set<String>) async throws -> ProjectSettingsSnapshot)?
    let manageExecutionHook: ((ProjectExecutionHookAction) async throws -> Void)?
    let loadExecutionAssignments: (() async throws -> [ProjectExecutionAssignment])?
    let retireExecutionAssignment: ((ProjectExecutionAssignment) async throws -> Void)?
    let recoverLostWorker: ((ProjectExecutionAssignment) async throws -> Void)?
    let reopenCurrentRegistration: (ProjectSettingsSnapshot) -> Void

    @State private var settings: ProjectSettingsSnapshot?
    @State private var staleSettings: ProjectSettingsSnapshot?
    @State private var settingsError: String?
    @State private var isLoadingSettings = true
    @State private var name = ""
    @State private var excluded: Set<String> = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var executionAssignments: [ProjectExecutionAssignment] = []
    @State private var selectedAssignmentID = ""
    @State private var isLoadingExecution = false
    @State private var executionMessage: String?
    @State private var executionFailed = false
    @State private var executionLoadFailed = false

    init(
        registration: ProjectRegistration,
        projectName: String,
        tasks: [CodexTaskDescriptor],
        initialSettings: ProjectSettingsSnapshot? = nil,
        loadSettings: @escaping () async throws -> ProjectSettingsSnapshot,
        saveSettings: ((String, Set<String>) async throws -> ProjectSettingsSnapshot)?,
        manageExecutionHook: ((ProjectExecutionHookAction) async throws -> Void)?,
        loadExecutionAssignments: (() async throws -> [ProjectExecutionAssignment])?,
        retireExecutionAssignment: ((ProjectExecutionAssignment) async throws -> Void)?,
        recoverLostWorker: ((ProjectExecutionAssignment) async throws -> Void)? = nil,
        reopenCurrentRegistration: @escaping (ProjectSettingsSnapshot) -> Void
    ) {
        self.registration = registration
        self.projectName = projectName
        self.tasks = tasks
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.manageExecutionHook = manageExecutionHook
        self.loadExecutionAssignments = loadExecutionAssignments
        self.retireExecutionAssignment = retireExecutionAssignment
        self.recoverLostWorker = recoverLostWorker
        self.reopenCurrentRegistration = reopenCurrentRegistration
        _settings = State(initialValue: initialSettings)
        _isLoadingSettings = State(initialValue: initialSettings == nil)
        _name = State(initialValue: initialSettings?.projectName ?? "")
        _excluded = State(initialValue: initialSettings?.excludedTaskIDs ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Manage Project").font(RekonTypography.screenTitle).foregroundStyle(RekonTheme.primaryText)
                VStack(alignment: .leading, spacing: 3) {
                    Text(projectName).font(.headline)
                    Text("\(registration.projectID.rawValue) · registration \(registration.registrationID) · generation \(registration.requestGeneration)")
                        .font(.caption.monospaced())
                        .foregroundStyle(RekonTheme.secondaryText)
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("manage-project-identity")

                settingsSection
                executionSection

                HStack {
                    Spacer()
                    Button("Done", action: { dismiss() })
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(minWidth: 520, idealWidth: 620, minHeight: 460, idealHeight: 640, maxHeight: 760)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
        .accessibilityIdentifier("manage-project-panel")
        .task {
            if settings == nil { await loadSettingsSection() }
        }
        .task { await loadExecutionSection() }
    }

    @ViewBuilder private var settingsSection: some View {
        RekonCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Project settings")
                    .font(.headline)
                    .accessibilityIdentifier("manage-project-section-settings")
                if isLoadingSettings {
                    ProgressView("Loading project settings…")
                } else if let settingsError {
                    RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                        Text("Project settings unavailable")
                            .font(.headline)
                            .accessibilityLabel("Project settings unavailable. \(settingsError)")
                            .accessibilityIdentifier("manage-project-section-settings-error")
                        Text(settingsError).foregroundStyle(RekonTheme.secondaryText)
                    }
                    if let staleSettings {
                        Button("Open current project registration") {
                            reopenCurrentRegistration(staleSettings)
                        }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("manage-project-section-settings-reopen")
                        .accessibilityLabel("Open current project registration")
                        .accessibilityHint("Closes the stale management view and opens the current project registration.")
                        .focusable()
                    } else {
                        Button("Retry project settings") { Task { await loadSettingsSection() } }
                            .buttonStyle(RekonSecondaryButtonStyle())
                            .accessibilityIdentifier("manage-project-section-settings-retry")
                            .accessibilityLabel("Retry project settings")
                            .accessibilityHint("Loads settings again for the selected project registration.")
                            .focusable()
                    }
                } else if settings != nil {
                    TextField("Project name", text: $name)
                        .textFieldStyle(RekonQuietTextFieldStyle())
                        .accessibilityIdentifier("project-settings-name")
                    Text("Observed Codex tasks").font(.headline)
                    if tasks.isEmpty && excluded.isEmpty {
                        Text("No tasks currently match this project folder.")
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                    ForEach(taskRows, id: \.id) { task in
                        RekonCheckbox(isOn: Binding(
                            get: { !excluded.contains(task.id) },
                            set: { include in
                                if include { excluded.remove(task.id) } else { excluded.insert(task.id) }
                            }
                        ), title: task.title, accessibilityLabel: task.title,
                           accessibilityIdentifier: "project-settings-task-\(task.id)")
                            .frame(height: 32, alignment: .leading)
                    }
                    if let saveError {
                        RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                            Text("Settings were not saved").font(.headline)
                            Text(saveError).foregroundStyle(RekonTheme.secondaryText)
                        }
                    }
                    Button(isSaving ? "Saving…" : "Save") { performSave() }
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .disabled(isSaving || saveSettings == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("project-settings-save")
                }
            }
        }
    }

    @ViewBuilder private var executionSection: some View {
        RekonCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Project execution")
                    .font(.headline)
                    .accessibilityIdentifier("manage-project-section-execution")
                Text("Update the verified Release Radar hook, or pause governed work and remove it. Close workers before removal. Conflicting edits are preserved.")
                    .font(.caption).foregroundStyle(RekonTheme.secondaryText)
                if isLoadingExecution {
                    ProgressView("Loading execution resources…")
                } else if executionLoadFailed, let executionMessage {
                    RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                        Text("Project execution unavailable").font(.headline)
                        Text(executionMessage).foregroundStyle(RekonTheme.secondaryText)
                    }
                    Button("Retry execution resources") { Task { await loadExecutionSection() } }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("manage-project-section-execution-retry")
                        .accessibilityLabel("Retry execution resources")
                        .accessibilityHint("Loads execution resources again for the selected project registration.")
                        .focusable()
                } else {
                    if manageExecutionHook != nil {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { executionButtons }
                            VStack(alignment: .leading, spacing: 10) { executionButtons }
                        }
                    }
                    if (retireExecutionAssignment != nil || recoverLostWorker != nil), !executionAssignments.isEmpty {
                        Picker("Worker resources", selection: $selectedAssignmentID) {
                            ForEach(executionAssignments, id: \.id) { assignment in
                                Text("\(assignment.work?.title ?? assignment.id) — \(assignment.state.rawValue)").tag(assignment.id)
                            }
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("project-settings-execution-assignment")
                        if recoverLostWorker != nil, selectedExecutionAssignmentCanRecover {
                            Text(selectedExecutionAssignmentNeedsRecoveryAudit
                                ? "The worker connection was recovered and its checkout and committed work were preserved, but the audit record is still pending. Finishing the audit does not complete or review the task."
                                : "Recovery preserves the checkout and committed work. It records the prior outcome as uncertain and enables only a fresh continuation; it does not complete or review the task.")
                                .font(.caption)
                                .foregroundStyle(RekonTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Button(selectedExecutionAssignmentNeedsRecoveryAudit ? "Finish recovery audit" : "Recover lost worker") {
                                performLostWorkerRecovery()
                            }
                                .buttonStyle(RekonSecondaryButtonStyle())
                                .disabled(isSaving)
                                .accessibilityIdentifier("project-settings-execution-recover")
                                .accessibilityHint(Text(selectedExecutionAssignmentNeedsRecoveryAudit
                                    ? "Records the pending audit for the existing recovered connection without repeating process or grant recovery."
                                    : "Verifies that the exact worker process is absent, releases its matching retained grant, and preserves committed work for a fresh continuation."))
                        }
                        if retireExecutionAssignment != nil {
                            Button("Retire resources and allow replacement") { performRetirement() }
                                .buttonStyle(RekonSecondaryButtonStyle())
                                .disabled(isSaving || selectedExecutionAssignment == nil)
                                .accessibilityIdentifier("project-settings-execution-retire")
                        }
                    }
                    if let executionMessage {
                        RekonCallout(tone: executionFailed ? .danger : .information, systemImage: executionFailed ? "exclamationmark.triangle" : "checkmark.circle") {
                            Text(executionMessage)
                        }
                        .accessibilityIdentifier("project-settings-execution-result")
                    }
                }
            }
        }
    }

    private var taskRows: [CodexTaskDescriptor] {
        var rows: [String: CodexTaskDescriptor] = [:]
        for task in tasks {
            rows[task.id] = task
        }
        for id in excluded where rows[id] == nil {
            rows[id] = .init(id: id, workingDirectory: URL(fileURLWithPath: "/"), title: "Excluded task \(id)")
        }
        return rows.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @ViewBuilder private var executionButtons: some View {
        Button("Update execution hook") { performExecution(.update) }
            .buttonStyle(RekonSecondaryButtonStyle()).disabled(isSaving)
            .accessibilityIdentifier("project-settings-execution-update")
        Button("Remove execution hook") { performExecution(.remove) }
            .buttonStyle(RekonSecondaryButtonStyle()).disabled(isSaving)
            .accessibilityIdentifier("project-settings-execution-remove")
        Button("Resume project workflow") { performExecution(.resume) }
            .buttonStyle(RekonSecondaryButtonStyle()).disabled(isSaving)
            .accessibilityIdentifier("project-settings-execution-resume")
    }

    private var selectedExecutionAssignment: ProjectExecutionAssignment? {
        executionAssignments.first { $0.id == selectedAssignmentID }
    }

    private var selectedExecutionAssignmentCanRecover: Bool {
        guard let assignment = selectedExecutionAssignment else { return false }
        if assignment.lostWorkerRecovery != nil {
            return assignment.retirement == nil && assignment.lostWorkerRecovery?.auditCompleted != true
                && assignment.role == .delivery && assignment.work != nil
                && assignment.launchReserved == true && assignment.connectionClosed == true
                && assignment.sessionID?.isEmpty == false && assignment.state == .stopped
                && assignment.uncertainOutcome == true
        }
        return assignment.retirement == nil
            && assignment.role == .delivery && assignment.work != nil
            && assignment.launchReserved == true && assignment.connectionClosed != true
            && assignment.sessionID?.isEmpty == false
            && [.authorized, .stopped, .unknown].contains(assignment.state)
    }

    private var selectedExecutionAssignmentNeedsRecoveryAudit: Bool {
        selectedExecutionAssignment?.lostWorkerRecovery?.auditCompleted != true
            && selectedExecutionAssignment?.lostWorkerRecovery != nil
    }

    private func loadSettingsSection() async {
        isLoadingSettings = true
        settingsError = nil
        staleSettings = nil
        defer { isLoadingSettings = false }
        do {
            let loaded = try await loadSettings()
            guard loaded.registration == registration else {
                settings = nil
                staleSettings = loaded
                settingsError = "The selected project registration changed while settings were loading. Close Manage Project and reopen it to load the current registration. No replacement settings were opened."
                return
            }
            settings = loaded
            name = loaded.projectName
            excluded = loaded.excludedTaskIDs
        } catch {
            settings = nil
            settingsError = error.localizedDescription
        }
    }

    private func loadExecutionSection(preservingFeedback: Bool = false) async {
        guard let loadExecutionAssignments else { return }
        isLoadingExecution = true
        executionLoadFailed = false
        if !preservingFeedback {
            executionFailed = false
            executionMessage = nil
        }
        defer { isLoadingExecution = false }
        do {
            executionAssignments = try await loadExecutionAssignments().filter {
                $0.registration == registration && $0.retirement?.completed != true
            }
            if !executionAssignments.contains(where: { $0.id == selectedAssignmentID }) {
                selectedAssignmentID = executionAssignments.first?.id ?? ""
            }
        } catch {
            executionLoadFailed = true
            executionFailed = true
            executionMessage = error.localizedDescription
        }
    }

    private func performSave() {
        guard let saveSettings, settings?.registration == registration else {
            settingsError = "The selected project registration is no longer current. Retry settings before saving."
            return
        }
        isSaving = true
        saveError = nil
        Task {
            defer { isSaving = false }
            do {
                let updated = try await saveSettings(name, excluded)
                guard updated.registration == registration else {
                    saveError = "The selected project registration changed while settings were saving. No replacement settings were opened."
                    return
                }
                settings = updated
                name = updated.projectName
                excluded = updated.excludedTaskIDs
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private func performExecution(_ action: ProjectExecutionHookAction) {
        guard let manageExecutionHook else { return }
        isSaving = true
        executionMessage = nil
        executionFailed = false
        Task {
            defer { isSaving = false }
            do {
                try await manageExecutionHook(action)
                switch action {
                case .remove: executionMessage = "Release Radar's hook was removed. The workflow remains disabled."
                case .update: executionMessage = "Execution hook update verified."
                case .resume: executionMessage = "Project workflow restored. Stopped and uncertain workers remain blocked; replacement work requires a fresh assignment."
                }
            } catch {
                executionFailed = true
                executionMessage = error.localizedDescription
            }
            await loadExecutionSection(preservingFeedback: true)
        }
    }

    private func performRetirement() {
        guard let retireExecutionAssignment, let expected = selectedExecutionAssignment else { return }
        isSaving = true
        executionMessage = nil
        executionFailed = false
        Task {
            defer { isSaving = false }
            do {
                try await retireExecutionAssignment(expected)
                executionMessage = "Resources retired. Replacement work requires a fresh current assignment; the prior outcome remains recorded."
            } catch {
                executionFailed = true
                executionMessage = error.localizedDescription
            }
            await loadExecutionSection(preservingFeedback: true)
        }
    }

    private func performLostWorkerRecovery() {
        guard let recoverLostWorker, let expected = selectedExecutionAssignment,
              selectedExecutionAssignmentCanRecover else { return }
        isSaving = true
        executionMessage = nil
        executionFailed = false
        Task {
            defer { isSaving = false }
            let wasFinishingAudit = expected.lostWorkerRecovery != nil
            var failure: Error?
            do {
                try await recoverLostWorker(expected)
            } catch {
                failure = error
            }
            await loadExecutionSection(preservingFeedback: true)
            if let failure {
                if executionLoadFailed {
                    executionFailed = true
                    executionMessage = "The recovery outcome could not be confirmed after the operation failed. Reload execution resources before trying again. The checkout and uncertain outcome remain preserved. \(failure.localizedDescription)"
                } else if let current = selectedExecutionAssignment,
                   current.id == expected.id,
                   let receipt = current.lostWorkerRecovery,
                   (expected.lostWorkerRecovery == nil
                        || expected.lostWorkerRecovery?.requestID == receipt.requestID) {
                    if receipt.auditCompleted == true {
                        executionFailed = false
                        executionMessage = expected.lostWorkerRecovery == nil
                            ? "Worker connection recovered and its audit finished. The checkout and committed work were preserved; task completion was not claimed."
                            : "Recovery audit finished for the existing recovered worker connection. The checkout and committed work remain preserved; task completion was not claimed."
                    } else {
                        executionFailed = true
                        executionMessage = "Worker connection recovered, but its audit record is still pending. The checkout and committed work were preserved; task completion was not claimed. Choose Finish recovery audit to reconcile the same recovery request. \(failure.localizedDescription)"
                    }
                } else {
                    executionFailed = true
                    executionMessage = "The worker connection was not recovered. \(failure.localizedDescription) The checkout, permission profile, and uncertain outcome were preserved."
                }
            } else if wasFinishingAudit {
                executionMessage = "Recovery audit finished for the existing recovered worker connection. The checkout and committed work remain preserved; task completion was not claimed."
            } else {
                executionMessage = "Worker connection recovered. The checkout and committed work were preserved; task completion was not claimed. Start a fresh continuation from this recovered assignment."
            }
        }
    }
}

struct ProjectSettingsEditor: View {
    @Environment(\.dismiss) private var dismiss
    let initial: ProjectSettingsSnapshot
    let tasks: [CodexTaskDescriptor]
    let manageExecutionHook: ((ProjectExecutionHookAction) async throws -> Void)?
    let loadExecutionAssignments: (() async throws -> [ProjectExecutionAssignment])?
    let retireExecutionAssignment: ((ProjectExecutionAssignment) async throws -> Void)?
    let save: (String, Set<String>) async throws -> ProjectSettingsSnapshot

    @State private var name: String
    @State private var excluded: Set<String>
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var executionMessage: String?
    @State private var executionFailed = false
    @State private var executionAssignments: [ProjectExecutionAssignment] = []
    @State private var selectedAssignmentID = ""

    init(
        initial: ProjectSettingsSnapshot,
        tasks: [CodexTaskDescriptor],
        manageExecutionHook: ((ProjectExecutionHookAction) async throws -> Void)? = nil,
        loadExecutionAssignments: (() async throws -> [ProjectExecutionAssignment])? = nil,
        retireExecutionAssignment: ((ProjectExecutionAssignment) async throws -> Void)? = nil,
        save: @escaping (String, Set<String>) async throws -> ProjectSettingsSnapshot
    ) {
        self.initial = initial
        self.tasks = tasks
        self.manageExecutionHook = manageExecutionHook
        self.loadExecutionAssignments = loadExecutionAssignments
        self.retireExecutionAssignment = retireExecutionAssignment
        self.save = save
        _name = State(initialValue: initial.projectName)
        _excluded = State(initialValue: initial.excludedTaskIDs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Project settings").font(RekonTypography.screenTitle).foregroundStyle(RekonTheme.primaryText)
                TextField("Project name", text: $name)
                    .textFieldStyle(RekonQuietTextFieldStyle())
                    .accessibilityIdentifier("project-settings-name")
                RekonCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Observed Codex tasks").font(.headline)
                        if tasks.isEmpty && excluded.isEmpty {
                            Text("No tasks currently match this project folder.")
                                .foregroundStyle(RekonTheme.secondaryText)
                        }
                        ForEach(taskRows, id: \.id) { task in
                            RekonCheckbox(isOn: Binding(
                                get: { !excluded.contains(task.id) },
                                set: { include in
                                    if include { excluded.remove(task.id) } else { excluded.insert(task.id) }
                                }
                            ), title: task.title, accessibilityLabel: task.title,
                               accessibilityIdentifier: "project-settings-task-\(task.id)")
                                .frame(height: 32, alignment: .leading)
                        }
                    }
                }
                if manageExecutionHook != nil {
                    RekonCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Project execution").font(.headline)
                            Text("Update the verified Release Radar hook, or pause governed work and remove it. Close workers before removal. Conflicting edits are preserved.")
                                .font(.caption).foregroundStyle(RekonTheme.secondaryText)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) { executionButtons }
                                VStack(alignment: .leading, spacing: 10) { executionButtons }
                            }
                            if retireExecutionAssignment != nil, !executionAssignments.isEmpty {
                                Picker("Worker resources", selection: $selectedAssignmentID) {
                                    ForEach(executionAssignments, id: \.id) { assignment in
                                        Text("\(assignment.work?.title ?? assignment.id) — \(assignment.state.rawValue)").tag(assignment.id)
                                    }
                                }
                                .disabled(isSaving)
                                .accessibilityIdentifier("project-settings-execution-assignment")
                                Text("After closing this worker, retire its clean checkout and matching permission profile to allow replacement work. Committed branches remain. Uncertain outcomes stay recorded; retirement does not complete the task.")
                                    .font(.caption).foregroundStyle(RekonTheme.secondaryText)
                                Button("Retire resources and allow replacement") { performRetirement() }
                                    .buttonStyle(RekonSecondaryButtonStyle())
                                    .disabled(isSaving || selectedExecutionAssignment == nil)
                                    .accessibilityIdentifier("project-settings-execution-retire")
                            }
                            if let executionMessage {
                                RekonCallout(tone: executionFailed ? .danger : .information, systemImage: executionFailed ? "exclamationmark.triangle" : "checkmark.circle") {
                                    Text(executionMessage)
                                }
                                .accessibilityIdentifier("project-settings-execution-result")
                            }
                        }
                    }
                }
                if let errorMessage {
                    RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                        Text("Settings were not saved").font(.headline)
                        Text(errorMessage).foregroundStyle(RekonTheme.secondaryText)
                    }
                }
                HStack {
                    Spacer()
                    Button("Cancel", action: { dismiss() })
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .keyboardShortcut(.cancelAction)
                        .disabled(isSaving)
                    Button(isSaving ? "Saving…" : "Save") { performSave() }
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("project-settings-save")
                }
            }
            .padding(28)
        }
        .frame(minWidth: 480, idealWidth: 580, minHeight: 380, idealHeight: 540, maxHeight: 700)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
        .task { await refreshExecutionAssignments() }
    }

    private var taskRows: [CodexTaskDescriptor] {
        var rows: [String: CodexTaskDescriptor] = [:]
        for task in tasks {
            rows[task.id] = task
        }
        for id in excluded where rows[id] == nil {
            rows[id] = .init(id: id, workingDirectory: URL(fileURLWithPath: "/"), title: "Excluded task \(id)")
        }
        return rows.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @ViewBuilder private var executionButtons: some View {
        Button("Update execution hook") { performExecution(.update) }
            .buttonStyle(RekonSecondaryButtonStyle()).disabled(isSaving)
            .accessibilityIdentifier("project-settings-execution-update")
        Button("Remove execution hook") { performExecution(.remove) }
            .buttonStyle(RekonSecondaryButtonStyle()).disabled(isSaving)
            .accessibilityIdentifier("project-settings-execution-remove")
        Button("Resume project workflow") { performExecution(.resume) }
            .buttonStyle(RekonSecondaryButtonStyle()).disabled(isSaving)
            .accessibilityIdentifier("project-settings-execution-resume")
    }

    private var selectedExecutionAssignment: ProjectExecutionAssignment? {
        executionAssignments.first { $0.id == selectedAssignmentID }
    }

    private func refreshExecutionAssignments() async {
        guard let loadExecutionAssignments else { return }
        do {
            executionAssignments = try await loadExecutionAssignments().filter { $0.retirement?.completed != true }
            if !executionAssignments.contains(where: { $0.id == selectedAssignmentID }) { selectedAssignmentID = executionAssignments.first?.id ?? "" }
        } catch { executionFailed = true; executionMessage = error.localizedDescription }
    }

    private func performRetirement() {
        guard let retireExecutionAssignment, let expected = selectedExecutionAssignment else { return }
        isSaving = true; executionMessage = nil; executionFailed = false
        Task {
            defer { isSaving = false }
            do {
                try await retireExecutionAssignment(expected)
                await refreshExecutionAssignments()
                if executionAssignments.first(where: { $0.registration.projectID == expected.registration.projectID && $0.id == expected.id })?.retirement?.replacementAllowed == true {
                    executionMessage = "Replacement work is allowed with a fresh assignment. The original configuration connection's closure remains unknown; its retirement is still incomplete."
                } else {
                    executionMessage = "Resources retired. Replacement work requires a fresh current assignment; the prior outcome remains recorded."
                }
            } catch { executionFailed = true; executionMessage = error.localizedDescription }
            await refreshExecutionAssignments()
        }
    }

    private func performExecution(_ action: ProjectExecutionHookAction) {
        guard let manageExecutionHook else { return }
        isSaving = true; executionMessage = nil; executionFailed = false
        Task {
            defer { isSaving = false }
            do {
                try await manageExecutionHook(action)
                switch action {
                case .remove: executionMessage = "Release Radar's hook was removed. The workflow remains disabled."
                case .update: executionMessage = "Execution hook update verified."
                case .resume: executionMessage = "Project workflow restored. Stopped and uncertain workers remain blocked; replacement work requires a fresh assignment."
                }
            } catch {
                executionFailed = true; executionMessage = error.localizedDescription
            }
            await refreshExecutionAssignments()
        }
    }

    private func performSave() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                _ = try await save(name, excluded)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ProjectLifecycleHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Project lifecycle help").font(RekonTypography.screenTitle).foregroundStyle(RekonTheme.primaryText)
            RekonCallout(tone: .information, systemImage: "folder.badge.gearshape") {
                Text("Initialize locally").font(.headline)
                Text("Choosing a folder saves an opaque project identity and folder authorization. A phase is optional, so you can open the project immediately.")
            }
            RekonCallout(tone: .accent, systemImage: "doc.badge.plus") {
                Text("Prepare repository documentation").font(.headline)
                Text("Copy the exact Codex bootstrap prompt. Review its preview before it writes the repository. Binding, catalog acceptance, and audited handoff remain separate owner actions.")
            }
            RekonCallout(tone: .warning, systemImage: "arrow.clockwise.circle") {
                Text("Recover safely").font(.headline)
                Text("If storage, folder access, documentation, observation, or the workflow needs attention, use Project Health for the exact target and then retry from refreshed state.")
            }
            HStack {
                Spacer()
                Button("Done", action: { dismiss() })
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 520, idealWidth: 620)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
        .accessibilityIdentifier("project-lifecycle-help")
    }
}

struct ProjectLifecycleConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: ProjectLifecyclePreview
    let confirm: () async throws -> Void
    @State private var isCommitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(actionTitle, systemImage: preview.target == .archived ? "archivebox" : "arrow.uturn.backward.circle")
                .font(RekonTypography.screenTitle)
                .foregroundStyle(RekonTheme.primaryText)
            Text(explanation).foregroundStyle(RekonTheme.secondaryText)
            RekonCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This exact project").font(.headline)
                    Text(preview.projectID.rawValue).font(.caption.monospaced()).textSelection(.enabled)
                    Text("registration \(preview.registration.registrationID) · generation \(preview.registration.requestGeneration)")
                        .font(.caption.monospaced()).foregroundStyle(RekonTheme.secondaryText).textSelection(.enabled)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) { retainedCounts }
                        VStack(alignment: .leading, spacing: 8) { retainedCounts }
                    }
                }
            }
            if preview.target == .archived {
                RekonCallout(tone: .information, systemImage: "checkmark.shield") {
                    Text("No project data will be deleted").font(.headline)
                    Text("The delivery graph, evidence references, registration identity, and history stay local. Pending notifications are suppressed and in-flight attempts are preserved as unknown.")
                        .foregroundStyle(RekonTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                RekonCallout(tone: .information, systemImage: "bell.slash") {
                    Text("Notifications stay historical").font(.headline)
                    Text("Restore makes the project active again, but it never replays notifications suppressed during archive.")
                        .foregroundStyle(RekonTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let errorMessage {
                RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                    Text("Project state was not changed").font(.headline)
                    Text(errorMessage).foregroundStyle(RekonTheme.secondaryText)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isCommitting)
                    .accessibilityLabel("Cancel")
                    .accessibilityIdentifier("project-lifecycle-cancel")
                Button(isCommitting ? "Saving…" : confirmTitle) { performConfirmation() }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(isCommitting)
                    .accessibilityLabel(confirmTitle)
                    .accessibilityIdentifier("project-lifecycle-confirm")
            }
        }
        .padding(28)
        .frame(minWidth: 500, idealWidth: 620)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
        .accessibilityIdentifier("project-lifecycle-confirmation")
    }

    @ViewBuilder private var retainedCounts: some View {
        Text("\(preview.counts.phases) phases")
        Text("\(preview.counts.tickets) tickets")
        Text("\(preview.counts.evidence) evidence items")
        Text("\(preview.counts.history) history events")
    }

    private var actionTitle: String {
        preview.target == .archived ? "Archive \(preview.projectName)?" : "Restore \(preview.projectName)?"
    }

    private var confirmTitle: String {
        preview.target == .archived ? "Archive Project" : "Restore Project"
    }

    private var explanation: String {
        preview.target == .archived
            ? "Archiving removes this project from active delivery surfaces and rejects new mutations until it is restored."
            : "Restoring returns this project to active delivery surfaces and admits new work again."
    }

    private func performConfirmation() {
        isCommitting = true
        errorMessage = nil
        Task {
            do {
                try await confirm()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isCommitting = false
            }
        }
    }
}

struct ProjectRemovalConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: ProjectRemovalPreview
    let confirm: () async throws -> Void
    @State private var isRemoving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Remove \(preview.projectName) from tracking?", systemImage: "trash")
                .font(RekonTypography.screenTitle)
                .foregroundStyle(RekonTheme.primaryText)
            Text("Release Radar will delete this project’s live delivery graph, saved folder authorization, and operational capabilities. Repository files are never changed.")
                .foregroundStyle(RekonTheme.secondaryText)
            RekonCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Exact project registration").font(.headline)
                    Text(preview.projectID.rawValue).font(.caption.monospaced()).textSelection(.enabled)
                    Text("registration \(preview.registration.registrationID) · generation \(preview.registration.requestGeneration)")
                        .font(.caption.monospaced()).foregroundStyle(RekonTheme.secondaryText).textSelection(.enabled)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) { removalCounts }
                        VStack(alignment: .leading, spacing: 8) { removalCounts }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            RekonCallout(tone: .warning, systemImage: "clock.badge.checkmark") {
                Text("Read-only history will remain").font(.headline)
                Text("Audit attribution, delivery events, review and completion context, and notification outcomes remain discoverable under Removed Projects. This action cannot be restored; add the folder again to create a new registration.")
                    .foregroundStyle(RekonTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let errorMessage {
                RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                    Text("Project was not removed").font(.headline)
                    Text(errorMessage).foregroundStyle(RekonTheme.secondaryText)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isRemoving)
                    .accessibilityIdentifier("project-removal-cancel")
                Button(isRemoving ? "Removing…" : "Remove from Tracking") { performRemoval() }
                    .buttonStyle(.borderedProminent)
                    .tint(RekonTheme.danger)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isRemoving)
                    .accessibilityIdentifier("project-removal-confirm")
            }
        }
        .padding(28)
        .frame(minWidth: 520, idealWidth: 650)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
        .accessibilityIdentifier("project-removal-confirmation")
    }

    @ViewBuilder private var removalCounts: some View {
        Text("\(preview.counts.phases) phases")
        Text("\(preview.counts.tickets) tickets")
        Text("\(preview.counts.evidence) evidence items")
        Text("\(preview.counts.history) history events")
    }

    private func performRemoval() {
        isRemoving = true
        errorMessage = nil
        Task {
            do {
                try await confirm()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isRemoving = false
            }
        }
    }
}

struct RemovedProjectView: View {
    let project: RemovedProjectRecord
    let activity: ProjectActivityProjection
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedEventID: HistoryEventIdentity?
    @State private var viewportOffset: Double?
    @State private var historyFocus: NavigationFocus? = .filterSummary

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) { heading; Spacer(); retainedCounts }
                    VStack(alignment: .leading, spacing: 14) { heading; retainedCounts }
                }
                RekonCallout(tone: .information, systemImage: "lock") {
                    Text("Retained history is read-only").font(.headline)
                    Text("This is the historical record for the removed registration. It has no saved folder access, live delivery graph, notifications, or restore action.")
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                Text("registration \(project.registration.registrationID) · generation \(project.registration.requestGeneration)")
                    .font(.caption.monospaced())
                    .foregroundStyle(RekonTheme.secondaryText)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 18)
            RekonSeparator()
            ActivityView(
                activity: activity,
                projectName: project.projectName,
                freshness: .init(state: .unavailable, lastObservedAt: nil),
                showsFreshness: false,
                selectedFilter: $selectedFilter,
                selectedEventID: $selectedEventID,
                viewportOffset: $viewportOffset,
                requestedFocus: historyFocus,
                focusChanged: { historyFocus = $0 }
            )
        }
        .background(RekonTheme.background)
        .accessibilityIdentifier("removed-project-history")
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.projectName).font(RekonTypography.screenTitle)
            Label("Removed from tracking \(project.removedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock.badge.xmark")
                .foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private var retainedCounts: some View {
        HStack(spacing: 18) {
            Text("\(project.counts.phases) phases")
            Text("\(project.counts.tickets) tickets")
            Text("\(project.counts.history) history")
        }
        .font(.caption)
        .foregroundStyle(RekonTheme.secondaryText)
    }
}

struct ArchivedProjectView: View {
    let project: ArchivedProjectProjection
    let loadHealth: (() async -> ProjectHealthSnapshot)?
    let previewRestore: () async throws -> ProjectLifecyclePreview
    let restore: (ProjectLifecyclePreview) async throws -> Void
    var previewRemoval: () async throws -> ProjectRemovalPreview = {
        throw ProjectRemovalError.projectNotFound
    }
    var remove: (ProjectRemovalPreview) async throws -> Void = { _ in }
    @State private var health: ProjectHealthSnapshot?
    @State private var lifecyclePreview: ProjectLifecyclePreview?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var showsConfirmation = false
    @State private var removalPreview: ProjectRemovalPreview?
    @State private var showsRemovalConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) { heading; Spacer(); actionButtons }
                    VStack(alignment: .leading, spacing: 12) { heading; actionButtons }
                }
                RekonCallout(tone: .information, systemImage: "lock") {
                    Text("Read-only while archived").font(.headline)
                    Text("The project graph, evidence references, registration, and history are retained. New agent, observation, and notification mutations are blocked until restore.")
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { countCards }
                    VStack(spacing: 14) { countCards }
                }
                RekonCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preserved registration").font(.headline)
                        Text(project.registration.registrationID).font(.caption.monospaced()).textSelection(.enabled)
                        Text("Request generation \(project.registration.requestGeneration)")
                            .font(.caption).foregroundStyle(RekonTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if loadHealth != nil {
                    ProjectHealthView(snapshot: health, isRefreshing: isWorking, refresh: refreshHealth)
                }
                if let errorMessage {
                    RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                        Text("Project action unavailable").font(.headline)
                        Text(errorMessage).foregroundStyle(RekonTheme.secondaryText)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RekonTheme.background)
        .task { if loadHealth != nil && health == nil { refreshHealth() } }
        .sheet(isPresented: $showsConfirmation) {
            if let lifecyclePreview {
                ProjectLifecycleConfirmationView(preview: lifecyclePreview) {
                    try await restore(lifecyclePreview)
                }
            }
        }
        .sheet(isPresented: $showsRemovalConfirmation) {
            if let removalPreview {
                ProjectRemovalConfirmationView(preview: removalPreview) {
                    try await remove(removalPreview)
                }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name).font(RekonTypography.screenTitle)
            Label("Archived project", systemImage: "archivebox")
                .foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private var restoreButton: some View {
        Button(isWorking ? "Preparing…" : "Restore Project…") { prepareRestore() }
            .buttonStyle(RekonPrimaryButtonStyle())
            .disabled(isWorking)
            .accessibilityLabel("Restore Project")
            .accessibilityIdentifier("archived-project-restore")
    }

    private var actionButtons: some View {
        HStack {
            restoreButton
            Button(isWorking ? "Preparing…" : "Remove…") { prepareRemoval() }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(isWorking)
                .accessibilityIdentifier("archived-project-remove")
        }
    }

    @ViewBuilder private var countCards: some View {
        countCard("Phases", project.counts.phases, "flag")
        countCard("Tickets", project.counts.tickets, "rectangle.stack")
        countCard("Evidence", project.counts.evidence, "paperclip")
        countCard("History", project.counts.history, "clock.arrow.circlepath")
    }

    private func countCard(_ title: String, _ value: Int64, _ image: String) -> some View {
        RekonCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: image).foregroundStyle(RekonTheme.accent)
                Text("\(value)").font(RekonTypography.sectionTitle)
                Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        }
    }

    private func prepareRestore() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                lifecyclePreview = try await previewRestore()
                showsConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshHealth() {
        guard let loadHealth else { return }
        isWorking = true
        Task {
            health = await loadHealth()
            isWorking = false
        }
    }

    private func prepareRemoval() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                removalPreview = try await previewRemoval()
                showsRemovalConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

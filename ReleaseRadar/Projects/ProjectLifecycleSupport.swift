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
                    Button("Reauthorize Saved Folder…", action: reauthorize)
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

struct ProjectSettingsEditor: View {
    @Environment(\.dismiss) private var dismiss
    let initial: ProjectSettingsSnapshot
    let tasks: [CodexTaskDescriptor]
    let save: (String, Set<String>) async throws -> ProjectSettingsSnapshot

    @State private var name: String
    @State private var excluded: Set<String>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        initial: ProjectSettingsSnapshot,
        tasks: [CodexTaskDescriptor],
        save: @escaping (String, Set<String>) async throws -> ProjectSettingsSnapshot
    ) {
        self.initial = initial
        self.tasks = tasks
        self.save = save
        _name = State(initialValue: initial.projectName)
        _excluded = State(initialValue: initial.excludedTaskIDs)
    }

    var body: some View {
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
        .frame(minWidth: 480, idealWidth: 580, minHeight: 380)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
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

struct ArchivedProjectView: View {
    let project: ArchivedProjectProjection
    let loadHealth: (() async -> ProjectHealthSnapshot)?
    let previewRestore: () async throws -> ProjectLifecyclePreview
    let restore: (ProjectLifecyclePreview) async throws -> Void
    @State private var health: ProjectHealthSnapshot?
    @State private var lifecyclePreview: ProjectLifecyclePreview?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var showsConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) { heading; Spacer(); restoreButton }
                    VStack(alignment: .leading, spacing: 12) { heading; restoreButton }
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
                        Text("Restore preview unavailable").font(.headline)
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
}

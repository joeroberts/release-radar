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
            Text("Project settings").font(.largeTitle.weight(.semibold))
            TextField("Project name", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("project-settings-name")
            RekonCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Observed Codex tasks").font(.headline)
                    if tasks.isEmpty && excluded.isEmpty {
                        Text("No tasks currently match this project folder.")
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                    ForEach(taskRows, id: \.id) { task in
                        Toggle(task.title, isOn: Binding(
                            get: { !excluded.contains(task.id) },
                            set: { include in
                                if include { excluded.remove(task.id) } else { excluded.insert(task.id) }
                            }
                        ))
                        .accessibilityIdentifier("project-settings-task-\(task.id)")
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
            Text("Project lifecycle help").font(.largeTitle.weight(.semibold))
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
            HStack { Spacer(); Button("Done", action: { dismiss() }).keyboardShortcut(.defaultAction) }
        }
        .padding(28)
        .frame(minWidth: 520, idealWidth: 620)
        .accessibilityIdentifier("project-lifecycle-help")
    }
}

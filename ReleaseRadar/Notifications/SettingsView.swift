import AppKit
import ReleaseRadarCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var pendingPluginConfirmation: PluginConfirmation?
    @FocusState private var focusedPluginAction: CodexPluginLifecycleAction?

    var body: some View {
        TabView {
            general
                .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.systemImage) }
                .accessibilityIdentifier(SettingsTab.general.accessibilityID)
            connections
                .tabItem { Label(SettingsTab.connections.title, systemImage: SettingsTab.connections.systemImage) }
                .accessibilityIdentifier(SettingsTab.connections.accessibilityID)
            notifications
                .tabItem { Label(SettingsTab.notifications.title, systemImage: SettingsTab.notifications.systemImage) }
                .accessibilityIdentifier(SettingsTab.notifications.accessibilityID)
            projects
                .tabItem { Label(SettingsTab.projects.title, systemImage: SettingsTab.projects.systemImage) }
                .accessibilityIdentifier(SettingsTab.projects.accessibilityID)
        }
        .frame(width: 680, height: 560)
        .scenePadding()
        .accessibilityIdentifier("content-settings")
    }

    private var general: some View {
        Form {
            Section("Release Radar By Rekon Labs") {
                LabeledContent("Storage", value: "Local app-owned database")
                LabeledContent("Delivery lanes", value: "Five persisted states")
                Text("Runtime observations never change a formal delivery lane.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var connections: some View {
        let plugin = CodexPluginSettingsPresentation(
            state: model.codexPluginState,
            operation: model.codexPluginOperation
        )
        return Form {
            Section("Release Radar Codex Plugin") {
                LabeledContent {
                    Text(plugin.status)
                } label: {
                    Label("Status", systemImage: plugin.systemImage)
                }
                .accessibilityIdentifier("codex-plugin-status")
                .accessibilityLabel("Release Radar Codex Plugin status: \(plugin.status)")

                LabeledContent("Shipped version", value: model.codexPluginShippedVersion)
                Text(plugin.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = model.codexPluginSettingsMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("codex-plugin-result")
                }

                pluginActions(plugin.actions)
            }

            Section("Codex live observation") {
                if let codexFailure = FailureStatePresentation(freshness: model.codexSnapshot.freshness) {
                    FailureStateView(presentation: codexFailure, style: .compact)
                } else {
                    LabeledContent("Observation", value: "Available")
                }
                Text("No supported live attachment is configured. Cached observations are shown only as stale.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Agent action bridge") {
                Text("Typed, authenticated delivery actions are handled by the app and audited locally.")
                    .foregroundStyle(.secondary)
            }
            Section("Pushover") {
                LabeledContent("Connection", value: model.isPushoverConfigured ? "Ready" : "Not configured")
                Text("Credentials are stored in the app's device-only Keychain items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            pendingPluginConfirmation?.title ?? "",
            isPresented: Binding(
                get: { pendingPluginConfirmation != nil },
                set: { if !$0 { cancelPluginConfirmation() } }
            ),
            titleVisibility: .visible
        ) {
            switch pendingPluginConfirmation {
            case .remove:
                Button("Remove", role: .destructive) {
                    pendingPluginConfirmation = nil
                    focusedPluginAction = nil
                    Task { await model.removeCodexPlugin() }
                }
                Button("Cancel", role: .cancel) { cancelPluginConfirmation() }
                    .keyboardShortcut(.defaultAction)
            case .reinstall:
                Button("Reinstall", role: .destructive) {
                    pendingPluginConfirmation = nil
                    focusedPluginAction = nil
                    Task { await model.reinstallCodexPlugin() }
                }
                Button("Cancel", role: .cancel) { cancelPluginConfirmation() }
                    .keyboardShortcut(.defaultAction)
            case nil:
                EmptyView()
            }
        } message: {
            if let pendingPluginConfirmation {
                Text(pendingPluginConfirmation.message)
            }
        }
        .onChange(of: model.codexPluginAnnouncement) { _, announcement in
            guard let announcement else { return }
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: announcement,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
    }

    @ViewBuilder
    private func pluginActions(_ actions: [CodexPluginLifecycleAction]) -> some View {
        if !actions.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack { pluginActionButtons(actions) }
                VStack(alignment: .leading) { pluginActionButtons(actions) }
            }
        }
    }

    @ViewBuilder
    private func pluginActionButtons(_ actions: [CodexPluginLifecycleAction]) -> some View {
        ForEach(actions, id: \.rawValue) { action in
            switch action {
            case .install:
                Button("Install") { Task { await model.installCodexPlugin() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("codex-plugin-install")
            case .update:
                Button("Update") { Task { await model.updateCodexPlugin() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("codex-plugin-update")
            case .remove:
                Button("Remove", role: .destructive) { pendingPluginConfirmation = .remove }
                    .accessibilityIdentifier("codex-plugin-remove")
                    .focused($focusedPluginAction, equals: .remove)
            case .reinstall:
                Button("Reinstall") { pendingPluginConfirmation = .reinstall }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("codex-plugin-reinstall")
                    .focused($focusedPluginAction, equals: .reinstall)
            case .tryAgain:
                Button("Try Again") { Task { await model.loadCodexPluginStatus(retrying: true) } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("codex-plugin-retry")
            }
        }
    }

    private func cancelPluginConfirmation() {
        let action = pendingPluginConfirmation?.returnFocusAction
        pendingPluginConfirmation = nil
        DispatchQueue.main.async {
            focusedPluginAction = action
        }
    }

    private var notifications: some View {
        Form {
            Section("Pushover") {
                LabeledContent("Status", value: model.isPushoverConfigured ? "Ready" : "Not configured")
                SecureField("Application token", text: $model.pushoverAppToken)
                    .textContentType(.password)
                SecureField("User key", text: $model.pushoverUserKey)
                    .textContentType(.password)
                HStack {
                    Button("Save credentials") {
                        Task { await model.savePushoverCredentials() }
                    }
                    Button("Remove", role: .destructive) {
                        Task { await model.removePushoverCredentials() }
                    }
                    .disabled(!model.isPushoverConfigured)
                }
                if let message = model.pushoverSettingsMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Alert rules") {
                if let rules = model.alertRules {
                    alertRuleToggle(
                        "Blocked linked goals",
                        kind: .blockedLinkedGoals,
                        accessibilityID: "alert-blocked-goals",
                        rules: rules
                    )
                    alertRuleToggle(
                        "Agent completion and review",
                        kind: .agentCompletionAndReview,
                        accessibilityID: "alert-agent-completion-review",
                        rules: rules
                    )
                    alertRuleToggle(
                        "Needs Review entry",
                        kind: .needsReviewEntry,
                        accessibilityID: "alert-needs-review",
                        rules: rules
                    )
                    alertRuleToggle(
                        "Paused goals",
                        kind: .pausedGoals,
                        accessibilityID: "alert-paused-goals",
                        rules: rules
                    )
                }
                if let failure = model.alertRulesFailure {
                    FailureStateView(presentation: failure, style: .compact)
                    Button("Retry") {
                        Task { await model.retryAlertRules() }
                    }
                    .accessibilityIdentifier("alert-rules-retry")
                } else if model.alertRules == nil {
                    ProgressView("Loading saved alert rules…")
                        .controlSize(.small)
                        .accessibilityIdentifier("alert-rules-loading")
                }
                Text("Alerts are created only after the project's dashboard has been opened once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func alertRuleToggle(
        _ title: String,
        kind: AlertRuleKind,
        accessibilityID: String,
        rules: AlertRuleSnapshot
    ) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { rules[kind] },
                set: { enabled in
                    Task { await model.setAlertRule(kind, enabled: enabled) }
                }
            )
        )
        .disabled(model.alertRuleControlsDisabled)
        .accessibilityIdentifier(accessibilityID)
    }

    private var projects: some View {
        Form {
            Section("Local projects") {
                if let projects = model.dashboard?.projects, !projects.isEmpty {
                    ForEach(projects) { project in
                        LabeledContent(project.name, value: project.activePhaseName)
                    }
                } else {
                    Text("No project data is available.")
                        .foregroundStyle(.secondary)
                }
                Text("Folder authorization and worktree access are managed during project onboarding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private enum PluginConfirmation: Identifiable {
    case remove
    case reinstall

    var id: Self { self }

    var title: String {
        switch self {
        case .remove: "Remove Release Radar Codex Plugin?"
        case .reinstall: "Reinstall Release Radar Codex Plugin?"
        }
    }

    var message: String {
        switch self {
        case .remove:
            "This removes the managed Codex plugin. It does not remove Release Radar delivery records."
        case .reinstall:
            "This replaces the managed plugin with the version shipped by Release Radar and may overwrite local plugin modifications."
        }
    }

    var returnFocusAction: CodexPluginLifecycleAction {
        switch self {
        case .remove: .remove
        case .reinstall: .reinstall
        }
    }
}

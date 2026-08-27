import ReleaseRadarCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

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
        .frame(width: 620, height: 420)
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
        return Form {
            Section("Codex") {
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

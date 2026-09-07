import AppKit
import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var pendingPluginConfirmation: PluginConfirmation?
    @State private var applicationHealth: ApplicationHealthSnapshot?
    @State private var isCheckingApplicationHealth = false
    @State private var applicationHealthGeneration: UInt64 = 0
    @State private var selectedTab: SettingsTab = .connections
    @FocusState private var focusedPluginAction: CodexPluginLifecycleAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RekonScreenHeader(title: "Settings", subtitle: "Configure local integrations and delivery behavior")

            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(SettingsTab.allCases) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                VStack(spacing: 10) {
                                    Text(tab.title)
                                        .font(RekonTypography.controlLabel)
                                    Capsule()
                                        .fill(selectedTab == tab ? RekonTheme.accent : .clear)
                                        .frame(height: 3)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: max(132, geometry.size.width / CGFloat(SettingsTab.allCases.count)))
                            .foregroundStyle(selectedTab == tab ? RekonTheme.primaryText : RekonTheme.secondaryText)
                            .accessibilityIdentifier(tab.accessibilityID)
                            .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                        }
                    }
                }
            }
            .frame(height: 52)

            Rectangle().fill(RekonTheme.borderSubtle).frame(height: 1)

            Group {
                switch selectedTab {
                case .general: general
                case .connections: connections
                case .notifications: notifications
                case .projects: projects
                }
            }
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .background(RekonTheme.background)
        .accessibilityIdentifier("content-settings")
    }

    private var general: some View {
        settingsScroll {
            RekonSectionPanel {
                settingsSectionHeader("Release Radar By Rekon Labs", systemImage: "radar")
                LabeledContent("Storage", value: "Local app-owned database")
                LabeledContent("Delivery lanes", value: "Five persisted states")
                Text("Runtime observations never change a formal delivery lane.")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
    }

    private var connections: some View {
        let plugin = CodexPluginSettingsPresentation(
            state: model.codexPluginState,
            operation: model.codexPluginOperation
        )
        return settingsScroll {
            RekonSectionPanel {
                settingsSectionHeader("Release Radar Codex Plugin", systemImage: "puzzlepiece.extension")
                LabeledContent {
                    RekonBadge(plugin.status, tone: plugin.badgeTone, systemImage: plugin.systemImage)
                } label: {
                    Label("Status", systemImage: plugin.systemImage)
                }
                .accessibilityIdentifier("codex-plugin-status")
                .accessibilityLabel("Release Radar Codex Plugin status: \(plugin.status)")

                LabeledContent("Shipped version", value: model.codexPluginShippedVersion)
                Text(plugin.detail)
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)

                if let recovery = plugin.recoveryDetail {
                    RekonCallout(tone: .warning, systemImage: "exclamationmark.triangle") {
                        Text("Recovery")
                            .font(RekonTypography.controlLabelEmphasized)
                        Text(recovery)
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                }

                if let message = plugin.uniqueOperationMessage(model.codexPluginSettingsMessage) {
                    Text(message)
                        .font(RekonTypography.metadata)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .accessibilityIdentifier("codex-plugin-result")
                }

                pluginActions(plugin.actions)
            }

            RekonSectionPanel {
                settingsSectionHeader("Codex live observation", systemImage: "bolt.horizontal.circle")
                if let codexFailure = FailureStatePresentation(freshness: model.codexSnapshot.freshness) {
                    FailureStateView(presentation: codexFailure, style: .compact)
                } else {
                    LabeledContent { RekonBadge("Available", tone: .success) } label: { Text("Observation") }
                }
                Text("No supported live attachment is configured. Cached observations are shown only as stale.")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            RekonSectionPanel {
                settingsSectionHeader("Agent action bridge", systemImage: "arrow.left.arrow.right")
                Text("Typed, authenticated delivery actions are handled by the app and audited locally.")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            RekonSectionPanel {
                settingsSectionHeader("Pushover", systemImage: "bell")
                LabeledContent {
                    RekonBadge(model.isPushoverConfigured ? "Ready" : "Not configured", tone: model.isPushoverConfigured ? .success : .neutral)
                } label: { Text("Connection") }
                Text("Credentials are stored in the app's device-only Keychain items.")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
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
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("codex-plugin-install")
            case .update:
                Button("Update") { Task { await model.updateCodexPlugin() } }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("codex-plugin-update")
            case .remove:
                Button("Remove", role: .destructive) { pendingPluginConfirmation = .remove }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("codex-plugin-remove")
                    .focused($focusedPluginAction, equals: .remove)
            case .reinstall:
                Button("Reinstall") { pendingPluginConfirmation = .reinstall }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("codex-plugin-reinstall")
                    .focused($focusedPluginAction, equals: .reinstall)
            case .tryAgain:
                Button("Try Again") { Task { await model.loadCodexPluginStatus(retrying: true) } }
                    .buttonStyle(RekonPrimaryButtonStyle())
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
        settingsScroll {
            RekonSectionPanel {
                settingsSectionHeader("Pushover", systemImage: "bell")
                LabeledContent("Status", value: model.isPushoverConfigured ? "Ready" : "Not configured")
                SecureField("Application token", text: $model.pushoverAppToken)
                    .textContentType(.password)
                    .textFieldStyle(RekonQuietTextFieldStyle())
                SecureField("User key", text: $model.pushoverUserKey)
                    .textContentType(.password)
                    .textFieldStyle(RekonQuietTextFieldStyle())
                HStack {
                    Button("Save credentials") {
                        Task { await model.savePushoverCredentials() }
                    }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    Button("Remove", role: .destructive) {
                        Task { await model.removePushoverCredentials() }
                    }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(!model.isPushoverConfigured)
                }
                if let message = model.pushoverSettingsMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            RekonSectionPanel {
                settingsSectionHeader("Alert rules", systemImage: "checkmark.shield")
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
    }

    private func alertRuleToggle(
        _ title: String,
        kind: AlertRuleKind,
        accessibilityID: String,
        rules: AlertRuleSnapshot
    ) -> some View {
        RekonCheckbox(
            isOn: Binding(
                get: { rules[kind] },
                set: { enabled in
                    Task { await model.setAlertRule(kind, enabled: enabled) }
                }
            ),
            title: title,
            accessibilityLabel: title,
            accessibilityIdentifier: accessibilityID
        )
        .frame(height: 32, alignment: .leading)
        .disabled(model.alertRuleControlsDisabled)
    }

    private var projects: some View {
        settingsScroll {
            RekonSectionPanel {
                settingsSectionHeader("Application health", systemImage: "heart.text.square")
                if let applicationHealth {
                    if let target = applicationHealth.projectTarget {
                        Text("\(target.projectID.rawValue) · registration \(target.registrationID) · generation \(target.requestGeneration)\(applicationHealth.rootPath.map { " · \($0)" } ?? "")")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .accessibilityIdentifier("settings-health-target")
                    } else {
                        Text("No project target is available. Storage, plugin, and observer recovery remain accessible here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(applicationHealth.checks) { check in
                        LabeledContent(check.title, value: check.detail)
                            .accessibilityIdentifier("settings-health-\(check.id)")
                    }
                    Text("Checked \(applicationHealth.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Check local storage, folder access, documentation, Codex observation, and the installed workflow.")
                        .foregroundStyle(.secondary)
                }
                Button(isCheckingApplicationHealth ? "Checking…" : "Check Health") {
                    refreshApplicationHealth()
                }
                .disabled(isCheckingApplicationHealth)
                .accessibilityIdentifier("settings-health-refresh")
            }
            RekonSectionPanel {
                settingsSectionHeader("Local projects", systemImage: "folder")
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
        .task { refreshApplicationHealth() }
    }

    private func settingsSectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(RekonTypography.cardTitle)
            .foregroundStyle(RekonTheme.primaryText)
    }

    private func settingsScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
    }

    private func refreshApplicationHealth() {
        applicationHealthGeneration &+= 1
        let generation = applicationHealthGeneration
        isCheckingApplicationHealth = true
        Task {
            let health = await model.applicationHealth()
            guard generation == applicationHealthGeneration else { return }
            applicationHealth = health
            isCheckingApplicationHealth = false
        }
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

private extension CodexPluginSettingsPresentation {
    var badgeTone: RekonTone {
        switch state {
        case .installed: .success
        case .checking, .notInstalled: .neutral
        case .updateAvailable: .information
        case .modified, .needsRepair: .warning
        case .failed: .danger
        }
    }
}

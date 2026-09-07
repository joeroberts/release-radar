import AppKit
import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

enum SettingsLayout {
    static let horizontalPadding: CGFloat = 28

    static func contentWidth(for availableWidth: CGFloat) -> CGFloat {
        max(0, availableWidth - horizontalPadding * 2)
    }
}

enum ApplicationHealthAction: Equatable {
    case openProject
    case reviewConnections
    case checkAgain
    case restoreBackup

    var title: String {
        switch self {
        case .openProject: "Open Project"
        case .reviewConnections: "Review Connection"
        case .checkAgain: "Check Again"
        case .restoreBackup: "Restore Backup"
        }
    }

    static func recommended(
        forCheckID id: String,
        state: ProjectHealthSnapshot.Check.State,
        hasProjectTarget: Bool
    ) -> ApplicationHealthAction? {
        guard state != .ready else { return nil }
        if id == "roots" || id.hasPrefix("root:") { return hasProjectTarget ? .openProject : .checkAgain }
        switch id {
        case "recovery":
            return .restoreBackup
        case "folder", "documentation":
            return hasProjectTarget ? .openProject : nil
        case "plugin", "observer":
            return .reviewConnections
        case "storage":
            return .checkAgain
        default:
            return nil
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var pendingPluginConfirmation: PluginConfirmation?
    @State private var applicationHealth: ApplicationHealthSnapshot?
    @State private var isCheckingApplicationHealth = false
    @State private var applicationHealthGeneration: UInt64 = 0
    @State private var selectedTab: SettingsTab = .connections
    @State private var pendingRecoveryConfirmation: RecoveryConfirmation?
    @State private var recoveryRetryAction: RecoveryRetryAction?
    @FocusState private var focusedPluginAction: CodexPluginLifecycleAction?

    init(model: AppModel, selectedTab: SettingsTab = .connections) {
        self.model = model
        _selectedTab = State(initialValue: selectedTab)
    }

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

            RekonSeparator()

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
        .confirmationDialog(
            pendingRecoveryConfirmation?.title ?? "",
            isPresented: Binding(
                get: { pendingRecoveryConfirmation != nil },
                set: { if !$0 { pendingRecoveryConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            recoveryConfirmationButtons
            Button("Cancel", role: .cancel) { pendingRecoveryConfirmation = nil }
                .keyboardShortcut(.defaultAction)
        } message: {
            if let pendingRecoveryConfirmation {
                Text(pendingRecoveryConfirmation.message)
            }
        }
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
            RekonSectionPanel {
                settingsSectionHeader("Backup and recovery", systemImage: "externaldrive.badge.timemachine")
                Text("A full backup contains the supported local database, preferences, history, plugin receipts and notification history.")
                    .foregroundStyle(RekonTheme.secondaryText)
                Text("Credentials, source repositories, portable project files and device permission grants are never included.")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
                ViewThatFits(in: .horizontal) {
                    HStack { backupAndRestoreButtons }
                    VStack(alignment: .leading) { backupAndRestoreButtons }
                }
            }
            RekonSectionPanel {
                settingsSectionHeader("Reset application preferences", systemImage: "arrow.counterclockwise.circle")
                Text("Restore the four alert-rule defaults and clear temporary view selections. Projects, tracking history, plugin management and Keychain credentials remain unchanged.")
                    .foregroundStyle(RekonTheme.secondaryText)
                Button("Reset Preferences…", role: .destructive) {
                    pendingRecoveryConfirmation = .preferences
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(model.applicationRecoveryInFlight)
                .accessibilityIdentifier("application-preferences-reset")
            }
            recoveryFeedback
        }
    }

    @ViewBuilder
    private var backupAndRestoreButtons: some View {
        Button("Create Backup…") { chooseBackupDestination() }
            .buttonStyle(RekonPrimaryButtonStyle())
            .disabled(model.applicationRecoveryInFlight)
            .accessibilityIdentifier("application-backup-create")
        Button("Restore Backup…", role: .destructive) { chooseRestorePackage() }
            .buttonStyle(RekonSecondaryButtonStyle())
            .disabled(model.applicationRecoveryInFlight)
            .accessibilityIdentifier("application-backup-restore")
    }

    @ViewBuilder
    private var recoveryFeedback: some View {
        if model.applicationRecoveryInFlight {
            ProgressView("Coordinating application recovery…")
                .controlSize(.small)
                .accessibilityIdentifier("application-recovery-progress")
        }
        if let failure = model.applicationRecoveryFailure {
            FailureStateView(presentation: failure, style: .compact)
            Button("Try Again") {
                model.applicationRecoveryFailure = nil
                retryRecoveryAction()
            }
            .buttonStyle(RekonSecondaryButtonStyle())
            .accessibilityIdentifier("application-recovery-retry")
        }
        if let message = model.applicationRecoveryMessage {
            RekonCallout(tone: .success, systemImage: "checkmark.circle") {
                Text("Recovery complete").font(RekonTypography.controlLabelEmphasized)
                Text(message).foregroundStyle(RekonTheme.secondaryText)
            }
            .accessibilityIdentifier("application-recovery-success")
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
        RekonCard {
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
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .disabled(model.alertRuleControlsDisabled)
    }

    private var projects: some View {
        settingsScroll {
            ApplicationHealthPanel(
                snapshot: applicationHealth,
                isRefreshing: isCheckingApplicationHealth,
                refresh: refreshApplicationHealth,
                openProject: openApplicationHealthProject,
                reviewConnections: { selectedTab = .connections },
                restoreBackup: {
                    selectedTab = .general
                    chooseRestorePackage()
                }
            )
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
            RekonSectionPanel {
                settingsSectionHeader("Reset tracking data", systemImage: "trash.slash")
                Text("Remove every active and archived project registration using retained-history semantics. Global preferences, plugin receipts and removal history are preserved.")
                    .foregroundStyle(RekonTheme.secondaryText)
                Button("Reset Tracking Data…", role: .destructive) { prepareTrackingReset() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(model.applicationRecoveryInFlight)
                    .accessibilityIdentifier("application-tracking-reset")
            }
            recoveryFeedback
        }
        .task { refreshApplicationHealth() }
    }

    private func settingsSectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(RekonTypography.cardTitle)
            .foregroundStyle(RekonTheme.primaryText)
    }

    private func settingsScroll<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .frame(width: SettingsLayout.contentWidth(for: geometry.size.width), alignment: .leading)
                .padding(.horizontal, SettingsLayout.horizontalPadding)
                .padding(.vertical, 28)
            }
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

    private func openApplicationHealthProject() {
        guard let projectID = applicationHealth?.projectTarget?.projectID else { return }
        Task { await model.navigate(to: .projectOverview(projectID)) }
    }

    private func chooseBackupDestination() {
        guard let url = ApplicationRecoveryFilePanels.chooseBackupDestination() else { return }
        recoveryRetryAction = .backup
        Task {
            do {
                pendingRecoveryConfirmation = .backup(try await model.previewApplicationBackup(destinationURL: url))
            } catch {
                model.presentApplicationRecoveryFailure(error)
            }
        }
    }

    private func chooseRestorePackage() {
        guard let url = ApplicationRecoveryFilePanels.chooseRestorePackage() else { return }
        recoveryRetryAction = .restore
        Task {
            do {
                pendingRecoveryConfirmation = .restore(try await model.previewApplicationRestore(packageURL: url))
            } catch {
                model.presentApplicationRecoveryFailure(error)
            }
        }
    }

    private func prepareTrackingReset() {
        recoveryRetryAction = .tracking
        Task {
            do {
                pendingRecoveryConfirmation = .tracking(try await model.previewTrackingReset())
            } catch {
                model.presentApplicationRecoveryFailure(error)
            }
        }
    }

    @ViewBuilder
    private var recoveryConfirmationButtons: some View {
        switch pendingRecoveryConfirmation {
        case let .backup(preview):
            Button("Create Backup") {
                pendingRecoveryConfirmation = nil
                recoveryRetryAction = .backup
                Task { await model.createApplicationBackup(preview) }
            }
        case let .restore(preview):
            Button("Restore Backup", role: .destructive) {
                pendingRecoveryConfirmation = nil
                recoveryRetryAction = .restore
                Task { await model.restoreApplicationBackup(preview) }
            }
        case .preferences:
            Button("Reset Preferences", role: .destructive) {
                pendingRecoveryConfirmation = nil
                recoveryRetryAction = .preferences
                Task { await model.resetApplicationPreferences() }
            }
        case let .tracking(preview):
            Button("Reset Tracking Data", role: .destructive) {
                pendingRecoveryConfirmation = nil
                recoveryRetryAction = .tracking
                Task { await model.resetTracking(preview) }
            }
        case nil:
            EmptyView()
        }
    }

    private func retryRecoveryAction() {
        switch recoveryRetryAction {
        case .backup: chooseBackupDestination()
        case .restore: chooseRestorePackage()
        case .preferences: pendingRecoveryConfirmation = .preferences
        case .tracking: prepareTrackingReset()
        case nil: break
        }
    }
}

private enum RecoveryRetryAction {
    case backup
    case restore
    case preferences
    case tracking
}

private enum RecoveryConfirmation: Equatable {
    case backup(ApplicationBackupPreview)
    case restore(ApplicationRestorePreview)
    case preferences
    case tracking(ApplicationTrackingResetPreview)

    var title: String {
        switch self {
        case .backup: "Create Full Backup?"
        case .restore: "Restore This Backup?"
        case .preferences: "Reset Application Preferences?"
        case .tracking: "Reset All Tracking Data?"
        }
    }

    var message: String {
        switch self {
        case let .backup(preview):
            return "Back up \(preview.projectCount) project\(preview.projectCount == 1 ? "" : "s") plus local preferences, history, audits, plugin receipts and notification history. Credentials, repositories, portable project files and device permissions are excluded."
        case let .restore(preview):
            let reconciliation = preview.newerHistoryReconciliationAvailable
                ? "Newer local removal, audit and terminal notification facts will be reconciled."
                : "The current store is unreadable; newer local history cannot be reconciled and will be reported unavailable."
            return "Restore \(preview.restoredRegistrations.count) saved registration\(preview.restoredRegistrations.count == 1 ? "" : "s") and displace \(preview.displacedRegistrations.count) current registration\(preview.displacedRegistrations.count == 1 ? "" : "s"). \(reconciliation) Saved folder permissions will require reauthorization. Backed-up pending notifications will not be sent."
        case .preferences:
            return "Blocked-goal, completion-review and needs-review alerts will be enabled; paused-goal alerts will be disabled. Tracking data, history, plugin receipts and credentials are preserved."
        case let .tracking(preview):
            return "Remove \(preview.projects.count) active or archived project registration\(preview.projects.count == 1 ? "" : "s"). Retained activity, audits, prior removals, global preferences and plugin receipts remain available. This does not delete source repositories or credentials."
        }
    }
}

struct ApplicationHealthPanel: View {
    let snapshot: ApplicationHealthSnapshot?
    let isRefreshing: Bool
    let refresh: () -> Void
    let openProject: () -> Void
    let reviewConnections: () -> Void
    let restoreBackup: () -> Void
    @State private var showsTechnicalDetails = false

    var body: some View {
        RekonSectionPanel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    heading
                    Spacer(minLength: 16)
                    refreshButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    heading
                    refreshButton
                }
            }

            if let snapshot {
                RekonBadge(summary, tone: attentionCount == 0 ? .success : .warning, systemImage: attentionCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
                    .accessibilityIdentifier("settings-health-summary")

                VStack(spacing: 10) {
                    ForEach(snapshot.checks) { check in
                        checkRow(check, hasProjectTarget: snapshot.projectTarget != nil)
                    }
                }

                DisclosureGroup("Technical details", isExpanded: $showsTechnicalDetails) {
                    technicalDetails(snapshot)
                        .padding(.top, 10)
                }
                .font(RekonTypography.controlLabel)
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("settings-health-technical-details")

                Text("Checked \(snapshot.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(RekonTheme.secondaryText)
            } else {
                Text("Check local storage, folder access, repository documentation, Codex observation, and the installed workflow.")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
        .accessibilityIdentifier("settings-application-health")
    }

    private var attentionCount: Int {
        snapshot?.checks.filter { $0.state != .ready }.count ?? 0
    }

    private var summary: String {
        switch attentionCount {
        case 0: "All checks are ready"
        case 1: "1 check needs attention"
        default: "\(attentionCount) checks need attention"
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Application health", systemImage: "heart.text.square")
                .font(RekonTypography.cardTitle)
                .foregroundStyle(RekonTheme.primaryText)
            Text("See what is ready and go directly to the surface that can resolve each problem.")
                .font(RekonTypography.metadata)
                .foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private var refreshButton: some View {
        Button(isRefreshing ? "Checking…" : (snapshot == nil ? "Check Application Health" : "Check Again"), action: refresh)
            .buttonStyle(RekonSecondaryButtonStyle())
            .disabled(isRefreshing)
            .accessibilityIdentifier("settings-health-refresh")
    }

    private func checkRow(_ check: ProjectHealthSnapshot.Check, hasProjectTarget: Bool) -> some View {
        let action = ApplicationHealthAction.recommended(
            forCheckID: check.id,
            state: check.state,
            hasProjectTarget: hasProjectTarget
        )
        return RekonCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    checkDescription(check)
                    Spacer(minLength: 12)
                    if let action { actionButton(action, checkID: check.id) }
                }
                VStack(alignment: .leading, spacing: 12) {
                    checkDescription(check)
                    if let action { actionButton(action, checkID: check.id) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("settings-health-\(check.id)")
    }

    private func checkDescription(_ check: ProjectHealthSnapshot.Check) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: check.state))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color(for: check.state))
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(RekonTypography.controlLabelEmphasized)
                    .foregroundStyle(RekonTheme.primaryText)
                Text(check.detail)
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func actionButton(_ action: ApplicationHealthAction, checkID: String) -> some View {
        Button(action.title) {
            switch action {
            case .openProject: openProject()
            case .reviewConnections: reviewConnections()
            case .checkAgain: refresh()
            case .restoreBackup: restoreBackup()
            }
        }
        .buttonStyle(RekonSecondaryButtonStyle())
        .accessibilityIdentifier("settings-health-action-\(checkID)")
    }

    @ViewBuilder
    private func technicalDetails(_ snapshot: ApplicationHealthSnapshot) -> some View {
        if let target = snapshot.projectTarget {
            VStack(alignment: .leading, spacing: 6) {
                technicalValue("Project ID", target.projectID.rawValue)
                technicalValue("Registration", target.registrationID)
                technicalValue("Generation", String(target.requestGeneration))
                if let rootPath = snapshot.rootPath {
                    technicalValue("Folder", rootPath)
                }
            }
            .accessibilityIdentifier("settings-health-target")
        } else {
            Text("No saved project target is available for this check.")
                .font(RekonTypography.metadata)
        }
    }

    private func technicalValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RekonTheme.secondaryText)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(RekonTheme.primaryText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func icon(for state: ProjectHealthSnapshot.Check.State) -> String {
        switch state {
        case .ready: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }

    private func color(for state: ProjectHealthSnapshot.Check.State) -> Color {
        switch state {
        case .ready: RekonTheme.success
        case .attention: RekonTheme.warning
        case .unavailable: RekonTheme.danger
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

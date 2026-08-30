import Foundation
import ReleaseRadarCore

enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general
    case connections
    case notifications
    case projects

    var id: String { rawValue }
    var accessibilityID: String { "settings-\(rawValue)" }

    var title: String {
        switch self {
        case .general: "General"
        case .connections: "Connections"
        case .notifications: "Notifications"
        case .projects: "Projects"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .connections: "point.3.connected.trianglepath.dotted"
        case .notifications: "bell"
        case .projects: "folder"
        }
    }
}

struct CodexConnectionPresentation: Equatable, Sendable {
    let status: String
    let detail: String

    init(freshness: CodexObservationFreshness) {
        switch freshness.state {
        case .unavailable:
            status = "Unavailable"
            detail = freshness.reason ?? "No supported Codex attachment is available."
        case .stale:
            status = "Stale"
            if let date = freshness.lastObservedAt {
                detail = "Last seen \(date.formatted(date: .abbreviated, time: .shortened))"
            } else {
                detail = "Last-seen time unavailable"
            }
        case .live:
            status = "Available"
            detail = "Observation connection available"
        }
    }
}

enum CodexPluginOperation: Equatable, Sendable {
    case checking
    case install
    case update
    case remove
    case reinstall
    case tryAgain

    var announcement: String {
        switch self {
        case .checking: "Checking plugin status"
        case .install: "Installing plugin"
        case .update: "Updating plugin"
        case .remove: "Removing plugin"
        case .reinstall: "Reinstalling plugin"
        case .tryAgain: "Trying plugin status again"
        }
    }
}

struct CodexPluginSettingsPresentation: Equatable, Sendable {
    let state: CodexPluginPresentationState
    let operation: CodexPluginOperation?

    init(state: CodexPluginPresentationState, operation: CodexPluginOperation? = nil) {
        self.state = state
        self.operation = operation
    }

    var status: String {
        if let operation { return operation.announcement }
        return switch state {
        case .checking: "Checking"
        case .notInstalled: "Not installed"
        case .installed: "Installed"
        case .updateAvailable: "Update available"
        case .modified: "Modified"
        case .needsRepair: "Needs repair"
        case .failed: "Failed"
        }
    }

    var detail: String {
        return switch state {
        case .checking:
            "Reading the managed plugin state."
        case .notInstalled:
            "Install the Release Radar workflow and its local typed MCP connection for Codex."
        case let .installed(version):
            "Installed version \(version) matches the version shipped with Release Radar."
        case let .updateAvailable(installed, shipped):
            "Version \(installed) is installed. Release Radar ships version \(shipped)."
        case let .modified(version):
            "The installed plugin\(version.map { " (\($0))" } ?? "") differs from its last managed receipt. Reinstall only if you want to replace those changes."
        case .needsRepair:
            "The managed plugin is incomplete or inconsistent. Reinstall to replace it with the shipped version."
        case let .failed(error):
            failureDetail(error)
        }
    }

    var actions: [CodexPluginLifecycleAction] {
        operation == nil ? CodexPluginLifecycleReducer.actions(for: state) : []
    }

    var systemImage: String {
        switch state {
        case .checking: "arrow.triangle.2.circlepath"
        case .notInstalled: "puzzlepiece.extension"
        case .installed: "checkmark.circle"
        case .updateAvailable: "arrow.down.circle"
        case .modified: "pencil.circle"
        case .needsRepair: "wrench.and.screwdriver"
        case .failed: "exclamationmark.triangle"
        }
    }

    private func failureDetail(_ error: CodexPluginLifecycleError) -> String {
        switch error {
        case .codexUnavailable:
            "The local Codex lifecycle helper is unavailable. Try again; macOS may ask you to allow the helper in Login Items."
        case .codexUntrusted:
            "The installed Codex executable could not be verified. Update or reinstall ChatGPT, then try again."
        case .unauthorizedPeer:
            "macOS did not authorize the Release Radar lifecycle helper. Review Login Items, then try again."
        case .marketplaceConflict:
            "A different Release Radar plugin or MCP entry already owns this name. Release Radar left it unchanged."
        case .timeout:
            "Codex did not finish the operation in time. No automatic retry was attempted."
        case .partialReinstall:
            "The previous plugin was removed, but the shipped copy could not be installed. Choose Reinstall to recover."
        case .integrityInvalid, .postconditionFailed:
            "The managed plugin could not be verified. Choose Reinstall to replace it, or Remove to leave it uninstalled."
        case .malformedResult, .outputOverflow, .integrityUnknown:
            "Release Radar could not safely verify the plugin state. Try again after checking the local Codex installation."
        }
    }
}

enum AlertRulesRetryAction: Equatable, Sendable {
    case load
    case update(AlertRuleKind, enabled: Bool)
}

struct AlertRulesFailureState: Equatable, Sendable {
    let presentation: FailureStatePresentation
    let retry: AlertRulesRetryAction

    static let load = AlertRulesFailureState(
        presentation: .init(
            title: "Alert settings unavailable",
            detail: "Release Radar could not load the saved alert rules. Retry to restore the controls; the rest of the dashboard remains available.",
            systemImage: "bell.badge.slash",
            tone: .error,
            accessibilityID: "alert-rules-failure"
        ),
        retry: .load
    )

    static func update(_ kind: AlertRuleKind, enabled: Bool) -> AlertRulesFailureState {
        AlertRulesFailureState(
            presentation: .init(
                title: "Alert setting not saved",
                detail: "The saved value did not change. Retry this alert rule update.",
                systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                tone: .error,
                accessibilityID: "alert-rules-failure"
            ),
            retry: .update(kind, enabled: enabled)
        )
    }
}

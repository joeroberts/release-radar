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

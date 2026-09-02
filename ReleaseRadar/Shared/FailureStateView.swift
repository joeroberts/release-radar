import ReleaseRadarCore
import SwiftUI

enum FailureStateTone: Equatable, Sendable {
    case neutral
    case warning
    case error

    var color: Color {
        switch self {
        case .neutral: .secondary
        case .warning: .orange
        case .error: .red
        }
    }
}

struct FailureStatePresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let systemImage: String
    let tone: FailureStateTone
    let accessibilityID: String

    static let noDeliveryStructure = FailureStatePresentation(
        title: "Project tracking not initialized",
        detail: "Choose Initialize Project Tracking to save this folder locally, then use the Codex prompt to define its current tracking state.",
        systemImage: "folder.badge.plus",
        tone: .neutral,
        accessibilityID: "failure-no-structure"
    )

    static let firstPhaseRequired = FailureStatePresentation(
        title: "Tracking state required",
        detail: "Use the Codex prompt to define the current tracking state, then choose Check Tracking Status before opening the delivery dashboard.",
        systemImage: "flag.badge.ellipsis",
        tone: .warning,
        accessibilityID: "failure-first-phase"
    )

    static let trackingStateRequired = FailureStatePresentation(
        title: "Tracking state required",
        detail: "Use the Codex prompt to define the current tracking state, then choose Check Tracking Status before finishing initialization.",
        systemImage: "flag.badge.ellipsis",
        tone: .warning,
        accessibilityID: "failure-tracking-state"
    )

    init(
        title: String,
        detail: String,
        systemImage: String,
        tone: FailureStateTone,
        accessibilityID: String
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.tone = tone
        self.accessibilityID = accessibilityID
    }

    init?(freshness: CodexObservationFreshness) {
        switch freshness.state {
        case .live:
            return nil
        case .unavailable:
            self.init(
                title: "Codex desktop observation unavailable",
                detail: freshness.reason ?? "No supported Codex attachment is available.",
                systemImage: "bolt.horizontal.circle",
                tone: .neutral,
                accessibilityID: "failure-codex-unavailable"
            )
        case .stale:
            let lastSeen = freshness.lastObservedAt.map {
                "Last seen \($0.formatted(date: .abbreviated, time: .shortened))"
            } ?? "Last-seen time unavailable"
            self.init(
                title: "Cached Codex state",
                detail: lastSeen,
                systemImage: "clock.badge.exclamationmark",
                tone: .warning,
                accessibilityID: "failure-codex-stale"
            )
        }
    }

    init?(onboardingError: OnboardingError) {
        switch onboardingError {
        case .invalidFolder:
            self.init(
                title: "Project folder unavailable",
                detail: "The folder may have moved or access may have expired. Select it again to reauthorize access.",
                systemImage: "folder.badge.questionmark",
                tone: .warning,
                accessibilityID: "failure-project-folder"
            )
        case .noFirstPhase, .projectNotPrepared:
            self = .trackingStateRequired
        case .invalidProjectName:
            self.init(
                title: "Project name required",
                detail: onboardingError.localizedDescription,
                systemImage: "text.badge.xmark",
                tone: .warning,
                accessibilityID: "failure-project-name"
            )
        case .rootAlreadyOwned:
            self.init(
                title: "Folder already in use",
                detail: onboardingError.localizedDescription,
                systemImage: "folder.badge.minus",
                tone: .warning,
                accessibilityID: "failure-project-owner"
            )
        case .reviewMarkerConflict:
            self.init(
                title: "Onboarding state conflict",
                detail: onboardingError.localizedDescription,
                systemImage: "exclamationmark.triangle",
                tone: .warning,
                accessibilityID: "failure-onboarding-marker-conflict"
            )
        }
    }

    init?(evidenceLabel: String, isAvailable: Bool) {
        guard !isAvailable else { return nil }
        self.init(
            title: "Evidence unavailable",
            detail: "\(evidenceLabel) remains in history, but its file cannot be opened from the recorded location.",
            systemImage: "doc.badge.ellipsis",
            tone: .warning,
            accessibilityID: "failure-evidence-unavailable"
        )
    }

    init?(reviewItem: ReviewItemProjection) {
        switch reviewItem.kind {
        case .uncertainImport:
            self.init(
                title: "Import needs review",
                detail: reviewItem.summary,
                systemImage: "tray.and.arrow.down",
                tone: .warning,
                accessibilityID: "failure-import-review"
            )
        case .duplicate:
            self.init(
                title: "Possible duplicate",
                detail: reviewItem.summary,
                systemImage: "square.on.square",
                tone: .warning,
                accessibilityID: "failure-import-duplicate"
            )
        case .unresolvedDependency:
            self.init(
                title: "Dependency needs review",
                detail: reviewItem.summary,
                systemImage: "arrow.triangle.branch",
                tone: .warning,
                accessibilityID: "failure-import-dependency"
            )
        case .unmatchedTask, .excludedTask, .agentReviewRequest, .unsupported:
            return nil
        }
    }

    init?(notificationState: NotificationDeliveryState?, statusText: String?) {
        switch notificationState {
        case .failed:
            self.init(
                title: "Pushover delivery failed",
                detail: statusText ?? "The failure is preserved in notification history and does not block the dashboard.",
                systemImage: "bell.badge.slash",
                tone: .error,
                accessibilityID: "failure-pushover-failed"
            )
        case .unknown:
            self.init(
                title: "Pushover delivery unknown",
                detail: statusText ?? "The attempt is preserved and is not retried automatically.",
                systemImage: "bell.badge.questionmark",
                tone: .warning,
                accessibilityID: "failure-pushover-unknown"
            )
        case .queued, .attemptStarted, .sent, nil:
            return nil
        }
    }

    init?(agentError: AgentCommandError) {
        switch agentError {
        case let .documentation(error):
            self.init(title: "Documentation action rejected",
                      detail: "Documentation operation failed (\(error.rawValue)). Inspect the project evidence inventory and retry the exact approved operation.",
                      systemImage: "xmark.octagon", tone: .error, accessibilityID: "failure-documentation-validation")
        case .outcomeUnknown:
            self.init(
                title: "Action outcome unknown",
                detail: "Do not assume success. Refresh persisted state before deciding what to do next; the action is not retried automatically.",
                systemImage: "questionmark.diamond",
                tone: .warning,
                accessibilityID: "failure-agent-outcome-unknown"
            )
        case let .invalidEnvelope(message),
             let .invalidReference(message),
             let .crossProjectReference(message),
             let .dependencyCycle(message):
            self.init(
                title: "Action rejected",
                detail: "\(message) No delivery state changed.",
                systemImage: "xmark.octagon",
                tone: .error,
                accessibilityID: "failure-agent-validation"
            )
        case let .unsupportedVersion(found, supported):
            self.init(
                title: "Action rejected",
                detail: "Command version \(found) is unsupported; version \(supported) is required. No delivery state changed.",
                systemImage: "xmark.octagon",
                tone: .error,
                accessibilityID: "failure-agent-validation"
            )
        case .unauthorizedProjectRoot:
            self.init(
                title: "Action rejected",
                detail: "The project folder is not authorized. No delivery state changed.",
                systemImage: "lock.trianglebadge.exclamationmark",
                tone: .error,
                accessibilityID: "failure-agent-validation"
            )
        case .requestIDReused:
            self.init(
                title: "Action rejected",
                detail: "The request identifier was already used for a different action. No delivery state changed.",
                systemImage: "xmark.octagon",
                tone: .error,
                accessibilityID: "failure-agent-validation"
            )
        case .appUnavailable:
            self.init(
                title: "Action unavailable",
                detail: "Release Radar could not accept the action. No delivery state changed.",
                systemImage: "app.badge.checkmark",
                tone: .error,
                accessibilityID: "failure-agent-unavailable"
            )
        case let .internalFailure(message):
            self.init(
                title: "Action failed",
                detail: "\(message) No partial delivery state was kept.",
                systemImage: "exclamationmark.triangle",
                tone: .error,
                accessibilityID: "failure-agent-internal"
            )
        }
    }

    init(projectAuthorizationError: ProjectAuthorizationError) {
        let recoverable: Bool = switch projectAuthorizationError {
        case .projectRootMissing, .bookmarkMissing, .bookmarkStale,
             .bookmarkResolutionFailed, .securityScopeAccessDenied, .bookmarkRootMismatch:
            true
        case .projectNotFound, .projectRootAlreadyAssociated, .projectRootMismatch,
             .rootAlreadyOwned, .invalidFolder:
            false
        }
        self.init(
            title: recoverable ? "Project folder authorization required" : "Project folder not accepted",
            detail: "\(projectAuthorizationError.localizedDescription) The review remains open; retry Resolve or Dismiss only after access is restored.",
            systemImage: "folder.badge.questionmark",
            tone: recoverable ? .warning : .error,
            accessibilityID: recoverable ? "review-locate-authorization" : "review-folder-authorization-error"
        )
    }

    init(activePhaseAuthorizationError error: ProjectAuthorizationError) {
        self.init(
            title: "Active phase authorization required",
            detail: "\(error.localizedDescription) Locate the same project folder to restore access, then select the phase again.",
            systemImage: "folder.badge.questionmark",
            tone: .warning,
            accessibilityID: "active-phase-authorization-failed"
        )
    }

    init(activePhaseAgentError error: AgentCommandError) {
        switch error {
        case .appUnavailable:
            self.init(
                title: "Active phase unavailable",
                detail: "Release Radar could not accept the phase change. The active phase and current board did not change. Reopen or reload Release Radar before trying again.",
                systemImage: "app.badge.checkmark",
                tone: .error,
                accessibilityID: "active-phase-unavailable"
            )
        case .outcomeUnknown:
            self.init(
                title: "Active phase outcome unknown",
                detail: "Refresh persisted state before deciding what to do next. Release Radar will not retry the phase change automatically.",
                systemImage: "questionmark.diamond",
                tone: .warning,
                accessibilityID: "active-phase-outcome-unknown"
            )
        default:
            let base = FailureStatePresentation(agentError: error)
            self.init(
                title: "Active phase change failed",
                detail: base?.detail ?? "The phase change failed and no partial delivery state was kept.",
                systemImage: base?.systemImage ?? "exclamationmark.triangle",
                tone: base?.tone ?? .error,
                accessibilityID: "active-phase-mutation-failed"
            )
        }
    }
}

enum FailureStateViewStyle: Sendable {
    case full
    case inline
    case compact
}

struct FailureStateView: View {
    let presentation: FailureStatePresentation
    var style: FailureStateViewStyle = .inline
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            switch style {
            case .full:
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        presentation.title,
                        systemImage: presentation.systemImage,
                        description: Text(presentation.detail)
                    )
                    actionButton
                }
            case .inline:
                HStack(alignment: .top, spacing: 12) {
                    stateIcon
                    stateCopy
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(presentation.tone.color.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(presentation.tone.color.opacity(0.24))
                }
            case .compact:
                HStack(alignment: .top, spacing: 8) {
                    stateIcon
                    stateCopy
                }
            }
        }
        .accessibilityElement(children: action == nil ? .combine : .contain)
        .accessibilityIdentifier(presentation.accessibilityID)
    }

    private var stateIcon: some View {
        Image(systemName: presentation.systemImage)
            .foregroundStyle(presentation.tone.color)
            .frame(width: 20)
            .accessibilityHidden(true)
    }

    private var stateCopy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(presentation.title)
                .font(.subheadline.weight(.semibold))
            Text(presentation.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, let action {
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
                .accessibilityIdentifier("\(presentation.accessibilityID)-action")
        }
    }
}

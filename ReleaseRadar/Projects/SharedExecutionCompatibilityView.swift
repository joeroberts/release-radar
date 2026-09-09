import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

struct SharedExecutionCompatibilityPresentation: Equatable, Sendable {
    let status: String
    let detail: String
    let recovery: String
    let systemImage: String

    init(state: SharedExecutionCompatibilityState) {
        switch state {
        case .notDeclared:
            status = "Not declared"
            detail = "This repository does not declare a shared-execution standard."
            recovery = "Adoption requires a separate owner-approved task."
            systemImage = "circle.dashed"
        case .compatibleV1:
            status = "Compatible with V1"
            detail = "The exact V1 declaration, recognized plugin capability, checker, and repository documentation currently agree. This does not prove a commit, owner approval, or task skill loading."
            recovery = "No action is required for technical compatibility."
            systemImage = "checkmark.seal.fill"
        case .compatibleOlder:
            status = "Compatible with an older standard"
            detail = "The installed exact plugin capability supports the repository's declared older standard."
            recovery = "Continue under the declared version or request a separate upgrade."
            systemImage = "checkmark.circle"
        case .updateAvailable:
            status = "Compatible update available"
            detail = "The installed exact capability supports this declaration and the shipped package supports a newer standard. Nothing was updated automatically."
            recovery = "Update or adopt only through separate owner actions."
            systemImage = "arrow.up.circle"
        case .pendingCatalogAcceptance:
            status = "Pending catalog acceptance"
            detail = "Repository files validate, but the current managed catalog snapshot is not accepted."
            recovery = "Accept the validated catalog through the existing owner-controlled flow."
            systemImage = "clock.badge.exclamationmark"
        case .incompatible:
            status = "Incompatible"
            detail = "The declaration, exact plugin capability, checker, or repository contract does not agree."
            recovery = "Standard-specific assistance remains disabled until the mismatch is resolved."
            systemImage = "exclamationmark.triangle.fill"
        case .unavailable:
            status = "Compatibility unavailable"
            detail = "A required root, plugin, checker, permission, or repository observation is unavailable."
            recovery = "Restore existing root or documentation access. Handle an absent plugin separately in owner-controlled plugin settings, then refresh."
            systemImage = "xmark.circle.fill"
        case .rootUnknown:
            status = "Repository root unknown"
            detail = "No exact canonical project root is established, so Release Radar did not inspect or infer adoption."
            recovery = "Authorize or select the exact project root before inspection."
            systemImage = "folder.badge.questionmark"
        case .unknown:
            status = "Compatibility unknown"
            detail = "A required observation was interrupted, ambiguous, or could not be attributed to this project."
            recovery = "Refresh the read-only observation before relying on this status."
            systemImage = "questionmark.circle.fill"
        }
    }

    static let checking = Self(
        status: "Checking compatibility",
        detail: "Reading the exact project root, declaration, plugin capability, checker, and repository documentation.",
        recovery: "Wait for the current read-only observation to finish.",
        systemImage: "arrow.clockwise.circle"
    )

    private init(status: String, detail: String, recovery: String, systemImage: String) {
        self.status = status
        self.detail = detail
        self.recovery = recovery
        self.systemImage = systemImage
    }
}

struct SharedExecutionCompatibilityView: View {
    let documentationStatus: DocumentationObservationStatus?
    let refresh: () async -> Void

    @State private var isRefreshing = false

    var body: some View {
        RekonSectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                heading
                refreshButton
            }

            Label(presentation.status, systemImage: presentation.systemImage)
                .font(.headline)
                .foregroundStyle(statusColor)
                .accessibilityIdentifier("shared-execution-status")
            Text(presentation.detail)
                .foregroundStyle(RekonTheme.secondaryText)
            Text(presentation.recovery)
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)

            if !directResults.isEmpty {
                Divider()
                Text("Direct results")
                    .font(.headline)
                ForEach(Array(directResults.enumerated()), id: \.offset) { index, result in
                    directResult(result, index: index)
                }
            }

            if let checkedAt {
                Text("Checked \(checkedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shared-execution-compatibility")
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Shared execution")
                .font(.title2.weight(.semibold))
            Text("Read-only technical compatibility for this project")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private var refreshButton: some View {
        Button(isRefreshing ? "Refreshing…" : "Refresh compatibility") {
            isRefreshing = true
            Task {
                await refresh()
                isRefreshing = false
            }
        }
        .buttonStyle(RekonSecondaryButtonStyle())
        .disabled(isRefreshing || isChecking)
        .accessibilityIdentifier("shared-execution-refresh")
    }

    private var presentation: SharedExecutionCompatibilityPresentation {
        guard case let .observed(observation) = documentationStatus else { return .checking }
        return .init(state: observation.sharedExecutionCompatibility.state)
    }

    private var directResults: [SharedExecutionDirectResult] {
        guard case let .observed(observation) = documentationStatus else { return [] }
        return observation.sharedExecutionCompatibility.directResults
    }

    private var checkedAt: Date? {
        guard case let .observed(observation) = documentationStatus else { return nil }
        return observation.checkedAt
    }

    private var isChecking: Bool {
        if case .observed = documentationStatus { return false }
        return true
    }

    private var statusColor: Color {
        guard case let .observed(observation) = documentationStatus else { return RekonTheme.warning }
        switch observation.sharedExecutionCompatibility.state {
        case .compatibleV1, .compatibleOlder:
            return RekonTheme.success
        case .notDeclared, .updateAvailable, .pendingCatalogAcceptance, .unknown, .rootUnknown:
            return RekonTheme.warning
        case .incompatible, .unavailable:
            return RekonTheme.danger
        }
    }

    private func directResult(_ result: SharedExecutionDirectResult, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            resultField("Check", result.check)
            resultField("Runner", result.runner)
            resultField("Scope", result.scope)
            resultField("Source", result.source)
            resultField("Applicability", result.applicability.rawValue)
            resultField("Status", result.status.rawValue)
            resultField("Direct result", result.directResult)
            if let limitation = result.limitation {
                resultField("Limitation", limitation)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(RekonTheme.border.opacity(0.7), lineWidth: RekonBorder.hairline)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shared-execution-result-\(index)")
    }

    private func resultField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(RekonTheme.primaryText)
                .textSelection(.enabled)
        }
    }
}

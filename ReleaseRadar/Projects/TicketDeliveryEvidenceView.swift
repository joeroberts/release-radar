import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

private enum DeliveryEvidenceSectionState {
    case idle
    case loaded(TicketDeliveryEvidence)
    case failed(FailureStatePresentation)
}

struct TicketDeliveryEvidenceSection: View {
    let identity: String
    let load: () async -> ReferenceLoadResult<TicketDeliveryEvidence>
    @State private var state: DeliveryEvidenceSectionState = .idle
    @State private var showsHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Delivery evidence", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer(minLength: 8)
                Button("Help", systemImage: "questionmark.circle") {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { showsHelp = true }
                }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .accessibilityHint("Explains recorded targets, applicability, and what Refresh can read.")
                    .accessibilityIdentifier("delivery-evidence-help")
            }

            switch state {
            case .idle:
                ProgressView("Loading delivery evidence…")
                    .controlSize(.small)
            case let .failed(failure):
                FailureStateView(
                    presentation: failure,
                    style: .compact,
                    actionTitle: "Retry",
                    action: { Task { await reload() } }
                )
            case let .loaded(evidence):
                loadedContent(evidence)
            }
        }
        .font(.subheadline)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(RekonTheme.border.opacity(0.82), lineWidth: RekonBorder.hairline)
        }
        .task(id: identity) { await reload() }
        .sheet(isPresented: $showsHelp) { DeliveryEvidenceHelpView() }
        .accessibilityIdentifier("ticket-delivery-evidence")
    }

    @ViewBuilder
    private func loadedContent(_ evidence: TicketDeliveryEvidence) -> some View {
        if let targetVersion = evidence.currentTargetVersion,
           let target = evidence.targets.first(where: { $0.version == targetVersion }) {
            targetCard(target, evidence: evidence)
            expectations(evidence.expectations)
            observations(evidence.observations)
            if evidence.targets.count > 1 {
                Text("\(evidence.targets.count - 1) earlier recorded target\(evidence.targets.count == 2 ? "" : "s") retained")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No revision-bound delivery evidence recorded")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("delivery-evidence-empty")
        }
        Label(
            "Owner acceptance: \(evidence.ownerAcceptance.displayName)",
            systemImage: evidence.ownerAcceptance == .accepted ? "person.crop.circle.badge.checkmark" : "person.crop.circle"
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(evidence.ownerAcceptance == .accepted ? RekonTheme.success : .secondary)
        .accessibilityIdentifier("delivery-evidence-owner-acceptance")
    }

    private func targetCard(
        _ target: DeliveryEvidenceTargetVersion,
        evidence: TicketDeliveryEvidence
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recorded target")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("v\(target.version) · set \(evidence.revision)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(target.revision.commitSHA)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Text(target.checkoutDescription)
                .font(.caption)
                .foregroundStyle(target.revision.checkoutState == .dirty ? .orange : .secondary)
            Text("Repository \(target.repositoryID) · root \(target.rootID)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            Text("Recorded \(target.recordedAt) · registration \(target.registrationID) / \(target.requestGeneration)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("delivery-evidence-recorded-target")
    }

    @ViewBuilder
    private func expectations(_ values: [DeliveryEvidenceExpectationAssessment]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Expected for this target")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if values.isEmpty {
                Text("No evidence categories specified")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(values.enumerated()), id: \.offset) { _, assessment in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Label(assessment.expectation.displayName, systemImage: assessment.expectation.category.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statusBadge(assessment.status.displayName, tone: assessment.status.tone)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func observations(_ values: [DeliveryEvidenceResolvedObservation]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Recorded observations")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if values.isEmpty {
                Text("No observations recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(values.reversed()) { value in observationCard(value) }
            }
        }
    }

    private func observationCard(_ resolved: DeliveryEvidenceResolvedObservation) -> some View {
        let observation = resolved.observation
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(observation.fact.category.displayName, systemImage: observation.fact.category.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("delivery-evidence-observation-\(observation.id)")
                Spacer(minLength: 8)
                statusBadge(observation.outcome.displayName, tone: observation.outcome.tone)
            }
            Text(observation.fact.detail)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                statusBadge(resolved.applicability.state.displayName, tone: resolved.applicability.state.tone)
                statusBadge("Source \(resolved.currentSourceAvailability.displayName)", tone: resolved.currentSourceAvailability.tone)
            }
            if !resolved.applicability.reasons.isEmpty {
                Text(resolved.applicability.reasons.map(\.displayName).joined(separator: " · "))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(resolved.applicability.state == .stale ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let digest = resolved.currentDocumentDigest {
                Text("Current document SHA-256 \(digest)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text("\(observation.source.kind.displayName) · \(observation.source.label)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Observed \(observation.observedAt) · recorded by app \(observation.recordedAt)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if let superseded = observation.supersedesObservationID {
                Text("Correction supersedes \(superseded)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.elevatedSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .focusable()
    }

    private func statusBadge(_ label: String, tone: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tone.opacity(0.12), in: Capsule())
    }

    @MainActor
    private func reload() async {
        state = .idle
        let result = await load()
        guard !Task.isCancelled else { return }
        switch result {
        case let .loaded(value): state = .loaded(value)
        case let .failed(failure): state = .failed(failure)
        }
    }
}

struct DeliveryEvidenceHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Delivery evidence help")
                    .font(RekonTypography.screenTitle)
                    .accessibilityIdentifier("delivery-evidence-help-sheet")
                RekonCallout(tone: .information, systemImage: "scope") {
                    Text("Recorded is not live").font(.headline)
                    Text("The target is the repository and revision recorded for this ticket. Release Radar does not inspect live HEAD, execute checks, contact a provider, or infer that a newer build is installed when this panel refreshes.")
                }
                RekonCallout(tone: .warning, systemImage: "clock.badge.exclamationmark") {
                    Text("Applicability follows identity").font(.headline)
                    Text("Repository, commit or merge revision, checkout state, dirty snapshot, and exact check scope determine whether an observation applies. A prior pass stays visible but becomes stale for a different target.")
                }
                RekonCallout(tone: .accent, systemImage: "doc.text.magnifyingglass") {
                    Text("Refresh reads bounded local facts").font(.headline)
                    Text("For managed documents, Refresh may compare the current authorized bytes with the recorded digest. Unavailable means the source cannot currently be read; unknown means the observation never established that identity.")
                }
                RekonCallout(tone: .information, systemImage: "person.crop.circle") {
                    Text("Evidence is not acceptance").font(.headline)
                    Text(WorkspaceHelpContent.deliveryEvidenceBoundary)
                }
                HStack {
                    Spacer()
                    Button("Done") {
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { dismiss() }
                    }
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("delivery-evidence-help-done")
                }
            }
            .padding(28)
        }
        .frame(minWidth: 500, idealWidth: 640, minHeight: 520)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
    }
}

private extension DeliveryEvidenceTargetVersion {
    var checkoutDescription: String {
        switch revision.checkoutState {
        case .clean: "Clean checkout"
        case .dirty: "Dirty snapshot \(revision.dirtySnapshotID ?? "unknown")"
        case .unknown: "Checkout state unknown"
        }
    }
}

private extension DeliveryEvidenceExpectation {
    var displayName: String {
        scope.map { "\(category.displayName) · \($0)" } ?? category.displayName
    }
}

private extension DeliveryEvidenceCategory {
    var displayName: String {
        switch self {
        case .repository: "Repository"
        case .commit: "Commit"
        case .pullRequest: "Pull request"
        case .check: "Check"
        case .document: "Document"
        case .build: "Build"
        case .installation: "Installation"
        }
    }

    var systemImage: String {
        switch self {
        case .repository: "folder"
        case .commit: "point.topleft.down.to.point.bottomright.curvepath"
        case .pullRequest: "arrow.triangle.pull"
        case .check: "checkmark.circle"
        case .document: "doc.text"
        case .build: "hammer"
        case .installation: "shippingbox"
        }
    }
}

private extension DeliveryEvidenceFact {
    var detail: String {
        switch self {
        case let .repository(fact):
            "Repository \(fact.repositoryID) · \(fact.revision.commitSHA)"
        case let .commit(fact):
            "Commit \(fact.revision.commitSHA) · repository \(fact.repositoryID)"
        case let .pullRequest(fact):
            "PR #\(fact.number) · \(fact.state.displayName) · head \(fact.headSHA)" + (fact.mergeSHA.map { " · merge \($0)" } ?? "")
        case let .check(fact):
            "Scope \(fact.scope)"
        case let .document(fact):
            "Artifact \(fact.artifactID) · recorded SHA-256 \(fact.contentDigest)"
        case let .build(fact):
            "Build \(fact.buildID)" + (fact.scope.map { " · scope \($0)" } ?? "")
        case let .installation(fact):
            "\(fact.context) · installation \(fact.installationID ?? "unknown") · build \(fact.buildID ?? "unknown")"
        }
    }
}

private extension DeliveryEvidencePullRequestState {
    var displayName: String { rawValue.capitalized }
}

private extension DeliveryEvidenceExpectationStatus {
    var displayName: String {
        switch self {
        case .satisfied: "Satisfied"
        case .failed: "Failed"
        case .skipped: "Skipped"
        case .missing: "Missing"
        case .unavailable: "Unavailable"
        case .unknown: "Unknown"
        case .notSpecified: "Not specified"
        }
    }

    var tone: Color {
        switch self {
        case .satisfied: RekonTheme.success
        case .failed: .red
        case .skipped, .missing, .unavailable: .orange
        case .unknown, .notSpecified: .secondary
        }
    }
}

private extension DeliveryEvidenceOutcome {
    var displayName: String { rawValue.capitalized }
    var tone: Color {
        switch self {
        case .passed: RekonTheme.success
        case .failed: .red
        case .skipped: .orange
        case .observed: RekonTheme.accent
        case .unknown: .secondary
        }
    }
}

private extension DeliveryEvidenceApplicabilityState {
    var displayName: String { rawValue.capitalized }
    var tone: Color {
        switch self {
        case .applicable: RekonTheme.success
        case .stale: .orange
        case .unknown: .secondary
        }
    }
}

private extension DeliveryEvidenceSourceAvailability {
    var displayName: String { rawValue.capitalized }
    var tone: Color {
        switch self {
        case .available: RekonTheme.success
        case .unavailable: .orange
        case .unknown: .secondary
        }
    }
}

private extension DeliveryEvidenceSourceKind {
    var displayName: String {
        switch self {
        case .localObservation: "Local observation"
        case .recordedClaim: "Recorded claim"
        case .managedDocument: "Managed document"
        case .importedLegacy: "Imported legacy evidence"
        }
    }
}

private extension DeliveryEvidenceApplicabilityReason {
    var displayName: String {
        switch self {
        case .targetVersionMismatch: "Earlier recorded target"
        case .repositoryMismatch: "Repository mismatch"
        case .repositoryUnknown: "Repository identity unknown"
        case .revisionMismatch: "Revision mismatch"
        case .revisionUnknown: "Revision identity unknown"
        case .checkoutStateMismatch: "Checkout state mismatch"
        case .dirtySnapshotMismatch: "Dirty snapshot mismatch"
        case .scopeMismatch: "Scope mismatch"
        case .installationIdentityUnknown: "Unknown installation identity"
        case .documentContentChanged: "Document content changed"
        case .documentCatalogChanged: "Document catalog changed"
        }
    }
}

private extension DeliveryEvidenceOwnerAcceptance {
    var displayName: String {
        switch self {
        case .accepted: "Accepted"
        case .notAccepted: "Not accepted"
        case .unknown: "Unknown"
        }
    }
}

import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct TicketDetailView: View {
    let detail: TicketDetailProjection
    var documentationStatus: DocumentationObservationStatus? = nil
    var restoreDocumentationFolderAccess: (() -> Void)? = nil
    var openWorktreeRecovery: (() -> Void)? = nil
    var loadEvidencePreview: ((EvidenceID) async -> EvidencePreview)? = nil
    var loadReferences: (() async -> ReferenceLoadResult<TicketReferenceSet>)? = nil
    var loadDeliveryEvidence: (() async -> ReferenceLoadResult<TicketDeliveryEvidence>)? = nil
    var openReferenceSource: ((String, Int64) -> Void)? = nil
    var referenceContextIdentity: String? = nil
    var reload: () async -> Void = {}
    @State private var isReloadingTasks = false
    @State private var isTaskHelpPresented = false
    @ScaledMetric(relativeTo: .subheadline) private var taskFontSize = 12

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Selected ticket")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(detail.id.rawValue)
                        .font(.system(.headline, design: .monospaced))
                    Text(detail.outcome)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("inspector-outcome")
                }

                tasksSection

                if let loadDeliveryEvidence {
                    let identity = "\(referenceContextIdentity ?? "unavailable"):\(detail.id.rawValue)"
                    TicketDeliveryEvidenceSection(identity: identity, load: loadDeliveryEvidence)
                        .id(identity)
                }

                if let loadReferences, let openReferenceSource {
                    let identity = "\(referenceContextIdentity ?? "unavailable"):\(detail.id.rawValue)"
                    TicketReferencesSection(
                        identity: identity,
                        load: loadReferences,
                        openSource: openReferenceSource
                    )
                    .id(identity)
                }

                detailSection("Delivery Goal", systemImage: "target") {
                    if let goal = detail.deliveryGoal {
                        Text("\(goal.goalID.rawValue) · \(goal.title)").font(.subheadline.weight(.medium))
                        Text(goal.lifecycle.displayName).foregroundStyle(.secondary)
                        Text(goal.outcome)
                        ForEach(Array(goal.doneCriteria.enumerated()), id: \.offset) { _, criterion in
                            Label(criterion, systemImage: "checkmark.circle")
                        }
                    } else {
                        Text("No Delivery Goal assigned").foregroundStyle(.secondary)
                    }
                    if detail.isLegacyContinuation {
                        Text("Legacy continuation · not covered by the current phase plan")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                detailSection("Codex execution goal", systemImage: "scope") {
                    Label(detail.goalContext.linkQuality.rawValue, systemImage: "checkmark.seal")
                        .foregroundStyle(detail.goalContext.linkQuality == .verified ? Color.green : Color.secondary)
                    if let status = detail.goalContext.status {
                        Text(status)
                            .font(.subheadline.weight(.medium))
                    }
                    if let text = detail.goalContext.text {
                        Text(text)
                            .foregroundStyle(.secondary)
                    }
                    if let observedAt = detail.goalContext.lastObservedAt {
                        Text("Last observed \(observedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if detail.goalContext.linkQuality == .unavailable {
                        Text("No linked Codex execution goal").foregroundStyle(.secondary)
                    }
                }

                relationshipSection("Requires", direction: "This ticket depends on", tickets: detail.requires)
                relationshipSection("Unlocks", direction: "These tickets depend on this ticket", tickets: detail.unlocks)

                textHistorySection(
                    "Owner attention",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    values: detail.ownerAttention,
                    empty: "No owner attention requested"
                )

                detailSection("Evidence", systemImage: "doc.text.magnifyingglass") {
                    if detail.evidence.isEmpty {
                        Text("No evidence recorded")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(detail.evidence) { evidence in
                            EvidenceDetailView(
                                evidence: evidence,
                                documentationStatus: documentationStatus,
                                restoreFolderAccess: restoreDocumentationFolderAccess,
                                openWorktreeRecovery: openWorktreeRecovery,
                                loadPreview: loadEvidencePreview.map { loader in
                                    { await loader(evidence.id) }
                                }
                            )
                        }
                    }
                }

                textHistorySection("Audit", systemImage: "clock.arrow.circlepath", values: detail.auditHistory, empty: "No audit events recorded")
                textHistorySection("Notifications", systemImage: "tray.full", values: detail.notificationHistory, empty: "No notification history")
            }
            .padding(.trailing, 6)
            .textSelection(.enabled)
        }
        .scrollIndicators(.visible)
        .accessibilityHint("Scroll to reach all ticket details and task rows. Task rows are keyboard focusable.")
        .accessibilityIdentifier("ticket-inspector")
    }

    private var tasksSection: some View {
        detailSection("Tasks", systemImage: "checklist") {
            HStack {
                Text("Definitions and completion are revisioned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button {
                    isTaskHelpPresented = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Task adoption help")
                .accessibilityIdentifier("task-adoption-help-button")
                .popover(isPresented: $isTaskHelpPresented, arrowEdge: .trailing) {
                    TaskAdoptionHelpView()
                }
            }
            switch detail.taskPlan {
            case .noPlan:
                Text("No task plan")
                    .foregroundStyle(.secondary)
            case let .loaded(plan):
                ForEach(Array(plan.tasks.enumerated()), id: \.element.id) { index, task in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: task.completion == .completed ? "checkmark.square" : "square")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("\(task.label): \(task.title)")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: taskFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(task.accessibilityLabel(position: index + 1, total: plan.tasks.count))
                    .accessibilityIdentifier("task-row-\(task.id.rawValue)")
                    .focusable()
                }
            case let .unavailable(recovery):
                FailureStateView(
                    presentation: .init(title: "Tasks unavailable", detail: recovery.message,
                        systemImage: "arrow.clockwise", tone: .warning,
                        accessibilityID: "task-plan-unavailable"),
                    style: .compact,
                    actionTitle: isReloadingTasks ? "Reloading…" : "Reload",
                    action: {
                        guard !isReloadingTasks else { return }
                        isReloadingTasks = true
                        Task {
                            await reload()
                            isReloadingTasks = false
                        }
                    }
                )
                .disabled(isReloadingTasks)
            }
        }
    }

    private func relationshipSection(
        _ title: String,
        direction: String,
        tickets: [TicketReferenceProjection]
    ) -> some View {
        detailSection(title, systemImage: title == "Requires" ? "arrow.left" : "arrow.right") {
            Text(direction)
                .font(.caption)
                .foregroundStyle(.secondary)
            if tickets.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tickets) { ticket in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ticket.id.rawValue)
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                        Text(ticket.outcome)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func textHistorySection(
        _ title: String,
        systemImage: String,
        values: [String],
        empty: String
    ) -> some View {
        detailSection(title, systemImage: systemImage) {
            if values.isEmpty {
                Text(empty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Text(value)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(RekonTheme.border.opacity(0.82), lineWidth: RekonBorder.hairline)
        }
    }
}

enum TaskAdoptionHelpContent {
    static let title = "Adopting ticket tasks"
    static let introduction = "Codex proposes one exact, project-scoped reconciliation. Nothing changes until you approve that reconciliation and the same inventory baseline still applies."
    static let classifications = "Each non-Accepted ticket is classified as atomic, non-atomic, already-planned, or blocked. Existing rows stay unchanged unless the reconciliation names an addition, permitted definition revision, or supersession."
    static let evidence = "A task is completed from prior evidence only when the current target has an explicitly applicable, available, successful observation for that exact ticket and task scope. Uncertain, failed, stale, or generic evidence keeps it Pending."
    static let recovery = "Commands use the exact plan revision and return the next revision. If availability is uncertain, retry the exact request. If identity or baseline changed, refresh and approve a new reconciliation."
}

struct TaskAdoptionHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(TaskAdoptionHelpContent.title, systemImage: "checklist.checked")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(RekonTheme.primaryText)
                Text(TaskAdoptionHelpContent.introduction)
                    .foregroundStyle(RekonTheme.secondaryText)
                helpSection("What you approve", text: TaskAdoptionHelpContent.classifications)
                helpSection("Prior completion", text: TaskAdoptionHelpContent.evidence)
                helpSection("Apply and recover", text: TaskAdoptionHelpContent.recovery)
                Label("Read the Tasks card and History after success.", systemImage: "clock.arrow.circlepath")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(RekonTheme.primaryText)
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("task-adoption-help-done")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 280, idealWidth: 420, minHeight: 420, idealHeight: 520)
        .background(RekonTheme.surface)
        .accessibilityIdentifier("task-adoption-help")
    }

    private func helpSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundStyle(RekonTheme.primaryText)
            Text(text)
                .font(.callout)
                .foregroundStyle(RekonTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

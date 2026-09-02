import SwiftUI

struct TicketDetailView: View {
    let detail: TicketDetailProjection
    var reload: () async -> Void = {}
    @State private var isReloadingTasks = false
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
                            EvidenceDetailView(evidence: evidence)
                        }
                    }
                }

                textHistorySection("Audit", systemImage: "clock.arrow.circlepath", values: detail.auditHistory, empty: "No audit events recorded")
                textHistorySection("Notifications", systemImage: "tray.full", values: detail.notificationHistory, empty: "No notification history")
            }
            .padding(.trailing, 6)
            .textSelection(.enabled)
        }
        .accessibilityIdentifier("ticket-inspector")
    }

    private var tasksSection: some View {
        detailSection("Tasks", systemImage: "checklist") {
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
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

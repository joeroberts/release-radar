import AppKit
import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

enum NeedsReviewLayout {
    static let minimumSplitWidth: CGFloat = 700

    static func showsInboxList(openItems: Int, deliveryGoals: Int, completedItems: Int) -> Bool {
        openItems + deliveryGoals + completedItems > 0
    }

    static func showsCountBadge(openCount: Int) -> Bool {
        openCount > 0
    }

    static func usesCompactLayout(availableWidth: CGFloat) -> Bool {
        availableWidth < minimumSplitWidth
    }
}

struct NeedsReviewView: View {
    let inbox: ReviewInboxProjection
    @Binding var selectedItemID: ReviewItemID?
    let isPerformingAction: Bool
    let actionFailure: FailureStatePresentation?
    let projectName: String
    let authorizationRecovery: ReviewAuthorizationRecovery?
    let onDecision: (ReviewDecision, ReviewItemProjection) async -> Void
    let onRecoverAuthorization: (URL, ProjectID) async -> Void
    var onAcceptDeliveryGoal: (DeliveryGoalAcceptanceReviewProjection) async -> Void = { _ in }
    var onReload: () async -> Void = {}
    var acceptanceNeedsReload = false
    @State private var selectedGoalID: DeliveryGoalAcceptanceReviewProjection.ID?
    @State private var pendingAssociationFolder: URL?
    @State private var isConfirmingAssociation = false

    private var selectedItem: ReviewItemProjection? {
        inbox.openItems.first { $0.id == selectedItemID } ?? inbox.openItems.first
    }

    private var selectedGoal: DeliveryGoalAcceptanceReviewProjection? {
        if let selectedGoalID { return inbox.deliveryGoalAcceptances.first { $0.id == selectedGoalID } }
        return selectedItemID == nil && inbox.openItems.isEmpty ? inbox.deliveryGoalAcceptances.first : nil
    }

    private var openCount: Int {
        inbox.openItems.count + inbox.deliveryGoalAcceptances.count
    }

    private var showsInboxList: Bool {
        NeedsReviewLayout.showsInboxList(
            openItems: inbox.openItems.count,
            deliveryGoals: inbox.deliveryGoalAcceptances.count,
            completedItems: inbox.completedItems.count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let actionFailure {
                FailureStateView(presentation: actionFailure, style: .inline,
                    actionTitle: authorizationRecovery?.actionTitle ?? (acceptanceNeedsReload ? "Reload dashboard" : nil),
                    action: authorizationRecovery != nil ? recoveryAction : (acceptanceNeedsReload ? { Task { await onReload() } } : nil))
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("review-action-error")
            }
            RekonSeparator()
            if !showsInboxList {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    if NeedsReviewLayout.usesCompactLayout(availableWidth: geometry.size.width) {
                        VStack(spacing: 0) {
                            inboxList
                                .frame(height: 320)
                            RekonSeparator()
                            detail
                        }
                    } else {
                        HSplitView {
                            inboxList
                                .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
                            detail
                                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .background(RekonTheme.background)
        .accessibilityIdentifier("content-needs-review")
        .onAppear {
            if inbox.openItems.isEmpty { selectedGoalID = inbox.deliveryGoalAcceptances.first?.id }
            else { selectedItemID = selectedItem?.id }
        }
        .onChange(of: inbox.deliveryGoalAcceptances.map(\.id)) { _, ids in
            if let selectedGoalID, !ids.contains(selectedGoalID) {
                self.selectedGoalID = ids.first
                if ids.isEmpty { selectedItemID = inbox.openItems.first?.id }
            }
        }
        .confirmationDialog(
            "Associate folder with \(projectName)?",
            isPresented: $isConfirmingAssociation,
            titleVisibility: .visible
        ) {
            Button("Associate project folder") {
                guard let pendingAssociationFolder else { return }
                self.pendingAssociationFolder = nil
                Task {
                    await onRecoverAuthorization(pendingAssociationFolder, inbox.projectID)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingAssociationFolder = nil
            }
        } message: {
            Text("Release Radar will associate the selected folder with \(projectName). This does not resolve or dismiss the review item.")
        }
    }

    private var header: some View {
        RekonScreenHeader(
            title: "Needs Review",
            subtitle: "Owner decisions requested by imports and agents",
            trailing: NeedsReviewLayout.showsCountBadge(openCount: openCount)
                ? AnyView(RekonBadge("\(openCount) open", tone: .warning))
                : nil
        )
    }

    private var inboxList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            if !inbox.deliveryGoalAcceptances.isEmpty {
                inboxSectionTitle("Delivery Goal acceptance")
                VStack(spacing: 8) {
                    ForEach(inbox.deliveryGoalAcceptances) { goal in
                        Button {
                            inboxSelection.wrappedValue = .goal(goal.id)
                        } label: {
                            inboxRow(isSelected: selectedGoalID == goal.id) {
                                Label(goal.title, systemImage: "target")
                                Text("\(goal.phaseName) · Awaiting acceptance")
                                    .font(.caption).foregroundStyle(RekonTheme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delivery Goal \(goal.title), \(goal.phaseName), Awaiting acceptance")
                    }
                }
            }
            inboxSectionTitle("Open")
            VStack(spacing: 8) {
                ForEach(inbox.openItems) { item in
                    Button {
                        inboxSelection.wrappedValue = .item(item.id)
                    } label: {
                        inboxRow(isSelected: selectedItemID == item.id) {
                            HStack(spacing: 10) {
                                Image(systemName: item.kind.systemImage)
                                    .foregroundStyle(RekonTheme.accent)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.kind.title).lineLimit(1)
                                    Text(item.ticketID?.rawValue ?? "Project review")
                                        .font(.caption)
                                        .foregroundStyle(RekonTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.kind.title), \(item.ticketID?.rawValue ?? "project review")")
                }
            }
            if !inbox.completedItems.isEmpty {
                inboxSectionTitle("Completed")
                VStack(spacing: 8) {
                    ForEach(inbox.completedItems) { item in
                        Text("\(item.kind.title) · \(item.status.rawValue.capitalized)")
                            .foregroundStyle(RekonTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            }
            .padding(18)
        }
        .background(RekonTheme.backgroundRaised)
        .accessibilityIdentifier("review-inbox-list")
    }

    private func inboxSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(RekonTypography.compactControlLabel)
            .foregroundStyle(RekonTheme.secondaryText)
            .textCase(.uppercase)
    }

    private func inboxRow<Content: View>(isSelected: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) { content() }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? RekonTheme.elevatedSurface : RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(isSelected ? RekonTheme.accent : RekonTheme.borderSubtle) }
            .foregroundStyle(RekonTheme.primaryText)
    }

    @ViewBuilder
    private var detail: some View {
        if let goal = selectedGoal {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Delivery Goal", systemImage: "target").font(.headline)
                    Text(goal.title).font(.title2.weight(.semibold))
                    Text("\(goal.phaseName) · Awaiting acceptance · revision \(goal.expectedPlanRevision)")
                        .foregroundStyle(.secondary)
                    Text(goal.outcome)
                    Text("Done criteria").font(.headline)
                    ForEach(Array(goal.doneCriteria.enumerated()), id: \.offset) { _, criterion in
                        Label(criterion, systemImage: "checkmark.circle")
                    }
                    Text("Tickets: \(goal.ticketIDs.map(\.rawValue).joined(separator: ", "))")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Accepting confirms this complete outcome as the owner. It does not change ticket lanes or Codex execution goals.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Accept Delivery Goal") { Task { await onAcceptDeliveryGoal(goal) } }
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .disabled(isPerformingAction || authorizationRecovery != nil || acceptanceNeedsReload)
                        .accessibilityIdentifier("delivery-goal-accept")
                        .accessibilityHint("Record owner acceptance of \(goal.title) at phase plan revision \(goal.expectedPlanRevision).")
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(28)
            }
        } else if let item = selectedItem {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    Label(item.kind.title, systemImage: item.kind.systemImage)
                        .font(.title2.weight(.semibold))
                    if let ticketID = item.ticketID {
                        Text(ticketID.rawValue)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.summary)
                        .font(.body)
                    if let importState = FailureStatePresentation(reviewItem: item) {
                        FailureStateView(presentation: importState)
                    } else {
                        Text("This decision updates the persisted review record through the typed agent-action boundary. It does not change a ticket lane.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Resolve") {
                            Task { await onDecision(.resolve, item) }
                        }
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("review-resolve")

                        Button("Dismiss") {
                            Task { await onDecision(.dismiss, item) }
                        }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("review-dismiss")
                    }
                    .disabled(isPerformingAction || authorizationRecovery != nil)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(28)
            }
        } else {
            ProjectEmptyStateView(presentation: .init(
                title: "Inbox clear",
                detail: "No review decisions are waiting for this project.",
                systemImage: "checkmark.circle",
                accessibilityID: "empty-review-inbox"
            ))
        }
    }

    private enum InboxSelection: Hashable {
        case item(ReviewItemID)
        case goal(DeliveryGoalAcceptanceReviewProjection.ID)
    }

    private var inboxSelection: Binding<InboxSelection?> {
        Binding(get: {
            if let selectedGoalID { return .goal(selectedGoalID) }
            return selectedItemID.map(InboxSelection.item)
        }, set: { value in
            switch value {
            case let .goal(id): selectedGoalID = id; selectedItemID = nil
            case let .item(id): selectedGoalID = nil; selectedItemID = id
            case nil: selectedGoalID = nil; selectedItemID = nil
            }
        })
    }

    private var recoveryAction: (() -> Void)? {
        guard authorizationRecovery != nil else { return nil }
        return { chooseAuthorizationFolder() }
    }

    private func chooseAuthorizationFolder() {
        guard let authorizationRecovery else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = authorizationRecovery == .reauthorizeProjectRoot
            ? "Reauthorize"
            : "Choose Project Folder"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        switch authorizationRecovery {
        case .reauthorizeProjectRoot:
            Task { await onRecoverAuthorization(folder, inbox.projectID) }
        case .associateFirstProjectRoot:
            pendingAssociationFolder = folder
            isConfirmingAssociation = true
        }
    }
}

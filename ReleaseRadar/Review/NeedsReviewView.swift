import AppKit
import ReleaseRadarCore
import SwiftUI

struct NeedsReviewView: View {
    let inbox: ReviewInboxProjection
    @Binding var selectedItemID: ReviewItemID?
    let isPerformingAction: Bool
    let actionFailure: FailureStatePresentation?
    let projectName: String
    let authorizationRecovery: ReviewAuthorizationRecovery?
    let onDecision: (ReviewDecision, ReviewItemProjection) async -> Void
    let onRecoverAuthorization: (URL, ProjectID) async -> Void
    @State private var pendingAssociationFolder: URL?
    @State private var isConfirmingAssociation = false

    private var selectedItem: ReviewItemProjection? {
        inbox.openItems.first { $0.id == selectedItemID } ?? inbox.openItems.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            HSplitView {
                inboxList
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
                detail
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityIdentifier("content-needs-review")
        .onAppear {
            selectedItemID = selectedItem?.id
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Needs Review")
                    .font(.largeTitle.weight(.semibold))
                Text("Owner decisions requested by imports and agents")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(inbox.openItems.count) open")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .padding(24)
    }

    private var inboxList: some View {
        List(selection: $selectedItemID) {
            Section("Open") {
                ForEach(inbox.openItems) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.kind.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.kind.title)
                                .lineLimit(1)
                            Text(item.ticketID?.rawValue ?? "Project review")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(item.id)
                    .accessibilityLabel("\(item.kind.title), \(item.ticketID?.rawValue ?? "project review")")
                }
            }
            if !inbox.completedItems.isEmpty {
                Section("Completed") {
                    ForEach(inbox.completedItems) { item in
                        Text("\(item.kind.title) · \(item.status.rawValue.capitalized)")
                            .tag(item.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("review-inbox-list")
    }

    @ViewBuilder
    private var detail: some View {
        if let item = selectedItem {
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

                    if let actionFailure {
                        FailureStateView(
                            presentation: actionFailure,
                            actionTitle: authorizationRecovery?.actionTitle,
                            action: recoveryAction
                        )
                            .accessibilityIdentifier("review-action-error")
                    }

                    HStack {
                        Button("Resolve") {
                            Task { await onDecision(.resolve, item) }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("review-resolve")

                        Button("Dismiss") {
                            Task { await onDecision(.dismiss, item) }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("review-dismiss")
                    }
                    .disabled(isPerformingAction || authorizationRecovery != nil)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(28)
            }
        } else {
            ContentUnavailableView(
                "Inbox clear",
                systemImage: "checkmark.circle",
                description: Text("No review decisions are waiting for this project.")
            )
        }
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

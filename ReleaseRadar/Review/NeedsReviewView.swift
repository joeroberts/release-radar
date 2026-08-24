import SwiftUI
import ReleaseRadarCore

struct NeedsReviewView: View {
    let inbox: ReviewInboxProjection
    @Binding var selectedItemID: ReviewItemID?
    let isPerformingAction: Bool
    let actionError: String?
    let onDecision: (ReviewDecision, ReviewItemProjection) async -> Void

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
            ScrollView {
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
                    Text("This decision updates the persisted review record through the typed agent-action boundary. It does not change a ticket lane.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let actionError {
                        Label(actionError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
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
                    .disabled(isPerformingAction)
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
}

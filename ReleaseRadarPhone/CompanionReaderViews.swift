import SwiftUI

@MainActor
struct CompanionReaderRootView: View {
    @ObservedObject var store: CompanionReaderStore

    var body: some View {
        TabView {
            NavigationStack {
                ProjectsView(store: store)
            }
            .tabItem { Label("Projects", systemImage: "folder") }
            .accessibilityIdentifier("phone.tab.projects")

            NavigationStack {
                OverviewView(store: store)
            }
            .tabItem { Label("Overview", systemImage: "rectangle.grid.2x2") }
            .accessibilityIdentifier("phone.tab.overview")

            NavigationStack {
                WorkView(store: store)
            }
            .tabItem { Label("Work", systemImage: "checklist") }
            .accessibilityIdentifier("phone.tab.work")

            NavigationStack {
                LibraryView(store: store)
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .accessibilityIdentifier("phone.tab.library")

            NavigationStack {
                HistoryView(store: store)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .accessibilityIdentifier("phone.tab.history")
        }
    }
}

@MainActor
private struct ProjectsView: View {
    @ObservedObject var store: CompanionReaderStore

    var body: some View {
        List {
            Section("Projects") {
                if let registrationID = store.snapshot.registrationID, store.snapshot.isCached {
                    NavigationLink {
                        ProjectDetailView(snapshot: store.snapshot)
                    } label: {
                        LabeledContent("Published project", value: registrationID)
                    }
                    .accessibilityIdentifier("phone.project.\(registrationID)")
                } else {
                    ReaderUnavailableRow(
                        title: "No compatible project copy",
                        reason: sourceReason
                    )
                }
            }

            if !trimmedSearch.isEmpty {
                Section("Search results") {
                    if store.searchResults.isEmpty {
                        ReaderUnavailableRow(
                            title: "No compatible results",
                            reason: "Search includes only known, non-withdrawn content in the local copy."
                        )
                    } else {
                        ForEach(store.searchResults) { item in
                            NavigationLink {
                                CompanionItemDetailView(item: item)
                            } label: {
                                CompanionItemRow(item: item)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .searchable(text: $store.searchText, prompt: "Search published content")
    }

    private var trimmedSearch: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceReason: String {
        switch store.snapshot.sourceState {
        case .cached:
            "The local copy does not contain a browsable project."
        case .unavailable:
            "No publication source is configured. A compatible local copy will remain available offline after receipt."
        case let .updateRequired(reason):
            reason
        }
    }
}

@MainActor
private struct OverviewView: View {
    @ObservedObject var store: CompanionReaderStore

    var body: some View {
        List {
            Section("Local copy") {
                StatusRow(title: "Project", value: store.snapshot.registrationID ?? "Unavailable")
                StatusRow(title: "Publisher epoch", value: store.snapshot.publisherEpoch ?? "Unavailable")
                StatusRow(
                    title: "Control sequence",
                    value: store.snapshot.controlSequence.map { String($0) } ?? "Unavailable"
                )
                StatusRow(title: "Account", value: accountDescription)
                StatusRow(title: "Source", value: sourceDescription)
            }

            Section("Provenance") {
                DateStatusRow(title: "Source occurred", date: store.snapshot.sourceOccurredAt)
                DateStatusRow(title: "Published", date: store.snapshot.publishedAt)
                DateStatusRow(title: "Received on this device", date: store.snapshot.deviceReceivedAt)
                DateStatusRow(title: "Last checked on this device", date: store.snapshot.lastCheckedAt)
            }

            Section("Published coverage") {
                if store.snapshot.classCoverage.isEmpty {
                    ReaderUnavailableRow(
                        title: "Coverage unavailable",
                        reason: "No compatible class inventory is stored; missing classes are not treated as empty."
                    )
                } else {
                    ForEach(store.snapshot.classCoverage) { coverage in
                        CoverageRow(coverage: coverage)
                    }
                }
            }

            if !store.snapshot.notices.isEmpty {
                Section("Attention") {
                    ForEach(store.snapshot.notices) { notice in
                        NoticeRow(notice: notice)
                    }
                }
            }
        }
        .navigationTitle("Overview")
        .accessibilityIdentifier("phone.overview")
    }

    private var accountDescription: String {
        switch store.snapshot.accountState {
        case .none: "Unavailable"
        case .bound: "Bound to the current local account"
        case .unknownOffline: "Cached binding retained; current account unknown offline"
        }
    }

    private var sourceDescription: String {
        switch store.snapshot.sourceState {
        case .cached: "Compatible local copy"
        case .unavailable: "Publication source unavailable"
        case .updateRequired: "Reader update required"
        }
    }
}

@MainActor
private struct WorkView: View {
    @ObservedObject var store: CompanionReaderStore

    private var phases: [CompanionReaderItem] {
        store.snapshot.items.filter { if case .phase = $0.content { true } else { false } }
    }

    private var tickets: [CompanionReaderItem] {
        store.snapshot.items.filter { if case .ticket = $0.content { true } else { false } }
    }

    private var reviews: [CompanionReaderItem] {
        store.snapshot.items.filter { if case .review = $0.content { true } else { false } }
    }

    var body: some View {
        List {
            WorkItemSection(title: "Phases", items: phases, emptyReason: coverageReason(for: "deliveryGraph"))
            WorkItemSection(title: "Tickets", items: tickets, emptyReason: coverageReason(for: "deliveryGraph"))
            WorkItemSection(title: "Reviews", items: reviews, emptyReason: coverageReason(for: "reviewMetadata"))

            Section("Current projection limits") {
                ProjectionLimitRow(title: "Delivery plans")
                ProjectionLimitRow(title: "Dependencies")
                ProjectionLimitRow(title: "Blockers")
                ProjectionLimitRow(title: "Progress")
            }
        }
        .navigationTitle("Work")
        .accessibilityIdentifier("phone.work")
    }

    private func coverageReason(for classID: String) -> String {
        guard let coverage = store.snapshot.classCoverage.first(where: { $0.classID == classID }) else {
            return "The publication does not describe this class; it is not treated as empty."
        }
        if let reason = coverage.reason { return reason }
        return coverage.status == .empty
            ? "The publisher explicitly reported this class as empty."
            : "No compatible items are available in the local copy."
    }
}

private struct WorkItemSection: View {
    let title: String
    let items: [CompanionReaderItem]
    let emptyReason: String

    var body: some View {
        Section(title) {
            if items.isEmpty {
                ReaderUnavailableRow(title: "No browsable \(title.lowercased())", reason: emptyReason)
            } else {
                ForEach(items) { item in
                    NavigationLink {
                        CompanionItemDetailView(item: item)
                    } label: {
                        CompanionItemRow(item: item)
                    }
                }
            }
        }
    }
}

@MainActor
private struct LibraryView: View {
    @ObservedObject var store: CompanionReaderStore

    var body: some View {
        List {
            Section("Documents") {
                LibraryAvailabilityRow(title: "Operational documents", classID: "documentation", snapshot: store.snapshot)
                LibraryAvailabilityRow(title: "Architecture and design", classID: "documentation", snapshot: store.snapshot)
                LibraryAvailabilityRow(title: "Briefs", classID: "documentation", snapshot: store.snapshot)
                LibraryAvailabilityRow(title: "Reports", classID: "documentation", snapshot: store.snapshot)
                LibraryAvailabilityRow(title: "Attachments", classID: "documentation", snapshot: store.snapshot)
            }
            Section("Verification") {
                LibraryAvailabilityRow(title: "Evidence", classID: "evidence", snapshot: store.snapshot)
            }
        }
        .navigationTitle("Library")
        .accessibilityIdentifier("phone.library")
    }
}

@MainActor
private struct HistoryView: View {
    @ObservedObject var store: CompanionReaderStore

    private var historyItems: [CompanionReaderItem] {
        store.snapshot.items.filter(\.isHistoryItem)
    }

    var body: some View {
        List {
            Section("Published history") {
                if historyItems.isEmpty {
                    ReaderUnavailableRow(
                        title: "No browsable history",
                        reason: coverageReason
                    )
                } else {
                    ForEach(historyItems) { item in
                        NavigationLink {
                            CompanionItemDetailView(item: item)
                        } label: {
                            CompanionItemRow(item: item)
                        }
                    }
                }
            }
            Section {
                Text("Archived entries remain browsable when published. Withdrawn item bytes and dependent copies are never shown; removal history is limited to the attribution present in the history projection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("History")
        .accessibilityIdentifier("phone.history")
    }

    private var coverageReason: String {
        guard let coverage = store.snapshot.classCoverage.first(where: { $0.classID == "historyMetadata" }) else {
            return "The publication does not describe history; it is not treated as empty."
        }
        return coverage.reason ?? (coverage.status == .empty
            ? "The publisher explicitly reported history as empty."
            : "No compatible history entries are available in the local copy.")
    }
}

private struct ProjectDetailView: View {
    let snapshot: CompanionReaderSnapshot

    var body: some View {
        List {
            Section("Identity") {
                StatusRow(title: "Registration", value: snapshot.registrationID ?? "Unavailable")
                StatusRow(title: "Publisher epoch", value: snapshot.publisherEpoch ?? "Unavailable")
            }
            Section("Browsable local content") {
                StatusRow(title: "Work", value: String(snapshot.items.filter(\.isWorkItem).count))
                StatusRow(title: "History", value: String(snapshot.items.filter(\.isHistoryItem).count))
            }
            Section {
                Text("This is a read-only phone copy. It cannot change delivery state, repository content, or publication records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(snapshot.registrationID ?? "Project")
    }
}

private struct CompanionItemRow: View {
    let item: CompanionReaderItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.content.title)
                .font(.headline)
            Text("\(item.content.kindLabel) · \(item.lifecycle.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("phone.item.\(item.identity.itemID)")
    }
}

private struct CompanionItemDetailView: View {
    let item: CompanionReaderItem

    var body: some View {
        List {
            Section("Published fields") {
                StatusRow(title: "Type", value: item.content.kindLabel)
                StatusRow(title: "Lifecycle", value: item.lifecycle.displayName)
                ForEach(Array(item.content.detailFields.enumerated()), id: \.offset) { _, field in
                    StatusRow(title: field.0, value: field.1)
                }
            }
            Section("Versioned provenance") {
                StatusRow(title: "Item", value: item.identity.itemID)
                StatusRow(title: "Version", value: item.identity.versionID)
                StatusRow(title: "Incarnation", value: item.identity.publicationIncarnationID.uuidString)
                StatusRow(title: "Source", value: item.provenance.sourceIdentity)
                DateStatusRow(title: "Source occurred", date: item.provenance.sourceOccurredAt)
                DateStatusRow(title: "Published", date: item.provenance.publishedAt)
                StatusRow(title: "Content digest", value: item.provenance.contentSHA256)
            }
        }
        .navigationTitle(item.content.title)
    }
}

private struct CoverageRow: View {
    let coverage: CompanionReaderClassCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(coverage.classID.displayClassName)
                Spacer()
                Text(coverage.status.displayName)
                    .foregroundStyle(.secondary)
            }
            if let itemCount = coverage.itemCount {
                Text("\(itemCount) published item\(itemCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let reason = coverage.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryAvailabilityRow: View {
    let title: String
    let classID: String
    let snapshot: CompanionReaderSnapshot

    var body: some View {
        ReaderUnavailableRow(title: title, reason: reason)
    }

    private var reason: String {
        guard let coverage = snapshot.classCoverage.first(where: { $0.classID == classID }) else {
            return "The publication does not describe this class; it is not treated as empty."
        }
        if let reason = coverage.reason { return reason }
        switch coverage.status {
        case .empty: return "The publisher explicitly reported this class as empty."
        case .complete: return "A compatible reader projection for this class is not yet implemented."
        case .unavailable: return "This class is unavailable from the publisher."
        case .excluded: return "This class is intentionally excluded from the phone copy."
        case .unsupported: return "This class is unsupported by the current publication."
        }
    }
}

private struct ProjectionLimitRow: View {
    let title: String

    var body: some View {
        ReaderUnavailableRow(
            title: title,
            reason: "The current producer projection does not publish this field yet."
        )
    }
}

private struct NoticeRow: View {
    let notice: CompanionReaderNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(notice.title, systemImage: notice.kind.systemImage)
                .font(.headline)
            Text(notice.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReaderUnavailableRow: View {
    let title: String
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

private struct DateStatusRow: View {
    let title: String
    let date: Date?

    var body: some View {
        StatusRow(
            title: title,
            value: date?.formatted(date: .abbreviated, time: .standard) ?? "Unavailable"
        )
    }
}

private extension CompanionReaderItem {
    var isWorkItem: Bool {
        switch content {
        case .phase, .ticket, .review: true
        case .history: false
        }
    }

    var isHistoryItem: Bool {
        if case .history = content { return true }
        return false
    }
}

private extension CompanionItemLifecycle {
    var displayName: String {
        switch self {
        case .active: "Active"
        case .archived: "Archived"
        case .removed: "Removed"
        }
    }
}

private extension CompanionClassCoverageStatus {
    var displayName: String {
        switch self {
        case .complete: "Complete"
        case .empty: "Empty"
        case .unavailable: "Unavailable"
        case .excluded: "Excluded"
        case .unsupported: "Unsupported"
        }
    }
}

private extension CompanionReaderNotice.Kind {
    var systemImage: String {
        switch self {
        case .excluded: "lock.shield"
        case .malformed: "exclamationmark.triangle"
        case .unavailable: "icloud.slash"
        case .unsupported: "questionmark.square.dashed"
        case .updateRequired: "arrow.down.circle"
        }
    }
}

private extension String {
    var displayClassName: String {
        switch self {
        case "deliveryGraph": "Delivery work"
        case "reviewMetadata": "Reviews"
        case "historyMetadata": "History"
        case "documentation": "Documentation"
        case "evidence": "Evidence"
        default: self
        }
    }
}

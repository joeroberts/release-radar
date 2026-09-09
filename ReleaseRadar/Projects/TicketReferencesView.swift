import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

enum ReferenceLoadResult<Value: Sendable>: Sendable {
    case loaded(Value)
    case failed(FailureStatePresentation)
}

private enum ReferenceSectionState {
    case idle
    case loaded(TicketReferenceSet)
    case failed(FailureStatePresentation)
}

struct TicketReferencesSection: View {
    let identity: String
    let load: () async -> ReferenceLoadResult<TicketReferenceSet>
    let openSource: (String, Int64) -> Void
    @State private var state: ReferenceSectionState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("References", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            switch state {
            case .idle:
                ProgressView("Loading reference links…")
                    .controlSize(.small)
            case let .failed(failure):
                FailureStateView(
                    presentation: failure,
                    style: .compact,
                    actionTitle: "Retry",
                    action: { Task { await reload() } }
                )
            case let .loaded(referenceSet):
                if referenceSet.links.isEmpty {
                    Text("No requirement or decision links recorded")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Revision \(referenceSet.linkSetRevision) · \(referenceSet.phaseLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(referenceSet.links) { link in
                        referenceCard(link)
                    }
                }
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
        .accessibilityIdentifier("ticket-references")
    }

    private func referenceCard(_ link: TicketReference) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Label(link.kind.displayName, systemImage: link.kind.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(link.relationship.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(link.relationship == .current ? RekonTheme.success : .secondary)
            }
            Text(link.sourceIdentityLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if link.resolution.facts.isEmpty {
                Label("Current source matches linked revision", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.success)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 5)], alignment: .leading, spacing: 5) {
                    ForEach(link.resolution.facts, id: \.self) { fact in
                        Text(fact.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(RekonTheme.elevatedSurface, in: Capsule())
                    }
                }
            }
            ForEach(link.versions) { version in
                Button {
                    openSource(link.id, version.version)
                } label: {
                    HStack {
                        Text("Version \(version.version)")
                        if let sourceLocalID = version.sourceLocalID {
                            Text(sourceLocalID).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("reference-source-\(link.id)-\(version.version)")
            }
        }
        .padding(10)
        .background(RekonTheme.elevatedSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
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

struct TicketReferenceSourceView: View {
    let ticketID: TicketID
    let link: TicketReference
    let selectedVersion: TicketReferenceVersion
    var requestedFocus: NavigationFocus? = nil
    var focusChanged: (NavigationFocus?) -> Void = { _ in }
    let openRecordedImpacts: () -> Void
    @FocusState private var impactsFocused: Bool
    @AccessibilityFocusState private var impactsAccessibilityFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ticketID.rawValue) · \(link.kind.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Reference source")
                        .font(RekonTypography.screenTitle)
                    Text(link.sourceIdentityLabel)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { metadata; resolution }
                    VStack(alignment: .leading, spacing: 16) { metadata; resolution }
                }
                preview
                Button("Recorded impacts", action: openRecordedImpacts)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .focusable()
                    .focused($impactsFocused)
                    .accessibilityFocused($impactsAccessibilityFocused)
                    .accessibilityHint("Shows project tickets explicitly recorded against this source. It does not claim complete semantic coverage.")
                    .accessibilityIdentifier("open-recorded-impacts")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(RekonTheme.background)
        .accessibilityIdentifier("reference-source-browser")
        .onChange(of: requestedFocus) { _, _ in applyRequestedFocus() }
        .task { applyRequestedFocus() }
    }

    private var metadata: some View {
        referencePanel("Linked revision", systemImage: "link") {
            metadataRow("Version", "\(selectedVersion.version)")
            metadataRow("SHA-256", selectedVersion.contentDigest)
            metadataRow("Observed path", selectedVersion.observedPath)
            metadataRow("Catalog", "v\(selectedVersion.catalogVersion) · \(selectedVersion.catalogDigest)")
            if let sourceLocalID = selectedVersion.sourceLocalID { metadataRow("Source-local ID", sourceLocalID) }
            if let locator = selectedVersion.locator { metadataRow("Locator", locator) }
        }
    }

    private var resolution: some View {
        referencePanel("Current resolution", systemImage: "point.3.connected.trianglepath.dotted") {
            if selectedVersion.resolution.facts.isEmpty {
                Label("Current source matches linked revision", systemImage: "checkmark.circle")
                    .foregroundStyle(RekonTheme.success)
            } else {
                ForEach(selectedVersion.resolution.facts, id: \.self) { fact in
                    Label(fact.displayName, systemImage: fact.systemImage)
                }
            }
            if let path = selectedVersion.resolution.currentPath { metadataRow("Current path", path) }
            if let lifecycle = selectedVersion.resolution.currentLifecycle { metadataRow("Lifecycle", lifecycle.rawValue) }
            if let authority = selectedVersion.resolution.currentAuthority { metadataRow("Authority", authority.rawValue) }
        }
    }

    @ViewBuilder private var preview: some View {
        referencePanel("Historical content", systemImage: "doc.plaintext") {
            if let content = selectedVersion.historicalPreview {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("reference-historical-preview")
                if selectedVersion.previewIsTruncated {
                    Text("Preview truncated; the linked digest covers the complete source bytes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Content unavailable for this linked revision. Current prose is not substituted.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("reference-preview-unavailable")
            }
        }
    }

    private func referencePanel<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content().font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(RekonTheme.border, lineWidth: RekonBorder.hairline) }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
        }
    }

    private func applyRequestedFocus() {
        guard requestedFocus == .referenceSource(linkID: link.id, version: selectedVersion.version) else { return }
        impactsFocused = true
        impactsAccessibilityFocused = true
        focusChanged(requestedFocus)
    }
}

struct RecordedImpactsView: View {
    let impacts: RecordedImpacts
    var requestedFocus: NavigationFocus? = nil
    var focusChanged: (NavigationFocus?) -> Void = { _ in }
    let openTicket: (RecordedImpact) -> Void
    @FocusState private var focusedRowID: String?
    @AccessibilityFocusState private var accessibilityFocusedRowID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(impacts.title).font(RekonTypography.screenTitle)
                    Text("Project-scoped tickets explicitly linked to \(impacts.artifactID). This is recorded linkage, not complete semantic impact or delivery coverage.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if impacts.rows.isEmpty {
                    ContentUnavailableView("No recorded impacts", systemImage: "arrow.triangle.branch")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(impacts.rows) { row in
                            Button {
                                focusChanged(.recordedImpact(rowID: row.id))
                                openTicket(row)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: row.kind.systemImage)
                                        .foregroundStyle(RekonTheme.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(row.ticketID).font(.system(.headline, design: .monospaced))
                                            Text(row.phaseLabel).foregroundStyle(.secondary)
                                            Spacer()
                                            Text(row.isCurrent ? "Current" : "Historical")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(row.isCurrent ? RekonTheme.success : .secondary)
                                        }
                                        Text("\(row.kind.displayName) · version \(row.version)")
                                        Text("SHA-256 \(row.contentDigest)")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        if let sourceLocalID = row.sourceLocalID {
                                            Text(sourceLocalID).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(RekonSecondaryButtonStyle())
                            .focusable()
                            .focused($focusedRowID, equals: row.id)
                            .accessibilityFocused($accessibilityFocusedRowID, equals: row.id)
                            .accessibilityIdentifier("recorded-impact-\(row.id)")
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(RekonTheme.background)
        .accessibilityIdentifier("recorded-impacts")
        .onChange(of: requestedFocus) { _, _ in applyRequestedFocus() }
        .task { applyRequestedFocus() }
    }

    private func applyRequestedFocus() {
        let rowID: String?
        switch requestedFocus {
        case .recordedImpacts:
            rowID = impacts.rows.first?.id
        case let .recordedImpact(requestedRowID):
            rowID = impacts.rows.first(where: { $0.id == requestedRowID })?.id
        default:
            rowID = nil
        }
        guard let rowID else { return }
        focusedRowID = rowID
        accessibilityFocusedRowID = rowID
        focusChanged(.recordedImpact(rowID: rowID))
    }
}

private enum SourceRouteState {
    case loading
    case loaded(TicketReference, TicketReferenceVersion)
    case failed(FailureStatePresentation)
}

struct TicketReferenceSourceRouteView: View {
    let identity: String
    let ticketID: TicketID
    let linkID: String
    let version: Int64
    let requestedFocus: NavigationFocus?
    let focusChanged: (NavigationFocus?) -> Void
    let load: () async -> ReferenceLoadResult<TicketReferenceSet>
    let openRecordedImpacts: (String, String) -> Void
    @State private var state: SourceRouteState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading exact reference source…")
                    .controlSize(.large)
            case let .loaded(link, selectedVersion):
                TicketReferenceSourceView(
                    ticketID: ticketID,
                    link: link,
                    selectedVersion: selectedVersion,
                    requestedFocus: requestedFocus,
                    focusChanged: focusChanged,
                    openRecordedImpacts: {
                        openRecordedImpacts(link.repositoryID, link.artifactID)
                    }
                )
            case let .failed(failure):
                FailureStateView(
                    presentation: failure,
                    style: .full,
                    actionTitle: "Retry",
                    action: { Task { await reload() } }
                )
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RekonTheme.background)
        .task(id: "\(identity):\(linkID):\(version)") { await reload() }
    }

    @MainActor
    private func reload() async {
        state = .loading
        let result = await load()
        guard !Task.isCancelled else { return }
        switch result {
        case let .failed(failure):
            state = .failed(failure)
        case let .loaded(set):
            guard let link = set.links.first(where: { $0.id == linkID }),
                  let selectedVersion = link.versions.first(where: { $0.version == version }) else {
                state = .failed(.init(
                    title: "Reference source unavailable",
                    detail: "The exact recorded link or version is no longer available. No replacement source was selected.",
                    systemImage: "questionmark.folder",
                    tone: .warning,
                    accessibilityID: "reference-source-missing"
                ))
                return
            }
            state = .loaded(link, selectedVersion)
        }
    }
}

private enum ImpactsRouteState {
    case loading
    case loaded(RecordedImpacts)
    case failed(FailureStatePresentation)
}

struct RecordedImpactsRouteView: View {
    let identity: String
    let requestedFocus: NavigationFocus?
    let focusChanged: (NavigationFocus?) -> Void
    let load: () async -> ReferenceLoadResult<RecordedImpacts>
    let openTicket: (RecordedImpact) -> Void
    @State private var state: ImpactsRouteState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading recorded impacts…")
                    .controlSize(.large)
            case let .loaded(impacts):
                RecordedImpactsView(
                    impacts: impacts,
                    requestedFocus: requestedFocus,
                    focusChanged: focusChanged,
                    openTicket: openTicket
                )
            case let .failed(failure):
                FailureStateView(
                    presentation: failure,
                    style: .full,
                    actionTitle: "Retry",
                    action: { Task { await reload() } }
                )
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RekonTheme.background)
        .task(id: identity) { await reload() }
    }

    @MainActor
    private func reload() async {
        state = .loading
        let result = await load()
        guard !Task.isCancelled else { return }
        switch result {
        case let .loaded(impacts): state = .loaded(impacts)
        case let .failed(failure): state = .failed(failure)
        }
    }
}

private extension TicketReferenceKind {
    var displayName: String { self == .requirement ? "Requirement" : "Decision" }
    var systemImage: String { self == .requirement ? "checklist" : "signpost.right" }
}

private extension TicketReferenceRelationship {
    var displayName: String { self == .current ? "Current" : "Retired" }
}

private extension TicketReference {
    var sourceIdentityLabel: String { "\(repositoryID) / \(artifactID)" }
}

private extension TicketReferenceImpactFact {
    var displayName: String {
        switch self {
        case .changed: "Changed bytes"
        case .moved: "Moved"
        case .retired: "Retired"
        case .superseded: "Superseded"
        case .archived: "Archived"
        case .noLongerControlling: "No longer controlling"
        case .unavailable: "Unavailable"
        case .unchecked: "Unchecked"
        }
    }
    var systemImage: String {
        switch self {
        case .changed: "arrow.triangle.2.circlepath"
        case .moved: "arrow.right"
        case .retired: "xmark.circle"
        case .superseded: "arrowshape.turn.up.right"
        case .archived: "archivebox"
        case .noLongerControlling: "exclamationmark.shield"
        case .unavailable: "questionmark.folder"
        case .unchecked: "questionmark.circle"
        }
    }
}

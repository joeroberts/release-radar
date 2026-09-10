import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

enum HistoryLayout {
    static func usesStackedDetail(forWidth width: CGFloat) -> Bool { width < 1_000 }
}

struct HistoryView: View {
    let state: HistorySurfaceState
    let projectName: String
    let freshness: CodexObservationFreshness
    let showsFreshness: Bool
    @Binding var selectedFilter: HistoryFilter
    @Binding var selectedEventID: HistoryEventIdentity?
    @Binding var viewportEventID: HistoryEventIdentity?
    var requestedFocus: NavigationFocus?
    var focusChanged: (NavigationFocus?) -> Void
    var openEntity: ((ProjectActivityItem) -> Void)?

    @State private var showsHelp = false
    @FocusState private var focusedEventID: HistoryEventIdentity?
    @FocusState private var focusedDetailEventID: HistoryEventIdentity?
    @FocusState private var filterFocused: Bool
    @AccessibilityFocusState private var accessibilityFocusedEventID: HistoryEventIdentity?
    @AccessibilityFocusState private var accessibilityFocusedDetailEventID: HistoryEventIdentity?
    @AccessibilityFocusState private var accessibilityFilterFocused: Bool

    init(
        activity: ProjectActivityProjection,
        projectName: String,
        freshness: CodexObservationFreshness,
        showsFreshness: Bool = true,
        selectedFilter: Binding<HistoryFilter> = .constant(.all),
        selectedEventID: Binding<HistoryEventIdentity?> = .constant(nil),
        viewportEventID: Binding<HistoryEventIdentity?> = .constant(nil),
        requestedFocus: NavigationFocus? = nil,
        focusChanged: @escaping (NavigationFocus?) -> Void = { _ in },
        openEntity: ((ProjectActivityItem) -> Void)? = nil
    ) {
        state = .loaded(activity)
        self.projectName = projectName
        self.freshness = freshness
        self.showsFreshness = showsFreshness
        _selectedFilter = selectedFilter
        _selectedEventID = selectedEventID
        _viewportEventID = viewportEventID
        self.requestedFocus = requestedFocus
        self.focusChanged = focusChanged
        self.openEntity = openEntity
    }

    init(
        state: HistorySurfaceState,
        projectName: String,
        freshness: CodexObservationFreshness,
        showsFreshness: Bool = true,
        selectedFilter: Binding<HistoryFilter> = .constant(.all),
        selectedEventID: Binding<HistoryEventIdentity?> = .constant(nil),
        viewportEventID: Binding<HistoryEventIdentity?> = .constant(nil),
        requestedFocus: NavigationFocus? = nil,
        focusChanged: @escaping (NavigationFocus?) -> Void = { _ in },
        openEntity: ((ProjectActivityItem) -> Void)? = nil
    ) {
        self.state = state
        self.projectName = projectName
        self.freshness = freshness
        self.showsFreshness = showsFreshness
        _selectedFilter = selectedFilter
        _selectedEventID = selectedEventID
        _viewportEventID = viewportEventID
        self.requestedFocus = requestedFocus
        self.focusChanged = focusChanged
        self.openEntity = openEntity
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    sourceStatus
                    filterControl
                    historyContent(width: geometry.size.width)
                }
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollPosition(id: $viewportEventID, anchor: .top)
        }
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("content-history")
        .sheet(isPresented: $showsHelp) { HistoryHelpView() }
        .task(id: requestedFocus) {
            await Task.yield()
            applyRequestedFocus()
        }
        .onChange(of: selectedFilter) { _, filter in
            guard let selectedEventID,
                  case let .loaded(activity) = state,
                  let item = activity.items.first(where: { $0.identity == selectedEventID }),
                  !filter.includes(item.source) else { return }
            self.selectedEventID = nil
        }
        .onChange(of: focusedEventID) { _, identity in
            if let identity,
               requestedFocus != .historyDetail(identity) {
                focusChanged(.historyEvent(identity))
            }
        }
        .onChange(of: accessibilityFocusedEventID) { _, identity in
            if let identity,
               requestedFocus != .historyDetail(identity) {
                focusChanged(.historyEvent(identity))
            }
        }
        .onChange(of: focusedDetailEventID) { _, identity in
            if let identity { focusChanged(.historyDetail(identity)) }
        }
        .onChange(of: accessibilityFocusedDetailEventID) { _, identity in
            if let identity { focusChanged(.historyDetail(identity)) }
        }
        .onChange(of: filterFocused) { _, focused in
            if focused { focusChanged(.filterSummary) }
        }
        .onChange(of: accessibilityFilterFocused) { _, focused in
            if focused { focusChanged(.filterSummary) }
        }
    }

    private var header: some View {
        RekonScreenHeader(
            title: "History",
            subtitle: "Recorded delivery events for \(projectName)",
            trailing: AnyView(
                Button("Help", systemImage: "questionmark.circle") { showsHelp = true }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("history-help")
            )
        )
    }

    @ViewBuilder
    private var sourceStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsFreshness, let codexFailure = FailureStatePresentation(freshness: freshness) {
                FailureStateView(presentation: codexFailure)
            }
            Text("Audit, review, completion, observation, and notification records keep their own provenance. Observation rows are latest persisted snapshots, not an invented timeline.")
                .font(RekonTypography.metadata)
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("history-source-guidance")
        }
        .padding(.horizontal, 28)
    }

    private var filterControl: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { filterHeading; filterPicker; Spacer() }
            VStack(alignment: .leading, spacing: 8) { filterHeading; filterPicker }
        }
        .padding(.horizontal, 28)
        .accessibilityIdentifier("history-filter-summary")
    }

    private var filterHeading: some View {
        Text("Event source")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private var filterPicker: some View {
        Picker("Event source", selection: $selectedFilter) {
            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 170, alignment: .leading)
        .accessibilityIdentifier("history-filter")
        .focused($filterFocused)
        .accessibilityFocused($accessibilityFilterFocused)
    }

    @ViewBuilder
    private func historyContent(width: CGFloat) -> some View {
        switch state.content(for: selectedFilter) {
        case let .events(items):
            if HistoryLayout.usesStackedDetail(forWidth: width) {
                VStack(alignment: .leading, spacing: 16) {
                    eventList(items)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    RekonSeparator()
                    inspector(items)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 28)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    eventList(items)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    RekonSeparator(.vertical)
                    inspector(items)
                        .frame(width: 350, alignment: .topLeading)
                }
                .padding(.horizontal, 28)
            }
        case .empty:
            contentMessage(title: "No recorded history", detail: "Release Radar has no persisted events for this project yet.", image: "clock")
        case .noMatches:
            contentMessage(title: "No \(selectedFilter.title.lowercased())", detail: "Other recorded event sources remain available. Choose another filter to continue.", image: "line.3.horizontal.decrease.circle")
        case let .failed(message):
            contentMessage(title: "History could not be loaded", detail: message, image: "exclamationmark.triangle")
        case let .incomplete(message):
            contentMessage(title: "History is incomplete", detail: message, image: "clock.badge.questionmark")
        }
    }

    private func eventList(_ items: [ProjectActivityItem]) -> some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(items) { item in eventRow(item) }
        }
        .scrollTargetLayout()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(items.count) History events, newest first")
    }

    private func eventRow(_ item: ProjectActivityItem) -> some View {
        let selected = selectedEventID == item.identity
        return Button {
            selectedEventID = item.identity
            focusedEventID = item.identity
            accessibilityFocusedEventID = item.identity
            focusChanged(.historyEvent(item.identity))
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: item.source.systemImage)
                    .foregroundStyle(item.source.tint)
                    .frame(width: 28, height: 28)
                    .background(item.source.tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack { eventHeading(item); Spacer(); eventTime(item) }
                        VStack(alignment: .leading, spacing: 4) { eventHeading(item); eventTime(item) }
                    }
                    Text(item.detail)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    HStack(spacing: 8) {
                        historyBadge(item.provenance.title, tint: item.source.tint)
                        if item.eventFacts == nil, item.source == .audit {
                            historyBadge("Historical facts unknown", tint: RekonTheme.warning)
                        }
                        if let status = item.notificationStatusText {
                            historyBadge(status, tint: item.notificationState == .unknown ? RekonTheme.warning : item.source.tint)
                        }
                    }
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? AnyShapeStyle(RekonTheme.elevatedSurface) : AnyShapeStyle(RekonTheme.surfaceGradient))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? RekonTheme.accent : RekonTheme.border.opacity(0.82), lineWidth: selected ? 2 : RekonBorder.hairline)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedEventID, equals: item.identity)
        .accessibilityFocused($accessibilityFocusedEventID, equals: item.identity)
        .id(item.identity)
        .accessibilityIdentifier("history-event-\(item.identity.source.rawValue)-\(item.identity.sourceID)")
        .accessibilityLabel(eventAccessibilityLabel(item, selected: selected))
        .accessibilityHint("Select to inspect exact provenance and event-time facts")
    }

    private func eventHeading(_ item: ProjectActivityItem) -> some View {
        HStack(spacing: 8) {
            Text(item.title).font(.headline)
            if let ticketID = item.eventFacts?.ticketID ?? item.ticketID {
                Text(ticketID.rawValue)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
    }

    private func eventTime(_ item: ProjectActivityItem) -> some View {
        Text(item.timelineDate?.formatted(date: .abbreviated, time: .shortened) ?? "Time unknown")
            .font(RekonTypography.metadata)
            .foregroundStyle(RekonTheme.secondaryText)
    }

    private func inspector(_ items: [ProjectActivityItem]) -> some View {
        let selected = selectedEventID.flatMap { identity in items.first { $0.identity == identity } }
        return Group {
            if let selected { eventDetail(selected) }
            else {
                ContentUnavailableView("Select an event", systemImage: "clock.arrow.circlepath", description: Text("Choose a row to inspect its exact source, time, identity, and recorded facts."))
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .accessibilityIdentifier("history-detail-empty")
            }
        }
    }

    private func eventDetail(_ item: ProjectActivityItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event detail")
                .font(.caption.weight(.medium))
                .foregroundStyle(RekonTheme.secondaryText)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            Text(item.title).font(.title3.weight(.semibold))
            detailSection("Recorded detail") {
                Text(item.detail)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("history-detail-record")
            }
            detailSection("Source") {
                detailRow("Provenance", item.provenance.title)
                detailRow("Source ID", item.identity.sourceID)
                detailRow("Registration", item.identity.registrationID ?? "Unknown")
                if let actorID = item.actorID { detailRow("Actor", actorID) }
                if let threadID = item.originatingThreadID { detailRow(item.threadAttribution.threadLabel, threadID) }
            }
            detailSection("Times") {
                detailRow("Occurred", formatted(item.occurredAt))
                detailRow("Observed", formatted(item.observedAt))
                detailRow("Recorded", formatted(item.recordedAt))
            }
            if let facts = item.eventFacts {
                detailSection("Facts at event time") {
                    detailRow("Project", facts.projectName ?? "Unknown")
                    detailRow("Entity", facts.entityType.map { "\($0.rawValue) · \(facts.entityID ?? "Unknown")" } ?? "Unknown")
                    detailRow("Phase", facts.phaseName ?? facts.phaseID?.rawValue ?? "Unknown")
                    detailRow("Outcome", facts.ticketOutcome ?? "Unknown")
                    detailRow("Lane change", transition(facts.previousLane?.dashboardTitle, facts.currentLane?.dashboardTitle))
                    detailRow("Phase change", transition(facts.previousPhaseID?.rawValue, facts.currentPhaseID?.rawValue))
                }
            } else {
                RekonCallout(tone: .warning, systemImage: "questionmark.circle") {
                    Text("Historical facts unknown").font(.headline)
                    Text("This source did not record immutable event-time facts. Current project state is not substituted for the past.")
                }
            }
            if item.source != .audit, let lane = item.deliveryLane {
                detailSection("Current context") { detailRow("Current delivery lane", lane.dashboardTitle) }
            }
            if openEntity != nil,
               item.eventFacts?.ticketID != nil || (item.source != .audit && item.ticketID != nil) {
                Button("Open recorded ticket", systemImage: "arrow.right.circle") {
                    focusedEventID = nil
                    accessibilityFocusedEventID = nil
                    focusedDetailEventID = item.identity
                    accessibilityFocusedDetailEventID = item.identity
                    focusChanged(.historyDetail(item.identity))
                    openEntity?(item)
                }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .focusable()
                    .focused($focusedDetailEventID, equals: item.identity)
                    .accessibilityFocused($accessibilityFocusedDetailEventID, equals: item.identity)
                    .accessibilityIdentifier("history-open-entity")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(18)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(RekonTheme.border, lineWidth: RekonBorder.hairline) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-event-detail")
    }

    private func contentMessage(title: String, detail: String, image: String) -> some View {
        ContentUnavailableView(title, systemImage: image, description: Text(detail))
            .frame(maxWidth: .infinity, minHeight: 320)
            .padding(.horizontal, 28)
            .accessibilityIdentifier("history-content-state")
    }

    private func historyBadge(_ text: String, tint: Color) -> some View {
        Text(text).font(.caption).foregroundStyle(tint)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            Text(value).font(.subheadline).textSelection(.enabled)
        }
    }

    private func formatted(_ date: Date?) -> String { date?.formatted(date: .abbreviated, time: .standard) ?? "Unknown" }

    private func transition(_ previous: String?, _ current: String?) -> String {
        switch (previous, current) {
        case let (previous?, current?) where previous != current: "\(previous) → \(current)"
        case let (_, current?): current
        case let (previous?, nil): previous
        case (nil, nil): "Unknown"
        }
    }

    private func eventAccessibilityLabel(_ item: ProjectActivityItem, selected: Bool) -> String {
        [item.title, item.provenance.title, item.detail, selected ? "selected" : nil]
            .compactMap { $0 }.joined(separator: ", ")
    }

    private func applyRequestedFocus() {
        switch requestedFocus {
        case let .historyEvent(identity):
            if selectedEventID != identity { selectedEventID = identity }
            focusedDetailEventID = nil
            accessibilityFocusedDetailEventID = nil
            focusedEventID = identity
            accessibilityFocusedEventID = identity
        case let .historyDetail(identity):
            if selectedEventID != identity { selectedEventID = identity }
            focusedEventID = nil
            accessibilityFocusedEventID = nil
            focusedDetailEventID = identity
            accessibilityFocusedDetailEventID = identity
        case .filterSummary:
            focusedEventID = nil
            accessibilityFocusedEventID = nil
            focusedDetailEventID = nil
            accessibilityFocusedDetailEventID = nil
            filterFocused = true
            accessibilityFilterFocused = true
        default:
            break
        }
    }
}

typealias ActivityView = HistoryView

struct HistoryHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("History help").font(RekonTypography.screenTitle)
                RekonCallout(tone: .information, systemImage: "checkmark.seal") {
                    Text("Provenance and time").font(.headline)
                    Text("Each row names its persisted source. Occurred, observed, and recorded times stay separate; an asserted thread label is never presented as independently verified.")
                }
                RekonCallout(tone: .warning, systemImage: "questionmark.circle") {
                    Text("Unknown historical facts").font(.headline)
                    Text("Older records may not contain event-time lane, phase, or names. History leaves those facts unknown instead of substituting current project state.")
                }
                RekonCallout(tone: .accent, systemImage: "scope") {
                    Text("Current context and recovery").font(.headline)
                    Text("Current context is explicitly labeled. Open recorded entities when available; Back restores the selected source filter and event. Missing or replaced registrations explain recovery without redirecting to another entity.")
                }
                RekonCallout(tone: .information, systemImage: "bell.badge") {
                    Text("Attention is not acceptance").font(.headline)
                    Text("History browsing and filters do not accept work, change delivery lanes, or create notifications. Copied commands and prompts are not dispatched until a separate supported action actually sends them.")
                }
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(minWidth: 520, idealWidth: 640, minHeight: 540)
        .foregroundStyle(RekonTheme.primaryText)
        .background(RekonTheme.background)
        .accessibilityIdentifier("history-help-sheet")
    }
}

private extension HistoryProvenance {
    var title: String {
        switch self {
        case .localAudit: "Local audit"
        case .persistedObservation: "Persisted observation"
        case .reviewRecord: "Review record"
        case .completionRecord: "Completion record"
        case .notificationDelivery: "Notification delivery"
        case .retainedSource: "Retained history"
        }
    }
}

private extension Optional where Wrapped == ThreadAttribution {
    var threadLabel: String {
        switch self {
        case .some(.verified): "Verified thread"
        case .some(.asserted): "Asserted thread"
        case .some(.none), .none: "Thread"
        }
    }
}

private extension ActivitySource {
    var systemImage: String {
        switch self {
        case .audit: "checkmark.seal"
        case .runtime: "clock.arrow.circlepath"
        case .review: "checkmark.bubble"
        case .completion: "flag.checkered"
        case .notification: "bell"
        }
    }

    var tint: Color {
        switch self {
        case .audit: RekonTheme.violet
        case .runtime: RekonTheme.accent
        case .review: RekonTheme.warning
        case .completion: RekonTheme.success
        case .notification: RekonTheme.danger
        }
    }
}

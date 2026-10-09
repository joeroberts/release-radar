import AppKit
import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct WorkspaceSearchView: View {
    @Bindable var model: AppModel
    @FocusState private var filtersFocused: Bool
    @FocusState private var focusedResultID: Data?
    @FocusState private var detailActionFocused: Bool
    @AccessibilityFocusState private var accessibilityFiltersFocused: Bool
    @AccessibilityFocusState private var accessibilityResultID: Data?
    @AccessibilityFocusState private var accessibilityDetailActionFocused: Bool

    private var results: [WorkspaceSearchResult] { model.workspaceSearchProjection?.results ?? [] }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RekonScreenHeader(
                        title: "Search",
                        subtitle: "Find recorded delivery identities across every authorized project"
                    )
                    queryControls
                    savedQueries
                    status
                    resultsContent(width: geometry.size.width)
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(SearchScrollOffsetBridge(
                    offset: Binding(
                        get: { model.workspaceSearchViewportOffset },
                        set: { model.setWorkspaceSearchViewportOffset($0) }
                    ),
                    restoreToken: model.navigationFocus
                ))
            }
        }
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace-search")
        .task(id: model.navigationFocus) { await Task.yield(); applyRequestedFocus() }
    }

    private var queryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { scopeControl; domainControl; sortControl }
                VStack(alignment: .leading, spacing: 10) { scopeControl; domainControl; sortControl }
            }
            .focusable()
            .focused($filtersFocused)
            .accessibilityFocused($accessibilityFiltersFocused)
            .accessibilityIdentifier("workspace-search-filters")
        }
        .padding(16)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 12))
        .disabled(model.workspaceSearchPreferenceIsUnsupported)
    }

    private var scopeControl: some View {
        Menu {
            Button {
                model.setWorkspaceSearchAllAuthorizedScope()
            } label: {
                if case .allAuthorized = model.workspaceSearchDefinition.scope {
                    Label("All authorized projects", systemImage: "checkmark")
                } else {
                    Text("All authorized projects")
                }
            }
            Divider()
            ForEach(model.availableWorkspaceSearchProjects, id: \.self) { project in
                Toggle(
                    projectLabel(project),
                    isOn: Binding(
                        get: { model.workspaceSearchIncludes(project) },
                        set: { model.setWorkspaceSearchProject(project, enabled: $0) }
                    )
                )
            }
        } label: {
            Label(scopeTitle, systemImage: "folder.badge.gearshape")
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("workspace-search-scope")
    }

    private var domainControl: some View {
        Menu {
            ForEach(WorkspaceSearchDomain.allCases, id: \.self) { domain in
                Toggle(
                    domain.title,
                    isOn: Binding(
                        get: { model.workspaceSearchDefinition.domains.contains(domain) },
                        set: { enabled in
                            Task { await model.updateWorkspaceSearchDomain(domain, enabled: enabled) }
                        }
                    )
                )
            }
        } label: {
            Label("\(model.workspaceSearchDefinition.domains.count) record types", systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("workspace-search-domains")
    }

    private var sortControl: some View {
        Picker(
            "Sort",
            selection: Binding(
                get: { model.workspaceSearchDefinition.sort },
                set: { model.setWorkspaceSearchSort($0) }
            )
        ) {
            ForEach(WorkspaceSearchSort.allCases, id: \.self) { sort in Text(sort.title).tag(sort) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("workspace-search-sort")
    }

    private var savedQueries: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved queries").font(RekonTypography.compactTitle)
            if !model.workspaceSearchSavedQueries.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(model.workspaceSearchSavedQueries) { record in
                            HStack(spacing: 6) {
                                Button(record.name) { Task { await model.loadWorkspaceSavedQuery(record) } }
                                    .buttonStyle(RekonSecondaryButtonStyle())
                                    .disabled(record.isUnsupported)
                                if record.isUnsupported {
                                    Text("Newer version").font(RekonTypography.metadata).foregroundStyle(RekonTheme.warning)
                                }
                                Button(role: .destructive) {
                                    Task { await model.deleteWorkspaceSavedQuery(id: record.id) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Delete \(record.name)")
                            }
                            .accessibilityIdentifier("workspace-saved-query-\(record.id)")
                        }
                    }
                }
            } else {
                Text("Use Save query in the toolbar to name the visible query and options.")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
    }

    @ViewBuilder private var status: some View {
        if model.workspaceSearchIsLoading {
            ProgressView("Searching recorded delivery data…")
        }
        if let failure = model.workspaceSearchFailure {
            RekonCallout(tone: .danger, systemImage: "magnifyingglass.circle") {
                Text("Search unavailable").font(.headline)
                Text(failure)
                if model.workspaceSearchNeedsScopeReselection {
                    Text("Choose the exact current scope. Your earlier restrictive scope stays unchanged until you make one of these choices.")
                    Button("Use all authorized projects") { model.setWorkspaceSearchAllAuthorizedScope() }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("workspace-search-scope-all-recovery")
                    ForEach(model.availableWorkspaceSearchProjects, id: \.self) { project in
                        Button("Use \(projectLabel(project)) only") {
                            model.setWorkspaceSearchProject(project, enabled: true)
                        }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("workspace-search-scope-project-recovery-\(project.registrationID)")
                    }
                }
            }
        }
        if model.workspaceSearchPreferenceIsUnsupported {
            RekonCallout(tone: .warning, systemImage: "exclamationmark.triangle") {
                Text("Saved working search needs a newer Release Radar").font(.headline)
                Text("Its stored filter payload has not been replaced. Reset explicitly or open a supported saved query before Search can run or save.")
                Button("Reset to a new search") { model.resetUnsupportedWorkspaceSearch() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("workspace-search-reset-unsupported")
                Button("Open Help") { Task { await model.navigate(to: .help) } }
                    .buttonStyle(RekonSecondaryButtonStyle())
            }
        }
        if let message = model.workspaceSearchPersistenceMessage {
            Text(message).font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
        }
        if let projection = model.workspaceSearchProjection, !projection.isComplete {
            RekonCallout(tone: .warning, systemImage: "exclamationmark.triangle") {
                Text("Partial results").font(.headline)
                Text("Unavailable: \(projection.omissions.map { $0.domain.title }.joined(separator: ", ")). These results are not complete.")
            }
            .accessibilityIdentifier("workspace-search-partial")
        }
    }

    @ViewBuilder private func resultsContent(width: CGFloat) -> some View {
        if model.workspaceSearchDefinition.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView("Search the workspace", systemImage: "magnifyingglass", description: Text("Enter an ID, name or recorded phrase, then choose Search."))
                .frame(maxWidth: .infinity, minHeight: 320)
        } else if !model.workspaceSearchIsLoading, model.workspaceSearchProjection != nil, results.isEmpty {
            ContentUnavailableView.search(text: model.workspaceSearchDefinition.text)
                .frame(maxWidth: .infinity, minHeight: 320)
                .accessibilityIdentifier("workspace-search-empty")
        } else if !results.isEmpty {
            if width < 900 {
                resultList(inlineSelectedDetail: true)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    resultList(inlineSelectedDetail: false)
                        .frame(minWidth: 300, idealWidth: 380, maxWidth: 460)
                    RekonSeparator(.vertical)
                    selectedDetail.frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private func resultList(inlineSelectedDetail: Bool) -> some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(RekonTypography.metadata)
                .foregroundStyle(RekonTheme.secondaryText)
            ForEach(results) { result in
                resultRow(result, inlineSelectedDetail: inlineSelectedDetail)
                if inlineSelectedDetail, model.selectedWorkspaceSearchResultID == result.id {
                    selectedDetail(result, inline: true)
                }
            }
        }
    }

    private func resultRow(_ result: WorkspaceSearchResult, inlineSelectedDetail: Bool) -> some View {
        let isSelected = model.selectedWorkspaceSearchResultID == result.id
        return Button {
            selectResult(result.id)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(result.domain.title.uppercased()).font(RekonTypography.metadata).foregroundStyle(RekonTheme.accent)
                Text(result.title).font(RekonTypography.compactTitle).lineLimit(inlineSelectedDetail && isSelected ? nil : 2)
                Text(rowProjectLabel(result.project, includeRegistrationDisambiguation: !inlineSelectedDetail))
                    .font(RekonTypography.secondaryBody)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(result.detail)
                    .font(RekonTypography.secondaryBody)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? RekonTheme.accent : RekonTheme.border,
                            lineWidth: isSelected ? 2 : RekonBorder.hairline)
            }
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedResultID, equals: result.id)
        .accessibilityFocused($accessibilityResultID, equals: result.id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
        .accessibilityLabel(
            "\(result.domain.singularTitle): \(result.title), \(rowProjectLabel(result.project, includeRegistrationDisambiguation: !inlineSelectedDetail)), \(result.detail)"
                + (result.isRetired ? ", Retired record" : "")
        )
        .accessibilityIdentifier("workspace-search-result-\(result.id.base64EncodedString())")
        .onMoveCommand { moveSelection($0, from: result.id) }
        .onKeyPress { press in
            guard press.key == .tab, isSelected, !press.modifiers.contains(.shift) else { return .ignored }
            focusDetailAction()
            return .handled
        }
    }

    @ViewBuilder private var selectedDetail: some View {
        if let selected = results.first(where: { $0.id == model.selectedWorkspaceSearchResultID }) {
            selectedDetail(selected, inline: false)
        } else {
            ContentUnavailableView("Select a result", systemImage: "cursorarrow.click")
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("workspace-search-detail")
        }
    }

    private func selectedDetail(_ selected: WorkspaceSearchResult, inline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if inline {
                Text("Result detail")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.accent)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text(selected.domain.singularTitle.uppercased())
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.accent)
                    .accessibilityAddTraits(.isHeader)
                Text(selected.title)
                    .font(RekonTypography.compactTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Project: \(projectContextLabel(selected.project))")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(selected.detail).font(RekonTypography.body)
            Text(detailIdentity(selected))
                .font(RekonTypography.metadata)
                .foregroundStyle(RekonTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let occurredAt = selected.occurredAt {
                Text("\(occurredAtLabel(for: selected)): \(occurredAt)")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            if selected.isRetired { Text("Retired record").foregroundStyle(RekonTheme.warning) }
            Button(actionTitle(for: selected)) { Task { await model.openWorkspaceSearchResult(selected) } }
                .buttonStyle(RekonPrimaryButtonStyle())
                .focusable()
                .focused($detailActionFocused)
                .accessibilityFocused($accessibilityDetailActionFocused)
                .accessibilityLabel("\(actionTitle(for: selected)): \(selected.title)")
                .accessibilityIdentifier("workspace-search-open-result")
                .onKeyPress(phases: .down) { press in
                    let isBacktab = press.key == .tab || press.characters == "\u{19}"
                    if isBacktab, press.modifiers.contains(.shift) {
                        returnFocusToSelectedResult(selected.id)
                        return .handled
                    }
                    guard press.key == .return || press.key == .space else { return .ignored }
                    Task { await model.openWorkspaceSearchResult(selected) }
                    return .handled
                }
        }
        .padding(inline ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace-search-detail")
        .onExitCommand { returnFocusToSelectedResult(selected.id) }
    }

    private var scopeTitle: String {
        switch model.workspaceSearchDefinition.scope {
        case .allAuthorized: "All authorized projects"
        case let .registrations(registrations): "\(registrations.count) selected project\(registrations.count == 1 ? "" : "s")"
        }
    }

    private func projectLabel(_ project: WorkspaceSearchProjectIdentity) -> String {
        "\(project.name) · \(project.lifecycle == .archived ? "Archived" : "Active") · Registration \(project.registrationID)"
    }

    private func projectContextLabel(_ project: WorkspaceSearchProjectIdentity) -> String {
        "\(project.name) · \(project.lifecycle == .archived ? "Archived" : "Active")"
    }

    private func rowProjectLabel(
        _ project: WorkspaceSearchProjectIdentity,
        includeRegistrationDisambiguation: Bool
    ) -> String {
        guard includeRegistrationDisambiguation, results.contains(where: {
            $0.project.name == project.name && $0.project.registrationID != project.registrationID
        }) else {
            return projectContextLabel(project)
        }
        return "\(projectContextLabel(project)) · Registration \(project.registrationID)"
    }

    private func selectResult(_ id: Data) {
        model.selectWorkspaceSearchResult(id)
        focusedResultID = id
        accessibilityResultID = id
        detailActionFocused = false
        accessibilityDetailActionFocused = false
    }

    private func moveSelection(_ direction: MoveCommandDirection, from id: Data) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        let destination: Int
        switch direction {
        case .up:
            destination = max(results.startIndex, index - 1)
        case .down:
            destination = min(results.index(before: results.endIndex), index + 1)
        default:
            return
        }
        guard destination != index else { return }
        selectResult(results[destination].id)
    }

    private func returnFocusToSelectedResult(_ id: Data) {
        guard model.selectedWorkspaceSearchResultID == id else { return }
        focusedResultID = id
        accessibilityResultID = id
        detailActionFocused = false
        accessibilityDetailActionFocused = false
    }

    private func focusDetailAction() {
        detailActionFocused = true
        accessibilityDetailActionFocused = true
    }

    private func actionTitle(for result: WorkspaceSearchResult) -> String {
        switch result.identity {
        case .project:
            return result.project.lifecycle == .archived ? "View archived project" : "Open project"
        case .deliveryGoal:
            return "View associated work"
        case .executionGoal:
            return "Open execution goal"
        case .ticket:
            return "Open ticket"
        case .decisionReference:
            return "Open decision source"
        case .history:
            return "Open history event"
        }
    }

    private func detailIdentity(_ result: WorkspaceSearchResult) -> String {
        switch result.identity {
        case let .project(projectID, registrationID):
            return "Project ID: \(projectID.rawValue) · Registration: \(registrationID)"
        case let .deliveryGoal(_, _, phaseID, goalID):
            return "Goal ID: \(goalID) · Phase ID: \(phaseID.rawValue)"
        case let .executionGoal(_, _, threadID, goalID):
            return "Thread: \(threadID.rawValue) · Goal ID: \(goalID.rawValue)"
        case let .ticket(_, _, ticketID, phaseID):
            return "Ticket ID: \(ticketID.rawValue)\(phaseID.map { " · Phase ID: \($0.rawValue)" } ?? "")"
        case let .decisionReference(_, _, ticketID, linkID, version, _, artifactID):
            return "Ticket ID: \(ticketID.rawValue) · Reference: \(linkID) · Version: \(version) · Artifact: \(artifactID)"
        case let .history(_, _, source, sourceID):
            return "\(source.rawValue.capitalized) source ID: \(sourceID)"
        }
    }

    private func occurredAtLabel(for result: WorkspaceSearchResult) -> String {
        switch result.identity {
        case .deliveryGoal:
            return "Recorded update"
        case .executionGoal:
            return "Last observed"
        case .ticket:
            return "Retired on"
        case .decisionReference:
            return "Reference version created"
        case let .history(_, _, source, _):
            return source == .observation ? "Last observed" : "Source created"
        case .project:
            return "Recorded at"
        }
    }

    private func applyRequestedFocus() {
        switch model.navigationFocus {
        case .workspaceSearchFilters:
            filtersFocused = true
            accessibilityFiltersFocused = true
        case let .workspaceSearchResult(id):
            focusedResultID = id
            accessibilityResultID = id
        default: break
        }
    }
}

private extension WorkspaceSearchSort {
    var title: String {
        switch self {
        case .domainThenTitle: "Record type, then title"
        case .title: "Title"
        case .newest: "Newest first"
        }
    }
}

private extension WorkspaceSearchDomain {
    var singularTitle: String {
        switch self {
        case .project: "Project"
        case .deliveryGoal: "Delivery Goal"
        case .executionGoal: "Execution Goal"
        case .ticket: "Ticket"
        case .decisionReference: "Decision reference"
        case .history: "History event"
        }
    }
}

private extension WorkspaceSavedQueryRecord {
    var isUnsupported: Bool {
        if case .unsupported = self { true } else { false }
    }
}

private struct SearchScrollOffsetBridge: NSViewRepresentable {
    @Binding var offset: Double?
    let restoreToken: NavigationFocus?

    func makeCoordinator() -> Coordinator { Coordinator(offset: $offset, restoreToken: restoreToken) }
    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.changed = { [weak coordinator = context.coordinator] view in
            coordinator?.attach(to: view.enclosingScrollView)
            coordinator?.restoreIfPossible()
        }
        return view
    }
    func updateNSView(_ nsView: ProbeView, context: Context) {
        context.coordinator.update(offset: $offset, restoreToken: restoreToken)
        context.coordinator.attach(to: nsView.enclosingScrollView)
        context.coordinator.restoreIfPossible()
    }
    static func dismantleNSView(_ nsView: ProbeView, coordinator: Coordinator) {
        coordinator.detach(); nsView.changed = nil
    }

    final class ProbeView: NSView {
        var changed: ((ProbeView) -> Void)?
        override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); changed?(self) }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); changed?(self) }
        override func layout() { super.layout(); changed?(self) }
    }

    @MainActor final class Coordinator: NSObject {
        private var offset: Binding<Double?>
        private var restoreToken: NavigationFocus?
        private weak var scrollView: NSScrollView?
        private weak var clipView: NSClipView?
        private var pending: Double?
        private var observed: Double?
        private var restoring = false

        init(offset: Binding<Double?>, restoreToken: NavigationFocus?) {
            self.offset = offset; self.restoreToken = restoreToken
            observed = offset.wrappedValue; pending = offset.wrappedValue
        }
        func update(offset: Binding<Double?>, restoreToken: NavigationFocus?) {
            self.offset = offset
            let requested = offset.wrappedValue
            guard self.restoreToken != restoreToken || observed != requested else { return }
            self.restoreToken = restoreToken; observed = requested; pending = requested
        }
        func attach(to scrollView: NSScrollView?) {
            guard let scrollView, self.scrollView !== scrollView else { return }
            detach(); self.scrollView = scrollView; clipView = scrollView.contentView
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(changed), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
            pending = offset.wrappedValue
        }
        func detach() {
            if let clipView { NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: clipView) }
            scrollView = nil; clipView = nil
        }
        func restoreIfPossible() {
            guard let requested = pending, let scrollView, let clipView, let document = scrollView.documentView else { return }
            let maximum = max(0, document.bounds.height - clipView.bounds.height)
            guard requested == 0 || maximum > 0 else { return }
            pending = nil; restoring = true
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: min(max(0, CGFloat(requested)), maximum)))
            scrollView.reflectScrolledClipView(clipView); restoring = false
        }
        @objc private func changed() {
            if pending != nil { restoreIfPossible(); return }
            guard !restoring, let clipView else { return }
            let value = Double(max(0, clipView.bounds.origin.y)); observed = value
            if offset.wrappedValue.map({ abs($0 - value) > 0.5 }) ?? true { offset.wrappedValue = value }
        }
    }
}

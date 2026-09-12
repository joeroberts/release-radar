import AppKit
import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct WorkspaceSearchView: View {
    @Bindable var model: AppModel
    @State private var savedQueryName = ""
    @FocusState private var searchFieldFocused: Bool
    @FocusState private var filtersFocused: Bool
    @FocusState private var focusedResultID: Data?
    @AccessibilityFocusState private var accessibilitySearchFieldFocused: Bool
    @AccessibilityFocusState private var accessibilityFiltersFocused: Bool
    @AccessibilityFocusState private var accessibilityResultID: Data?

    private var results: [WorkspaceSearchResult] { model.workspaceSearchProjection?.results ?? [] }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RekonScreenHeader(
                        title: "Search",
                        subtitle: "Find recorded delivery identities across every authorized project",
                        trailing: AnyView(
                            Button("Help", systemImage: "questionmark.circle") {
                                Task { await model.navigate(to: .help) }
                            }
                            .buttonStyle(RekonSecondaryButtonStyle())
                            .accessibilityIdentifier("search-help")
                        )
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
            HStack(spacing: 10) {
                TextField(
                    "Search IDs, names and recorded text",
                    text: Binding(
                        get: { model.workspaceSearchDefinition.text },
                        set: { model.setWorkspaceSearchText($0) }
                    )
                )
                .textFieldStyle(RekonQuietTextFieldStyle())
                .onSubmit { Task { await model.runWorkspaceSearch() } }
                .focused($searchFieldFocused)
                .accessibilityFocused($accessibilitySearchFieldFocused)
                .accessibilityIdentifier("workspace-search-field")

                Button("Search", systemImage: "magnifyingglass") {
                    Task { await model.runWorkspaceSearch() }
                }
                .buttonStyle(RekonPrimaryButtonStyle())
                .disabled(
                    model.workspaceSearchIsLoading
                        || model.workspaceSearchPreferenceIsUnsupported
                        || model.workspaceSearchNeedsScopeReselection
                )
                .accessibilityIdentifier("workspace-search-run")
            }

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
                        set: { model.setWorkspaceSearchDomain(domain, enabled: $0) }
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
            HStack(spacing: 8) {
                TextField("Query name", text: $savedQueryName)
                    .textFieldStyle(RekonQuietTextFieldStyle())
                    .accessibilityIdentifier("workspace-search-save-name")
                Button("Save") {
                    let name = savedQueryName
                    Task {
                        await model.saveCurrentWorkspaceSearch(name: name)
                        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { savedQueryName = "" }
                    }
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(
                    model.workspaceSearchPreferenceIsUnsupported
                        || model.workspaceSearchNeedsScopeReselection
                )
                .accessibilityIdentifier("workspace-search-save")
            }
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
                VStack(alignment: .leading, spacing: 18) { resultList; selectedDetail }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    resultList.frame(minWidth: 300, idealWidth: 380, maxWidth: 460)
                    RekonSeparator(.vertical)
                    selectedDetail.frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var resultList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(RekonTypography.metadata)
                .foregroundStyle(RekonTheme.secondaryText)
            ForEach(results) { result in
                Button {
                    model.selectWorkspaceSearchResult(result.id)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.domain.title.uppercased()).font(RekonTypography.metadata).foregroundStyle(RekonTheme.accent)
                        Text(result.title).font(RekonTypography.compactTitle).lineLimit(2)
                        Text(projectLabel(result.project))
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
                            .stroke(model.selectedWorkspaceSearchResultID == result.id ? RekonTheme.accent : RekonTheme.border,
                                    lineWidth: model.selectedWorkspaceSearchResultID == result.id ? 2 : RekonBorder.hairline)
                    }
                }
                .buttonStyle(.plain)
                .focusable()
                .focused($focusedResultID, equals: result.id)
                .accessibilityFocused($accessibilityResultID, equals: result.id)
                .accessibilityIdentifier("workspace-search-result-\(result.id.base64EncodedString())")
            }
        }
    }

    @ViewBuilder private var selectedDetail: some View {
        if let selected = results.first(where: { $0.id == model.selectedWorkspaceSearchResultID }) {
            VStack(alignment: .leading, spacing: 12) {
                Text(selected.domain.title.uppercased()).font(RekonTypography.metadata).foregroundStyle(RekonTheme.accent)
                Text(selected.title).font(RekonTypography.screenTitle)
                Text(selected.detail).font(RekonTypography.body)
                Text("Project: \(projectLabel(selected.project))")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if selected.isRetired { Text("Retired record").foregroundStyle(RekonTheme.warning) }
                Button("Open exact record") { Task { await model.openWorkspaceSearchResult(selected) } }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("workspace-search-open-result")
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
            .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("workspace-search-detail")
        } else {
            ContentUnavailableView("Select a result", systemImage: "cursorarrow.click")
                .frame(maxWidth: .infinity, minHeight: 250)
        }
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

    private func applyRequestedFocus() {
        switch model.navigationFocus {
        case .workspaceSearchField:
            searchFieldFocused = true
            accessibilitySearchFieldFocused = true
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

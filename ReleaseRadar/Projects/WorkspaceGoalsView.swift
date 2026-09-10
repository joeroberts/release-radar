import AppKit
import RekonDesignSystem
import ReleaseRadarCore
import SwiftUI

enum WorkspaceGoalsDomain: String, CaseIterable, Identifiable, Sendable {
    case delivery
    case execution

    var id: Self { self }
    var title: String { self == .delivery ? "Delivery" : "Execution" }
}

enum WorkspaceExecutionScope: String, CaseIterable, Identifiable, Sendable {
    case all, linked, unlinked
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "All goals"
        case .linked: "Linked work"
        case .unlinked: "Unlinked observations"
        }
    }
}

enum WorkspaceGoalsLayout {
    static func usesStackedDetail(forWidth width: CGFloat) -> Bool { width < 1_000 }
}

struct WorkspaceGoalsProjectChoice: Equatable {
    let id: Data
    let label: String
}

func workspaceGoalsProjectChoices(_ projects: [ProjectDashboardProjection]) -> [WorkspaceGoalsProjectChoice] {
    var unique: [Data: ProjectDashboardProjection] = [:]
    for project in projects {
        let id = Data(project.id.rawValue.utf8)
        if unique[id] == nil { unique[id] = project }
    }
    let ordered = unique.values.sorted {
        if $0.name != $1.name { return $0.name < $1.name }
        return $0.id.rawValue.utf8.lexicographicallyPrecedes($1.id.rawValue.utf8)
    }
    return ByteStablePickerOption.disambiguating(ordered.map {
        (label: $0.name, byteIdentity: $0.id.rawValue, value: Data($0.id.rawValue.utf8))
    }).map { .init(id: $0.value, label: $0.selection) }
}

func workspaceDeliveryIdentityCue(
    for item: WorkspaceDeliveryGoalProjection,
    among items: [WorkspaceDeliveryGoalProjection]
) -> String? {
    let collides = items.filter {
        $0.project.name == item.project.name
            && $0.phaseName == item.phaseName
            && $0.goal.title == item.goal.title
    }.count > 1
    guard collides else { return nil }
    return "Project \(item.project.id.rawValue) · phase \(item.phaseID.rawValue) · goal \(item.goal.goalID.rawValue)"
}

struct WorkspaceDeliveryGoalFacts: Equatable {
    let formalState: String
    let phaseLifecycle: String
    let structuralReadiness: String
    let coverage: String
    let ownerAcceptance: String
}

func workspaceDeliveryGoalFacts(_ item: WorkspaceDeliveryGoalProjection) -> WorkspaceDeliveryGoalFacts {
    let readiness = switch item.phasePlan.state {
    case .legacyUnassessed: "Legacy unassessed"
    case .draft: "Draft"
    case .ready: "Ready"
    }
    let coverage: String
    if let assessment = item.goal.coverage {
        coverage = "Carried-obligation coverage: \(assessment.deliveredLeafCount)/\(assessment.requiredLeafCount) delivered · \(assessment.isResolved ? "resolved" : "unresolved") · \(assessment.isAcceptanceEligible ? "acceptance eligible" : "not acceptance eligible")"
    } else {
        coverage = "Carried-obligation coverage: unavailable"
    }
    return .init(
        formalState: "Formal Delivery Goal state: \(item.goal.lifecycle.displayName)",
        phaseLifecycle: "Phase lifecycle: \(item.phaseLifecycle?.lifecycle.displayName ?? "Unavailable")",
        structuralReadiness: "Structural readiness: \(readiness) · revision \(item.phasePlan.revision) · \(item.phasePlan.coveredUpcomingCount)/\(item.phasePlan.upcomingCount) upcoming work covered · \(item.phasePlan.unassignedUpcomingCount) unassigned",
        coverage: coverage,
        ownerAcceptance: item.goal.lifecycle == .accepted
            ? "Owner acceptance: Recorded"
            : "Owner acceptance: Not recorded"
    )
}

struct WorkspaceGoalsView: View {
    let goals: WorkspaceGoalsProjection
    let freshness: CodexObservationFreshness
    let openDeliveryGoal: (WorkspaceDeliveryGoalProjection) -> Void
    let openUnassignedWork: (WorkspaceUnassignedDeliveryWorkProjection) -> Void
    let openExecutionGoal: (WorkspaceExecutionGoalProjection) -> Void
    @Binding var domain: WorkspaceGoalsDomain
    @Binding var projectID: ProjectID?
    @Binding var deliveryLifecycle: DeliveryGoalLifecycle?
    @Binding var executionStatus: String?
    @Binding var executionScope: WorkspaceExecutionScope
    @Binding var selectedDeliveryID: Data?
    @Binding var selectedExecutionID: Data?
    @Binding var viewportOffset: Double?
    var requestedFocus: NavigationFocus?
    var focusChanged: (NavigationFocus?) -> Void

    @State private var showsHelp = false
    @FocusState private var focusedGoalID: Data?
    @FocusState private var filterFocused: Bool
    @AccessibilityFocusState private var accessibilityFocusedGoalID: Data?
    @AccessibilityFocusState private var accessibilityFilterFocused: Bool

    private var projects: [ProjectDashboardProjection] {
        let delivery = goals.delivery.map(\.project)
        let execution = goals.execution.map(\.project)
        let unassigned = goals.unassignedDeliveryWork.map(\.project)
        var projectsByID: [Data: ProjectDashboardProjection] = [:]
        for project in delivery + execution + unassigned {
            let id = Data(project.id.rawValue.utf8)
            if projectsByID[id] == nil { projectsByID[id] = project }
        }
        return projectsByID.values.sorted { $0.name < $1.name }
    }

    private var projectChoices: [WorkspaceGoalsProjectChoice] {
        workspaceGoalsProjectChoices(projects)
    }

    private var delivery: [WorkspaceDeliveryGoalProjection] {
        goals.delivery.filter {
            matchesSelectedProject($0.project.id)
                && (deliveryLifecycle == nil || $0.goal.lifecycle == deliveryLifecycle)
        }
    }

    private var unassignedWork: [WorkspaceUnassignedDeliveryWorkProjection] {
        guard deliveryLifecycle == nil else { return [] }
        return goals.unassignedDeliveryWork.filter { matchesSelectedProject($0.project.id) }
    }

    private var execution: [WorkspaceExecutionGoalProjection] {
        goals.execution.filter {
            matchesSelectedProject($0.project.id)
                && (executionStatus == nil || $0.status == executionStatus)
                && (executionScope == .all || (executionScope == .linked) == ($0.link.ticketID != nil))
        }
    }

    private var executionStatuses: [String] {
        Array(Set(goals.execution.map(\.status))).sorted()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    sourceStatus
                    controls
                    if domain == .delivery {
                        deliveryContent(width: geometry.size.width)
                    } else {
                        executionContent(width: geometry.size.width)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(WorkspaceGoalsScrollOffsetBridge(offset: $viewportOffset, restoreToken: requestedFocus))
            }
        }
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace-goals")
        .sheet(isPresented: $showsHelp) { WorkspaceGoalsHelpView() }
        .task(id: requestedFocus) { await Task.yield(); applyRequestedFocus() }
        .onChange(of: focusedGoalID) { _, id in if let id { focusChanged(.workspaceGoal(id)) } }
        .onChange(of: accessibilityFocusedGoalID) { _, id in if let id { focusChanged(.workspaceGoal(id)) } }
        .onChange(of: filterFocused) { _, focused in if focused { focusChanged(.workspaceGoalsFilter) } }
        .onChange(of: accessibilityFilterFocused) { _, focused in if focused { focusChanged(.workspaceGoalsFilter) } }
    }

    private var header: some View {
        RekonScreenHeader(
            title: "Goals",
            subtitle: "Delivery outcomes and persisted Codex execution observations across active projects",
            trailing: AnyView(
                Button("Help", systemImage: "questionmark.circle") { showsHelp = true }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("goals-help")
            )
        )
    }

    @ViewBuilder private var sourceStatus: some View {
        if domain == .execution {
            VStack(alignment: .leading, spacing: 10) {
                if let codexFailure = FailureStatePresentation(freshness: freshness) {
                    FailureStateView(presentation: codexFailure)
                }
                Text("Source · persisted snapshot. Stored observations remain available when live Codex observation is stale or unavailable.")
                    .font(RekonTypography.metadata)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .accessibilityIdentifier("goals-execution-source")
            }
        }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { domainPicker; projectPicker; statePickers; Spacer() }
            VStack(alignment: .leading, spacing: 10) { domainPicker; projectPicker; statePickers }
        }
        .accessibilityIdentifier("goals-filter-summary")
    }

    private var domainPicker: some View {
        Picker("Goal domain", selection: $domain) {
            ForEach(WorkspaceGoalsDomain.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .accessibilityIdentifier("goals-domain")
        .focused($filterFocused)
        .accessibilityFocused($accessibilityFilterFocused)
    }

    private var projectPicker: some View {
        Picker("Projects", selection: Binding(
            get: { projectID.map { Data($0.rawValue.utf8) } },
            set: { identity in
                projectID = identity.flatMap { selected in
                    projects.first(where: { Data($0.id.rawValue.utf8) == selected })?.id
                }
            }
        )) {
            Text("All Projects").tag(Data?.none)
            ForEach(projectChoices, id: \.id) { choice in
                Text(choice.label).tag(Data?.some(choice.id))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("goals-project-filter")
    }

    @ViewBuilder private var statePickers: some View {
        if domain == .delivery {
            Picker("Delivery state", selection: $deliveryLifecycle) {
                Text("All states").tag(DeliveryGoalLifecycle?.none)
                ForEach(DeliveryGoalLifecycle.allCases, id: \.self) { lifecycle in
                    Text(lifecycle.displayName).tag(DeliveryGoalLifecycle?.some(lifecycle))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("goals-delivery-state-filter")
        } else {
            HStack(spacing: 12) {
                Picker("Execution state", selection: $executionStatus) {
                    Text("All states").tag(String?.none)
                    ForEach(executionStatuses, id: \.self) { status in Text(status).tag(String?.some(status)) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("goals-execution-state-filter")
                Picker("Execution links", selection: $executionScope) {
                    ForEach(WorkspaceExecutionScope.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("goals-execution-link-filter")
            }
        }
    }

    private func deliveryContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if !unassignedWork.isEmpty { unassignedSection }
            if delivery.isEmpty {
                goalsEmptyState(
                    title: goals.delivery.isEmpty ? "No Delivery Goals recorded" : "No Delivery Goals match these filters",
                    detail: goals.delivery.isEmpty
                        ? "No phase-owned Delivery Goals are recorded. Unassigned and legacy work remains visible without inferring a goal."
                        : "Other recorded Delivery Goals remain available. Clear the project and state filters to continue.",
                    canReset: projectID != nil || deliveryLifecycle != nil,
                    reset: { projectID = nil; deliveryLifecycle = nil }
                )
            } else {
                goalsSplitView(items: delivery, selectedID: $selectedDeliveryID, width: width, row: deliveryRow, detail: deliveryDetail)
            }
        }
    }

    private var unassignedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Work with no Delivery Goal").font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(unassignedWork) { item in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.project.name) · \(item.phaseName ?? "Not placed")")
                        Text("\(item.tickets.count) persisted work item\(item.tickets.count == 1 ? "" : "s") · no goal inferred")
                            .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
                    }
                    Spacer()
                    Button("View unassigned work") { openUnassignedWork(item) }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("goals-open-unassigned-work")
                }
                .padding(14)
                .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .accessibilityIdentifier("goals-unassigned-work")
    }

    private func deliveryRow(_ item: WorkspaceDeliveryGoalProjection) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.goal.title).font(RekonTypography.cardTitle)
            Text("\(item.project.name) · \(item.phaseName)").font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
            if let cue = workspaceDeliveryIdentityCue(for: item, among: delivery) {
                Text(cue).font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
            }
            Text("\(item.goal.lifecycle.displayName) · \(item.goal.ticketIDs.count) associated work item\(item.goal.ticketIDs.count == 1 ? "" : "s")")
                .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private func deliveryDetail(_ item: WorkspaceDeliveryGoalProjection) -> some View {
        let facts = workspaceDeliveryGoalFacts(item)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Delivery Goal · \(item.project.name) · \(item.phaseName)")
                .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText).textCase(.uppercase)
            Text(item.goal.title).font(RekonTypography.screenTitle)
            Text(item.goal.outcome).foregroundStyle(RekonTheme.secondaryText)
            Text(facts.formalState)
            Text(facts.phaseLifecycle)
            Text(facts.structuralReadiness)
            Text(facts.coverage)
            Text("\(facts.ownerAcceptance). Browsing does not accept outcomes or change formal delivery state.")
                .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
            if item.goal.doneCriteria.isEmpty {
                Text("No recorded criteria").foregroundStyle(RekonTheme.secondaryText)
            } else {
                ForEach(Array(item.goal.doneCriteria.enumerated()), id: \.offset) { _, criterion in
                    Label(criterion, systemImage: "checkmark.circle")
                }
            }
            Button("View associated work") { openDeliveryGoal(item) }
                .buttonStyle(RekonPrimaryButtonStyle())
                .accessibilityIdentifier("goals-open-associated-work")
        }
    }

    private func executionContent(width: CGFloat) -> some View {
        Group {
            if execution.isEmpty {
                let selectedProjectHasNoObservations = projectID != nil
                    && !goals.execution.contains(where: { matchesSelectedProject($0.project.id) })
                goalsEmptyState(
                    title: selectedProjectHasNoObservations
                        ? "Known project, no persisted observation"
                        : (goals.execution.isEmpty ? "No persisted execution observations" : "No persisted goals match these filters"),
                    detail: selectedProjectHasNoObservations
                        ? "The project is known locally, but no authorized cached goal observation exists."
                        : (goals.execution.isEmpty
                            ? "No persisted Codex execution goals are available. This is distinct from observer availability."
                            : "Other persisted observations remain available. Clear the project, state, and link filters to continue."),
                    canReset: projectID != nil || executionStatus != nil || executionScope != .all,
                    reset: { projectID = nil; executionStatus = nil; executionScope = .all }
                )
            } else {
                goalsSplitView(items: execution, selectedID: $selectedExecutionID, width: width, row: executionRow, detail: executionDetail)
            }
        }
    }

    private func executionRow(_ item: WorkspaceExecutionGoalProjection) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.text).font(RekonTypography.cardTitle).lineLimit(2)
            Text("\(item.project.name) · \(item.status)").font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
            Text(item.link.ticketID.map { "Exact work link: \($0.rawValue)" } ?? "No exact work link")
                .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private func executionDetail(_ item: WorkspaceExecutionGoalProjection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Codex execution goal · \(item.project.name)")
                .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText).textCase(.uppercase)
            Text(item.text).font(RekonTypography.screenTitle)
            Text("Persisted exact local \(item.link.ticketID == nil ? "observation" : "link") · Source: persisted snapshot")
                .font(RekonTypography.metadata)
            Text("Source identity: thread \(item.threadID) · goal \(item.goalID)")
                .font(.system(.subheadline, design: .monospaced))
            if let ticketID = item.link.ticketID {
                Text("Associated work: \(ticketID.rawValue) · \(item.link.phaseName ?? "stored phase unavailable") · \(item.link.phaseID?.rawValue ?? "phase identity unavailable")")
            } else {
                Text("No exact linked work. This persisted observation is retained without creating attention or a Delivery Goal.")
            }
            Text(item.observedAt.map {
                "Last observed \($0.formatted(date: .abbreviated, time: .shortened)). Persisted observations are not live visibility."
            } ?? "Observation time unavailable.")
                .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
            if item.link.ticketID != nil {
                Button("View associated work") { openExecutionGoal(item) }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("goals-open-execution-work")
            }
        }
    }

    private func goalsSplitView<Item: Identifiable, Row: View, Detail: View>(
        items: [Item], selectedID: Binding<Data?>, width: CGFloat,
        @ViewBuilder row: @escaping (Item) -> Row,
        @ViewBuilder detail: @escaping (Item) -> Detail
    ) -> some View where Item.ID == Data {
        Group {
            if WorkspaceGoalsLayout.usesStackedDetail(forWidth: width) {
                VStack(alignment: .leading, spacing: 18) {
                    goalList(items, selectedID: selectedID, row: row)
                    RekonSeparator()
                    selectedDetail(items, selectedID: selectedID, detail: detail)
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    goalList(items, selectedID: selectedID, row: row).frame(minWidth: 280, idealWidth: 380, maxWidth: 460)
                    RekonSeparator(.vertical)
                    selectedDetail(items, selectedID: selectedID, detail: detail)
                        .offset(y: CGFloat(max(0, viewportOffset ?? 0)))
                }
            }
        }
    }

    private func goalList<Item: Identifiable, Row: View>(
        _ items: [Item], selectedID: Binding<Data?>,
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View where Item.ID == Data {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                let selected = selectedID.wrappedValue == item.id
                Button {
                    selectedID.wrappedValue = item.id
                    focusedGoalID = item.id
                    accessibilityFocusedGoalID = item.id
                    focusChanged(.workspaceGoal(item.id))
                } label: {
                    row(item)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? AnyShapeStyle(RekonTheme.elevatedSurface) : AnyShapeStyle(RekonTheme.surfaceGradient))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selected ? RekonTheme.accent : RekonTheme.border, lineWidth: selected ? 2 : RekonBorder.hairline)
                        }
                }
                .buttonStyle(.plain)
                .focusable()
                .focused($focusedGoalID, equals: item.id)
                .accessibilityFocused($accessibilityFocusedGoalID, equals: item.id)
                .id(item.id)
                .accessibilityIdentifier("workspace-goal-\(item.id.base64EncodedString())")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(items.count) goals")
    }

    @ViewBuilder private func selectedDetail<Item: Identifiable, Detail: View>(
        _ items: [Item], selectedID: Binding<Data?>,
        @ViewBuilder detail: @escaping (Item) -> Detail
    ) -> some View where Item.ID == Data {
        if let selected = items.first(where: { $0.id == selectedID.wrappedValue }) {
            detail(selected)
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("workspace-goal-detail")
        }
    }

    private func goalsEmptyState(title: String, detail: String, canReset: Bool, reset: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "target")
        } description: {
            Text(detail)
        } actions: {
            if canReset {
                Button("Show All Projects · All states", action: reset)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("goals-clear-filters")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .accessibilityIdentifier("goals-empty")
    }

    private func matchesSelectedProject(_ candidate: ProjectID) -> Bool {
        guard let projectID else { return true }
        return candidate.rawValue.utf8.elementsEqual(projectID.rawValue.utf8)
    }

    private func applyRequestedFocus() {
        switch requestedFocus {
        case let .workspaceGoal(id):
            focusedGoalID = id
            accessibilityFocusedGoalID = id
        case .workspaceGoalsFilter:
            filterFocused = true
            accessibilityFilterFocused = true
        default:
            break
        }
    }

}

private struct WorkspaceGoalsScrollOffsetBridge: NSViewRepresentable {
    @Binding var offset: Double?
    let restoreToken: NavigationFocus?

    func makeCoordinator() -> Coordinator { Coordinator(offset: $offset, restoreToken: restoreToken) }

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onHierarchyOrLayoutChange = { [weak coordinator = context.coordinator] view in
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
        coordinator.detach()
        nsView.onHierarchyOrLayoutChange = nil
    }

    final class ProbeView: NSView {
        var onHierarchyOrLayoutChange: ((ProbeView) -> Void)?
        override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); onHierarchyOrLayoutChange?(self) }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); onHierarchyOrLayoutChange?(self) }
        override func layout() { super.layout(); onHierarchyOrLayoutChange?(self) }
    }

    @MainActor final class Coordinator: NSObject {
        private var offset: Binding<Double?>
        private var restoreToken: NavigationFocus?
        private weak var scrollView: NSScrollView?
        private weak var clipView: NSClipView?
        private var pendingRestoreOffset: Double?
        private var isRestoring = false

        init(offset: Binding<Double?>, restoreToken: NavigationFocus?) {
            self.offset = offset
            self.restoreToken = restoreToken
            pendingRestoreOffset = offset.wrappedValue
        }

        func update(offset: Binding<Double?>, restoreToken: NavigationFocus?) {
            self.offset = offset
            guard self.restoreToken != restoreToken else { return }
            self.restoreToken = restoreToken
            pendingRestoreOffset = offset.wrappedValue
        }

        func attach(to scrollView: NSScrollView?) {
            guard let scrollView, self.scrollView !== scrollView else { return }
            detach()
            self.scrollView = scrollView
            clipView = scrollView.contentView
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            pendingRestoreOffset = offset.wrappedValue
        }

        func detach() {
            if let clipView {
                NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: clipView)
            }
            scrollView = nil
            clipView = nil
        }

        func restoreIfPossible() {
            guard let requestedOffset = pendingRestoreOffset,
                  let scrollView,
                  let clipView,
                  let documentView = scrollView.documentView else { return }
            let maximumOffset = max(0, documentView.bounds.height - clipView.bounds.height)
            guard requestedOffset == 0 || maximumOffset > 0 else { return }
            let boundedOffset = min(max(0, CGFloat(requestedOffset)), maximumOffset)
            pendingRestoreOffset = nil
            isRestoring = true
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: boundedOffset))
            scrollView.reflectScrolledClipView(clipView)
            isRestoring = false
        }

        @objc private func boundsDidChange(_ notification: Notification) {
            if pendingRestoreOffset != nil { restoreIfPossible(); return }
            guard !isRestoring, let clipView else { return }
            let value = Double(max(0, clipView.bounds.origin.y))
            guard offset.wrappedValue.map({ abs($0 - value) > 0.5 }) ?? true else { return }
            offset.wrappedValue = value
        }
    }
}

private struct WorkspaceGoalsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Goals help").font(RekonTypography.screenTitle)
                RekonCallout(tone: .information, systemImage: "target") {
                    Text("Delivery and Execution are separate").font(.headline)
                    Text("Delivery Goals are phase-owned formal outcomes. Readiness, carried coverage, and owner acceptance retain their existing policy and authority. Codex execution goals are persisted observations and never promote or change Delivery state.")
                }
                RekonCallout(tone: .warning, systemImage: "clock.badge.exclamationmark") {
                    Text("Persisted does not mean live").font(.headline)
                    Text("Execution rows show observed time, exact thread and goal identity, source provenance, and whether an exact work link exists. A stale or unavailable observer does not erase retained observations or create attention.")
                }
                RekonCallout(tone: .accent, systemImage: "arrow.turn.down.right") {
                    Text("Filters and navigation").font(.headline)
                    Text("Use domain, project, state, and link filters to narrow discovery. Associated work from either domain opens the existing all-phase board with its exact typed goal filter; select All goals there to clear it. Back and Forward restore Goals filters, selection, scroll and focus.")
                }
                RekonCallout(tone: .information, systemImage: "arrow.uturn.backward.circle") {
                    Text("Recovery is explicit").font(.headline)
                    Text("If an exact goal or project registration disappears or is replaced, Release Radar explains the recovery and never substitutes a different record.")
                }
                Button("Done") { dismiss() }.buttonStyle(RekonPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(28)
        }
        .frame(minWidth: 520, idealWidth: 650, minHeight: 480)
        .background(RekonTheme.background)
        .accessibilityIdentifier("goals-help-sheet")
    }
}

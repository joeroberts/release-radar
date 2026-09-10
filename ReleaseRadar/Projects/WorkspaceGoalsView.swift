import RekonDesignSystem
import ReleaseRadarCore
import SwiftUI

enum WorkspaceGoalsDomain: String, CaseIterable, Identifiable {
    case delivery
    case execution

    var id: Self { self }
    var title: String { self == .delivery ? "Delivery" : "Execution" }
}

private enum WorkspaceExecutionScope: String, CaseIterable, Identifiable {
    case all, linked, unlinked
    var id: Self { self }
    var title: String { switch self { case .all: "All goals"; case .linked: "Linked work"; case .unlinked: "Unlinked observations" } }
}

struct WorkspaceGoalsView: View {
    let goals: WorkspaceGoalsProjection
    let openDeliveryGoal: (WorkspaceDeliveryGoalProjection) -> Void
    @Binding var domain: WorkspaceGoalsDomain
    @Binding var projectID: ProjectID?
    @Binding var selectedDeliveryID: Data?
    @Binding var selectedExecutionID: Data?
    @State private var showsHelp = false
    @State private var deliveryLifecycle: DeliveryGoalLifecycle?
    @State private var executionScope: WorkspaceExecutionScope = .all

    private var projects: [ProjectDashboardProjection] {
        let delivery = goals.delivery.map(\.project)
        let execution = goals.execution.map(\.project)
        return Dictionary(uniqueKeysWithValues: (delivery + execution).map { ($0.id, $0) })
            .values.sorted { $0.name < $1.name }
    }

    private var delivery: [WorkspaceDeliveryGoalProjection] {
        goals.delivery.filter { (projectID == nil || $0.project.id == projectID) && (deliveryLifecycle == nil || $0.goal.lifecycle == deliveryLifecycle) }
    }

    private var execution: [WorkspaceExecutionGoalProjection] {
        goals.execution.filter {
            (projectID == nil || $0.project.id == projectID)
                && (executionScope == .all || (executionScope == .linked) == ($0.link.ticketID != nil))
        }
    }

    private var selectedDelivery: WorkspaceDeliveryGoalProjection? {
        delivery.first { $0.id == selectedDeliveryID } ?? delivery.first
    }

    private var selectedExecution: WorkspaceExecutionGoalProjection? {
        execution.first { $0.id == selectedExecutionID } ?? execution.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RekonScreenHeader(title: "Goals", subtitle: "Delivery outcomes and persisted Codex execution observations across active projects", trailing: AnyView(
                Button("Help", systemImage: "questionmark.circle") { showsHelp = true }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("goals-help")
            ))
            controls
            if domain == .delivery { deliveryContent } else { executionContent }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RekonTheme.background)
        .accessibilityIdentifier("workspace-goals")
        .sheet(isPresented: $showsHelp) { WorkspaceGoalsHelpView() }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { domainPicker; projectPicker; statePicker; Spacer() }
            VStack(alignment: .leading, spacing: 10) { domainPicker; projectPicker; statePicker }
        }
    }

    private var domainPicker: some View {
        Picker("Goal domain", selection: $domain) {
            ForEach(WorkspaceGoalsDomain.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .accessibilityIdentifier("goals-domain")
    }

    private var projectPicker: some View {
        Picker("Projects", selection: $projectID) {
            Text("All Projects").tag(ProjectID?.none)
            ForEach(projects) { project in Text(project.name).tag(ProjectID?.some(project.id)) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("goals-project-filter")
    }

    @ViewBuilder private var statePicker: some View {
        if domain == .delivery {
            Picker("Delivery state", selection: $deliveryLifecycle) {
                Text("All states").tag(DeliveryGoalLifecycle?.none)
                ForEach(DeliveryGoalLifecycle.allCases, id: \.self) { lifecycle in
                    Text(lifecycle.displayName).tag(DeliveryGoalLifecycle?.some(lifecycle))
                }
            }.pickerStyle(.menu).accessibilityIdentifier("goals-delivery-state-filter")
        } else {
            Picker("Execution scope", selection: $executionScope) {
                ForEach(WorkspaceExecutionScope.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.menu).accessibilityIdentifier("goals-execution-state-filter")
        }
    }

    private var deliveryContent: some View {
        goalsSplitView(
            items: delivery,
            selectedID: $selectedDeliveryID,
            itemID: \.id,
            row: { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.goal.title).font(RekonTypography.cardTitle)
                    Text("\(item.project.name) · \(item.phaseName)").font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
                    Text("\(item.goal.lifecycle.displayName) · \(item.goal.ticketIDs.count) associated work item\(item.goal.ticketIDs.count == 1 ? "" : "s")")
                        .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
                }
            },
            detail: { item in
                VStack(alignment: .leading, spacing: 14) {
                    Text("Delivery Goal").font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText).textCase(.uppercase)
                    Text(item.goal.title).font(RekonTypography.screenTitle)
                    Text(item.goal.outcome).foregroundStyle(RekonTheme.secondaryText)
                    Text("Phase plan: \(item.phasePlan.state.rawValue) · \(item.phasePlan.coveredUpcomingCount)/\(item.phasePlan.upcomingCount) upcoming work covered")
                    Text("Owner acceptance: \(item.goal.lifecycle.displayName). Browsing does not accept outcomes or change formal delivery state.")
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
            },
            emptyTitle: "No Delivery Goals recorded",
            emptyDetail: "No recorded phase-owned Delivery Goals match this project scope. This does not infer a goal for unassigned or legacy work."
        )
    }

    private var executionContent: some View {
        goalsSplitView(
            items: execution,
            selectedID: $selectedExecutionID,
            itemID: \.id,
            row: { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.text).font(RekonTypography.cardTitle).lineLimit(2)
                    Text("\(item.project.name) · \(item.status)").font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
                    Text(item.link.ticketID.map { "Exact work link: \($0.rawValue)" } ?? "No exact work link")
                        .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
                }
            },
            detail: { item in
                VStack(alignment: .leading, spacing: 14) {
                    Text("Codex execution goal").font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText).textCase(.uppercase)
                    Text(item.text).font(RekonTypography.screenTitle)
                    Text("Project: \(item.project.name)")
                    Text("Source identity: thread \(item.threadID) · goal \(item.goalID)")
                        .font(.system(.subheadline, design: .monospaced))
                    Text(item.link.ticketID.map { "Exact linked work: \($0.rawValue)" } ?? "No exact linked work. This persisted observation is retained without creating attention or a Delivery Goal.")
                    Text(item.observedAt.map { "Last observed \($0.formatted(date: .abbreviated, time: .shortened)). Persisted observations are not live visibility." } ?? "Observation time unavailable.")
                        .font(RekonTypography.metadata).foregroundStyle(RekonTheme.secondaryText)
                }
            },
            emptyTitle: "No persisted execution observations",
            emptyDetail: "No persisted Codex execution goals match this project scope. This is distinct from unavailable observation data."
        )
    }

    private func goalsSplitView<Item: Identifiable, Row: View, Detail: View>(
        items: [Item], selectedID: Binding<Item.ID?>, itemID: KeyPath<Item, Item.ID>,
        @ViewBuilder row: @escaping (Item) -> Row, @ViewBuilder detail: @escaping (Item) -> Detail,
        emptyTitle: String, emptyDetail: String
    ) -> some View {
        Group {
            if items.isEmpty {
                ProjectEmptyStateView(presentation: .init(title: emptyTitle, detail: emptyDetail, systemImage: "target", accessibilityID: "goals-empty"))
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) { goalList(items, selectedID: selectedID, row: row); RekonSeparator(.vertical); selectedDetail(items, selectedID: selectedID, detail: detail) }
                    VStack(alignment: .leading, spacing: 18) { goalList(items, selectedID: selectedID, row: row); RekonSeparator(); selectedDetail(items, selectedID: selectedID, detail: detail) }
                }
            }
        }
    }

    private func goalList<Item: Identifiable, Row: View>(_ items: [Item], selectedID: Binding<Item.ID?>, @ViewBuilder row: @escaping (Item) -> Row) -> some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 8) { ForEach(items) { item in Button { selectedID.wrappedValue = item.id } label: { row(item).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 10)).overlay { if selectedID.wrappedValue == item.id { RoundedRectangle(cornerRadius: 10).fill(RekonTheme.elevatedSurface.opacity(0.85)) } } }.buttonStyle(.plain) } } }
            .frame(minWidth: 280, idealWidth: 380, maxWidth: 460, minHeight: 360)
    }

    private func selectedDetail<Item: Identifiable, Detail: View>(_ items: [Item], selectedID: Binding<Item.ID?>, @ViewBuilder detail: @escaping (Item) -> Detail) -> some View {
        let selected = items.first { $0.id == selectedID.wrappedValue } ?? items.first!
        return detail(selected).padding(18).frame(maxWidth: .infinity, alignment: .topLeading)
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
                    Text("Delivery Goals are phase-owned formal outcomes. Readiness, coverage, and owner acceptance keep their existing policy and authority. Codex execution goals are persisted observations and never promote or change Delivery state.")
                }
                RekonCallout(tone: .warning, systemImage: "clock.badge.exclamationmark") {
                    Text("Persisted does not mean live").font(.headline)
                    Text("Execution rows show their observed time, exact thread and goal identity, and whether an exact work link exists. A stale or unavailable observer does not erase retained observations or create new attention.")
                }
                RekonCallout(tone: .accent, systemImage: "arrow.turn.down.right") {
                    Text("Filters and navigation").font(.headline)
                    Text("Use the domain and project filters to narrow discovery. View associated work opens the existing all-phase board with an explicit Delivery Goal filter; select All goals there to clear it. Back returns to this Goals scope without changing an active phase or formal state.")
                }
                Button("Done") { dismiss() }.buttonStyle(RekonPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }.padding(28)
        }
        .frame(minWidth: 520, idealWidth: 650, minHeight: 480)
        .background(RekonTheme.background)
        .accessibilityIdentifier("goals-help-sheet")
    }
}

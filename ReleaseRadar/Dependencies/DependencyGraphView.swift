import AppKit
import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

struct DependencyGraphView: View {
    let graph: DependencyGraphProjection
    @Binding var selectedTicketID: TicketID
    let freshness: CodexObservationFreshness
    var projectName = "Project"
    var retainedOrder: DependencyGraphRankOrder? = nil
    var arrangementStatus: DependencyGraphArrangementStatus = .automatic
    var onUpdateOrder: ((DependencyGraphRankOrder) -> Void)? = nil
    var onResetOrder: (() -> Void)? = nil
    var onRetryArrangement: (() -> Void)? = nil

    @State private var finderState = DependencyGraphFinderState()
    @State private var isArranging = false
    @State private var sessionOrders: [TicketID: DependencyGraphRankOrder] = [:]
    @State private var arrangementMessage: String?
    @FocusState private var finderFocused: Bool
    @FocusState private var focusedFinderResultID: TicketID?
    @FocusState private var focusedNodeID: TicketID?
    @AccessibilityFocusState private var accessibilityFocusedFinderResultID: TicketID?
    @AccessibilityFocusState private var accessibilityFocusedNodeID: TicketID?

    private var focusedGraph: DependencyGraphProjection {
        selectedTicketID.rawValue.isEmpty ? graph.clearingSelection() : graph.selecting(selectedTicketID)
    }

    private var selected: DependencyInspectorProjection? { focusedGraph.selected }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                header
                RekonSeparator()

                if let selected {
                    if geometry.size.width >= 980 {
                        HStack(spacing: 0) {
                            graphWorkspace(selected: selected)
                                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                            RekonSeparator(.vertical)
                            inspector(selection: selected, compact: false)
                                .frame(width: 308)
                                .frame(maxHeight: .infinity)
                        }
                    } else {
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                graphWorkspace(selected: selected)
                                    .frame(height: max(360, geometry.size.height * 0.64))
                                RekonSeparator()
                                inspector(selection: selected, compact: true)
                                    .frame(minHeight: 230)
                            }
                        }
                    }
                } else {
                    focusState
                }
            }
        }
        .accessibilityIdentifier("content-dependencies")
        .background(RekonTheme.background)
        .onAppear { focusFinderForEmptyOrMissingSelection() }
        .onChange(of: focusedGraph.focus) { _, _ in focusFinderForEmptyOrMissingSelection() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(projectName) · All project tickets")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RekonTheme.secondaryText)
                Text("Dependency map")
                    .font(RekonTypography.screenTitle)
                    .foregroundStyle(RekonTheme.primaryText)
                if let selected {
                    Text("\(selected.ticket.id.rawValue) · \(selected.ticket.outcome)")
                        .foregroundStyle(RekonTheme.secondaryText)
                }
            }

            HStack(spacing: 12) {
                finder
                Button(isArranging ? "Done arranging" : "Arrange") {
                    isArranging.toggle()
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(selected == nil || arrangementStatus.blocksAdjustment)
                .accessibilityIdentifier("dependency-arrange")
                Button("Reset") { resetSessionOrder() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(
                        selected == nil || currentOrder == nil
                            || arrangementStatus.blocksAdjustment || arrangementStatus.isBusy
                    )
                    .accessibilityIdentifier("dependency-reset-layout")
            }
            .accessibilityElement(children: .contain)

            if let message = arrangementStatus.message ?? arrangementMessage {
                HStack(spacing: 8) {
                    Label(
                        message,
                        systemImage: arrangementStatus.systemImage
                    )
                    .accessibilityIdentifier("dependency-layout-status")
                    Spacer(minLength: 0)
                    if arrangementStatus.canRetry, let onRetryArrangement {
                        Button("Retry", action: onRetryArrangement)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dependency-layout-retry")
                    }
                }
                .font(.caption)
                .foregroundStyle(arrangementStatus.isWarning ? RekonTheme.warning : RekonTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            finderResults
            Button("Find ticket") { finderFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .padding(24)
    }

    private var finder: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(RekonTheme.secondaryText)
            DependencyFinderTextField(
                text: Binding(
                    get: { finderState.query },
                    set: { finderState.updateQuery($0, in: graph) }
                ),
                isFocused: Binding(
                    get: { finderFocused },
                    set: { finderFocused = $0 }
                ),
                move: { direction in
                    let query = finderState.query.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !query.isEmpty, !graph.matchingTickets(query).isEmpty else { return false }
                    finderState.move(direction, in: graph)
                    return true
                },
                focusHighlightedResult: focusHighlightedFinderResult,
                clear: { finderState = .init() },
                submit: selectFirstFinderResult
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(finderFocused ? RekonTheme.accent : RekonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dependency-finder")
    }

    @ViewBuilder private var finderResults: some View {
        let results = graph.matchingTickets(finderState.query)
        if !finderState.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    if results.isEmpty {
                        Text("No project ticket matches that ID, outcome, phase, or lane.")
                            .foregroundStyle(RekonTheme.secondaryText)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { node in
                                Button { select(node.id) } label: {
                                    HStack {
                                        Text(node.id.rawValue).font(.system(.body, design: .monospaced, weight: .semibold))
                                        Text(node.outcome).lineLimit(1)
                                        Spacer()
                                        Text(node.phaseName).foregroundStyle(RekonTheme.secondaryText)
                                        Text(node.lane?.dashboardTitle ?? "Not placed").foregroundStyle(RekonTheme.secondaryText)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .focusable()
                                .focused($focusedFinderResultID, equals: node.id)
                                .accessibilityFocused($accessibilityFocusedFinderResultID, equals: node.id)
                                .background(
                                    node.id == finderState.highlightedTicketID
                                        ? RekonTheme.accent.opacity(0.14)
                                        : Color.clear
                                )
                                .accessibilityAddTraits(node.id == finderState.highlightedTicketID ? .isSelected : [])
                                .accessibilityLabel("\(node.id.rawValue), \(node.outcome), \(node.phaseName), \(node.lane?.dashboardTitle ?? "not placed")")
                                .accessibilityIdentifier("dependency-finder-result-\(node.id.rawValue)")
                                .id(node.id)
                                .onMoveCommand { direction in
                                    switch direction {
                                    case .up: finderState.move(.previous, in: graph)
                                    case .down: finderState.move(.next, in: graph)
                                    default: return
                                    }
                                    focusedFinderResultID = finderState.highlightedTicketID
                                    accessibilityFocusedFinderResultID = finderState.highlightedTicketID
                                }
                            }
                        }
                    }
                }
                .onChange(of: finderState.highlightedTicketID) { _, ticketID in
                    guard let ticketID else { return }
                    scrollProxy.scrollTo(ticketID, anchor: .center)
                }
                .frame(maxHeight: 220)
                .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(RekonTheme.border) }
                .accessibilityIdentifier("dependency-finder-results")
            }
        }
    }

    @ViewBuilder private var focusState: some View {
        switch focusedGraph.focus {
        case .none:
            ContentUnavailableView(
                "Find a ticket to explore dependencies",
                systemImage: "arrow.triangle.branch",
                description: Text(graph.nodes.isEmpty
                    ? "This project has no tickets to display."
                    : "Search this project's ticket IDs, outcomes, phases, or lanes. No active-phase ticket is selected automatically.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(graph.nodes.isEmpty ? "dependency-empty-project" : "dependency-no-selection")
        case let .missing(ticketID):
            ContentUnavailableView(
                "Ticket unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The exact ticket \(ticketID.rawValue) is no longer available in this project. Find another ticket or reload the project data.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("dependency-missing-ticket")
        case .selected:
            EmptyView()
        }
    }

    private func graphWorkspace(selected: DependencyInspectorProjection) -> some View {
        GeometryReader { proxy in
            let canvasSize = CGSize(
                width: DependencyGraphLayout.requiredCanvasWidth(for: focusedGraph, minimum: max(proxy.size.width, 820)),
                height: DependencyGraphLayout.requiredCanvasHeight(for: focusedGraph, minimum: max(proxy.size.height - 122, 330))
            )
            let layout = DependencyGraphLayout.makeLayout(
                graph: focusedGraph,
                size: canvasSize,
                retainedOrder: currentOrder
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("\(layout.frames.count) of \(focusedGraph.nodes.count) project tickets shown")
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                    Spacer()
                    if isArranging {
                        Text("Drag within a rank · Option–↑/↓ moves · Shift moves farther · Escape exits")
                            .font(.caption)
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                laneLegend.padding(.horizontal, 16).padding(.bottom, 10)
                RekonSeparator()

                ScrollViewReader { scrollProxy in
                    ScrollView([.horizontal, .vertical]) {
                        VStack(spacing: 0) {
                            columnHeaders(layout.columns, canvasWidth: canvasSize.width)
                            RekonSeparator()
                            dependencyCanvas(layout: layout, canvasSize: canvasSize)
                        }
                        .frame(width: canvasSize.width)
                    }
                    .scrollIndicators(.automatic)
                    .onAppear { scrollProxy.scrollTo(selected.ticket.id, anchor: .center) }
                    .onChange(of: selected.ticket.id) { _, id in
                        withAnimation { scrollProxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
            .background(RekonTheme.backgroundRaised)
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(RekonTheme.border.opacity(0.82), lineWidth: RekonBorder.hairline) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Dependency graph; \(layout.frames.count) of \(focusedGraph.nodes.count) project tickets shown")
        }
        .accessibilityIdentifier("dependency-graph")
    }

    private var laneLegend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], alignment: .leading, spacing: 7) {
            ForEach(TicketLane.allCases, id: \.self) { lane in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(lane.graphColor).frame(width: 12, height: 12)
                    Text(lane.dashboardTitle).font(.caption)
                }
                .accessibilityElement(children: .combine)
            }
            Label("Dependency", systemImage: "arrow.right").font(.caption)
            Label("Blocking path", systemImage: "arrow.right").font(.caption).foregroundStyle(.red)
        }
    }

    private func columnHeaders(_ columns: [DependencyGraphColumn], canvasWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(column.containsSelection ? RekonTheme.accent : RekonTheme.secondaryText)
                    .frame(width: column.frame.width, height: 43)
                    .position(x: column.frame.midX, y: 21.5)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(width: canvasWidth, height: 43)
    }

    private func dependencyCanvas(layout: DependencyGraphLayoutResult, canvasSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for column in layout.columns.dropLast() {
                    var separator = Path()
                    separator.move(to: CGPoint(x: column.frame.maxX, y: 0))
                    separator.addLine(to: CGPoint(x: column.frame.maxX, y: canvasSize.height))
                    context.stroke(separator, with: .color(.secondary.opacity(0.28)), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
                }
                for connector in layout.connectors {
                    let color = connector.isBlocking ? Color.red : Color.secondary
                    var path = Path()
                    guard let first = connector.points.first else { continue }
                    path.move(to: first)
                    for point in connector.points.dropFirst() { path.addLine(to: point) }
                    context.stroke(path, with: .color(color.opacity(connector.isBlocking ? 0.9 : 0.72)), style: StrokeStyle(lineWidth: connector.isBlocking ? 2.4 : 1.5, lineJoin: .round))
                    var arrow = Path()
                    arrow.move(to: connector.end)
                    arrow.addLine(to: CGPoint(x: connector.end.x - 8, y: connector.end.y - 5))
                    arrow.addLine(to: CGPoint(x: connector.end.x - 8, y: connector.end.y + 5))
                    arrow.closeSubpath()
                    context.fill(arrow, with: .color(color))
                }
            }
            .accessibilityHidden(true)

            ForEach(focusedGraph.nodes) { node in
                if let frame = layout.frames[node.id], let rankTitle = layout.columnTitle(for: node.id) {
                    graphNode(node, rankTitle: rankTitle, layout: layout)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .id(node.id)
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func graphNode(_ node: DependencyGraphNode, rankTitle: String, layout: DependencyGraphLayoutResult) -> some View {
        let isSelected = node.id == selectedTicketID
        return Button { select(node.id) } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Text(node.id.rawValue).font(.system(.subheadline, design: .monospaced, weight: .semibold)).lineLimit(1)
                    Text(node.phaseName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    if node.lane == .blocked {
                        Label("Blocked", systemImage: "exclamationmark.octagon.fill").font(.caption2.weight(.medium)).foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background((node.lane?.graphColor ?? RekonTheme.secondaryText).opacity(isSelected ? 0.28 : 0.15))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(isSelected ? RekonTheme.accent : (node.lane?.graphColor ?? RekonTheme.secondaryText), lineWidth: isSelected ? 2.5 : 1) }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                if node.blockerCount > 0 {
                    Text("\(node.blockerCount)").font(.caption2.weight(.medium)).foregroundStyle(.white)
                        .frame(width: 21, height: 21).background(.red, in: Circle()).offset(x: 7, y: -7).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedNodeID, equals: node.id)
        .accessibilityFocused($accessibilityFocusedNodeID, equals: node.id)
        .accessibilityLabel("\(node.id.rawValue), \(node.outcome), \(node.phaseName), \(node.lane?.dashboardTitle ?? "No delivery lane"), \(node.blockerCount) blocker\(node.blockerCount == 1 ? "" : "s"), \(rankTitle)\(isSelected ? ", selected" : "")")
        .accessibilityHint(isArranging ? "Select this ticket. Option Up or Down reorders it within its rank." : "Select to focus this ticket's relationships")
        .draggable(isArranging ? node.id.rawValue : "")
        .dropDestination(for: String.self) { values, _ in
            guard isArranging, let source = values.first.map(TicketID.init(rawValue:)),
                  layout.rank(for: source) == layout.rank(for: node.id),
                  let destination = layout.rankOrder.ranks.first(where: { $0.ticketIDs.contains(node.id) })?.ticketIDs.firstIndex(of: node.id)
            else { return false }
            updateOrder(layout.rankOrder.moving(ticketID: source, to: destination))
            return true
        }
        .onKeyPress(keys: [.upArrow, .downArrow, .escape], phases: .down) { press in
            if press.key == .escape, isArranging {
                isArranging = false
                return .handled
            }
            guard isArranging, press.modifiers.contains(.option),
                  let rank = layout.rankOrder.ranks.first(where: { $0.ticketIDs.contains(node.id) }),
                  let index = rank.ticketIDs.firstIndex(of: node.id)
            else { return .ignored }
            let distance = press.modifiers.contains(.shift) ? 5 : 1
            let destination = press.key == .upArrow ? index - distance : index + distance
            updateOrder(layout.rankOrder.moving(ticketID: node.id, to: destination))
            return .handled
        }
    }

    private func inspector(selection: DependencyInspectorProjection, compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(compact ? "\(selection.ticket.id.rawValue) · \(selection.ticket.outcome)" : "Selected ticket")
                    .font(compact ? .title3.weight(.semibold) : .caption.weight(.medium))
                    .foregroundStyle(compact ? RekonTheme.primaryText : RekonTheme.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                if !compact {
                    Text(selection.ticket.id.rawValue).font(.system(.title2, design: .monospaced, weight: .semibold))
                    Text(selection.ticket.outcome)
                }
                LabeledContent("Phase", value: selection.ticket.phaseName)
                LabeledContent("Delivery lane", value: selection.ticket.lane?.dashboardTitle ?? "Not placed")
                if let failure = FailureStatePresentation(freshness: freshness) {
                    FailureStateView(presentation: failure, style: .compact)
                }
                RekonSeparator()
                relationshipSection("Directly requires", nodes: selection.directRequires)
                relationshipSection("Indirectly requires", nodes: selection.indirectRequires)
                relationshipSection("Unlocks", nodes: selection.unlocks)
            }
            .padding(20)
        }
        .background(RekonTheme.backgroundRaised)
        .accessibilityIdentifier("dependency-inspector")
    }

    private func relationshipSection(_ title: String, nodes: [DependencyGraphNode]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(title) · \(nodes.count)").font(.caption.weight(.medium)).foregroundStyle(.secondary).textCase(.uppercase).accessibilityAddTraits(.isHeader)
            if nodes.isEmpty {
                Text("None").foregroundStyle(.tertiary)
            } else {
                ForEach(nodes) { node in
                    Button { select(node.id) } label: {
                        HStack(spacing: 8) {
                            Circle().fill(node.lane?.graphColor ?? RekonTheme.secondaryText).frame(width: 8, height: 8)
                            Text(node.id.rawValue).font(.system(.subheadline, design: .monospaced))
                            Text(node.phaseName).font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(node.id.rawValue), \(node.outcome), \(node.phaseName), \(node.lane?.dashboardTitle ?? "not placed")")
                    .accessibilityHint("Select to focus this ticket's relationships")
                }
            }
        }
    }

    private var currentOrder: DependencyGraphRankOrder? {
        if onUpdateOrder != nil { return retainedOrder }
        return selected.flatMap { sessionOrders[$0.ticket.id] }
    }

    private func select(_ ticketID: TicketID) {
        selectedTicketID = ticketID
        finderState = .init()
        finderFocused = false
        focusedFinderResultID = nil
        accessibilityFocusedFinderResultID = nil
        focusedNodeID = ticketID
        accessibilityFocusedNodeID = ticketID
    }

    private func selectFirstFinderResult() {
        if let selected = finderState.selectedTicket(in: graph) ?? graph.matchingTickets(finderState.query).first {
            select(selected.id)
        }
    }

    private func focusHighlightedFinderResult() -> Bool {
        guard let highlightedTicketID = finderState.highlightedTicketID else { return false }
        finderFocused = false
        focusedFinderResultID = highlightedTicketID
        accessibilityFocusedFinderResultID = highlightedTicketID
        return true
    }

    private func focusFinderForEmptyOrMissingSelection() {
        switch focusedGraph.focus {
        case .none, .missing: finderFocused = true
        case .selected: break
        }
    }

    private func updateOrder(_ order: DependencyGraphRankOrder) {
        guard let selectedID = selected?.ticket.id,
              !arrangementStatus.blocksAdjustment else { return }
        if let onUpdateOrder {
            onUpdateOrder(order)
            return
        }
        sessionOrders[selectedID] = order
        arrangementMessage = "Unsaved arrangement"
    }

    private func resetSessionOrder() {
        guard let selectedID = selected?.ticket.id,
              !arrangementStatus.blocksAdjustment else { return }
        if let onResetOrder {
            onResetOrder()
            return
        }
        sessionOrders.removeValue(forKey: selectedID)
        arrangementMessage = nil
    }
}

private struct DependencyFinderTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let move: (DependencyGraphFinderDirection) -> Bool
    let focusHighlightedResult: () -> Bool
    let clear: () -> Void
    let submit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: $isFocused,
            move: move,
            focusHighlightedResult: focusHighlightedResult,
            clear: clear,
            submit: submit
        )
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit)
        field.stringValue = text
        field.placeholderString = "Find ticket by ID, outcome, phase, or lane"
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        field.cell?.sendsActionOnEndEditing = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setAccessibilityIdentifier("dependency-finder-input")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.update(
            text: $text,
            isFocused: $isFocused,
            move: move,
            focusHighlightedResult: focusHighlightedResult,
            clear: clear,
            submit: submit
        )
        context.coordinator.reconcileText(in: field)
        context.coordinator.focusIfRequested(field)
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        private var text: Binding<String>
        private var isFocused: Binding<Bool>
        private var move: (DependencyGraphFinderDirection) -> Bool
        private var focusHighlightedResult: () -> Bool
        private var clear: () -> Void
        private var submitAction: () -> Void
        private var lastNativeText: String
        private var pendingExternalText: String?
        private var isApplyingExternalText = false

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            move: @escaping (DependencyGraphFinderDirection) -> Bool,
            focusHighlightedResult: @escaping () -> Bool,
            clear: @escaping () -> Void,
            submit: @escaping () -> Void
        ) {
            self.text = text
            self.isFocused = isFocused
            self.move = move
            self.focusHighlightedResult = focusHighlightedResult
            self.clear = clear
            submitAction = submit
            lastNativeText = text.wrappedValue
        }

        func update(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            move: @escaping (DependencyGraphFinderDirection) -> Bool,
            focusHighlightedResult: @escaping () -> Bool,
            clear: @escaping () -> Void,
            submit: @escaping () -> Void
        ) {
            self.text = text
            self.isFocused = isFocused
            self.move = move
            self.focusHighlightedResult = focusHighlightedResult
            self.clear = clear
            submitAction = submit
        }

        func reconcileText(in field: NSTextField) {
            let requestedText = text.wrappedValue
            guard requestedText != lastNativeText else {
                pendingExternalText = nil
                return
            }
            if let editor = field.currentEditor() as? NSTextView,
               editor.hasMarkedText(),
               !requestedText.isEmpty {
                pendingExternalText = requestedText
                return
            }
            applyExternalText(requestedText, to: field)
        }

        private func applyExternalText(_ value: String, to field: NSTextField) {
            pendingExternalText = nil
            isApplyingExternalText = true
            defer { isApplyingExternalText = false }
            lastNativeText = value
            field.stringValue = value
            guard let editor = field.currentEditor() as? NSTextView,
                  editor.string != value else { return }
            editor.string = value
            editor.setSelectedRange(NSRange(location: (value as NSString).length, length: 0))
        }

        func focusIfRequested(_ field: NSTextField) {
            guard isFocused.wrappedValue, field.currentEditor() == nil else { return }
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field,
                      self.isFocused.wrappedValue,
                      field.currentEditor() == nil else { return }
                field.window?.makeFirstResponder(field)
            }
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            if !isFocused.wrappedValue { isFocused.wrappedValue = true }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard !isApplyingExternalText,
                  let field = notification.object as? NSTextField else { return }
            lastNativeText = field.stringValue
            if let pendingExternalText,
               (field.currentEditor() as? NSTextView)?.hasMarkedText() != true {
                applyExternalText(pendingExternalText, to: field)
                return
            }
            guard pendingExternalText == nil else { return }
            if text.wrappedValue != field.stringValue { text.wrappedValue = field.stringValue }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField,
               let pendingExternalText {
                applyExternalText(pendingExternalText, to: field)
            }
            if isFocused.wrappedValue { isFocused.wrappedValue = false }
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                return move(.previous)
            case #selector(NSResponder.moveDown(_:)):
                return move(.next)
            case #selector(NSResponder.insertTab(_:)):
                return focusHighlightedResult()
            case #selector(NSResponder.cancelOperation(_:)):
                textView.string = ""
                pendingExternalText = nil
                lastNativeText = ""
                text.wrappedValue = ""
                clear()
                return true
            default:
                return false
            }
        }

        @objc func submit() {
            submitAction()
        }
    }
}

private extension TicketLane {
    var graphColor: Color {
        switch self {
        case .backlog: RekonTheme.secondaryText
        case .inProgress: RekonTheme.accent
        case .needsReview: RekonTheme.warning
        case .blocked: RekonTheme.danger
        case .accepted: RekonTheme.success
        }
    }
}

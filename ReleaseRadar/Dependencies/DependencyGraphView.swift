import ReleaseRadarCore
import SwiftUI

struct DependencyGraphView: View {
    let graph: DependencyGraphProjection
    @Binding var selectedTicketID: TicketID
    let freshness: CodexObservationFreshness

    private var selectedGraph: DependencyGraphProjection {
        graph.selecting(selectedTicketID) ?? graph
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()

                if geometry.size.width >= 980 {
                    HStack(spacing: 0) {
                        graphWorkspace
                            .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                        Divider()
                        inspector
                            .frame(width: 300)
                            .frame(maxHeight: .infinity)
                    }
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            graphWorkspace
                                .frame(height: max(480, geometry.size.height * 0.72))
                            Divider()
                            inspector
                                .frame(minHeight: 390)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("content-dependencies")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Phase dependency map")
                .font(.largeTitle.weight(.semibold))
            Text("Selected path for \(selectedGraph.selected.ticket.id.rawValue) · direct and indirect relationships across the phase")
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var graphWorkspace: some View {
        GeometryReader { proxy in
            let canvasSize = CGSize(
                width: max(proxy.size.width, 820),
                height: max(proxy.size.height - 136, 400)
            )
            let layout = DependencyGraphLayout.makeLayout(graph: selectedGraph, size: canvasSize)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(layout.frames.count) of \(selectedGraph.nodes.count) phase tickets shown")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                    laneLegend
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        columnHeaders(layout.columns, canvasWidth: canvasSize.width)
                        Divider()
                        dependencyCanvas(layout: layout, canvasSize: canvasSize)
                    }
                    .frame(width: canvasSize.width)
                }
                .scrollIndicators(.automatic)
            }
            .background(Color(nsColor: .underPageBackgroundColor).opacity(0.38))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Selected dependency path; \(layout.frames.count) of \(selectedGraph.nodes.count) phase tickets shown")
        }
        .accessibilityIdentifier("dependency-graph")
    }

    private var laneLegend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 105), spacing: 12)],
            alignment: .leading,
            spacing: 7
        ) {
            ForEach(TicketLane.allCases, id: \.self) { lane in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lane.graphColor)
                        .frame(width: 12, height: 12)
                    Text(lane.dashboardTitle)
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
            }
            Label("Dependency", systemImage: "arrow.right")
                .font(.caption)
                .accessibilityLabel("Dependency connector")
            Label("Blocking path", systemImage: "arrow.right")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityLabel("Blocking path connector")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Delivery lane and relationship legend")
    }

    private func columnHeaders(
        _ columns: [DependencyGraphColumn],
        canvasWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(column.role == .selectedTicket ? Color.accentColor : .secondary)
                    .frame(width: column.frame.width, height: 43)
                    .position(x: column.frame.midX, y: 21.5)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(width: canvasWidth, height: 43)
    }

    private func dependencyCanvas(
        layout: DependencyGraphLayoutResult,
        canvasSize: CGSize
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for column in layout.columns.dropLast() {
                    var separator = Path()
                    separator.move(to: CGPoint(x: column.frame.maxX, y: 0))
                    separator.addLine(to: CGPoint(x: column.frame.maxX, y: canvasSize.height))
                    context.stroke(
                        separator,
                        with: .color(.secondary.opacity(0.28)),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 6])
                    )
                }

                for connector in layout.connectors {
                    let color = connector.isBlocking ? Color.red : Color.secondary
                    var path = Path()
                    path.move(to: connector.start)
                    let middle = (connector.start.x + connector.end.x) / 2
                    path.addCurve(
                        to: connector.end,
                        control1: CGPoint(x: middle, y: connector.start.y),
                        control2: CGPoint(x: middle, y: connector.end.y)
                    )
                    context.stroke(
                        path,
                        with: .color(color.opacity(connector.isBlocking ? 0.9 : 0.68)),
                        style: StrokeStyle(lineWidth: connector.isBlocking ? 2.4 : 1.4)
                    )

                    let backward: CGFloat = connector.end.x >= connector.start.x ? -8 : 8
                    var arrowhead = Path()
                    arrowhead.move(to: connector.end)
                    arrowhead.addLine(to: CGPoint(x: connector.end.x + backward, y: connector.end.y - 5))
                    arrowhead.addLine(to: CGPoint(x: connector.end.x + backward, y: connector.end.y + 5))
                    arrowhead.closeSubpath()
                    context.fill(arrowhead, with: .color(color))
                }
            }
            .accessibilityHidden(true)

            ForEach(selectedGraph.nodes) { node in
                if let frame = layout.frames[node.id], let role = layout.role(for: node.id) {
                    graphNode(node, role: role)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func graphNode(
        _ node: DependencyGraphNode,
        role: DependencyGraphColumnRole
    ) -> some View {
        let isSelected = node.id == selectedTicketID
        return Button {
            selectedTicketID = node.id
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Text(node.id.rawValue)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .lineLimit(1)
                    if node.lane == .blocked {
                        Label("Blocked", systemImage: "exclamationmark.octagon.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(node.lane.graphColor.opacity(isSelected ? 0.28 : 0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : node.lane.graphColor, lineWidth: isSelected ? 2.5 : 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                if node.blockerCount > 0 {
                    Text("\(node.blockerCount)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 21, height: 21)
                        .background(.red, in: Circle())
                        .offset(x: 7, y: -7)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(node.id.rawValue), \(node.lane.dashboardTitle), \(node.blockerCount) "
                + "blocker\(node.blockerCount == 1 ? "" : "s"), \(role.title)"
                + (isSelected ? ", selected" : "")
        )
        .accessibilityHint("Select to show this ticket's dependency path")
    }

    private var inspector: some View {
        let selection = selectedGraph.selected
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Selected ticket")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                Text(selection.ticket.id.rawValue)
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Outcome")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                    Text(selection.ticket.outcome)
                }
                LabeledContent("Delivery lane", value: selection.ticket.lane.dashboardTitle)
                LabeledContent("Runtime", value: freshness.state.rawValue.capitalized)
                LabeledContent("Freshness", value: freshnessDescription)
                if let codexFailure = FailureStatePresentation(freshness: freshness) {
                    FailureStateView(presentation: codexFailure, style: .compact)
                }

                Divider()
                relationshipSection("Directly requires", nodes: selection.directRequires)
                Divider()
                relationshipSection("Indirectly requires", nodes: selection.indirectRequires)
                Divider()
                relationshipSection("Unlocks", nodes: selection.unlocks)
            }
            .padding(20)
        }
        .accessibilityIdentifier("dependency-inspector")
    }

    private func relationshipSection(_ title: String, nodes: [DependencyGraphNode]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(title) · \(nodes.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            if nodes.isEmpty {
                Text("None").foregroundStyle(.tertiary)
            } else {
                ForEach(nodes) { node in
                    Button {
                        selectedTicketID = node.id
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(node.lane.graphColor)
                                .frame(width: 8, height: 8)
                            Text(node.id.rawValue)
                                .font(.system(.subheadline, design: .monospaced))
                            Spacer(minLength: 8)
                            Text(node.lane.dashboardTitle)
                                .font(.caption)
                                .foregroundStyle(node.lane == .blocked ? .red : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(node.id.rawValue), \(node.lane.dashboardTitle)")
                    .accessibilityHint("Select to show this ticket's dependency path")
                }
            }
        }
    }

    private var freshnessDescription: String {
        guard let lastObservedAt = freshness.lastObservedAt else {
            return freshness.reason ?? "No observation available"
        }
        return "Last observed \(lastObservedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

private extension TicketLane {
    var graphColor: Color {
        switch self {
        case .backlog: .secondary
        case .inProgress: .blue
        case .needsReview: .orange
        case .blocked: .red
        case .accepted: .green
        }
    }
}

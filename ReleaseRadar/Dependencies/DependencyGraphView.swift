import SwiftUI
import ReleaseRadarCore

struct DependencyGraphView: View {
    let graph: DependencyGraphProjection
    @Binding var selectedTicketID: TicketID
    let freshness: CodexObservationFreshness

    private var selectedGraph: DependencyGraphProjection {
        graph.selecting(selectedTicketID) ?? graph
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            HSplitView {
                graphWorkspace
                    .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                inspector
                    .frame(minWidth: 250, idealWidth: 290, maxWidth: 340, maxHeight: .infinity)
            }
        }
        .accessibilityIdentifier("content-dependencies")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Phase dependency map")
                    .font(.largeTitle.weight(.semibold))
                Text("Selected path for \(selectedGraph.selected.ticket.id.rawValue) · direct and indirect relationships")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            laneLegend
        }
        .padding(24)
    }

    private var laneLegend: some View {
        HStack(spacing: 10) {
            ForEach(TicketLane.allCases, id: \.self) { lane in
                HStack(spacing: 4) {
                    Circle().fill(lane.graphColor).frame(width: 7, height: 7)
                    Text(lane.dashboardTitle).font(.caption)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Delivery lane color legend")
    }

    private var graphWorkspace: some View {
        GeometryReader { proxy in
            let canvasSize = CGSize(width: max(proxy.size.width, 1_080), height: max(proxy.size.height, 620))
            let layout = DependencyGraphLayout.makeLayout(graph: selectedGraph, size: canvasSize)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        for connector in layout.connectors {
                            var path = Path()
                            path.move(to: connector.start)
                            let middle = (connector.start.x + connector.end.x) / 2
                            path.addCurve(
                                to: connector.end,
                                control1: CGPoint(x: middle, y: connector.start.y),
                                control2: CGPoint(x: middle, y: connector.end.y)
                            )
                            let isBlocking = selectedGraph.node(id: connector.sourceID)?.lane == .blocked
                            context.stroke(
                                path,
                                with: .color(isBlocking ? .red.opacity(0.72) : .secondary.opacity(0.55)),
                                style: StrokeStyle(lineWidth: isBlocking ? 2 : 1.2)
                            )
                            context.fill(
                                Path(ellipseIn: CGRect(x: connector.end.x - 3, y: connector.end.y - 3, width: 6, height: 6)),
                                with: .color(isBlocking ? .red : .secondary)
                            )
                        }
                    }
                    ForEach(selectedGraph.nodes) { node in
                        if let frame = layout.frames[node.id] {
                            graphNode(node)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .padding(10)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.38))
        .accessibilityIdentifier("dependency-graph")
    }

    private func graphNode(_ node: DependencyGraphNode) -> some View {
        Button {
            selectedTicketID = node.id
        } label: {
            ZStack(alignment: .topTrailing) {
                Text(node.id.rawValue)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(node.lane.graphColor.opacity(node.id == selectedTicketID ? 0.28 : 0.15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(node.id == selectedTicketID ? Color.accentColor : node.lane.graphColor, lineWidth: node.id == selectedTicketID ? 2 : 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if node.blockerCount > 0 {
                    Text("\(node.blockerCount)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 21, height: 21)
                        .background(.red, in: Circle())
                        .offset(x: 7, y: -7)
                        .accessibilityLabel("\(node.blockerCount) blocker\(node.blockerCount == 1 ? "" : "s")")
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(node.id.rawValue), \(node.lane.dashboardTitle), \(node.blockerCount) blockers")
    }

    private var inspector: some View {
        let selection = selectedGraph.selected
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Selected ticket")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(selection.ticket.id.rawValue)
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                Text(selection.ticket.outcome)
                    .foregroundStyle(.secondary)
                LabeledContent("Delivery lane", value: selection.ticket.lane.dashboardTitle)
                if let codexFailure = FailureStatePresentation(freshness: freshness) {
                    FailureStateView(presentation: codexFailure, style: .compact)
                } else {
                    LabeledContent("Runtime", value: "Available")
                }
                relationshipSection("Directly requires", nodes: selection.directRequires)
                relationshipSection("Indirectly requires", nodes: selection.indirectRequires)
                relationshipSection("Unlocks", nodes: selection.unlocks)
            }
            .padding(22)
        }
        .accessibilityIdentifier("dependency-inspector")
    }

    private func relationshipSection(_ title: String, nodes: [DependencyGraphNode]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) · \(nodes.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if nodes.isEmpty {
                Text("None").foregroundStyle(.tertiary)
            } else {
                ForEach(nodes) { node in
                    Text("\(node.id.rawValue) · \(node.lane.dashboardTitle)")
                        .font(.subheadline)
                }
            }
        }
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

import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class DependencyGraphWorkspaceTests: XCTestCase {
    func testDependencyGraphFinderSupportsEmptyFocusAndProjectFields() {
        let graph = graph(focus: .none)

        XCTAssertNil(graph.selected)
        XCTAssertEqual(graph.matchingTickets("").map(\.id.rawValue), ["CURRENT", "LATER", "ROOT"])
        XCTAssertEqual(graph.matchingTickets("later phase").map(\.id.rawValue), ["LATER"])
        XCTAssertEqual(graph.matchingTickets("blocked").map(\.id.rawValue), ["LATER"])
        XCTAssertEqual(graph.matchingTickets("prepare release").map(\.id.rawValue), ["LATER"])
        XCTAssertEqual(graph.clearingSelection().focus, .none)
    }

    func testMissingFocusDoesNotSubstituteAnotherTicket() {
        let graph = graph(focus: .none)
        let missingID = TicketID(rawValue: "MISSING")

        let missing = graph.selecting(missingID)

        XCTAssertEqual(missing.focus, .missing(missingID))
        XCTAssertNil(missing.selected)
        XCTAssertEqual(missing.matchingTickets("").map(\.id.rawValue), ["CURRENT", "LATER", "ROOT"])
    }

    func testRetainedOrderReconcilesOnlyWithinComputedRank() throws {
        let graph = graph(focus: .selected(try XCTUnwrap(graph(focus: .none).selecting(.init(rawValue: "CURRENT")).selected)))
        let retainedOrder = DependencyGraphRankOrder(ranks: [
            .init(depth: 0, ticketIDs: [.init(rawValue: "LATER"), .init(rawValue: "ROOT")]),
            .init(depth: 1, ticketIDs: [.init(rawValue: "CURRENT")]),
        ])

        let layout = DependencyGraphLayout.makeLayout(
            graph: graph,
            size: CGSize(width: 960, height: 520),
            retainedOrder: retainedOrder
        )

        XCTAssertEqual(layout.rankOrder.ranks.first { $0.depth == 0 }?.ticketIDs.map(\.rawValue), ["ROOT"])
        XCTAssertEqual(layout.rankOrder.ranks.first { $0.depth == 1 }?.ticketIDs.map(\.rawValue), ["CURRENT"])
        XCTAssertEqual(layout.rankOrder.ranks.first { $0.depth == 2 }?.ticketIDs.map(\.rawValue), ["LATER"])
    }

    func testFocusedLayoutExcludesSiblingsOutsideSelectedAncestorsAndDependents() {
        let root = node("ROOT")
        let selected = node("SELECTED")
        let dependent = node("DEPENDENT")
        let sibling = node("SIBLING")
        let graph = DependencyGraphProjection(
            projectID: .init(rawValue: "focus-project"),
            nodes: [root, selected, dependent, sibling],
            edges: [
                edge("root-selected", root, selected),
                edge("selected-dependent", selected, dependent),
                edge("root-sibling", root, sibling),
            ],
            focus: .none
        ).selecting(selected.id)

        let layout = DependencyGraphLayout.makeLayout(graph: graph, size: CGSize(width: 960, height: 520))

        XCTAssertEqual(Set(layout.frames.keys), [root.id, selected.id, dependent.id])
        XCTAssertEqual(Set(layout.connectors.map(\.id.rawValue)), ["root-selected", "selected-dependent"])
    }

    func testAdjacentRelationshipsUseDistinctOrthogonalChannels() throws {
        let rootA = node("ROOT-A")
        let rootB = node("ROOT-B")
        let middleC = node("MIDDLE-C")
        let middleD = node("MIDDLE-D")
        let selected = node("SELECTED")
        let graph = DependencyGraphProjection(
            projectID: .init(rawValue: "channel-project"),
            nodes: [rootA, rootB, middleC, middleD, selected],
            edges: [
                edge("a-d", rootA, middleD),
                edge("b-c", rootB, middleC),
                edge("c-selected", middleC, selected),
                edge("d-selected", middleD, selected),
            ],
            focus: .none
        ).selecting(selected.id)

        let layout = DependencyGraphLayout.makeLayout(graph: graph, size: CGSize(width: 1_100, height: 600))
        let aToD = try XCTUnwrap(layout.connectors.first { $0.id.rawValue == "a-d" })
        let bToC = try XCTUnwrap(layout.connectors.first { $0.id.rawValue == "b-c" })
        let rootAFrame = try XCTUnwrap(layout.frames[rootA.id])
        let middleDFrame = try XCTUnwrap(layout.frames[middleD.id])

        XCTAssertNotEqual(aToD.points[1].x, bToC.points[1].x)
        XCTAssertEqual(aToD.start, CGPoint(x: rootAFrame.maxX, y: rootAFrame.midY))
        XCTAssertEqual(aToD.end, CGPoint(x: middleDFrame.minX, y: middleDFrame.midY))
    }

    func testDependentRanksUseNeutralLabels() throws {
        let root = node("ROOT")
        let selected = node("SELECTED")
        let dependent = node("DEPENDENT")
        let graph = DependencyGraphProjection(
            projectID: .init(rawValue: "labels-project"),
            nodes: [root, selected, dependent],
            edges: [edge("root-selected", root, selected), edge("selected-dependent", selected, dependent)],
            focus: .none
        ).selecting(selected.id)

        let layout = DependencyGraphLayout.makeLayout(graph: graph, size: CGSize(width: 960, height: 520))

        XCTAssertEqual(
            try XCTUnwrap(layout.columnTitle(for: dependent.id)),
            "Dependency depth 3"
        )
    }

    func testFinderStateHighlightsAllResultsAndClampsKeyboardNavigation() {
        let nodes = (0...9).map { index in
            DependencyGraphNode(
                id: .init(rawValue: String(format: "T%02d", index)),
                outcome: "Ticket \(index)",
                lane: .backlog,
                blockerCount: 0,
                phaseName: "Planning"
            )
        }
        let graph = DependencyGraphProjection(
            projectID: .init(rawValue: "finder-project"),
            nodes: nodes,
            edges: [],
            focus: .none
        )
        var finder = DependencyGraphFinderState()

        finder.updateQuery("", in: graph)
        XCTAssertEqual(graph.matchingTickets(finder.query).count, 10)
        XCTAssertEqual(finder.selectedTicket(in: graph)?.id.rawValue, "T00")

        for _ in 0..<20 { finder.move(.next, in: graph) }
        XCTAssertEqual(finder.selectedTicket(in: graph)?.id.rawValue, "T09")

        for _ in 0..<20 { finder.move(.previous, in: graph) }
        XCTAssertEqual(finder.selectedTicket(in: graph)?.id.rawValue, "T00")

        finder.updateQuery("ticket 9", in: graph)
        XCTAssertEqual(finder.selectedTicket(in: graph)?.id.rawValue, "T09")
    }

    private func graph(focus: DependencyGraphFocus) -> DependencyGraphProjection {
        let root = DependencyGraphNode(
            id: .init(rawValue: "ROOT"),
            outcome: "Establish prerequisite",
            lane: .accepted,
            blockerCount: 0,
            phaseName: "Current phase"
        )
        let current = DependencyGraphNode(
            id: .init(rawValue: "CURRENT"),
            outcome: "Current selected work",
            lane: .inProgress,
            blockerCount: 0,
            phaseName: "Current phase"
        )
        let later = DependencyGraphNode(
            id: .init(rawValue: "LATER"),
            outcome: "Prepare release",
            lane: .blocked,
            blockerCount: 1,
            phaseName: "Later phase"
        )
        return DependencyGraphProjection(
            projectID: .init(rawValue: "graph-project"),
            nodes: [root, current, later],
            edges: [
                .init(id: .init(rawValue: "root-current"), sourceID: root.id, targetID: current.id),
                .init(id: .init(rawValue: "current-later"), sourceID: current.id, targetID: later.id),
            ],
            focus: focus
        )
    }

    private func node(_ id: String) -> DependencyGraphNode {
        DependencyGraphNode(
            id: .init(rawValue: id),
            outcome: "Outcome for \(id)",
            lane: .backlog,
            blockerCount: 0,
            phaseName: "Current phase"
        )
    }

    private func edge(
        _ id: String,
        _ prerequisite: DependencyGraphNode,
        _ dependent: DependencyGraphNode
    ) -> DependencyGraphEdge {
        .init(id: .init(rawValue: id), sourceID: prerequisite.id, targetID: dependent.id)
    }
}

import ReleaseRadarCore

struct NavigationHistoryEntry: Equatable, Sendable {
    var route: AppRoute
    var phaseID: PhaseID?
    var selectedTicketID: TicketID?
}

struct NavigationHistory: Equatable, Sendable {
    private(set) var entries: [NavigationHistoryEntry]
    private(set) var index: Int

    init(initial route: AppRoute) {
        entries = [.init(route: route, phaseID: nil, selectedTicketID: nil)]
        index = 0
    }

    var current: NavigationHistoryEntry { entries[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index + 1 < entries.count }

    mutating func navigate(to route: AppRoute, phaseID: PhaseID? = nil, selectedTicketID: TicketID? = nil) {
        if canGoForward {
            entries.removeSubrange((index + 1)..<entries.count)
        }
        entries.append(.init(route: route, phaseID: phaseID, selectedTicketID: selectedTicketID))
        index = entries.count - 1
    }

    mutating func updateCurrent(phaseID: PhaseID?, selectedTicketID: TicketID?) {
        entries[index].phaseID = phaseID
        entries[index].selectedTicketID = selectedTicketID
    }

    mutating func goBack() -> Bool {
        guard canGoBack else { return false }
        index -= 1
        return true
    }

    mutating func goForward() -> Bool {
        guard canGoForward else { return false }
        index += 1
        return true
    }
}

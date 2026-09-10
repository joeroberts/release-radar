import ReleaseRadarCore

extension ProjectRegistration {
    func hasSameNavigationIdentity(as other: ProjectRegistration) -> Bool {
        projectID == other.projectID
            && registrationID.utf8.elementsEqual(other.registrationID.utf8)
    }
}

enum NavigationFocus: Hashable, Sendable {
    case route(AppRoute)
    case ticket(TicketID)
    case historyEvent(HistoryEventIdentity)
    case historyDetail(HistoryEventIdentity)
    case planChangeProposal(proposalID: String, version: Int64, ticketID: TicketID?)
    case referenceSource(linkID: String, version: Int64)
    case recordedImpacts
    case recordedImpact(rowID: String)
    case filterSummary
    case recovery
}

struct NavigationHistoryEntry: Equatable, Sendable {
    var route: AppRoute
    var registration: ProjectRegistration?
    var phaseID: PhaseID?
    var showsAllPhases: Bool
    var filter: DeliveryGoalFilter?
    var selectedTicketID: TicketID?
    var historyFilter: HistoryFilter?
    var selectedHistoryEventID: HistoryEventIdentity?
    var historyViewportEventID: HistoryEventIdentity?
    var focus: NavigationFocus?

    init(
        route: AppRoute,
        registration: ProjectRegistration? = nil,
        phaseID: PhaseID? = nil,
        showsAllPhases: Bool = false,
        filter: DeliveryGoalFilter? = nil,
        selectedTicketID: TicketID? = nil,
        historyFilter: HistoryFilter? = nil,
        selectedHistoryEventID: HistoryEventIdentity? = nil,
        historyViewportEventID: HistoryEventIdentity? = nil,
        focus: NavigationFocus? = nil
    ) {
        self.route = route
        self.registration = registration
        self.phaseID = phaseID
        self.showsAllPhases = showsAllPhases
        self.filter = filter
        self.selectedTicketID = selectedTicketID
        self.historyFilter = historyFilter
        self.selectedHistoryEventID = selectedHistoryEventID
        self.historyViewportEventID = historyViewportEventID
        self.focus = focus
    }
}

struct NavigationHistory: Equatable, Sendable {
    private(set) var entries: [NavigationHistoryEntry]
    private(set) var index: Int

    init(initial route: AppRoute) {
        entries = [.init(route: route)]
        index = 0
    }

    var current: NavigationHistoryEntry { entries[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index + 1 < entries.count }

    mutating func navigate(to entry: NavigationHistoryEntry) {
        if canGoForward {
            entries.removeSubrange((index + 1)..<entries.count)
        }
        entries.append(entry)
        index = entries.count - 1
    }

    mutating func navigate(
        to route: AppRoute,
        registration: ProjectRegistration? = nil,
        phaseID: PhaseID? = nil,
        showsAllPhases: Bool = false,
        filter: DeliveryGoalFilter? = nil,
        selectedTicketID: TicketID? = nil,
        historyFilter: HistoryFilter? = nil,
        selectedHistoryEventID: HistoryEventIdentity? = nil,
        historyViewportEventID: HistoryEventIdentity? = nil,
        focus: NavigationFocus? = nil
    ) {
        navigate(to: .init(
            route: route,
            registration: registration,
            phaseID: phaseID,
            showsAllPhases: showsAllPhases,
            filter: filter,
            selectedTicketID: selectedTicketID,
            historyFilter: historyFilter,
            selectedHistoryEventID: selectedHistoryEventID,
            historyViewportEventID: historyViewportEventID,
            focus: focus
        ))
    }

    mutating func updateCurrent(
        registration: ProjectRegistration? = nil,
        phaseID: PhaseID?,
        showsAllPhases: Bool = false,
        filter: DeliveryGoalFilter? = nil,
        selectedTicketID: TicketID?,
        historyFilter: HistoryFilter? = nil,
        selectedHistoryEventID: HistoryEventIdentity? = nil,
        historyViewportEventID: HistoryEventIdentity? = nil,
        focus: NavigationFocus? = nil
    ) {
        entries[index].registration = registration ?? entries[index].registration
        entries[index].phaseID = phaseID
        entries[index].showsAllPhases = showsAllPhases
        entries[index].filter = filter
        entries[index].selectedTicketID = selectedTicketID
        entries[index].historyFilter = historyFilter
        entries[index].selectedHistoryEventID = selectedHistoryEventID
        entries[index].historyViewportEventID = historyViewportEventID
        entries[index].focus = focus
    }

    mutating func reset(to route: AppRoute = .projects) {
        self = .init(initial: route)
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

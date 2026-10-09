import CryptoKit
import Foundation
import SQLite3

public struct TicketOrderingContext: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let digest: String

    public init(projectID: ProjectID, digest: String) {
        self.projectID = projectID
        self.digest = digest
    }
}

public enum TicketOrderAnchor: Codable, Equatable, Sendable {
    case before(TicketID)
    case after(TicketID)

    var ticketID: TicketID {
        switch self {
        case let .before(ticketID), let .after(ticketID): ticketID
        }
    }
}

public struct TicketLaneOrderSnapshot: Equatable, Sendable {
    public let lane: TicketLane
    public let ticketIDs: [TicketID]

    public init(lane: TicketLane, ticketIDs: [TicketID]) {
        self.lane = lane
        self.ticketIDs = ticketIDs
    }
}

public struct TicketOrderingSnapshot: Equatable, Sendable {
    public let context: TicketOrderingContext
    public let lanes: [TicketLaneOrderSnapshot]

    public init(context: TicketOrderingContext, lanes: [TicketLaneOrderSnapshot]) {
        self.context = context
        self.lanes = lanes
    }

    public func ticketIDs(in lane: TicketLane) -> [TicketID] {
        lanes.first { $0.lane == lane }?.ticketIDs ?? []
    }
}

public enum TicketOrderingUnavailableReason: Codable, Equatable, Sendable {
    case missingOrderRow(TicketID)
    case unexpectedOrderRow(TicketID)
    case laneMismatch(TicketID)
    case malformedOrderKey(TicketID)
    case duplicateOrderKey(TicketLane)
    case invalidStoredState(String)
    case contextTooLarge
}

public enum TicketOrderingIneligibility: String, Codable, Equatable, Sendable {
    case unplaced
    case retired
    case accepted
    case completedPhase
}

public struct TicketOrderingConflict: Codable, Equatable, Sendable {
    public let prerequisiteTicketID: TicketID
    public let dependentTicketID: TicketID
    public let witnessChain: [TicketID]
    public let lane: TicketLane
    public let prerequisitePhaseID: PhaseID
    public let prerequisitePhaseName: String
    public let dependentPhaseID: PhaseID
    public let dependentPhaseName: String

    public init(
        prerequisiteTicketID: TicketID,
        dependentTicketID: TicketID,
        witnessChain: [TicketID],
        lane: TicketLane,
        prerequisitePhaseID: PhaseID,
        prerequisitePhaseName: String,
        dependentPhaseID: PhaseID,
        dependentPhaseName: String
    ) {
        self.prerequisiteTicketID = prerequisiteTicketID
        self.dependentTicketID = dependentTicketID
        self.witnessChain = witnessChain
        self.lane = lane
        self.prerequisitePhaseID = prerequisitePhaseID
        self.prerequisitePhaseName = prerequisitePhaseName
        self.dependentPhaseID = dependentPhaseID
        self.dependentPhaseName = dependentPhaseName
    }
}

public enum TicketOrderingError: Error, LocalizedError, Codable, Equatable, Sendable {
    case ownerAuthorityRequired
    case staleContext
    case unavailable(TicketOrderingUnavailableReason)
    case targetIneligible(TicketOrderingIneligibility)
    case invalidAnchor(TicketID)
    case dependencyConflict(TicketOrderingConflict)
    case resourceLimit

    public var errorDescription: String? {
        switch self {
        case .ownerAuthorityRequired:
            "Only the owner application can reorder tickets."
        case .staleContext:
            "Ticket order or its dependency context changed. Refresh before trying again."
        case .unavailable:
            "Ticket ordering is unavailable because its complete stored context could not be validated."
        case let .targetIneligible(reason):
            switch reason {
            case .unplaced: "Place the ticket in a phase before reordering it."
            case .retired: "Retired tickets are read-only and cannot be reordered."
            case .accepted: "Accepted tickets are read-only and cannot be reordered."
            case .completedPhase: "Reopen the completed phase before reordering its tickets."
            }
        case let .invalidAnchor(ticketID):
            "Ticket \(ticketID.rawValue) is not an available anchor in the complete lane order."
        case let .dependencyConflict(conflict):
            let chain = conflict.witnessChain.map(\.rawValue).joined(separator: " → ")
            return "Keep prerequisite \(conflict.prerequisiteTicketID.rawValue) before dependent \(conflict.dependentTicketID.rawValue) in \(conflict.lane.rawValue). Dependency path: \(chain)."
        case .resourceLimit:
            "The requested order key exceeds the current SQLite storage limit. The existing order was preserved."
        }
    }
}

/// Owns only the persisted sequence within the five existing lanes. Ticket rows
/// remain authoritative for placement, phase, lifecycle and lane membership.
public enum TicketLaneOrderingPolicy {
    private static let maximumContextRows = 10_000

    public static func snapshot(
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> TicketOrderingSnapshot {
        try validatedLoad(projectID: projectID, connection: connection).snapshot
    }

    private static func validatedLoad(
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> LoadedState {
        do {
            return try load(projectID: projectID, connection: connection)
        } catch let error as TicketOrderingError {
            throw error
        } catch DocumentationOperationError.inventoryTooLarge {
            throw TicketOrderingError.unavailable(.contextTooLarge)
        } catch {
            throw TicketOrderingError.unavailable(.invalidStoredState(error.localizedDescription))
        }
    }

    static func reorder(
        projectID: ProjectID,
        ticketID: TicketID,
        expectedLane: TicketLane,
        anchor: TicketOrderAnchor,
        expectedOrderingContext: TicketOrderingContext,
        connection: SQLiteConnection
    ) throws -> TicketOrderingContext {
        let state = try validatedLoad(projectID: projectID, connection: connection)
        guard identity(state.snapshot.context.projectID) == identity(expectedOrderingContext.projectID),
              state.snapshot.context.digest == expectedOrderingContext.digest else {
            throw TicketOrderingError.staleContext
        }
        guard let target = state.tickets[identity(ticketID)] else {
            throw TicketOrderingError.targetIneligible(.unplaced)
        }
        if target.retired { throw TicketOrderingError.targetIneligible(.retired) }
        guard let targetLane = target.lane, target.phaseID != nil else {
            throw TicketOrderingError.targetIneligible(.unplaced)
        }
        guard targetLane != .accepted else {
            throw TicketOrderingError.targetIneligible(.accepted)
        }
        guard target.phaseLifecycle != .completed else {
            throw TicketOrderingError.targetIneligible(.completedPhase)
        }
        guard targetLane == expectedLane else {
            throw TicketOrderingError.staleContext
        }

        let anchorID = anchor.ticketID
        guard identity(anchorID) != identity(ticketID),
              let anchorTicket = state.tickets[identity(anchorID)],
              !anchorTicket.retired,
              anchorTicket.lane == expectedLane,
              anchorTicket.orderKey != nil
        else {
            throw TicketOrderingError.invalidAnchor(anchorID)
        }

        let original = state.snapshot.ticketIDs(in: expectedLane)
        guard let originalIndex = original.firstIndex(where: { identity($0) == identity(ticketID) }) else {
            throw TicketOrderingError.unavailable(.missingOrderRow(ticketID))
        }
        var candidate = original
        candidate.remove(at: originalIndex)
        guard let anchorIndex = candidate.firstIndex(where: { identity($0) == identity(anchorID) }) else {
            throw TicketOrderingError.invalidAnchor(anchorID)
        }
        let insertionIndex: Int
        switch anchor {
        case .before: insertionIndex = anchorIndex
        case .after: insertionIndex = anchorIndex + 1
        }
        candidate.insert(ticketID, at: insertionIndex)

        let originalPositions = Dictionary(uniqueKeysWithValues: original.enumerated().map { (identity($0.element), $0.offset) })
        let candidatePositions = Dictionary(uniqueKeysWithValues: candidate.enumerated().map { (identity($0.element), $0.offset) })
        let affected = Set(candidate.map { identity($0) }.filter { originalPositions[$0] != candidatePositions[$0] })
        if let conflict = dependencyConflict(
            affected: affected,
            candidatePositions: candidatePositions,
            state: state
        ) {
            throw TicketOrderingError.dependencyConflict(conflict)
        }

        guard candidate.map({ identity($0) }) != original.map({ identity($0) }) else {
            return state.snapshot.context
        }
        let leftKey = insertionIndex > 0
            ? state.tickets[identity(candidate[insertionIndex - 1])]?.orderKey
            : nil
        let rightKey = insertionIndex + 1 < candidate.count
            ? state.tickets[identity(candidate[insertionIndex + 1])]?.orderKey
            : nil
        let orderKey = try allocateOrderKey(
            after: leftKey,
            before: rightKey,
            maximumLength: try sqliteMaximumLength(connection)
        )
        do {
            try connection.execute(
                "UPDATE ticket_lane_order SET order_key=? WHERE project_id=? AND ticket_id=? AND lane=?",
                bindings: [
                    .text(orderKey), .text(projectID.rawValue), .text(ticketID.rawValue),
                    .text(expectedLane.rawValue),
                ]
            )
        } catch let error as SQLiteError where error.code == SQLITE_TOOBIG || error.code == SQLITE_NOMEM {
            throw TicketOrderingError.resourceLimit
        }
        guard try connection.scalarText(
            "SELECT order_key FROM ticket_lane_order WHERE project_id=? AND ticket_id=? AND lane=?",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue), .text(expectedLane.rawValue)]
        ) == orderKey else {
            throw TicketOrderingError.unavailable(.missingOrderRow(ticketID))
        }
        return try validatedLoad(projectID: projectID, connection: connection).snapshot.context
    }

    static func maintainPlacedTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        lane: TicketLane,
        connection: SQLiteConnection
    ) throws {
        let current = try connection.row(
            "SELECT lane,order_key FROM ticket_lane_order WHERE project_id=? AND ticket_id=?",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        )
        if current?["lane"] == .text(lane.rawValue) { return }
        let lastKey = try connection.scalarText(
            "SELECT order_key FROM ticket_lane_order WHERE project_id=? AND lane=? AND ticket_id<>? ORDER BY order_key COLLATE BINARY DESC LIMIT 1",
            bindings: [.text(projectID.rawValue), .text(lane.rawValue), .text(ticketID.rawValue)]
        )
        let orderKey = try allocateOrderKey(
            after: lastKey,
            before: nil,
            maximumLength: try sqliteMaximumLength(connection)
        )
        do {
            if current == nil {
                try connection.execute(
                    "INSERT INTO ticket_lane_order (project_id,ticket_id,lane,order_key) VALUES (?,?,?,?)",
                    bindings: [
                        .text(projectID.rawValue), .text(ticketID.rawValue),
                        .text(lane.rawValue), .text(orderKey),
                    ]
                )
            } else {
                try connection.execute(
                    "UPDATE ticket_lane_order SET lane=?,order_key=? WHERE project_id=? AND ticket_id=?",
                    bindings: [
                        .text(lane.rawValue), .text(orderKey),
                        .text(projectID.rawValue), .text(ticketID.rawValue),
                    ]
                )
            }
        } catch let error as SQLiteError where error.code == SQLITE_TOOBIG || error.code == SQLITE_NOMEM {
            throw TicketOrderingError.resourceLimit
        }
    }

    static func removeTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            "DELETE FROM ticket_lane_order WHERE project_id=? AND ticket_id=?",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        )
    }

    private static func allocateOrderKey(
        after left: String?,
        before right: String?,
        maximumLength: Int
    ) throws -> String {
        if let left, !isValidOrderKey(left) {
            throw TicketOrderingError.unavailable(.invalidStoredState("The left order anchor is malformed."))
        }
        if let right, !isValidOrderKey(right) {
            throw TicketOrderingError.unavailable(.invalidStoredState("The right order anchor is malformed."))
        }

        let pieces: [String]
        switch (left, right) {
        case (nil, nil):
            pieces = ["1"]
        case let (left?, nil):
            pieces = [left, "1"]
        case let (nil, right?):
            let zeroCount = right.prefix { $0 == "0" }.count
            pieces = [String(repeating: "0", count: zeroCount + 1), "1"]
        case let (left?, right?):
            guard binaryLess(left, right) else {
                throw TicketOrderingError.unavailable(.invalidStoredState("Order anchors are not strictly increasing."))
            }
            if right.hasPrefix(left) {
                let suffix = right.dropFirst(left.count)
                let zeroCount = suffix.prefix { $0 == "0" }.count
                pieces = [left, String(repeating: "0", count: zeroCount + 1), "1"]
            } else {
                pieces = [left, "1"]
            }
        }

        var byteCount = 0
        for piece in pieces {
            let (next, overflow) = byteCount.addingReportingOverflow(piece.utf8.count)
            guard !overflow, next <= maximumLength else {
                throw TicketOrderingError.resourceLimit
            }
            byteCount = next
        }
        let key = pieces.joined()
        guard isValidOrderKey(key),
              left.map({ binaryLess($0, key) }) ?? true,
              right.map({ binaryLess(key, $0) }) ?? true
        else {
            throw TicketOrderingError.unavailable(.invalidStoredState("The requested order key could not be allocated."))
        }
        return key
    }

    private static func sqliteMaximumLength(_ connection: SQLiteConnection) throws -> Int {
        let value = try connection.scalarInt(
            "SELECT CAST(substr(compile_options,12) AS INTEGER) FROM pragma_compile_options WHERE compile_options GLOB 'MAX_LENGTH=*' LIMIT 1"
        ) ?? Int64(Int32.max)
        guard value > 0, let maximum = Int(exactly: value) else {
            throw TicketOrderingError.resourceLimit
        }
        return maximum
    }

    private static func load(
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> LoadedState {
        guard let projectRow = try connection.row(
            "SELECT id,name,lifecycle FROM projects WHERE id=?",
            bindings: [.text(projectID.rawValue)]
        ), case let .text(projectName)? = projectRow["name"],
           case let .text(projectLifecycle)? = projectRow["lifecycle"]
        else {
            throw TicketOrderingError.unavailable(.invalidStoredState("The project is unavailable."))
        }

        let registrationRow = try connection.row(
            "SELECT registration_id,request_generation,setup_state FROM project_registrations WHERE project_id=?",
            bindings: [.text(projectID.rawValue)]
        )
        let registration: ContextRegistration?
        if let registrationRow {
            guard case let .text(id)? = registrationRow["registration_id"],
                  case let .integer(generation)? = registrationRow["request_generation"],
                  case let .text(state)? = registrationRow["setup_state"]
            else {
                throw TicketOrderingError.unavailable(.invalidStoredState("The project registration is malformed."))
            }
            registration = .init(id: id, generation: generation, state: state)
        } else {
            registration = nil
        }
        let rootRows = try boundedRows(
            connection,
            "SELECT id,path FROM project_roots WHERE project_id=? ORDER BY id COLLATE BINARY,path COLLATE BINARY",
            bindings: [.text(projectID.rawValue)]
        )
        let roots = try rootRows.map { row -> ContextRoot in
            guard case let .text(id)? = row["id"], case let .text(path)? = row["path"] else {
                throw TicketOrderingError.unavailable(.invalidStoredState("A project root is malformed."))
            }
            return .init(id: id, path: path)
        }

        let phaseRows = try boundedRows(
            connection,
            """
            SELECT phases.id,phases.name,phase_lifecycles.lifecycle
            FROM phases
            LEFT JOIN phase_lifecycles
              ON phase_lifecycles.project_id=phases.project_id
             AND phase_lifecycles.phase_id=phases.id
            WHERE phases.project_id=?
            ORDER BY phases.id COLLATE BINARY
            """,
            bindings: [.text(projectID.rawValue)]
        )
        var phases: [Data: ContextPhase] = [:]
        for row in phaseRows {
            guard case let .text(id)? = row["id"],
                  case let .text(name)? = row["name"],
                  case let .text(lifecycleText)? = row["lifecycle"],
                  let lifecycle = PhaseLifecycle(rawValue: lifecycleText)
            else {
                throw TicketOrderingError.unavailable(.invalidStoredState("A phase lifecycle is malformed."))
            }
            phases[identity(id)] = .init(id: id, name: name, lifecycle: lifecycle)
        }

        let ticketRows = try boundedRows(
            connection,
            """
            SELECT tickets.id,tickets.phase_id,tickets.lane,
                   CASE WHEN ticket_retirements.ticket_id IS NULL THEN 0 ELSE 1 END AS is_retired,
                   ticket_lane_order.lane AS order_lane,ticket_lane_order.order_key
            FROM tickets
            LEFT JOIN ticket_retirements
              ON ticket_retirements.project_id=tickets.project_id
             AND ticket_retirements.ticket_id=tickets.id
            LEFT JOIN ticket_lane_order
              ON ticket_lane_order.project_id=tickets.project_id
             AND ticket_lane_order.ticket_id=tickets.id
            WHERE tickets.project_id=?
            ORDER BY tickets.id COLLATE BINARY
            """,
            bindings: [.text(projectID.rawValue)]
        )
        var tickets: [Data: LoadedTicket] = [:]
        var laneMembers = Dictionary(uniqueKeysWithValues: TicketLane.allCases.map { ($0, [(TicketID, String)]()) })
        var laneKeys = Dictionary(uniqueKeysWithValues: TicketLane.allCases.map { ($0, Set<String>()) })
        for row in ticketRows {
            guard case let .text(id)? = row["id"], case let .integer(retiredValue)? = row["is_retired"] else {
                throw TicketOrderingError.unavailable(.invalidStoredState("A ticket identity is malformed."))
            }
            let ticketID = TicketID(rawValue: id)
            let phaseID = text(row["phase_id"])
            let laneText = text(row["lane"])
            let orderLaneText = text(row["order_lane"])
            let orderKey = text(row["order_key"])
            let retired = retiredValue != 0
            if retired {
                if orderKey != nil || orderLaneText != nil {
                    throw TicketOrderingError.unavailable(.unexpectedOrderRow(ticketID))
                }
            } else if phaseID == nil && laneText == nil {
                if orderKey != nil || orderLaneText != nil {
                    throw TicketOrderingError.unavailable(.unexpectedOrderRow(ticketID))
                }
            } else {
                guard let phaseID, let laneText, let lane = TicketLane(rawValue: laneText),
                      let phase = phases[identity(phaseID)]
                else {
                    throw TicketOrderingError.unavailable(.invalidStoredState("A placed ticket has invalid phase or lane state."))
                }
                guard let orderKey, let orderLaneText else {
                    throw TicketOrderingError.unavailable(.missingOrderRow(ticketID))
                }
                guard orderLaneText == lane.rawValue else {
                    throw TicketOrderingError.unavailable(.laneMismatch(ticketID))
                }
                guard isValidOrderKey(orderKey) else {
                    throw TicketOrderingError.unavailable(.malformedOrderKey(ticketID))
                }
                guard laneKeys[lane, default: []].insert(orderKey).inserted else {
                    throw TicketOrderingError.unavailable(.duplicateOrderKey(lane))
                }
                laneMembers[lane, default: []].append((ticketID, orderKey))
                tickets[identity(id)] = .init(
                    id: ticketID, phaseID: PhaseID(rawValue: phaseID), phaseName: phase.name,
                    phaseLifecycle: phase.lifecycle, lane: lane, retired: false, orderKey: orderKey
                )
                continue
            }
            let phase = phaseID.flatMap { phases[identity($0)] }
            tickets[identity(id)] = .init(
                id: ticketID,
                phaseID: phaseID.map(PhaseID.init(rawValue:)),
                phaseName: phase?.name,
                phaseLifecycle: phase?.lifecycle,
                lane: laneText.flatMap(TicketLane.init(rawValue:)),
                retired: retired,
                orderKey: nil
            )
        }

        let dependencyRows = try boundedRows(
            connection,
            "SELECT id,ticket_id,depends_on_ticket_id FROM ticket_dependencies WHERE project_id=? ORDER BY id COLLATE BINARY",
            bindings: [.text(projectID.rawValue)]
        )
        let dependencies = try dependencyRows.map { row -> ContextDependency in
            guard case let .text(id)? = row["id"],
                  case let .text(ticketID)? = row["ticket_id"],
                  case let .text(prerequisiteID)? = row["depends_on_ticket_id"],
                  tickets[identity(ticketID)] != nil, tickets[identity(prerequisiteID)] != nil
            else {
                throw TicketOrderingError.unavailable(.invalidStoredState("A ticket dependency is malformed."))
            }
            return .init(id: id, ticketID: ticketID, prerequisiteID: prerequisiteID)
        }

        let orderedLanes = TicketLane.allCases.map { lane -> TicketLaneOrderSnapshot in
            let ids = laneMembers[lane, default: []]
                .sorted { binaryLess($0.1, $1.1) }
                .map(\.0)
            return .init(lane: lane, ticketIDs: ids)
        }
        let capture = ContextCapture(
            projectID: projectID.rawValue,
            projectName: projectName,
            projectLifecycle: projectLifecycle,
            registration: registration,
            roots: roots,
            phases: phases.values.sorted { binaryLess($0.id, $1.id) },
            tickets: tickets.values.sorted { binaryLess($0.id.rawValue, $1.id.rawValue) }.map(ContextTicket.init),
            dependencies: dependencies
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(capture))
            .map { String(format: "%02x", $0) }
            .joined()
        return LoadedState(
            snapshot: .init(
                context: .init(projectID: projectID, digest: digest),
                lanes: orderedLanes
            ),
            tickets: tickets,
            dependencies: dependencies
        )
    }

    private static func dependencyConflict(
        affected: Set<Data>,
        candidatePositions: [Data: Int],
        state: LoadedState
    ) -> TicketOrderingConflict? {
        var dependents: [Data: [Data]] = [:]
        var prerequisites: [Data: [Data]] = [:]
        for edge in state.dependencies {
            let prerequisiteID = identity(edge.prerequisiteID)
            let dependentID = identity(edge.ticketID)
            guard state.tickets[prerequisiteID]?.lane != .accepted else { continue }
            dependents[prerequisiteID, default: []].append(dependentID)
            prerequisites[dependentID, default: []].append(prerequisiteID)
        }
        for key in Array(dependents.keys) { dependents[key]?.sort(by: dataLess) }
        for key in Array(prerequisites.keys) { prerequisites[key]?.sort(by: dataLess) }

        let affectedIDs = affected.sorted(by: dataLess)
        for prerequisiteID in affectedIDs {
            var queue: [(Data, [Data])] = [(prerequisiteID, [prerequisiteID])]
            var visited: Set<Data> = [prerequisiteID]
            var index = 0
            while index < queue.count {
                let (current, path) = queue[index]
                index += 1
                for dependentID in dependents[current, default: []] where visited.insert(dependentID).inserted {
                    let nextPath = path + [dependentID]
                    if let conflict = conflict(
                        prerequisiteID: prerequisiteID,
                        dependentID: dependentID,
                        witness: nextPath,
                        candidatePositions: candidatePositions,
                        state: state
                    ) { return conflict }
                    queue.append((dependentID, nextPath))
                }
            }
        }
        for dependentID in affectedIDs {
            var queue: [(Data, [Data])] = [(dependentID, [dependentID])]
            var visited: Set<Data> = [dependentID]
            var index = 0
            while index < queue.count {
                let (current, path) = queue[index]
                index += 1
                for prerequisiteID in prerequisites[current, default: []] where visited.insert(prerequisiteID).inserted {
                    let nextPath = [prerequisiteID] + path
                    if let conflict = conflict(
                        prerequisiteID: prerequisiteID,
                        dependentID: dependentID,
                        witness: nextPath,
                        candidatePositions: candidatePositions,
                        state: state
                    ) { return conflict }
                    queue.append((prerequisiteID, nextPath))
                }
            }
        }
        return nil
    }

    private static func conflict(
        prerequisiteID: Data,
        dependentID: Data,
        witness: [Data],
        candidatePositions: [Data: Int],
        state: LoadedState
    ) -> TicketOrderingConflict? {
        guard prerequisiteID != dependentID,
              let prerequisite = state.tickets[prerequisiteID],
              let dependent = state.tickets[dependentID],
              !prerequisite.retired, !dependent.retired,
              let lane = prerequisite.lane, dependent.lane == lane,
              let prerequisitePosition = candidatePositions[identity(prerequisite.id)],
              let dependentPosition = candidatePositions[identity(dependent.id)],
              prerequisitePosition >= dependentPosition,
              let prerequisitePhaseID = prerequisite.phaseID,
              let prerequisitePhaseName = prerequisite.phaseName,
              let dependentPhaseID = dependent.phaseID,
              let dependentPhaseName = dependent.phaseName
        else { return nil }
        let witnessChain = witness.compactMap { state.tickets[$0]?.id }
        guard witnessChain.count == witness.count else { return nil }
        return .init(
            prerequisiteTicketID: prerequisite.id,
            dependentTicketID: dependent.id,
            witnessChain: witnessChain,
            lane: lane,
            prerequisitePhaseID: prerequisitePhaseID,
            prerequisitePhaseName: prerequisitePhaseName,
            dependentPhaseID: dependentPhaseID,
            dependentPhaseName: dependentPhaseName
        )
    }

    private static func boundedRows(
        _ connection: SQLiteConnection,
        _ sql: String,
        bindings: [SQLiteValue]
    ) throws -> [[String: SQLiteValue]] {
        try connection.rows(sql, bindings: bindings, maximum: maximumContextRows)
    }

    private static func isValidOrderKey(_ key: String) -> Bool {
        !key.isEmpty && key.utf8.last == 49 && key.utf8.allSatisfy { $0 == 48 || $0 == 49 }
    }

    private static func binaryLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }

    private static func dataLess(_ lhs: Data, _ rhs: Data) -> Bool {
        lhs.lexicographicallyPrecedes(rhs)
    }

    private static func identity(_ value: String) -> Data {
        Data(value.utf8)
    }

    private static func identity(_ value: TicketID) -> Data {
        identity(value.rawValue)
    }

    private static func identity(_ value: ProjectID) -> Data {
        identity(value.rawValue)
    }

    private static func text(_ value: SQLiteValue?) -> String? {
        guard case let .text(value)? = value else { return nil }
        return value
    }
}

private struct LoadedState {
    let snapshot: TicketOrderingSnapshot
    let tickets: [Data: LoadedTicket]
    let dependencies: [ContextDependency]
}

private struct LoadedTicket {
    let id: TicketID
    let phaseID: PhaseID?
    let phaseName: String?
    let phaseLifecycle: PhaseLifecycle?
    let lane: TicketLane?
    let retired: Bool
    let orderKey: String?
}

private struct ContextCapture: Codable {
    let projectID: String
    let projectName: String
    let projectLifecycle: String
    let registration: ContextRegistration?
    let roots: [ContextRoot]
    let phases: [ContextPhase]
    let tickets: [ContextTicket]
    let dependencies: [ContextDependency]
}

private struct ContextRegistration: Codable {
    let id: String
    let generation: Int64
    let state: String
}

private struct ContextRoot: Codable {
    let id: String
    let path: String
}

private struct ContextPhase: Codable {
    let id: String
    let name: String
    let lifecycle: PhaseLifecycle
}

private struct ContextTicket: Codable {
    let id: String
    let phaseID: String?
    let lane: TicketLane?
    let retired: Bool
    let orderKey: String?

    init(_ ticket: LoadedTicket) {
        id = ticket.id.rawValue
        phaseID = ticket.phaseID?.rawValue
        lane = ticket.lane
        retired = ticket.retired
        orderKey = ticket.orderKey
    }
}

private struct ContextDependency: Codable {
    let id: String
    let ticketID: String
    let prerequisiteID: String
}

import Foundation

public enum DeliveryGoalCoveragePolicy {
    public static func assess(
        projectID: ProjectID,
        phaseID: PhaseID,
        goalID: DeliveryGoalID,
        connection: SQLiteConnection
    ) throws -> DeliveryGoalCoverageAssessment {
        let obligationRows = try connection.rows(
            """
            SELECT o.phase_id,o.goal_id,o.ticket_id,o.scope,o.assessment,t.lane,
                   CASE WHEN a.ticket_id IS NULL THEN 0 ELSE 1 END AS is_current,
                   d.reason AS drop_reason
            FROM delivery_goal_obligations o
            JOIN tickets t ON t.project_id=o.project_id AND t.id=o.ticket_id
            LEFT JOIN delivery_goal_ticket_assignments a
              ON a.project_id=o.project_id AND a.phase_id=o.phase_id
             AND a.goal_id=o.goal_id AND a.ticket_id=o.ticket_id
            LEFT JOIN delivery_goal_obligation_drops d
              ON d.project_id=o.project_id AND d.phase_id=o.phase_id
             AND d.goal_id=o.goal_id AND d.ticket_id=o.ticket_id
            WHERE o.project_id=?
            ORDER BY o.phase_id,o.goal_id,o.ticket_id
            """,
            bindings: [.text(projectID.rawValue)],
            maximum: 10_000
        )
        let lineageRows = try connection.rows(
            """
            SELECT source_phase_id,source_goal_id,source_ticket_id,
                   descendant_phase_id,descendant_goal_id,descendant_ticket_id,reason
            FROM delivery_goal_obligation_lineage
            WHERE project_id=?
            ORDER BY source_phase_id,source_goal_id,source_ticket_id,
                     descendant_phase_id,descendant_goal_id,descendant_ticket_id
            """,
            bindings: [.text(projectID.rawValue)],
            maximum: 10_000
        )

        struct StoredNode {
            let scope: String
            let assessment: String
            let lane: String
            let isCurrent: Bool
            let dropReason: String?
        }
        func text(_ row: [String: SQLiteValue], _ name: String) throws -> String {
            guard case let .text(value)? = row[name] else {
                throw SQLiteError(code: 20, message: "Invalid goal-obligation coverage row")
            }
            return value
        }
        func optionalText(_ value: SQLiteValue?) -> String? {
            guard case let .text(text)? = value else { return nil }
            return text
        }
        func key(_ row: [String: SQLiteValue], prefix: String = "") throws -> DeliveryGoalObligationKey {
            .init(
                phaseID: .init(rawValue: try text(row, "\(prefix)phase_id")),
                goalID: .init(rawValue: try text(row, "\(prefix)goal_id")),
                ticketID: .init(rawValue: try text(row, "\(prefix)ticket_id"))
            )
        }

        var nodes: [DeliveryGoalObligationKey: StoredNode] = [:]
        for row in obligationRows {
            let obligationKey = try key(row)
            nodes[obligationKey] = .init(
                scope: try text(row, "scope"),
                assessment: try text(row, "assessment"),
                lane: try text(row, "lane"),
                isCurrent: row["is_current"] == .integer(1),
                dropReason: optionalText(row["drop_reason"])
            )
        }
        var descendants: [DeliveryGoalObligationKey: [DeliveryGoalObligationKey]] = [:]
        var carryReasons: [DeliveryGoalObligationKey: String] = [:]
        for row in lineageRows {
            let source = try key(row, prefix: "source_")
            let descendant = try key(row, prefix: "descendant_")
            descendants[source, default: []].append(descendant)
            carryReasons[source] = try text(row, "reason")
        }

        let roots = nodes.keys.filter { $0.phaseID == phaseID && $0.goalID == goalID }
        var included = Set(roots)
        var pending = roots
        while let next = pending.popLast() {
            for descendant in descendants[next] ?? [] where included.insert(descendant).inserted {
                pending.append(descendant)
            }
        }
        let orderedKeys = included.sorted {
            ($0.phaseID.rawValue, $0.goalID.rawValue, $0.ticketID.rawValue)
                < ($1.phaseID.rawValue, $1.goalID.rawValue, $1.ticketID.rawValue)
        }
        func state(for obligationKey: DeliveryGoalObligationKey) -> DeliveryGoalObligationCoverageState {
            guard let node = nodes[obligationKey] else { return .uncovered }
            if node.dropReason != nil { return .dropped }
            if !(descendants[obligationKey] ?? []).isEmpty { return .carried }
            if node.assessment == "unassessed" { return .unassessed }
            if node.lane == TicketLane.accepted.rawValue { return .delivered }
            if node.isCurrent { return .required }
            return .uncovered
        }
        func resolves(_ obligationKey: DeliveryGoalObligationKey, visiting: inout Set<DeliveryGoalObligationKey>) -> Bool {
            guard visiting.insert(obligationKey).inserted else { return false }
            defer { visiting.remove(obligationKey) }
            switch state(for: obligationKey) {
            case .delivered, .dropped:
                return true
            case .carried:
                let children = descendants[obligationKey] ?? []
                return !children.isEmpty && children.allSatisfy { resolves($0, visiting: &visiting) }
            case .required, .uncovered, .unassessed:
                return false
            }
        }

        let obligations = orderedKeys.compactMap { obligationKey -> DeliveryGoalObligationCoverage? in
            guard let node = nodes[obligationKey] else { return nil }
            return .init(
                key: obligationKey,
                scope: node.scope,
                state: state(for: obligationKey),
                reason: node.dropReason ?? carryReasons[obligationKey],
                descendants: descendants[obligationKey] ?? []
            )
        }
        let leafStates = obligations.filter { $0.descendants.isEmpty }.map(\.state)
        let deliveredLeafCount = leafStates.filter { $0 == .delivered }.count
        var visiting = Set<DeliveryGoalObligationKey>()
        let resolved = !roots.isEmpty && roots.allSatisfy { resolves($0, visiting: &visiting) }
        return .init(
            phaseID: phaseID,
            goalID: goalID,
            obligations: obligations,
            requiredLeafCount: leafStates.filter { $0 == .required || $0 == .delivered }.count,
            deliveredLeafCount: deliveredLeafCount,
            isResolved: resolved,
            hasDeliveredOutcome: deliveredLeafCount > 0
        )
    }
}

import Foundation

public enum AlertRuleKind: String, CaseIterable, Codable, Equatable, Sendable {
    case blockedLinkedGoals = "blocked_linked_goals"
    case agentCompletionAndReview = "agent_completion_and_review"
    case needsReviewEntry = "needs_review_entry"
    case pausedGoals = "paused_goals"
}

public struct AlertRuleSnapshot: Equatable, Sendable {
    private let values: [AlertRuleKind: Bool]

    init(values: [AlertRuleKind: Bool]) throws {
        guard values.count == AlertRuleKind.allCases.count,
              Set(values.keys) == Set(AlertRuleKind.allCases)
        else { throw AlertRuleStoreError.invalidSnapshot }
        self.values = values
    }

    public subscript(kind: AlertRuleKind) -> Bool {
        values[kind]!
    }

    static func load(from connection: SQLiteConnection) throws -> AlertRuleSnapshot {
        guard try connection.scalarInt("SELECT COUNT(*) FROM alert_rules") == Int64(AlertRuleKind.allCases.count)
        else { throw AlertRuleStoreError.invalidSnapshot }

        var values: [AlertRuleKind: Bool] = [:]
        for offset in 0..<AlertRuleKind.allCases.count {
            guard let row = try connection.row(
                "SELECT kind, is_enabled FROM alert_rules ORDER BY kind LIMIT 1 OFFSET ?",
                bindings: [.integer(Int64(offset))]
            ),
            case let .text(rawKind)? = row["kind"],
            let kind = AlertRuleKind(rawValue: rawKind),
            case let .integer(rawEnabled)? = row["is_enabled"],
            rawEnabled == 0 || rawEnabled == 1,
            values.updateValue(rawEnabled == 1, forKey: kind) == nil
            else { throw AlertRuleStoreError.invalidSnapshot }
        }
        return try AlertRuleSnapshot(values: values)
    }
}

public enum AlertRuleStoreError: Error, LocalizedError, Equatable, Sendable {
    case invalidSnapshot

    public var errorDescription: String? {
        "Alert rules are incomplete or malformed. Retry after restoring the local Release Radar database."
    }
}

public struct AlertRuleStore: Sendable {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func load() async throws -> AlertRuleSnapshot {
        try await store.read { connection in
            try AlertRuleSnapshot.load(from: connection)
        }
    }

    public func set(_ kind: AlertRuleKind, enabled: Bool) async throws -> AlertRuleSnapshot {
        do {
            return try await store.transact(
                actor: .init(id: "release-radar-owner"),
                reason: "Set global alert rule \(kind.rawValue) \(enabled ? "enabled" : "disabled")"
            ) { connection in
                let current = try AlertRuleSnapshot.load(from: connection)
                guard current[kind] != enabled else { throw AlertRuleNoChange() }
                try connection.execute(
                    "UPDATE alert_rules SET is_enabled = ? WHERE kind = ?",
                    bindings: [.integer(enabled ? 1 : 0), .text(kind.rawValue)]
                )
                return try AlertRuleSnapshot.load(from: connection)
            }
        } catch is AlertRuleNoChange {
            return try await load()
        }
    }
}

private struct AlertRuleNoChange: Error {}

import Foundation

public struct CodexPluginLifecycleStore: Sendable {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func load() async throws -> CodexPluginReceipt {
        try await store.read { connection in
            guard try connection.scalarInt("SELECT COUNT(*) FROM codex_plugin_lifecycle") == 1 else {
                throw CodexPluginLifecycleError.malformedResult
            }
            guard let row = try connection.row(
                "SELECT intent, managed_version, managed_digest, verified_at FROM codex_plugin_lifecycle WHERE plugin_id = 'release-radar'"
            ) else { throw CodexPluginLifecycleError.malformedResult }
            guard case let .text(intentRaw) = row["intent"],
                  let intent = CodexPluginIntent(rawValue: intentRaw)
            else { throw CodexPluginLifecycleError.malformedResult }
            let version: String?
            let digest: String?
            let verifiedAt: Date?
            switch (row["managed_version"], row["managed_digest"], row["verified_at"]) {
            case (.some(.null), .some(.null), .some(.null)):
                version = nil
                digest = nil
                verifiedAt = nil
            case let (.some(.text(storedVersion)), .some(.text(storedDigest)), .some(.text(storedDate))):
                guard let date = ISO8601DateFormatter().date(from: storedDate) else {
                    throw CodexPluginLifecycleError.malformedResult
                }
                version = storedVersion
                digest = storedDigest
                verifiedAt = date
            default:
                throw CodexPluginLifecycleError.malformedResult
            }
            return CodexPluginReceipt(
                intent: intent,
                managedVersion: version,
                managedDigest: digest,
                verifiedAt: verifiedAt
            )
        }
    }

    public func recordVerified(_ receipt: CodexPluginReceipt, reason: String) async throws {
        try await store.transact(actor: .init(id: "release-radar-owner"), reason: reason) { connection in
            try Self.update(receipt, connection: connection)
        }
    }

    public func recordObservation(_ receipt: CodexPluginReceipt, reason: String) async throws {
        let current = try await load()
        guard current.intent != receipt.intent else { return }
        try await store.transact(actor: .init(id: "release-radar-observer"), reason: reason) { connection in
            try Self.update(receipt, connection: connection)
        }
    }

    private static func update(_ receipt: CodexPluginReceipt, connection: SQLiteConnection) throws {
        try connection.execute(
            "UPDATE codex_plugin_lifecycle SET intent = ?, managed_version = ?, managed_digest = ?, verified_at = ? WHERE plugin_id = 'release-radar'",
            bindings: [
                .text(receipt.intent.rawValue),
                receipt.managedVersion.map(SQLiteValue.text) ?? .null,
                receipt.managedDigest.map(SQLiteValue.text) ?? .null,
                receipt.verifiedAt.map { .text(ISO8601DateFormatter().string(from: $0)) } ?? .null,
            ]
        )
        guard try connection.scalarInt("SELECT changes()") == 1 else {
            throw CodexPluginLifecycleError.malformedResult
        }
    }
}

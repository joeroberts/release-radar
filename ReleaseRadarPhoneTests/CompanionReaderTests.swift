import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarPhone

@MainActor
final class CompanionReaderTests: XCTestCase {
    func testCompatibleSearchIncludesKnownActiveAndArchivedItemsOnly() throws {
        let cacheURL = try makeCacheURL()
        let store = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: "account-A")
        let active = item(id: "ticket-A", classID: "deliveryGraph", payload: ["id": "ticket-A", "kind": "ticket", "phaseID": "phase-A", "lane": "work"])
        let archived = item(id: "history-A", classID: "historyMetadata", lifecycle: .archived, payload: ["id": "history-A", "kind": "history", "entityType": "ticket", "createdAt": "2026-10-19T12:00:00Z"])
        let unknown = item(id: "unknown-A", classID: "future", payload: ["id": "unknown-A", "kind": "future"])

        try store.receive(
            publication(items: [active, archived, unknown], controlSequence: 1),
            accountID: "account-A",
            receivedAt: date(30)
        )

        store.searchText = "ticket"
        XCTAssertEqual(store.searchResults.map { $0.identity.itemID }, ["ticket-A", "history-A"])
        XCTAssertFalse(store.snapshot.items.contains(where: { $0.identity.itemID == "unknown-A" }))
        XCTAssertFalse(store.snapshot.notices.isEmpty)
    }

    func testUpdateRequiredReplacementStillPrunesWithdrawnIncarnationAndItsDerivedItem() throws {
        let cacheURL = try makeCacheURL()
        let store = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: "account-A")
        let withdrawnIncarnation = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let ticketA = item(id: "ticket-A", incarnation: withdrawnIncarnation, classID: "deliveryGraph", payload: ["id": "ticket-A", "kind": "ticket"])
        let previewA = item(
            id: "preview-A",
            classID: "reviewMetadata",
            payload: ["id": "preview-A", "kind": "review", "reviewKind": "preview", "status": "open"],
            derivedFrom: [.init(identity: ticketA.identity, relationship: "derived")]
        )
        let ticketB = item(id: "ticket-B", classID: "deliveryGraph", payload: ["id": "ticket-B", "kind": "ticket"])
        try store.receive(
            publication(items: [ticketA, previewA, ticketB], controlSequence: 1),
            accountID: "account-A",
            receivedAt: date(10)
        )

        try store.receive(
            publication(
                items: [ticketA, previewA, ticketB],
                controlSequence: 2,
                schemaVersion: CompanionManifest.currentSchemaVersion + 1,
                withdrawals: [.init(registrationID: "registration-A", itemID: "ticket-A", publicationIncarnationID: withdrawnIncarnation)]
            ),
            accountID: "account-A",
            receivedAt: date(20)
        )

        XCTAssertEqual(store.snapshot.items.map { $0.identity.itemID }, ["ticket-B"])
        XCTAssertEqual(store.snapshot.deviceReceivedAt, date(10), "An incompatible replacement must not refresh the cached receipt.")
    }

    func testExactEquivalentControlIsIdempotentButChangedEqualSequenceAndEpochChangeAreRejected() throws {
        let cacheURL = try makeCacheURL()
        let store = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: "account-A")
        let ticket = item(id: "ticket-A", classID: "deliveryGraph", payload: ["id": "ticket-A", "kind": "ticket"])
        let first = publication(items: [ticket], controlSequence: 1)
        try store.receive(first, accountID: "account-A", receivedAt: date(10))
        try store.receive(first, accountID: "account-A", receivedAt: date(20))
        XCTAssertEqual(store.snapshot.deviceReceivedAt, date(10))

        XCTAssertThrowsError(try store.receive(
            publication(items: [ticket], controlSequence: 1, withdrawals: [.init(registrationID: "registration-A", itemID: "ticket-A", publicationIncarnationID: ticket.identity.publicationIncarnationID)]),
            accountID: "account-A",
            receivedAt: date(30)
        ))
        XCTAssertThrowsError(try store.receive(
            publication(items: [ticket], controlSequence: 2, epoch: "epoch-B"),
            accountID: "account-A",
            receivedAt: date(40)
        ))
    }

    func testOfflineRelaunchRetainsBoundCacheWithoutClaimingCurrentAccountOrRenewingFreshness() throws {
        let cacheURL = try makeCacheURL()
        let ticket = item(id: "ticket-A", classID: "deliveryGraph", payload: ["id": "ticket-A", "kind": "ticket"])
        let store = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: "account-A")
        try store.receive(
            publication(items: [ticket], controlSequence: 1, sourceOccurredAt: date(1), publishedAt: date(2)),
            accountID: "account-A",
            receivedAt: date(3)
        )
        try store.recordCheck(at: date(4))

        let offline = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: nil)
        XCTAssertEqual(offline.snapshot.items.map { $0.identity.itemID }, ["ticket-A"])
        XCTAssertEqual(offline.snapshot.sourceOccurredAt, date(1))
        XCTAssertEqual(offline.snapshot.publishedAt, date(2))
        XCTAssertEqual(offline.snapshot.deviceReceivedAt, date(3))
        XCTAssertEqual(offline.snapshot.lastCheckedAt, date(4))
        XCTAssertTrue(offline.snapshot.isCached)
        XCTAssertEqual(offline.snapshot.accountState, .unknownOffline)
        XCTAssertEqual(offline.snapshot.sourceState, .unavailable)
    }

    func testCorruptPersistedCacheIsDiscardedWithAnExplicitNotice() throws {
        let cacheURL = try makeCacheURL()
        let store = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: "account-A")
        let ticket = item(id: "ticket-A", classID: "deliveryGraph", payload: ["id": "ticket-A", "kind": "ticket"])
        try store.receive(
            publication(items: [ticket], controlSequence: 1),
            accountID: "account-A",
            receivedAt: date(3)
        )
        try Data("tampered cache".utf8).write(to: cacheURL)

        let reloaded = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: "account-A")
        XCTAssertTrue(reloaded.snapshot.items.isEmpty)
        XCTAssertNil(reloaded.snapshot.registrationID)
        XCTAssertTrue(reloaded.snapshot.notices.contains { $0.kind == .malformed })
        XCTAssertEqual(reloaded.snapshot.sourceState, .unavailable)
    }

    func testAccountSwitchClearsOldBoundCacheAndMalformedOrExcludedContentNeverBecomesSearchable() throws {
        let cacheURL = try makeCacheURL()
        let store = CompanionReaderStore(cacheURL: cacheURL, currentAccountID: "account-A")
        let malformed = item(id: "ticket-malformed", classID: "deliveryGraph", payload: ["id": "ticket-malformed", "kind": "ticket", "phaseID": 1])
        let excluded = item(id: "evidence-A", classID: "evidence", payload: ["id": "evidence-A", "kind": "ticket"])
        try store.receive(
            publication(
                items: [malformed, excluded],
                controlSequence: 1,
                coverage: [
                    .init(classID: "deliveryGraph", coverage: .init(status: .complete, itemCount: 1, reason: nil)),
                    .init(classID: "evidence", coverage: .init(status: .excluded, itemCount: nil, reason: .init(rawValue: "excluded-sensitive-class")))
                ]
            ),
            accountID: "account-A",
            receivedAt: date(10)
        )

        store.searchText = "ticket"
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertTrue(store.snapshot.items.isEmpty)
        XCTAssertFalse(store.snapshot.notices.isEmpty)

        try store.switchAccount(to: "account-B")
        XCTAssertTrue(store.snapshot.items.isEmpty)
        XCTAssertNil(store.snapshot.registrationID)
    }
}

private extension CompanionReaderTests {
    func makeCacheURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompanionReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("reader-cache.json")
    }

    func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    func item(
        id: String,
        incarnation: UUID = UUID(),
        classID: String,
        lifecycle: CompanionItemLifecycle = .active,
        payload: [String: Any],
        derivedFrom: [CompanionItemVersionReference] = []
    ) -> CompanionItem {
        let payloadData = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let digest = SHA256.hash(data: payloadData).map { String(format: "%02x", $0) }.joined()
        return CompanionItem(
            identity: .init(itemID: id, publicationIncarnationID: incarnation, versionID: "v1"),
            classID: classID,
            lifecycle: lifecycle,
            provenance: .init(sourceIdentity: id, sourceOccurredAt: date(1), publishedAt: date(2), contentSHA256: digest),
            derivedFrom: derivedFrom,
            payload: payloadData
        )
    }

    func publication(
        items: [CompanionItem],
        controlSequence: Int64,
        epoch: String = "epoch-A",
        schemaVersion: Int = CompanionManifest.currentSchemaVersion,
        withdrawals: [CompanionWithdrawal] = [],
        coverage: [CompanionClassInventory]? = nil,
        sourceOccurredAt: Date? = nil,
        publishedAt: Date? = nil
    ) -> ReadOnlyCompanionPublication {
        let inventory = items.map {
            CompanionManifestEntry(identity: $0.identity, contentSHA256: $0.provenance.contentSHA256, byteCount: $0.payload.count)
        }
        return ReadOnlyCompanionPublication(
            manifest: .init(
                registrationID: "registration-A",
                publisherEpoch: epoch,
                controlSequence: controlSequence,
                schemaVersion: schemaVersion,
                minimumReaderVersion: CompanionManifest.minimumReaderVersionForCurrentSchema,
                activation: .active,
                inventory: inventory,
                sourceOccurredAt: sourceOccurredAt,
                publishedAt: publishedAt
            ),
            classInventories: coverage ?? [.init(classID: "deliveryGraph", coverage: .init(status: .complete, itemCount: items.count, reason: nil))],
            items: items,
            control: .init(registrationID: "registration-A", publisherEpoch: epoch, controlSequence: controlSequence, withdrawals: withdrawals)
        )
    }
}

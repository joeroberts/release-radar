import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ReadOnlyCompanionPublicationTests: XCTestCase {
    func testActiveManifestRequiresExactInventoryWhilePendingManifestStaysInactive() throws {
        let payload = Data("safe record".utf8)
        let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let identity = CompanionItemIdentity(
            itemID: "item-A",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            versionID: "v1"
        )
        let item = CompanionItem(
            identity: identity,
            classID: "ticket",
            lifecycle: .active,
            provenance: .init(
                sourceIdentity: "ticket-A",
                sourceOccurredAt: Date(timeIntervalSince1970: 1),
                publishedAt: Date(timeIntervalSince1970: 2),
                contentSHA256: digest
            ),
            derivedFrom: [],
            payload: payload
        )
        let manifest = CompanionManifest(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 1,
            schemaVersion: 1,
            minimumReaderVersion: 1,
            activation: .active,
            inventory: [.init(identity: identity, contentSHA256: digest, byteCount: payload.count)],
            sourceOccurredAt: Date(timeIntervalSince1970: 1),
            publishedAt: Date(timeIntervalSince1970: 2)
        )
        XCTAssertNoThrow(try manifest.validate(items: [item]))
        XCTAssertThrowsError(try manifest.validate(items: []))

        let pending = CompanionManifest(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 2,
            schemaVersion: 1,
            minimumReaderVersion: 1,
            activation: .pending,
            inventory: [.init(identity: identity, contentSHA256: digest, byteCount: payload.count)],
            sourceOccurredAt: Date(timeIntervalSince1970: 3),
            publishedAt: Date(timeIntervalSince1970: 4)
        )
        XCTAssertNoThrow(try pending.validate(items: []))
    }

    func testActiveManifestRejectsSameLengthPayloadTamperingWithStaleDigestMetadata() throws {
        let original = Data("safe record".utf8)
        let tampered = Data("evil record".utf8)
        XCTAssertEqual(original.count, tampered.count)
        let digest = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        let identity = CompanionItemIdentity(
            itemID: "item-A",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            versionID: "v1"
        )
        let item = CompanionItem(
            identity: identity,
            classID: "ticket",
            lifecycle: .active,
            provenance: .init(
                sourceIdentity: "ticket-A",
                sourceOccurredAt: nil,
                publishedAt: nil,
                contentSHA256: digest
            ),
            derivedFrom: [],
            payload: tampered
        )
        let manifest = CompanionManifest(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 1,
            schemaVersion: 1,
            minimumReaderVersion: 1,
            activation: .active,
            inventory: [.init(identity: identity, contentSHA256: digest, byteCount: original.count)],
            sourceOccurredAt: nil,
            publishedAt: nil
        )

        XCTAssertThrowsError(try manifest.validate(items: [item])) {
            XCTAssertEqual($0 as? CompanionPublicationValidationError, .inventoryMismatch)
        }
    }

    func testClassCoverageKeepsCompleteEmptyAndSafeNonpublicationReasonsDistinct() throws {
        let complete = CompanionClassCoverage(status: .complete, itemCount: 1, reason: nil)
        let empty = CompanionClassCoverage(status: .empty, itemCount: 0, reason: nil)
        let unavailable = CompanionClassCoverage(
            status: .unavailable,
            itemCount: nil,
            reason: .init(rawValue: "account-unavailable")
        )
        let excluded = CompanionClassCoverage(
            status: .excluded,
            itemCount: nil,
            reason: .init(rawValue: "excluded-by-project-selection")
        )
        let unsupported = CompanionClassCoverage(
            status: .unsupported,
            itemCount: nil,
            reason: .init(rawValue: "reader-update-required")
        )

        XCTAssertNoThrow(try complete.validate())
        XCTAssertNoThrow(try empty.validate())
        XCTAssertNoThrow(try unavailable.validate())
        XCTAssertNoThrow(try excluded.validate())
        XCTAssertNoThrow(try unsupported.validate())
        XCTAssertThrowsError(try CompanionClassCoverage(status: .excluded, itemCount: nil, reason: nil).validate())
    }

    func testWithdrawalEligibilityDeniesItsIncarnationAndDependentItems() {
        let incarnation = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let aV1Identity = CompanionItemIdentity(itemID: "item-A", publicationIncarnationID: incarnation, versionID: "v1")
        let aV2Identity = CompanionItemIdentity(itemID: "item-A", publicationIncarnationID: incarnation, versionID: "v2")
        let derivedIdentity = CompanionItemIdentity(
            itemID: "preview-A",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
            versionID: "v1"
        )
        let bIdentity = CompanionItemIdentity(
            itemID: "item-B",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
            versionID: "v1"
        )
        let missingIdentity = CompanionItemIdentity(
            itemID: "missing",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
            versionID: "v1"
        )
        let removedIdentity = CompanionItemIdentity(
            itemID: "removed",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!,
            versionID: "v1"
        )
        let unknownIdentity = CompanionItemIdentity(
            itemID: "unknown-derived",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!,
            versionID: "v1"
        )
        let cyclicIdentity = CompanionItemIdentity(
            itemID: "cyclic-derived",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!,
            versionID: "v1"
        )
        let provenance = CompanionItemProvenance(
            sourceIdentity: "safe-source",
            sourceOccurredAt: nil,
            publishedAt: nil,
            contentSHA256: String(repeating: "a", count: 64)
        )
        let aV1 = CompanionItem(
            identity: aV1Identity,
            classID: "ticket",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [],
            payload: Data("A v1".utf8)
        )
        let aV2 = CompanionItem(
            identity: aV2Identity,
            classID: "ticket",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [],
            payload: Data("A v2".utf8)
        )
        let derived = CompanionItem(
            identity: derivedIdentity,
            classID: "preview",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [.init(identity: aV1Identity, relationship: "preview")],
            payload: Data("A preview".utf8)
        )
        let b = CompanionItem(
            identity: bIdentity,
            classID: "ticket",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [],
            payload: Data("B".utf8)
        )
        let removed = CompanionItem(
            identity: removedIdentity,
            classID: "ticket",
            lifecycle: .removed,
            provenance: provenance,
            derivedFrom: [],
            payload: Data("removed".utf8)
        )
        let unknown = CompanionItem(
            identity: unknownIdentity,
            classID: "preview",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [.init(identity: missingIdentity, relationship: "unknown")],
            payload: Data("unknown".utf8)
        )
        let cyclic = CompanionItem(
            identity: cyclicIdentity,
            classID: "preview",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [.init(identity: cyclicIdentity, relationship: "cycle")],
            payload: Data("cycle".utf8)
        )
        let control = CompanionControl(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 1,
            withdrawals: [.init(registrationID: "registration-A", itemID: "item-A", publicationIncarnationID: incarnation)]
        )
        let items = [aV1, aV2, derived, b, removed, unknown, cyclic]

        XCTAssertFalse(control.isEligible(aV1, among: items))
        XCTAssertFalse(control.isEligible(aV2, among: items))
        XCTAssertFalse(control.isEligible(derived, among: items))
        XCTAssertTrue(control.isEligible(b, among: items))
        XCTAssertFalse(control.isEligible(removed, among: items))
        XCTAssertFalse(control.isEligible(unknown, among: items))
        XCTAssertFalse(control.isEligible(cyclic, among: items))
    }

    func testEligibilityRejectsSuppliedValueThatDiffersFromItsInventoriedIdentity() {
        let identity = CompanionItemIdentity(
            itemID: "item-B",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
            versionID: "v1"
        )
        let provenance = CompanionItemProvenance(
            sourceIdentity: "safe-source",
            sourceOccurredAt: nil,
            publishedAt: nil,
            contentSHA256: String(repeating: "b", count: 64)
        )
        let inventoried = CompanionItem(
            identity: identity,
            classID: "ticket",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [],
            payload: Data("stored bytes".utf8)
        )
        let supplied = CompanionItem(
            identity: identity,
            classID: "ticket",
            lifecycle: .removed,
            provenance: provenance,
            derivedFrom: [.init(identity: identity, relationship: "altered")],
            payload: Data("alteredbytes".utf8)
        )
        let control = CompanionControl(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 1,
            withdrawals: []
        )

        XCTAssertFalse(control.isEligible(supplied, among: [inventoried]))
    }

    func testEligibilityHandlesSharedDependenciesAndADeepChain() {
        let provenance = CompanionItemProvenance(
            sourceIdentity: "safe-source",
            sourceOccurredAt: nil,
            publishedAt: nil,
            contentSHA256: String(repeating: "c", count: 64)
        )
        let incarnation = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!
        let sourceIdentity = CompanionItemIdentity(itemID: "source", publicationIncarnationID: incarnation, versionID: "v1")
        let leftIdentity = CompanionItemIdentity(itemID: "left", publicationIncarnationID: incarnation, versionID: "v1")
        let rightIdentity = CompanionItemIdentity(itemID: "right", publicationIncarnationID: incarnation, versionID: "v1")
        let rootIdentity = CompanionItemIdentity(itemID: "root", publicationIncarnationID: incarnation, versionID: "v1")
        let source = CompanionItem(identity: sourceIdentity, classID: "ticket", lifecycle: .active, provenance: provenance, derivedFrom: [], payload: Data("source".utf8))
        let left = CompanionItem(identity: leftIdentity, classID: "preview", lifecycle: .active, provenance: provenance, derivedFrom: [.init(identity: sourceIdentity, relationship: "summary")], payload: Data("left".utf8))
        let right = CompanionItem(identity: rightIdentity, classID: "preview", lifecycle: .active, provenance: provenance, derivedFrom: [.init(identity: sourceIdentity, relationship: "summary")], payload: Data("right".utf8))
        let root = CompanionItem(
            identity: rootIdentity,
            classID: "preview",
            lifecycle: .active,
            provenance: provenance,
            derivedFrom: [
                .init(identity: leftIdentity, relationship: "summary"),
                .init(identity: rightIdentity, relationship: "summary"),
            ],
            payload: Data("root".utf8)
        )
        var chain: [CompanionItem] = []
        for index in stride(from: 128, through: 0, by: -1) {
            let identity = CompanionItemIdentity(itemID: "chain-\(index)", publicationIncarnationID: incarnation, versionID: "v1")
            let dependencies: [CompanionItemVersionReference] = index == 128
                ? []
                : [.init(
                    identity: CompanionItemIdentity(itemID: "chain-\(index + 1)", publicationIncarnationID: incarnation, versionID: "v1"),
                    relationship: "summary"
                )]
            chain.append(
                CompanionItem(
                    identity: identity,
                    classID: "preview",
                    lifecycle: .active,
                    provenance: provenance,
                    derivedFrom: dependencies,
                    payload: Data("chain-\(index)".utf8)
                )
            )
        }
        let control = CompanionControl(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 1,
            withdrawals: []
        )

        XCTAssertTrue(control.isEligible(root, among: [source, left, right, root]))
        XCTAssertTrue(control.isEligible(chain.last!, among: chain))
    }

    func testControlRetainsPriorIncarnationWithdrawalAndRejectsUnsafeReconciliation() throws {
        let withdrawal = CompanionWithdrawal(
            registrationID: "registration-A",
            itemID: "item-A",
            publicationIncarnationID: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        )
        let previous = CompanionControl(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 5,
            withdrawals: [withdrawal]
        )
        let retained = CompanionControl(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 6,
            withdrawals: [withdrawal]
        )
        let omitted = CompanionControl(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 6,
            withdrawals: []
        )
        let otherEpoch = CompanionControl(
            registrationID: "registration-A",
            publisherEpoch: "epoch-B",
            controlSequence: 6,
            withdrawals: [withdrawal]
        )

        XCTAssertNoThrow(try retained.validate(previous: previous))
        XCTAssertThrowsError(try omitted.validate(previous: previous)) {
            XCTAssertEqual($0 as? CompanionPublicationValidationError, .withdrawalOmitted)
        }
        XCTAssertThrowsError(try otherEpoch.validate(previous: previous)) {
            XCTAssertEqual($0 as? CompanionPublicationValidationError, .epochReconciliationRequired)
        }
    }

    func testCurrentManifestSchemaIsCompatibleWithCurrentReader() throws {
        XCTAssertEqual(CompanionManifest.currentSchemaVersion, 1)
        XCTAssertEqual(CompanionManifest.minimumReaderVersionForCurrentSchema, 1)
        XCTAssertEqual(CompanionManifest.currentReaderVersion, 1)
        let manifest = CompanionManifest(
            registrationID: "registration-A",
            publisherEpoch: "epoch-A",
            controlSequence: 1,
            schemaVersion: CompanionManifest.currentSchemaVersion,
            minimumReaderVersion: CompanionManifest.minimumReaderVersionForCurrentSchema,
            activation: .pending,
            inventory: [],
            sourceOccurredAt: nil,
            publishedAt: nil
        )
        XCTAssertNoThrow(try manifest.requireCompatible())
        XCTAssertNoThrow(try manifest.requireCompatible(readerVersion: CompanionManifest.currentReaderVersion))
    }

    func testManifestCompatibilityRejectsInvalidAndFutureVersions() throws {
        for (schemaVersion, minimumReaderVersion, readerVersion) in [(0, 1, 1), (1, 0, 1), (1, 1, 0)] {
            let manifest = CompanionManifest(
                registrationID: "registration-A", publisherEpoch: "epoch-A", controlSequence: 1,
                schemaVersion: schemaVersion, minimumReaderVersion: minimumReaderVersion,
                activation: .pending, inventory: [], sourceOccurredAt: nil, publishedAt: nil
            )
            XCTAssertThrowsError(try manifest.requireCompatible(readerVersion: readerVersion)) {
                XCTAssertEqual($0 as? CompanionManifestCompatibilityError, .invalidVersion)
            }
        }
        for (schemaVersion, minimumReaderVersion) in [(1, 2), (2, 1)] {
            let manifest = CompanionManifest(
                registrationID: "registration-A", publisherEpoch: "epoch-A", controlSequence: 1,
                schemaVersion: schemaVersion, minimumReaderVersion: minimumReaderVersion,
                activation: .pending, inventory: [], sourceOccurredAt: nil, publishedAt: nil
            )
            XCTAssertThrowsError(try manifest.requireCompatible(readerVersion: 1)) {
                XCTAssertEqual($0 as? CompanionManifestCompatibilityError, .updateRequired)
            }
        }
    }
}

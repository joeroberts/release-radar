import CryptoKit
import Foundation

/// The portable, read-only representation of one complete companion publication.
public struct ReadOnlyCompanionPublication: Codable, Equatable, Sendable {
    public let manifest: CompanionManifest
    public let classInventories: [CompanionClassInventory]
    public let items: [CompanionItem]
    public let control: CompanionControl

    public init(
        manifest: CompanionManifest,
        classInventories: [CompanionClassInventory],
        items: [CompanionItem],
        control: CompanionControl
    ) {
        self.manifest = manifest
        self.classInventories = classInventories
        self.items = items
        self.control = control
    }
}

public struct CompanionManifest: Codable, Equatable, Sendable {
    public let registrationID: String
    public let publisherEpoch: String
    public let controlSequence: Int64
    public let schemaVersion: Int
    public let minimumReaderVersion: Int
    public let activation: CompanionManifestActivation
    public let inventory: [CompanionManifestEntry]
    public let sourceOccurredAt: Date?
    public let publishedAt: Date?

    public init(
        registrationID: String,
        publisherEpoch: String,
        controlSequence: Int64,
        schemaVersion: Int,
        minimumReaderVersion: Int,
        activation: CompanionManifestActivation,
        inventory: [CompanionManifestEntry],
        sourceOccurredAt: Date?,
        publishedAt: Date?
    ) {
        self.registrationID = registrationID
        self.publisherEpoch = publisherEpoch
        self.controlSequence = controlSequence
        self.schemaVersion = schemaVersion
        self.minimumReaderVersion = minimumReaderVersion
        self.activation = activation
        self.inventory = inventory
        self.sourceOccurredAt = sourceOccurredAt
        self.publishedAt = publishedAt
    }

    /// A pending manifest is deliberately not an active publication. An active
    /// manifest must describe exactly the published item identities and bytes.
    public func validate(items: [CompanionItem]) throws {
        guard activation == .active else { return }

        var entries: [CompanionItemIdentity: CompanionManifestEntry] = [:]
        for entry in inventory {
            guard entries.updateValue(entry, forKey: entry.identity) == nil else {
                throw CompanionPublicationValidationError.inventoryMismatch
            }
        }
        guard Set(items.map(\.identity)).count == items.count, entries.count == items.count else {
            throw CompanionPublicationValidationError.inventoryMismatch
        }

        for item in items {
            let payloadDigest = SHA256.hash(data: item.payload).map { String(format: "%02x", $0) }.joined()
            guard let entry = entries[item.identity],
                  entry.contentSHA256 == item.provenance.contentSHA256,
                  entry.contentSHA256 == payloadDigest,
                  entry.byteCount == item.payload.count else {
                throw CompanionPublicationValidationError.inventoryMismatch
            }
        }
    }
}

public enum CompanionManifestActivation: String, Codable, Equatable, Sendable {
    case pending
    case active
}

public struct CompanionManifestEntry: Codable, Equatable, Hashable, Sendable {
    public let identity: CompanionItemIdentity
    public let contentSHA256: String
    public let byteCount: Int

    public init(identity: CompanionItemIdentity, contentSHA256: String, byteCount: Int) {
        self.identity = identity
        self.contentSHA256 = contentSHA256
        self.byteCount = byteCount
    }
}

public struct CompanionClassInventory: Codable, Equatable, Sendable {
    public let classID: String
    public let coverage: CompanionClassCoverage

    public init(classID: String, coverage: CompanionClassCoverage) {
        self.classID = classID
        self.coverage = coverage
    }
}

public struct CompanionClassCoverage: Codable, Equatable, Sendable {
    public let status: CompanionClassCoverageStatus
    public let itemCount: Int?
    public let reason: CompanionSafeReason?

    public init(status: CompanionClassCoverageStatus, itemCount: Int?, reason: CompanionSafeReason?) {
        self.status = status
        self.itemCount = itemCount
        self.reason = reason
    }

    public func validate() throws {
        switch status {
        case .complete:
            guard let itemCount, itemCount >= 0, reason == nil else {
                throw CompanionPublicationValidationError.invalidClassCoverage
            }
        case .empty:
            guard itemCount == 0, reason == nil else {
                throw CompanionPublicationValidationError.invalidClassCoverage
            }
        case .unavailable, .excluded, .unsupported:
            guard itemCount == nil, let reason, !reason.rawValue.isEmpty else {
                throw CompanionPublicationValidationError.invalidClassCoverage
            }
        }
    }
}

public enum CompanionClassCoverageStatus: String, Codable, Equatable, Sendable {
    case complete
    case empty
    case unavailable
    case excluded
    case unsupported
}

public struct CompanionSafeReason: Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct CompanionItem: Codable, Equatable, Sendable {
    public let identity: CompanionItemIdentity
    public let classID: String
    public let lifecycle: CompanionItemLifecycle
    public let provenance: CompanionItemProvenance
    public let derivedFrom: [CompanionItemVersionReference]
    public let payload: Data

    public init(
        identity: CompanionItemIdentity,
        classID: String,
        lifecycle: CompanionItemLifecycle,
        provenance: CompanionItemProvenance,
        derivedFrom: [CompanionItemVersionReference],
        payload: Data
    ) {
        self.identity = identity
        self.classID = classID
        self.lifecycle = lifecycle
        self.provenance = provenance
        self.derivedFrom = derivedFrom
        self.payload = payload
    }
}

public struct CompanionItemIdentity: Codable, Equatable, Hashable, Sendable {
    public let itemID: String
    public let publicationIncarnationID: UUID
    public let versionID: String

    public init(itemID: String, publicationIncarnationID: UUID, versionID: String) {
        self.itemID = itemID
        self.publicationIncarnationID = publicationIncarnationID
        self.versionID = versionID
    }
}

public enum CompanionItemLifecycle: String, Codable, Equatable, Sendable {
    case active
    case archived
    case removed
}

public struct CompanionItemProvenance: Codable, Equatable, Sendable {
    public let sourceIdentity: String
    public let sourceOccurredAt: Date?
    public let publishedAt: Date?
    public let contentSHA256: String

    public init(sourceIdentity: String, sourceOccurredAt: Date?, publishedAt: Date?, contentSHA256: String) {
        self.sourceIdentity = sourceIdentity
        self.sourceOccurredAt = sourceOccurredAt
        self.publishedAt = publishedAt
        self.contentSHA256 = contentSHA256
    }
}

public struct CompanionItemVersionReference: Codable, Equatable, Hashable, Sendable {
    public let identity: CompanionItemIdentity
    public let relationship: String

    public init(identity: CompanionItemIdentity, relationship: String) {
        self.identity = identity
        self.relationship = relationship
    }
}

public struct CompanionControl: Codable, Equatable, Sendable {
    public let registrationID: String
    public let publisherEpoch: String
    public let controlSequence: Int64
    /// Complete set of denied item incarnations for this registration.
    public let withdrawals: [CompanionWithdrawal]

    public init(
        registrationID: String,
        publisherEpoch: String,
        controlSequence: Int64,
        withdrawals: [CompanionWithdrawal]
    ) {
        self.registrationID = registrationID
        self.publisherEpoch = publisherEpoch
        self.controlSequence = controlSequence
        self.withdrawals = withdrawals
    }

    /// A newer control cannot silently restore a previously denied incarnation.
    public func validate(previous: CompanionControl?) throws {
        guard Set(withdrawals).count == withdrawals.count,
              withdrawals.allSatisfy({ $0.registrationID == registrationID }) else {
            throw CompanionPublicationValidationError.duplicateWithdrawal
        }
        guard let previous else { return }
        guard registrationID == previous.registrationID else {
            throw CompanionPublicationValidationError.registrationMismatch
        }
        guard publisherEpoch == previous.publisherEpoch else {
            throw CompanionPublicationValidationError.epochReconciliationRequired
        }
        guard controlSequence > previous.controlSequence else {
            throw CompanionPublicationValidationError.nonIncreasingControlSequence
        }
        guard Set(previous.withdrawals).isSubset(of: Set(withdrawals)) else {
            throw CompanionPublicationValidationError.withdrawalOmitted
        }
    }

    /// Determines whether an item can be exposed by this control snapshot.
    /// Missing or cyclic dependency information is denied rather than exposed.
    public func isEligible(_ item: CompanionItem, among items: [CompanionItem]) -> Bool {
        var itemsByIdentity: [CompanionItemIdentity: CompanionItem] = [:]
        for candidate in items {
            guard itemsByIdentity.updateValue(candidate, forKey: candidate.identity) == nil else {
                return false
            }
        }
        guard itemsByIdentity[item.identity] == item else { return false }

        enum Traversal {
            case visit(CompanionItemIdentity)
            case finish(CompanionItemIdentity)
        }

        var outcomes: [CompanionItemIdentity: Bool] = [:]
        var visiting: Set<CompanionItemIdentity> = []
        var work: [Traversal] = [.visit(item.identity)]
        while let next = work.popLast() {
            switch next {
            case let .visit(identity):
                if outcomes[identity] != nil { continue }
                guard let candidate = itemsByIdentity[identity],
                      candidate.lifecycle != .removed,
                      !withdrawals.contains(where: {
                          $0.registrationID == registrationID
                              && $0.itemID == identity.itemID
                              && $0.publicationIncarnationID == identity.publicationIncarnationID
                      }) else {
                    outcomes[identity] = false
                    continue
                }
                guard visiting.insert(identity).inserted else {
                    outcomes[identity] = false
                    continue
                }
                work.append(.finish(identity))
                work.append(contentsOf: candidate.derivedFrom.map { .visit($0.identity) })
            case let .finish(identity):
                guard let candidate = itemsByIdentity[identity] else {
                    outcomes[identity] = false
                    continue
                }
                outcomes[identity] = candidate.derivedFrom.allSatisfy { outcomes[$0.identity] == true }
                visiting.remove(identity)
            }
        }

        return outcomes[item.identity] == true
    }
}

public struct CompanionWithdrawal: Codable, Equatable, Hashable, Sendable {
    public let registrationID: String
    public let itemID: String
    public let publicationIncarnationID: UUID

    public init(registrationID: String, itemID: String, publicationIncarnationID: UUID) {
        self.registrationID = registrationID
        self.itemID = itemID
        self.publicationIncarnationID = publicationIncarnationID
    }
}

public enum CompanionPublicationValidationError: Error, Equatable, Sendable {
    case inventoryMismatch
    case invalidClassCoverage
    case duplicateWithdrawal
    case registrationMismatch
    case epochReconciliationRequired
    case nonIncreasingControlSequence
    case withdrawalOmitted
}

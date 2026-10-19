import Combine
import CryptoKit
import Foundation

enum CompanionReaderPersistenceOperation: Equatable, Sendable {
    case writeDenial
    case writeCache
    case protectCache
    case removeCache
}

enum CompanionReaderAccountState: Equatable, Sendable {
    case none
    case bound
    case unknownOffline
}

enum CompanionReaderSourceState: Equatable, Sendable {
    case cached
    case unavailable
    case updateRequired(reason: String)
}

struct CompanionReaderNotice: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case excluded
        case malformed
        case unavailable
        case unsupported
        case updateRequired
    }

    let kind: Kind
    let title: String
    let message: String

    var id: String { "\(kind.rawValue):\(title):\(message)" }
}

enum CompanionReaderCoverageStatus: Equatable, Sendable {
    case complete
    case empty
    case partial
    case unavailable
    case excluded
    case unsupported
}

struct CompanionReaderClassCoverage: Equatable, Identifiable, Sendable {
    let classID: String
    let status: CompanionReaderCoverageStatus
    let itemCount: Int?
    let availableItemCount: Int
    let reason: String?

    var id: String { classID }
}

enum CompanionReaderContent: Equatable, Sendable {
    case phase(id: String)
    case ticket(id: String, phaseID: String?, lane: String?)
    case review(id: String, reviewKind: String, status: String, ticketID: String?)
    case history(id: String, entityType: String?, createdAt: String)

    var title: String {
        switch self {
        case let .phase(id), let .ticket(id, _, _), let .review(id, _, _, _), let .history(id, _, _):
            id
        }
    }

    var kindLabel: String {
        switch self {
        case .phase: "Phase"
        case .ticket: "Ticket"
        case .review: "Review"
        case .history: "History"
        }
    }

    var detailFields: [(String, String)] {
        switch self {
        case .phase:
            []
        case let .ticket(_, phaseID, lane):
            [("Phase", phaseID), ("Lane", lane)].compactMap { label, value in
                value.map { (label, $0) }
            }
        case let .review(_, reviewKind, status, ticketID):
            [("Review kind", reviewKind), ("Status", status)]
                + (ticketID.map { [("Ticket", $0)] } ?? [])
        case let .history(_, entityType, createdAt):
            (entityType.map { [("Entity type", $0)] } ?? [])
                + [("Created", createdAt)]
        }
    }

    var searchableValues: [String] {
        [title, kindLabel] + detailFields.map(\.1)
    }
}

struct CompanionReaderItem: Equatable, Identifiable, Sendable {
    let identity: CompanionItemIdentity
    let classID: String
    let lifecycle: CompanionItemLifecycle
    let provenance: CompanionItemProvenance
    let content: CompanionReaderContent

    var id: CompanionItemIdentity { identity }

    var searchableText: String {
        (content.searchableValues + [
            identity.itemID,
            identity.versionID,
            provenance.sourceIdentity,
            lifecycle.rawValue,
        ]).joined(separator: " ")
    }
}

struct CompanionReaderSnapshot: Equatable, Sendable {
    let registrationID: String?
    let publisherEpoch: String?
    let controlSequence: Int64?
    let classCoverage: [CompanionReaderClassCoverage]
    let items: [CompanionReaderItem]
    let sourceOccurredAt: Date?
    let publishedAt: Date?
    let deviceReceivedAt: Date?
    let lastCheckedAt: Date?
    let isCached: Bool
    let accountState: CompanionReaderAccountState
    let sourceState: CompanionReaderSourceState
    let notices: [CompanionReaderNotice]
}

enum CompanionReaderError: Error, Equatable, LocalizedError {
    case inactivePublication
    case invalidPublication(String)
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .inactivePublication:
            "The publication is pending and cannot replace the last compatible local copy."
        case let .invalidPublication(reason):
            "The publication could not be admitted: \(reason)"
        case let .persistenceFailed(reason):
            "The protected local copy could not be updated: \(reason)"
        }
    }
}

@MainActor
final class CompanionReaderStore: ObservableObject {
    @Published private(set) var snapshot: CompanionReaderSnapshot
    @Published var searchText = ""

    var searchResults: [CompanionReaderItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return snapshot.items.filter {
            $0.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    private let cacheURL: URL
    private let denialURL: URL
    private let fileManager: FileManager
    private let now: () -> Date
    private let persistenceFault: ((CompanionReaderPersistenceOperation) throws -> Void)?
    private var cache: PersistedCache?
    private var currentAccountBinding: String?
    private var sourceState: CompanionReaderSourceState = .unavailable
    private var loadNotices: [CompanionReaderNotice] = []

    init(
        cacheURL: URL,
        currentAccountID: String? = nil,
        now: @escaping () -> Date = Date.init,
        fileManager: FileManager = .default,
        persistenceFault: ((CompanionReaderPersistenceOperation) throws -> Void)? = nil
    ) {
        self.cacheURL = cacheURL.standardizedFileURL
        denialURL = cacheURL.standardizedFileURL.appendingPathExtension("denials")
        self.fileManager = fileManager
        self.now = now
        self.persistenceFault = persistenceFault
        currentAccountBinding = currentAccountID.map(Self.accountBinding)
        snapshot = Self.emptySnapshot(
            accountState: currentAccountID == nil ? .none : .bound,
            sourceState: .unavailable
        )

        loadCache(currentAccountID: currentAccountID)
        refreshSnapshot()
    }

    convenience init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(
            cacheURL: baseURL
                .appendingPathComponent("ReleaseRadarPhone", isDirectory: true)
                .appendingPathComponent("companion-reader.json", isDirectory: false)
        )
    }

    func receive(
        _ publication: ReadOnlyCompanionPublication,
        accountID: String,
        receivedAt: Date
    ) throws {
        try bindForReceipt(accountID: accountID)
        let previousAcceptedCache = cache
        let equivalentControl = cache?.control == publication.control

        if let previousControl = cache?.control {
            if publication.control.controlSequence == previousControl.controlSequence {
                guard equivalentControl else {
                    throw CompanionPublicationValidationError.nonIncreasingControlSequence
                }
            } else {
                try publication.control.validate(previous: previousControl)
            }
        } else {
            try publication.control.validate(previous: nil)
        }

        do {
            try writeDenialRecord(.init(
                accountBinding: Self.accountBinding(accountID),
                signedOut: false,
                control: publication.control
            ))
        } catch {
            cache = nil
            searchText = ""
            sourceState = .unavailable
            refreshSnapshot()
            throw error
        }

        var controlState = stateApplyingControl(publication.control, checkedAt: receivedAt)
        cache = controlState
        sourceState = .unavailable
        refreshSnapshot()
        try writeCache(controlState)

        do {
            try publication.manifest.requireCompatible()
        } catch CompanionManifestCompatibilityError.updateRequired {
            let reason = "This publication requires a newer phone reader."
            controlState.updateRequiredReason = reason
            controlState.notices = Self.uniqued(controlState.notices + [
                .init(kind: .updateRequired, title: "Reader update required", message: reason),
            ])
            cache = controlState
            sourceState = .updateRequired(reason: reason)
            refreshSnapshot()
            try writeCache(controlState)
            return
        } catch CompanionManifestCompatibilityError.invalidVersion {
            let reason = "The publication declares an invalid schema or reader version."
            controlState.notices = Self.uniqued(controlState.notices + [
                .init(kind: .malformed, title: "Invalid publication version", message: reason),
            ])
            cache = controlState
            sourceState = .unavailable
            refreshSnapshot()
            try writeCache(controlState)
            throw CompanionReaderError.invalidPublication(reason)
        }

        do {
            try validatePublicationEnvelope(publication)
        } catch let error as CompanionReaderError {
            refreshSnapshot()
            throw error
        } catch {
            refreshSnapshot()
            throw CompanionReaderError.invalidPublication(String(describing: error))
        }

        let classified = classifyForStorage(publication.items, inventories: publication.classInventories)
        if classified.hasUnsupportedContent {
            let reason = "The publication contains a class, kind, or field that requires a newer reader."
            controlState.updateRequiredReason = reason
            controlState.notices = Self.uniqued(controlState.notices + classified.notices + [
                .init(kind: .updateRequired, title: "Reader update required", message: reason),
            ])
            cache = controlState
            sourceState = .updateRequired(reason: reason)
            refreshSnapshot()
            try writeCache(controlState)
            return
        }
        let admittedItems = pruneUnavailableDependencies(
            classified.retainedItems,
            allItems: publication.items,
            control: publication.control
        )

        if publication.control.controlSequence == previousAcceptedCache?.manifest?.controlSequence,
           let previousManifest = previousAcceptedCache?.manifest {
            guard previousManifest == publication.manifest,
                  previousAcceptedCache?.classInventories == publication.classInventories,
                  previousAcceptedCache?.items == admittedItems,
                  equivalentControl else {
                throw CompanionPublicationValidationError.nonIncreasingControlSequence
            }

            var checkedCache = controlState
            checkedCache.lastCheckedAt = receivedAt
            checkedCache.updateRequiredReason = nil
            sourceState = .cached
            cache = checkedCache
            refreshSnapshot()
            try writeCache(checkedCache)
            return
        }

        let candidate = PersistedCache(
            accountBinding: Self.accountBinding(accountID),
            manifest: publication.manifest,
            classInventories: publication.classInventories,
            items: admittedItems,
            control: publication.control,
            deviceReceivedAt: receivedAt,
            lastCheckedAt: receivedAt,
            updateRequiredReason: nil,
            notices: classified.notices,
            coverageNotes: coverageNotes(
                retainedItems: classified.retainedItems,
                admittedItems: admittedItems
            )
        )
        sourceState = .cached
        do {
            try writeCache(candidate)
            cache = candidate
        } catch {
            cache = controlState
            sourceState = .unavailable
            refreshSnapshot()
            throw error
        }
        refreshSnapshot()
    }

    func recordCheck(at date: Date) throws {
        guard cache != nil else {
            sourceState = .unavailable
            refreshSnapshot()
            return
        }
        cache?.lastCheckedAt = date
        sourceState = .unavailable
        try saveCache()
        refreshSnapshot()
    }

    func recordCheck() throws {
        try recordCheck(at: now())
    }

    func switchAccount(to accountID: String?) throws {
        guard let accountID else {
            currentAccountBinding = nil
            sourceState = .unavailable
            refreshSnapshot()
            return
        }

        let binding = Self.accountBinding(accountID)
        currentAccountBinding = binding
        sourceState = .unavailable
        if let cache, cache.accountBinding != binding {
            self.cache = nil
            try removeCacheFileIfPresent()
        }
        refreshSnapshot()
    }

    private func loadCache(currentAccountID: String?) {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheURL)
            var loaded = try JSONDecoder.companionReader.decode(PersistedCache.self, from: data)
            if let currentAccountBinding, loaded.accountBinding != currentAccountBinding {
                try removeCacheFileIfPresent()
                cache = nil
                return
            }
            try validateLoadedCache(loaded)
            let classified = classifyForStorage(loaded.items, inventories: loaded.classInventories)
            loaded.items = pruneUnavailableDependencies(
                classified.retainedItems,
                allItems: loaded.items,
                control: loaded.control
            )
            loaded.notices = Self.uniqued(loaded.notices + classified.notices)
            cache = loaded
            sourceState = .unavailable
        } catch {
            cache = nil
            try? removeCacheFileIfPresent()
            loadNotices = [
                CompanionReaderNotice(
                    kind: .malformed,
                    title: "Cached copy unavailable",
                    message: "The protected local copy could not be read and was not presented as current data."
                ),
            ]
        }
    }

    private func validateLoadedCache(_ loaded: PersistedCache) throws {
        try loaded.control.validate(previous: nil)
        guard let manifest = loaded.manifest else {
            guard loaded.items.isEmpty, loaded.classInventories.isEmpty, loaded.deviceReceivedAt == nil else {
                throw CompanionReaderError.invalidPublication("The control-only cache contains publication data.")
            }
            return
        }
        guard manifest.activation == .active,
              manifest.registrationID == loaded.control.registrationID,
              manifest.publisherEpoch == loaded.control.publisherEpoch,
              manifest.controlSequence <= loaded.control.controlSequence else {
            throw CompanionReaderError.invalidPublication("The cached manifest and control do not agree.")
        }

        var entries: [CompanionItemIdentity: CompanionManifestEntry] = [:]
        for entry in manifest.inventory {
            guard entries.updateValue(entry, forKey: entry.identity) == nil else {
                throw CompanionReaderError.invalidPublication("The cached manifest contains duplicate items.")
            }
        }
        guard Set(loaded.items.map(\.identity)).count == loaded.items.count else {
            throw CompanionReaderError.invalidPublication("The cached copy contains duplicate items.")
        }
        for item in loaded.items {
            let digest = SHA256.hash(data: item.payload).map { String(format: "%02x", $0) }.joined()
            guard let entry = entries[item.identity],
                  entry.contentSHA256 == item.provenance.contentSHA256,
                  entry.contentSHA256 == digest,
                  entry.byteCount == item.payload.count else {
                throw CompanionReaderError.invalidPublication("A cached item does not match its versioned provenance.")
            }
        }

        var classIDs: Set<String> = []
        for inventory in loaded.classInventories {
            guard classIDs.insert(inventory.classID).inserted else {
                throw CompanionReaderError.invalidPublication("The cached class inventory contains duplicates.")
            }
            try inventory.coverage.validate()
        }
    }

    private func bindForReceipt(accountID: String) throws {
        let binding = Self.accountBinding(accountID)
        if let existing = cache?.accountBinding, existing != binding {
            cache = nil
            try removeCacheFileIfPresent()
        }
        currentAccountBinding = binding
    }

    private func persistControlAndWithdrawals(_ control: CompanionControl, checkedAt: Date) throws {
        if cache == nil {
            guard let currentAccountBinding else {
                throw CompanionReaderError.invalidPublication("A local account binding is required.")
            }
            cache = PersistedCache(
                accountBinding: currentAccountBinding,
                manifest: nil,
                classInventories: [],
                items: [],
                control: control,
                deviceReceivedAt: nil,
                lastCheckedAt: checkedAt,
                updateRequiredReason: nil,
                notices: []
            )
        } else {
            let previousItems = cache?.items ?? []
            cache?.control = control
            cache?.items = previousItems.filter { control.isEligible($0, among: previousItems) }
            cache?.lastCheckedAt = checkedAt
        }
        try saveCache()
    }

    private func validatePublicationEnvelope(_ publication: ReadOnlyCompanionPublication) throws {
        guard publication.manifest.activation == .active else {
            throw CompanionReaderError.inactivePublication
        }
        guard publication.manifest.registrationID == publication.control.registrationID,
              publication.manifest.publisherEpoch == publication.control.publisherEpoch,
              publication.manifest.controlSequence == publication.control.controlSequence else {
            throw CompanionReaderError.invalidPublication("Manifest and control identities do not match.")
        }
        try publication.manifest.validate(items: publication.items)

        var classIDs: Set<String> = []
        for inventory in publication.classInventories {
            guard classIDs.insert(inventory.classID).inserted else {
                throw CompanionReaderError.invalidPublication("The class inventory contains duplicate identifiers.")
            }
            try inventory.coverage.validate()
        }
    }

    private func classifyForStorage(
        _ items: [CompanionItem],
        inventories: [CompanionClassInventory]
    ) -> (retainedItems: [CompanionItem], notices: [CompanionReaderNotice]) {
        let excludedClassIDs = Set(inventories.compactMap {
            $0.coverage.status == .excluded ? $0.classID : nil
        })
        var retained: [CompanionItem] = []
        var notices: [CompanionReaderNotice] = []

        for item in items {
            if excludedClassIDs.contains(item.classID) {
                notices.append(.init(
                    kind: .excluded,
                    title: "Excluded content omitted",
                    message: "\(item.classID) is excluded and was not stored on this device."
                ))
                continue
            }

            switch Self.decodeContent(item) {
            case .known:
                retained.append(item)
            case let .unknown(reason):
                retained.append(item)
                notices.append(.init(
                    kind: .updateRequired,
                    title: "Reader update required",
                    message: reason
                ))
            case let .malformed(reason):
                notices.append(.init(
                    kind: .malformed,
                    title: "Malformed content omitted",
                    message: reason
                ))
            }
        }
        return (retained, Self.uniqued(notices))
    }

    private func pruneUnavailableDependencies(
        _ retainedItems: [CompanionItem],
        allItems: [CompanionItem],
        control: CompanionControl
    ) -> [CompanionItem] {
        var retained = retainedItems.filter { control.isEligible($0, among: allItems) }
        var retainedIdentities = Set(retained.map(\.identity))
        var changed = true
        while changed {
            let next = retained.filter { item in
                item.derivedFrom.allSatisfy { retainedIdentities.contains($0.identity) }
            }
            changed = next.count != retained.count
            retained = next
            retainedIdentities = Set(retained.map(\.identity))
        }
        return retained
    }

    private func saveCache() throws {
        guard let cache else { return }
        do {
            let directory = cacheURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            var directoryValues = URLResourceValues()
            directoryValues.isExcludedFromBackup = true
            var mutableDirectory = directory
            try mutableDirectory.setResourceValues(directoryValues)

            let data = try JSONEncoder.companionReader.encode(cache)
            try data.write(to: cacheURL, options: [.atomic, .completeFileProtection])
            var fileValues = URLResourceValues()
            fileValues.isExcludedFromBackup = true
            var mutableCacheURL = cacheURL
            try mutableCacheURL.setResourceValues(fileValues)
        } catch {
            throw CompanionReaderError.persistenceFailed(error.localizedDescription)
        }
    }

    private func removeCacheFileIfPresent() throws {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return }
        do {
            try fileManager.removeItem(at: cacheURL)
        } catch {
            throw CompanionReaderError.persistenceFailed(error.localizedDescription)
        }
    }

    private func refreshSnapshot() {
        let accountState: CompanionReaderAccountState
        if currentAccountBinding != nil {
            accountState = .bound
        } else if cache != nil {
            accountState = .unknownOffline
        } else {
            accountState = .none
        }

        guard let cache else {
            snapshot = Self.emptySnapshot(accountState: accountState, sourceState: sourceState, notices: loadNotices)
            return
        }

        let decodedItems = cache.items.compactMap { item -> CompanionReaderItem? in
            guard case let .known(content) = Self.decodeContent(item) else { return nil }
            return CompanionReaderItem(
                identity: item.identity,
                classID: item.classID,
                lifecycle: item.lifecycle,
                provenance: item.provenance,
                content: content
            )
        }
        let coverage = cache.classInventories.map {
            CompanionReaderClassCoverage(
                classID: $0.classID,
                status: $0.coverage.status,
                itemCount: $0.coverage.itemCount,
                reason: $0.coverage.reason?.rawValue
            )
        }
        var notices = loadNotices + cache.notices
        if let reason = cache.updateRequiredReason {
            notices.append(.init(kind: .updateRequired, title: "Reader update required", message: reason))
        }
        notices.append(contentsOf: Self.coverageNotices(cache.classInventories))

        snapshot = CompanionReaderSnapshot(
            registrationID: cache.manifest?.registrationID ?? cache.control.registrationID,
            publisherEpoch: cache.manifest?.publisherEpoch ?? cache.control.publisherEpoch,
            controlSequence: cache.control.controlSequence,
            classCoverage: coverage,
            items: decodedItems,
            sourceOccurredAt: cache.manifest?.sourceOccurredAt,
            publishedAt: cache.manifest?.publishedAt,
            deviceReceivedAt: cache.deviceReceivedAt,
            lastCheckedAt: cache.lastCheckedAt,
            isCached: cache.manifest != nil,
            accountState: accountState,
            sourceState: sourceState,
            notices: Self.uniqued(notices)
        )
    }

    private static func decodeContent(_ item: CompanionItem) -> ContentClassification {
        let fields: [String: String]
        do {
            fields = try JSONDecoder().decode([String: String].self, from: item.payload)
        } catch {
            if Self.knownClassIDs.contains(item.classID) {
                return .malformed("\(item.identity.itemID) has a payload that is not a string-valued JSON object.")
            }
            return .unknown("\(item.classID) content requires a newer reader.")
        }

        guard let id = fields["id"], id == item.identity.itemID, let kind = fields["kind"] else {
            return .malformed("\(item.identity.itemID) is missing its matching id or kind.")
        }

        switch (item.classID, kind) {
        case ("deliveryGraph", "phase"):
            guard Set(fields.keys).isSubset(of: ["id", "kind"]) else {
                return .unknown("Phase \(id) contains fields this reader does not understand.")
            }
            return .known(.phase(id: id))
        case ("deliveryGraph", "ticket"):
            guard Set(fields.keys).isSubset(of: ["id", "kind", "phaseID", "lane"]) else {
                return .unknown("Ticket \(id) contains fields this reader does not understand.")
            }
            return .known(.ticket(id: id, phaseID: fields["phaseID"], lane: fields["lane"]))
        case ("reviewMetadata", "review"):
            guard let reviewKind = fields["reviewKind"], let status = fields["status"] else {
                return .malformed("Review \(id) is missing reviewKind or status.")
            }
            guard Set(fields.keys).isSubset(of: ["id", "kind", "reviewKind", "status", "ticketID"]) else {
                return .unknown("Review \(id) contains fields this reader does not understand.")
            }
            return .known(.review(
                id: id,
                reviewKind: reviewKind,
                status: status,
                ticketID: fields["ticketID"]
            ))
        case ("historyMetadata", "history"):
            guard let createdAt = fields["createdAt"] else {
                return .malformed("History \(id) is missing createdAt.")
            }
            guard Set(fields.keys).isSubset(of: ["id", "kind", "entityType", "createdAt"]) else {
                return .unknown("History \(id) contains fields this reader does not understand.")
            }
            return .known(.history(id: id, entityType: fields["entityType"], createdAt: createdAt))
        case ("deliveryGraph", _), ("reviewMetadata", _), ("historyMetadata", _):
            return .unknown("\(item.classID) kind \(kind) requires a newer reader.")
        case ("documentation", _), ("evidence", _):
            return .unknown("\(item.classID) projection is not implemented by this reader.")
        default:
            return .unknown("\(item.classID) content requires a newer reader.")
        }
    }

    private static func coverageNotices(_ inventories: [CompanionClassInventory]) -> [CompanionReaderNotice] {
        var notices: [CompanionReaderNotice] = inventories.compactMap { inventory in
            let reason = inventory.coverage.reason?.rawValue
            switch inventory.coverage.status {
            case .complete, .empty:
                return nil
            case .unavailable:
                return .init(
                    kind: .unavailable,
                    title: "\(displayName(for: inventory.classID)) unavailable",
                    message: reason ?? "The publisher did not provide this class."
                )
            case .excluded:
                return .init(
                    kind: .excluded,
                    title: "\(displayName(for: inventory.classID)) excluded",
                    message: reason ?? "This class is intentionally excluded from the phone copy."
                )
            case .unsupported:
                return .init(
                    kind: .unsupported,
                    title: "\(displayName(for: inventory.classID)) unsupported",
                    message: reason ?? "This class is not supported by the current publication."
                )
            }
        }

        let described = Set(inventories.map(\.classID))
        for classID in expectedClassIDs where !described.contains(classID) {
            notices.append(.init(
                kind: .updateRequired,
                title: "\(displayName(for: classID)) coverage unknown",
                message: "The publication does not describe this class, so it is not treated as empty."
            ))
        }
        for inventory in inventories where !expectedClassIDs.contains(inventory.classID) {
            notices.append(.init(
                kind: .updateRequired,
                title: "Reader update required",
                message: "\(inventory.classID) is a published class this reader does not understand."
            ))
        }
        return notices
    }

    private static func displayName(for classID: String) -> String {
        switch classID {
        case "deliveryGraph": "Delivery work"
        case "reviewMetadata": "Reviews"
        case "historyMetadata": "History"
        case "documentation": "Documentation"
        case "evidence": "Evidence"
        default: classID
        }
    }

    private static func accountBinding(_ accountID: String) -> String {
        SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func uniqued(_ notices: [CompanionReaderNotice]) -> [CompanionReaderNotice] {
        var seen: Set<String> = []
        return notices.filter { seen.insert($0.id).inserted }
    }

    private static func emptySnapshot(
        accountState: CompanionReaderAccountState,
        sourceState: CompanionReaderSourceState,
        notices: [CompanionReaderNotice] = []
    ) -> CompanionReaderSnapshot {
        CompanionReaderSnapshot(
            registrationID: nil,
            publisherEpoch: nil,
            controlSequence: nil,
            classCoverage: [],
            items: [],
            sourceOccurredAt: nil,
            publishedAt: nil,
            deviceReceivedAt: nil,
            lastCheckedAt: nil,
            isCached: false,
            accountState: accountState,
            sourceState: sourceState,
            notices: notices
        )
    }

    private static let knownClassIDs: Set<String> = [
        "deliveryGraph", "reviewMetadata", "historyMetadata", "documentation", "evidence",
    ]

    private static let expectedClassIDs: [String] = [
        "deliveryGraph", "reviewMetadata", "historyMetadata", "documentation", "evidence",
    ]
}

private enum ContentClassification {
    case known(CompanionReaderContent)
    case unknown(String)
    case malformed(String)
}

private struct PersistedCache: Codable, Equatable {
    let accountBinding: String
    var manifest: CompanionManifest?
    var classInventories: [CompanionClassInventory]
    var items: [CompanionItem]
    var control: CompanionControl
    var deviceReceivedAt: Date?
    var lastCheckedAt: Date?
    var updateRequiredReason: String?
    var notices: [CompanionReaderNotice]
}

private extension JSONEncoder {
    static var companionReader: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var companionReader: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

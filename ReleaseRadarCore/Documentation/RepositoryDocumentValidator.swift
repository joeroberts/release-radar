import CryptoKit
import Foundation

public struct RepositoryDocumentValidator {
    private let limits: RepositoryDocumentContract.Limits
    private let afterRead: ((String) -> Void)?
    private let beforeRootOpen: ((String) -> Void)?
    public init(limits: RepositoryDocumentContract.Limits = .init()) {
        self.limits = limits
        self.afterRead = nil
        self.beforeRootOpen = nil
    }
    // Internal scheduling seam: tests mutate real files between read and stability
    // verification; no read results or filesystem safety checks are substituted.
    init(limits: RepositoryDocumentContract.Limits = .init(), afterRead: @escaping (String) -> Void) {
        self.limits = limits
        self.afterRead = afterRead
        self.beforeRootOpen = nil
    }

    init(limits: RepositoryDocumentContract.Limits = .init(), beforeRootOpen: @escaping (String) -> Void) {
        self.limits = limits
        self.afterRead = nil
        self.beforeRootOpen = beforeRootOpen
    }

    /// Validates this tree only. Acceptance of a change additionally requires validateTransition.
    public func validateCurrent(authorizedRoot: URL) throws -> RepositoryDocumentSnapshot {
        let reader = try RepositoryDocumentReader(rootURL: authorizedRoot, limits: limits, afterRead: afterRead, beforeRootOpen: beforeRootOpen)
        return try validateCurrent(reader: reader)
    }

    // The index tool transforms only validated collection-index paths. All contents,
    // links, checksums, and transitional navigation are validated on the complete
    // in-memory candidate before the caller may write it.
    func validateCurrent(reader: RepositoryDocumentReader,
                         prepareIndexes: ((RepositoryDocumentCatalog) throws -> [String: Data])? = nil) throws -> RepositoryDocumentSnapshot {
        guard [limits.maximumCatalogBytes, limits.maximumFileBytes, limits.maximumArtifactCount,
               limits.maximumCollectionCount, limits.maximumTotalBytes, limits.maximumPathBytes,
               limits.maximumDepth].allSatisfy({ $0 > 0 && $0 <= 1_073_741_824 }) else {
            throw RepositoryDocumentError(.limitExceeded)
        }
        let bytes = try reader.read(RepositoryDocumentContract.catalogPath, catalog: true)
        guard String(data: bytes, encoding: .utf8) != nil else { throw RepositoryDocumentError(.invalidUTF8) }
        let catalog: RepositoryDocumentCatalog
        do {
            struct Version: Decodable { let version: Int }
            let version = try JSONDecoder().decode(Version.self, from: bytes).version
            guard version == RepositoryDocumentContract.catalogVersion else { throw RepositoryDocumentError(.unsupportedVersion) }
            catalog = try JSONDecoder().decode(RepositoryDocumentCatalog.self, from: bytes)
        } catch let failure as RepositoryDocumentError { throw failure }
        catch { throw RepositoryDocumentError(.malformedCatalog) }
        try validateMetadata(catalog)
        let inventory = try reader.inventory()
        try reader.verifyStable()
        let expectedFiles = Set(catalog.artifacts.map(\.path)).union([RepositoryDocumentContract.catalogPath])
        if let missing = expectedFiles.subtracting(inventory.files).sorted().first {
            throw RepositoryDocumentError(.missingFile, path: missing)
        }
        if let extra = inventory.files.subtracting(expectedFiles).sorted().first {
            throw RepositoryDocumentError(.uncataloguedFile, path: extra)
        }
        guard Set(catalog.collections.map(\.path)) == inventory.directories else {
            throw RepositoryDocumentError(.invalidCollection)
        }
        let indexes = try prepareIndexes?(catalog) ?? [:]
        let indexPaths = Set(catalog.artifacts.filter { $0.kind == .collectionIndex }.map(\.path))
        guard Set(indexes.keys).isSubset(of: indexPaths) else { throw RepositoryDocumentError(.unsafePath) }
        try reader.validateReplacementBounds(indexes)
        try validateContents(catalog, reader: reader, indexes: indexes)
        try reader.verifyStable()
        let canonical = try canonicalData(catalog)
        return .init(catalog: catalog, canonicalCatalog: canonical, digest: Self.digest(canonical))
    }

    private func validateMetadata(_ catalog: RepositoryDocumentCatalog) throws {
        guard UUID(uuidString: catalog.repositoryID) != nil else { throw RepositoryDocumentError(.invalidIdentity) }
        guard catalog.artifacts.count <= limits.maximumArtifactCount,
              catalog.collections.count <= limits.maximumCollectionCount,
              catalog.retiredArtifactIDs.count <= limits.maximumArtifactCount else { throw RepositoryDocumentError(.limitExceeded) }
        let artifactIDs = catalog.artifacts.map(\.artifactID)
        let collectionIDs = catalog.collections.map(\.collectionID)
        for id in artifactIDs + collectionIDs + catalog.retiredArtifactIDs {
            guard Self.validID(id) else { throw RepositoryDocumentError(.invalidIdentity) }
        }
        guard Set(artifactIDs).count == artifactIDs.count,
              Set(collectionIDs).count == collectionIDs.count,
              Set(catalog.retiredArtifactIDs).count == catalog.retiredArtifactIDs.count else {
            throw RepositoryDocumentError(.duplicateIdentity)
        }
        guard Set(artifactIDs).isDisjoint(with: catalog.retiredArtifactIDs) else { throw RepositoryDocumentError(.retiredIdentity) }
        var paths = Set<String>()
        for path in catalog.artifacts.map(\.path) + catalog.collections.map(\.path) {
            try RepositoryDocumentReader.validatePath(path, limits: limits)
            guard !RepositoryDocumentReader.isProhibited(path) else { throw RepositoryDocumentError(.prohibitedContent, path: path) }
            guard paths.insert(path.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))).inserted else {
                throw RepositoryDocumentError(.duplicatePath, path: path)
            }
        }
        let artifacts = Dictionary(uniqueKeysWithValues: catalog.artifacts.map { ($0.artifactID, $0) })
        let collections = Dictionary(uniqueKeysWithValues: catalog.collections.map { ($0.collectionID, $0) })
        var controllers = Set<String>()
        for artifact in catalog.artifacts {
            guard artifact.path != RepositoryDocumentContract.catalogPath,
                  let parent = collections[artifact.parentCollection], Self.parent(artifact.path) == parent.path else {
                throw RepositoryDocumentError(.invalidCollection, path: artifact.path)
            }
            if artifact.authorityLevel == .controlling {
                guard artifact.lifecycle == .active, let role = artifact.authorityRole, Self.validID(role) else {
                    throw RepositoryDocumentError(.invalidAuthority, path: artifact.path)
                }
                guard controllers.insert(role).inserted else { throw RepositoryDocumentError(.conflictingController, path: artifact.path) }
            } else if artifact.authorityRole != nil || (artifact.lifecycle == .archived && artifact.authorityLevel != .nonAuthoritative) {
                throw RepositoryDocumentError(.invalidAuthority, path: artifact.path)
            }
            let sensitivities = artifact.applicationSensitivity.map(\.rawValue)
            guard !sensitivities.isEmpty, Set(sensitivities).count == sensitivities.count,
                  !(sensitivities.count > 1 && sensitivities.contains("none")) else { throw RepositoryDocumentError(.malformedCatalog) }
            guard Set(artifact.supersedes).count == artifact.supersedes.count else { throw RepositoryDocumentError(.duplicateIdentity) }
            for oldID in artifact.supersedes {
                guard artifacts[oldID] != nil || catalog.retiredArtifactIDs.contains(oldID) else {
                    throw RepositoryDocumentError(.missingReplacement, path: artifact.path)
                }
            }
            switch artifact.checksum.policy {
            case .notApplicable:
                guard artifact.checksum.manifestArtifactID == nil else { throw RepositoryDocumentError(.checksumMismatch, path: artifact.path) }
            case .required:
                guard let manifestID = artifact.checksum.manifestArtifactID,
                      let manifest = artifacts[manifestID], manifest.kind == .checksumManifest,
                      manifestID != artifact.artifactID else { throw RepositoryDocumentError(.checksumMismatch, path: artifact.path) }
            }
        }
        // Iterative graph traversal avoids recursion proportional to untrusted catalog size.
        var complete = Set<String>()
        for artifact in catalog.artifacts {
            var stack: [(String, Bool)] = [(artifact.artifactID, false)]
            var visiting = Set<String>()
            while let (id, exiting) = stack.popLast() {
                if exiting { visiting.remove(id); complete.insert(id); continue }
                if complete.contains(id) { continue }
                guard visiting.insert(id).inserted else { throw RepositoryDocumentError(.supersessionCycle) }
                stack.append((id, true))
                for old in artifacts[id]?.supersedes.reversed() ?? [] { stack.append((old, false)) }
            }
        }
        guard let root = catalog.collections.first(where: { $0.path == "docs" }), root.parentCollection == nil,
              !root.isLeaf, root.indexArtifactID.flatMap({ artifacts[$0]?.path }) == RepositoryDocumentContract.rootIndexPath else {
            throw RepositoryDocumentError(.invalidCollection)
        }
        for collection in catalog.collections {
            guard Self.validText(collection.purpose), !collection.allowedContents.isEmpty,
                  !collection.prohibitedContents.isEmpty,
                  (collection.allowedContents + collection.prohibitedContents).allSatisfy(Self.validText),
                  Set(collection.allowedContents).count == collection.allowedContents.count,
                  Set(collection.prohibitedContents).count == collection.prohibitedContents.count else {
                throw RepositoryDocumentError(.invalidCollection, path: collection.path)
            }
            if collection.path != "docs" {
                guard let parentID = collection.parentCollection, let parent = collections[parentID],
                      parent.path == Self.parent(collection.path) else { throw RepositoryDocumentError(.invalidCollection, path: collection.path) }
            }
            if collection.isLeaf {
                guard collection.indexArtifactID == nil else { throw RepositoryDocumentError(.invalidCollection, path: collection.path) }
                if catalog.collections.contains(where: { $0.parentCollection == collection.collectionID }) && collection.path != "docs/superpowers" {
                    throw RepositoryDocumentError(.invalidCollection, path: collection.path)
                }
            } else {
                guard let indexID = collection.indexArtifactID, let index = artifacts[indexID],
                      index.kind == .collectionIndex, index.path == collection.path + "/README.md",
                      index.parentCollection == collection.collectionID else { throw RepositoryDocumentError(.invalidCollection, path: collection.path) }
            }
            if let first = collection.firstRead {
                guard let artifact = artifacts[first], artifact.parentCollection == collection.collectionID, artifact.lifecycle != .archived else {
                    throw RepositoryDocumentError(.invalidCollection, path: collection.path)
                }
            }
            if let archiveID = collection.archiveDestination {
                guard archiveID != collection.collectionID, let archive = collections[archiveID],
                      !catalog.artifacts.contains(where: { $0.parentCollection == archive.collectionID && $0.authorityLevel == .controlling }) else {
                    throw RepositoryDocumentError(.invalidCollection, path: collection.path)
                }
                var seen: Set<String> = [collection.collectionID]
                var next: String? = archiveID
                while let id = next {
                    guard seen.insert(id).inserted else { throw RepositoryDocumentError(.invalidCollection) }
                    next = collections[id]?.archiveDestination
                }
            }
        }
        for index in catalog.artifacts where index.kind == .collectionIndex {
            guard collections[index.parentCollection]?.indexArtifactID == index.artifactID else { throw RepositoryDocumentError(.invalidCollection, path: index.path) }
        }
        try validateTransitionalMetadata(catalog)
    }

    private func validateTransitionalMetadata(_ catalog: RepositoryDocumentCatalog) throws {
        let special = catalog.collections.filter { $0.path == "docs/superpowers" || $0.path.hasPrefix("docs/superpowers/") }
        guard let transition = catalog.transitionalSubtree else {
            guard special.isEmpty else { throw RepositoryDocumentError(.invalidTransitionalSubtree) }
            return
        }
        let paths: Set<String> = ["docs/superpowers", "docs/superpowers/plans", "docs/superpowers/specs"]
        let artifacts = catalog.artifacts.filter { $0.path.hasPrefix("docs/superpowers/") }
        guard transition.path == "docs/superpowers",
              catalog.collections.first(where: { $0.collectionID == transition.indexedAncestor })?.path == "docs",
              Set(special.map(\.path)) == paths, special.allSatisfy(\.isLeaf),
              Set(transition.collectionIDs) == Set(special.map(\.collectionID)), transition.collectionIDs.count == 3,
              Set(transition.artifactIDs) == Set(artifacts.map(\.artifactID)), transition.artifactIDs.count == artifacts.count,
              artifacts.allSatisfy({ Self.parent($0.path) != "docs/superpowers" }) else {
            throw RepositoryDocumentError(.invalidTransitionalSubtree)
        }
    }

    public func validateTransition(from prior: RepositoryDocumentSnapshot, to current: RepositoryDocumentSnapshot) throws {
        let old = prior.catalog
        let new = current.catalog
        guard old.repositoryID.lowercased() == new.repositoryID.lowercased() else { throw RepositoryDocumentError(.repositoryIdentityChanged) }
        let oldArtifacts = Dictionary(uniqueKeysWithValues: old.artifacts.map { ($0.artifactID, $0) })
        let newArtifacts = Dictionary(uniqueKeysWithValues: new.artifacts.map { ($0.artifactID, $0) })
        let retired = Set(new.retiredArtifactIDs)
        guard retired.isSuperset(of: old.retiredArtifactIDs), Set(newArtifacts.keys).isDisjoint(with: old.retiredArtifactIDs) else {
            throw RepositoryDocumentError(.retiredIdentity)
        }
        // New tombstones must retire an actual previously accepted artifact, not reserve arbitrary IDs.
        guard retired.subtracting(old.retiredArtifactIDs).isSubset(of: Set(oldArtifacts.keys)) else { throw RepositoryDocumentError(.retiredIdentity) }
        if let transition = new.transitionalSubtree {
            guard let previous = old.transitionalSubtree,
                  Set(transition.artifactIDs).isSubset(of: previous.artifactIDs),
                  Set(transition.collectionIDs) == Set(previous.collectionIDs) else { throw RepositoryDocumentError(.invalidTransitionalSubtree) }
            for id in transition.artifactIDs {
                guard oldArtifacts[id]?.path == newArtifacts[id]?.path else { throw RepositoryDocumentError(.invalidTransitionalSubtree) }
            }
        }
        for artifact in old.artifacts {
            guard let replacement = newArtifacts[artifact.artifactID] else {
                guard artifact.authorityLevel != .controlling else { throw RepositoryDocumentError(.controllingDeletion, path: artifact.path) }
                guard retired.contains(artifact.artifactID) else { throw RepositoryDocumentError(.retiredIdentity, path: artifact.path) }
                continue
            }
            guard replacement.kind == artifact.kind else { throw RepositoryDocumentError(.invalidTransition, path: replacement.path) }
            if artifact.authorityLevel == .controlling && replacement.authorityLevel != .controlling && replacement.lifecycle == .active {
                throw RepositoryDocumentError(.invalidTransition, path: replacement.path)
            }
            if artifact.lifecycle == replacement.lifecycle { continue }
            switch (artifact.lifecycle, replacement.lifecycle) {
            case (.proposed, .active): break
            case (.active, .completed):
                guard artifact.kind == .document || artifact.kind == .verificationEvidence else { throw RepositoryDocumentError(.invalidTransition, path: replacement.path) }
            case (.active, .superseded):
                guard new.artifacts.contains(where: {
                    $0.lifecycle == .active && $0.supersedes.contains(artifact.artifactID)
                        && (artifact.authorityLevel != .controlling || ($0.authorityLevel == .controlling && $0.authorityRole == artifact.authorityRole))
                }) else { throw RepositoryDocumentError(.missingReplacement, path: replacement.path) }
            case (.completed, .archived):
                guard let source = old.collections.first(where: { $0.collectionID == artifact.parentCollection }),
                      let archive = source.archiveDestination, replacement.parentCollection == archive,
                      replacement.path != artifact.path else { throw RepositoryDocumentError(.invalidTransition, path: replacement.path) }
            default: throw RepositoryDocumentError(.invalidTransition, path: replacement.path)
            }
        }
    }

    private func validateContents(_ catalog: RepositoryDocumentCatalog, reader: RepositoryDocumentReader, indexes: [String: Data]) throws {
        func contents(_ path: String) throws -> Data { try indexes[path] ?? reader.read(path) }
        let byID = Dictionary(uniqueKeysWithValues: catalog.artifacts.map { ($0.artifactID, $0) })
        let byPath = Dictionary(uniqueKeysWithValues: catalog.artifacts.map { ($0.path, $0) })
        var text: [String: String] = [:]
        for artifact in catalog.artifacts where artifact.kind != .designAsset {
            guard let contents = String(data: try contents(artifact.path), encoding: .utf8) else {
                throw RepositoryDocumentError(.invalidUTF8, path: artifact.path)
            }
            text[artifact.path] = contents
        }
        var manifests: [String: [String: String]] = [:]
        for artifact in catalog.artifacts where artifact.kind == .checksumManifest {
            var entries: [String: String] = [:]
            for line in (text[artifact.path] ?? "").split(separator: "\n") {
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                guard line.count > 66 else { throw RepositoryDocumentError(.checksumMismatch, path: artifact.path) }
                let digest = String(line.prefix(64))
                let separator = String(line.dropFirst(64).prefix(2))
                let path = String(line.dropFirst(66))
                guard digest.count == 64, digest.allSatisfy({ $0.isHexDigit && $0.isASCII }),
                      separator == "  " || separator == " *", entries[path] == nil,
                      let target = byPath[path], target.artifactID != artifact.artifactID,
                      target.checksum.policy == .required, target.checksum.manifestArtifactID == artifact.artifactID else {
                    throw RepositoryDocumentError(.checksumMismatch, path: artifact.path)
                }
                entries[path] = digest.lowercased()
            }
            manifests[artifact.artifactID] = entries
        }
        for artifact in catalog.artifacts where artifact.checksum.policy == .required {
            guard let manifestID = artifact.checksum.manifestArtifactID,
                  manifests[manifestID]?[artifact.path] == Self.digest(try contents(artifact.path)) else {
                throw RepositoryDocumentError(.checksumMismatch, path: artifact.path)
            }
        }
        for artifact in catalog.artifacts where artifact.lifecycle == .active && artifact.path.lowercased().hasSuffix(".md") {
            for link in try RepositoryDocumentMarkdown.links(in: text[artifact.path] ?? "") {
                guard let path = try resolvedLink(link.destination, source: artifact.path) else { continue }
                if let target = byPath[path] {
                    // Index navigation labels historical content; executable document guidance cannot route through it.
                    guard artifact.kind == .collectionIndex || target.lifecycle != .archived
                            || (link.isHistoricalCitation && target.authorityLevel == .nonAuthoritative) else {
                        throw RepositoryDocumentError(.archivedReference, path: artifact.path)
                    }
                } else if catalog.collections.contains(where: { $0.path == path }) {
                    continue
                } else {
                    do { _ = try reader.read(path) }
                    catch let failure as RepositoryDocumentError where failure.code == .missingFile {
                        throw RepositoryDocumentError(.brokenLink, path: artifact.path)
                    }
                }
            }
        }
        if let transitional = catalog.transitionalSubtree,
           let collection = catalog.collections.first(where: { $0.collectionID == transitional.indexedAncestor }),
           let indexID = collection.indexArtifactID, let index = byID[indexID] {
            let destinations = try Set(RepositoryDocumentMarkdown.links(in: text[index.path] ?? "")
                .filter(\.isNavigation).compactMap { try resolvedLink($0.destination, source: index.path) })
            let required = Set(catalog.collections.filter { transitional.collectionIDs.contains($0.collectionID) }.map(\.path))
                .union(catalog.artifacts.filter { transitional.artifactIDs.contains($0.artifactID) }.map(\.path))
            guard destinations.isSuperset(of: required) else { throw RepositoryDocumentError(.invalidTransitionalSubtree) }
        }
    }

    private func resolvedLink(_ destination: String, source: String) throws -> String? {
        let value = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value.hasPrefix("#") { return nil }
        if let scheme = URLComponents(string: value)?.scheme {
            guard ["http", "https", "mailto"].contains(scheme.lowercased()) else { throw RepositoryDocumentError(.brokenLink, path: source) }
            return nil
        }
        let rawPath = value.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
        guard let decoded = String(rawPath).removingPercentEncoding, !decoded.hasPrefix("/"), !decoded.contains("\\") else {
            throw RepositoryDocumentError(.unsafePath)
        }
        if decoded.isEmpty { return nil }
        var parts = Self.parent(source).split(separator: "/").map(String.init)
        for part in decoded.split(separator: "/") {
            if part == "." { continue }
            if part == ".." {
                guard !parts.isEmpty else { throw RepositoryDocumentError(.unsafePath) }
                parts.removeLast()
            } else { parts.append(String(part)) }
        }
        let path = parts.joined(separator: "/")
        try RepositoryDocumentReader.validatePath(path, limits: limits, docsOnly: false)
        return path
    }

    private func canonicalData(_ catalog: RepositoryDocumentCatalog) throws -> Data {
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(catalog)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        var artifacts = object["artifacts"] as! [[String: Any]]
        for index in artifacts.indices {
            artifacts[index]["supersedes"] = (artifacts[index]["supersedes"] as! [String]).sorted()
            artifacts[index]["applicationSensitivity"] = (artifacts[index]["applicationSensitivity"] as! [String]).sorted()
        }
        object["artifacts"] = artifacts.sorted { ($0["artifactID"] as! String) < ($1["artifactID"] as! String) }
        object["collections"] = (object["collections"] as! [[String: Any]]).sorted { ($0["collectionID"] as! String) < ($1["collectionID"] as! String) }
        object["retiredArtifactIDs"] = catalog.retiredArtifactIDs.sorted()
        object["repositoryID"] = catalog.repositoryID.lowercased()
        if var transitional = object["transitionalSubtree"] as? [String: Any] {
            transitional["collectionIDs"] = (transitional["collectionIDs"] as! [String]).sorted()
            transitional["artifactIDs"] = (transitional["artifactIDs"] as! [String]).sorted()
            object["transitionalSubtree"] = transitional
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func parent(_ path: String) -> String { path.split(separator: "/").dropLast().joined(separator: "/") }
    private static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 128 && id.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_:.").contains($0)
        }
    }
    private static func validText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.utf8.count <= 4_096
            && !text.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }
}

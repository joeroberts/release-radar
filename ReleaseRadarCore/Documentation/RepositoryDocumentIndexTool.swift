import Foundation

public struct RepositoryDocumentIndexError: Error, Equatable, LocalizedError {
    public enum Code: String, Sendable {
        case invalidMarkers, staleIndex, writeFailed, rollbackFailed
        case cleanupFailedAfterCommit, cleanupFailedAfterRollback
    }
    public let code: Code
    public let paths: [String]
    /// Only used with incomplete rollback: these candidates are not recovery sources.
    public let disposableCandidatePaths: [String]

    init(code: Code, paths: [String], disposableCandidatePaths: [String] = []) {
        self.code = code
        self.paths = paths
        self.disposableCandidatePaths = disposableCandidatePaths
    }

    public var errorDescription: String? {
        let action: String
        switch code {
        case .invalidMarkers: action = "Provide exactly one start/end marker pair on separate lines."
        case .staleIndex: action = "Run the documentation tool in write mode when authorized, then check again."
        case .writeFailed: action = "Original indexes were restored. Check repository permissions and retry."
        case .rollbackFailed:
            action = "Recovery is incomplete. The listed original backup locations require inspection with the affected README files before manual recovery. Preserve them."
                + (disposableCandidatePaths.isEmpty ? "" : " Disposable generated candidates: \(disposableCandidatePaths.joined(separator: ", ")). Do not restore these candidates over README files.")
        case .cleanupFailedAfterCommit:
            action = "All index replacements committed. Listed temporary files contain previous originals; keep current README files and remove these obsolete backups when authorized."
        case .cleanupFailedAfterRollback:
            action = "No replacements remain; original indexes are unchanged or restored. Listed temporary files contain generated or partial candidates. Do not restore them over README files; remove them when authorized."
        }
        return "Repository documentation index failed (\(code.rawValue)): \(paths.joined(separator: ", ")). \(action)"
    }
}

/// Fixed-purpose catalog-driven README checking and generation. The caller must
/// retain authorization to the explicit root throughout the operation. Write is
/// a separate opt-in action; checking and preparing candidates never write.
public struct RepositoryDocumentIndexTool {
    private let limits: RepositoryDocumentContract.Limits
    private let beforeReplace: ((String) throws -> Void)?
    private let beforeCleanup: ((String) -> Void)?

    public init(limits: RepositoryDocumentContract.Limits = .init()) {
        self.limits = limits
        beforeReplace = nil
        beforeCleanup = nil
    }

    // Scheduling seam for real late I/O failures, without substituting any I/O.
    init(beforeReplace: @escaping (String) throws -> Void, beforeCleanup: ((String) -> Void)? = nil) {
        limits = .init()
        self.beforeReplace = beforeReplace
        self.beforeCleanup = beforeCleanup
    }

    public func check(authorizedRoot: URL) throws {
        let (_, changes) = try prepare(authorizedRoot)
        guard changes.isEmpty else { throw RepositoryDocumentIndexError(code: .staleIndex, paths: changes.keys.sorted()) }
    }

    /// Returns only the sorted paths actually changed, not every visited index.
    @discardableResult
    public func write(authorizedRoot: URL) throws -> [String] {
        let (reader, changes) = try prepare(authorizedRoot)
        try RepositoryDocumentIndexWriter.replace(changes, reader: reader, beforeReplace: beforeReplace, beforeCleanup: beforeCleanup)
        return changes.keys.sorted()
    }

    private func prepare(_ root: URL) throws -> (RepositoryDocumentReader, [String: Data]) {
        let reader = try RepositoryDocumentReader(rootURL: root, limits: limits, afterRead: nil)
        var changes: [String: Data] = [:]
        _ = try RepositoryDocumentValidator(limits: limits).validateCurrent(reader: reader) { catalog in
            let renderer = RepositoryDocumentIndexRenderer(catalog: catalog)
            for collection in catalog.collections.sorted(by: { $0.path < $1.path }) where collection.indexArtifactID != nil {
                let path = collection.path + "/README.md"
                let original = try reader.read(path)
                let candidate = try Self.replacingManagedBytes(original, section: renderer.render(collection), path: path)
                if original != candidate { changes[path] = candidate }
            }
            return changes
        }
        return (reader, changes)
    }

    private static func replacingManagedBytes(_ original: Data, section: String, path: String) throws -> Data {
        let start = Data(RepositoryDocumentContract.managedIndexStart.utf8)
        let end = Data(RepositoryDocumentContract.managedIndexEnd.utf8)
        let namespace = Data("release-radar-docs:".utf8)
        var occurrences: [Range<Data.Index>] = []
        var cursor = original.startIndex
        while let range = original.range(of: namespace, in: cursor..<original.endIndex) {
            occurrences.append(range)
            cursor = range.upperBound
        }
        guard occurrences.count == 2,
              let first = original.range(of: start), let last = original.range(of: end), first.upperBound < last.lowerBound,
              first.lowerBound == original.startIndex || original[first.lowerBound - 1] == 10,
              original[last.lowerBound - 1] == 10 else {
            throw RepositoryDocumentIndexError(code: .invalidMarkers, paths: [path])
        }
        func newlineEnd(at index: Int) -> Int? {
            if index < original.count && original[index] == 10 { return index + 1 }
            if index + 1 < original.count && original[index] == 13 && original[index + 1] == 10 { return index + 2 }
            return nil
        }
        guard let bodyStart = newlineEnd(at: first.upperBound),
              last.upperBound == original.endIndex || newlineEnd(at: last.upperBound) != nil else {
            throw RepositoryDocumentIndexError(code: .invalidMarkers, paths: [path])
        }
        // Preserve the marker lines, their line endings, and every byte outside.
        return original[..<bodyStart] + Data(("\n" + section + "\n").utf8) + original[last.lowerBound...]
    }
}

private struct RepositoryDocumentIndexRenderer {
    let catalog: RepositoryDocumentCatalog

    func render(_ collection: RepositoryDocumentCollection) -> String {
        let source = collection.path
        var lines = block(collection, source: source, leaf: false)
        // Leaf collections have no README: their entire metadata and inventory
        // belongs in their nearest indexed ancestor, including the v1 staging tree.
        func appendLeaves(_ parent: RepositoryDocumentCollection) {
            for child in children(parent) where child.isLeaf {
                lines += [""] + block(child, source: source, leaf: true)
                appendLeaves(child)
            }
        }
        appendLeaves(collection)
        return lines.joined(separator: "\n") + "\n"
    }

    private func block(_ collection: RepositoryDocumentCollection, source: String, leaf: Bool) -> [String] {
        let artifacts = catalog.artifacts.filter { $0.parentCollection == collection.collectionID }.sorted { $0.path < $1.path }
        let first = collection.firstRead.flatMap { id in catalog.artifacts.first { $0.artifactID == id } }
        let archive = collection.archiveDestination.flatMap { id in catalog.collections.first { $0.collectionID == id } }
        var lines = [
            "## \(leaf ? "Leaf collection" : "Collection"): \(text(collection.collectionID))",
            "",
            "- Path: \(link(collection.path, destination: collection.path, source: source))",
            "- Purpose: \(text(collection.purpose))",
            "- Allowed contents: \(collection.allowedContents.sorted().map(text).joined(separator: "; "))",
            "- Prohibited contents: \(collection.prohibitedContents.sorted().map(text).joined(separator: "; "))",
            "- First read: \(first.map { link($0.artifactID, destination: $0.path, source: source) } ?? "none")",
            "- Archive destination: \(archive.map { link($0.collectionID, destination: $0.path, source: source) } ?? "none")",
            "- Historical boundary: archived artifacts are non-authoritative.",
            "", "### Artifacts", "",
            "| ID | Path | Kind | Authority | Lifecycle | Supersedes | Superseded by |",
            "| --- | --- | --- | --- | --- | --- | --- |"
        ]
        for artifact in artifacts {
            let authority = artifact.authorityLevel.rawValue + (artifact.authorityRole.map { " (\($0))" } ?? "")
            let replacements = catalog.artifacts.filter { $0.supersedes.contains(artifact.artifactID) }.map(\.artifactID).sorted()
            lines.append("| \(text(artifact.artifactID)) | \(link(artifact.path, destination: artifact.path, source: source)) | \(artifact.kind.rawValue) | \(text(authority)) | \(artifact.lifecycle.rawValue) | \(relations(artifact.supersedes, source: source)) | \(relations(replacements, source: source)) |")
        }
        if artifacts.isEmpty { lines += ["", "No artifacts."] }
        lines += ["", "### Children", ""]
        let descendants = children(collection)
        if descendants.isEmpty {
            lines += [leaf ? "Leaf: no child collections." : "No child collections."]
        } else {
            for child in descendants {
                let target = child.isLeaf ? child.path : child.path + "/README.md"
                lines.append("- \(link(child.collectionID, destination: target, source: source)) — \(child.isLeaf ? "leaf" : "indexed"); \(text(child.purpose))")
            }
        }
        return lines
    }

    private func children(_ collection: RepositoryDocumentCollection) -> [RepositoryDocumentCollection] {
        catalog.collections.filter { $0.parentCollection == collection.collectionID }.sorted { $0.path < $1.path }
    }

    private func relations(_ ids: [String], source: String) -> String {
        if ids.isEmpty { return "none" }
        return ids.sorted().map { id in
            if let artifact = catalog.artifacts.first(where: { $0.artifactID == id }) {
                return link(id, destination: artifact.path, source: source)
            }
            return text(id) + " (retired)"
        }.joined(separator: ", ")
    }

    private func text(_ value: String) -> String {
        value.map { character in
            if "&<>[]()\\`*_|!:".contains(character), let scalar = character.unicodeScalars.first {
                return "&#\(scalar.value);"
            }
            return String(character)
        }.joined()
    }

    private func link(_ label: String, destination: String, source: String) -> String {
        var sourceParts = source.split(separator: "/").map(String.init)
        var targetParts = destination.split(separator: "/").map(String.init)
        while sourceParts.first == targetParts.first && !sourceParts.isEmpty && !targetParts.isEmpty {
            sourceParts.removeFirst(); targetParts.removeFirst()
        }
        let relative = (Array(repeating: "..", count: sourceParts.count) + targetParts).joined(separator: "/")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/")
        let encoded = (relative.isEmpty ? "." : relative).addingPercentEncoding(withAllowedCharacters: allowed)!
        return "[\(text(label))](\(encoded))"
    }
}

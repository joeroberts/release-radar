import Foundation
import Darwin

public enum ProjectGuidanceState: Equatable, Sendable {
    case missing
    case current(version: Int)
    case handoffIncomplete(version: Int)
    case outdated(installed: Int, current: Int)
    case needsRepair
    case unavailable
}

/// Catalog staging is an observation only. It never activates managed behavior.
public enum ProjectDocumentationState: Equatable, Sendable {
    case legacy(ProjectGuidanceState)
    case stagedCatalog(hasAuditedHandoff: Bool, preview: StagedCatalogPreview)

    public var guidanceState: ProjectGuidanceState {
        switch self {
        case let .legacy(state): state
        case let .stagedCatalog(audited, _):
            audited ? .current(version: RepositoryDocumentContract.legacyGuidanceVersion) : .handoffIncomplete(version: RepositoryDocumentContract.legacyGuidanceVersion)
        }
    }
}

public enum StagedCatalogPreview: Equatable, Sendable {
    case valid(version: Int, digest: String)
    case invalid(RepositoryDocumentError)
}

public struct ProjectGuidanceObservation: Equatable, Sendable {
    public let projectRoot: URL?
    public let documentationState: ProjectDocumentationState
    public var state: ProjectGuidanceState { documentationState.guidanceState }

    public init(projectRoot: URL?, state: ProjectGuidanceState) {
        self.projectRoot = projectRoot
        self.documentationState = .legacy(state)
    }

    public init(projectRoot: URL?, documentationState: ProjectDocumentationState) {
        self.projectRoot = projectRoot
        self.documentationState = documentationState
    }
}

public enum ProjectGuidanceInspection {
    public static func inspectDocumentation(rootURL: URL, hasAuditedHandoff: Bool = false) -> ProjectDocumentationState {
        let guidance = inspect(rootURL: rootURL, hasAuditedHandoff: hasAuditedHandoff)
        let version = RepositoryDocumentContract.legacyGuidanceVersion
        guard guidance == .current(version: version) || guidance == .handoffIncomplete(version: version) else {
            return .legacy(guidance)
        }
        do {
            let reader = try RepositoryDocumentReader(rootURL: rootURL, limits: .init(), afterRead: nil)
            do {
                _ = try reader.read(RepositoryDocumentContract.catalogPath, catalog: true)
            } catch let error as RepositoryDocumentError where error.code == .missingFile {
                // Only an absent catalog is legacy. Missing referenced artifacts below
                // remain an invalid staged preview, as do unsafe catalog components.
                return .legacy(guidance)
            }
            let snapshot = try RepositoryDocumentValidator().validateCurrent(reader: reader)
            return .stagedCatalog(hasAuditedHandoff: hasAuditedHandoff, preview: .valid(version: snapshot.version, digest: snapshot.digest))
        } catch let error as RepositoryDocumentError {
            return .stagedCatalog(hasAuditedHandoff: hasAuditedHandoff, preview: .invalid(error))
        } catch {
            return .stagedCatalog(hasAuditedHandoff: hasAuditedHandoff, preview: .invalid(.init(.readFailed)))
        }
    }

    public static let currentVersion = RepositoryDocumentContract.guidanceVersion
    public static let handoffEvidenceIDPrefix = RepositoryDocumentContract.handoffEvidenceIDPrefix
    public static let managedBlock = RepositoryDocumentContract.managedGuidanceBlock

    private static let startPrefix = RepositoryDocumentContract.guidanceStartPrefix
    private static let startSuffix = RepositoryDocumentContract.guidanceStartSuffix
    private static let endMarker = RepositoryDocumentContract.guidanceEndMarker

    public static func inspect(
        rootURL: URL,
        hasAuditedHandoff: Bool = false
    ) -> ProjectGuidanceState {
        let agentsURL = rootURL.appendingPathComponent(RepositoryDocumentContract.guidancePath, isDirectory: false)
        var metadata = stat()
        let status: Int32 = agentsURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return lstat(path, &metadata)
        }
        if status != 0 {
            return errno == ENOENT ? .missing : .unavailable
        }
        guard metadata.st_mode & S_IFMT == S_IFREG else { return .unavailable }
        guard
            let data = try? Data(contentsOf: agentsURL),
            let contents = String(data: data, encoding: .utf8)
        else { return .needsRepair }
        let guidanceState = inspect(contents: contents)
        guard case let .current(version) = guidanceState else { return guidanceState }
        return hasAuditedHandoff ? guidanceState : .handoffIncomplete(version: version)
    }

    public static func inspect(contents: String?) -> ProjectGuidanceState {
        guard let contents else { return .missing }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let starts = lines.indices.filter {
            lines[$0].hasPrefix(startPrefix) && lines[$0].hasSuffix(startSuffix)
        }
        let ends = lines.indices.filter { lines[$0] == endMarker }
        let markerLines = lines.indices.filter { lines[$0].contains(RepositoryDocumentContract.guidanceMarkerName) }
        guard !markerLines.isEmpty else {
            return .missing
        }
        guard markerLines.count == 2, starts.count == 1, ends.count == 1, starts[0] < ends[0] else {
            return .needsRepair
        }

        let startLine = lines[starts[0]]
        let versionStart = startLine.index(startLine.startIndex, offsetBy: startPrefix.count)
        let versionEnd = startLine.index(startLine.endIndex, offsetBy: -startSuffix.count)
        guard let installedVersion = Int(startLine[versionStart..<versionEnd]), installedVersion >= 0 else {
            return .needsRepair
        }
        guard installedVersion <= currentVersion else { return .needsRepair }
        guard installedVersion == currentVersion else {
            return .outdated(installed: installedVersion, current: currentVersion)
        }

        let observedBlock = lines[starts[0]...ends[0]].joined(separator: "\n")
        return observedBlock == managedBlock ? .current(version: currentVersion) : .needsRepair
    }
}

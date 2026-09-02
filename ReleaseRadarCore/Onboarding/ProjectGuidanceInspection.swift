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

/// Read-only observation. Only typed binding/catalog acceptance enables managed operations.
public enum ProjectDocumentationState: Equatable, Sendable {
    case legacy(ProjectGuidanceState)
    case stagedCatalog(hasAuditedHandoff: Bool, preview: StagedCatalogPreview)
    case managed(hasAuditedHandoff: Bool, catalogVersion: Int, catalogDigest: String)
    case managedUnavailable(hasAuditedHandoff: Bool, reason: DocumentationOperationError, validationError: RepositoryDocumentError.Code?)

    public var guidanceState: ProjectGuidanceState {
        switch self {
        case let .legacy(state): state
        case .stagedCatalog:
            .outdated(installed: RepositoryDocumentContract.legacyGuidanceVersion, current: RepositoryDocumentContract.guidanceVersion)
        case let .managed(audited, _, _), let .managedUnavailable(audited, _, _):
            audited ? .current(version: RepositoryDocumentContract.guidanceVersion) : .handoffIncomplete(version: RepositoryDocumentContract.guidanceVersion)
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
        inspectDocumentation(rootURL: rootURL, hasAuditedHandoff: hasAuditedHandoff, context: nil)
    }

    static func inspectDocumentation(rootURL: URL, hasAuditedHandoff: Bool, context: DocumentationRootContext?) -> ProjectDocumentationState {
        let guidance = inspect(rootURL: rootURL, hasAuditedHandoff: hasAuditedHandoff)
        let managed = guidance == .current(version: currentVersion) || guidance == .handoffIncomplete(version: currentVersion)
        let legacy = guidance == .outdated(installed: RepositoryDocumentContract.legacyGuidanceVersion, current: currentVersion)
        guard managed || legacy else { return .legacy(guidance) }
        do {
            let reader = try RepositoryDocumentReader(rootURL: rootURL, limits: .init(), afterRead: nil)
            if managed, try RepositoryDocumentationMode.read(reader) != .managedV2 { throw DocumentationOperationError.guidanceUnavailable }
            do {
                _ = try reader.read(RepositoryDocumentContract.catalogPath, catalog: true)
            } catch let error as RepositoryDocumentError where error.code == .missingFile && !managed {
                return .legacy(guidance)
            }
            let snapshot = try RepositoryDocumentValidator().validateCurrent(reader: reader)
            if managed {
                guard let context else { throw DocumentationOperationError.bindingMissing }
                guard context.root == rootURL else { throw DocumentationOperationError.rootMismatch }
                try context.requireAccepted(snapshot)
                return .managed(hasAuditedHandoff: hasAuditedHandoff, catalogVersion: snapshot.version, catalogDigest: snapshot.digest)
            }
            return .stagedCatalog(hasAuditedHandoff: hasAuditedHandoff, preview: .valid(version: snapshot.version, digest: snapshot.digest))
        } catch let error as RepositoryDocumentError {
            if managed { return .managedUnavailable(hasAuditedHandoff: hasAuditedHandoff, reason: .catalogInvalid, validationError: error.code) }
            return .stagedCatalog(hasAuditedHandoff: hasAuditedHandoff, preview: .invalid(error))
        } catch {
            if managed { return .managedUnavailable(hasAuditedHandoff: hasAuditedHandoff, reason: DocumentationCatalogContext.map(error), validationError: nil) }
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
        let observedBlock = lines[starts[0]...ends[0]].joined(separator: "\n")
        guard installedVersion == currentVersion else {
            if installedVersion == RepositoryDocumentContract.legacyGuidanceVersion,
               observedBlock != RepositoryDocumentContract.legacyManagedGuidanceBlock { return .needsRepair }
            return .outdated(installed: installedVersion, current: currentVersion)
        }
        return observedBlock == managedBlock ? .current(version: currentVersion) : .needsRepair
    }
}

import Foundation

public enum SharedExecutionCompatibilityState: String, Codable, Equatable, Sendable {
    case notDeclared
    case compatibleV1
    case compatibleOlder
    case updateAvailable
    case pendingCatalogAcceptance
    case incompatible
    case unavailable
    case rootUnknown
    case unknown
}

public enum SharedExecutionCompatibilityIssue: Equatable, Sendable {
    case declarationModified
    case declarationDuplicate
    case unsupportedDeclaredStandard
    case pluginModified
    case pluginUnrecognized
    case installedCapabilityUnsupported
    case checkerIncompatible
    case checkerFailed
    case repositoryInvalid
    case repositoryIdentityMismatch
}

public enum SharedExecutionAdoptionProgress: String, Codable, Equatable, Sendable {
    case workingTreeCandidate
    case committedCandidate
    case ledgerRecorded
    case unknown
}

public struct SharedExecutionDirectResult: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Equatable, Sendable {
        case passed
        case failed
        case skipped
        case unavailable
        case unknown
        case notRun
    }

    public enum Applicability: String, Codable, Equatable, Sendable {
        case exactRevision
        case workingTree
        case unknown
    }

    public let check: String
    public let runner: String
    public let scope: String
    public let source: String
    public let applicability: Applicability
    public let status: Status
    public let directResult: String
    public let limitation: String?

    public init(
        check: String,
        runner: String,
        scope: String,
        source: String,
        applicability: Applicability,
        status: Status,
        directResult: String,
        limitation: String?
    ) {
        self.check = check
        self.runner = runner
        self.scope = scope
        self.source = source
        self.applicability = applicability
        self.status = status
        self.directResult = directResult
        self.limitation = limitation
    }
}

public struct SharedExecutionRepositoryIdentity: Codable, Equatable, Sendable {
    public let repositoryID: String
    public let catalogVersion: Int
    public let catalogDigest: String

    public init(repositoryID: String, catalogVersion: Int, catalogDigest: String) {
        self.repositoryID = repositoryID
        self.catalogVersion = catalogVersion
        self.catalogDigest = catalogDigest
    }
}

public struct SharedExecutionCheckerResult: Equatable, Sendable {
    public let contractVersion: Int
    public let supportedCatalogVersions: [Int]
    public let target: SharedExecutionRepositoryIdentity?
    public let status: RepositoryDocumentDiagnostic.Status

    public init(
        contractVersion: Int,
        supportedCatalogVersions: [Int],
        target: SharedExecutionRepositoryIdentity?,
        status: RepositoryDocumentDiagnostic.Status
    ) {
        self.contractVersion = contractVersion
        self.supportedCatalogVersions = supportedCatalogVersions
        self.target = target
        self.status = status
    }

    public init(_ diagnostic: RepositoryDocumentDiagnostic) {
        contractVersion = diagnostic.checker.contractVersion
        supportedCatalogVersions = diagnostic.checker.supportedCatalogVersions
        if let repositoryID = diagnostic.target.repositoryID,
           let catalogVersion = diagnostic.target.catalogVersion,
           let catalogDigest = diagnostic.target.catalogDigest {
            target = .init(
                repositoryID: repositoryID,
                catalogVersion: catalogVersion,
                catalogDigest: catalogDigest
            )
        } else {
            target = nil
        }
        status = diagnostic.status
    }
}

public enum SharedExecutionRootObservation: Equatable, Sendable {
    case exact(String)
    case unavailable(String)
    case unknown
}

public enum SharedExecutionDeclarationObservation: Equatable, Sendable {
    case absent
    case exact(version: Int)
    case legacy(version: Int)
    case modified(version: Int?)
    case duplicate
    case unavailable(RepositoryDocumentError.Code)
    case unknown(RepositoryDocumentError.Code)
}

public enum SharedExecutionPluginObservation: Equatable, Sendable {
    case clean(installed: RecognizedPluginCapability, shipped: RecognizedPluginCapability)
    case absent
    case modified
    case unrecognized(manifestVersion: String, normalizedPackageDigest: String)
    case unavailable(String)
    case unknown(String)
}

public enum SharedExecutionCheckerObservation: Equatable, Sendable {
    case result(SharedExecutionCheckerResult)
    case incompatible(String)
    case unavailable(String)
    case unknown(String)
}

public enum SharedExecutionRepositoryObservation: Equatable, Sendable {
    case accepted(SharedExecutionRepositoryIdentity)
    case pendingAcceptance(SharedExecutionRepositoryIdentity)
    case identityMismatch
    case invalid(String)
    case unavailable(String)
    case unknown(String)
}

public struct SharedExecutionCompatibilityInput: Equatable, Sendable {
    public let root: SharedExecutionRootObservation
    public let declaration: SharedExecutionDeclarationObservation
    public let plugin: SharedExecutionPluginObservation
    public let checker: SharedExecutionCheckerObservation
    public let repository: SharedExecutionRepositoryObservation
    public let directResults: [SharedExecutionDirectResult]

    public init(
        root: SharedExecutionRootObservation,
        declaration: SharedExecutionDeclarationObservation,
        plugin: SharedExecutionPluginObservation,
        checker: SharedExecutionCheckerObservation,
        repository: SharedExecutionRepositoryObservation,
        directResults: [SharedExecutionDirectResult]
    ) {
        self.root = root
        self.declaration = declaration
        self.plugin = plugin
        self.checker = checker
        self.repository = repository
        self.directResults = directResults
    }
}

public struct SharedExecutionCompatibilityResult: Equatable, Sendable {
    public let state: SharedExecutionCompatibilityState
    public let directResults: [SharedExecutionDirectResult]
    public let issue: SharedExecutionCompatibilityIssue?

    public init(
        state: SharedExecutionCompatibilityState,
        directResults: [SharedExecutionDirectResult],
        issue: SharedExecutionCompatibilityIssue? = nil
    ) {
        self.state = state
        self.directResults = directResults
        self.issue = issue
    }
}

public enum SharedExecutionCompatibilityReducer {
    public static func reduce(_ input: SharedExecutionCompatibilityInput) -> SharedExecutionCompatibilityResult {
        let evaluation = evaluation(for: input)
        return .init(
            state: evaluation.state,
            directResults: input.directResults,
            issue: evaluation.issue
        )
    }

    private static func evaluation(
        for input: SharedExecutionCompatibilityInput
    ) -> (state: SharedExecutionCompatibilityState, issue: SharedExecutionCompatibilityIssue?) {
        switch input.root {
        case .unknown:
            return (.rootUnknown, nil)
        case .unavailable:
            return (.unavailable, nil)
        case let .exact(path) where path.isEmpty:
            return (.rootUnknown, nil)
        case .exact:
            break
        }

        let declaredVersion: Int
        switch input.declaration {
        case .absent:
            return (.notDeclared, nil)
        case let .exact(version), let .legacy(version):
            declaredVersion = version
        case .modified:
            return (.incompatible, .declarationModified)
        case .duplicate:
            return (.incompatible, .declarationDuplicate)
        case .unavailable:
            return (.unavailable, nil)
        case .unknown:
            return (.unknown, nil)
        }
        guard declaredVersion >= 0, declaredVersion <= SharedExecutionDeclarationInspector.currentVersion else {
            return (.incompatible, .unsupportedDeclaredStandard)
        }

        let installed: RecognizedPluginCapability
        let shipped: RecognizedPluginCapability
        switch input.plugin {
        case let .clean(installedCapability, shippedCapability):
            installed = installedCapability
            shipped = shippedCapability
        case .absent, .unavailable:
            return (.unavailable, nil)
        case .modified:
            return (.incompatible, .pluginModified)
        case .unrecognized:
            return (.incompatible, .pluginUnrecognized)
        case .unknown:
            return (.unknown, nil)
        }
        guard installed.sharedExecutionStandardVersions.contains(declaredVersion) else {
            return (.incompatible, .installedCapabilityUnsupported)
        }

        let checker: SharedExecutionCheckerResult
        switch input.checker {
        case let .result(result):
            checker = result
        case .incompatible:
            return (.incompatible, .checkerIncompatible)
        case .unavailable:
            return (.unavailable, nil)
        case .unknown:
            return (.unknown, nil)
        }
        guard checker.contractVersion == 1, checker.status == .passed else {
            return (.incompatible, .checkerFailed)
        }

        let repositoryIdentity: SharedExecutionRepositoryIdentity
        let pendingAcceptance: Bool
        switch input.repository {
        case let .accepted(identity):
            repositoryIdentity = identity
            pendingAcceptance = false
        case let .pendingAcceptance(identity):
            repositoryIdentity = identity
            pendingAcceptance = true
        case .identityMismatch:
            return (.incompatible, .repositoryIdentityMismatch)
        case .invalid:
            return (.incompatible, .repositoryInvalid)
        case .unavailable:
            return (.unavailable, nil)
        case .unknown:
            return (.unknown, nil)
        }
        guard checker.supportedCatalogVersions.contains(repositoryIdentity.catalogVersion),
              checker.target == repositoryIdentity else {
            return (.incompatible, .repositoryIdentityMismatch)
        }
        if pendingAcceptance {
            return (.pendingCatalogAcceptance, nil)
        }

        let installedNewest = installed.sharedExecutionStandardVersions.max() ?? -1
        let shippedNewest = shipped.sharedExecutionStandardVersions.max() ?? -1
        if shippedNewest > installedNewest {
            return (.updateAvailable, nil)
        }
        return (
            declaredVersion < SharedExecutionDeclarationInspector.currentVersion
                ? .compatibleOlder
                : .compatibleV1,
            nil
        )
    }
}

public enum SharedExecutionDeclarationInspector {
    public static let currentVersion = 1
    public static let markerName = "release-radar-shared-execution"
    public static let startPrefix = "<!-- \(markerName):v"
    public static let startSuffix = ":start -->"
    public static let endMarker = "<!-- \(markerName):end -->"
    public static let managedBlock = """
    <!-- release-radar-shared-execution:v1:start -->
    ## Shared execution integration

    For authorized implementation or substantive review work, invoke the installed
    `$release-radar:shared-execution` skill and apply shared-execution standard v1.
    This repository's explicit owner authorization, controlling product and architecture
    documents, and delivery ledger remain authoritative. The shared standard supplies
    bounded context, repository-native check reporting, and compatibility diagnostics
    only; it cannot grant authority, accept work, identify an independent reviewer,
    change delivery state, or trigger installation, trust, permissions, publication,
    or any other action. If the skill is missing, modified, incompatible, or unavailable,
    report that state and use only this repository's own governing instructions. The
    repository must independently retain its requirements for material independent
    review, explicit owner acceptance and external effects, and material safety and
    recovery. If those local fallbacks do not cover every removed required clause, stop
    the affected material work; unrelated read-only and product work may continue under
    the local instructions.
    <!-- release-radar-shared-execution:end -->
    """

    public static func inspect(contents: String?) -> SharedExecutionDeclarationObservation {
        guard let contents else { return .absent }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let starts = lines.indices.filter { lines[$0].hasPrefix(startPrefix) && lines[$0].hasSuffix(startSuffix) }
        let ends = lines.indices.filter { lines[$0] == endMarker }
        let markers = lines.indices.filter { lines[$0].contains(markerName) }
        guard !markers.isEmpty else { return .absent }
        if starts.count > 1 || ends.count > 1 { return .duplicate }
        guard markers.count == 2, starts.count == 1, ends.count == 1, starts[0] < ends[0] else {
            return .modified(version: nil)
        }
        let start = lines[starts[0]]
        let versionStart = start.index(start.startIndex, offsetBy: startPrefix.count)
        let versionEnd = start.index(start.endIndex, offsetBy: -startSuffix.count)
        guard let version = Int(start[versionStart..<versionEnd]), version >= 0 else {
            return .modified(version: nil)
        }
        let observed = lines[starts[0]...ends[0]].joined(separator: "\n")
        if version == currentVersion {
            return observed == managedBlock ? .exact(version: version) : .modified(version: version)
        }
        return version < currentVersion ? .legacy(version: version) : .modified(version: version)
    }

    public static func inspect(
        rootURL: URL,
        limits: RepositoryDocumentContract.Limits = .init(),
        afterRead: ((String) -> Void)? = nil
    ) -> SharedExecutionDeclarationObservation {
        do {
            let reader = try RepositoryDocumentReader(rootURL: rootURL, limits: limits, afterRead: afterRead)
            let data = try reader.read(RepositoryDocumentContract.guidancePath)
            guard let contents = String(data: data, encoding: .utf8) else {
                return .unavailable(.invalidUTF8)
            }
            let result = inspect(contents: contents)
            try reader.verifyStable()
            return result
        } catch let error as RepositoryDocumentError {
            switch error.code {
            case .missingFile:
                return .absent
            case .changedDuringRead:
                return .unknown(.changedDuringRead)
            default:
                return .unavailable(error.code)
            }
        } catch {
            return .unavailable(.readFailed)
        }
    }
}

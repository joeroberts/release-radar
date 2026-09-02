import Foundation

/// The caller must keep authorization to its resolved project root alive for the whole validation.
public enum RepositoryDocumentContract {
    public static let catalogVersion = 1
    public static let catalogPath = "docs/catalog.json"
    public static let rootIndexPath = "docs/README.md"
    public static let guidancePath = "AGENTS.md"
    public static let progressPath = "docs/delivery/progress.md"
    public static let managedIndexStart = "<!-- release-radar-docs:v1:start -->"
    public static let managedIndexEnd = "<!-- release-radar-docs:end -->"

    public struct Limits: Sendable {
        public let maximumCatalogBytes: Int
        public let maximumFileBytes: Int
        public let maximumArtifactCount: Int
        public let maximumCollectionCount: Int
        public let maximumTotalBytes: Int
        public let maximumPathBytes: Int
        public let maximumDepth: Int

        public init(maximumCatalogBytes: Int = 4 * 1_024 * 1_024,
                    maximumFileBytes: Int = 32 * 1_024 * 1_024,
                    maximumArtifactCount: Int = 10_000,
                    maximumCollectionCount: Int = 2_000,
                    maximumTotalBytes: Int = 256 * 1_024 * 1_024,
                    maximumPathBytes: Int = 1_024,
                    maximumDepth: Int = 32) {
            self.maximumCatalogBytes = maximumCatalogBytes
            self.maximumFileBytes = maximumFileBytes
            self.maximumArtifactCount = maximumArtifactCount
            self.maximumCollectionCount = maximumCollectionCount
            self.maximumTotalBytes = maximumTotalBytes
            self.maximumPathBytes = maximumPathBytes
            self.maximumDepth = maximumDepth
        }
    }
}

public struct RepositoryDocumentCatalog: Codable, Equatable, Sendable {
    public let version: Int
    public let repositoryID: String
    public let retiredArtifactIDs: [String]
    public let collections: [RepositoryDocumentCollection]
    public let artifacts: [RepositoryDocumentArtifact]
    public let transitionalSubtree: RepositoryDocumentTransitionalSubtree?
}

public struct RepositoryDocumentArtifact: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case document, collectionIndex, designAsset, verificationEvidence, checksumManifest
    }
    public enum Lifecycle: String, Codable, Sendable { case proposed, active, completed, superseded, archived }
    public enum Authority: String, Codable, Sendable { case controlling, supporting, nonAuthoritative }
    public enum Sensitivity: String, Codable, Sendable { case guidance, importer, evidence, prompt, fixture, none }
    public struct Checksum: Codable, Equatable, Sendable {
        public enum Policy: String, Codable, Sendable { case required, notApplicable }
        public let policy: Policy
        public let manifestArtifactID: String?
    }
    public let artifactID: String
    public let path: String
    public let kind: Kind
    public let lifecycle: Lifecycle
    public let authorityLevel: Authority
    public let authorityRole: String?
    public let parentCollection: String
    public let supersedes: [String]
    public let applicationSensitivity: [Sensitivity]
    public let checksum: Checksum
}

public struct RepositoryDocumentCollection: Codable, Equatable, Sendable {
    public let collectionID: String
    public let path: String
    public let parentCollection: String?
    public let purpose: String
    public let allowedContents: [String]
    public let prohibitedContents: [String]
    public let firstRead: String?
    public let indexArtifactID: String?
    public let isLeaf: Bool
    public let archiveDestination: String?
}

/// The sole v1 staging exception: the existing superpowers plans/specs tree is
/// enumerated directly from the root index, with a frozen artifact membership.
public struct RepositoryDocumentTransitionalSubtree: Codable, Equatable, Sendable {
    public let path: String
    public let indexedAncestor: String
    public let collectionIDs: [String]
    public let artifactIDs: [String]
}

public struct RepositoryDocumentSnapshot: Equatable, Sendable {
    public let catalog: RepositoryDocumentCatalog
    public let canonicalCatalog: Data
    public let digest: String
    public var version: Int { catalog.version }
}

public struct RepositoryDocumentError: Error, Equatable, Sendable, LocalizedError {
    public enum Code: String, Sendable {
        case malformedCatalog, unsupportedVersion, invalidUTF8, missingFile
        case invalidIdentity, duplicateIdentity, duplicatePath, invalidAuthority, conflictingController
        case supersessionCycle, missingReplacement, invalidCollection, retiredIdentity
        case unsafePath, unsafeFileType, prohibitedContent, uncataloguedFile
        case checksumMismatch, brokenLink, archivedReference, limitExceeded, changedDuringRead
        case repositoryIdentityChanged, controllingDeletion, invalidTransition, invalidTransitionalSubtree
        case readFailed
    }
    public let code: Code
    public let artifactPath: String?
    init(_ code: Code, path: String? = nil) {
        self.code = code
        // Never reflect unsafe input, absolute owner paths, or arbitrary file contents.
        self.artifactPath = path.flatMap {
            $0.hasPrefix("docs/") && $0.utf8.count <= 1_024 && !$0.contains("..") && !$0.contains("%")
                && !$0.contains("\\") && !$0.unicodeScalars.contains(where: { $0.value < 32 }) ? $0 : nil
        }
    }
    public var errorDescription: String? {
        "Repository documentation validation failed (\(code.rawValue))\(artifactPath.map { " at \($0)" } ?? ""). Repair the catalog or artifact and retry."
    }
}

import Foundation

/// The caller must keep authorization to its resolved project root alive for the whole validation.
public enum RepositoryDocumentContract {
    public static let catalogVersion = 1
    public static let legacyGuidanceVersion = 1
    public static let guidanceVersion = 2
    public static let rekonSeedVersion = 1
    public static let catalogPath = "docs/catalog.json"
    public static let rootIndexPath = "docs/README.md"
    public static let guidancePath = "AGENTS.md"
    public static let progressPath = "docs/delivery/progress.md"
    public static let rekonSeedPath = "docs/delivery/dashboard-status.json"
    public static let deliveryCollectionPath = "docs/delivery"
    public static let taskBriefCollectionPath = "docs/delivery/task-briefs"
    public static let handoffCollectionPath = "docs/delivery/handoffs"
    public static let reviewCollectionPath = "docs/delivery/reviews"
    public static let evidenceCollectionPath = "docs/delivery/evidence"
    public static let planCollectionPath = "docs/delivery/plans"
    public static let archiveCollectionPath = "docs/delivery/archive"
    public static let rekonRoadmapPath = "docs/delivery/roadmap.md"
    public static let rekonEvidenceBasePath = "docs/delivery/dashboard"
    public static let managedIndexStart = "<!-- release-radar-docs:v1:start -->"
    public static let managedIndexEnd = "<!-- release-radar-docs:end -->"
    public static let guidanceMarkerName = "release-radar-guidance"
    public static let guidanceStartPrefix = "<!-- \(guidanceMarkerName):v"
    public static let guidanceStartSuffix = ":start -->"
    public static let guidanceStartMarker = "\(guidanceStartPrefix)\(guidanceVersion)\(guidanceStartSuffix)"
    public static let guidanceEndMarker = "<!-- \(guidanceMarkerName):end -->"
    // Evidence identity survives guidance upgrades; this is an identity namespace, not the installed guidance version.
    public static let handoffEvidenceIDPrefix = "release-radar-handoff:v1:"
    public static let legacyManagedGuidanceBlock = """
    <!-- release-radar-guidance:v1:start -->
    ## Release Radar tracking

    This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

    - `\(progressPath)` is the repository's durable delivery source of truth.
    - Codex may update repository tracking documents under owner authorization.
    - Release Radar is the only writer of its SQLite database. Use its existing typed MCP mutations; never edit that database directly.
    - Do not claim synchronization without both a successful audited MCP result and direct readback of the corresponding repository files.
    - Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state.
    \(guidanceEndMarker)
    """

    public static let managedGuidanceBlock = """
    \(guidanceStartMarker)
    ## Release Radar tracking

    This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

    - Read `\(catalogPath)` and begin documentation discovery at `\(rootIndexPath)`. Follow generated local indexes before broad search and load only task-relevant controlling artifacts.
    - The catalog owns documentation identity, lifecycle, authority, and navigation. `\(progressPath)` remains the durable delivery source of truth; the catalog and indexes never authorize or infer ticket or phase state.
    - Under owner authorization, update the catalog, collection/index metadata, active references, and applicable checksums in the same change as any durable add, move, rename, supersession, closeout, restoration, or deletion. Preserve stable artifact IDs and never reuse retired IDs.
    - Keep only active operational detail in `\(progressPath)`; move closed detail to `\(archiveCollectionPath)/` and label it historical and non-authoritative. Place implementation plans in `\(planCollectionPath)/` and controlling task briefs in `\(taskBriefCollectionPath)/`.
    - Add no new content under `docs/superpowers/` during transition and never recreate it after cutover.
    - Release Radar is the only SQLite writer. Never edit that database or repair a managed evidence path directly. Use supported read-only inventory and typed, audited evidence operations with exact artifact IDs and request identities.
    - Managed operations require the exact authorized root and accepted repository ID, catalog version, and digest. Only explicit repository binding establishes a missing binding; only catalog acceptance advances an accepted snapshot. Treat a changed catalog as pending until Release Radar accepts its validated transition.
    - Run the repository documentation check and read back the resulting repository and application state before completion. Do not claim completion while catalog, indexes, lifecycle, authority, references, applicable checksums, evidence resolution, or application readback disagree. Preserve exact requests across uncertain outcomes.
    - Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state. Repository-local rules outside this block may narrow this contract but must not weaken or duplicate it.
    \(guidanceEndMarker)
    """

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
    public enum Code: String, Codable, Sendable {
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

import CryptoKit
import Foundation

public struct RepositoryPlanSourceOption: Codable, Equatable, Identifiable, Sendable {
    public let artifactID: String
    public let path: String
    public let contentSHA256: String
    public let lifecycle: RepositoryDocumentArtifact.Lifecycle
    public let authority: RepositoryDocumentArtifact.Authority

    public var id: String { artifactID }

    public init(
        artifactID: String,
        path: String,
        contentSHA256: String,
        lifecycle: RepositoryDocumentArtifact.Lifecycle,
        authority: RepositoryDocumentArtifact.Authority
    ) {
        self.artifactID = artifactID
        self.path = path
        self.contentSHA256 = contentSHA256
        self.lifecycle = lifecycle
        self.authority = authority
    }
}

public struct RepositoryPlanSourceInventory: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let rootID: String
    public let registration: ProjectRegistration
    public let repositoryID: String
    public let acceptedCatalogVersion: Int
    public let acceptedCatalogDigest: String
    public let sources: [RepositoryPlanSourceOption]

    public init(
        projectID: ProjectID,
        rootID: String,
        registration: ProjectRegistration,
        repositoryID: String,
        acceptedCatalogVersion: Int,
        acceptedCatalogDigest: String,
        sources: [RepositoryPlanSourceOption]
    ) {
        self.projectID = projectID
        self.rootID = rootID
        self.registration = registration
        self.repositoryID = repositoryID
        self.acceptedCatalogVersion = acceptedCatalogVersion
        self.acceptedCatalogDigest = acceptedCatalogDigest
        self.sources = sources
    }
}

/// Reads the accepted documentation catalog through an already-authorized
/// project root. The persisted registration, root and accepted catalog are
/// rechecked after filesystem access so callers never present stale choices or
/// captured bytes as current.
public enum RepositoryPlanSourceSelection {
    public static func availableSources(
        from store: DeliveryStore,
        project: AuthorizedProject
    ) async throws -> RepositoryPlanSourceInventory {
        let context = try await currentContext(from: store, project: project)
        let catalog = try DocumentationCatalogContext(root: context.root)
        let snapshot = try catalog.managedSnapshot()
        try context.requireAccepted(snapshot)

        let sources = try snapshot.catalog.artifacts.map { artifact in
            RepositoryPlanSourceOption(
                artifactID: artifact.artifactID,
                path: artifact.path,
                contentSHA256: digest(try catalog.reader.read(artifact.path)),
                lifecycle: artifact.lifecycle,
                authority: artifact.authorityLevel
            )
        }
        try catalog.reader.verifyStable()
        try await requireCurrent(context, in: store)
        let sorted = sources.sorted {
            Data($0.path.utf8).lexicographicallyPrecedes(Data($1.path.utf8))
        }
        guard let registration = context.registration, let binding = context.binding else {
            throw DocumentationOperationError.staleRegistration
        }
        return .init(
            projectID: registration.projectID,
            rootID: context.rootID,
            registration: registration,
            repositoryID: binding.repositoryID,
            acceptedCatalogVersion: binding.acceptedCatalogVersion,
            acceptedCatalogDigest: binding.acceptedCatalogDigest,
            sources: sorted
        )
    }

    public static func capture(
        artifactIDs: [String],
        from store: DeliveryStore,
        project: AuthorizedProject
    ) async throws -> RepositoryPlanSourceManifest {
        let context = try await currentContext(from: store, project: project)
        let manifest = try RepositoryPlanSourceCapture.capture(
            context: context,
            artifactIDs: artifactIDs
        )
        try await requireCurrent(context, in: store)
        return manifest
    }

    private static func currentContext(
        from store: DeliveryStore,
        project: AuthorizedProject
    ) async throws -> DocumentationRootContext {
        guard let registration = project.registration else {
            throw DocumentationOperationError.staleRegistration
        }
        let context = try await store.read { connection in
            try DocumentationRootContext.read(
                connection,
                path: project.canonicalRoot.path,
                projectID: project.projectID.rawValue,
                schemaVersion: store.schemaVersionForDocumentation
            )
        }
        guard context.registration == registration,
              context.root.path == project.canonicalRoot.path else {
            throw DocumentationOperationError.staleRegistration
        }
        return context
    }

    private static func requireCurrent(
        _ context: DocumentationRootContext,
        in store: DeliveryStore
    ) async throws {
        try await store.read { connection in
            try context.verifyPersisted(connection)
        }
    }

    private static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

/// Captures only owner-selected catalog artifacts from the already authorized
/// repository root. Callers retain responsibility for keeping bookmark access
/// alive and rechecking the persisted root context around later operations.
struct RepositoryPlanSourceCapture {
    static func capture(
        context: DocumentationRootContext,
        artifactIDs: [String]
    ) throws -> RepositoryPlanSourceManifest {
        guard let registration = context.registration,
              registration.projectID.rawValue == context.projectID,
              let binding = context.binding,
              binding.projectID.rawValue == context.projectID,
              binding.rootID.rawValue == context.rootID,
              !artifactIDs.isEmpty else {
            throw DocumentationOperationError.invalidRequest
        }

        var selectedIDs = Set<Data>()
        for artifactID in artifactIDs {
            guard validIdentity(artifactID), selectedIDs.insert(Data(artifactID.utf8)).inserted else {
                throw DocumentationOperationError.invalidRequest
            }
        }

        let catalog = try DocumentationCatalogContext(root: context.root)
        let snapshot = try catalog.managedSnapshot()
        try context.requireAccepted(snapshot)

        var sources: [RepositoryPlanCapturedSource] = []
        sources.reserveCapacity(artifactIDs.count)
        for artifactID in artifactIDs {
            guard let artifact = snapshot.catalog.artifacts.first(where: {
                Data($0.artifactID.utf8) == Data(artifactID.utf8)
            }) else {
                throw DocumentationOperationError.missingFile
            }
            let bytes = try catalog.reader.read(artifact.path)
            sources.append(.init(
                artifactID: artifact.artifactID,
                path: artifact.path,
                contentSHA256: digest(bytes),
                lifecycle: artifact.lifecycle,
                authority: artifact.authorityLevel,
                bytes: bytes
            ))
        }

        try catalog.reader.verifyStable()
        return .init(
            projectID: registration.projectID,
            rootID: context.rootID,
            rootPath: context.root.path,
            registration: registration,
            repositoryID: binding.repositoryID,
            acceptedCatalogVersion: binding.acceptedCatalogVersion,
            acceptedCatalogDigest: binding.acceptedCatalogDigest,
            sources: sources
        )
    }

    private static func validIdentity(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256
            && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    private static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

/// Verifies an app-materialized preparation snapshot through the same
/// descriptor-relative, no-follow reader used for repository capture.
public enum RepositoryPlanSourceSnapshot {
    public static func verify(
        rootURL: URL,
        manifest: RepositoryPlanSourceManifest
    ) throws {
        let reader = try RepositoryDocumentReader(
            rootURL: rootURL,
            limits: .init(),
            afterRead: nil
        )
        let expectedFiles = Set(manifest.sources.map { "input/" + $0.path })
        var expectedDirectories: Set<String> = ["input", "session"]
        for file in expectedFiles {
            let components = file.split(separator: "/").map(String.init)
            guard components.count > 1 else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            var path = components[0]
            for component in components.dropFirst().dropLast() {
                path += "/" + component
                expectedDirectories.insert(path)
            }
        }
        let inventory = try reader.inventory(rootDirectories: ["input", "session"])
        guard inventory.files == expectedFiles,
              inventory.directories == expectedDirectories else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        for source in manifest.sources {
            let bytes = try reader.read("input/" + source.path)
            guard bytes == source.bytes else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
        }
        try reader.verifyStable()
    }
}

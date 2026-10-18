import CryptoKit
import Foundation

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

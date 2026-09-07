import Foundation

public enum ProjectDocumentationSetupAction: Equatable, Sendable {
    case bind
    case accept(priorCatalogVersion: Int, priorCatalogDigest: String)
    case current
}

public struct ProjectDocumentationSetupPreview: Equatable, Sendable {
    public let registration: ProjectRegistration
    public let rootPath: String
    public let target: DocumentationTarget
    public let action: ProjectDocumentationSetupAction

    public init(
        registration: ProjectRegistration,
        rootPath: String,
        target: DocumentationTarget,
        action: ProjectDocumentationSetupAction
    ) {
        self.registration = registration
        self.rootPath = rootPath
        self.target = target
        self.action = action
    }
}

public enum ProjectDocumentationSetupError: Error, LocalizedError, Equatable, Sendable {
    case staleRegistration
    case catalogUnavailable
    case bindingMismatch
    case command(AgentCommandError)

    public var errorDescription: String? {
        switch self {
        case .staleRegistration: "This documentation request is stale. Reload Project Health before retrying."
        case .catalogUnavailable: "The repository catalog is not ready. Complete the copied Codex bootstrap and check the repository first."
        case .bindingMismatch: "The saved documentation binding targets a different repository or project root. Recover that binding before accepting a catalog."
        case let .command(error): "The documentation action was not committed: \(String(describing: error))."
        }
    }
}

public actor ProjectDocumentationSetupCoordinator {
    private let store: DeliveryStore
    private let bookmarkStore: any ProjectBookmarkStoring

    public init(
        store: DeliveryStore,
        bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()
    ) {
        self.store = store
        self.bookmarkStore = bookmarkStore
    }

    public func preview(registration: ProjectRegistration) async throws -> ProjectDocumentationSetupPreview {
        try await requireCurrent(registration)
        let (authorization, snapshot) = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: bookmarkStore
        ).withReadOnlyAuthorizedProject(projectID: registration.projectID) { authorization in
            do {
                let snapshot = try RepositoryDocumentValidator().validateCurrent(
                    authorizedRoot: authorization.canonicalRoot
                )
                return (authorization, snapshot)
            } catch {
                throw ProjectDocumentationSetupError.catalogUnavailable
            }
        }
        let persisted = try await store.read { connection in
            let rootID = try connection.scalarText(
                "SELECT id FROM project_roots WHERE project_id = ? AND path = ?",
                bindings: [.text(registration.projectID.rawValue), .text(authorization.canonicalRoot.path)]
            )
            let binding = try DocumentationRootContext.binding(
                connection,
                projectID: registration.projectID.rawValue,
                version: Int(StoreMigrations.currentVersion)
            )
            return (rootID, binding)
        }
        guard let rootID = persisted.0 else { throw ProjectDocumentationSetupError.catalogUnavailable }
        let target = DocumentationTarget(
            projectID: registration.projectID.rawValue,
            rootID: rootID,
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest
        )
        let action: ProjectDocumentationSetupAction
        if let binding = persisted.1 {
            guard binding.repositoryID == target.repositoryID,
                  binding.rootID.rawValue == target.rootID else {
                throw ProjectDocumentationSetupError.bindingMismatch
            }
            if binding.acceptedCatalogVersion == target.catalogVersion,
               binding.acceptedCatalogDigest == target.catalogDigest {
                action = .current
            } else {
                action = .accept(
                    priorCatalogVersion: binding.acceptedCatalogVersion,
                    priorCatalogDigest: binding.acceptedCatalogDigest
                )
            }
        } else {
            action = .bind
        }
        return .init(
            registration: registration,
            rootPath: authorization.canonicalRoot.path,
            target: target,
            action: action
        )
    }

    public func perform(_ preview: ProjectDocumentationSetupPreview) async throws -> AuditEventID? {
        try await requireCurrent(preview.registration)
        let current = try await self.preview(registration: preview.registration)
        guard current == preview else { throw ProjectDocumentationSetupError.staleRegistration }
        let command: AgentCommand
        switch preview.action {
        case .bind:
            command = .bindDocumentationRepository(target: preview.target)
        case let .accept(priorVersion, priorDigest):
            command = .acceptDocumentationCatalog(
                target: preview.target,
                priorCatalogVersion: priorVersion,
                priorCatalogDigest: priorDigest
            )
        case .current:
            return nil
        }
        let envelope = AgentCommandEnvelope(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: preview.rootPath,
            reason: "Owner-confirmed project documentation setup",
            command: command
        )
        let body = try JSONEncoder().encode(envelope)
        let result = await DocumentationCommandDispatcher(
            store: store,
            bookmarkStore: bookmarkStore
        ).dispatch(envelope, requestBody: body, origin: .ownerApp, admissionDeadline: nil)
        if let error = result.error { throw ProjectDocumentationSetupError.command(error) }
        return result.auditEventID
    }

    private func requireCurrent(_ registration: ProjectRegistration) async throws {
        let matches = try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM project_registrations WHERE project_id = ? AND registration_id = ? AND request_generation = ? AND setup_state = 'complete'",
                bindings: [
                    .text(registration.projectID.rawValue),
                    .text(registration.registrationID),
                    .integer(registration.requestGeneration),
                ]
            ) == 1
        }
        guard matches else { throw ProjectDocumentationSetupError.staleRegistration }
    }
}

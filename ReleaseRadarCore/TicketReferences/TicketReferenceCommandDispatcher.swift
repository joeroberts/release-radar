import Foundation

struct TicketReferenceCommandDispatcher: Sendable {
    let store: DeliveryStore
    let bookmarkStore: any ProjectBookmarkStoring

    func dispatch(
        _ envelope: AgentCommandEnvelope,
        requestBody: Data,
        origin: AgentCommandOrigin,
        admissionDeadline: TimeInterval?,
        expectedRegistration: ProjectRegistration?
    ) async -> AgentCommandResult {
        do {
            guard let identity = envelope.command.ticketReferenceProjectAndRoot,
                  let ids = envelope.command.ticketReferenceIDs else {
                throw DocumentationOperationError.invalidRequest
            }
            let context = try await store.documentationRead {
                try DocumentationRootContext.read(
                    $0,
                    path: envelope.projectRoot,
                    projectID: identity.projectID,
                    rootID: identity.rootID,
                    schemaVersion: Int(StoreMigrations.currentVersion)
                )
            }
            let receiptBody = requestBody
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: context.bookmark) { resolved in
                try context.verifyAuthorization(resolved)
                if let replay = try await store.documentationRead({ connection in
                    try Self.requireCurrentAuthorization(
                        projectID: identity.projectID,
                        registration: expectedRegistration,
                        connection: connection
                    )
                    return try Self.replay(
                        connection,
                        requestID: envelope.requestID,
                        body: receiptBody,
                        registration: expectedRegistration
                    )
                }) {
                    return replay
                }

                let prepared = try Self.prepare(envelope.command, context: context)
                let auditID = AuditEventID(rawValue: UUID().uuidString)
                let actor: DeliveryActor = origin == .ownerApp
                    ? .init(id: "release-radar-owner")
                    : .init(
                        id: "release-radar-agent",
                        threadID: envelope.assertedThreadID,
                        threadAttribution: envelope.assertedThreadID == nil ? ThreadAttribution.none : .asserted
                    )
                do {
                    return try await store.transact(
                        actor: actor,
                        reason: envelope.reason,
                        auditEventID: auditID,
                        auditScope: .init(
                            projectID: .init(rawValue: identity.projectID),
                            entityType: .ticketReference,
                            entityID: ids.linkID
                        )
                    ) { connection in
                        if let admissionDeadline,
                           admissionDeadline <= Date().timeIntervalSince1970 {
                            throw TicketReferenceControl.expired
                        }
                        try Self.requireCurrentAuthorization(
                            projectID: identity.projectID,
                            registration: expectedRegistration,
                            connection: connection
                        )
                        if let replay = try Self.replay(
                            connection,
                            requestID: envelope.requestID,
                            body: receiptBody,
                            registration: expectedRegistration
                        ) {
                            throw TicketReferenceControl.replay(replay)
                        }
                        try context.verifyPersisted(connection)
                        let current = try Self.prepare(envelope.command, context: context)
                        guard current == prepared else {
                            throw DocumentationOperationError.catalogUnaccepted
                        }
                        let revision = try Self.apply(
                            envelope.command,
                            prepared: current,
                            retirementReason: envelope.reason,
                            context: context,
                            connection: connection
                        )
                        let result = AgentCommandResult(
                            entityIDs: [ids.ticketID, ids.linkID],
                            auditEventID: auditID,
                            error: nil,
                            ticketReferenceLinkSetRevision: revision
                        )
                        let resultData = try JSONEncoder().encode(result)
                        try connection.execute(
                            "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at, registration_project_id, registration_id, request_generation) VALUES (?, ?, ?, ?, ?, ?, ?)",
                            bindings: [
                                .text(envelope.requestID.uuidString),
                                .blob(receiptBody),
                                .blob(resultData),
                                .text(Self.timestamp()),
                            ] + ProjectLifecycleManager.receiptScopeBindings(expectedRegistration)
                        )
                        return result
                    }
                } catch let TicketReferenceControl.replay(result) {
                    return result
                }
            }
        } catch TicketReferenceControl.requestIDReused {
            return .init(entityIDs: [], auditEventID: nil, error: .requestIDReused)
        } catch TicketReferenceControl.expired {
            return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
        } catch let error as TicketReferenceMutationError {
            return .init(entityIDs: [], auditEventID: nil, error: Self.map(error))
        } catch let error as DocumentationOperationError {
            return .init(entityIDs: [], auditEventID: nil, error: .documentation(error))
        } catch let error as StoreError {
            if case .unavailable = error {
                return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
            }
            return .init(entityIDs: [], auditEventID: nil, error: .internalFailure(error.localizedDescription))
        } catch {
            return .init(entityIDs: [], auditEventID: nil, error: .documentation(DocumentationCatalogContext.map(error)))
        }
    }

    private struct PreparedSource: Equatable, Sendable {
        let repositoryID: String
        let artifactID: String
        let contentDigest: String
        let catalogVersion: Int
        let catalogDigest: String
        let path: String
        let lifecycle: RepositoryDocumentArtifact.Lifecycle
        let authority: RepositoryDocumentArtifact.Authority
    }

    private static func prepare(
        _ command: AgentCommand,
        context: DocumentationRootContext
    ) throws -> PreparedSource? {
        guard case let .upsertTicketReference(target, _, _, _, artifactID, _, _, expectedContentDigest, _) = command else {
            guard case .retireTicketReference = command else {
                throw DocumentationOperationError.invalidRequest
            }
            return nil
        }
        let catalog = try DocumentationCatalogContext(root: context.root)
        let snapshot = try catalog.managedSnapshot(target: target)
        try context.requireAccepted(snapshot)
        guard let artifact = snapshot.catalog.artifacts.first(where: { $0.artifactID == artifactID }),
              artifact.lifecycle == .active,
              artifact.authorityLevel == .controlling else {
            throw TicketReferenceMutationError.sourceNotAuthoritative
        }
        let bytes = try catalog.reader.read(artifact.path)
        try catalog.reader.verifyStable()
        guard documentationDigest(bytes) == expectedContentDigest else {
            throw DocumentationOperationError.staleEvidence
        }
        return .init(
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            artifactID: artifact.artifactID,
            contentDigest: documentationDigest(bytes),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest,
            path: artifact.path,
            lifecycle: artifact.lifecycle,
            authority: artifact.authorityLevel
        )
    }

    private static func apply(
        _ command: AgentCommand,
        prepared: PreparedSource?,
        retirementReason: String,
        context: DocumentationRootContext,
        connection: SQLiteConnection
    ) throws -> Int64 {
        let ids = command.ticketReferenceIDs!
        guard let ticket = try connection.row(
            "SELECT lane FROM tickets WHERE project_id = ? AND id = ?",
            bindings: [.text(context.projectID), .text(ids.ticketID)]
        ) else {
            throw TicketReferenceMutationError.notFound
        }
        if ticket["lane"] == .text(TicketLane.accepted.rawValue) {
            throw TicketReferenceMutationError.ticketAccepted
        }
        let currentRevision = try connection.scalarInt(
            "SELECT revision FROM ticket_reference_link_sets WHERE project_id = ? AND ticket_id = ?",
            bindings: [.text(context.projectID), .text(ids.ticketID)]
        ) ?? 0
        let expectedRevision: Int64 = switch command {
        case let .upsertTicketReference(_, _, _, _, _, _, _, _, value): value
        case let .retireTicketReference(_, _, _, _, _, value): value
        default: throw DocumentationOperationError.invalidRequest
        }
        guard currentRevision == expectedRevision else {
            throw TicketReferenceMutationError.linkSetRevisionConflict(
                expected: expectedRevision,
                current: currentRevision
            )
        }
        let nextLinkSetRevision = currentRevision + 1
        let now = timestamp()

        switch command {
        case let .upsertTicketReference(_, _, linkID, kind, artifactID, sourceLocalID, locator, _, _):
            guard let prepared else { throw DocumentationOperationError.invalidRequest }
            let existing = try connection.row(
                "SELECT kind, repository_id, artifact_id, current_version, relationship FROM ticket_reference_links WHERE project_id = ? AND ticket_id = ? AND id = ?",
                bindings: [.text(context.projectID), .text(ids.ticketID), .text(linkID)]
            )
            let version: Int64
            if let existing {
                guard existing["kind"] == .text(kind.rawValue),
                      existing["repository_id"] == .text(prepared.repositoryID),
                      existing["artifact_id"] == .text(artifactID),
                      existing["relationship"] == .text("current"),
                      case let .integer(currentVersion)? = existing["current_version"] else {
                    throw TicketReferenceMutationError.identityImmutable
                }
                version = currentVersion + 1
                try connection.execute(
                    "UPDATE ticket_reference_links SET current_version = ?, updated_at = ? WHERE project_id = ? AND ticket_id = ? AND id = ?",
                    bindings: [.integer(version), .text(now), .text(context.projectID), .text(ids.ticketID), .text(linkID)]
                )
            } else {
                version = 1
                if currentRevision == 0 {
                    try connection.execute(
                        "INSERT INTO ticket_reference_link_sets (project_id, ticket_id, revision, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                        bindings: [.text(context.projectID), .text(ids.ticketID), .integer(nextLinkSetRevision), .text(now), .text(now)]
                    )
                }
                try connection.execute(
                    "INSERT INTO ticket_reference_links (project_id, ticket_id, id, kind, repository_id, artifact_id, current_version, relationship, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 1, 'current', ?, ?)",
                    bindings: [.text(context.projectID), .text(ids.ticketID), .text(linkID), .text(kind.rawValue), .text(prepared.repositoryID), .text(artifactID), .text(now), .text(now)]
                )
            }
            try connection.execute(
                "INSERT INTO ticket_reference_versions (project_id, ticket_id, link_id, version, content_digest, source_local_id, locator, catalog_version, catalog_digest, observed_path, observed_lifecycle, observed_authority, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                bindings: [
                    .text(context.projectID), .text(ids.ticketID), .text(linkID), .integer(version),
                    .text(prepared.contentDigest), sourceLocalID.map(SQLiteValue.text) ?? .null,
                    locator.map(SQLiteValue.text) ?? .null, .integer(Int64(prepared.catalogVersion)),
                    .text(prepared.catalogDigest), .text(prepared.path),
                    .text(prepared.lifecycle.rawValue), .text(prepared.authority.rawValue), .text(now),
                ]
            )
        case let .retireTicketReference(_, _, _, linkID, version, _):
            guard let row = try connection.row(
                "SELECT current_version, relationship FROM ticket_reference_links WHERE project_id = ? AND ticket_id = ? AND id = ?",
                bindings: [.text(context.projectID), .text(ids.ticketID), .text(linkID)]
            ), row["current_version"] == .integer(version), row["relationship"] == .text("current") else {
                throw TicketReferenceMutationError.notFound
            }
            try connection.execute(
                "UPDATE ticket_reference_links SET relationship = 'retired', retired_version = ?, retired_at = ?, retirement_reason = ?, updated_at = ? WHERE project_id = ? AND ticket_id = ? AND id = ?",
                bindings: [.integer(version), .text(now), .text(retirementReason), .text(now),
                           .text(context.projectID), .text(ids.ticketID), .text(linkID)]
            )
        default:
            throw DocumentationOperationError.invalidRequest
        }
        if currentRevision > 0 {
            try connection.execute(
                "UPDATE ticket_reference_link_sets SET revision = ?, updated_at = ? WHERE project_id = ? AND ticket_id = ?",
                bindings: [.integer(nextLinkSetRevision), .text(now), .text(context.projectID), .text(ids.ticketID)]
            )
        }
        return nextLinkSetRevision
    }

    private static func requireCurrentAuthorization(
        projectID: String,
        registration: ProjectRegistration?,
        connection: SQLiteConnection
    ) throws {
        do {
            try ProjectLifecycleManager.requireCurrentAuthorization(
                projectID: .init(rawValue: projectID),
                registration: registration,
                connection: connection
            )
        } catch {
            throw DocumentationOperationError.staleRegistration
        }
    }

    private static func replay(
        _ connection: SQLiteConnection,
        requestID: UUID,
        body: Data,
        registration: ProjectRegistration?
    ) throws -> AgentCommandResult? {
        guard let row = try connection.row(
            "SELECT request_body, result_data, registration_project_id, registration_id, request_generation FROM agent_command_requests WHERE request_id = ?",
            bindings: [.text(requestID.uuidString)]
        ) else { return nil }
        guard ProjectLifecycleManager.receiptScopeMatches(row, registration: registration),
              row["request_body"] == .blob(body),
              case let .blob(bytes)? = row["result_data"],
              let result = try? JSONDecoder().decode(AgentCommandResult.self, from: bytes) else {
            throw TicketReferenceControl.requestIDReused
        }
        return result
    }

    private static func map(_ error: TicketReferenceMutationError) -> AgentCommandError {
        switch error {
        case let .linkSetRevisionConflict(expected, current):
            .ticketReferenceLinkSetRevisionConflict(expected: expected, current: current)
        case .notFound: .ticketReferenceNotFound
        case .identityImmutable: .ticketReferenceIdentityImmutable
        case .ticketAccepted: .ticketReferenceTicketAccepted
        case .sourceNotAuthoritative: .ticketReferenceSourceNotAuthoritative
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private enum TicketReferenceControl: Error {
    case requestIDReused
    case expired
    case replay(AgentCommandResult)
}

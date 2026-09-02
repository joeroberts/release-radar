import Foundation

extension DeliveryStore {
    /// Read-only reconstruction of the persisted trust anchor. Malformed stored
    /// metadata fails closed rather than becoming an implicit activation.
    public func documentationBinding(projectID: ProjectID) throws -> ProjectDocumentationBinding? {
        try read { connection in
            guard let row = try connection.row(
                "SELECT * FROM project_documentation_bindings WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            ) else { return nil }
            guard case let .text(rootID) = row["root_id"],
                  case let .text(repositoryID) = row["repository_id"],
                  case let .integer(version) = row["accepted_catalog_version"],
                  case let .text(digest) = row["accepted_catalog_digest"],
                  case let .blob(catalog) = row["accepted_catalog"] else {
                throw ProjectDocumentationBindingError.invalidAcceptedSnapshot
            }
            return try .init(projectID: projectID, rootID: .init(rawValue: rootID), repositoryID: repositoryID,
                             acceptedCatalogVersion: Int(version), acceptedCatalogDigest: digest, acceptedCatalog: catalog)
        }
    }

    public func locatedEvidence(projectID: ProjectID, evidenceID: EvidenceID) throws -> LocatedEvidenceRecord? {
        try read { connection in
            guard let row = try connection.row(
                "SELECT ticket_id, path, artifact_id, is_available FROM evidence WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(evidenceID.rawValue)]
            ) else { return nil }
            let locator: EvidenceLocator
            switch (row["path"], row["artifact_id"]) {
            case let (.text(path), .null): locator = .filePath(path)
            case let (.null, .text(artifactID)): locator = .managedDocument(artifactID: artifactID)
            default: throw StoreError.unavailable("Evidence does not have exactly one supported locator")
            }
            let ticketID: TicketID?
            switch row["ticket_id"] {
            case let .text(value): ticketID = .init(rawValue: value)
            case .null: ticketID = nil
            default: throw StoreError.unavailable("Evidence ticket identity is invalid")
            }
            guard case let .integer(available) = row["is_available"], available == 0 || available == 1 else {
                throw StoreError.unavailable("Evidence availability is invalid")
            }
            return .init(id: evidenceID, projectID: projectID, ticketID: ticketID, locator: locator, isAvailable: available == 1)
        }
    }
}

/// Stored identity and fresh catalog resolution are distinct public readback fields.
public struct EvidenceReadback: Equatable, Codable, Sendable {
    public let evidence: LocatedEvidenceRecord
    public let managedDocument: ResolvedManagedDocument?
}

extension DeliveryStore {
    public func evidenceReadback(projectID: ProjectID,
                                 bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) async throws -> [EvidenceReadback] {
        let version = schemaVersionForDocumentation
        let state = try documentationRead { c in
            var records: [LocatedEvidenceRecord] = []
            var offset = 0
            let artifactColumn = version >= 13 ? "artifact_id" : "NULL AS artifact_id"
            while let row = try c.row("SELECT id, ticket_id, path, \(artifactColumn), is_available FROM evidence WHERE project_id = ? ORDER BY rowid LIMIT 1 OFFSET ?",
                                      bindings: [.text(projectID.rawValue), .integer(Int64(offset))]) {
                guard case let .text(id) = row["id"], case let .integer(available) = row["is_available"] else {
                    throw StoreError.unavailable("Invalid evidence record")
                }
                let locator: EvidenceLocator
                switch (row["path"], row["artifact_id"]) {
                case let (.text(path), .null): locator = .filePath(path)
                case let (.null, .text(artifact)): locator = .managedDocument(artifactID: artifact)
                default: throw StoreError.unavailable("Evidence does not have exactly one supported locator")
                }
                let ticket: TicketID?
                if case let .text(value) = row["ticket_id"] { ticket = .init(rawValue: value) } else { ticket = nil }
                records.append(.init(id: .init(rawValue: id), projectID: projectID, ticketID: ticket, locator: locator, isAvailable: available == 1))
                offset += 1
            }
            var binding: ProjectDocumentationBinding?
            var invalidBinding = false
            do { binding = try DocumentationRootContext.binding(c, projectID: projectID.rawValue, version: version) }
            catch { invalidBinding = true }
            var root: ProjectRootRecord?
            var bookmark: Data?
            var stale = false
            if let binding, let row = try c.row("SELECT r.path, b.bookmark_data, b.is_stale FROM project_roots r LEFT JOIN project_bookmarks b ON b.project_id = r.project_id AND b.path = r.path WHERE r.id = ? AND r.project_id = ?",
                                               bindings: [.text(binding.rootID.rawValue), .text(projectID.rawValue)]), case let .text(path) = row["path"] {
                root = .init(id: binding.rootID, projectID: projectID, path: path)
                if case let .blob(data) = row["bookmark_data"] { bookmark = data }
                stale = row["is_stale"] == .integer(1)
            }
            return (records, binding, root, bookmark, stale, invalidBinding)
        }
        let artifactIDs = state.0.compactMap { record -> String? in
            if case let .managedDocument(id) = record.locator { return id }; return nil
        }
        let resolved = await ManagedDocumentResolver().resolve(artifactIDs: artifactIDs, projectID: projectID,
            binding: state.1, root: state.2, bookmark: state.4 ? nil : state.3, bookmarkStore: bookmarkStore)
        return state.0.map { record in
            guard case let .managedDocument(id) = record.locator else { return .init(evidence: record, managedDocument: nil) }
            let failure: ManagedDocumentResolutionFailure? = state.5 ? .bindingMismatch : state.4 ? .staleRoot : nil
            let document = failure.map { ResolvedManagedDocument(artifactID: id, resolvedPath: nil, label: nil, lifecycle: nil, authority: nil, authorityRole: nil, failure: $0) } ?? resolved[id]
            return .init(evidence: record, managedDocument: document)
        }
    }
}

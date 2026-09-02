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

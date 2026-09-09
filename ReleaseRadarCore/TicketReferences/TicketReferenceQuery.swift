import Foundation

struct TicketReferenceCapture: Sendable {
    let context: DocumentationRootContext
    private let ticketID: String
    private let phaseID: String?
    private let phaseLabel: String
    private let revision: Int64
    private let links: [StoredLink]

    init(_ connection: SQLiteConnection, context: DocumentationRootContext, ticketID: String) throws {
        guard let ticket = try connection.row(
            "SELECT tickets.phase_id, phases.name FROM tickets LEFT JOIN phases ON phases.project_id = tickets.project_id AND phases.id = tickets.phase_id WHERE tickets.project_id = ? AND tickets.id = ?",
            bindings: [.text(context.projectID), .text(ticketID)]
        ) else { throw TicketReferenceMutationError.notFound }
        self.context = context
        self.ticketID = ticketID
        phaseID = ticket["phase_id"].text
        phaseLabel = ticket["name"].text ?? "Not placed"
        revision = try connection.scalarInt(
            "SELECT revision FROM ticket_reference_link_sets WHERE project_id = ? AND ticket_id = ?",
            bindings: [.text(context.projectID), .text(ticketID)]
        ) ?? 0
        links = try connection.rows(
            "SELECT * FROM ticket_reference_links WHERE project_id = ? AND ticket_id = ? ORDER BY kind, id",
            bindings: [.text(context.projectID), .text(ticketID)], maximum: 4096
        ).map { row in
            guard let id = row["id"].text,
                  let kind = row["kind"].text.flatMap(TicketReferenceKind.init(rawValue:)),
                  let repositoryID = row["repository_id"].text,
                  let artifactID = row["artifact_id"].text,
                  let currentVersion = row["current_version"].integer,
                  let relationship = row["relationship"].text.flatMap(TicketReferenceRelationship.init(rawValue:)) else {
                throw DocumentationOperationError.invalidRequest
            }
            let versions = try connection.rows(
                "SELECT * FROM ticket_reference_versions WHERE project_id = ? AND ticket_id = ? AND link_id = ? ORDER BY version DESC",
                bindings: [.text(context.projectID), .text(ticketID), .text(id)], maximum: 4096
            ).map(StoredVersion.init)
            return StoredLink(
                id: id, kind: kind, repositoryID: repositoryID, artifactID: artifactID,
                currentVersion: currentVersion, relationship: relationship,
                retiredVersion: row["retired_version"].integer, retiredAt: row["retired_at"].text,
                retirementReason: row["retirement_reason"].text, versions: versions
            )
        }
    }

    func resolve() -> TicketReferenceSet {
        var resolved: [TicketReference]
        do {
            let catalog = try DocumentationCatalogContext(root: context.root)
            let snapshot = try catalog.managedSnapshot()
            try context.requireAccepted(snapshot)
            resolved = links.map { $0.resolve(snapshot: snapshot, reader: catalog.reader) }
            try catalog.reader.verifyStable()
        } catch {
            resolved = links.map { $0.unavailable() }
        }
        return .init(projectID: context.projectID, ticketID: ticketID, phaseID: phaseID,
                     phaseLabel: phaseLabel, linkSetRevision: revision, links: resolved)
    }
}

private struct StoredLink: Sendable {
    let id: String
    let kind: TicketReferenceKind
    let repositoryID: String
    let artifactID: String
    let currentVersion: Int64
    let relationship: TicketReferenceRelationship
    let retiredVersion: Int64?
    let retiredAt: String?
    let retirementReason: String?
    let versions: [StoredVersion]

    func resolve(snapshot: RepositoryDocumentSnapshot, reader: RepositoryDocumentReader) -> TicketReference {
        var sharedFacts: [TicketReferenceImpactFact] = []
        var path: String?
        var digest: String?
        var lifecycle: RepositoryDocumentArtifact.Lifecycle?
        var authority: RepositoryDocumentArtifact.Authority?
        var bytes: Data?
        if repositoryID != snapshot.catalog.repositoryID.lowercased() {
            sharedFacts = [.unavailable, .unchecked]
        } else if let artifact = snapshot.catalog.artifacts.first(where: { $0.artifactID == artifactID }) {
            path = artifact.path
            lifecycle = artifact.lifecycle
            authority = artifact.authorityLevel
            if artifact.lifecycle == .superseded || snapshot.catalog.artifacts.contains(where: { $0.supersedes.contains(artifactID) }) {
                sharedFacts.append(.superseded)
            }
            if artifact.lifecycle == .archived { sharedFacts.append(.archived) }
            if artifact.authorityLevel != .controlling { sharedFacts.append(.noLongerControlling) }
            do {
                let current = try reader.read(artifact.path)
                let currentDigest = documentationDigest(current)
                bytes = current
                digest = currentDigest
            } catch {
                sharedFacts.append(contentsOf: [.unavailable, .unchecked])
            }
        } else if snapshot.catalog.retiredArtifactIDs.contains(artifactID) {
            sharedFacts.append(.retired)
        } else {
            sharedFacts.append(contentsOf: [.unavailable, .unchecked])
        }
        func resolution(for version: StoredVersion) -> TicketReferenceResolution {
            var facts = sharedFacts
            if let path, version.observedPath != path { facts.append(.moved) }
            if let digest, version.contentDigest != digest { facts.append(.changed) }
            return .init(
                facts: TicketReferenceImpactFact.stableOrder.filter(Set(facts).contains),
                currentPath: path,
                currentDigest: digest,
                currentLifecycle: lifecycle,
                currentAuthority: authority
            )
        }
        let currentResolution = versions.first(where: { $0.version == currentVersion }).map(resolution)
            ?? .init(facts: [.unavailable, .unchecked], currentPath: path, currentDigest: digest,
                     currentLifecycle: lifecycle, currentAuthority: authority)
        return reference(
            resolution: currentResolution,
            previewBytes: bytes,
            versionResolution: resolution
        )
    }

    func unavailable() -> TicketReference {
        reference(
            resolution: .init(facts: [.unavailable, .unchecked], currentPath: nil, currentDigest: nil,
                              currentLifecycle: nil, currentAuthority: nil),
            previewBytes: nil,
            versionResolution: { _ in
                .init(facts: [.unavailable, .unchecked], currentPath: nil, currentDigest: nil,
                      currentLifecycle: nil, currentAuthority: nil)
            }
        )
    }

    private func reference(
        resolution: TicketReferenceResolution,
        previewBytes: Data?,
        versionResolution: (StoredVersion) -> TicketReferenceResolution
    ) -> TicketReference {
        .init(
            id: id, kind: kind, repositoryID: repositoryID, artifactID: artifactID,
            currentVersion: currentVersion, relationship: relationship,
            retiredVersion: retiredVersion, retiredAt: retiredAt, retirementReason: retirementReason,
            versions: versions.map { $0.output(previewBytes: previewBytes, resolution: versionResolution($0)) },
            resolution: resolution
        )
    }
}

private struct StoredVersion: Sendable {
    static let maximumPreviewBytes = 32_768
    let version: Int64
    let contentDigest: String
    let sourceLocalID: String?
    let locator: String?
    let catalogVersion: Int
    let catalogDigest: String
    let observedPath: String
    let observedLifecycle: RepositoryDocumentArtifact.Lifecycle
    let observedAuthority: RepositoryDocumentArtifact.Authority
    let createdAt: String

    init(_ row: [String: SQLiteValue]) throws {
        guard let version = row["version"].integer,
              let contentDigest = row["content_digest"].text,
              let catalogVersion = row["catalog_version"].integer,
              let catalogDigest = row["catalog_digest"].text,
              let observedPath = row["observed_path"].text,
              let observedLifecycle = row["observed_lifecycle"].text.flatMap(RepositoryDocumentArtifact.Lifecycle.init(rawValue:)),
              let observedAuthority = row["observed_authority"].text.flatMap(RepositoryDocumentArtifact.Authority.init(rawValue:)),
              let createdAt = row["created_at"].text else {
            throw DocumentationOperationError.invalidRequest
        }
        self.version = version; self.contentDigest = contentDigest
        sourceLocalID = row["source_local_id"].text; locator = row["locator"].text
        self.catalogVersion = Int(catalogVersion); self.catalogDigest = catalogDigest
        self.observedPath = observedPath; self.observedLifecycle = observedLifecycle
        self.observedAuthority = observedAuthority; self.createdAt = createdAt
    }

    func output(previewBytes: Data?, resolution: TicketReferenceResolution) -> TicketReferenceVersion {
        let matches = previewBytes.map { documentationDigest($0) == contentDigest } == true
        let preview: String?
        if matches, let previewBytes, String(data: previewBytes, encoding: .utf8) != nil {
            preview = String(decoding: previewBytes.prefix(Self.maximumPreviewBytes), as: UTF8.self)
        } else {
            preview = nil
        }
        return .init(
            version: version, contentDigest: contentDigest, sourceLocalID: sourceLocalID,
            locator: locator, catalogVersion: catalogVersion, catalogDigest: catalogDigest,
            observedPath: observedPath, observedLifecycle: observedLifecycle,
            observedAuthority: observedAuthority, createdAt: createdAt, resolution: resolution,
            historicalPreview: preview, previewIsTruncated: matches && (previewBytes?.count ?? 0) > Self.maximumPreviewBytes
        )
    }
}

struct RecordedImpactsCapture: Sendable {
    let context: DocumentationRootContext
    let result: RecordedImpacts

    init(
        _ connection: SQLiteConnection,
        context: DocumentationRootContext,
        repositoryID: String,
        artifactID: String
    ) throws {
        guard context.binding?.repositoryID == repositoryID else {
            throw DocumentationOperationError.bindingMismatch
        }
        self.context = context
        let rows = try connection.rows(
            """
            SELECT v.ticket_id, t.phase_id, p.name AS phase_name, v.link_id, l.kind,
                   v.source_local_id, v.content_digest, v.version, l.current_version, l.relationship
            FROM ticket_reference_versions v
            JOIN ticket_reference_links l
              ON l.project_id = v.project_id AND l.ticket_id = v.ticket_id AND l.id = v.link_id
            JOIN tickets t ON t.project_id = v.project_id AND t.id = v.ticket_id
            LEFT JOIN phases p ON p.project_id = t.project_id AND p.id = t.phase_id
            WHERE v.project_id = ? AND l.repository_id = ? AND l.artifact_id = ?
            ORDER BY CASE WHEN v.version = l.current_version AND l.relationship = 'current' THEN 0 ELSE 1 END,
                     v.ticket_id, v.link_id, v.version DESC
            """,
            bindings: [.text(context.projectID), .text(repositoryID), .text(artifactID)],
            maximum: 8192
        ).map { row -> RecordedImpact in
            guard let ticketID = row["ticket_id"].text,
                  let linkID = row["link_id"].text,
                  let kind = row["kind"].text.flatMap(TicketReferenceKind.init(rawValue:)),
                  let contentDigest = row["content_digest"].text,
                  let version = row["version"].integer,
                  let currentVersion = row["current_version"].integer,
                  let relationship = row["relationship"].text else {
                throw DocumentationOperationError.invalidRequest
            }
            return .init(
                ticketID: ticketID, phaseID: row["phase_id"].text,
                phaseLabel: row["phase_name"].text ?? "Not placed", linkID: linkID,
                kind: kind, sourceLocalID: row["source_local_id"].text,
                contentDigest: contentDigest, version: version,
                isCurrent: relationship == "current" && version == currentVersion
            )
        }
        result = .init(title: "Recorded impacts", projectID: context.projectID,
                       repositoryID: repositoryID, artifactID: artifactID, rows: rows)
    }
}

private extension SQLiteValue? {
    var text: String? {
        guard case let .text(value)? = self else { return nil }
        return value
    }
    var integer: Int64? {
        guard case let .integer(value)? = self else { return nil }
        return value
    }
}

private extension TicketReferenceImpactFact {
    static let stableOrder: [Self] = [
        .changed, .moved, .retired, .superseded, .archived,
        .noLongerControlling, .unavailable, .unchecked,
    ]
}

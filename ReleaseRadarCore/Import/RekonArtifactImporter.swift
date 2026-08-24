import Foundation
import Darwin

public struct RekonArtifactImporter: DeliveryArtifactImporter, Sendable {
    private static let artifactPath = "docs/delivery/dashboard-status.json"
    private static let maximumArtifactBytes = 1_048_576
    private static let maximumPhases = 256
    private static let maximumTasks = 5_000
    private static let maximumDependencies = 20_000
    private static let maximumIdentifierBytes = 256
    private static let maximumTextBytes = 4_096
    private static let maximumScannedEvidenceEntries = 512
    private static let maximumEvidenceRecords = 1_024

    private let store: DeliveryStore
    private let project: AuthorizedProject

    public init(store: DeliveryStore, project: AuthorizedProject) {
        self.store = store
        self.project = project
    }

    public func canImport(_ folder: URL) -> Bool {
        (try? preview(folder)) != nil
    }

    public func preview(_ folder: URL) throws -> ImportPreview {
        let root = AuthorizedProject.canonicalize(folder)
        guard project.authorizedRoots.contains(root) else {
            throw RekonImportError.unauthorizedFolder
        }
        let artifactURL = root.appendingPathComponent(Self.artifactPath).standardizedFileURL
        let data = try Self.readArtifactData(under: root, artifactURL: artifactURL)
        let artifact: RekonArtifact
        do {
            artifact = try JSONDecoder().decode(RekonArtifact.self, from: data)
        } catch {
            throw RekonImportError.malformedArtifact
        }
        guard artifact.schemaVersion == 1 else {
            throw RekonImportError.unsupportedSchemaVersion(artifact.schemaVersion)
        }
        try validateLimits(artifact)

        var reviews: [ImportReviewItem] = []
        let phaseCounts = Dictionary(grouping: artifact.phases, by: \.id).mapValues(\.count)
        let phases = artifact.phases.compactMap { phase -> ImportPhase? in
            guard phaseCounts[phase.id] == 1 else { return nil }
            guard isBoundedID(phase.id), let name = boundedText(phase.label) else {
                reviews.append(.init(
                    sourceID: phase.id,
                    ticketID: nil,
                    kind: .missingOutcome,
                    summary: "Phase \(phase.id) is missing a usable label"
                ))
                return nil
            }
            return .init(id: .init(rawValue: phase.id), name: name)
        }
        for (id, count) in phaseCounts where count > 1 {
            reviews.append(.init(
                sourceID: id,
                ticketID: nil,
                kind: .duplicate,
                summary: "Phase \(id) appears \(count) times"
            ))
        }
        let phaseIDs = Set(phases.map(\.id))

        var phaseDependencyCandidates: [ImportPhaseDependency] = []
        for phase in artifact.phases where phaseCounts[phase.id] == 1 && phaseIDs.contains(.init(rawValue: phase.id)) {
            for dependencyID in phase.dependsOnPhaseIds ?? [] {
                if dependencyID == phase.id {
                    reviews.append(.init(
                        sourceID: "\(phase.id)→\(dependencyID)",
                        ticketID: nil,
                        kind: .unresolvedDependency,
                        summary: "Phase \(phase.id) cannot depend on itself"
                    ))
                } else if phaseIDs.contains(.init(rawValue: dependencyID)) {
                    phaseDependencyCandidates.append(.init(
                        phaseID: .init(rawValue: phase.id),
                        dependsOnPhaseID: .init(rawValue: dependencyID)
                    ))
                } else {
                    reviews.append(.init(
                        sourceID: "\(phase.id)→\(dependencyID)",
                        ticketID: nil,
                        kind: .unresolvedDependency,
                        summary: "Phase \(phase.id) depends on unknown phase \(dependencyID)"
                    ))
                }
            }
        }
        let filteredPhaseDependencies = filterCycles(
            phaseDependencyCandidates,
            subject: { $0.phaseID.rawValue },
            dependency: { $0.dependsOnPhaseID.rawValue }
        )
        let phaseDependencies = filteredPhaseDependencies.accepted
        for dependency in filteredPhaseDependencies.rejected {
            reviews.append(.init(
                sourceID: "\(dependency.phaseID.rawValue)→\(dependency.dependsOnPhaseID.rawValue)",
                ticketID: nil,
                kind: .unresolvedDependency,
                summary: "Phase dependency would create a cycle"
            ))
        }

        let taskCounts = Dictionary(grouping: artifact.tasks, by: \.id).mapValues(\.count)
        var tickets: [ImportTicket] = []
        for task in artifact.tasks {
            guard taskCounts[task.id] == 1 else { continue }
            guard isBoundedID(task.id), let outcome = boundedText(task.title) else {
                reviews.append(.init(
                    sourceID: task.id,
                    ticketID: nil,
                    kind: .missingOutcome,
                    summary: "Task \(task.id) is missing a usable outcome"
                ))
                continue
            }
            guard let lane = task.status.flatMap(TicketLane.init(rawValue:)) else {
                reviews.append(.init(
                    sourceID: task.id,
                    ticketID: nil,
                    kind: .unmappedStatus,
                    summary: "Task \(task.id) has an unmapped status"
                ))
                continue
            }
            guard let phaseID = task.phaseId, phaseIDs.contains(.init(rawValue: phaseID)) else {
                reviews.append(.init(
                    sourceID: task.id,
                    ticketID: nil,
                    kind: .unresolvedDependency,
                    summary: "Task \(task.id) references an unknown phase"
                ))
                continue
            }
            tickets.append(.init(
                id: .init(rawValue: task.id),
                phaseID: .init(rawValue: phaseID),
                outcome: outcome,
                lane: lane
            ))
        }
        for (id, count) in taskCounts where count > 1 {
            reviews.append(.init(
                sourceID: id,
                ticketID: nil,
                kind: .duplicate,
                summary: "Task \(id) appears \(count) times"
            ))
        }
        let ticketIDs = Set(tickets.map(\.id))

        var ticketDependencyCandidates: [ImportTicketDependency] = []
        for task in artifact.tasks where taskCounts[task.id] == 1 && ticketIDs.contains(.init(rawValue: task.id)) {
            for dependencyID in task.dependsOnTaskIds ?? [] {
                if dependencyID == task.id {
                    reviews.append(.init(
                        sourceID: "\(task.id)→\(dependencyID)",
                        ticketID: .init(rawValue: task.id),
                        kind: .unresolvedDependency,
                        summary: "Task \(task.id) cannot depend on itself"
                    ))
                } else if ticketIDs.contains(.init(rawValue: dependencyID)) {
                    ticketDependencyCandidates.append(.init(
                        ticketID: .init(rawValue: task.id),
                        dependsOnTicketID: .init(rawValue: dependencyID)
                    ))
                } else {
                    reviews.append(.init(
                        sourceID: "\(task.id)→\(dependencyID)",
                        ticketID: .init(rawValue: task.id),
                        kind: .unresolvedDependency,
                        summary: "Task \(task.id) depends on unknown task \(dependencyID)"
                    ))
                }
            }
        }
        let filteredTicketDependencies = filterCycles(
            ticketDependencyCandidates,
            subject: { $0.ticketID.rawValue },
            dependency: { $0.dependsOnTicketID.rawValue }
        )
        let ticketDependencies = filteredTicketDependencies.accepted
        for dependency in filteredTicketDependencies.rejected {
            reviews.append(.init(
                sourceID: "\(dependency.ticketID.rawValue)→\(dependency.dependsOnTicketID.rawValue)",
                ticketID: dependency.ticketID,
                kind: .unresolvedDependency,
                summary: "Task dependency would create a cycle"
            ))
        }

        let evidence = try collectEvidence(
            artifact: artifact,
            root: root,
            confidentTicketIDs: ticketIDs,
            taskCounts: taskCounts
        )
        let activePhaseID: PhaseID?
        if let sourceActivePhaseID = artifact.activePhaseId,
           phaseIDs.contains(.init(rawValue: sourceActivePhaseID)) {
            activePhaseID = .init(rawValue: sourceActivePhaseID)
        } else {
            activePhaseID = nil
            reviews.append(.init(
                sourceID: artifact.activePhaseId ?? "activePhaseId",
                ticketID: nil,
                kind: artifact.activePhaseId == nil ? .missingOutcome : .unresolvedDependency,
                summary: artifact.activePhaseId == nil
                    ? "The artifact does not identify an active phase"
                    : "The artifact's active phase is not a confident phase record"
            ))
        }

        return .init(
            sourceRoot: root,
            artifactURL: artifactURL,
            schemaVersion: artifact.schemaVersion,
            activePhaseID: activePhaseID,
            phases: phases.sorted { $0.id.rawValue < $1.id.rawValue },
            phaseDependencies: phaseDependencies.sorted(by: phaseDependencyOrder),
            tickets: tickets.sorted { $0.id.rawValue < $1.id.rawValue },
            ticketDependencies: ticketDependencies.sorted(by: ticketDependencyOrder),
            evidence: evidence.sorted { $0.path < $1.path },
            reviewItems: reviews.sorted { ($0.kind.rawValue, $0.sourceID) < ($1.kind.rawValue, $1.sourceID) }
        )
    }

    public func apply(_ preview: ImportPreview, to project: ProjectID) async throws {
        guard project == self.project.projectID else {
            throw RekonImportError.targetProjectMismatch
        }
        let currentPreview = try self.preview(preview.sourceRoot)
        guard preview == currentPreview,
              preview.sourceRoot == self.project.canonicalRoot || self.project.authorizedRoots.contains(preview.sourceRoot),
              preview.artifactURL == preview.sourceRoot
                .appendingPathComponent(Self.artifactPath)
                .standardizedFileURL else {
            throw RekonImportError.malformedArtifact
        }

        let projectID = project.rawValue
        let rootPath = preview.sourceRoot.path
        try await store.transact(
            actor: .init(id: "release-radar-importer"),
            reason: "Import recognized Rekon delivery records",
            auditScope: .init(projectID: project, entityType: .project, entityID: projectID)
        ) { connection in
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM projects WHERE id = ?",
                bindings: [.text(projectID)]
            ) == 1,
            try connection.scalarText(
                "SELECT project_id FROM project_roots WHERE path = ?",
                bindings: [.text(rootPath)]
            ) == projectID else {
                throw RekonImportError.projectNotFound
            }

            var reviews = preview.reviewItems
            var availablePhaseIDs = Set<PhaseID>()
            for phase in preview.phases {
                if let existing = try connection.row(
                    "SELECT project_id, name FROM phases WHERE id = ?",
                    bindings: [.text(phase.id.rawValue)]
                ) {
                    if existing["project_id"] == .text(projectID), existing["name"] == .text(phase.name) {
                        availablePhaseIDs.insert(phase.id)
                    } else {
                        reviews.append(.conflict(
                            sourceID: phase.id.rawValue,
                            summary: "Phase \(phase.id.rawValue) conflicts with an existing delivery record"
                        ))
                    }
                    continue
                }
                try connection.execute(
                    "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
                    bindings: [.text(phase.id.rawValue), .text(projectID), .text(phase.name)]
                )
                availablePhaseIDs.insert(phase.id)
            }

            if let activePhaseID = preview.activePhaseID,
               availablePhaseIDs.contains(activePhaseID) {
                try connection.execute(
                    """
                    INSERT INTO project_active_phases (project_id, phase_id) VALUES (?, ?)
                    ON CONFLICT(project_id) DO UPDATE SET phase_id = excluded.phase_id
                    """,
                    bindings: [.text(projectID), .text(activePhaseID.rawValue)]
                )
            }

            var availableTicketIDs = Set<TicketID>()
            for ticket in preview.tickets {
                guard availablePhaseIDs.contains(ticket.phaseID) else {
                    reviews.append(.conflict(
                        sourceID: ticket.id.rawValue,
                        summary: "Task \(ticket.id.rawValue) could not import because its phase conflicts"
                    ))
                    continue
                }
                if let existing = try connection.row(
                    "SELECT project_id, phase_id, outcome, lane FROM tickets WHERE id = ?",
                    bindings: [.text(ticket.id.rawValue)]
                ) {
                    if existing["project_id"] == .text(projectID),
                       existing["phase_id"] == .text(ticket.phaseID.rawValue),
                       existing["outcome"] == .text(ticket.outcome),
                       existing["lane"] == .text(ticket.lane.rawValue) {
                        availableTicketIDs.insert(ticket.id)
                    } else {
                        reviews.append(.conflict(
                            sourceID: ticket.id.rawValue,
                            summary: "Task \(ticket.id.rawValue) conflicts with an existing delivery record"
                        ))
                    }
                    continue
                }
                try connection.execute(
                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
                    bindings: [
                        .text(ticket.id.rawValue),
                        .text(projectID),
                        .text(ticket.phaseID.rawValue),
                        .text(ticket.outcome),
                        .text(ticket.lane.rawValue),
                    ]
                )
                availableTicketIDs.insert(ticket.id)
            }

            var phaseDependencyAdjacency = try Self.loadDependencyAdjacency(
                from: connection,
                projectID: projectID,
                sql: "SELECT phase_id AS source_id, depends_on_phase_id AS dependency_id FROM phase_dependencies WHERE project_id = ? ORDER BY phase_id, depends_on_phase_id LIMIT 1 OFFSET ?"
            )
            for dependency in preview.phaseDependencies {
                guard availablePhaseIDs.contains(dependency.phaseID),
                      availablePhaseIDs.contains(dependency.dependsOnPhaseID) else {
                    reviews.append(.conflict(
                        sourceID: "\(dependency.phaseID.rawValue)→\(dependency.dependsOnPhaseID.rawValue)",
                        summary: "Phase dependency could not import because an endpoint conflicts"
                    ))
                    continue
                }
                let sourceID = dependency.phaseID.rawValue
                let dependsOnID = dependency.dependsOnPhaseID.rawValue
                if phaseDependencyAdjacency[sourceID]?.contains(dependsOnID) == true { continue }
                if Self.hasPath(from: dependsOnID, to: sourceID, adjacency: phaseDependencyAdjacency) {
                    reviews.append(.init(
                        sourceID: "\(sourceID)→\(dependsOnID)",
                        ticketID: nil,
                        kind: .unresolvedDependency,
                        summary: "Phase dependency would create a cycle"
                    ))
                    continue
                }
                let id = Self.stableID(
                    "phase-dependency",
                    projectID,
                    sourceID,
                    dependsOnID
                )
                guard try connection.scalarText("SELECT id FROM phase_dependencies WHERE id = ?", bindings: [.text(id)]) == nil else {
                    reviews.append(.conflict(sourceID: id, summary: "Phase dependency identifier conflicts with an existing record"))
                    continue
                }
                try connection.execute(
                    "INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES (?, ?, ?, ?)",
                    bindings: [
                        .text(id),
                        .text(projectID),
                        .text(sourceID),
                        .text(dependsOnID),
                    ]
                )
                phaseDependencyAdjacency[sourceID, default: []].insert(dependsOnID)
            }

            var ticketDependencyAdjacency = try Self.loadDependencyAdjacency(
                from: connection,
                projectID: projectID,
                sql: "SELECT ticket_id AS source_id, depends_on_ticket_id AS dependency_id FROM ticket_dependencies WHERE project_id = ? ORDER BY ticket_id, depends_on_ticket_id LIMIT 1 OFFSET ?"
            )
            for dependency in preview.ticketDependencies {
                guard availableTicketIDs.contains(dependency.ticketID),
                      availableTicketIDs.contains(dependency.dependsOnTicketID) else {
                    reviews.append(.conflict(
                        sourceID: "\(dependency.ticketID.rawValue)→\(dependency.dependsOnTicketID.rawValue)",
                        summary: "Task dependency could not import because an endpoint conflicts"
                    ))
                    continue
                }
                let sourceID = dependency.ticketID.rawValue
                let dependsOnID = dependency.dependsOnTicketID.rawValue
                if ticketDependencyAdjacency[sourceID]?.contains(dependsOnID) == true { continue }
                if Self.hasPath(from: dependsOnID, to: sourceID, adjacency: ticketDependencyAdjacency) {
                    reviews.append(.init(
                        sourceID: "\(sourceID)→\(dependsOnID)",
                        ticketID: dependency.ticketID,
                        kind: .unresolvedDependency,
                        summary: "Task dependency would create a cycle"
                    ))
                    continue
                }
                let id = Self.stableID(
                    "ticket-dependency",
                    projectID,
                    sourceID,
                    dependsOnID
                )
                guard try connection.scalarText("SELECT id FROM ticket_dependencies WHERE id = ?", bindings: [.text(id)]) == nil else {
                    reviews.append(.conflict(sourceID: id, summary: "Task dependency identifier conflicts with an existing record"))
                    continue
                }
                try connection.execute(
                    "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES (?, ?, ?, ?)",
                    bindings: [
                        .text(id),
                        .text(projectID),
                        .text(sourceID),
                        .text(dependsOnID),
                    ]
                )
                ticketDependencyAdjacency[sourceID, default: []].insert(dependsOnID)
            }

            try connection.execute(
                "UPDATE evidence SET is_available = 0 WHERE project_id = ? AND id LIKE 'import-evidence:%'",
                bindings: [.text(projectID)]
            )
            for evidence in preview.evidence {
                let evidenceURL = AuthorizedProject.canonicalize(URL(fileURLWithPath: evidence.path))
                guard evidence.path.utf8.count <= Self.maximumTextBytes,
                      Self.contains(evidenceURL, within: preview.sourceRoot) else {
                    throw RekonImportError.invalidPath(evidence.path)
                }
                let ticketID = evidence.ticketID.flatMap { availableTicketIDs.contains($0) ? $0.rawValue : nil }
                let isAvailable = FileManager.default.fileExists(atPath: evidenceURL.path)
                if try connection.scalarText(
                    "SELECT id FROM evidence WHERE project_id = ? AND path = ?",
                    bindings: [.text(projectID), .text(evidenceURL.path)]
                ) != nil {
                    try connection.execute(
                        "UPDATE evidence SET ticket_id = ?, is_available = ? WHERE project_id = ? AND path = ?",
                        bindings: [
                            ticketID.map(SQLiteValue.text) ?? .null,
                            .integer(isAvailable ? 1 : 0),
                            .text(projectID),
                            .text(evidenceURL.path),
                        ]
                    )
                    continue
                }
                let id = Self.stableID("evidence", projectID, evidenceURL.path)
                guard try connection.scalarText("SELECT id FROM evidence WHERE id = ?", bindings: [.text(id)]) == nil else {
                    reviews.append(.conflict(sourceID: evidenceURL.path, summary: "Evidence identifier conflicts with an existing record"))
                    continue
                }
                try connection.execute(
                    "INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES (?, ?, ?, ?, ?)",
                    bindings: [
                        .text(id),
                        .text(projectID),
                        ticketID.map(SQLiteValue.text) ?? .null,
                        .text(evidenceURL.path),
                        .integer(isAvailable ? 1 : 0),
                    ]
                )
            }

            for review in reviews {
                let id = Self.stableID("review", projectID, review.kind.rawValue, review.sourceID)
                let ticketID = review.ticketID.flatMap { availableTicketIDs.contains($0) ? $0.rawValue : nil }
                if let owner = try connection.scalarText(
                    "SELECT project_id FROM review_items WHERE id = ?",
                    bindings: [.text(id)]
                ), owner != projectID {
                    continue
                }
                try connection.execute(
                    "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open') ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, kind = excluded.kind, summary = excluded.summary WHERE review_items.project_id = excluded.project_id",
                    bindings: [
                        .text(id),
                        .text(projectID),
                        ticketID.map(SQLiteValue.text) ?? .null,
                        .text(review.kind.rawValue),
                        .text(review.summary),
                    ]
                )
                if try connection.scalarText(
                    "SELECT status FROM review_items WHERE id = ? AND project_id = ?",
                    bindings: [.text(id), .text(projectID)]
                ) == "open" {
                    _ = try MeaningfulDeliveryEvent.enqueue(
                        projectID: ProjectID(rawValue: projectID),
                        kind: .importNeedsReview,
                        subjectID: id,
                        ticketID: ticketID.map(TicketID.init(rawValue:)),
                        goalID: nil,
                        connection: connection
                    )
                }
            }
        }
    }

    private func validateLimits(_ artifact: RekonArtifact) throws {
        guard artifact.phases.count <= Self.maximumPhases else {
            throw RekonImportError.limitExceeded("The artifact exceeds 256 phases")
        }
        guard artifact.tasks.count <= Self.maximumTasks else {
            throw RekonImportError.limitExceeded("The artifact exceeds 5000 tasks")
        }
        let dependencyCount = artifact.phases.reduce(0) { $0 + ($1.dependsOnPhaseIds?.count ?? 0) }
            + artifact.tasks.reduce(0) { $0 + ($1.dependsOnTaskIds?.count ?? 0) }
        guard dependencyCount <= Self.maximumDependencies else {
            throw RekonImportError.limitExceeded("The artifact exceeds 20000 dependencies")
        }
    }

    private func collectEvidence(
        artifact: RekonArtifact,
        root: URL,
        confidentTicketIDs: Set<TicketID>,
        taskCounts: [String: Int]
    ) throws -> [ImportEvidence] {
        var records: [String: ImportEvidence] = [:]
        var scannedEntryCount = 0
        let virtualDashboardDirectory = root.appendingPathComponent("docs/delivery/dashboard", isDirectory: true)
        for task in artifact.tasks where taskCounts[task.id] == 1 && confidentTicketIDs.contains(.init(rawValue: task.id)) {
            guard let evidence = task.evidence, let href = boundedText(evidence.href) else { continue }
            let resolvedEvidence = try validateEvidence(
                URL(fileURLWithPath: href, relativeTo: virtualDashboardDirectory),
                within: root,
                allowMissing: true
            )
            let resolved = resolvedEvidence.url
            let record = ImportEvidence(
                ticketID: .init(rawValue: task.id),
                label: boundedText(evidence.label) ?? resolved.lastPathComponent,
                path: resolved.path,
                isAvailable: resolvedEvidence.isAvailable
            )
            if let existing = records[resolved.path], existing.ticketID != record.ticketID {
                records[resolved.path] = .init(
                    ticketID: nil,
                    label: existing.label,
                    path: resolved.path,
                    isAvailable: existing.isAvailable
                )
            } else {
                try retainEvidence(record, records: &records)
            }
        }

        let delivery = root.appendingPathComponent("docs/delivery", isDirectory: true)
        try addEvidenceIfPresent(delivery.appendingPathComponent("roadmap.md"), label: "Roadmap", within: root, records: &records)
        try addRecognizedMarkdown(
            in: delivery.appendingPathComponent("task-briefs", isDirectory: true),
            label: "Task brief",
            within: root,
            scannedEntryCount: &scannedEntryCount,
            records: &records
        )
        try addRecognizedMarkdown(
            in: delivery.appendingPathComponent("handoffs", isDirectory: true),
            label: "Handoff",
            within: root,
            scannedEntryCount: &scannedEntryCount,
            records: &records
        )
        try addLedgers(in: delivery, within: root, scannedEntryCount: &scannedEntryCount, records: &records)
        try addLedgers(
            in: delivery.appendingPathComponent("reviews", isDirectory: true),
            within: root,
            scannedEntryCount: &scannedEntryCount,
            records: &records
        )
        return Array(records.values)
    }

    private func addRecognizedMarkdown(
        in directory: URL,
        label: String,
        within root: URL,
        scannedEntryCount: inout Int,
        records: inout [String: ImportEvidence]
    ) throws {
        try scanTopLevel(
            in: directory,
            within: root,
            scannedEntryCount: &scannedEntryCount,
            records: &records
        ) { url in
            guard url.pathExtension.lowercased() == "md" else { return nil }
            return label
        }
    }

    private func addLedgers(
        in directory: URL,
        within root: URL,
        scannedEntryCount: inout Int,
        records: inout [String: ImportEvidence]
    ) throws {
        try scanTopLevel(
            in: directory,
            within: root,
            scannedEntryCount: &scannedEntryCount,
            records: &records
        ) { url in
            guard url.pathExtension.lowercased() == "md",
                  url.deletingPathExtension().lastPathComponent.lowercased().contains("ledger") else {
                return nil
            }
            return "Delivery ledger"
        }
    }

    private func addEvidenceIfPresent(
        _ url: URL,
        label: String,
        within root: URL,
        records: inout [String: ImportEvidence]
    ) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let resolvedEvidence = try validateEvidence(url, within: root, allowMissing: false)
        let resolved = resolvedEvidence.url
        if records[resolved.path] == nil {
            try retainEvidence(
                .init(ticketID: nil, label: label, path: resolved.path, isAvailable: true),
                records: &records
            )
        }
    }

    private func scanTopLevel(
        in requestedDirectory: URL,
        within root: URL,
        scannedEntryCount: inout Int,
        records: inout [String: ImportEvidence],
        label: (URL) -> String?
    ) throws {
        guard FileManager.default.fileExists(atPath: requestedDirectory.path) else { return }
        let directory = AuthorizedProject.canonicalize(requestedDirectory)
        let directoryValues = try directory.resourceValues(forKeys: [.isDirectoryKey])
        guard contains(directory, within: root), directoryValues.isDirectory == true else {
            throw RekonImportError.invalidPath(requestedDirectory.path)
        }
        var enumerationFailed = false
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, _ in
                enumerationFailed = true
                return false
            }
        ) else {
            throw RekonImportError.invalidPath(requestedDirectory.path)
        }
        while let url = enumerator.nextObject() as? URL {
            scannedEntryCount += 1
            guard scannedEntryCount <= Self.maximumScannedEvidenceEntries else {
                throw RekonImportError.limitExceeded("Evidence discovery exceeds 512 scanned entries")
            }
            guard let label = label(url) else { continue }
            try addEvidenceIfPresent(url, label: label, within: root, records: &records)
        }
        guard !enumerationFailed else { throw RekonImportError.invalidPath(requestedDirectory.path) }
    }

    private func validateEvidence(
        _ requestedURL: URL,
        within root: URL,
        allowMissing: Bool
    ) throws -> (url: URL, isAvailable: Bool) {
        let resolved = AuthorizedProject.canonicalize(requestedURL)
        guard contains(resolved, within: root) else {
            throw RekonImportError.invalidPath(requestedURL.path)
        }
        guard FileManager.default.fileExists(atPath: resolved.path) else {
            guard allowMissing else { throw RekonImportError.invalidPath(requestedURL.path) }
            return (resolved, false)
        }
        let values = try resolved.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            throw RekonImportError.invalidPath(requestedURL.path)
        }
        return (resolved, true)
    }

    private func retainEvidence(
        _ evidence: ImportEvidence,
        records: inout [String: ImportEvidence]
    ) throws {
        guard records[evidence.path] != nil || records.count < Self.maximumEvidenceRecords else {
            throw RekonImportError.limitExceeded("Evidence discovery exceeds 1024 records")
        }
        records[evidence.path] = evidence
    }

    private static func readArtifactData(under root: URL, artifactURL: URL) throws -> Data {
        let directoryFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        let rootDescriptor = root.path.withCString { Darwin.open($0, directoryFlags) }
        guard rootDescriptor >= 0 else {
            throw RekonImportError.invalidPath(root.path)
        }
        defer { _ = Darwin.close(rootDescriptor) }

        let docsDescriptor = "docs".withCString { Darwin.openat(rootDescriptor, $0, directoryFlags) }
        guard docsDescriptor >= 0 else {
            throw artifactOpenError(path: artifactURL.path, code: errno)
        }
        defer { _ = Darwin.close(docsDescriptor) }

        let deliveryDescriptor = "delivery".withCString { Darwin.openat(docsDescriptor, $0, directoryFlags) }
        guard deliveryDescriptor >= 0 else {
            throw artifactOpenError(path: artifactURL.path, code: errno)
        }
        defer { _ = Darwin.close(deliveryDescriptor) }

        let fileFlags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC
        let artifactDescriptor = "dashboard-status.json".withCString {
            Darwin.openat(deliveryDescriptor, $0, fileFlags)
        }
        guard artifactDescriptor >= 0 else {
            throw artifactOpenError(path: artifactURL.path, code: errno)
        }
        defer { _ = Darwin.close(artifactDescriptor) }

        var fileStatus = stat()
        guard Darwin.fstat(artifactDescriptor, &fileStatus) == 0 else {
            throw RekonImportError.invalidPath(artifactURL.path)
        }
        guard fileStatus.st_mode & S_IFMT == S_IFREG else {
            throw RekonImportError.invalidPath(artifactURL.path)
        }
        guard fileStatus.st_size >= 0,
              fileStatus.st_size <= off_t(maximumArtifactBytes) else {
            throw RekonImportError.inputTooLarge
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while data.count <= maximumArtifactBytes {
            let requestedCount = min(buffer.count, maximumArtifactBytes + 1 - data.count)
            let readCount = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(artifactDescriptor, bytes.baseAddress, requestedCount)
            }
            if readCount < 0, errno == EINTR { continue }
            guard readCount >= 0 else {
                throw RekonImportError.invalidPath(artifactURL.path)
            }
            guard readCount > 0 else { break }
            data.append(contentsOf: buffer.prefix(readCount))
        }
        guard data.count <= maximumArtifactBytes else {
            throw RekonImportError.inputTooLarge
        }
        return data
    }

    private static func artifactOpenError(path: String, code: Int32) -> RekonImportError {
        code == ENOENT ? .missingArtifact : .invalidPath(path)
    }

    private static func contains(_ candidate: URL, within root: URL) -> Bool {
        let candidateComponents = candidate.pathComponents
        let rootComponents = root.pathComponents
        return candidateComponents.count >= rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }

    private func contains(_ candidate: URL, within root: URL) -> Bool {
        Self.contains(candidate, within: root)
    }

    private static func stableID(_ components: String...) -> String {
        "import-" + components.joined(separator: ":")
    }

    private func isBoundedID(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.utf8.count <= Self.maximumIdentifierBytes
    }

    private func boundedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= Self.maximumTextBytes else { return nil }
        return trimmed
    }

    private func phaseDependencyOrder(_ lhs: ImportPhaseDependency, _ rhs: ImportPhaseDependency) -> Bool {
        (lhs.phaseID.rawValue, lhs.dependsOnPhaseID.rawValue) < (rhs.phaseID.rawValue, rhs.dependsOnPhaseID.rawValue)
    }

    private func ticketDependencyOrder(_ lhs: ImportTicketDependency, _ rhs: ImportTicketDependency) -> Bool {
        (lhs.ticketID.rawValue, lhs.dependsOnTicketID.rawValue) < (rhs.ticketID.rawValue, rhs.dependsOnTicketID.rawValue)
    }

    private func filterCycles<Edge>(
        _ candidates: [Edge],
        subject: (Edge) -> String,
        dependency: (Edge) -> String
    ) -> (accepted: [Edge], rejected: [Edge]) {
        let ordered = candidates.sorted {
            (subject($0), dependency($0)) < (subject($1), dependency($1))
        }
        var accepted: [Edge] = []
        var rejected: [Edge] = []
        var adjacency: [String: Set<String>] = [:]
        var seenEdges = Set<String>()

        for candidate in ordered {
            let source = subject(candidate)
            let target = dependency(candidate)
            let edgeKey = "\(source)\u{0}\(target)"
            guard seenEdges.insert(edgeKey).inserted else { continue }
            if Self.hasPath(from: target, to: source, adjacency: adjacency) {
                rejected.append(candidate)
            } else {
                accepted.append(candidate)
                adjacency[source, default: []].insert(target)
            }
        }
        return (accepted, rejected)
    }

    private static func hasPath(
        from start: String,
        to destination: String,
        adjacency: [String: Set<String>]
    ) -> Bool {
        var pending = [start]
        var visited = Set<String>()
        while let current = pending.popLast() {
            if current == destination { return true }
            guard visited.insert(current).inserted else { continue }
            pending.append(contentsOf: (adjacency[current] ?? []).sorted(by: >))
        }
        return false
    }

    private static func loadDependencyAdjacency(
        from connection: SQLiteConnection,
        projectID: String,
        sql: String
    ) throws -> [String: Set<String>] {
        var adjacency: [String: Set<String>] = [:]
        var offset: Int64 = 0
        while let row = try connection.row(
            sql,
            bindings: [.text(projectID), .integer(offset)]
        ) {
            guard case let .text(sourceID)? = row["source_id"],
                  case let .text(dependencyID)? = row["dependency_id"] else {
                throw StoreError.unavailable("A persisted dependency graph contains an invalid edge")
            }
            adjacency[sourceID, default: []].insert(dependencyID)
            offset += 1
        }
        return adjacency
    }
}

private struct RekonArtifact: Decodable {
    let schemaVersion: Int
    let activePhaseId: String?
    let phases: [RekonPhase]
    let tasks: [RekonTask]
}

private struct RekonPhase: Decodable {
    let id: String
    let label: String?
    let dependsOnPhaseIds: [String]?
}

private struct RekonTask: Decodable {
    let id: String
    let title: String?
    let status: String?
    let phaseId: String?
    let dependsOnTaskIds: [String]?
    let evidence: RekonEvidence?
}

private struct RekonEvidence: Decodable {
    let label: String?
    let href: String?
}

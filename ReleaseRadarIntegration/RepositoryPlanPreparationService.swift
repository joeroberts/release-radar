import CryptoKit
import Foundation
import ReleaseRadarCore

protocol RepositoryPlanPreparationClienting: Sendable {
    func target(model: String, effort: String) async throws -> RepositoryPlanPreparationTarget
    func prepare(_ request: RepositoryPlanPreparationRequest) async throws -> RepositoryPlanPreparationReadback
    func status(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback
    func cancel(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback
    func close(_ identity: RepositoryPlanPreparationIdentity) async throws
}

extension ProjectExecutionSetupClient: RepositoryPlanPreparationClienting {
    func target(model: String, effort: String) async throws -> RepositoryPlanPreparationTarget {
        guard let contextID = try await selectedCodexContextID() else {
            throw CodexExecutionContextError.selectionRequired
        }
        return .init(
            codexContextID: contextID,
            destinationLabel: "Selected ChatGPT Codex context",
            model: model,
            effort: effort
        )
    }

    func prepare(
        _ request: RepositoryPlanPreparationRequest
    ) async throws -> RepositoryPlanPreparationReadback {
        try await preparePlanDraft(request)
    }

    func status(
        _ identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        try await planDraftStatus(identity)
    }

    func cancel(
        _ identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        try await cancelPlanDraft(identity)
    }

    func close(_ identity: RepositoryPlanPreparationIdentity) async throws {
        try await closePlanDraft(identity)
    }
}

actor RepositoryPlanPreparationService: RepositoryPlanPreparationServicing {
    private struct Reservation: Equatable {
        let projectID: ProjectID
        let attemptID: UUID
        let projectionID: UUID
        let proposalID: PlanChangeProposalID
    }

    private struct ActiveAttempt {
        let request: RepositoryPlanPreparationRequest
        let snapshotRoot: URL
        let snapshotBase: URL
        var readback: RepositoryPlanPreparationReadback
        var terminalClosePending: Bool
    }

    private static let model = "gpt-6-astra"
    private static let effort = "high"

    private let client: any RepositoryPlanPreparationClienting
    private let sourceCapture: @Sendable (
        RepositoryPlanPreparationConsent
    ) async throws -> RepositoryPlanSourceManifest
    private let snapshotRoot: @Sendable () throws -> URL
    private let identityGenerator: @Sendable () -> UUID
    private var proposalIDs: [ProjectID: PlanChangeProposalID] = [:]
    private var reservation: Reservation?
    private var activeAttempt: ActiveAttempt?

    init(
        store: DeliveryStore,
        onboarding: FolderProjectOnboarding,
        plugin: CodexPluginLifecycleCoordinator?,
        snapshotRoot: @escaping @Sendable () throws -> URL = {
            try ProjectExecutionFileStore.applicationRoot()
                .appendingPathComponent("PlanPreparation", isDirectory: true)
        },
        identityGenerator: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        client = ProjectExecutionSetupClient(plugin: plugin)
        sourceCapture = { consent in
            try await onboarding.withAuthorizedProject(
                projectID: consent.inventory.projectID
            ) { project in
                try await RepositoryPlanSourceSelection.capture(
                    artifactIDs: consent.selectedSources.map(\.artifactID),
                    from: store,
                    project: project
                )
            }
        }
        self.snapshotRoot = snapshotRoot
        self.identityGenerator = identityGenerator
    }

    init(
        client: any RepositoryPlanPreparationClienting,
        sourceCapture: @escaping @Sendable (
            RepositoryPlanPreparationConsent
        ) async throws -> RepositoryPlanSourceManifest,
        snapshotRoot: @escaping @Sendable () throws -> URL,
        identityGenerator: @escaping @Sendable () -> UUID
    ) {
        self.client = client
        self.sourceCapture = sourceCapture
        self.snapshotRoot = snapshotRoot
        self.identityGenerator = identityGenerator
    }

    func target() async throws -> RepositoryPlanPreparationTarget {
        try await client.target(model: Self.model, effort: Self.effort)
    }

    func start(
        consent: RepositoryPlanPreparationConsent
    ) async throws -> RepositoryPlanPreparationReadback {
        try validate(consent)
        let projectID = consent.inventory.projectID
        let proposalID = proposalIDs[projectID]
            ?? PlanChangeProposalID(rawValue: "proposal-\(projectID.rawValue)")
        let pending = Reservation(
            projectID: projectID,
            attemptID: identityGenerator(),
            projectionID: identityGenerator(),
            proposalID: proposalID
        )
        guard reservation == nil, activeAttempt == nil else {
            throw RepositoryPlanPreparationError(code: .invalidRequest)
        }
        reservation = pending
        proposalIDs[projectID] = proposalID

        var materialized: RepositoryPlanPreparationSnapshotStore.Materialized?
        do {
            let currentTarget = try await client.target(
                model: consent.target.model,
                effort: consent.target.effort
            )
            guard currentTarget == consent.target, reservation == pending else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }

            let manifest = try await sourceCapture(consent)
            guard reservation == pending else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            guard Self.matches(manifest, consent: consent) else {
                throw RepositoryPlanPreparationError(code: .sourceChanged)
            }

            let base = try snapshotRoot()
            let captured = try RepositoryPlanPreparationSnapshotStore.materialize(
                manifest: manifest,
                attemptID: pending.attemptID,
                below: base
            )
            materialized = captured
            let request = RepositoryPlanPreparationRequest(
                identity: .init(
                    registration: manifest.registration,
                    rootID: manifest.rootID,
                    proposalID: pending.proposalID,
                    attemptID: pending.attemptID
                ),
                sourceManifest: manifest,
                snapshot: captured.snapshot,
                projectionID: pending.projectionID,
                projectionRevision: 1,
                codexContextID: currentTarget.codexContextID,
                model: currentTarget.model,
                effort: currentTarget.effort
            )
            guard reservation == pending else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            let initial = RepositoryPlanPreparationReadback(
                identity: request.identity,
                state: .queued,
                threadID: nil,
                turnID: nil,
                draftBytes: nil,
                error: nil
            )
            activeAttempt = .init(
                request: request,
                snapshotRoot: captured.root,
                snapshotBase: captured.base,
                readback: initial,
                terminalClosePending: false
            )
            reservation = nil

            let readback = try await client.prepare(request)
            guard readback.identity == request.identity,
                  activeAttempt?.request.identity == request.identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            activeAttempt?.readback = readback
            try await closeKnownTerminal(readback)
            return readback
        } catch {
            if reservation == pending { reservation = nil }
            if let active = activeAttempt,
               active.request.identity.attemptID == pending.attemptID {
                if let retained = try? await client.status(active.request.identity),
                   retained.identity == active.request.identity {
                    activeAttempt?.readback = retained
                    return retained
                }
                activeAttempt = nil
                try? RepositoryPlanPreparationSnapshotStore.remove(
                    active.snapshotRoot,
                    below: active.snapshotBase
                )
            } else if let materialized {
                try? RepositoryPlanPreparationSnapshotStore.remove(
                    materialized.root,
                    below: materialized.base
                )
            }
            throw error
        }
    }

    func status(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        _ = try requireActive(identity)
        let readback = try await client.status(identity)
        guard readback.identity == identity,
              activeAttempt?.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        activeAttempt?.readback = readback
        activeAttempt?.terminalClosePending = false
        try await closeKnownTerminal(readback)
        return readback
    }

    func cancel(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        let active = try requireActive(identity)
        let readback: RepositoryPlanPreparationReadback
        do {
            readback = try await client.cancel(identity)
        } catch {
            guard activeAttempt?.request.identity == identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            activeAttempt?.readback = Self.unknownReadback(
                from: active.readback,
                error: error
            )
            activeAttempt?.terminalClosePending = false
            throw error
        }
        guard readback.identity == identity,
              activeAttempt?.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        activeAttempt?.readback = readback
        activeAttempt?.terminalClosePending = false
        try await closeKnownTerminal(readback)
        return readback
    }

    func reconcile(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        let active = try requireActive(identity)
        guard active.readback.state == .outcomeUnknown else {
            throw RepositoryPlanPreparationError(code: .invalidRequest)
        }
        if !active.terminalClosePending {
            let readback = try await client.status(identity)
            guard readback.identity == identity,
                  activeAttempt?.request.identity == identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            activeAttempt?.readback = readback
            activeAttempt?.terminalClosePending = false
            if readback.state == .outcomeUnknown {
                return try await closeUncertainAttempt(
                    try requireActive(identity),
                    identity: identity
                )
            }
            if ![.readyForReview, .failed, .cancelled].contains(readback.state) {
                return readback
            }
            try await closeKnownTerminal(readback)
            return readback
        }
        return try await closeUncertainAttempt(active, identity: identity)
    }

    private func closeUncertainAttempt(
        _ active: ActiveAttempt,
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        do {
            try await client.close(identity)
        } catch {
            guard activeAttempt?.request.identity == identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            activeAttempt?.terminalClosePending = true
            throw error
        }
        guard activeAttempt?.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        activeAttempt = nil
        try RepositoryPlanPreparationSnapshotStore.remove(
            active.snapshotRoot,
            below: active.snapshotBase
        )
        return .init(
            identity: identity,
            state: .failed,
            threadID: active.readback.threadID,
            turnID: active.readback.turnID,
            draftBytes: nil,
            error: "The uncertain preparation was ended and its exact runtime was closed."
        )
    }

    private func requireActive(
        _ identity: RepositoryPlanPreparationIdentity
    ) throws -> ActiveAttempt {
        guard let activeAttempt, activeAttempt.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        return activeAttempt
    }

    private func closeKnownTerminal(
        _ readback: RepositoryPlanPreparationReadback
    ) async throws {
        guard [.readyForReview, .failed, .cancelled].contains(readback.state),
              let active = activeAttempt,
              active.request.identity == readback.identity else { return }
        do {
            try await client.close(readback.identity)
        } catch {
            guard activeAttempt?.request.identity == readback.identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            activeAttempt?.readback = Self.unknownReadback(
                from: readback,
                error: error
            )
            activeAttempt?.terminalClosePending = true
            throw error
        }
        guard activeAttempt?.request.identity == readback.identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        activeAttempt = nil
        if readback.state != .readyForReview {
            try RepositoryPlanPreparationSnapshotStore.remove(
                active.snapshotRoot,
                below: active.snapshotBase
            )
        }
    }

    private func validate(_ consent: RepositoryPlanPreparationConsent) throws {
        let selected = consent.selectedSources
        guard consent.inventory.registration.projectID == consent.inventory.projectID,
              !selected.isEmpty,
              selected == selected.sorted(by: Self.ordersByArtifactID),
              Set(selected.map(\.artifactID)).count == selected.count,
              selected.allSatisfy({ consent.inventory.sources.contains($0) }),
              !consent.target.destinationLabel.isEmpty,
              !consent.target.model.isEmpty,
              !consent.target.effort.isEmpty else {
            throw RepositoryPlanPreparationError(code: .invalidRequest)
        }
    }

    private static func matches(
        _ manifest: RepositoryPlanSourceManifest,
        consent: RepositoryPlanPreparationConsent
    ) -> Bool {
        let inventory = consent.inventory
        guard manifest.projectID == inventory.projectID,
              manifest.rootID == inventory.rootID,
              manifest.registration == inventory.registration,
              manifest.repositoryID == inventory.repositoryID,
              manifest.acceptedCatalogVersion == inventory.acceptedCatalogVersion,
              manifest.acceptedCatalogDigest == inventory.acceptedCatalogDigest else {
            return false
        }
        let captured = manifest.sources.map {
            RepositoryPlanSourceOption(
                artifactID: $0.artifactID,
                path: $0.path,
                contentSHA256: $0.contentSHA256,
                lifecycle: $0.lifecycle,
                authority: $0.authority
            )
        }.sorted(by: ordersByArtifactID)
        return captured == consent.selectedSources
    }

    private static func ordersByArtifactID(
        _ lhs: RepositoryPlanSourceOption,
        _ rhs: RepositoryPlanSourceOption
    ) -> Bool {
        Data(lhs.artifactID.utf8).lexicographicallyPrecedes(Data(rhs.artifactID.utf8))
    }

    private static func unknownReadback(
        from readback: RepositoryPlanPreparationReadback,
        error: Error
    ) -> RepositoryPlanPreparationReadback {
        .init(
            identity: readback.identity,
            state: .outcomeUnknown,
            threadID: readback.threadID,
            turnID: readback.turnID,
            draftBytes: nil,
            error: error.localizedDescription
        )
    }
}

private enum RepositoryPlanPreparationSnapshotStore {
    struct Materialized {
        let base: URL
        let root: URL
        let snapshot: RepositoryPlanPreparationSnapshot
    }

    static func materialize(
        manifest: RepositoryPlanSourceManifest,
        attemptID: UUID,
        below base: URL
    ) throws -> Materialized {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: base,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let canonicalBase = base.standardizedFileURL.resolvingSymlinksInPath()
        guard canonicalBase.path == base.standardizedFileURL.path else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        let root = canonicalBase.appendingPathComponent(
            attemptID.uuidString.lowercased(),
            isDirectory: true
        )
        guard !fileManager.fileExists(atPath: root.path) else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        try fileManager.createDirectory(
            at: root.appendingPathComponent("input", isDirectory: true),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent("session", isDirectory: true),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        do {
            for source in manifest.sources {
                let relative = source.path.split(separator: "/", omittingEmptySubsequences: false)
                guard !relative.isEmpty,
                      relative.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
                    throw RepositoryPlanPreparationError(code: .identityMismatch)
                }
                let destination = relative.reduce(
                    root.appendingPathComponent("input", isDirectory: true)
                ) { partial, component in
                    partial.appendingPathComponent(String(component))
                }
                let parent = destination.deletingLastPathComponent()
                try fileManager.createDirectory(
                    at: parent,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                guard destination.standardizedFileURL.path.hasPrefix(root.path + "/input/") else {
                    throw RepositoryPlanPreparationError(code: .identityMismatch)
                }
                try source.bytes.write(to: destination, options: [.withoutOverwriting])
                try fileManager.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: destination.path
                )
            }
            try RepositoryPlanSourceSnapshot.verify(rootURL: root, manifest: manifest)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let digest = SHA256.hash(data: try encoder.encode(manifest))
                .map { String(format: "%02x", $0) }
                .joined()
            return .init(
                base: canonicalBase,
                root: root,
                snapshot: .init(
                    rootPath: root.path,
                    workingPath: root.appendingPathComponent("session", isDirectory: true).path,
                    manifestSHA256: digest
                )
            )
        } catch {
            try? remove(root, below: canonicalBase)
            throw error
        }
    }

    static func remove(_ root: URL, below base: URL) throws {
        let canonicalBase = base.standardizedFileURL.resolvingSymlinksInPath()
        guard root.deletingLastPathComponent().standardizedFileURL.path == canonicalBase.path,
              root.lastPathComponent.count == 36,
              UUID(uuidString: root.lastPathComponent) != nil else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }
}

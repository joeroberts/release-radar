import CryptoKit
import Foundation
import ReleaseRadarCore

protocol RepositoryPlanPreparationClienting: Sendable {
    func target(model: String, effort: String) async throws -> RepositoryPlanPreparationTarget
    func prepare(_ request: RepositoryPlanPreparationRequest) async throws -> RepositoryPlanPreparationReadback
    func prepare(
        _ request: RepositoryPlanPreparationRequest,
        onProgress: @escaping @Sendable (
            RepositoryPlanPreparationReadback
        ) async throws -> Void
    ) async throws -> RepositoryPlanPreparationReadback
    func status(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback
    func cancel(_ identity: RepositoryPlanPreparationIdentity) async throws -> RepositoryPlanPreparationReadback
    func close(_ identity: RepositoryPlanPreparationIdentity) async throws
    func restore(
        request: RepositoryPlanPreparationRequest,
        readback: RepositoryPlanPreparationReadback
    ) async throws
}

extension RepositoryPlanPreparationClienting {
    func prepare(
        _ request: RepositoryPlanPreparationRequest,
        onProgress: @escaping @Sendable (
            RepositoryPlanPreparationReadback
        ) async throws -> Void
    ) async throws -> RepositoryPlanPreparationReadback {
        try await prepare(request)
    }

    func restore(
        request: RepositoryPlanPreparationRequest,
        readback: RepositoryPlanPreparationReadback
    ) async throws {}
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

    func prepare(
        _ request: RepositoryPlanPreparationRequest,
        onProgress: @escaping @Sendable (
            RepositoryPlanPreparationReadback
        ) async throws -> Void
    ) async throws -> RepositoryPlanPreparationReadback {
        try await preparePlanDraft(request, onProgress: onProgress)
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

    func restore(
        request: RepositoryPlanPreparationRequest,
        readback: RepositoryPlanPreparationReadback
    ) async throws {
        try await restorePlanDraft(request, readback: readback)
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
        var pendingTerminalReadback: RepositoryPlanPreparationReadback?
        var runtimeCloseConfirmed: Bool
        var runtimeRestoreRequired: Bool
        var persistenceRevision: Int64?
    }

    private struct PreparedDraftRecord {
        let identity: RepositoryPlanPreparationIdentity
        let request: RepositoryPlanPreparationRequest
        let bytes: Data
    }

    private static let model = "gpt-6-astra"
    private static let effort = "high"

    private let client: any RepositoryPlanPreparationClienting
    private let sourceCapture: @Sendable (
        RepositoryPlanPreparationConsent
    ) async throws -> RepositoryPlanSourceManifest
    private let snapshotRoot: @Sendable () throws -> URL
    private let identityGenerator: @Sendable () -> UUID
    private let persistenceStore: DeliveryStore?
    private let persistenceRequestIDGenerator: @Sendable () -> UUID
    private var proposalIDs: [ProjectID: PlanChangeProposalID] = [:]
    private var reservation: Reservation?
    private var activeAttempt: ActiveAttempt?
    private var preparedDraft: PreparedDraftRecord?

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
        persistenceStore = store
        persistenceRequestIDGenerator = { UUID() }
    }

    init(
        client: any RepositoryPlanPreparationClienting,
        sourceCapture: @escaping @Sendable (
            RepositoryPlanPreparationConsent
        ) async throws -> RepositoryPlanSourceManifest,
        snapshotRoot: @escaping @Sendable () throws -> URL,
        identityGenerator: @escaping @Sendable () -> UUID,
        persistenceStore: DeliveryStore? = nil,
        persistenceRequestIDGenerator: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.client = client
        self.sourceCapture = sourceCapture
        self.snapshotRoot = snapshotRoot
        self.identityGenerator = identityGenerator
        self.persistenceStore = persistenceStore
        self.persistenceRequestIDGenerator = persistenceRequestIDGenerator
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
        preparedDraft = nil
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
            let persistenceRevision: Int64?
            if let persistenceStore {
                persistenceRevision = try await RepositoryPlanPreparationPersistence.begin(
                    request: request,
                    requestID: persistenceRequestIDGenerator(),
                    in: persistenceStore
                ).revision
            } else {
                persistenceRevision = nil
            }
            activeAttempt = .init(
                request: request,
                snapshotRoot: captured.root,
                snapshotBase: captured.base,
                readback: initial,
                terminalClosePending: false,
                pendingTerminalReadback: nil,
                runtimeCloseConfirmed: false,
                runtimeRestoreRequired: false,
                persistenceRevision: persistenceRevision
            )
            reservation = nil

            let readback = try await client.prepare(
                request,
                onProgress: { [weak self] progress in
                    try await self?.recordProgress(progress, request: request)
                }
            )
            guard readback.identity == request.identity,
                  activeAttempt?.request.identity == request.identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            try capturePreparedDraft(readback, request: request)
            activeAttempt?.readback = readback
            if Self.isKnownTerminal(readback) {
                try await closeKnownTerminal(readback)
            } else {
                try await persist(readback)
            }
            return readback
        } catch {
            if reservation == pending { reservation = nil }
            if let active = activeAttempt,
               active.request.identity.attemptID == pending.attemptID {
                if active.runtimeCloseConfirmed || active.pendingTerminalReadback != nil {
                    throw error
                }
                if let retained = try? await client.status(active.request.identity),
                   retained.identity == active.request.identity {
                    try capturePreparedDraft(retained, request: active.request)
                    activeAttempt?.readback = retained
                    if Self.isKnownTerminal(retained) {
                        try await closeKnownTerminal(retained)
                    } else {
                        try await persist(retained)
                    }
                    return retained
                }
                let unknown = Self.unknownReadback(from: active.readback, error: error)
                activeAttempt?.readback = unknown
                try? await persist(unknown)
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
        let active = try requireActive(identity)
        let readback = try await client.status(identity)
        guard readback.identity == identity,
              activeAttempt?.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        try capturePreparedDraft(readback, request: active.request)
        activeAttempt?.readback = readback
        activeAttempt?.terminalClosePending = false
        if Self.isKnownTerminal(readback) {
            try await closeKnownTerminal(readback)
        } else {
            try await persist(readback)
        }
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
            if let unknown = activeAttempt?.readback {
                try? await persist(unknown)
            }
            throw error
        }
        guard readback.identity == identity,
              activeAttempt?.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        try capturePreparedDraft(readback, request: active.request)
        activeAttempt?.readback = readback
        activeAttempt?.terminalClosePending = false
        if Self.isKnownTerminal(readback) {
            try await closeKnownTerminal(readback)
        } else {
            try await persist(readback)
        }
        return readback
    }

    func reconcile(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        let active = try requireActive(identity)
        if let pendingTerminal = active.pendingTerminalReadback {
            try await closeKnownTerminal(pendingTerminal)
            return pendingTerminal
        }
        guard active.readback.state == .outcomeUnknown else {
            throw RepositoryPlanPreparationError(code: .invalidRequest)
        }
        if !active.terminalClosePending {
            if active.runtimeRestoreRequired {
                do {
                    try await client.restore(
                        request: active.request,
                        readback: active.readback
                    )
                    guard activeAttempt?.request.identity == identity else {
                        throw RepositoryPlanPreparationError(code: .identityMismatch)
                    }
                    activeAttempt?.runtimeRestoreRequired = false
                } catch {
                    guard activeAttempt?.request.identity == identity else {
                        throw RepositoryPlanPreparationError(code: .identityMismatch)
                    }
                    activeAttempt?.readback = Self.unknownReadback(
                        from: active.readback,
                        error: error
                    )
                    if let unknown = activeAttempt?.readback {
                        try? await persist(unknown)
                    }
                    throw error
                }
            }
            let readback = try await client.status(identity)
            guard readback.identity == identity,
                  activeAttempt?.request.identity == identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            try capturePreparedDraft(readback, request: active.request)
            activeAttempt?.readback = readback
            activeAttempt?.terminalClosePending = false
            if readback.state == .outcomeUnknown {
                try await persist(readback)
                return try await closeUncertainAttempt(
                    try requireActive(identity),
                    identity: identity
                )
            }
            if ![.readyForReview, .failed, .cancelled].contains(readback.state) {
                try await persist(readback)
                return readback
            }
            try await closeKnownTerminal(readback)
            return readback
        }
        return try await closeUncertainAttempt(active, identity: identity)
    }

    func recover(projectID: ProjectID) async throws -> [RepositoryPlanPreparationReadback] {
        guard let persistenceStore else { return [] }
        let records = try await RepositoryPlanPreparationPersistence.load(
            projectID: projectID,
            from: persistenceStore
        ).filter {
            $0.isCurrent && $0.replacedByAttemptID == nil
                && [.queued, .running, .awaitingResolution, .outcomeUnknown, .readyForReview]
                    .contains($0.state)
        }
        guard let record = records.max(by: { $0.updatedAt < $1.updatedAt }) else { return [] }
        let readback = Self.readback(from: record)
        proposalIDs[projectID] = record.request.identity.proposalID
        let snapshotRoot = URL(fileURLWithPath: record.request.snapshot.rootPath, isDirectory: true)
        let snapshotBase = snapshotRoot.deletingLastPathComponent()
        if record.state == .readyForReview, let bytes = record.draftBytes {
            preparedDraft = .init(
                identity: record.request.identity,
                request: record.request,
                bytes: bytes
            )
            activeAttempt = nil
        } else {
            activeAttempt = .init(
                request: record.request,
                snapshotRoot: snapshotRoot,
                snapshotBase: snapshotBase,
                readback: readback,
                terminalClosePending: false,
                pendingTerminalReadback: nil,
                runtimeCloseConfirmed: false,
                runtimeRestoreRequired: true,
                persistenceRevision: record.revision
            )
            preparedDraft = nil
            do {
                try await client.restore(request: record.request, readback: readback)
                activeAttempt?.runtimeRestoreRequired = false
                let observed = try await client.status(record.request.identity)
                guard observed.identity == record.request.identity else {
                    throw RepositoryPlanPreparationError(code: .identityMismatch)
                }
                try capturePreparedDraft(observed, request: record.request)
                activeAttempt?.readback = observed
                if Self.isKnownTerminal(observed) {
                    try await closeKnownTerminal(observed)
                } else {
                    try await persist(observed)
                }
                reservation = nil
                return [observed]
            } catch {
                let unknown = Self.unknownReadback(from: readback, error: error)
                activeAttempt?.readback = unknown
                try await persist(unknown)
                return [unknown]
            }
        }
        reservation = nil
        return [readback]
    }

    func reviewDraft(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparedDraft {
        guard let preparedDraft, preparedDraft.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        let request = preparedDraft.request
        let validated = try RepositoryPlanProjectionValidator.validate(
            preparedDraft.bytes,
            against: request.sourceManifest
        )
        guard validated.projection.projectionID.lowercased()
                == request.projectionID.uuidString.lowercased(),
              validated.projection.projectionRevision == request.projectionRevision else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        let manifest = request.sourceManifest
        return .init(
            source: .init(
                projectID: manifest.projectID,
                rootID: manifest.rootID,
                registration: manifest.registration,
                repositoryID: manifest.repositoryID,
                projectionID: request.projectionID,
                projectionRevision: request.projectionRevision,
                projectionBytes: validated.bytes,
                projectionSHA256: validated.contentSHA256,
                acceptedCatalogVersion: manifest.acceptedCatalogVersion,
                acceptedCatalogDigest: manifest.acceptedCatalogDigest,
                capturedSourceManifest: manifest,
                observedGitHEAD: nil
            ),
            originalProjection: validated.projection
        )
    }

    private func capturePreparedDraft(
        _ readback: RepositoryPlanPreparationReadback,
        request: RepositoryPlanPreparationRequest
    ) throws {
        guard readback.state == .readyForReview else { return }
        guard readback.identity == request.identity, let bytes = readback.draftBytes else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        preparedDraft = .init(
            identity: request.identity,
            request: request,
            bytes: bytes
        )
    }

    private func closeUncertainAttempt(
        _ active: ActiveAttempt,
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback {
        if !active.runtimeCloseConfirmed {
            do {
                try await client.close(identity)
            } catch {
                guard activeAttempt?.request.identity == identity else {
                    throw RepositoryPlanPreparationError(code: .identityMismatch)
                }
                if let failure = error as? RepositoryPlanPreparationError,
                   failure.code == .outcomeUnknown {
                    activeAttempt?.terminalClosePending = false
                } else {
                    activeAttempt?.terminalClosePending = true
                }
                throw error
            }
        }
        guard activeAttempt?.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        let terminal = RepositoryPlanPreparationReadback(
            identity: identity,
            state: .failed,
            threadID: active.readback.threadID,
            turnID: active.readback.turnID,
            draftBytes: nil,
            error: "The uncertain preparation was ended and its exact runtime was closed."
        )
        activeAttempt?.runtimeCloseConfirmed = true
        activeAttempt?.terminalClosePending = false
        activeAttempt?.pendingTerminalReadback = terminal
        try await persist(terminal)
        activeAttempt = nil
        try RepositoryPlanPreparationSnapshotStore.remove(
            active.snapshotRoot,
            below: active.snapshotBase
        )
        return terminal
    }

    private func requireActive(
        _ identity: RepositoryPlanPreparationIdentity
    ) throws -> ActiveAttempt {
        guard let activeAttempt, activeAttempt.request.identity == identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        return activeAttempt
    }

    private func persist(_ readback: RepositoryPlanPreparationReadback) async throws {
        guard let persistenceStore,
              let active = activeAttempt,
              let revision = active.persistenceRevision else { return }
        let record = try await RepositoryPlanPreparationPersistence.record(
            identity: active.request.identity,
            expectedRevision: revision,
            readback: readback,
            in: persistenceStore
        )
        guard activeAttempt?.request.identity == active.request.identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        activeAttempt?.persistenceRevision = record.revision
    }

    private func recordProgress(
        _ readback: RepositoryPlanPreparationReadback,
        request: RepositoryPlanPreparationRequest
    ) async throws {
        guard readback.identity == request.identity,
              activeAttempt?.request == request,
              [.queued, .running, .awaitingResolution, .outcomeUnknown]
                .contains(readback.state) else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        activeAttempt?.readback = readback
        try await persist(readback)
    }

    private static func readback(
        from record: RepositoryPlanPreparationRecord
    ) -> RepositoryPlanPreparationReadback {
        .init(
            identity: record.request.identity,
            state: record.state,
            threadID: record.threadID,
            turnID: record.turnID,
            draftBytes: record.draftBytes,
            error: record.error
        )
    }

    private func closeKnownTerminal(
        _ readback: RepositoryPlanPreparationReadback
    ) async throws {
        guard Self.isKnownTerminal(readback),
              let active = activeAttempt,
              active.request.identity == readback.identity else { return }
        activeAttempt?.pendingTerminalReadback = readback
        if !active.runtimeCloseConfirmed {
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
                if let unknown = activeAttempt?.readback {
                    try? await persist(unknown)
                }
                throw error
            }
        }
        guard activeAttempt?.request.identity == readback.identity else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        activeAttempt?.runtimeCloseConfirmed = true
        activeAttempt?.terminalClosePending = false
        activeAttempt?.readback = readback
        try await persist(readback)
        activeAttempt = nil
        if readback.state != .readyForReview {
            try RepositoryPlanPreparationSnapshotStore.remove(
                active.snapshotRoot,
                below: active.snapshotBase
            )
        }
    }

    private static func isKnownTerminal(_ readback: RepositoryPlanPreparationReadback) -> Bool {
        [.readyForReview, .failed, .cancelled].contains(readback.state)
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

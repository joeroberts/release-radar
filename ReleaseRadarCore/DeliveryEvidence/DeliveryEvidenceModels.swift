import Foundation

public enum DeliveryEvidenceCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case repository
    case commit
    case pullRequest
    case check
    case document
    case build
    case installation
}

public enum DeliveryEvidenceCheckoutState: String, Codable, Equatable, Sendable {
    case clean
    case dirty
    case unknown
}

public struct DeliveryEvidenceRevision: Codable, Equatable, Sendable {
    public let commitSHA: String
    public let checkoutState: DeliveryEvidenceCheckoutState
    public let dirtySnapshotID: String?

    public init(commitSHA: String, checkoutState: DeliveryEvidenceCheckoutState, dirtySnapshotID: String?) {
        self.commitSHA = commitSHA
        self.checkoutState = checkoutState
        self.dirtySnapshotID = dirtySnapshotID
    }
}

public struct DeliveryEvidenceExpectation: Codable, Equatable, Sendable {
    public let category: DeliveryEvidenceCategory
    public let scope: String?

    public init(category: DeliveryEvidenceCategory, scope: String?) {
        self.category = category
        self.scope = scope
    }
}

public struct DeliveryEvidenceTargetVersion: Codable, Equatable, Sendable {
    public let version: Int
    public let repositoryID: String
    public let rootID: String
    public let revision: DeliveryEvidenceRevision
    public let expectations: [DeliveryEvidenceExpectation]
    public let registrationID: String
    public let requestGeneration: Int
    public let recordedAt: String

    public init(
        version: Int,
        repositoryID: String,
        rootID: String,
        revision: DeliveryEvidenceRevision,
        expectations: [DeliveryEvidenceExpectation],
        registrationID: String,
        requestGeneration: Int,
        recordedAt: String
    ) {
        self.version = version
        self.repositoryID = repositoryID
        self.rootID = rootID
        self.revision = revision
        self.expectations = expectations
        self.registrationID = registrationID
        self.requestGeneration = requestGeneration
        self.recordedAt = recordedAt
    }
}

public struct DeliveryEvidenceRepositoryFact: Codable, Equatable, Sendable {
    public let repositoryID: String
    public let rootID: String?
    public let revision: DeliveryEvidenceRevision

    public init(repositoryID: String, rootID: String?, revision: DeliveryEvidenceRevision) {
        self.repositoryID = repositoryID
        self.rootID = rootID
        self.revision = revision
    }
}

public struct DeliveryEvidenceCommitFact: Codable, Equatable, Sendable {
    public let repositoryID: String
    public let revision: DeliveryEvidenceRevision

    public init(repositoryID: String, revision: DeliveryEvidenceRevision) {
        self.repositoryID = repositoryID
        self.revision = revision
    }
}

public enum DeliveryEvidencePullRequestState: String, Codable, Equatable, Sendable {
    case open
    case closed
    case merged
    case unknown
}

public struct DeliveryEvidencePullRequestFact: Codable, Equatable, Sendable {
    public let repositoryID: String
    public let revision: DeliveryEvidenceRevision
    public let number: Int
    public let headSHA: String
    public let mergeSHA: String?
    public let state: DeliveryEvidencePullRequestState

    var hasConsistentRevision: Bool {
        revision.commitSHA.caseInsensitiveCompare(headSHA) == .orderedSame
            || (state == .merged && mergeSHA.map {
                revision.commitSHA.caseInsensitiveCompare($0) == .orderedSame
            } == true)
    }

    public init(
        repositoryID: String,
        revision: DeliveryEvidenceRevision,
        number: Int,
        headSHA: String,
        mergeSHA: String?,
        state: DeliveryEvidencePullRequestState
    ) {
        self.repositoryID = repositoryID
        self.revision = revision
        self.number = number
        self.headSHA = headSHA
        self.mergeSHA = mergeSHA
        self.state = state
    }
}

public struct DeliveryEvidenceCheckFact: Codable, Equatable, Sendable {
    public let scope: String

    public init(scope: String) {
        self.scope = scope
    }
}

public struct DeliveryEvidenceDocumentFact: Codable, Equatable, Sendable {
    public let repositoryID: String
    public let revision: DeliveryEvidenceRevision
    public let artifactID: String
    public let contentDigest: String
    public let catalogVersion: Int
    public let catalogDigest: String

    public init(
        repositoryID: String,
        revision: DeliveryEvidenceRevision,
        artifactID: String,
        contentDigest: String,
        catalogVersion: Int,
        catalogDigest: String
    ) {
        self.repositoryID = repositoryID
        self.revision = revision
        self.artifactID = artifactID
        self.contentDigest = contentDigest
        self.catalogVersion = catalogVersion
        self.catalogDigest = catalogDigest
    }
}

public struct DeliveryEvidenceBuildFact: Codable, Equatable, Sendable {
    public let repositoryID: String
    public let revision: DeliveryEvidenceRevision
    public let buildID: String
    public let scope: String?

    public init(repositoryID: String, revision: DeliveryEvidenceRevision, buildID: String, scope: String?) {
        self.repositoryID = repositoryID
        self.revision = revision
        self.buildID = buildID
        self.scope = scope
    }
}

public struct DeliveryEvidenceInstallationFact: Codable, Equatable, Sendable {
    public let repositoryID: String?
    public let revision: DeliveryEvidenceRevision?
    public let installationID: String?
    public let buildID: String?
    public let context: String

    public init(
        repositoryID: String?,
        revision: DeliveryEvidenceRevision?,
        installationID: String?,
        buildID: String?,
        context: String
    ) {
        self.repositoryID = repositoryID
        self.revision = revision
        self.installationID = installationID
        self.buildID = buildID
        self.context = context
    }
}

public enum DeliveryEvidenceFact: Codable, Equatable, Sendable {
    case repository(DeliveryEvidenceRepositoryFact)
    case commit(DeliveryEvidenceCommitFact)
    case pullRequest(DeliveryEvidencePullRequestFact)
    case check(DeliveryEvidenceCheckFact)
    case document(DeliveryEvidenceDocumentFact)
    case build(DeliveryEvidenceBuildFact)
    case installation(DeliveryEvidenceInstallationFact)

    public var category: DeliveryEvidenceCategory {
        switch self {
        case .repository: .repository
        case .commit: .commit
        case .pullRequest: .pullRequest
        case .check: .check
        case .document: .document
        case .build: .build
        case .installation: .installation
        }
    }

    public var repositoryID: String? {
        switch self {
        case let .repository(fact): fact.repositoryID
        case let .commit(fact): fact.repositoryID
        case let .pullRequest(fact): fact.repositoryID
        case .check: nil
        case let .document(fact): fact.repositoryID
        case let .build(fact): fact.repositoryID
        case let .installation(fact): fact.repositoryID
        }
    }

    public var revision: DeliveryEvidenceRevision? {
        switch self {
        case let .repository(fact): fact.revision
        case let .commit(fact): fact.revision
        case let .pullRequest(fact): fact.revision
        case .check: nil
        case let .document(fact): fact.revision
        case let .build(fact): fact.revision
        case let .installation(fact): fact.revision
        }
    }

    public var scope: String? {
        switch self {
        case let .check(fact): fact.scope
        case let .build(fact): fact.scope
        default: nil
        }
    }
}

public enum DeliveryEvidenceSourceKind: String, Codable, Equatable, Sendable {
    case localObservation
    case recordedClaim
    case managedDocument
    case importedLegacy
}

public struct DeliveryEvidenceSource: Codable, Equatable, Sendable {
    public let kind: DeliveryEvidenceSourceKind
    public let label: String

    public init(kind: DeliveryEvidenceSourceKind, label: String) {
        self.kind = kind
        self.label = label
    }
}

public enum DeliveryEvidenceSourceAvailability: String, Codable, Equatable, Sendable {
    case available
    case unavailable
    case unknown
}

public enum DeliveryEvidenceOutcome: String, Codable, Equatable, Sendable {
    case observed
    case passed
    case failed
    case skipped
    case unknown
}

public struct DeliveryEvidenceObservation: Codable, Equatable, Sendable {
    public let id: String
    public let targetVersion: Int
    public let fact: DeliveryEvidenceFact
    public let source: DeliveryEvidenceSource
    public let sourceAvailability: DeliveryEvidenceSourceAvailability
    public let outcome: DeliveryEvidenceOutcome
    public let observedAt: String
    /// Readback contains application recording time. On input this legacy field
    /// remains part of exact replay identity but never supplies persisted time.
    public let recordedAt: String
    public let attachmentEvidenceID: String?
    public let supersedesObservationID: String?

    public init(
        id: String,
        targetVersion: Int,
        fact: DeliveryEvidenceFact,
        source: DeliveryEvidenceSource,
        sourceAvailability: DeliveryEvidenceSourceAvailability,
        outcome: DeliveryEvidenceOutcome,
        observedAt: String,
        recordedAt: String,
        attachmentEvidenceID: String? = nil,
        supersedesObservationID: String? = nil
    ) {
        self.id = id
        self.targetVersion = targetVersion
        self.fact = fact
        self.source = source
        self.sourceAvailability = sourceAvailability
        self.outcome = outcome
        self.observedAt = observedAt
        self.recordedAt = recordedAt
        self.attachmentEvidenceID = attachmentEvidenceID
        self.supersedesObservationID = supersedesObservationID
    }
}

public enum DeliveryEvidenceApplicabilityState: String, Codable, Equatable, Sendable {
    case applicable
    case stale
    case unknown
}

public enum DeliveryEvidenceApplicabilityReason: String, Codable, Equatable, Sendable {
    case targetVersionMismatch
    case repositoryMismatch
    case repositoryUnknown
    case revisionMismatch
    case revisionUnknown
    case checkoutStateMismatch
    case dirtySnapshotMismatch
    case scopeMismatch
    case installationIdentityUnknown
    case documentContentChanged
    case documentCatalogChanged
}

public struct DeliveryEvidenceApplicability: Codable, Equatable, Sendable {
    public let state: DeliveryEvidenceApplicabilityState
    public let reasons: [DeliveryEvidenceApplicabilityReason]

    public init(state: DeliveryEvidenceApplicabilityState, reasons: [DeliveryEvidenceApplicabilityReason]) {
        self.state = state
        self.reasons = reasons
    }
}

public enum DeliveryEvidenceExpectationStatus: String, Codable, Equatable, Sendable {
    case satisfied
    case failed
    case skipped
    case missing
    case unavailable
    case unknown
    case notSpecified
}

public struct DeliveryEvidenceExpectationAssessment: Codable, Equatable, Sendable {
    public let expectation: DeliveryEvidenceExpectation
    public let status: DeliveryEvidenceExpectationStatus
    public let observationID: String?

    public init(
        expectation: DeliveryEvidenceExpectation,
        status: DeliveryEvidenceExpectationStatus,
        observationID: String?
    ) {
        self.expectation = expectation
        self.status = status
        self.observationID = observationID
    }
}

public enum DeliveryEvidenceOwnerAcceptance: String, Codable, Equatable, Sendable {
    case accepted
    case notAccepted
    case unknown
}

public struct DeliveryEvidenceResolvedObservation: Codable, Equatable, Sendable, Identifiable {
    public var id: String { observation.id }
    public let observation: DeliveryEvidenceObservation
    public let applicability: DeliveryEvidenceApplicability
    public let currentSourceAvailability: DeliveryEvidenceSourceAvailability
    public let currentDocumentDigest: String?

    public init(
        observation: DeliveryEvidenceObservation,
        applicability: DeliveryEvidenceApplicability,
        currentSourceAvailability: DeliveryEvidenceSourceAvailability,
        currentDocumentDigest: String?
    ) {
        self.observation = observation
        self.applicability = applicability
        self.currentSourceAvailability = currentSourceAvailability
        self.currentDocumentDigest = currentDocumentDigest
    }
}

public struct TicketDeliveryEvidence: Codable, Equatable, Sendable {
    public let projectID: String
    public let ticketID: String
    public let phaseID: String?
    public let phaseLabel: String
    public let revision: Int64
    public let currentTargetVersion: Int?
    public let targets: [DeliveryEvidenceTargetVersion]
    public let observations: [DeliveryEvidenceResolvedObservation]
    public let expectations: [DeliveryEvidenceExpectationAssessment]
    public let ownerAcceptance: DeliveryEvidenceOwnerAcceptance

    public init(
        projectID: String,
        ticketID: String,
        phaseID: String?,
        phaseLabel: String,
        revision: Int64,
        currentTargetVersion: Int?,
        targets: [DeliveryEvidenceTargetVersion],
        observations: [DeliveryEvidenceResolvedObservation],
        expectations: [DeliveryEvidenceExpectationAssessment],
        ownerAcceptance: DeliveryEvidenceOwnerAcceptance
    ) {
        self.projectID = projectID
        self.ticketID = ticketID
        self.phaseID = phaseID
        self.phaseLabel = phaseLabel
        self.revision = revision
        self.currentTargetVersion = currentTargetVersion
        self.targets = targets
        self.observations = observations
        self.expectations = expectations
        self.ownerAcceptance = ownerAcceptance
    }
}

public enum DeliveryEvidenceApplicabilityEvaluator {
    public static func evaluate(
        _ observation: DeliveryEvidenceObservation,
        against target: DeliveryEvidenceTargetVersion
    ) -> DeliveryEvidenceApplicability {
        var stale: [DeliveryEvidenceApplicabilityReason] = []
        var unknown: [DeliveryEvidenceApplicabilityReason] = []

        if observation.targetVersion != target.version {
            stale.append(.targetVersionMismatch)
        }

        if let repositoryID = observation.fact.repositoryID {
            if repositoryID.caseInsensitiveCompare(target.repositoryID) != .orderedSame {
                stale.append(.repositoryMismatch)
            }
        } else if observation.fact.category == .installation {
            unknown.append(.repositoryUnknown)
        }

        if stale.contains(.repositoryMismatch) {
            // Revision details from another repository cannot add a meaningful
            // applicability fact beyond the identity mismatch.
        } else if let revision = observation.fact.revision
                    ?? (observation.fact.category == .check ? target.revision : nil) {
            if revision.commitSHA.caseInsensitiveCompare(target.revision.commitSHA) != .orderedSame {
                stale.append(.revisionMismatch)
            } else if revision.checkoutState == .unknown || target.revision.checkoutState == .unknown {
                unknown.append(.revisionUnknown)
            } else if revision.checkoutState != target.revision.checkoutState {
                stale.append(.checkoutStateMismatch)
            } else if revision.checkoutState == .dirty,
                      revision.dirtySnapshotID?.isEmpty != false || target.revision.dirtySnapshotID?.isEmpty != false {
                unknown.append(.revisionUnknown)
            } else if revision.checkoutState == .dirty,
                      revision.dirtySnapshotID != target.revision.dirtySnapshotID {
                stale.append(.dirtySnapshotMismatch)
            }
        } else if observation.fact.category == .installation {
            unknown.append(.revisionUnknown)
        }

        if case let .pullRequest(fact) = observation.fact,
           !fact.hasConsistentRevision,
           !stale.contains(.revisionMismatch) {
            stale.append(.revisionMismatch)
        }

        if case let .repository(fact) = observation.fact,
           let rootID = fact.rootID,
           rootID != target.rootID {
            stale.append(.repositoryMismatch)
        }

        if case let .installation(fact) = observation.fact,
           fact.installationID == nil || fact.buildID == nil {
            unknown.append(.installationIdentityUnknown)
        }

        if !stale.isEmpty {
            return .init(state: .stale, reasons: stale)
        }
        if !unknown.isEmpty {
            return .init(state: .unknown, reasons: unknown)
        }
        return .init(state: .applicable, reasons: [])
    }

    public static func assessExpectations(
        target: DeliveryEvidenceTargetVersion,
        observations: [DeliveryEvidenceObservation]
    ) -> [DeliveryEvidenceExpectationAssessment] {
        let superseded = Set(observations.compactMap(\.supersedesObservationID))
        return target.expectations.map { expectation in
            let matching = observations
                .filter { !superseded.contains($0.id) }
                .filter { $0.fact.category == expectation.category && $0.fact.scope == expectation.scope }
                .filter { evaluate($0, against: target).state == .applicable }
            guard let observation = matching.last else {
                return .init(expectation: expectation, status: .missing, observationID: nil)
            }
            return .init(
                expectation: expectation,
                status: expectationStatus(for: observation),
                observationID: observation.id
            )
        }
    }

    public static func assessExpectations(
        target: DeliveryEvidenceTargetVersion,
        resolvedObservations: [DeliveryEvidenceResolvedObservation]
    ) -> [DeliveryEvidenceExpectationAssessment] {
        let superseded = Set(resolvedObservations.compactMap { $0.observation.supersedesObservationID })
        return target.expectations.map { expectation in
            let matching = resolvedObservations.filter {
                !superseded.contains($0.id)
                    && $0.observation.fact.category == expectation.category
                    && $0.observation.fact.scope == expectation.scope
                    && $0.applicability.state == .applicable
            }
            guard let resolved = matching.last else {
                return .init(expectation: expectation, status: .missing, observationID: nil)
            }
            let availability = resolved.currentSourceAvailability
            guard availability == .available else {
                return .init(
                    expectation: expectation,
                    status: availability == .unavailable ? .unavailable : .unknown,
                    observationID: resolved.observation.id
                )
            }
            return .init(
                expectation: expectation,
                status: outcomeStatus(resolved.observation.outcome),
                observationID: resolved.observation.id
            )
        }
    }

    public static func status(
        for category: DeliveryEvidenceCategory,
        scope: String?,
        target: DeliveryEvidenceTargetVersion,
        observations: [DeliveryEvidenceObservation]
    ) -> DeliveryEvidenceExpectationStatus {
        guard target.expectations.contains(where: { $0.category == category && $0.scope == scope }) else {
            return .notSpecified
        }
        return assessExpectations(target: target, observations: observations)
            .first(where: { $0.expectation.category == category && $0.expectation.scope == scope })?
            .status ?? .missing
    }

    private static func expectationStatus(
        for observation: DeliveryEvidenceObservation
    ) -> DeliveryEvidenceExpectationStatus {
        guard observation.sourceAvailability == .available else {
            return observation.sourceAvailability == .unavailable ? .unavailable : .unknown
        }
        return outcomeStatus(observation.outcome)
    }

    private static func outcomeStatus(
        _ outcome: DeliveryEvidenceOutcome
    ) -> DeliveryEvidenceExpectationStatus {
        switch outcome {
        case .observed, .passed: return .satisfied
        case .failed: return .failed
        case .skipped: return .skipped
        case .unknown: return .unknown
        }
    }
}

enum DeliveryEvidenceMutationError: Error, Equatable, Sendable {
    case revisionConflict(expected: Int64, current: Int64)
    case notFound
    case ticketAccepted
    case ticketRetired
    case invalid(String)
}

extension AgentCommand {
    var isDeliveryEvidenceMutation: Bool {
        switch self {
        case .recordDeliveryEvidenceTarget, .appendDeliveryEvidenceObservation: true
        default: false
        }
    }

    var deliveryEvidenceProjectRootAndTicket: (projectID: String, rootID: String, ticketID: String)? {
        switch self {
        case let .recordDeliveryEvidenceTarget(target, ticketID, _, _, _),
             let .appendDeliveryEvidenceObservation(target, ticketID, _, _):
            (target.projectID, target.rootID, ticketID)
        default: nil
        }
    }

    func validateDeliveryEvidence() throws {
        func valid(_ value: String, maximum: Int = 4096) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && value.utf8.count <= maximum
                && !value.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
        }
        func validRevision(_ revision: DeliveryEvidenceRevision) -> Bool {
            validSHA(revision.commitSHA)
                && ((revision.checkoutState == .dirty) == (revision.dirtySnapshotID != nil))
                && (revision.dirtySnapshotID.map { valid($0, maximum: 256) } ?? true)
        }
        func validSHA(_ value: String) -> Bool {
            (40...64).contains(value.utf8.count)
                && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        }
        func validDigest(_ value: String) -> Bool {
            value.utf8.count == 64
                && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        }
        func validRepositoryID(_ value: String) -> Bool {
            UUID(uuidString: value) != nil && value == value.lowercased()
        }
        guard let identity = deliveryEvidenceProjectRootAndTicket,
              valid(identity.projectID, maximum: 256),
              valid(identity.rootID, maximum: 256),
              valid(identity.ticketID, maximum: 256) else {
            throw DeliveryEvidenceMutationError.invalid("Evidence identity is invalid")
        }
        switch self {
        case let .recordDeliveryEvidenceTarget(target, _, revision, expectations, expected):
            guard expected >= 0,
                  UUID(uuidString: target.repositoryID) != nil,
                  target.repositoryID == target.repositoryID.lowercased(),
                  validRevision(revision),
                  expectations.count <= 64,
                  expectations.allSatisfy { $0.scope.map { valid($0, maximum: 256) } ?? true },
                  Set(expectations.map { "\($0.category.rawValue)\u{0}\($0.scope ?? "")" }).count == expectations.count else {
                throw DeliveryEvidenceMutationError.invalid("Evidence target is invalid")
            }
        case let .appendDeliveryEvidenceObservation(_, _, observation, expected):
            guard expected > 0,
                  valid(observation.id, maximum: 256),
                  observation.targetVersion > 0,
                  valid(observation.source.label, maximum: 1024),
                  valid(observation.observedAt, maximum: 64),
                  valid(observation.recordedAt, maximum: 64),
                  observation.attachmentEvidenceID.map { valid($0, maximum: 256) } ?? true,
                  observation.supersedesObservationID.map { valid($0, maximum: 256) } ?? true,
                  observation.supersedesObservationID != observation.id else {
                throw DeliveryEvidenceMutationError.invalid("Evidence observation is invalid")
            }
            if let repositoryID = observation.fact.repositoryID,
               !validRepositoryID(repositoryID) {
                throw DeliveryEvidenceMutationError.invalid("Evidence repository identity is invalid")
            }
            if let revision = observation.fact.revision, !validRevision(revision) {
                throw DeliveryEvidenceMutationError.invalid("Evidence revision is invalid")
            }
            let factIsValid: Bool
            switch observation.fact {
            case let .repository(fact):
                factIsValid = fact.rootID.map { valid($0, maximum: 256) } ?? true
            case .commit:
                factIsValid = true
            case let .pullRequest(fact):
                factIsValid = fact.number > 0
                    && validSHA(fact.headSHA)
                    && (fact.mergeSHA.map(validSHA) ?? true)
                    && fact.hasConsistentRevision
            case let .check(fact):
                factIsValid = valid(fact.scope, maximum: 256)
            case let .document(fact):
                factIsValid = valid(fact.artifactID, maximum: 128)
                    && validDigest(fact.contentDigest)
                    && fact.catalogVersion > 0
                    && validDigest(fact.catalogDigest)
            case let .build(fact):
                factIsValid = valid(fact.buildID, maximum: 256)
                    && (fact.scope.map { valid($0, maximum: 256) } ?? true)
            case let .installation(fact):
                factIsValid = valid(fact.context)
                    && (fact.installationID.map { valid($0, maximum: 256) } ?? true)
                    && (fact.buildID.map { valid($0, maximum: 256) } ?? true)
            }
            guard factIsValid else {
                throw DeliveryEvidenceMutationError.invalid("Evidence fact is invalid")
            }
        default:
            throw DeliveryEvidenceMutationError.invalid("Evidence command is invalid")
        }
    }
}

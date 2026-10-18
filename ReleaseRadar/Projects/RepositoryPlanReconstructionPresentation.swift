import Foundation
import ReleaseRadarCore

protocol RepositoryPlanPreparationServicing: Sendable {
    func target() async throws -> RepositoryPlanPreparationTarget
    func start(consent: RepositoryPlanPreparationConsent) async throws -> RepositoryPlanPreparationReadback

    func status(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback

    func cancel(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback

    func reconcile(
        identity: RepositoryPlanPreparationIdentity
    ) async throws -> RepositoryPlanPreparationReadback
}

struct RepositoryPlanPreparationTarget: Codable, Equatable, Sendable {
    let codexContextID: UUID
    let destinationLabel: String
    let model: String
    let effort: String
}

struct RepositoryPlanPreparationConsent: Codable, Equatable, Sendable {
    let inventory: RepositoryPlanSourceInventory
    let selectedSources: [RepositoryPlanSourceOption]
    let target: RepositoryPlanPreparationTarget
}

enum RepositoryPlanReconstructionStage: Equatable, Sendable {
    case loadingSources
    case selectingSources
    case starting
    case preparing(RepositoryPlanPreparationState)
    case reviewing
    case applying
    case outcomeUnknown
    case applied
    case failed
}

struct RepositoryPlanReconstructionPresentation: Equatable, Sendable {
    let projectID: ProjectID
    var stage: RepositoryPlanReconstructionStage
    var inventory: RepositoryPlanSourceInventory?
    var target: RepositoryPlanPreparationTarget?
    var selectedArtifactIDs: Set<String>
    var preparation: RepositoryPlanPreparationReadback?
    var message: String?

    static func loading(projectID: ProjectID) -> Self {
        .init(
            projectID: projectID,
            stage: .loadingSources,
            inventory: nil,
            target: nil,
            selectedArtifactIDs: [],
            preparation: nil,
            message: nil
        )
    }

    static func selecting(
        projectID: ProjectID,
        inventory: RepositoryPlanSourceInventory,
        target: RepositoryPlanPreparationTarget,
        message: String? = nil
    ) -> Self {
        .init(
            projectID: projectID,
            stage: .selectingSources,
            inventory: inventory,
            target: target,
            selectedArtifactIDs: [],
            preparation: nil,
            message: message
        )
    }

    static func failed(projectID: ProjectID, message: String) -> Self {
        .init(
            projectID: projectID,
            stage: .failed,
            inventory: nil,
            target: nil,
            selectedArtifactIDs: [],
            preparation: nil,
            message: message
        )
    }

    mutating func apply(_ readback: RepositoryPlanPreparationReadback) {
        preparation = readback
        stage = readback.state == .outcomeUnknown
            ? .outcomeUnknown
            : .preparing(readback.state)
        message = readback.error
    }

    var sources: [RepositoryPlanSourceOption] {
        inventory?.sources ?? []
    }
}

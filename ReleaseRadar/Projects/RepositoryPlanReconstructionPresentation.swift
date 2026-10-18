import Foundation
import ReleaseRadarCore

enum RepositoryPlanReconstructionStage: Equatable, Sendable {
    case loadingSources
    case selectingSources
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
    var sources: [RepositoryPlanSourceOption]
    var selectedArtifactIDs: Set<String>
    var message: String?

    static func loading(projectID: ProjectID) -> Self {
        .init(
            projectID: projectID,
            stage: .loadingSources,
            sources: [],
            selectedArtifactIDs: [],
            message: nil
        )
    }

    static func selecting(
        projectID: ProjectID,
        sources: [RepositoryPlanSourceOption]
    ) -> Self {
        .init(
            projectID: projectID,
            stage: .selectingSources,
            sources: sources,
            selectedArtifactIDs: [],
            message: nil
        )
    }

    static func failed(projectID: ProjectID, message: String) -> Self {
        .init(
            projectID: projectID,
            stage: .failed,
            sources: [],
            selectedArtifactIDs: [],
            message: message
        )
    }
}

import Foundation
import ReleaseRadarCore
import XCTest

final class RepositoryPlanReconstructionPublicAPITests: XCTestCase {
    func testPublicCorrectionDerivesExactProjectionAndRejectsSourceMismatch() throws {
        let phase = RepositoryPlanProjectionPhase(
            sourceID: "phase-current",
            authorityClass: .currentApproved,
            sourceRefs: [.projection(pointer: "/phases/0")],
            name: "Original phase",
            lifecycle: .upcoming,
            stateEvidence: []
        )
        let original = RepositoryPlanProjection(
            format: "release-radar.repository-plan",
            schemaVersion: 1,
            repositoryID: "9141d1ea-3342-4462-9e06-6934d816c03f",
            projectionID: "00000000-0000-0000-0000-000000000001",
            projectionRevision: 1,
            documents: [],
            phases: [phase],
            tickets: [],
            phaseDependencies: [],
            ticketDependencies: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let subject = RepositoryPlanReconstructionSubject(
            kind: .phase,
            parentSourceID: nil,
            sourceID: phase.sourceID
        )
        let correction = RepositoryPlanReconstructionCorrection(
            subject: subject,
            field: "name",
            sourceValue: try encoder.encode(phase.name),
            chosenValue: try encoder.encode("Reviewed phase")
        )

        let reviewed = try RepositoryPlanReconstructionCorrections.apply(
            [correction],
            to: original
        )

        XCTAssertEqual(reviewed.phases.map(\.name), ["Reviewed phase"])
        XCTAssertEqual(reviewed.phases[0].sourceID, phase.sourceID)
        XCTAssertEqual(reviewed.phases[0].sourceRefs, phase.sourceRefs)
        XCTAssertEqual(reviewed.repositoryID, original.repositoryID)
        XCTAssertEqual(reviewed.projectionID, original.projectionID)

        let mismatched = RepositoryPlanReconstructionCorrection(
            subject: subject,
            field: "name",
            sourceValue: try encoder.encode("Different source value"),
            chosenValue: try encoder.encode("Reviewed phase")
        )
        XCTAssertThrowsError(
            try RepositoryPlanReconstructionCorrections.apply([mismatched], to: original)
        ) { error in
            guard case RepositoryPlanReconstructionError.invalidPayload = error else {
                return XCTFail("Expected the public correction API to reject a source mismatch, got \(error)")
            }
        }
    }
}

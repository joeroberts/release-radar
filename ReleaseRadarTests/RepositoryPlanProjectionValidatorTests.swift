import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RepositoryPlanProjectionValidatorTests: XCTestCase {
    func testValidEmptyProjectionBindsExactCapturedProjectionAndManifest() throws {
        let bytes = projection()
        let result = try RepositoryPlanProjectionValidator.validate(bytes, against: manifest(for: bytes))

        XCTAssertEqual(result.bytes, bytes)
        XCTAssertEqual(result.contentSHA256, sha256(bytes))
        XCTAssertEqual(result.projection.repositoryID, "repository-101")
        XCTAssertEqual(result.projection.projectionID, "00000000-0000-4000-8000-000000000101")
        XCTAssertEqual(result.projection.projectionRevision, 1)
        XCTAssertTrue(result.projection.phases.isEmpty)
        XCTAssertTrue(result.projection.tickets.isEmpty)
    }

    func testRejectsBomMalformedUnknownAndMissingRequiredEnvelopeFields() throws {
        let valid = projectionObject()
        let cases: [(String, Data, RepositoryPlanProjectionError.Code)] = [
            ("BOM", Data([0xEF, 0xBB, 0xBF]) + projection(), .invalidUTF8),
            ("malformed", Data("{\"format\":".utf8), .malformedJSON),
            ("unknown", encode(valid.merging(["unexpected": true]) { _, new in new }), .unknownKey),
            ("missing", encode(valid.filter { $0.key != "projectionRevision" }), .missingRequiredField),
        ]

        for (name, bytes, code) in cases {
            assertRejected(bytes, manifest: manifest(for: bytes), code: code, name: name)
        }
    }

    func testRejectsWrongRepositoryOrCapturedArtifactDigest() throws {
        var wrongRepository = projectionObject()
        wrongRepository["repositoryID"] = "repository-other"
        let repositoryBytes = encode(wrongRepository)
        assertRejected(repositoryBytes, manifest: manifest(for: repositoryBytes), code: .sourceMismatch)

        let bytes = projection()
        var source = capturedProjection(bytes: bytes)
        source = .init(
            artifactID: source.artifactID,
            path: source.path,
            contentSHA256: String(repeating: "0", count: 64),
            lifecycle: source.lifecycle,
            authority: source.authority,
            bytes: source.bytes
        )
        let invalidManifest = manifest(for: bytes, sources: [source])
        assertRejected(bytes, manifest: invalidManifest, code: .sourceMismatch)
    }

    func testRejectsDuplicateSourceIdentitiesAndInvalidDocumentReference() throws {
        var duplicate = projectionObject()
        duplicate["phases"] = [phase(sourceID: "phase-1"), phase(sourceID: "phase-1")]
        let duplicateBytes = encode(duplicate)
        assertRejected(duplicateBytes, manifest: manifest(for: duplicateBytes), code: .duplicateIdentity)

        var reference = projectionObject()
        reference["phases"] = [phase(sourceID: "phase-1", references: [[
            "kind": "document", "documentID": "missing-artifact", "locator": "#phase-1",
        ]])]
        let referenceBytes = encode(reference)
        assertRejected(referenceBytes, manifest: manifest(for: referenceBytes), code: .invalidReference)
    }

    func testRejectsUnknownAuthorityClassInsteadOfTreatingItAsCurrentWork() throws {
        var invalidAuthority = projectionObject()
        invalidAuthority["phases"] = [[
            "sourceID": "phase-1",
            "authorityClass": "accepted_by_agent",
            "sourceRefs": [],
            "name": "Untrusted classification",
            "lifecycle": "unassessed",
            "stateEvidence": [],
        ]]
        let bytes = encode(invalidAuthority)
        assertRejected(bytes, manifest: manifest(for: bytes), code: .invalidValue)
    }

    func testRejectsDeeplyNestedJSONBeforeRecursingWithoutBound() throws {
        let depth = 300
        let bytes = Data((String(repeating: "[", count: depth) + String(repeating: "]", count: depth)).utf8)

        assertRejected(bytes, manifest: manifest(for: bytes), code: .limitExceeded)
    }

    func testRejectsDuplicateDependencyPairsWithDistinctEdgeIdentities() throws {
        var phaseEdges = projectionObject()
        phaseEdges["phases"] = [phase(sourceID: "phase-1"), phase(sourceID: "phase-2")]
        phaseEdges["phaseDependencies"] = [
            dependency(sourceID: "edge-1", subject: "phase-1", dependsOn: "phase-2"),
            dependency(sourceID: "edge-2", subject: "phase-1", dependsOn: "phase-2"),
        ]
        let phaseBytes = encode(phaseEdges)
        assertRejected(phaseBytes, manifest: manifest(for: phaseBytes), code: .duplicateIdentity)

        var ticketEdges = projectionObject()
        ticketEdges["tickets"] = [ticket(sourceID: "ticket-1"), ticket(sourceID: "ticket-2")]
        ticketEdges["ticketDependencies"] = [
            dependency(sourceID: "edge-1", subject: "ticket-1", dependsOn: "ticket-2"),
            dependency(sourceID: "edge-2", subject: "ticket-1", dependsOn: "ticket-2"),
        ]
        let ticketBytes = encode(ticketEdges)
        assertRejected(ticketBytes, manifest: manifest(for: ticketBytes), code: .duplicateIdentity)
    }

    func testRejectsTaskLabelsOutsideTheExistingExactLabelContract() throws {
        var oversized = projectionObject()
        oversized["phases"] = [phase(sourceID: "phase-1")]
        oversized["tickets"] = [ticket(
            sourceID: "ticket-1",
            phaseSourceID: "phase-1",
            lane: "backlog",
            tasks: [task(sourceID: "task-1", label: String(repeating: "x", count: 257))]
        )]
        let oversizedBytes = encode(oversized)
        assertRejected(oversizedBytes, manifest: manifest(for: oversizedBytes), code: .invalidValue)

        var activeDuplicate = projectionObject()
        activeDuplicate["phases"] = [phase(sourceID: "phase-1")]
        activeDuplicate["tickets"] = [ticket(
            sourceID: "ticket-1",
            phaseSourceID: "phase-1",
            lane: "backlog",
            tasks: [task(sourceID: "task-1", label: "Task 1"), task(sourceID: "task-2", label: "Task 1")]
        )]
        let activeBytes = encode(activeDuplicate)
        assertRejected(activeBytes, manifest: manifest(for: activeBytes), code: .duplicateIdentity)

        var retainedDuplicate = projectionObject()
        retainedDuplicate["phases"] = [phase(sourceID: "phase-1")]
        retainedDuplicate["tickets"] = [ticket(
            sourceID: "ticket-1",
            phaseSourceID: "phase-1",
            lane: "backlog",
            tasks: [
                task(sourceID: "task-active", label: "Task 1"),
                task(sourceID: "task-superseded", label: "Task 1", lifecycle: "superseded", evidence: projectionRootReference()),
            ]
        )]
        let retainedBytes = encode(retainedDuplicate)
        assertRejected(retainedBytes, manifest: manifest(for: retainedBytes), code: .duplicateIdentity)
    }

    func testRejectsNonUUIDProjectionIdentity() throws {
        var invalid = projectionObject()
        invalid["projectionID"] = "projection-101"
        let bytes = encode(invalid)
        assertRejected(bytes, manifest: manifest(for: bytes), code: .invalidValue)
    }

    func testRejectsDependencyCyclesAndImpossiblePlacementState() throws {
        var cycle = projectionObject()
        cycle["phases"] = [phase(sourceID: "phase-1"), phase(sourceID: "phase-2")]
        cycle["phaseDependencies"] = [
            dependency(sourceID: "edge-1", subject: "phase-1", dependsOn: "phase-2"),
            dependency(sourceID: "edge-2", subject: "phase-2", dependsOn: "phase-1"),
        ]
        let cycleBytes = encode(cycle)
        assertRejected(cycleBytes, manifest: manifest(for: cycleBytes), code: .dependencyCycle)

        var impossible = projectionObject()
        impossible["tickets"] = [[
            "sourceID": "ticket-1",
            "authorityClass": "current_approved",
            "sourceRefs": [],
            "outcome": "Impossible unplaced completion",
            "phaseSourceID": NSNull(),
            "lane": NSNull(),
            "taskPlan": [
                "sourceRevision": 1,
                "tasks": [[
                    "sourceID": "task-1", "authorityClass": "current_approved", "sourceRefs": [],
                    "label": "Task 1", "title": "Completed while unplaced",
                    "sortOrder": 0, "completion": "completed", "lifecycle": "active", "stateEvidence": [],
                ]],
            ],
            "stateEvidence": [],
            "evidenceRefs": [],
        ]]
        let impossibleBytes = encode(impossible)
        assertRejected(impossibleBytes, manifest: manifest(for: impossibleBytes), code: .invalidPlacement)
    }

    private func projection() -> Data { encode(projectionObject()) }

    private func projectionObject() -> [String: Any] {
        [
            "format": "release-radar.repository-plan",
            "schemaVersion": 1,
            "repositoryID": "repository-101",
            "projectionID": "00000000-0000-4000-8000-000000000101",
            "projectionRevision": 1,
            "documents": [],
            "phases": [],
            "tickets": [],
            "phaseDependencies": [],
            "ticketDependencies": [],
        ]
    }

    private func phase(sourceID: String, references: [[String: Any]] = []) -> [String: Any] {
        [
            "sourceID": sourceID,
            "authorityClass": "current_approved",
            "sourceRefs": references,
            "name": "Phase \(sourceID)",
            "lifecycle": "unassessed",
            "stateEvidence": [],
        ]
    }

    private func dependency(sourceID: String, subject: String, dependsOn: String) -> [String: Any] {
        [
            "sourceID": sourceID,
            "subjectSourceID": subject,
            "dependsOnSourceID": dependsOn,
            "sourceRefs": [],
        ]
    }

    private func ticket(
        sourceID: String,
        phaseSourceID: String? = nil,
        lane: String? = nil,
        tasks: [[String: Any]]? = nil
    ) -> [String: Any] {
        [
            "sourceID": sourceID,
            "authorityClass": "current_approved",
            "sourceRefs": [],
            "outcome": "Outcome \(sourceID)",
            "phaseSourceID": phaseSourceID.map { $0 as Any } ?? NSNull(),
            "lane": lane.map { $0 as Any } ?? NSNull(),
            "taskPlan": tasks.map { ["sourceRevision": 1, "tasks": $0] } ?? NSNull(),
            "stateEvidence": [],
            "evidenceRefs": [],
        ]
    }

    private func task(
        sourceID: String,
        label: String,
        lifecycle: String = "active",
        evidence: [[String: Any]] = []
    ) -> [String: Any] {
        [
            "sourceID": sourceID,
            "authorityClass": "current_approved",
            "sourceRefs": [],
            "label": label,
            "title": "Title \(sourceID)",
            "sortOrder": 0,
            "completion": "pending",
            "lifecycle": lifecycle,
            "stateEvidence": evidence,
        ]
    }

    private func projectionRootReference() -> [[String: Any]] {
        [["kind": "projection", "pointer": ""]]
    }

    private func capturedProjection(bytes: Data) -> RepositoryPlanCapturedSource {
        .init(
            artifactID: "reconstruction-projection",
            path: "docs/delivery/reconstruction-plan.json",
            contentSHA256: sha256(bytes),
            lifecycle: .active,
            authority: .controlling,
            bytes: bytes
        )
    }

    private func manifest(
        for bytes: Data,
        sources: [RepositoryPlanCapturedSource]? = nil
    ) -> RepositoryPlanSourceManifest {
        .init(
            projectID: .init(rawValue: "project-101"),
            rootID: "root-101",
            rootPath: "/fixture/repository-101",
            registration: .init(
                projectID: .init(rawValue: "project-101"),
                registrationID: "registration-101",
                requestGeneration: 1
            ),
            repositoryID: "repository-101",
            acceptedCatalogVersion: 1,
            acceptedCatalogDigest: String(repeating: "a", count: 64),
            sources: sources ?? [capturedProjection(bytes: bytes)]
        )
    }

    private func assertRejected(
        _ bytes: Data,
        manifest: RepositoryPlanSourceManifest,
        code: RepositoryPlanProjectionError.Code,
        name: String = #function
    ) {
        XCTAssertThrowsError(try RepositoryPlanProjectionValidator.validate(bytes, against: manifest), name) { error in
            XCTAssertEqual((error as? RepositoryPlanProjectionError)?.code, code, name)
        }
    }

    private func encode(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

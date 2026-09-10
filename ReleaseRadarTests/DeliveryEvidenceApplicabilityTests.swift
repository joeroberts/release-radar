import XCTest
@testable import ReleaseRadarCore

final class DeliveryEvidenceApplicabilityTests: XCTestCase {
    func testExactRepositoryRevisionAndScopeAreApplicable() {
        let target = target(expectations: [.init(category: .check, scope: "ReleaseRadarTests")])
        let observation = observation(
            fact: .check(.init(scope: "ReleaseRadarTests")),
            outcome: .passed
        )

        XCTAssertEqual(
            DeliveryEvidenceApplicabilityEvaluator.evaluate(observation, against: target),
            .init(state: .applicable, reasons: [])
        )
        XCTAssertEqual(
            DeliveryEvidenceApplicabilityEvaluator.assessExpectations(
                target: target,
                observations: [observation]
            ),
            [.init(
                expectation: .init(category: .check, scope: "ReleaseRadarTests"),
                status: .satisfied,
                observationID: "observation"
            )]
        )
    }

    func testWrongRepositoryOlderRevisionAndDirtySnapshotDoNotTransfer() {
        let target = target(
            revision: .init(
                commitSHA: String(repeating: "a", count: 40),
                checkoutState: .dirty,
                dirtySnapshotID: "snapshot-new"
            )
        )
        let cases: [(DeliveryEvidenceObservation, [DeliveryEvidenceApplicabilityReason])] = [
            (
                observation(repositoryID: "22222222-2222-2222-2222-222222222222"),
                [.repositoryMismatch]
            ),
            (
                observation(revision: .init(
                    commitSHA: String(repeating: "b", count: 40),
                    checkoutState: .dirty,
                    dirtySnapshotID: "snapshot-new"
                )),
                [.revisionMismatch]
            ),
            (
                observation(revision: .init(
                    commitSHA: String(repeating: "a", count: 40),
                    checkoutState: .dirty,
                    dirtySnapshotID: "snapshot-old"
                )),
                [.dirtySnapshotMismatch]
            ),
        ]

        for (candidate, reasons) in cases {
            XCTAssertEqual(
                DeliveryEvidenceApplicabilityEvaluator.evaluate(candidate, against: target),
                .init(state: .stale, reasons: reasons)
            )
        }
    }

    func testFailedAndSkippedChecksRemainDistinctFromApplicability() {
        let target = target(expectations: [
            .init(category: .check, scope: "unit"),
            .init(category: .check, scope: "native"),
        ])
        let failed = observation(id: "failed", fact: .check(.init(scope: "unit")), outcome: .failed)
        let skipped = observation(id: "skipped", fact: .check(.init(scope: "native")), outcome: .skipped)

        XCTAssertEqual(
            DeliveryEvidenceApplicabilityEvaluator.evaluate(failed, against: target).state,
            .applicable
        )
        XCTAssertEqual(
            DeliveryEvidenceApplicabilityEvaluator.assessExpectations(
                target: target,
                observations: [failed, skipped]
            ).map(\.status),
            [.failed, .skipped]
        )
    }

    func testUnknownInstallationAndUnspecifiedExpectationsRemainUnknownAndUnspecified() {
        let target = target(expectations: [.init(category: .check, scope: "unit")])
        let installation = DeliveryEvidenceObservation(
            id: "installation",
            targetVersion: 1,
            fact: .installation(.init(
                repositoryID: nil,
                revision: nil,
                installationID: nil,
                buildID: nil,
                context: "/Applications/ReleaseRadar.app"
            )),
            source: .init(kind: .recordedClaim, label: "release notes"),
            sourceAvailability: .available,
            outcome: .unknown,
            observedAt: "2026-09-10T17:00:00Z",
            recordedAt: "2026-09-10T17:01:00Z"
        )

        XCTAssertEqual(
            DeliveryEvidenceApplicabilityEvaluator.evaluate(installation, against: target),
            .init(
                state: .unknown,
                reasons: [.repositoryUnknown, .revisionUnknown, .installationIdentityUnknown]
            )
        )
        XCTAssertEqual(
            DeliveryEvidenceApplicabilityEvaluator.assessExpectations(
                target: target,
                observations: [installation]
            ).map(\.expectation.category),
            [.check]
        )
        XCTAssertEqual(
            DeliveryEvidenceApplicabilityEvaluator.status(
                for: .build,
                scope: nil,
                target: target,
                observations: [installation]
            ),
            .notSpecified
        )
    }

    private func target(
        revision: DeliveryEvidenceRevision = .init(
            commitSHA: String(repeating: "a", count: 40),
            checkoutState: .clean,
            dirtySnapshotID: nil
        ),
        expectations: [DeliveryEvidenceExpectation] = []
    ) -> DeliveryEvidenceTargetVersion {
        .init(
            version: 1,
            repositoryID: "11111111-1111-1111-1111-111111111111",
            rootID: "root",
            revision: revision,
            expectations: expectations,
            registrationID: "registration",
            requestGeneration: 1,
            recordedAt: "2026-09-10T17:00:00Z"
        )
    }

    private func observation(
        id: String = "observation",
        repositoryID: String = "11111111-1111-1111-1111-111111111111",
        revision: DeliveryEvidenceRevision = .init(
            commitSHA: String(repeating: "a", count: 40),
            checkoutState: .clean,
            dirtySnapshotID: nil
        ),
        fact: DeliveryEvidenceFact? = nil,
        outcome: DeliveryEvidenceOutcome = .observed
    ) -> DeliveryEvidenceObservation {
        .init(
            id: id,
            targetVersion: 1,
            fact: fact ?? .commit(.init(repositoryID: repositoryID, revision: revision)),
            source: .init(kind: .recordedClaim, label: "writer result"),
            sourceAvailability: .available,
            outcome: outcome,
            observedAt: "2026-09-10T17:00:00Z",
            recordedAt: "2026-09-10T17:01:00Z"
        )
    }
}

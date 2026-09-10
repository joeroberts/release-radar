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

    func testSupersededObservationsCannotSatisfyEitherAssessmentEntryPoint() {
        let target = target(expectations: [
            .init(category: .check, scope: "unit"),
            .init(category: .build, scope: "unit"),
        ])
        let repositoryID = target.repositoryID
        let oldRevision = DeliveryEvidenceRevision(
            commitSHA: String(repeating: "b", count: 40), checkoutState: .clean, dirtySnapshotID: nil
        )
        let history = [
            observation(id: "check-pass", fact: .check(.init(scope: "unit")), outcome: .passed),
            observation(id: "build-pass", fact: .build(.init(
                repositoryID: repositoryID, revision: target.revision, buildID: "build", scope: "unit"
            )), outcome: .passed),
            observation(id: "check-correction", fact: .check(.init(scope: "integration")),
                        outcome: .failed, supersedes: "check-pass"),
            observation(id: "build-correction", fact: .build(.init(
                repositoryID: repositoryID, revision: oldRevision, buildID: "build", scope: "unit"
            )), outcome: .passed, supersedes: "build-pass"),
        ]
        let resolved = history.map {
            DeliveryEvidenceResolvedObservation(
                observation: $0, applicability: DeliveryEvidenceApplicabilityEvaluator.evaluate($0, against: target),
                currentSourceAvailability: .available, currentDocumentDigest: nil
            )
        }
        XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.assessExpectations(
            target: target, observations: history
        ).map(\.status), [.missing, .missing])
        XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.assessExpectations(
            target: target, resolvedObservations: resolved
        ).map(\.status), [.missing, .missing])
        XCTAssertEqual(resolved.map(\.id), history.map(\.id))
    }

    func testUnknownCheckoutIdentityNeverProvesBuildOrTargetBoundCheckApplicability() {
        let unknown = DeliveryEvidenceRevision(
            commitSHA: String(repeating: "a", count: 40), checkoutState: .unknown, dirtySnapshotID: nil
        )
        let clean = target().revision
        for (targetRevision, factRevision) in [(unknown, unknown), (unknown, clean), (clean, unknown)] {
            let target = target(revision: targetRevision, expectations: [.init(category: .build, scope: nil)])
            let build = observation(fact: .build(.init(
                repositoryID: target.repositoryID, revision: factRevision, buildID: "build", scope: nil
            )), outcome: .passed)
            XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.evaluate(build, against: target).state, .unknown)
            XCTAssertNotEqual(DeliveryEvidenceApplicabilityEvaluator.assessExpectations(
                target: target, observations: [build]
            ).first?.status, .satisfied)
        }
        let unknownTarget = target(revision: unknown)
        XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.evaluate(
            observation(fact: .check(.init(scope: "unit")), outcome: .passed), against: unknownTarget
        ).state, .unknown)
        let missingSnapshot = DeliveryEvidenceRevision(
            commitSHA: clean.commitSHA, checkoutState: .dirty, dirtySnapshotID: nil
        )
        XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.evaluate(
            observation(revision: missingSnapshot), against: target(revision: missingSnapshot)
        ).state, .unknown)
        XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.evaluate(
            observation(revision: .init(
                commitSHA: String(repeating: "b", count: 40), checkoutState: .unknown, dirtySnapshotID: nil
            )), against: unknownTarget
        ).state, .stale)
    }

    func testPullRequestApplicabilityRequiresExplicitHeadOrMergedRevision() {
        let head = String(repeating: "a", count: 40)
        let merge = String(repeating: "b", count: 40)
        let unrelated = String(repeating: "c", count: 40)
        for (sha, state, mergeSHA, expected) in [
            (head, DeliveryEvidencePullRequestState.open, nil, DeliveryEvidenceApplicabilityState.applicable),
            (head, .merged, Optional(merge), .applicable),
            (merge, .merged, Optional(merge), .applicable),
            (unrelated, .merged, Optional(merge), .stale),
            (merge, .open, Optional(merge), .stale),
        ] {
            let revision = DeliveryEvidenceRevision(commitSHA: sha, checkoutState: .clean, dirtySnapshotID: nil)
            let target = target(revision: revision)
            let candidate = observation(fact: .pullRequest(.init(
                repositoryID: target.repositoryID, revision: revision, number: 42,
                headSHA: head, mergeSHA: mergeSHA, state: state
            )))
            XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.evaluate(candidate, against: target).state, expected)
        }
        let headObservation = observation(fact: .pullRequest(.init(
            repositoryID: target().repositoryID, revision: target().revision,
            number: 42, headSHA: head, mergeSHA: merge, state: .merged
        )))
        XCTAssertEqual(DeliveryEvidenceApplicabilityEvaluator.evaluate(
            headObservation, against: target(revision: .init(
                commitSHA: merge, checkoutState: .clean, dirtySnapshotID: nil
            ))
        ).state, .stale)
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
        outcome: DeliveryEvidenceOutcome = .observed,
        supersedes: String? = nil
    ) -> DeliveryEvidenceObservation {
        .init(
            id: id,
            targetVersion: 1,
            fact: fact ?? .commit(.init(repositoryID: repositoryID, revision: revision)),
            source: .init(kind: .recordedClaim, label: "writer result"),
            sourceAvailability: .available,
            outcome: outcome,
            observedAt: "2026-09-10T17:00:00Z",
            recordedAt: "2026-09-10T17:01:00Z",
            supersedesObservationID: supersedes
        )
    }
}

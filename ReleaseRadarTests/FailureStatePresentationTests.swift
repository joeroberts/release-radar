import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class FailureStatePresentationTests: XCTestCase {
    func testOnboardingStatesUseInitializationAndTrackingStateTerminology() throws {
        let noStructure = FailureStatePresentation.noDeliveryStructure
        XCTAssertEqual(noStructure.title, "Project tracking not initialized")
        XCTAssertTrue(noStructure.detail.contains("Initialize Project Tracking"))
        XCTAssertTrue(noStructure.detail.localizedCaseInsensitiveContains("tracking state"))

        let activePresentations = [
            FailureStatePresentation.firstPhaseRequired,
            FailureStatePresentation.trackingStateRequired,
            try XCTUnwrap(FailureStatePresentation(onboardingError: .noFirstPhase)),
            try XCTUnwrap(FailureStatePresentation(onboardingError: .projectNotPrepared)),
        ]
        for presentation in activePresentations {
            XCTAssertEqual(presentation.title, "Tracking state required")
            XCTAssertTrue(presentation.detail.localizedCaseInsensitiveContains("tracking state"))
            XCTAssertFalse(presentation.title.localizedCaseInsensitiveContains("first phase"))
            XCTAssertFalse(presentation.detail.localizedCaseInsensitiveContains("first phase"))
            XCTAssertFalse(presentation.detail.localizedCaseInsensitiveContains("ask an agent"))
        }

        let inaccessible = FailureStatePresentation(onboardingError: .invalidFolder)
        XCTAssertEqual(inaccessible?.title, "Project folder unavailable")
        XCTAssertTrue(inaccessible?.detail.contains("moved") == true)
    }

    func testDesktopObservationUnavailableAndCachedStateNeverClaimLiveObservation() throws {
        let unavailable = try XCTUnwrap(FailureStatePresentation(freshness: .init(
            state: .unavailable,
            lastObservedAt: nil,
            reason: "No supported attachment"
        )))
        XCTAssertEqual(unavailable.title, "Codex desktop observation unavailable")
        XCTAssertFalse(unavailable.title.localizedCaseInsensitiveContains("codex unavailable"))
        XCTAssertEqual(unavailable.detail, "No supported attachment")

        let lastSeen = Date(timeIntervalSince1970: 1_700_000_000)
        let stale = try XCTUnwrap(FailureStatePresentation(freshness: .init(
            state: .stale,
            lastObservedAt: lastSeen,
            reason: "Codex is offline"
        )))
        XCTAssertEqual(stale.title, "Cached Codex state")
        XCTAssertTrue(stale.detail.hasPrefix("Last seen "))
        XCTAssertNil(FailureStatePresentation(freshness: .init(
            state: .live,
            lastObservedAt: lastSeen,
            reason: nil
        )))
    }

    func testUnavailableEvidenceAndImportAmbiguityPreserveHistoryAndOwnerDecision() throws {
        let evidence = try XCTUnwrap(FailureStatePresentation(
            evidenceLabel: "Architecture decision",
            isAvailable: false
        ))
        XCTAssertEqual(evidence.title, "Evidence unavailable")
        XCTAssertTrue(evidence.detail.contains("remains in history"))
        XCTAssertNil(FailureStatePresentation(evidenceLabel: "Test output", isAvailable: true))

        let review = ReviewItemProjection(
            id: .init(rawValue: "import-review"),
            projectID: .init(rawValue: "project-1"),
            ticketID: nil,
            kind: .uncertainImport,
            summary: "Two roadmap items may describe the same work",
            status: .open
        )
        let importState = try XCTUnwrap(FailureStatePresentation(reviewItem: review))
        XCTAssertEqual(importState.title, "Import needs review")
        XCTAssertEqual(importState.detail, review.summary)
    }

    func testPushoverFailedAndUnknownRemainNonblockingAndDoNotImplyRetry() throws {
        let failed = try XCTUnwrap(FailureStatePresentation(
            notificationState: .failed,
            statusText: "Delivery failed · Provider rejected"
        ))
        XCTAssertEqual(failed.title, "Pushover delivery failed")
        XCTAssertEqual(failed.detail, "Delivery failed · Provider rejected")

        let unknown = try XCTUnwrap(FailureStatePresentation(
            notificationState: .unknown,
            statusText: nil
        ))
        XCTAssertEqual(unknown.title, "Pushover delivery unknown")
        XCTAssertTrue(unknown.detail.contains("not retried automatically"))
        XCTAssertNil(FailureStatePresentation(notificationState: .sent, statusText: "Delivered"))
    }

    func testDeliveryGoalErrorsGiveExactRevisionAndActionableRecovery() throws {
        let conflict = try XCTUnwrap(FailureStatePresentation(agentError: .planRevisionConflict(expected: 2, current: 3)))
        XCTAssertTrue(conflict.detail.contains("revision is 3"))
        let incomplete = try XCTUnwrap(FailureStatePresentation(agentError: .phasePlanIncomplete(.init(
            unassignedTicketIDs: [.init(rawValue: "T-1")], incompleteGoalIDs: [.init(rawValue: "G-1")], conflictingTicketIDs: [.init(rawValue: "T-2")]))))
        for id in ["T-1", "G-1", "T-2"] { XCTAssertTrue(incomplete.detail.contains(id)) }
        let owner = try XCTUnwrap(FailureStatePresentation(agentError: .ownerAcceptanceRequired))
        XCTAssertTrue(owner.detail.contains("cannot grant"))
        let evidence = try XCTUnwrap(FailureStatePresentation(agentError: .goalAcceptanceEvidenceUnavailable([.init(rawValue: "T-3")])))
        XCTAssertTrue(evidence.detail.contains("T-3")); XCTAssertTrue(evidence.detail.contains("Restore"))
    }

    func testTypedAgentValidationAndUnknownOutcomeNeverClaimPartialState() throws {
        let validation = try XCTUnwrap(FailureStatePresentation(
            agentError: .invalidReference("Ticket MISSING was not found")
        ))
        XCTAssertEqual(validation.title, "Action rejected")
        XCTAssertTrue(validation.detail.contains("No delivery state changed"))

        let unknown = try XCTUnwrap(FailureStatePresentation(agentError: .outcomeUnknown))
        XCTAssertEqual(unknown.title, "Action outcome unknown")
        XCTAssertTrue(unknown.detail.contains("Do not assume success"))
        XCTAssertTrue(unknown.detail.contains("not retried automatically"))
    }
}

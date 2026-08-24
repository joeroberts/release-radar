import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class FailureStatePresentationTests: XCTestCase {
    func testOnboardingStatesKeepNoStructureFirstPhaseAndFolderFailuresDistinct() {
        XCTAssertEqual(FailureStatePresentation.noDeliveryStructure.title, "No delivery structure yet")
        XCTAssertTrue(FailureStatePresentation.noDeliveryStructure.detail.contains("folder-backed project"))

        let firstPhase = FailureStatePresentation(onboardingError: .noFirstPhase)
        XCTAssertEqual(firstPhase?.title, "First phase required")
        XCTAssertTrue(firstPhase?.detail.contains("agent") == true)

        let inaccessible = FailureStatePresentation(onboardingError: .invalidFolder)
        XCTAssertEqual(inaccessible?.title, "Project folder unavailable")
        XCTAssertTrue(inaccessible?.detail.contains("moved") == true)
    }

    func testCodexUnavailableAndCachedStateNeverClaimLiveObservation() throws {
        let unavailable = try XCTUnwrap(FailureStatePresentation(freshness: .init(
            state: .unavailable,
            lastObservedAt: nil,
            reason: "No supported attachment"
        )))
        XCTAssertEqual(unavailable.title, "Codex unavailable")
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

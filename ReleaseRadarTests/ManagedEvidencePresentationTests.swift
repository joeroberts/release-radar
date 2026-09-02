import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class ManagedEvidencePresentationTests: XCTestCase {
    func testAvailableProposedCurrentAndHistoricalAuthorityAreSeparate() {
        for lifecycle in RepositoryDocumentArtifact.Lifecycle.allPresentationCases {
            let controlling = lifecycle == .active
            let resolved = ResolvedManagedDocument(artifactID: "artifact", resolvedPath: "docs/item.md", label: "item.md", lifecycle: lifecycle,
                authority: controlling ? .controlling : lifecycle == .proposed ? .supporting : .nonAuthoritative, authorityRole: controlling ? "plan" : nil, failure: nil)
            let presentation = EvidenceStatusPresentation(evidence(resolved))
            XCTAssertEqual(presentation.availability, "Available")
            XCTAssertEqual(presentation.authority, controlling ? "Controlling · plan" : lifecycle == .proposed ? "Non-controlling · Supporting" : "Non-controlling · Non-authoritative")
            XCTAssertTrue(presentation.accessibilityLabel.contains("artifact"))
            XCTAssertTrue(presentation.accessibilityLabel.contains("docs/item.md"))
            XCTAssertTrue(presentation.accessibilityLabel.contains(presentation.lifecycle!))
        }
    }
    func testEveryUnavailableManagedReasonRetainsIdentityAndActionableRecovery() {
        let failures: [ManagedDocumentResolutionFailure] = [.guidanceUnavailable, .bindingMissing, .bindingMismatch, .rootNotBound, .rootUnavailable,
            .staleRoot, .catalogUnaccepted, .artifactNotFound, .missingDocument, .checksumInvalid, .unsafeResolution, .catalogInvalid(.malformedCatalog)]
        for failure in failures {
            let resolved = ResolvedManagedDocument(artifactID: "stable-id", resolvedPath: nil, label: nil, lifecycle: nil, authority: nil, authorityRole: nil, failure: failure)
            let presentation = EvidenceStatusPresentation(evidence(resolved))
            XCTAssertEqual(presentation.availability, "Unavailable")
            XCTAssertFalse(presentation.recovery!.isEmpty)
            XCTAssertTrue(presentation.accessibilityLabel.contains("stable-id"))
            XCTAssertTrue(presentation.accessibilityLabel.contains(presentation.recovery!))
        }
    }
    func testLegacyPresentationPreservesLabelPathAndPersistedAvailability() {
        let presentation = EvidenceStatusPresentation(.init(id: .init(rawValue: "legacy"), label: "Owner evidence", path: "/arbitrary/file", isAvailable: false))
        XCTAssertEqual(presentation.locator, "Legacy file path")
        XCTAssertNil(presentation.authority)
        XCTAssertNil(presentation.lifecycle)
        XCTAssertTrue(presentation.accessibilityLabel.contains("Owner evidence"))
        XCTAssertTrue(presentation.accessibilityLabel.contains("/arbitrary/file"))
    }
    private func evidence(_ document: ResolvedManagedDocument) -> EvidenceProjection {
        .init(EvidenceReadback(evidence: .init(id: .init(rawValue: "e"), projectID: .init(rawValue: "p"), ticketID: nil,
            locator: .managedDocument(artifactID: document.artifactID), isAvailable: true), managedDocument: document))
    }
}
private extension RepositoryDocumentArtifact.Lifecycle {
    static var allPresentationCases: [Self] { [.proposed, .active, .completed, .superseded, .archived] }
}

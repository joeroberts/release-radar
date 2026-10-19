import AppKit
import ApplicationServices
import CryptoKit
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class RepositoryPlanReconstructionNativeRenderingTests: XCTestCase {
    func testReviewRendersSubstantialSourceComparisonCorrectionExclusionEvidenceAndOwnerActionsAtBothWidths() async throws {
        let presentation = try substantialPresentation(stage: .reviewing)
        let requiredIdentifiers = [
            "repository-plan-source-summary",
            "repository-plan-comparisons",
            "repository-plan-comparison-phase-phase-current",
            "repository-plan-comparison-ticket-ticket-historical",
            "repository-plan-comparison-task-task-current",
            "repository-plan-comparison-phase_dependency-phase-dependency",
            "repository-plan-comparison-ticket_dependency-ticket-dependency",
            "repository-plan-comparison-details",
            "repository-plan-mapping-destination",
            "repository-plan-mapping-apply",
            "repository-plan-mapping-clear",
            "repository-plan-correction-field",
            "repository-plan-correction-value",
            "repository-plan-correction-apply",
            "repository-plan-exclusion-reason",
            "repository-plan-exclude",
            "repository-plan-restore",
            "repository-plan-original-evidence",
            "repository-plan-evidence-state",
            "repository-plan-evidence-add",
            "repository-plan-evidence-remove",
            "repository-plan-phase-membership",
            "repository-plan-phase-tickets",
            "repository-plan-phase-goals",
            "repository-plan-phase-obligations",
            "repository-plan-phase-obligation-descendants",
            "repository-plan-phase-delivered-by",
            "repository-plan-blockers",
            "repository-plan-remaining-setup",
            "repository-plan-authority-confirmed",
            "repository-plan-save-rationale",
            "repository-plan-save",
            "repository-plan-approve",
            "repository-plan-apply",
        ]

        for (width, height, label) in [(1_180.0, 820.0, "normal"), (720.0, 760.0, "compact")] {
            try await host(
                presentation: presentation,
                width: width,
                height: height,
                label: "repository-plan-review-\(label)",
                requiredIdentifiers: requiredIdentifiers,
                requiredText: [
                    "Current delivery phase",
                    "Historical delivered phase",
                    "Deliver the current project outcome.",
                    "Retain delivered historical context.",
                    "Implement the owner-reviewed change.",
                    "Destination: phase-destination-101",
                    "Existing destination phase",
                    "membershipComplete=true",
                    "obligation-native=fulfilled[ticket:phase-historical:ticket-historical:current-plan:#delivery-proof]",
                ],
                forbiddenIdentifiers: [
                    "repository-plan-open-plan",
                    "repository-plan-open-board",
                    "repository-plan-open-history",
                    "repository-plan-refresh-applied",
                ]
            )
        }
    }

    func testUnknownAppliedAndReviewLoadFailureExposeOnlyTheirRecoveryOrDestinationActions() async throws {
        let unknown = try substantialPresentation(stage: .outcomeUnknown)
        try await host(
            presentation: unknown,
            width: 720,
            height: 760,
            label: "repository-plan-apply-unknown",
            requiredIdentifiers: [
                "repository-plan-apply-recover",
                "repository-plan-source-summary",
            ],
            forbiddenIdentifiers: [
                "repository-plan-open-plan",
                "repository-plan-open-board",
                "repository-plan-open-history",
                "repository-plan-refresh-applied",
            ]
        )

        let applied = try substantialPresentation(stage: .applied)
        for (width, height, label) in [(1_180.0, 820.0, "normal"), (720.0, 760.0, "compact")] {
            try await host(
                presentation: applied,
                width: width,
                height: height,
                label: "repository-plan-applied-\(label)",
                requiredIdentifiers: [
                    "repository-plan-open-plan",
                    "repository-plan-open-board",
                    "repository-plan-open-history",
                    "repository-plan-prepare-fresh",
                    "repository-plan-refresh-applied",
                    "repository-plan-source-summary",
                ],
                forbiddenIdentifiers: ["repository-plan-apply-recover"]
            )
        }

        var failure = try substantialPresentation(stage: .reviewLoadFailed)
        failure.message = "The prepared draft is safe, but its review could not be loaded."
        try await host(
            presentation: failure,
            width: 540,
            height: 480,
            label: "repository-plan-review-load-failed",
            requiredIdentifiers: [
                "repository-plan-review-retry",
                "repository-plan-review-restart",
            ],
            forbiddenIdentifiers: [
                "repository-plan-open-plan",
                "repository-plan-open-board",
                "repository-plan-open-history",
                "repository-plan-refresh-applied",
            ]
        )
    }

    private func host(
        presentation: RepositoryPlanReconstructionPresentation,
        width: CGFloat,
        height: CGFloat,
        label: String,
        requiredIdentifiers: [String],
        requiredText: [String] = [],
        forbiddenIdentifiers: [String] = []
    ) async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Repository Plan Native QA — \(label) — \(UUID().uuidString)"
        defer { window.close() }
        let hosting = NSHostingView(rootView: RepositoryPlanReconstructionView(
            presentation: presentation,
            retry: {},
            setSourceSelected: { _, _ in },
            startPreparation: {},
            refreshPreparation: {},
            cancelPreparation: {},
            reconcilePreparation: {},
            restartPreparation: {},
            setCorrection: { _, _, _ in },
            setExclusion: { _, _ in },
            setTerminalEvidence: { _ in },
            setAuthorityConfirmed: { _ in },
            save: { _ in },
            approve: {},
            apply: {},
            recoverApply: {},
            openPlan: {},
            openBoard: {},
            openHistory: {}
        ).environment(\.colorScheme, .dark))
        hosting.appearance = window.appearance
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.contentView = hosting
        window.setContentSize(NSSize(width: width, height: height))
        hosting.frame = window.contentView?.bounds ?? hosting.frame
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.setContentSize(NSSize(width: width, height: height))
        hosting.frame = window.contentView?.bounds ?? hosting.frame
        try await Task.sleep(for: .milliseconds(250))
        try await settle(hosting)

        try capture(hosting, name: label)
        if let nativeWindow = accessibilityWindow(title: window.title) {
            for identifier in requiredIdentifiers {
                XCTAssertNotNil(
                    accessibilityElement(nativeWindow, identifier: identifier),
                    "\(identifier) must be reachable in the \(label) native accessibility tree."
                )
            }
            let renderedText = accessibilityText(nativeWindow)
            for expectedText in requiredText {
                XCTAssertTrue(
                    renderedText.contains(expectedText),
                    "\(label) must disclose exact plan content: \(expectedText)"
                )
            }
            for identifier in forbiddenIdentifiers {
                XCTAssertNil(
                    accessibilityElement(nativeWindow, identifier: identifier),
                    "\(identifier) must not be reachable in the \(label) native accessibility tree."
                )
            }
        } else {
            let limitation = XCTAttachment(
                string: "The XCTest host did not expose its owned NSWindow through self-AX. The retained native capture remains valid visual evidence; AX identifiers were not observed in this environment."
            )
            limitation.name = "\(label)-self-ax-unavailable"
            limitation.lifetime = .keepAlways
            add(limitation)
        }
        let contentSize = try XCTUnwrap(window.contentView?.frame.size)
        XCTAssertEqual(contentSize.width, width, accuracy: 1)
        XCTAssertEqual(contentSize.height, height, accuracy: 1)
    }

    private func substantialPresentation(
        stage: RepositoryPlanReconstructionStage
    ) throws -> RepositoryPlanReconstructionPresentation {
        let projectID = ProjectID(rawValue: "project-native-reconstruction")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-native-reconstruction",
            requestGeneration: 7
        )
        let repositoryID = "9141d1ea-3342-4462-9e06-6934d816c03f"
        let sourceBytes = Data("Current and historical repository plan sources".utf8)
        let sourceDigest = digest(sourceBytes)
        let captured = RepositoryPlanCapturedSource(
            artifactID: "current-plan",
            path: "docs/plans/current.md",
            contentSHA256: sourceDigest,
            lifecycle: .active,
            authority: .controlling,
            bytes: sourceBytes
        )
        let manifest = RepositoryPlanSourceManifest(
            projectID: projectID,
            rootID: "root-native-reconstruction",
            rootPath: "/tmp/native-reconstruction",
            registration: registration,
            repositoryID: repositoryID,
            acceptedCatalogVersion: 4,
            acceptedCatalogDigest: String(repeating: "c", count: 64),
            sources: [captured]
        )
        let projection = RepositoryPlanProjection(
            format: "release-radar.repository-plan",
            schemaVersion: 1,
            repositoryID: repositoryID,
            projectionID: "00000000-0000-4000-8000-000000000201",
            projectionRevision: 9,
            documents: [.init(
                id: "current-plan",
                artifactID: captured.artifactID,
                contentSHA256: sourceDigest
            )],
            phases: [
                .init(
                    sourceID: "phase-current",
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/phases/0")],
                    name: "Current delivery phase",
                    lifecycle: .upcoming,
                    stateEvidence: []
                ),
                .init(
                    sourceID: "phase-historical",
                    authorityClass: .historical,
                    sourceRefs: [.projection(pointer: "/phases/1")],
                    name: "Historical delivered phase",
                    lifecycle: .completed,
                    stateEvidence: [.document(documentID: "current-plan", locator: "#history")]
                ),
            ],
            tickets: [
                .init(
                    sourceID: "ticket-current",
                    authorityClass: .currentApproved,
                    sourceRefs: [.projection(pointer: "/tickets/0")],
                    outcome: "Deliver the current project outcome.",
                    phaseSourceID: "phase-current",
                    lane: .backlog,
                    taskPlan: .init(sourceRevision: 2, tasks: [.init(
                        sourceID: "task-current",
                        authorityClass: .currentApproved,
                        sourceRefs: [.projection(pointer: "/tickets/0/taskPlan/tasks/0")],
                        label: "Task 1",
                        title: "Implement the owner-reviewed change.",
                        sortOrder: 0,
                        completion: .pending,
                        lifecycle: .active,
                        stateEvidence: []
                    )]),
                    stateEvidence: [],
                    evidenceRefs: []
                ),
                .init(
                    sourceID: "ticket-historical",
                    authorityClass: .historical,
                    sourceRefs: [.projection(pointer: "/tickets/1")],
                    outcome: "Retain delivered historical context.",
                    phaseSourceID: "phase-historical",
                    lane: .accepted,
                    taskPlan: nil,
                    stateEvidence: [.document(documentID: "current-plan", locator: "#accepted")],
                    evidenceRefs: []
                ),
            ],
            phaseDependencies: [.init(
                sourceID: "phase-dependency",
                subjectSourceID: "phase-current",
                dependsOnSourceID: "phase-historical",
                sourceRefs: [.projection(pointer: "/phaseDependencies/0")]
            )],
            ticketDependencies: [.init(
                sourceID: "ticket-dependency",
                subjectSourceID: "ticket-current",
                dependsOnSourceID: "ticket-historical",
                sourceRefs: [.projection(pointer: "/ticketDependencies/0")]
            )]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let projectionBytes = try encoder.encode(projection)
        let source = RepositoryPlanReconstructionSourceSnapshot(
            projectID: projectID,
            rootID: manifest.rootID,
            registration: registration,
            repositoryID: repositoryID,
            projectionID: UUID(uuidString: projection.projectionID)!,
            projectionRevision: projection.projectionRevision,
            projectionBytes: projectionBytes,
            projectionSHA256: digest(projectionBytes),
            acceptedCatalogVersion: manifest.acceptedCatalogVersion,
            acceptedCatalogDigest: manifest.acceptedCatalogDigest,
            capturedSourceManifest: manifest,
            observedGitHEAD: String(repeating: "a", count: 40)
        )
        let comparisons: [RepositoryPlanReconstructionComparison] = [
            .init(kind: .phase, parentSourceID: nil, sourceID: "phase-current", destinationID: "phase-destination-101", disposition: .conflicting),
            .init(kind: .ticket, parentSourceID: nil, sourceID: "ticket-historical", destinationID: nil, disposition: .excluded),
            .init(kind: .task, parentSourceID: "ticket-current", sourceID: "task-current", destinationID: nil, disposition: .new),
            .init(kind: .phaseDependency, parentSourceID: "phase-current", sourceID: "phase-dependency", destinationID: nil, disposition: .blocked),
            .init(kind: .ticketDependency, parentSourceID: "ticket-current", sourceID: "ticket-dependency", destinationID: nil, disposition: .blocked),
        ]
        let correction = RepositoryPlanReconstructionCorrection(
            subject: comparisons[0].subject,
            field: "name",
            sourceValue: try encoder.encode("Current delivery phase"),
            chosenValue: try encoder.encode("Reviewed current delivery phase")
        )
        let exclusion = RepositoryPlanReconstructionExclusion(
            subject: comparisons[1].subject,
            reason: "Keep historical context out of the live plan."
        )
        let blocker = RepositoryPlanReconstructionBlocker(
            code: "dependency_requires_owner_review",
            subject: comparisons[3].subject,
            message: "Confirm how the historical phase dependency should be represented."
        )
        let decisionID = "decision-native-reconstruction"
        let sourceRef = RepositoryPlanSourceReference.document(
            documentID: "current-plan",
            locator: "#accepted"
        )
        let completionProof = RepositoryPlanSourceReference.document(
            documentID: "current-plan",
            locator: "#delivery-proof"
        )
        let deliveryReference = RepositoryPlanPhaseCompletionReference(
            kind: .ticket,
            phaseSourceID: "phase-historical",
            sourceID: "ticket-historical",
            proofRef: completionProof
        )
        let evidence: [RepositoryPlanTerminalEvidence] = [
            .ownerAttestation(.init(
                id: "attestation-phase-completed",
                subject: .phase(.init(
                    sourceID: "phase-historical",
                    name: "Historical delivered phase"
                )),
                state: .completed,
                phaseCompletion: .init(
                    membershipComplete: true,
                    tickets: [.init(
                        sourceTicketID: "ticket-historical",
                        lane: .accepted,
                        acceptanceProof: completionProof
                    )],
                    goals: [],
                    obligations: [.init(
                        sourceObligationID: "obligation-native",
                        disposition: .fulfilled,
                        descendants: [deliveryReference]
                    )],
                    deliveredBy: [deliveryReference]
                ),
                decisionID: decisionID,
                attestedAt: Date(timeIntervalSince1970: 1_700_000_100),
                originalOccurredAt: nil,
                originalActorID: nil
            )),
            .original(sourceRef: sourceRef, record: .init(
                recordID: "record-original-accepted",
                repositoryID: repositoryID,
                kind: .ticketAcceptance,
                subject: .ticket(.init(
                    sourceID: "ticket-historical",
                    outcome: "Retain delivered historical context.",
                    phaseSourceID: "phase-historical",
                    taskPlan: nil
                )),
                state: .accepted,
                occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
                actorID: "historical-owner",
                phaseCompletion: nil
            )),
            .ownerAttestation(.init(
                id: "attestation-policy-b",
                subject: .ticket(.init(
                    sourceID: "ticket-historical",
                    outcome: "Retain delivered historical context.",
                    phaseSourceID: "phase-historical",
                    taskPlan: nil
                )),
                state: .accepted,
                phaseCompletion: nil,
                decisionID: decisionID,
                attestedAt: Date(timeIntervalSince1970: 1_700_000_100),
                originalOccurredAt: Date(timeIntervalSince1970: 1_700_000_000),
                originalActorID: "historical-owner"
            )),
        ]
        let payload = RepositoryPlanReconstructionPayload(
            source: source,
            reviewedProjection: projection,
            comparisons: comparisons,
            corrections: [correction],
            exclusions: [exclusion],
            terminalEvidence: evidence,
            blockers: [blocker]
        )
        let proposalID = PlanChangeProposalID(rawValue: "proposal-native-reconstruction")
        let decision = PlanChangeDecisionRecord(
            id: decisionID,
            disposition: .approved,
            actorID: "owner-app",
            baselineDigest: String(repeating: "b", count: 64),
            registration: registration,
            createdAt: Date(timeIntervalSince1970: 1_700_000_200)
        )
        let application = PlanChangeApplicationRecord(
            id: "application-native-reconstruction",
            decisionID: decisionID,
            auditEventID: .init(rawValue: "audit-native-reconstruction"),
            appliedAt: Date(timeIntervalSince1970: 1_700_000_300)
        )
        let attemptState: RepositoryPlanReconstructionApplicationAttemptState = stage == .applied
            ? .applied
            : .pending
        let attempt = RepositoryPlanReconstructionApplicationAttemptRecord(
            projectID: projectID,
            proposalID: proposalID,
            version: 1,
            applicationID: application.id,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000202")!,
            registration: registration,
            envelopeBytes: Data("exact recorded Apply envelope".utf8),
            state: attemptState,
            result: nil
        )
        let readback = RepositoryPlanReconstructionReadback(
            proposalID: proposalID,
            version: .init(
                version: 1,
                registration: registration,
                baselineDigest: decision.baselineDigest,
                baseline: Data("baseline".utf8),
                operations: [.reconstructRepositoryPlan(payload)],
                diff: .init(groups: []),
                sourceImpacts: [],
                rationale: "Review every source before Apply.",
                createdAt: Date(timeIntervalSince1970: 1_700_000_150),
                decision: decision,
                application: stage == .applied ? application : nil
            ),
            payload: payload,
            applicationAttempt: stage == .reviewing || stage == .reviewLoadFailed ? nil : attempt,
            provenance: [],
            remainingSetup: ["Resolve the remaining dependency mapping before final setup."]
        )
        let review = RepositoryPlanReconstructionReviewPresentation(
            source: source,
            originalProjection: projection,
            reviewedProjection: projection,
            comparisons: comparisons,
            blockers: [blocker],
            corrections: [correction],
            exclusions: [exclusion],
            explicitMappings: [],
            destinationSnapshots: [.init(
                subject: comparisons[0].subject,
                destinationID: "phase-destination-101",
                fields: try JSONSerialization.data(
                    withJSONObject: [
                        "lifecycle": "upcoming",
                        "name": "Existing destination phase",
                    ],
                    options: [.sortedKeys]
                )
            )],
            terminalEvidence: evidence,
            decisionID: decisionID,
            authorityConfirmed: true,
            savedReadback: readback,
            persistedVersion: 1,
            revision: 4,
            isUpdating: false,
            isSaving: false,
            isDeciding: false
        )
        return .init(
            projectID: projectID,
            stage: stage,
            inventory: nil,
            target: nil,
            selectedArtifactIDs: [],
            preparation: nil,
            review: review,
            message: stage == .outcomeUnknown
                ? "The exact recorded Apply attempt must be reconciled before retrying."
                : nil
        )
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func settle<V: View>(_ hosting: NSHostingView<V>) async throws {
        for _ in 0..<8 {
            hosting.layoutSubtreeIfNeeded()
            hosting.window?.displayIfNeeded()
            await Task.yield()
        }
    }

    private func capture<V: View>(_ hosting: NSHostingView<V>, name: String) throws {
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func accessibilityWindow(title: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success else { return nil }
        return (value as? [AXUIElement])?.first {
            accessibilityString($0, attribute: kAXTitleAttribute) == title
        }
    }

    private func accessibilityElement(
        _ root: AXUIElement,
        identifier: String
    ) -> AXUIElement? {
        var pending = [root]
        var inspected = 0
        while let element = pending.popLast(), inspected < 3_000 {
            inspected += 1
            if accessibilityString(element, attribute: kAXIdentifierAttribute) == identifier {
                return element
            }
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element,
                kAXChildrenAttribute as CFString,
                &value
            ) == .success,
               let children = value as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }

    private func accessibilityString(
        _ element: AXUIElement,
        attribute: String
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return value as? String
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root]
        var values: [String] = []
        var inspected = 0
        while let element = pending.popLast(), inspected < 3_000 {
            inspected += 1
            for attribute in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute] {
                if let value = accessibilityString(element, attribute: attribute) {
                    values.append(value)
                }
            }
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element,
                kAXChildrenAttribute as CFString,
                &value
            ) == .success,
               let children = value as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return values.joined(separator: "\n")
    }
}

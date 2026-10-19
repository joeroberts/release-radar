import AppKit
import ApplicationServices
import Foundation
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class ProjectExecutionProfileCleanupPreviewViewTests: XCTestCase {
    func testPresentationSelectsOnlyEligibleRowsAndExplainsEveryExclusion() {
        let snapshot = fixtureSnapshot()
        let eligible = selection(for: snapshot.rows[0])
        let retained = selection(for: snapshot.rows[1])

        let presentation = ProjectExecutionProfileCleanupPreviewPresentation.make(snapshot: snapshot,
            selection: [eligible, retained])

        XCTAssertEqual(presentation.selected, Set([eligible]))
        XCTAssertEqual(presentation.selectedEligibleRows.map(\.profileID), ["rr-delivery-closed"])
        XCTAssertEqual(presentation.exclusionRows.map(\.profileID), ["rr-delivery-retained", "rr-project-ro"])
        XCTAssertEqual(presentation.exclusionRows.map(\.reason), [.missingTerminalClosure, .association(.reservedProfile)])
    }

    func testRefreshDropsSelectionWhenIdentityOrBaselineChangesOrEligibilityIsLost() {
        let original = fixtureSnapshot()
        let originalSelection = selection(for: original.rows[0])

        var changedBaseline = original.rows[0]
        changedBaseline = ProjectExecutionProfileCleanupPreview.Row(profileID: changedBaseline.profileID, assignmentID: changedBaseline.assignmentID,
            role: changedBaseline.role, category: .cleanupEligible, reason: nil,
            configurationBaseline: baseline(profile: changedBaseline.profileID, version: "v2"), evidence: changedBaseline.evidence)
        let changedSnapshot = ProjectExecutionProfileCleanupPreview(
            observationIdentity: original.observationIdentity, rows: [changedBaseline])
        XCTAssertEqual(ProjectExecutionProfileCleanupPreviewPresentation.reconciling(selection: Set([originalSelection]),
            with: changedSnapshot), Set())

        var nowRetained = original.rows[0]
        nowRetained = ProjectExecutionProfileCleanupPreview.Row(profileID: nowRetained.profileID, assignmentID: nowRetained.assignmentID,
            role: nowRetained.role, category: .recoveryRetained, reason: .missingTerminalClosure,
            configurationBaseline: nowRetained.configurationBaseline, evidence: nowRetained.evidence)
        let retainedSnapshot = ProjectExecutionProfileCleanupPreview(
            observationIdentity: original.observationIdentity, rows: [nowRetained])
        XCTAssertEqual(ProjectExecutionProfileCleanupPreviewPresentation.reconciling(selection: Set([originalSelection]),
            with: retainedSnapshot), Set())
    }

    func testRefreshDropsSelectionWhenProtectedAssignmentBaselineChanges() {
        let original = fixtureSnapshot()
        let originalSelection = selection(for: original.rows[0])
        var revisedAssignment = try! XCTUnwrap(original.rows[0].assignmentBaseline)
        revisedAssignment.workerAttemptID = UUID()
        let revised = ProjectExecutionProfileCleanupPreview.Row(
            profileID: original.rows[0].profileID, assignmentID: original.rows[0].assignmentID,
            role: original.rows[0].role, category: .cleanupEligible, reason: nil,
            configurationBaseline: original.rows[0].configurationBaseline,
            assignmentBaseline: revisedAssignment, evidence: "Worker attempt changed")
        let snapshot = ProjectExecutionProfileCleanupPreview(observationIdentity: original.observationIdentity, rows: [revised])

        XCTAssertEqual(ProjectExecutionProfileCleanupPreviewPresentation.reconciling(selection: Set([originalSelection]),
            with: snapshot), Set(), "A new worker attempt must invalidate a prior cleanup preview selection")
    }

    func testSelectionChangeRequiresExplicitReselectionMessage() {
        let original = fixtureSnapshot()
        let selection = Set([self.selection(for: original.rows[0])])
        var changedAssignment = original.rows[0].assignmentBaseline!
        changedAssignment.workerAttemptID = UUID()
        let changed = ProjectExecutionProfileCleanupPreview.Row(profileID: original.rows[0].profileID,
            assignmentID: original.rows[0].assignmentID, role: original.rows[0].role, category: .cleanupEligible,
            reason: nil, configurationBaseline: original.rows[0].configurationBaseline,
            assignmentBaseline: changedAssignment, evidence: "Worker attempt changed")
        let current = ProjectExecutionProfileCleanupPreviewPresentation.reconciling(selection: selection,
            with: .init(observationIdentity: original.observationIdentity, rows: [changed]))

        XCTAssertEqual(ProjectExecutionProfileCleanupPreviewPresentation.reselectMessage(previous: selection, current: current),
                       "Profile evidence changed. Re-select eligible profiles before previewing cleanup.")
    }

    func testLoadStatesRepresentLoadingEmptyAndRecoverableFailureWithoutInventingRows() {
        XCTAssertEqual(ProjectExecutionProfileCleanupPreviewLoadState.loading,
            ProjectExecutionProfileCleanupPreviewLoadState.loading)
        XCTAssertEqual(ProjectExecutionProfileCleanupPreviewLoadState.empty,
            ProjectExecutionProfileCleanupPreviewLoadState.empty)
        XCTAssertEqual(ProjectExecutionProfileCleanupPreviewLoadState.failed("Configuration unavailable"),
            ProjectExecutionProfileCleanupPreviewLoadState.failed("Configuration unavailable"))
    }

    func testFreshViewResumesProtectedConfirmationWithoutCreatingNewAuthority() async throws {
        let snapshot = fixtureSnapshot()
        let row = snapshot.rows[0]
        var assignment = try XCTUnwrap(row.assignmentBaseline)
        let baseline = try XCTUnwrap(row.configurationBaseline)
        assignment.codexContextID = snapshot.observationIdentity.selectedCodexContextID
        assignment.permissionProfileDefinition = baseline.observedDefinition
        let confirmation = ProjectExecutionProfileCleanupConfirmation(
            requestID: UUID(), registration: assignment.registration,
            selectedCodexContextID: snapshot.observationIdentity.selectedCodexContextID,
            configurationVersion: snapshot.observationIdentity.configurationVersion,
            targets: [.init(profileID: row.profileID, assignmentID: assignment.id,
                expectedDefinition: baseline.observedDefinition, assignmentBaseline: assignment)])
        let calls = ConfirmationCalls()
        try await host(ExecutionProfileCleanupPreviewView(
            registration: assignment.registration,
            loadPreview: { snapshot },
            loadRecoverableConfirmations: { [confirmation] },
            removeConfirmedProfiles: { submitted in
                await calls.record(submitted)
                return [.init(profileID: submitted.targets[0].profileID,
                    assignmentID: submitted.targets[0].assignmentID, kind: .replayed,
                    detail: "The protected request resumed and finalized.",
                    finalizationStatus: .complete)]
            }), name: "profile-cleanup-restart-resume", width: 620) { [self] window in
                let resumeID = "project-execution-profile-cleanup-resume-\(confirmation.requestID.uuidString.lowercased())"
                let root = try await waitForAccessibilityWindow(named: window.title)
                let resume = try await waitForAccessibilityElement(root, identifier: resumeID)
                XCTAssertTrue(accessibilityText(resume).contains("Resume confirmed cleanup"))
                let callsBeforeResume = await calls.values
                XCTAssertTrue(callsBeforeResume.isEmpty)

                XCTAssertEqual(AXUIElementPerformAction(resume, kAXPressAction as CFString), .success)
                let confirmationSheet = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet")
                XCTAssertTrue(accessibilityText(confirmationSheet).contains(row.profileID))
                captureSheetContent(try await waitForSheet(on: window),
                    name: "profile-cleanup-restart-confirmation-620")
                try press(confirmationSheet, identifier: "project-execution-profile-cleanup-confirm-submit")
                _ = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-outcomes-sheet")
                captureSheetContent(try await waitForSheet(on: window),
                    name: "profile-cleanup-restart-outcomes-620")

                let submitted = await calls.values
                XCTAssertEqual(submitted, [confirmation],
                    "Restart recovery must submit the exact protected confirmation without a new UUID or selection")
            }
    }

    func testConfirmationFreezesExactSelectionCancelDoesNotCallAndResultsRemainPerTarget() async throws {
        for width in [1_100.0, 620.0] {
            let snapshot = fixtureSnapshot()
            let calls = ConfirmationCalls()
            try await host(ExecutionProfileCleanupPreviewView(registration: snapshot.rows[0].assignmentBaseline!.registration,
            loadPreview: { snapshot }, removeConfirmedProfiles: { confirmation in
                await calls.record(confirmation)
                return [
                    .init(profileID: "rr-delivery-closed", assignmentID: "closed-one",
                        kind: .removed, detail: "Removed and finalized.", finalizationStatus: .complete),
                    .init(profileID: "rr-delivery-retained", assignmentID: "retained-one",
                        kind: .replayed, detail: "Removal verified; finalization remains pending.",
                        finalizationStatus: .pending),
                ]
            }), name: "profile-cleanup-confirmation-\(Int(width))", width: width) { [self] window in
                let root = try await waitForAccessibilityWindow(named: window.title)
                try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-closed")
                try await Task.sleep(for: .milliseconds(100))
                try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
                let previewRoot = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-sheet")
                try press(previewRoot, identifier: "project-execution-profile-cleanup-confirm")
                let confirmationRoot = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet")
                XCTAssertTrue(accessibilityText(confirmationRoot).contains("rr-delivery-closed"))
                captureSheetContent(try await waitForSheet(on: window),
                    name: "profile-cleanup-confirmation-cancel-\(Int(width))")
                try press(confirmationRoot, identifier: "project-execution-profile-cleanup-confirm-cancel")
                try await Task.sleep(for: .milliseconds(100))
                let callsAfterCancel = await calls.values
                XCTAssertTrue(callsAfterCancel.isEmpty, "Cancel must not invoke cleanup")

                try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
                let secondPreview = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-sheet")
                try press(secondPreview, identifier: "project-execution-profile-cleanup-confirm")
                let submitRoot = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet")
                try press(submitRoot, identifier: "project-execution-profile-cleanup-confirm-submit")
                let outcomes = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-outcomes-sheet")
                captureSheetContent(try await waitForSheet(on: window),
                    name: "profile-cleanup-outcomes-resume-\(Int(width))")
                let callsAfterSubmit = await calls.values
                let submitted = try XCTUnwrap(callsAfterSubmit.first)
                XCTAssertEqual(submitted.selectedCodexContextID, snapshot.observationIdentity.selectedCodexContextID)
                XCTAssertEqual(submitted.configurationVersion, snapshot.observationIdentity.configurationVersion)
                XCTAssertEqual(submitted.targets.map(\.profileID), ["rr-delivery-closed"])
                let text = accessibilityText(outcomes)
                XCTAssertTrue(text.contains("Removed; cleanup complete"))
                XCTAssertTrue(text.contains("Previously verified removal; finalization pending"))
                try press(outcomes, identifier: "project-execution-profile-cleanup-outcomes-resume")
                let resumed = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet")
                try press(resumed, identifier: "project-execution-profile-cleanup-confirm-submit")
                _ = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-outcomes-sheet")
                let submittedConfirmations = await calls.values
                XCTAssertEqual(submittedConfirmations.count, 2)
                XCTAssertEqual(submittedConfirmations[0], submittedConfirmations[1],
                    "Resume must retain the complete immutable confirmation instead of generating new authority")
            }
        }
    }

    func testInFlightConfirmationPreventsDuplicateSubmitAndCannotBeDismissedAsCancelled() async throws {
        let snapshot = fixtureSnapshot()
        let calls = ConfirmationCalls()
        let gate = SubmissionGate()
        try await host(ExecutionProfileCleanupPreviewView(registration: snapshot.rows[0].assignmentBaseline!.registration,
            loadPreview: { snapshot }, removeConfirmedProfiles: { confirmation in
                await calls.record(confirmation)
                await gate.pause()
                return [.init(profileID: confirmation.targets[0].profileID,
                    assignmentID: confirmation.targets[0].assignmentID, kind: .removed, detail: "Removed.")]
            }), name: "profile-cleanup-in-flight", width: 620) { [self] window in
                let root = try await waitForAccessibilityWindow(named: window.title)
                try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-closed")
                try await Task.sleep(for: .milliseconds(100))
                try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
                let preview = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-sheet")
                try press(preview, identifier: "project-execution-profile-cleanup-confirm")
                let confirmation = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet")
                try press(confirmation, identifier: "project-execution-profile-cleanup-confirm-submit")
                await gate.waitUntilEntered()
                _ = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirm-progress")
                captureSheetContent(try await waitForSheet(on: window),
                    name: "profile-cleanup-confirmation-progress-620")
                let submit = try XCTUnwrap(accessibilityElement(confirmation,
                    identifier: "project-execution-profile-cleanup-confirm-submit"))
                let cancel = try XCTUnwrap(accessibilityElement(confirmation,
                    identifier: "project-execution-profile-cleanup-confirm-cancel"))
                var submitEnabled: CFTypeRef?
                var cancelEnabled: CFTypeRef?
                XCTAssertEqual(AXUIElementCopyAttributeValue(submit, kAXEnabledAttribute as CFString, &submitEnabled), .success)
                XCTAssertEqual(AXUIElementCopyAttributeValue(cancel, kAXEnabledAttribute as CFString, &cancelEnabled), .success)
                XCTAssertEqual(submitEnabled as? Bool, false)
                XCTAssertEqual(cancelEnabled as? Bool, false)
                let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: 0, windowNumber: window.sheets.last?.windowNumber ?? window.windowNumber,
                    context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                    isARepeat: false, keyCode: 53))
                NSApp.sendEvent(escape)
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertNotNil(accessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet"),
                    "Escape cannot imply cancellation after confirmed work starts")
                let inFlightCalls = await calls.values
                XCTAssertEqual(inFlightCalls.count, 1)
                await gate.resume()
                _ = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-outcomes-sheet")
            }
    }

    func testSubmissionFailureIsVisibleInRetainedConfirmationAndRetryUsesSameRequest() async throws {
        let snapshot = fixtureSnapshot()
        let responder = ConfirmationResponder()
        try await host(ExecutionProfileCleanupPreviewView(registration: snapshot.rows[0].assignmentBaseline!.registration,
            loadPreview: { snapshot }, removeConfirmedProfiles: { confirmation in
                try await responder.respond(to: confirmation)
            }), name: "profile-cleanup-retry", width: 620) { [self] window in
                let root = try await waitForAccessibilityWindow(named: window.title)
                try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-closed")
                try await Task.sleep(for: .milliseconds(100))
                try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
                let preview = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-sheet")
                try press(preview, identifier: "project-execution-profile-cleanup-confirm")
                let confirmation = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet")
                try press(confirmation, identifier: "project-execution-profile-cleanup-confirm-submit")
                let retained = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-confirmation-sheet")
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertTrue(accessibilityText(retained).contains("Cleanup needs attention"),
                    "A recoverable failure must be visible inside the retained modal")
                captureSheetContent(try await waitForSheet(on: window),
                    name: "profile-cleanup-confirmation-error-620")
                try press(retained, identifier: "project-execution-profile-cleanup-confirm-submit")
                _ = try await waitForAccessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-outcomes-sheet")
                let confirmations = await responder.confirmations
                XCTAssertEqual(confirmations.count, 2)
                XCTAssertEqual(confirmations[0], confirmations[1])
            }
    }

    func testRenderedPreviewSeparatesEligibleAndRetainedProfilesAtWideAndCompactWidths() async throws {
        for width in [1_100.0, 620.0] {
            let snapshot = fixtureSnapshot()
            let loader = PreviewLoader(results: [.success(snapshot), .success(snapshot), .success(snapshot)])
            try await host(ExecutionProfileCleanupPreviewView(registration: snapshot.rows[0].assignmentBaseline!.registration) { try await loader.next() },
                           name: "profile-cleanup-preview-\(Int(width))", width: width) { [self] window in
                let root = try XCTUnwrap(accessibilityWindow(named: window.title))
                for identifier in [
                    "project-execution-profile-cleanup-preview",
                    "project-execution-profile-cleanup-refresh",
                    "project-execution-profile-cleanup-row-rr-delivery-closed",
                    "project-execution-profile-cleanup-row-rr-delivery-retained",
                    "project-execution-profile-cleanup-row-rr-project-ro",
                    "project-execution-profile-cleanup-select-rr-delivery-closed",
                ] {
                    XCTAssertNotNil(accessibilityElement(root, identifier: identifier), "Missing \(identifier) at width \(width)")
                }
                XCTAssertNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-retained"))
                XCTAssertNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-select-rr-project-ro"))
                let text = accessibilityText(root)
                for expected in ["Eligible for cleanup preview", "Retained for recovery", "Outside assignment cleanup",
                                 "Closed worker connection recorded", "Worker closure evidence is incomplete",
                                 "This reusable or probe profile is outside assignment cleanup.",
                                 "Project historical-project · registration historical-registration · generation 4",
                                 "Worker attempt", "session closed-session · connection unknown",
                                 "Worktree /Synthetic/Execution/Worktrees/historical-project/closed-one · root /Synthetic/HistoricalProject"] {
                    XCTAssertTrue(text.contains(expected), "Missing \(expected) at width \(width)")
                }

                let select = try XCTUnwrap(accessibilityElement(root,
                    identifier: "project-execution-profile-cleanup-select-rr-delivery-closed"))
                XCTAssertEqual(AXUIElementSetAttributeValue(select, kAXFocusedAttribute as CFString, kCFBooleanTrue), .success)
                try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-closed")
                try await Task.sleep(for: .milliseconds(150))
                try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
                let sheet = try await waitForSheet(on: window)
                captureSheetContent(sheet, name: "profile-cleanup-preview-sheet-\(Int(width))")
                let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
                let sheetRoot = try await waitForAccessibilityElement(application,
                    identifier: "project-execution-profile-cleanup-sheet")
                let sheetText = accessibilityText(sheetRoot)
                XCTAssertTrue(sheetText.contains("rr-delivery-closed"))
                XCTAssertFalse(sheetText.contains("rr-delivery-retained\n"))
                XCTAssertTrue(sheetText.contains("Excluded profiles"))
                XCTAssertTrue(sheetText.contains("rr-project-ro"))
                let done = try XCTUnwrap(accessibilityElement(sheetRoot,
                    identifier: "project-execution-profile-cleanup-sheet-done"))
                var role: CFTypeRef?
                XCTAssertEqual(AXUIElementCopyAttributeValue(done, kAXRoleAttribute as CFString, &role), .success)
                XCTAssertEqual(role as? String, kAXButtonRole)
                XCTAssertEqual(AXUIElementPerformAction(done, kAXPressAction as CFString), .success)
                try await Task.sleep(for: .milliseconds(150))
                XCTAssertTrue(window.sheets.isEmpty, "Done must dismiss the read-only preview")

                try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
                let escapeSheet = try await waitForSheet(on: window)
                XCTAssertTrue(escapeSheet.isKeyWindow, "Cleanup preview sheet must receive keyboard events")
                let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: 0, windowNumber: escapeSheet.windowNumber, context: nil, characters: "\u{1b}",
                    charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
                NSApp.sendEvent(escape)
                try await Task.sleep(for: .milliseconds(150))
                XCTAssertTrue(window.sheets.isEmpty, "Escape must dismiss the read-only preview")
            }
        }
    }

    func testRefreshDropsChangedEligibilityBaselineAndExposesRecoverableFailure() async throws {
        let initial = fixtureSnapshot()
        let changed = ProjectExecutionProfileCleanupPreview(
            observationIdentity: initial.observationIdentity,
            rows: [
                .init(profileID: "rr-delivery-closed", assignmentID: "closed-one", role: "delivery",
                      category: .cleanupEligible, reason: nil,
                      configurationBaseline: baseline(profile: "rr-delivery-closed",
                                                     context: initial.observationIdentity.selectedCodexContextID,
                                                     version: "v2"), evidence: "Configuration changed"),
            ]
        )
        let loader = PreviewLoader(results: [.success(initial), .success(changed), .failure(PreviewError.unavailable)])
        try await host(ExecutionProfileCleanupPreviewView(registration: initial.rows[0].assignmentBaseline!.registration) { try await loader.next() }, name: "profile-cleanup-refresh", width: 620) { [self] window in
            var root = try XCTUnwrap(accessibilityWindow(named: window.title))
            try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-closed")
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertNotNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-preview-selected"))

            try press(root, identifier: "project-execution-profile-cleanup-refresh")
            try await Task.sleep(for: .milliseconds(200))
            root = try XCTUnwrap(accessibilityWindow(named: window.title))
            XCTAssertNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-preview-selected"),
                         "A changed evidence baseline must deselect the prior candidate")

            try press(root, identifier: "project-execution-profile-cleanup-refresh")
            try await Task.sleep(for: .milliseconds(200))
            root = try XCTUnwrap(accessibilityWindow(named: window.title))
            XCTAssertNotNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-error"))
            XCTAssertTrue(accessibilityText(root).contains("Profile evidence needs attention"))
            XCTAssertTrue(accessibilityText(root).contains("Configuration unavailable"))
        }
    }

    func testPreviewRefreshExplainsDroppedSelectionWithoutOpeningAnEmptySheet() async throws {
        let initial = fixtureSnapshot()
        var changedAssignment = initial.rows[0].assignmentBaseline!
        changedAssignment.workerAttemptID = UUID()
        let changed = ProjectExecutionProfileCleanupPreview(observationIdentity: initial.observationIdentity, rows: [
            .init(profileID: initial.rows[0].profileID, assignmentID: initial.rows[0].assignmentID,
                  role: initial.rows[0].role, category: .cleanupEligible, reason: nil,
                  configurationBaseline: initial.rows[0].configurationBaseline,
                  assignmentBaseline: changedAssignment, evidence: "Worker attempt changed"),
        ])
        let loader = PreviewLoader(results: [.success(initial), .success(changed)])
        try await host(ExecutionProfileCleanupPreviewView(registration: initial.rows[0].assignmentBaseline!.registration) {
            try await loader.next()
        }, name: "profile-cleanup-reselection", width: 620) { [self] window in
            let root = try XCTUnwrap(accessibilityWindow(named: window.title))
            try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-closed")
            try await Task.sleep(for: .milliseconds(100))
            try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
            let changedNotice = try await waitForAccessibilityElement(root,
                identifier: "project-execution-profile-cleanup-selection-changed")
            XCTAssertTrue(accessibilityText(changedNotice).contains(
                "Profile evidence changed. Re-select eligible profiles before previewing cleanup."))
            XCTAssertTrue(window.sheets.isEmpty, "An empty cleanup preview must not open after selection evidence changes")
        }
    }

    func testRegistrationSwitchResetsPreviewRowsSelectionAndLoaderIdentity() async throws {
        let firstRegistration = ProjectRegistration(projectID: .init(rawValue: "first-project"),
            registrationID: "first-registration", requestGeneration: 1)
        let secondRegistration = ProjectRegistration(projectID: .init(rawValue: "second-project"),
            registrationID: "second-registration", requestGeneration: 2)
        let first = fixtureSnapshot(registration: firstRegistration, profileID: "rr-delivery-first")
        let second = fixtureSnapshot(registration: secondRegistration, profileID: "rr-delivery-second")
        let loader = RegistrationLoader(first: first, second: second)
        try await host(RegistrationSwitchHost(first: firstRegistration, second: secondRegistration, loader: loader),
                       name: "profile-cleanup-registration-switch", width: 620) { [self] window in
            var root = try XCTUnwrap(accessibilityWindow(named: window.title))
            _ = try await waitForAccessibilityElement(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-first")
            try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-first")
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertNotNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-preview-selected"))

            try press(root, identifier: "profile-cleanup-switch-registration")
            try await Task.sleep(for: .milliseconds(250))
            root = try XCTUnwrap(accessibilityWindow(named: window.title))
            XCTAssertNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-row-rr-delivery-first"))
            XCTAssertNotNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-row-rr-delivery-second"))
            XCTAssertNil(accessibilityElement(root, identifier: "project-execution-profile-cleanup-preview-selected"),
                         "A new registration must not retain the prior registration's selection")
        }
        let calls = await loader.calls
        XCTAssertEqual(calls, [firstRegistration, secondRegistration])
    }

    func testLargeMixedPreviewUsesScrollableReadOnlySheet() async throws {
        let base = fixtureSnapshot()
        let eligible = base.rows[0]
        let retained = base.rows[1]
        let rows = [eligible] + (0 ..< 80).map { index in
            ProjectExecutionProfileCleanupPreview.Row(profileID: "rr-delivery-retained-\(index)",
                assignmentID: "retained-\(index)", role: retained.role, category: .recoveryRetained,
                reason: .missingTerminalClosure, configurationBaseline: retained.configurationBaseline,
                assignmentBaseline: retained.assignmentBaseline, evidence: "Closure evidence is incomplete for retained worker \(index).")
        }
        let snapshot = ProjectExecutionProfileCleanupPreview(observationIdentity: base.observationIdentity, rows: rows)
        let loader = PreviewLoader(results: [.success(snapshot), .success(snapshot)])
        try await host(ExecutionProfileCleanupPreviewView(registration: eligible.assignmentBaseline!.registration) {
            try await loader.next()
        }, name: "profile-cleanup-large-preview", width: 620) { [self] window in
            let root = try XCTUnwrap(accessibilityWindow(named: window.title))
            try press(root, identifier: "project-execution-profile-cleanup-select-rr-delivery-closed")
            try await Task.sleep(for: .milliseconds(100))
            try press(root, identifier: "project-execution-profile-cleanup-preview-selected")
            let sheet = try await waitForSheet(on: window)
            captureSheetContent(sheet, name: "profile-cleanup-preview-sheet-large")
            XCTAssertTrue(containsScrollView(sheet.contentView), "Large mixed previews must remain bounded by a scrollable sheet")
            let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
            let sheetRoot = try await waitForAccessibilityElement(application,
                identifier: "project-execution-profile-cleanup-sheet")
            let text = accessibilityText(sheetRoot)
            XCTAssertTrue(text.contains("rr-delivery-closed"))
            XCTAssertTrue(text.contains("rr-delivery-retained-79"))
            XCTAssertTrue(text.contains("Excluded profiles"))
        }
    }

    private func fixtureSnapshot(registration: ProjectRegistration = .init(projectID: .init(rawValue: "historical-project"),
                                 registrationID: "historical-registration", requestGeneration: 4),
                                 profileID: String = "rr-delivery-closed") -> ProjectExecutionProfileCleanupPreview {
        let identity = ProjectExecutionProfileCleanupPreview.ObservationIdentity(selectedCodexContextID: UUID(),
            configurationVersion: "v1", observedAt: Date(timeIntervalSinceReferenceDate: 1))
        let eligible = ProjectExecutionProfileCleanupPreview.Row(profileID: profileID, assignmentID: "closed-one",
            role: "delivery", category: .cleanupEligible, reason: nil,
            configurationBaseline: baseline(profile: profileID, context: identity.selectedCodexContextID),
            assignmentBaseline: assignmentBaseline(registration: registration, profileID: profileID),
            evidence: "Closed worker connection recorded")
        var retainedAssignment = assignmentBaseline(registration: registration, profileID: "rr-delivery-retained")
        retainedAssignment.connectionClosed = nil
        let retained = ProjectExecutionProfileCleanupPreview.Row(profileID: "rr-delivery-retained", assignmentID: "retained-one",
            role: "delivery", category: .recoveryRetained, reason: .missingTerminalClosure,
            configurationBaseline: baseline(profile: "rr-delivery-retained", context: identity.selectedCodexContextID),
            assignmentBaseline: retainedAssignment,
            evidence: "Worker closure evidence is incomplete")
        let reusable = ProjectExecutionProfileCleanupPreview.Row(profileID: "rr-project-ro", assignmentID: nil,
            role: nil, category: .outsideAssignmentCleanup, reason: .association(.reservedProfile),
            configurationBaseline: nil, evidence: "Reusable project profile")
        return .init(observationIdentity: identity, rows: [eligible, retained, reusable])
    }

    private func selection(for row: ProjectExecutionProfileCleanupPreview.Row)
    -> ProjectExecutionProfileCleanupPreviewPresentation.Selection {
        .init(profileID: row.profileID, assignmentID: row.assignmentID!, configurationBaseline: row.configurationBaseline!,
              assignmentBaseline: row.assignmentBaseline!)
    }

    private func baseline(profile: String, context: UUID = UUID(), version: String = "v1")
    -> ProjectExecutionProfileCleanupClassification.ConfigurationBaseline {
        .init(candidateProfileID: profile, selectedCodexContextID: context,
            observedDefinition: Data(#"{"filesystem":{"version":"\#(version)"},"network":{"enabled":false}}"#.utf8))
    }

    private func assignmentBaseline(registration: ProjectRegistration, profileID: String = "rr-delivery-closed") -> ProjectExecutionAssignment {
        var assignment = ProjectExecutionAssignment(id: "closed-one", registration: registration,
            checkoutPath: "/Synthetic/Execution/Worktrees/historical-project/closed-one", role: .delivery,
            permissionProfile: profileID, model: "gpt-5.6-terra", effort: "medium",
            authorization: "Synthetic closed assignment", context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], state: .closed,
            sessionID: "closed-session", worktree: .init(checkout: "/Synthetic/Execution/Worktrees/historical-project/closed-one",
                baseline: String(repeating: "a", count: 40), branch: "codex/historical-closed", commonGitDirectory: "/Synthetic/.git",
                primaryRoot: "/Synthetic/HistoricalProject"), work: nil)
        assignment.codexContextID = UUID(); assignment.connectionClosed = true; assignment.workerAttemptID = UUID(); assignment.launchReserved = true
        return assignment
    }

    private enum PreviewError: LocalizedError { case unavailable
        var errorDescription: String? { "Configuration unavailable" }
    }

    private actor PreviewLoader {
        private var results: [Result<ProjectExecutionProfileCleanupPreview, Error>]
        init(results: [Result<ProjectExecutionProfileCleanupPreview, Error>]) { self.results = results }
        func next() throws -> ProjectExecutionProfileCleanupPreview {
            guard !results.isEmpty else { throw PreviewError.unavailable }
            return try results.removeFirst().get()
        }
    }

    private actor ConfirmationCalls {
        private(set) var values = [ProjectExecutionProfileCleanupConfirmation]()
        func record(_ confirmation: ProjectExecutionProfileCleanupConfirmation) { values.append(confirmation) }
    }

    private actor SubmissionGate {
        private var entered = false
        private var arrival: CheckedContinuation<Void, Never>?
        private var release: CheckedContinuation<Void, Never>?
        func pause() async {
            entered = true
            arrival?.resume(); arrival = nil
            await withCheckedContinuation { release = $0 }
        }
        func waitUntilEntered() async {
            if !entered { await withCheckedContinuation { arrival = $0 } }
        }
        func resume() { release?.resume(); release = nil }
    }

    private actor ConfirmationResponder {
        private(set) var confirmations = [ProjectExecutionProfileCleanupConfirmation]()
        func respond(to confirmation: ProjectExecutionProfileCleanupConfirmation) throws
        -> [ProjectExecutionProfileCleanupOutcome] {
            confirmations.append(confirmation)
            if confirmations.count == 1 { throw ProjectExecutionError.unavailable }
            return [.init(profileID: confirmation.targets[0].profileID,
                assignmentID: confirmation.targets[0].assignmentID, kind: .replayed,
                detail: "The same confirmed request resumed safely.")]
        }
    }

    private actor RegistrationLoader {
        let first: ProjectExecutionProfileCleanupPreview
        let second: ProjectExecutionProfileCleanupPreview
        private(set) var calls = [ProjectRegistration]()
        init(first: ProjectExecutionProfileCleanupPreview, second: ProjectExecutionProfileCleanupPreview) { self.first = first; self.second = second }
        func load(registration: ProjectRegistration) -> ProjectExecutionProfileCleanupPreview {
            calls.append(registration)
            return registration == firstAssignment.registration ? first : second
        }
        private var firstAssignment: ProjectExecutionAssignment { first.rows[0].assignmentBaseline! }
    }

    private struct RegistrationSwitchHost: View {
        let first: ProjectRegistration
        let second: ProjectRegistration
        let loader: RegistrationLoader
        @State private var registration: ProjectRegistration

        init(first: ProjectRegistration, second: ProjectRegistration, loader: RegistrationLoader) {
            self.first = first; self.second = second; self.loader = loader
            _registration = State(initialValue: first)
        }

        var body: some View {
            VStack {
                Button("Switch registration") { registration = second }
                    .accessibilityIdentifier("profile-cleanup-switch-registration")
                ExecutionProfileCleanupPreviewView(registration: registration) {
                    await loader.load(registration: registration)
                }
                .id(registration)
            }
        }
    }

    private func host<V: View>(_ view: V, name: String, width: Double,
                               exercise: @escaping (NSWindow) async throws -> Void) async throws {
        let frame = NSRect(x: 30, y: 30, width: width, height: 850)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = name; window.isReleasedWhenClosed = false; window.contentView = hosting
        let previousPolicy = NSApp.activationPolicy(); NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        defer { window.close(); NSApp.setActivationPolicy(previousPolicy) }
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        hosting.layoutSubtreeIfNeeded()
        try await exercise(window)
    }

    private func accessibilityWindow(named title: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        func matches(_ element: AXUIElement) -> Bool {
            var candidate: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &candidate) == .success
                && candidate as? String == title
        }
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
           let window = (value as? [AXUIElement])?.first(where: matches) {
            return window
        }
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var candidate: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, attribute as CFString, &candidate) == .success,
                  let candidate,
                  CFGetTypeID(candidate) == AXUIElementGetTypeID() else { continue }
            let element = candidate as! AXUIElement
            if matches(element) { return element }
        }
        return nil
    }

    private func waitForAccessibilityWindow(named title: String) async throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let window = accessibilityWindow(named: title) { return window }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw PreviewError.unavailable
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        while let element = pending.popLast() {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier { return element }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return nil
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root], result = [String]()
        while let element = pending.popLast() {
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                   let text = value as? String { result.append(text) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return result.joined(separator: "\n")
    }

    private func press(_ root: AXUIElement, identifier: String) throws {
        let element = try XCTUnwrap(accessibilityElement(root, identifier: identifier))
        XCTAssertEqual(AXUIElementPerformAction(element, kAXPressAction as CFString), .success)
    }

    private func waitForSheet(on window: NSWindow) async throws -> NSWindow {
        let deadline = Date().addingTimeInterval(2)
        while window.sheets.isEmpty, Date() < deadline { try await Task.sleep(for: .milliseconds(25)) }
        return try XCTUnwrap(window.sheets.last, "Expected read-only cleanup preview sheet")
    }

    private func waitForAccessibilityElement(_ root: AXUIElement, identifier: String) async throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let element = accessibilityElement(root, identifier: identifier) { return element }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw PreviewError.unavailable
    }

    private func containsScrollView(_ view: NSView?) -> Bool {
        guard let view else { return false }
        return view is NSScrollView || view.subviews.contains(where: containsScrollView)
    }

    private func captureSheetContent(_ sheet: NSWindow, name: String) {
        guard let content = sheet.contentView else { return }
        content.layoutSubtreeIfNeeded()
        content.displayIfNeeded()
        guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

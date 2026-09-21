import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class ProjectDocumentationRenderingTests: XCTestCase {
    func testOverviewMetricsCenterUntruncatedLongValuesAtWideAndCompactWidths() async throws {
        let longPhaseName = "Phase 6: persistent workspace toolbar and project-management recovery"
        let project = ProjectDashboardProjection(
            id: .init(rawValue: "overview-metrics-rendering"),
            name: "Overview metrics",
            activePhaseName: longPhaseName,
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 12,
            attentionCount: 3
        )

        for width in [1100.0, 620.0] {
            try await render(
                ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: .legacy(.unavailable),
                    projectRoot: nil,
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in }
                ),
                name: "overview-metrics-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: ["Active phase", "Current work", "Owner attention", longPhaseName, "12", "3"],
                presentIdentifiers: [
                    "overview-metric-active-phase", "overview-metric-current-work", "overview-metric-owner-attention",
                ]
            )
        }
    }

    func testManageProjectOpensImmediatelyWithSelectedRegistrationAndIndependentSections() async throws {
        let projectID = ProjectID(rawValue: "manage-project-immediate")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-immediate-registration",
            requestGeneration: 7
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Immediate management",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )

        try await render(
            ProjectOverviewView(
                project: project,
                board: nil,
                documentationState: .legacy(.missing),
                projectRoot: nil,
                phaseSelectionStatus: .idle,
                openBoard: {},
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                loadProjectSettings: {
                    try await Task.sleep(for: .seconds(2))
                    return .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                }
            ),
            name: "manage-project-immediate",
            width: 620,
            expected: nil,
            presentIdentifiers: ["project-manage"],
            postActionIdentifiers: [
                "manage-project-panel",
                "manage-project-identity",
                "manage-project-section-execution",
            ],
            postActionText: [projectID.rawValue, registration.registrationID, "generation 7"],
            pressIdentifiers: ["project-manage"]
        )
    }

    func testManageProjectSheetRendersAtWideAndCompactHostWidths() async throws {
        let projectID = ProjectID(rawValue: "manage-project-sheet")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-sheet-registration",
            requestGeneration: 4
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Sheet management",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )

        for width in [1100.0, 620.0] {
            try await render(
                ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: .legacy(.missing),
                    projectRoot: nil,
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in },
                    loadProjectSettings: {
                        .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                    }
                ),
                name: "manage-project-sheet-host-\(Int(width))",
                width: width,
                expected: nil,
                presentIdentifiers: ["project-manage"],
                postActionIdentifiers: [
                    "manage-project-panel",
                    "manage-project-identity",
                    "manage-project-section-settings",
                    "manage-project-section-execution",
                ],
                postActionText: [projectID.rawValue, registration.registrationID, "generation 4"],
                pressIdentifiers: ["project-manage"],
                sheetAttachmentName: "manage-project-sheet-\(Int(width))"
            )
        }
    }

    func testManageProjectRelocatesProjectControlsAndPreservesExactCallbacks() async throws {
        let projectID = ProjectID(rawValue: "manage-project-controls")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-controls-registration",
            requestGeneration: 9
        )
        let evidence = EvidenceProjection(
            id: .init(rawValue: "manage-project-evidence"),
            label: "Management evidence",
            path: "docs/evidence/management.md",
            isAvailable: true
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Managed controls",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 1,
            evidence: [evidence]
        )
        let health = ProjectHealthSnapshot(
            projectID: projectID,
            registration: registration,
            rootPath: "/Synthetic/ManageProject",
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [.init(id: "folder", title: "Folder access needs attention", detail: "Restore the saved folder.", state: .attention)]
        )
        let preview = ProjectDocumentationSetupPreview(
            registration: registration,
            rootPath: health.rootPath!,
            target: .init(
                projectID: projectID.rawValue,
                rootID: "manage-project-root",
                repositoryID: "00000000-0000-4000-8000-000000000009",
                catalogVersion: 1,
                catalogDigest: String(repeating: "9", count: 64)
            ),
            action: .bind
        )
        let documentationStatus = DocumentationObservationStatus.observed(.init(
            identity: .init(
                projectID: projectID,
                registration: registration,
                rootID: .init(rawValue: "manage-project-root"),
                rootPath: health.rootPath,
                binding: nil
            ),
            generation: 1,
            checkedAt: health.checkedAt,
            documentationState: .legacy(.missing),
            evidence: [],
            sharedExecutionCompatibility: .init(state: .unavailable, directResults: [])
        ))
        var documentationPreviewRegistration: ProjectRegistration?
        var compatibilityRefreshCount = 0
        var evidencePreviewCount = 0

        for width in [1100.0, 620.0] {
            try await render(
                ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: .legacy(.missing),
                    documentationStatus: documentationStatus,
                    projectRoot: URL(fileURLWithPath: health.rootPath!),
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in },
                    refreshDocumentation: { compatibilityRefreshCount += 1 },
                    loadProjectSettings: {
                        .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                    },
                    loadProjectHealth: { health },
                    loadEvidencePreview: { requestedEvidenceID in
                        XCTAssertEqual(requestedEvidenceID, evidence.id)
                        evidencePreviewCount += 1
                        return .init(identity: evidence.locator, path: evidence.path, status: .available,
                                     content: .text("Exact managed evidence", isTruncated: false))
                    },
                    previewDocumentationSetup: { requestedRegistration in
                        documentationPreviewRegistration = requestedRegistration
                        return preview
                    }
                ),
                name: "manage-project-controls-\(Int(width))",
                width: width,
                expected: nil,
                postActionIdentifiers: [
                    "manage-project-panel",
                    "manage-project-identity",
                    "manage-project-section-documentation",
                    "manage-project-section-shared-execution",
                    "manage-project-section-repository-access",
                    "manage-project-section-evidence",
                ],
                pressIdentifiers: [
                    "project-manage",
                    "project-documentation-preview",
                    "shared-execution-refresh",
                    "project-health-refresh",
                    "evidence-preview-manage-project-evidence",
                ],
                afterPressIdentifiers: [
                    ["manage-project-panel"],
                    [],
                    [],
                    [],
                    ["evidence-preview-text-manage-project-evidence"],
                ]
            )
        }

        XCTAssertEqual(documentationPreviewRegistration, registration)
        XCTAssertEqual(compatibilityRefreshCount, 2)
        XCTAssertEqual(evidencePreviewCount, 2)
    }

    func testManageProjectRelocatesLifecycleControlsWithExactPreviewIdentity() async throws {
        let projectID = ProjectID(rawValue: "manage-project-lifecycle")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-lifecycle-registration",
            requestGeneration: 11
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Lifecycle management",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )
        let archivePreview = ProjectLifecyclePreview(
            projectID: projectID,
            projectName: project.name,
            source: .active,
            target: .archived,
            registration: registration,
            counts: .init(phases: 2, tickets: 5, evidence: 3, history: 8)
        )
        let removalPreview = ProjectRemovalPreview(
            projectID: projectID,
            projectName: project.name,
            lifecycle: .active,
            registration: registration,
            counts: .init(phases: 2, tickets: 5, evidence: 3, history: 8)
        )

        for width in [1100.0, 620.0] {
            var archivedPreviewCount = 0
            var archivedWith: ProjectLifecyclePreview?
            try await render(
                lifecycleOverview(
                    project: project,
                    registration: registration,
                    archivePreview: {
                        archivedPreviewCount += 1
                        return archivePreview
                    },
                    archive: { preview in archivedWith = preview },
                    removalPreview: { removalPreview },
                    remove: { _ in }
                ),
                name: "manage-project-archive-relocation-\(Int(width))",
                width: width,
                expected: nil,
                absentButtonTitles: ["Archive…", "Remove…"],
                postActionIdentifiers: ["manage-project-panel", "manage-project-identity", "manage-project-archive"],
                pressIdentifiers: ["project-manage", "manage-project-archive"],
                afterPressIdentifiers: [[], ["project-lifecycle-confirmation"]],
                afterPressFocusIdentifiers: [["manage-project-archive"], ["project-lifecycle-cancel", "project-lifecycle-confirm"]],
                afterPressText: [[], [registration.registrationID, "2 phases", "5 tickets", "No project data will be deleted"]],
                pressTitles: ["Archive Project"],
                sheetAttachmentName: "manage-project-archive-confirmation-\(Int(width))"
            )
            XCTAssertEqual(archivedPreviewCount, 1)
            XCTAssertEqual(archivedWith, archivePreview)

            var removedPreviewCount = 0
            var removedWith: ProjectRemovalPreview?
            try await render(
                lifecycleOverview(
                    project: project,
                    registration: registration,
                    archivePreview: { archivePreview },
                    archive: { _ in },
                    removalPreview: {
                        removedPreviewCount += 1
                        return removalPreview
                    },
                    remove: { preview in removedWith = preview }
                ),
                name: "manage-project-remove-relocation-\(Int(width))",
                width: width,
                expected: nil,
                absentButtonTitles: ["Archive…", "Remove…"],
                postActionIdentifiers: ["manage-project-panel", "manage-project-identity", "manage-project-remove"],
                pressIdentifiers: ["project-manage", "manage-project-remove"],
                afterPressIdentifiers: [[], ["project-removal-confirmation"]],
                afterPressFocusIdentifiers: [["manage-project-remove"], ["project-removal-cancel", "project-removal-confirm"]],
                afterPressText: [[], [registration.registrationID, "2 phases", "5 tickets", "Read-only history will remain"]],
                pressTitles: ["Remove from Tracking"],
                sheetAttachmentName: "manage-project-remove-confirmation-\(Int(width))"
            )
            XCTAssertEqual(removedPreviewCount, 1)
            XCTAssertEqual(removedWith, removalPreview)
        }
    }

    func testManageProjectLifecycleCancellationDoesNotApplyPreview() async throws {
        let projectID = ProjectID(rawValue: "manage-project-lifecycle-cancel")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-lifecycle-cancel-registration",
            requestGeneration: 12
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Lifecycle cancellation",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )
        let preview = ProjectLifecyclePreview(
            projectID: projectID,
            projectName: project.name,
            source: .active,
            target: .archived,
            registration: registration,
            counts: .init(phases: 1, tickets: 2, evidence: 3, history: 4)
        )
        var archiveCallCount = 0

        try await render(
            lifecycleOverview(
                project: project,
                registration: registration,
                archivePreview: { preview },
                archive: { _ in archiveCallCount += 1 },
                removalPreview: { throw ProjectRemovalError.projectNotFound },
                remove: { _ in }
            ),
            name: "manage-project-archive-cancellation",
            width: 620,
            expected: nil,
            postActionIdentifiers: ["manage-project-archive"],
            pressIdentifiers: ["project-manage", "manage-project-archive", "project-lifecycle-cancel"],
            afterPressIdentifiers: [[], ["project-lifecycle-confirmation"], ["manage-project-archive"]],
            afterPressFocusIdentifiers: [["manage-project-archive"], ["project-lifecycle-cancel"], ["manage-project-archive"]]
        )

        XCTAssertEqual(archiveCallCount, 0)
    }

    private func lifecycleOverview(
        project: ProjectDashboardProjection,
        registration: ProjectRegistration,
        archivePreview: @escaping () async throws -> ProjectLifecyclePreview,
        archive: @escaping (ProjectLifecyclePreview) async throws -> Void,
        removalPreview: @escaping () async throws -> ProjectRemovalPreview,
        remove: @escaping (ProjectRemovalPreview) async throws -> Void
    ) -> ProjectOverviewView {
        ProjectOverviewView(
            project: project,
            board: nil,
            documentationState: .legacy(.missing),
            projectRoot: nil,
            phaseSelectionStatus: .idle,
            openBoard: {},
            selectActivePhase: { _ in },
            reloadActivePhase: {},
            reauthorizeActivePhase: { _ in },
            loadProjectSettings: {
                .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
            },
            previewArchive: archivePreview,
            archive: archive,
            previewRemoval: removalPreview,
            remove: remove
        )
    }

    func testManageProjectRootRecoveryCallbacksPresentInsideTheManagementSheet() async throws {
        let projectID = ProjectID(rawValue: "manage-project-root-recovery")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-root-recovery-registration",
            requestGeneration: 1
        )
        let evidence = EvidenceProjection(
            id: .init(rawValue: "manage-project-worktree-evidence"),
            label: "Worktree evidence",
            path: "output/result.md",
            isAvailable: true
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Recovery management",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 1,
            evidence: [evidence]
        )
        let health = ProjectHealthSnapshot(
            projectID: projectID,
            registration: registration,
            rootPath: "/Synthetic/ManageProjectRecovery",
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [.init(id: "folder", title: "Folder access needs attention", detail: "Manage the saved roots.", state: .attention)]
        )
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-ManageProjectRecovery-\(UUID().uuidString).sqlite")
        let recovery = RepositoryRecoveryModel(
            store: DeliveryStore(databaseURL: databaseURL),
            projectID: projectID,
            allowsRelocation: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: databaseURL) }

        for (name, presses) in [
            ("repository-roots", ["project-manage", "project-health-manage-roots"]),
            ("saved-worktree", ["project-manage", "evidence-preview-manage-project-worktree-evidence", "evidence-preview-reconnect-worktree-manage-project-worktree-evidence"]),
        ] {
            try await render(
                ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: .legacy(.unavailable),
                    projectRoot: nil,
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in },
                    repositoryRecovery: recovery,
                    loadProjectSettings: {
                        .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                    },
                    loadProjectHealth: { health },
                    loadEvidencePreview: { requestedEvidenceID in
                        XCTAssertEqual(requestedEvidenceID, evidence.id)
                        return .init(
                            identity: evidence.locator,
                            path: evidence.path,
                            status: .inaccessible,
                            content: nil,
                            recovery: .reconnectWorktree(rootID: .init(rawValue: "saved-worktree"), path: "/Synthetic/SavedWorktree")
                        )
                    }
                ),
                name: "manage-project-recovery-\(name)",
                width: 620,
                expected: nil,
                postActionIdentifiers: ["manage-project-root-recovery-sheet"],
                pressIdentifiers: presses,
                afterPressIdentifiers: [["manage-project-panel", "project-health-manage-roots"], [], []]
            )
        }
    }

    func testManageProjectSettingsFailureIsLocalAndRetryLoadsOnlySettings() async throws {
        let projectID = ProjectID(rawValue: "manage-project-retry")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-retry-registration",
            requestGeneration: 3
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Retry management",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )
        var settingsLoadCount = 0
        var executionLoadCount = 0

        try await render(
            ProjectOverviewView(
                project: project,
                board: nil,
                documentationState: .legacy(.missing),
                projectRoot: nil,
                phaseSelectionStatus: .idle,
                openBoard: {},
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                loadProjectSettings: {
                    settingsLoadCount += 1
                    if settingsLoadCount == 1 {
                        throw NSError(domain: "ManageProjectTests", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: "Settings connection failed",
                        ])
                    }
                    return .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                },
                loadExecutionAssignments: { _ in
                    executionLoadCount += 1
                    return []
                }
            ),
            name: "manage-project-local-retry",
            width: 620,
            expected: nil,
            presentIdentifiers: ["project-manage"],
            postActionIdentifiers: [
                "manage-project-section-settings",
                "manage-project-section-execution",
                "project-settings-name",
            ],
            postActionText: [project.name],
            pressIdentifiers: [
                "project-manage",
                "manage-project-section-settings-retry",
            ],
            afterPressIdentifiers: [
                ["manage-project-section-settings-retry"],
                ["project-settings-name"],
            ]
        )

        XCTAssertEqual(settingsLoadCount, 2)
        XCTAssertEqual(executionLoadCount, 1)
    }

    func testManageProjectStaleSettingsRegistrationOffersCloseAndReopenRecovery() async throws {
        let projectID = ProjectID(rawValue: "manage-project-selected")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-selected-registration",
            requestGeneration: 2
        )
        let mismatchedRegistration = ProjectRegistration(
            projectID: projectID,
            registrationID: "manage-project-replacement-registration",
            requestGeneration: 3
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Selected management",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )
        var saveCalls = 0
        var settingsLoadCount = 0

        try await render(
            ProjectOverviewView(
                project: project,
                board: nil,
                documentationState: .legacy(.missing),
                projectRoot: nil,
                phaseSelectionStatus: .idle,
                openBoard: {},
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                loadProjectSettings: {
                    settingsLoadCount += 1
                    return .init(registration: mismatchedRegistration, projectName: "Replacement", excludedTaskIDs: [])
                },
                saveProjectSettings: { _, _, _ in
                    saveCalls += 1
                    return .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                }
            ),
            name: "manage-project-stale-registration",
            width: 620,
            expected: nil,
            presentIdentifiers: ["project-manage"],
            postActionIdentifiers: ["project-settings-name"],
            postActionText: [
                mismatchedRegistration.registrationID,
                "Replacement",
            ],
            pressIdentifiers: [
                "project-manage",
                "manage-project-section-settings-reopen",
            ],
            afterPressIdentifiers: [
                [
                    "manage-project-section-settings-error",
                    "manage-project-section-settings-reopen",
                ],
                ["project-settings-name"],
            ]
        )

        XCTAssertEqual(saveCalls, 0)
        XCTAssertEqual(settingsLoadCount, 1)
    }

    func testManageProjectOffersLostWorkerRecoveryWithoutConflatingRetirementOrCompletion() async throws {
        let projectID = ProjectID(rawValue: "manage-project-lost-worker")
        let registration = ProjectRegistration(projectID: projectID,
            registrationID: "manage-project-lost-worker-registration", requestGeneration: 1)
        var assignment = ProjectExecutionAssignment(id: "delivery-legacy-lost",
            registration: registration,
            checkoutPath: "/Synthetic/Execution/Worktrees/manage-project-lost-worker/delivery-legacy-lost",
            role: .delivery, permissionProfile: "rr-delivery-legacy-lost",
            model: "gpt-5.6-terra", effort: "medium",
            authorization: "Approved legacy work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .authorized, sessionID: "legacy-session",
            worktree: .init(
                checkout: "/Synthetic/Execution/Worktrees/manage-project-lost-worker/delivery-legacy-lost",
                baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-manage-project-lost-worker-delivery-legacy-lost",
                commonGitDirectory: "/Synthetic/Repository/.git",
                primaryRoot: "/Synthetic/Repository"
            ),
            work: .init(projectID: projectID, ticketID: "manage-project", taskID: "task-02",
                outcome: "Relocate controls", title: "Manage Project Task02",
                taskPlanRevision: 1, phaseID: "phase-six", phaseRevision: 1))
        assignment.launchReserved = true
        var recoveryCalls = 0
        var retirementCalls = 0

        for width in [1100.0, 620.0] {
            try await render(
                ManageProjectView(
                    registration: registration,
                    projectName: "Lost worker recovery",
                    tasks: [],
                    initialSettings: .init(registration: registration,
                        projectName: "Lost worker recovery", excludedTaskIDs: []),
                    loadSettings: {
                        .init(registration: registration,
                            projectName: "Lost worker recovery", excludedTaskIDs: [])
                    },
                    saveSettings: nil,
                    manageExecutionHook: { _ in },
                    loadExecutionAssignments: { [assignment] },
                    retireExecutionAssignment: { _ in retirementCalls += 1 },
                    recoverLostWorker: { expected in
                        XCTAssertEqual(expected.id, assignment.id)
                        recoveryCalls += 1
                    },
                    reopenCurrentRegistration: { _ in }
                ),
                name: "manage-project-lost-worker-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "Recover lost worker",
                    "Retire resources and allow replacement",
                    "Recovery preserves the checkout and committed work",
                ],
                postActionIdentifiers: ["project-settings-execution-result"],
                postActionText: [
                    "Worker connection recovered",
                    "task completion was not claimed",
                    "fresh continuation",
                ],
                pressIdentifiers: ["project-settings-execution-recover"],
                minimumElementSizes: [
                    "project-settings-execution-recover": .init(width: 44, height: 32),
                ]
            )
        }

        XCTAssertEqual(recoveryCalls, 2)
        XCTAssertEqual(retirementCalls, 0)
    }

    func testManageProjectReportsPersistedRecoveryWhenSuccessAuditIsPending() async throws {
        let projectID = ProjectID(rawValue: "manage-project-recovery-audit")
        let registration = ProjectRegistration(projectID: projectID,
            registrationID: "manage-project-recovery-audit-registration", requestGeneration: 1)
        var assignment = ProjectExecutionAssignment(id: "delivery-recovery-audit",
            registration: registration,
            checkoutPath: "/Synthetic/Execution/Worktrees/manage-project-recovery-audit/delivery-recovery-audit",
            role: .delivery, permissionProfile: "rr-delivery-recovery-audit",
            model: "gpt-5.6-terra", effort: "medium", authorization: "Approved recovery fixture",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .authorized, sessionID: "lost-session",
            worktree: .init(
                checkout: "/Synthetic/Execution/Worktrees/manage-project-recovery-audit/delivery-recovery-audit",
                baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-manage-project-recovery-audit-delivery-recovery-audit",
                commonGitDirectory: "/Synthetic/Repository/.git", primaryRoot: "/Synthetic/Repository"),
            work: .init(projectID: projectID, ticketID: "manage-project", taskID: "task-02",
                outcome: "Relocate controls", title: "Manage Project Task02",
                taskPlanRevision: 1, phaseID: "phase-six", phaseRevision: 1))
        assignment.launchReserved = true
        var recovered = assignment
        recovered.state = .stopped; recovered.connectionClosed = true; recovered.uncertainOutcome = true
        recovered.lostWorkerRecovery = .init(requestID: UUID(), priorState: .authorized,
            candidateRevision: String(repeating: "b", count: 40),
            process: .init(version: 1, observedAt: Date(timeIntervalSince1970: 1_790_049_600),
                executablePath: CodexExecutionIdentity.executable,
                permissionProfile: recovered.permissionProfile,
                argumentMarker: "permissions.\(recovered.permissionProfile).network.enabled=false"),
            grantDisposition: .matchingGrantReleased)
        var currentAssignment = assignment
        var recoveryCalls = 0

        try await render(
            ManageProjectView(
                registration: registration,
                projectName: "Recovery audit pending",
                tasks: [],
                initialSettings: .init(registration: registration,
                    projectName: "Recovery audit pending", excludedTaskIDs: []),
                loadSettings: {
                    .init(registration: registration,
                        projectName: "Recovery audit pending", excludedTaskIDs: [])
                },
                saveSettings: nil,
                manageExecutionHook: nil,
                loadExecutionAssignments: { [currentAssignment] },
                retireExecutionAssignment: nil,
                recoverLostWorker: { _ in
                    recoveryCalls += 1
                    currentAssignment = recovered
                    throw StoreError.unavailable("Synthetic success audit failure after recovery persisted.")
                },
                reopenCurrentRegistration: { _ in }
            ),
            name: "manage-project-recovery-audit-pending",
            width: 620,
            expected: nil,
            absentText: ["The worker connection was not recovered."],
            presentIdentifiers: ["project-settings-execution-recover"],
            postActionIdentifiers: ["project-settings-execution-result"],
            postActionText: [
                "Worker connection recovered",
                "audit record is still pending",
                "task completion was not claimed",
                "Finish recovery audit",
            ],
            pressIdentifiers: ["project-settings-execution-recover"],
            afterPressIdentifiers: [["project-settings-execution-recover"]]
        )

        XCTAssertEqual(recoveryCalls, 1)
    }

    func testProjectRemovalConfirmationAndRemovedHistoryAtWideAndCompactWidths() async throws {
        let projectID = ProjectID(rawValue: "project-removal-rendering")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-removal-rendering",
            requestGeneration: 12
        )
        let counts = ProjectLifecycleCounts(phases: 2, tickets: 9, evidence: 4, history: 18)
        let preview = ProjectRemovalPreview(
            projectID: projectID,
            projectName: "Historical Delivery",
            lifecycle: .active,
            registration: registration,
            counts: counts
        )
        let record = RemovedProjectRecord(
            id: .init(rawValue: "removal-rendering"),
            projectID: projectID,
            projectName: "Historical Delivery",
            originalLifecycle: .active,
            registration: registration,
            removedAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-07T12:00:00Z")),
            counts: counts
        )
        let activity = ProjectActivityProjection(projectID: projectID, items: [
            .init(
                id: "retained-audit",
                identity: .init(
                    projectID: projectID,
                    registrationID: registration.registrationID,
                    source: .audit,
                    sourceID: "retained-audit"
                ),
                source: .audit, provenance: .retainedSource, title: "Project change",
                detail: "Retained attributed history", observedAt: record.removedAt,
                occurredAt: record.removedAt, recordedAt: record.removedAt, eventFacts: nil,
                ticketID: nil, deliveryLane: nil, runtimeState: nil,
                notificationState: nil, notificationStatusText: nil,
                originatingThreadID: "thread-removal-rendering"
            ),
        ])

        for width in [1100.0, 620.0] {
            try await render(
                ProjectRemovalConfirmationView(preview: preview, confirm: {}),
                name: "c6-remove-confirmation-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "Remove Historical Delivery from tracking?", "project-removal-rendering",
                    "registration-removal-rendering", "2 phases", "9 tickets", "4 evidence items",
                    "18 history events", "Repository files are never changed",
                    "Read-only history will remain", "cannot be restored", "Cancel", "Remove from Tracking",
                ]
            )
            try await render(
                RemovedProjectView(project: record, activity: activity),
                name: "c6-removed-history-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "Historical Delivery", "Removed from tracking", "Retained history is read-only",
                    "registration-removal-rendering", "Retained attributed history",
                ],
                absentText: ["Restore Project", "Manage Project", "Remove from Tracking"]
            )
        }

        var confirmationCalls = 0
        try await render(
            ProjectRemovalConfirmationView(preview: preview) {
                confirmationCalls += 1
                throw ProjectRemovalError.stalePreview
            },
            name: "c6-remove-error",
            width: 620,
            expected: nil,
            expectedText: ["Project was not removed"],
            pressTitles: ["Remove from Tracking"]
        )
        XCTAssertEqual(confirmationCalls, 1)
        XCTAssertEqual(
            ProjectRemovalError.stalePreview.errorDescription,
            "The project changed after this removal confirmation was prepared. Review the latest counts and try again."
        )

        confirmationCalls = 0
        try await render(
            ProjectRemovalConfirmationView(preview: preview) { confirmationCalls += 1 },
            name: "c6-remove-cancel",
            width: 620,
            expected: nil,
            expectedText: ["Cancel", "Remove from Tracking"],
            pressTitles: ["Cancel"]
        )
        XCTAssertEqual(confirmationCalls, 0)
    }

    func testProjectArchiveAndArchivedDetailAtWideAndCompactWidths() async throws {
        let projectID = ProjectID(rawValue: "project-archive-rendering")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-archive-rendering",
            requestGeneration: 8
        )
        let counts = ProjectLifecycleCounts(phases: 3, tickets: 12, evidence: 7, history: 24)
        let preview = ProjectLifecyclePreview(
            projectID: projectID,
            projectName: "Archived Delivery",
            source: .active,
            target: .archived,
            registration: registration,
            counts: counts
        )
        let archived = ArchivedProjectProjection(
            id: projectID,
            name: "Archived Delivery",
            registration: registration,
            counts: counts
        )

        for width in [1100.0, 620.0] {
            try await render(
                ProjectLifecycleConfirmationView(preview: preview, confirm: {}),
                name: "c5-archive-confirmation-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: ["Archive Archived Delivery?", "3 phases", "12 tickets", "7 evidence items", "24 history events", "No project data will be deleted", "Cancel", "Archive Project"]
            )
            try await render(
                ArchivedProjectView(project: archived, loadHealth: nil, previewRestore: { throw ProjectLifecycleError.stalePreview }, restore: { _ in }),
                name: "c5-archived-detail-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: ["Archived Delivery", "Archived project", "Read-only", "Restore Project", "registration-archive-rendering", "12", "7"],
                absentText: ["Manage Project", "Manage Repository Roots", "Copy setup prompt"]
            )
        }

        var confirmationCalls = 0
        try await render(
            ProjectLifecycleConfirmationView(preview: preview) {
                confirmationCalls += 1
                throw ProjectLifecycleError.stalePreview
            },
            name: "c5-archive-error",
            width: 620,
            expected: nil,
            expectedText: ["Project state was not changed", "The project changed after this confirmation was prepared"],
            pressTitles: ["Archive Project"]
        )
        XCTAssertEqual(confirmationCalls, 1)

        confirmationCalls = 0
        try await render(
            ProjectLifecycleConfirmationView(preview: preview) { confirmationCalls += 1 },
            name: "c5-archive-cancel",
            width: 620,
            expected: nil,
            expectedText: ["Cancel", "Archive Project"],
            pressTitles: ["Cancel"]
        )
        XCTAssertEqual(confirmationCalls, 0)
    }

    // Inspect only this isolated test process and its own titled native windows.
    func testOverviewDocumentationStateAtWideAndCompactWidths() async throws {
        let project = ProjectDashboardProjection(
            id: .init(rawValue: "m2c-rendering"),
            name: "Documentation Preview",
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )
        for (name, state) in states {
            for width in [1100.0, 620.0] {
                let view = ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: state,
                    projectRoot: URL(fileURLWithPath: "/Synthetic/DocumentationPreview"),
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in }
                )
                try await render(
                    view,
                    name: "m5-overview-\(name)-\(Int(width))",
                    width: width,
                    expected: ProjectGuidancePresentation(documentationState: state),
                    expectedText: ["Shared execution", "Checking compatibility", "Refresh compatibility"]
                )
            }
        }
    }

    func testDocumentationActivationShowsActionableCatalogTransitionRejection() async throws {
        let projectID = ProjectID(rawValue: "catalog-transition-rendering")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "catalog-transition-registration",
            requestGeneration: 1
        )
        let preview = ProjectDocumentationSetupPreview(
            registration: registration,
            rootPath: "/Synthetic/CatalogTransition",
            target: .init(
                projectID: projectID.rawValue,
                rootID: "root",
                repositoryID: "00000000-0000-4000-8000-000000000001",
                catalogVersion: 1,
                catalogDigest: String(repeating: "b", count: 64)
            ),
            action: .accept(
                priorCatalogVersion: 1,
                priorCatalogDigest: String(repeating: "a", count: 64)
            )
        )
        let diagnostic = DocumentationCatalogTransitionDiagnostic(
            projectID: projectID.rawValue,
            rootID: "root",
            repositoryID: preview.target.repositoryID,
            acceptedCatalogVersion: 1,
            acceptedCatalogDigest: String(repeating: "a", count: 64),
            candidateCatalogVersion: 1,
            candidateCatalogDigest: String(repeating: "b", count: 64),
            isValid: false,
            validationError: .invalidTransition,
            artifactID: "rr-active-brief",
            artifactPath: "docs/delivery/task-briefs/active.md"
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Catalog Transition",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 1
        )
        let health = ProjectHealthSnapshot(
            projectID: projectID,
            registration: registration,
            rootPath: preview.rootPath,
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: []
        )

        for width in [1100.0, 620.0] {
            let view = ProjectOverviewView(
                project: project,
                board: nil,
                documentationState: .managedUnavailable(hasAuditedHandoff: true, reason: .catalogUnaccepted, validationError: nil),
                projectRoot: URL(fileURLWithPath: preview.rootPath),
                phaseSelectionStatus: .idle,
                openBoard: {},
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                loadProjectSettings: {
                    .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                },
                loadProjectHealth: { health },
                previewDocumentationSetup: { _ in preview },
                performDocumentationSetup: { _ in
                    throw ProjectDocumentationSetupError.catalogTransitionRejected(diagnostic)
                }
            )
            try await render(
                view,
                name: "catalog-transition-rejection-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "Catalog was not accepted",
                    "invalidTransition",
                    "rr-active-brief",
                    "docs/delivery/task-briefs/active.md",
                    "Run the repository documentation check",
                    "No accepted documentation state changed",
                ],
                postActionIdentifiers: ["project-documentation-action-error"],
                postActionVisibleIdentifiers: ["project-documentation-action-error"],
                postActionFocusedIdentifier: "project-documentation-action-error",
                pressIdentifiers: ["project-manage"],
                pressTitles: ["Preview Documentation Action", "Accept This Catalog"]
            )
        }
    }

    func testDocumentationBindFailureRetainsRepositoryActionHeading() async throws {
        let projectID = ProjectID(rawValue: "repository-bind-rendering")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "repository-bind-registration",
            requestGeneration: 1
        )
        let preview = ProjectDocumentationSetupPreview(
            registration: registration,
            rootPath: "/Synthetic/RepositoryBind",
            target: .init(
                projectID: projectID.rawValue,
                rootID: "root",
                repositoryID: "00000000-0000-4000-8000-000000000001",
                catalogVersion: 1,
                catalogDigest: String(repeating: "b", count: 64)
            ),
            action: .bind
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Repository Binding",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 1
        )
        let health = ProjectHealthSnapshot(
            projectID: projectID,
            registration: registration,
            rootPath: preview.rootPath,
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: []
        )

        try await render(
            ProjectOverviewView(
                project: project,
                board: nil,
                documentationState: .legacy(.current(version: RepositoryDocumentContract.guidanceVersion)),
                projectRoot: URL(fileURLWithPath: preview.rootPath),
                phaseSelectionStatus: .idle,
                openBoard: {},
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                loadProjectSettings: {
                    .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                },
                loadProjectHealth: { health },
                previewDocumentationSetup: { _ in preview },
                performDocumentationSetup: { _ in
                    throw ProjectDocumentationSetupError.command(.documentation(.bindingMismatch))
                }
            ),
            name: "repository-bind-rejection-620",
            width: 620,
            expected: nil,
            expectedText: ["Repository was not bound", "bindingMismatch"],
            absentText: ["Catalog was not accepted"],
            postActionIdentifiers: ["project-documentation-action-error"],
            postActionVisibleIdentifiers: ["project-documentation-action-error"],
            postActionFocusedIdentifier: "project-documentation-action-error",
            pressIdentifiers: ["project-manage"],
            pressTitles: ["Preview Documentation Action", "Bind This Repository"]
        )
    }

    func testOnboardingDocumentationPreviewAtWideAndCompactWidths() async throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-M5-Rendering-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        print("M5 isolated rendering store: \(output.path)")
        let store = DeliveryStore(databaseURL: output.appendingPathComponent("rendering.sqlite"))
        for (name, state) in states {
            let preview = OnboardingPreview(
                selectedFolder: URL(fileURLWithPath: "/Synthetic/DocumentationPreview"),
                gitRoot: nil,
                includedTaskDescriptors: [],
                rejectedTaskDescriptors: [],
                authorizedWorktreeURLs: [],
                worktreesRequiringAuthorization: [],
                documentationState: state
            )
            for width in [1100.0, 620.0] {
                let captureName = "m5-onboarding-\(name)-\(Int(width))"
                let view = OnboardingView(
                    store: store,
                    navigationTitle: captureName,
                    onOpenExisting: { _ in },
                    pasteboardWriter: { _ in XCTFail("Rendering must not write to the clipboard"); return false },
                    initialPreview: preview,
                    onFinished: { _ in XCTFail("Rendering must not initialize a project") }
                )
                try await render(view, name: captureName, width: width, expected: ProjectGuidancePresentation(documentationState: state))
            }
        }
    }

    func testUsableLifecycleOverviewAtWideAndCompactWidths() async throws {
        let projectID = ProjectID(rawValue: "project-rendering-opaque")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-rendering-opaque",
            requestGeneration: 3
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Usable Lifecycle",
            registration: registration,
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 1
        )
        let health = ProjectHealthSnapshot(
            projectID: projectID,
            registration: registration,
            rootPath: "/Synthetic/UsableLifecycle",
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [
                .init(id: "storage", title: "Local storage ready", detail: "The current Release Radar schema is available.", state: .ready),
                .init(id: "folder", title: "Folder access ready", detail: "/Synthetic/UsableLifecycle", state: .ready),
                .init(id: "documentation", title: "Release Radar guidance not installed", detail: "Repository preparation remains explicit.", state: .attention),
                .init(id: "plugin", title: "Codex workflow ready", detail: "The installed workflow matches.", state: .ready),
                .init(id: "observer", title: "Codex observation unavailable", detail: "Retry observation separately.", state: .attention),
            ]
        )
        for width in [1100.0, 620.0] {
            let view = ProjectOverviewView(
                project: project,
                board: nil,
                documentationState: .legacy(.missing),
                projectRoot: URL(fileURLWithPath: "/Synthetic/UsableLifecycle"),
                phaseSelectionStatus: .idle,
                openBoard: {},
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                loadProjectSettings: {
                    .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                },
                saveProjectSettings: { _, _, _ in
                    XCTFail("Rendering must not save settings")
                    return .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                },
                loadProjectHealth: { health },
                previewDocumentationSetup: { _ in
                    XCTFail("Rendering must not preview documentation")
                    throw ProjectDocumentationSetupError.catalogUnavailable
                }
            )
            try await render(
                view,
                name: "lifecycle-overview-\(Int(width))",
                width: width,
                expected: ProjectGuidancePresentation(documentationState: .legacy(.missing)),
                expectedText: [
                    "Ready for a first phase",
                    "Manage Project",
                    "Help",
                    "Documentation activation",
                    "Project health",
                    "registration-rendering-opaque",
                    "generation 3",
                    "Local storage ready",
                    "Folder access ready",
                    "Codex workflow ready",
                    "Codex observation unavailable",
                ]
            )
        }
    }

    func testRDSApplicationRoutesAtWideAndCompactWidths() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RDS-Routes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()

        let projectID = DashboardSampleData.projectID
        let routes: [(String, AppRoute, String)] = [
            ("projects", .projects, "Projects"),
            ("needs-review", .needsReview, "Needs Review"),
            ("notifications", .notifications, "Notifications"),
            ("settings", .settings, "Connections"),
            ("overview", .projectOverview(projectID), "Overview"),
            ("phase-board", .phaseBoard(projectID), "Phase Board"),
            ("dependencies", .dependencies(projectID), "Dependencies"),
            ("activity", .activity(projectID), "History"),
        ]

        for width in [1100.0, 620.0] {
            model.isSidebarCompact = width <= 620
            for (name, route, expectedTitle) in routes {
                model.selection = route
                var absentText = ["Persisted locally"]
                switch route {
                case .projects, .needsReview, .notifications, .settings:
                    absentText.append("Delivery")
                default:
                    break
                }
                try await render(
                    SidebarView(model: model),
                    name: "rds-\(name)-\(Int(width))",
                    width: width,
                    expected: nil,
                    expectedText: [expectedTitle],
                    absentText: absentText
                )
            }
        }
    }

    func testRDSLifecycleSheetsAndPluginConflictRenderInExistingHost() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RDS-Sheets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            externalServicesSuppressed: true,
            seedSampleData: false
        )
        model.codexPluginState = .failed(.marketplaceConflict)
        model.codexPluginSettingsMessage = CodexPluginSettingsPresentation(state: model.codexPluginState).detail
        try await render(
            SettingsView(model: model),
            name: "rds-plugin-conflict-settings",
            width: 760,
            expected: nil,
            expectedText: [
                "Release Radar Codex Plugin",
                "A different Release Radar plugin or MCP entry already owns this name.",
                "Resolve or rename the conflicting plugin or MCP entry in Codex, then try again.",
            ]
        )

        let helperModel = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("helper.sqlite")),
            codexPluginShippedVersion: "0.1.9",
            externalServicesSuppressed: true,
            seedSampleData: false
        )
        helperModel.codexPluginState = .installed(version: "0.1.9")
        helperModel.codexPluginSettingsMessage = "Lifecycle helper restarted. Plugin status refreshed."
        for width in [1100.0, 620.0] {
            try await render(
                SettingsView(model: helperModel),
                name: "codex-helper-restart-success-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "Release Radar Codex Plugin",
                    "Installed",
                    "Restart plugin helper",
                    "Lifecycle helper restarted. Plugin status refreshed.",
                ],
                minimumElementSizes: ["codex-plugin-restart-helper": .init(width: 44, height: 24)]
            )
        }

        helperModel.codexPluginSettingsMessage = nil
        helperModel.codexPluginOperation = .restartHelper
        try await render(
            SettingsView(model: helperModel),
            name: "codex-helper-restart-progress",
            width: 620,
            expected: nil,
            expectedText: ["Restarting plugin helper", "Restart plugin helper"],
            disabledIdentifiers: ["codex-plugin-restart-helper"]
        )
        helperModel.codexPluginOperation = nil

        model.alertRules = try AlertRuleSnapshot(values: Dictionary(
            uniqueKeysWithValues: AlertRuleKind.allCases.map { ($0, true) }
        ))
        for width in [1100.0, 620.0] {
            try await render(
                SettingsView(model: model),
                name: "rds-notification-settings-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: ["Alert rules", "Blocked linked goals", "Paused goals"],
                pressIdentifiers: ["settings-notifications"],
                minimumElementSizes: [
                    "alert-blocked-goals": CGSize(width: 240, height: 44),
                    "alert-agent-completion-review": CGSize(width: 240, height: 44),
                    "alert-needs-review": CGSize(width: 240, height: 44),
                    "alert-paused-goals": CGSize(width: 240, height: 44),
                ]
            )
        }

        let registration = ProjectRegistration(
            projectID: .init(rawValue: "rds-sheet-project"),
            registrationID: "rds-sheet-registration",
            requestGeneration: 1
        )
        try await render(
            ProjectSettingsEditor(
                initial: .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: []),
                tasks: [.init(id: "task-1", workingDirectory: directory, title: "RDS adoption")],
                save: { _, _ in
                    XCTFail("Rendering must not save project settings")
                    return .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: [])
                }
            ),
            name: "rds-project-settings-sheet",
            width: 620,
            expected: nil,
            expectedText: ["Project settings", "Observed Codex tasks", "RDS adoption", "Save"]
        )

        try await render(
            ProjectSettingsEditor(
                initial: .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: []),
                tasks: [],
                manageExecutionHook: { _ in throw ProjectExecutionError.workflowDisabled },
                save: { _, _ in
                    XCTFail("Rendering must not save project settings")
                    return .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: [])
                }
            ),
            name: "disabled-workflow-update-guidance",
            width: 620,
            expected: nil,
            expectedText: [
                "This project workflow is disabled. Choose Resume project workflow to restore the verified hook.",
                "Stopped and uncertain workers remain blocked; replacement work requires a fresh assignment.",
            ],
            absentText: ["Return to the coordinator; no work turn is authorized."],
            pressIdentifiers: ["project-settings-execution-update"]
        )

        try await render(
            ProjectSettingsEditor(
                initial: .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: []),
                tasks: [],
                manageExecutionHook: { _ in throw ProjectExecutionError.unavailable },
                save: { _, _ in
                    XCTFail("Rendering must not save project settings")
                    return .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: [])
                }
            ),
            name: "unavailable-workflow-update-guidance",
            width: 620,
            expected: nil,
            expectedText: ["Project execution setup is unavailable. Resume setup in Release Radar before launching work."],
            absentText: ["This project workflow is disabled"],
            pressIdentifiers: ["project-settings-execution-update"]
        )

        try await render(
            ProjectLifecycleHelpView(),
            name: "rds-project-lifecycle-help",
            width: 620,
            expected: nil,
            expectedText: ["Project lifecycle help", "Initialize locally", "Prepare repository documentation", "Recover safely"]
        )
    }

    func testEmptyReviewInboxRendersWithoutAnEmptyColumnOrZeroBadge() async throws {
        let projectID = ProjectID(rawValue: "empty-review-project")
        var selection: ReviewItemID?
        let view = NeedsReviewView(
            inbox: .init(projectID: projectID, openItems: [], completedItems: []),
            selectedItemID: Binding(get: { selection }, set: { selection = $0 }),
            isPerformingAction: false,
            actionFailure: nil,
            projectName: "Empty Review Project",
            authorizationRecovery: nil,
            onDecision: { _, _ in },
            onRecoverAuthorization: { _, _ in }
        )

        for width in [1100.0, 620.0] {
            try await render(
                view,
                name: "empty-review-inbox-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: ["Inbox clear", "No review decisions are waiting for this project."],
                absentText: ["0 open", "OPEN"]
            )
        }
    }

    func testApplicationHealthPanelPresentsReadableRecoveryActionsAtWideAndCompactWidths() async throws {
        let projectID = ProjectID(rawValue: "health-project")
        let snapshot = ApplicationHealthSnapshot(
            projectTarget: .init(projectID: projectID, registrationID: "health-registration", requestGeneration: 4),
            rootPath: "/Synthetic/HealthProject",
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [
                .init(id: "storage", title: "Local storage ready", detail: "The current schema is available.", state: .ready),
                .init(id: "folder", title: "Folder access needs attention", detail: "Reauthorize the saved folder.", state: .attention),
                .init(id: "documentation", title: "Documentation needs attention", detail: "Complete repository setup.", state: .attention),
                .init(id: "plugin", title: "Codex workflow ready", detail: "Version 0.1.7 is installed.", state: .ready),
                .init(id: "observer", title: "Codex observation unavailable", detail: "No live attachment is configured.", state: .attention),
            ]
        )

        for width in [1100.0, 620.0] {
            try await render(
                ApplicationHealthPanel(
                    snapshot: snapshot,
                    isRefreshing: false,
                    refresh: {},
                    openProject: {},
                    reviewConnections: {},
                    restoreBackup: {}
                ),
                name: "application-health-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "3 checks need attention",
                    "Folder access needs attention",
                    "Open Project",
                    "Review Connection",
                    "Technical details",
                    "Check Again",
                ]
            )
        }

        var restoreCalls = 0
        let recovery = ApplicationHealthSnapshot(
            projectTarget: nil,
            rootPath: nil,
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [
                .init(
                    id: "recovery",
                    title: "Recovery requires attention",
                    detail: "Target: /Synthetic/release-radar.sqlite. Choose Restore Backup; plugin, permission and notification state remains unchanged during inspection.",
                    state: .unavailable
                ),
            ]
        )
        try await render(
            ApplicationHealthPanel(
                snapshot: recovery,
                isRefreshing: false,
                refresh: {},
                openProject: {},
                reviewConnections: {},
                restoreBackup: { restoreCalls += 1 }
            ),
            name: "application-health-recovery-action",
            width: 620,
            expected: nil,
            expectedText: ["Recovery requires attention", "Restore Backup", "/Synthetic/release-radar.sqlite"],
            pressTitles: ["Restore Backup"]
        )
        XCTAssertEqual(restoreCalls, 1)
    }

    func testRecoverySettingsKeepRDSStructureAtWideAndCompactWidths() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-C7-Settings-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("release-radar.sqlite")
        let model = AppModel(
            store: DeliveryStore(databaseURL: databaseURL),
            databaseURL: databaseURL,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()

        for width in [1100.0, 620.0] {
            try await render(
                SettingsView(model: model, selectedTab: .general),
                name: "c7-recovery-general-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "Backup and recovery", "Create Backup", "Restore Backup",
                    "Credentials", "device permission", "Reset application preferences",
                    "Reset Preferences",
                ]
            )
            try await render(
                SettingsView(model: model, selectedTab: .projects),
                name: "c7-recovery-projects-\(Int(width))",
                width: width,
                expected: nil,
                expectedText: [
                    "Application health", "Reset tracking data", "Reset Tracking Data",
                    "active and archived", "retained-history",
                ]
            )
        }
    }

    func testPhaseLessRoutesRenderAsSupportedRDSStatesAtWideAndCompactWidths() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RDS-PhaseLess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed phase-less RDS rendering fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('phase-less-rds', 'Phase-less Project')")
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let projectID = ProjectID(rawValue: "phase-less-rds")

        for width in [1100.0, 620.0] {
            model.isSidebarCompact = width <= 620
            for (name, route, expectedTitle) in [
                ("phase-board", AppRoute.phaseBoard(projectID), "Ready for a first phase"),
                ("dependencies", AppRoute.dependencies(projectID), "No phase dependencies yet"),
            ] {
                model.selection = route
                try await render(
                    SidebarView(model: model),
                    name: "rds-phase-less-\(name)-\(Int(width))",
                    width: width,
                    expected: nil,
                    expectedText: [expectedTitle]
                )
            }
        }
    }

    func testProjectHealthFolderRecoveryButtonInvokesItsAuthorizedAction() async throws {
        var invocationCount = 0
        var rootsInvocationCount = 0
        let projectID = ProjectID(rawValue: "project-recovery")
        let snapshot = ProjectHealthSnapshot(
            projectID: projectID,
            registration: .init(projectID: projectID, registrationID: "registration-recovery", requestGeneration: 1),
            rootPath: "/Synthetic/Recovery",
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [
                .init(id: "folder", title: "Folder access expired", detail: "Select the same saved folder again.", state: .attention),
                .init(id: "documentation", title: "Managed documentation unavailable", detail: "Catalog remains invalid.", state: .attention),
            ]
        )
        try await render(
            ProjectHealthView(snapshot: snapshot, isRefreshing: false, refresh: {}, reauthorize: { invocationCount += 1 }, manageRoots: { rootsInvocationCount += 1 }),
            name: "lifecycle-folder-recovery",
            width: 620,
            expected: nil,
            expectedText: ["Restore folder access", "Catalog remains invalid."],
            pressIdentifiers: ["project-health-reauthorize", "project-health-manage-roots"]
        )
        XCTAssertEqual(invocationCount, 1)
        XCTAssertEqual(rootsInvocationCount, 1)
    }

    func testOnboardingNativeCopyUsesTheManagedUpgradePromptForOutdatedGuidance() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-copy-action-test-\(UUID().uuidString)", isDirectory: true)
        let root = directory.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        try Data("# Existing owner documentation\n".utf8).write(to: root.appendingPathComponent("README.md"))
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let preview = OnboardingPreview(
            selectedFolder: root,
            gitRoot: nil,
            includedTaskDescriptors: [],
            rejectedTaskDescriptors: [],
            authorizedWorktreeURLs: [],
            worktreesRequiringAuthorization: [],
            documentationState: .legacy(.outdated(installed: 1, current: 3))
        )
        var copied = ""
        let view = OnboardingView(
            store: store,
            navigationTitle: "lifecycle-native-copy",
            onOpenExisting: { _ in XCTFail("Must remain in initialization") },
            pasteboardWriter: { copied = $0; return true },
            initialPreview: preview,
            onFinished: { _ in XCTFail("Copy does not finish initialization") }
        )

        try await render(
            view,
            name: "lifecycle-native-copy",
            width: 620,
            expected: ProjectGuidancePresentation(documentationState: preview.documentationState),
            pressIdentifiers: ["onboarding-initialize-confirm", "onboarding-copy-codex-prompt"]
        )

        XCTAssertFalse(copied.localizedCaseInsensitiveContains("lifecycle bootstrap"))
        XCTAssertTrue(copied.contains("Require an existing catalogued"))
    }

    func testPhase3ADocumentationCheckingAndFolderRecoveryAtWideAndCompactWidths() async throws {
        let projectID = ProjectID(rawValue: "phase3a-rendering")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "phase3a-rendering-registration",
            requestGeneration: 3
        )
        let identity = DocumentationObservationIdentity(
            projectID: projectID,
            registration: registration,
            rootID: .init(rawValue: "phase3a-rendering-root"),
            rootPath: "/Synthetic/Phase3A",
            binding: nil
        )
        let unavailableState = ProjectDocumentationState.managedUnavailable(
            hasAuditedHandoff: true,
            reason: .rootUnavailable,
            validationError: nil
        )
        let unavailableEvidence = EvidenceProjection(
            EvidenceReadback(
                evidence: .init(
                    id: .init(rawValue: "phase3a-evidence"),
                    projectID: projectID,
                    ticketID: nil,
                    locator: .managedDocument(artifactID: "current-plan"),
                    isAvailable: false
                ),
                managedDocument: .init(
                    artifactID: "current-plan",
                    resolvedPath: nil,
                    label: "Current plan",
                    lifecycle: nil,
                    authority: nil,
                    authorityRole: nil,
                    failure: .rootUnavailable
                )
            )
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Documentation Freshness",
            registration: registration,
            activePhaseName: "Current delivery",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 2,
            attentionCount: 1,
            evidence: [unavailableEvidence]
        )
        let checkingStatus = DocumentationObservationStatus.checking(identity: identity, generation: 7)
        let unavailableStatus = DocumentationObservationStatus.observed(
            .init(
                identity: identity,
                generation: 8,
                checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
                documentationState: unavailableState,
                evidence: []
            )
        )
        for width in [1100.0, 620.0] {
            try await render(
                ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: .managed(hasAuditedHandoff: true, catalogVersion: 1, catalogDigest: "synthetic"),
                    documentationStatus: checkingStatus,
                    projectRoot: URL(fileURLWithPath: "/Synthetic/Phase3A"),
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in }
                ),
                name: "phase3a-checking-\(Int(width))",
                width: width,
                expected: .checking,
                expectedText: ["Checking"]
            )
            try await render(
                ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: unavailableState,
                    documentationStatus: unavailableStatus,
                    projectRoot: URL(fileURLWithPath: "/Synthetic/Phase3A"),
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in },
                    reauthorizeProjectHealth: { _, _ in
                        throw ProjectRootManagementError.stale
                    }
                ),
                name: "phase3a-folder-recovery-\(Int(width))",
                width: width,
                expected: ProjectGuidancePresentation(documentationState: unavailableState),
                expectedText: ["Restore folder access", "Repository folder is unavailable"]
            )
        }
    }

    func testSharedExecutionCompatibilityPresentationCoversEveryReviewedState() {
        let expectedTitles: [(SharedExecutionCompatibilityState, String)] = [
            (.notDeclared, "Not declared"),
            (.compatibleV1, "Compatible with V1"),
            (.compatibleOlder, "Compatible with an older standard"),
            (.updateAvailable, "Compatible update available"),
            (.pendingCatalogAcceptance, "Pending catalog acceptance"),
            (.incompatible, "Incompatible"),
            (.unavailable, "Compatibility unavailable"),
            (.rootUnknown, "Repository root unknown"),
            (.unknown, "Compatibility unknown"),
        ]

        for (state, title) in expectedTitles {
            let presentation = SharedExecutionCompatibilityPresentation(state: state)
            XCTAssertEqual(presentation.status, title)
            XCTAssertFalse(presentation.detail.isEmpty)
            XCTAssertFalse(presentation.recovery.isEmpty)
        }

        let mismatchCopy: [(SharedExecutionCompatibilityIssue, String, String)] = [
            (.declarationDuplicate, "declared more than once", "Keep one exact V1 block"),
            (.declarationModified, "does not match the V1 block", "Restore the exact V1 declaration"),
            (.unsupportedDeclaredStandard, "declared standard is not supported", "Adopt a supported standard"),
            (.installedCapabilityUnsupported, "installed exact plugin capability does not support", "Use the separate owner-controlled plugin flow"),
            (.repositoryIdentityMismatch, "diagnosis does not match the accepted repository", "Recheck the exact root and accepted catalog"),
            (.checkerFailed, "repository checker failed", "Inspect the checker direct result"),
        ]
        for (issue, detail, recovery) in mismatchCopy {
            let presentation = SharedExecutionCompatibilityPresentation(result: .init(
                state: .incompatible,
                directResults: [],
                issue: issue
            ))
            XCTAssertTrue(presentation.detail.contains(detail))
            XCTAssertTrue(presentation.recovery.contains(recovery))
        }
    }

    func testSharedExecutionCompatibilityRendersAllStatesAndDirectResultsAtWideAndCompactWidths() async throws {
        let result = SharedExecutionDirectResult(
            check: "documentation",
            runner: "ReleaseRadarDocumentationTool contract v1",
            scope: "/Synthetic/SharedExecution/docs",
            source: "local observation; Git source unknown",
            applicability: .unknown,
            status: .passed,
            directResult: "passed",
            limitation: "This observation does not establish owner acceptance."
        )
        let states: [SharedExecutionCompatibilityState] = [
            .notDeclared, .compatibleV1, .compatibleOlder, .updateAvailable,
            .pendingCatalogAcceptance, .incompatible, .unavailable, .rootUnknown, .unknown,
        ]
        for width in [1100.0, 620.0] {
            for state in states {
                let presentation = SharedExecutionCompatibilityPresentation(state: state)
                let directResults = state == .compatibleV1 ? [result] : []
                try await render(
                    ScrollView {
                        SharedExecutionCompatibilityView(
                            documentationStatus: compatibilityStatus(
                                state: state,
                                directResults: directResults
                            ),
                            refresh: {}
                        )
                        .padding(24)
                    },
                    name: "shared-execution-\(state.rawValue)-\(Int(width))",
                    width: width,
                    expected: nil,
                    expectedText: [
                        "Shared execution", presentation.status, presentation.detail,
                        presentation.recovery, "Refresh compatibility",
                    ] + (directResults.isEmpty ? [] : [
                        "Direct results", "Check", "documentation", "Runner",
                        "Scope", "Source", "Applicability", "unknown", "Status",
                        "passed", "Direct result", "Limitation",
                        "This observation does not establish owner acceptance.",
                    ]),
                    absentText: ["Install plugin", "Adopt standard", "Accept catalog"],
                    absentButtonTitles: ["Install plugin", "Adopt standard", "Accept catalog"]
                )
            }
        }
    }

    func testSharedExecutionCompatibilityRefreshIsAccessibleAndReadOnly() async throws {
        var refreshCount = 0
        try await render(
            SharedExecutionCompatibilityView(
                documentationStatus: compatibilityStatus(state: .unavailable),
                refresh: { refreshCount += 1 }
            )
            .padding(24),
            name: "shared-execution-refresh",
            width: 620,
            expected: nil,
            expectedText: ["Shared execution", "Compatibility unavailable"],
            absentText: ["Install plugin", "Adopt standard", "Accept catalog"],
            absentButtonTitles: ["Install plugin", "Adopt standard", "Accept catalog"],
            focusIdentifiers: ["shared-execution-refresh"],
            pressIdentifiers: ["shared-execution-refresh"],
            minimumElementSizes: ["shared-execution-refresh": .init(width: 44, height: 24)]
        )
        XCTAssertEqual(refreshCount, 1)
    }

    func testSharedExecutionCompatibilityCheckingDisablesRefresh() async throws {
        try await render(
            SharedExecutionCompatibilityView(
                documentationStatus: .checking(identity: nil, generation: 1),
                refresh: { XCTFail("Checking must disable duplicate refresh") }
            )
            .padding(24),
            name: "shared-execution-checking",
            width: 620,
            expected: nil,
            expectedText: ["Shared execution", "Checking compatibility", "Refresh compatibility"],
            disabledIdentifiers: ["shared-execution-refresh"]
        )
    }

    func testProjectNavigationStatusRendersCheckingAtWideAndCompactWidths() async throws {
        for (name, width, isCompact) in [("wide", 280.0, false), ("compact", 86.0, true)] {
            try await render(
                ProjectNavigationStatusView(
                    documentationStatus: .checking(identity: nil, generation: 1),
                    isCompact: isCompact
                )
                .padding(12),
                name: "project-navigation-checking-\(name)",
                width: width,
                expected: nil,
                expectedText: ["Checking project documentation"],
                presentIdentifiers: [
                    "project-documentation-checking",
                    "project-documentation-checking-progress",
                ]
            )
        }
    }

    private func compatibilityStatus(
        state: SharedExecutionCompatibilityState,
        directResults: [SharedExecutionDirectResult] = []
    ) -> DocumentationObservationStatus {
        let projectID = ProjectID(rawValue: "shared-execution-rendering")
        return .observed(.init(
            identity: .init(
                projectID: projectID,
                registration: nil,
                rootID: .init(rawValue: "shared-execution-rendering-root"),
                rootPath: "/Synthetic/SharedExecution",
                binding: nil
            ),
            generation: 1,
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            documentationState: .legacy(.unavailable),
            evidence: [],
            sharedExecutionCompatibility: .init(state: state, directResults: directResults)
        ))
    }

    private var states: [(String, ProjectDocumentationState)] {
        [
            ("v1-update", .legacy(.outdated(installed: 1, current: 3))),
            ("managed-current", .managed(hasAuditedHandoff: true, catalogVersion: 1, catalogDigest: "test-only")),
            ("managed-unavailable", .managedUnavailable(hasAuditedHandoff: true, reason: .catalogUnaccepted, validationError: nil))
        ]
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root], result: [String] = [], count = 0
        while let element = pending.popLast(), count < 1000 {
            count += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value = value as? String { result.append(value) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success, let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return result.joined(separator: "\n")
    }

    private func render<V: View>(
        _ view: V,
        name: String,
        width: Double,
        expected: ProjectGuidancePresentation?,
        expectedText: [String] = [],
        absentText: [String] = [],
        absentButtonTitles: [String] = [],
        presentIdentifiers: [String] = [],
        postActionIdentifiers: [String] = [],
        eventuallyPostActionIdentifiers: [String] = [],
        postActionVisibleIdentifiers: [String] = [],
        postActionText: [String] = [],
        postActionFocusedIdentifier: String? = nil,
        focusIdentifiers: [String] = [],
        disabledIdentifiers: [String] = [],
        pressIdentifiers: [String] = [],
        afterPressIdentifiers: [[String]] = [],
        afterPressFocusIdentifiers: [[String]] = [],
        afterPressText: [[String]] = [],
        pressTitles: [String] = [],
        minimumElementSizes: [String: CGSize] = [:],
        sheetAttachmentName: String? = nil,
        verifyAccessibility: @escaping (AXUIElement) throws -> Void = { _ in }
    ) async throws {
        let frame = NSRect(x: 30, y: 30, width: width, height: 850)
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = name
        let priorActivationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer { window.close(); NSApp.setActivationPolicy(priorActivationPolicy) }
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        hosting.layoutSubtreeIfNeeded()
        window.title = name
        if let seconds = ProcessInfo.processInfo.environment["RR_TASK7A_INSPECT_SECONDS"].flatMap(Double.init), seconds > 0 {
            print("Task 7A external inspection: \(name), \(Int(width))×850, PID \(ProcessInfo.processInfo.processIdentifier)")
            try await Task.sleep(for: .seconds(min(seconds, 60)))
        }
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value), .success)
        func matchesTestWindow(_ element: AXUIElement) -> Bool {
            var pid: pid_t = 0
            var title: CFTypeRef?
            var role: CFTypeRef?
            return AXUIElementGetPid(element, &pid) == .success
                && pid == ProcessInfo.processInfo.processIdentifier
                && AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success
                && (role as? String) == kAXWindowRole
                && AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success
                && (title as? String) == name
        }
        var ownWindow = (value as? [AXUIElement] ?? []).first(where: matchesTestWindow)
        // XCTest can expose its window through focused/main attributes while AXWindows is empty.
        if ownWindow == nil {
            for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
                var candidate: CFTypeRef?
                guard AXUIElementCopyAttributeValue(application, attribute as CFString, &candidate) == .success,
                      let candidate, CFGetTypeID(candidate) == AXUIElementGetTypeID() else { continue }
                let element = candidate as! AXUIElement
                if matchesTestWindow(element) {
                    ownWindow = element
                    break
                }
            }
        }
        let initialActual = accessibilityText(try XCTUnwrap(ownWindow))
        try verifyAccessibility(try XCTUnwrap(ownWindow))
        for identifier in presentIdentifiers {
            XCTAssertNotNil(
                accessibilityElement(try XCTUnwrap(ownWindow), identifier: identifier),
                "Missing accessibility element \(identifier)"
            )
        }
        for title in absentButtonTitles {
            XCTAssertNil(
                accessibilityButton(try XCTUnwrap(ownWindow), title: title),
                "Unexpected accessibility button titled \(title)"
            )
        }
        for focusIdentifier in focusIdentifiers {
            let element = try XCTUnwrap(
                accessibilityElement(try XCTUnwrap(ownWindow), identifier: focusIdentifier),
                "Missing accessibility element \(focusIdentifier)"
            )
            XCTAssertEqual(
                AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue),
                .success
            )
            var value: CFTypeRef?
            XCTAssertEqual(
                AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &value),
                .success
            )
            XCTAssertEqual(value as? Bool, true, "\(focusIdentifier) did not retain focus")
        }
        for disabledIdentifier in disabledIdentifiers {
            let element = try XCTUnwrap(
                accessibilityElement(try XCTUnwrap(ownWindow), identifier: disabledIdentifier),
                "Missing accessibility element \(disabledIdentifier)"
            )
            var value: CFTypeRef?
            XCTAssertEqual(
                AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value),
                .success
            )
            XCTAssertEqual(value as? Bool, false, "\(disabledIdentifier) must be disabled")
        }
        func waitForAccessibilityElement(identifier: String) async throws -> AXUIElement? {
            let deadline = Date().addingTimeInterval(2)
            repeat {
                hosting.layoutSubtreeIfNeeded()
                if let element = accessibilityElement(try XCTUnwrap(ownWindow), identifier: identifier) {
                    return element
                }
                try? await Task.sleep(for: .milliseconds(25))
            } while Date() < deadline
            return nil
        }
        for (index, pressIdentifier) in pressIdentifiers.enumerated() {
            let button = try XCTUnwrap(accessibilityElement(try XCTUnwrap(ownWindow), identifier: pressIdentifier))
            XCTAssertEqual(AXUIElementPerformAction(button, kAXPressAction as CFString), .success)
            try await Task.sleep(for: .milliseconds(300))
            for identifier in afterPressIdentifiers.indices.contains(index) ? afterPressIdentifiers[index] : [] {
                let element = try await waitForAccessibilityElement(identifier: identifier)
                XCTAssertNotNil(
                    element,
                    "Missing post-press accessibility element \(identifier)"
                )
            }
            for identifier in afterPressFocusIdentifiers.indices.contains(index) ? afterPressFocusIdentifiers[index] : [] {
                let candidate = try await waitForAccessibilityElement(identifier: identifier)
                let element = try XCTUnwrap(candidate, "Missing focusable post-press accessibility element \(identifier)")
                XCTAssertEqual(
                    AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue),
                    .success
                )
                var focusedValue: CFTypeRef?
                XCTAssertEqual(
                    AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &focusedValue),
                    .success
                )
                XCTAssertEqual(focusedValue as? Bool, true, "\(identifier) did not retain focus")
            }
            for text in afterPressText.indices.contains(index) ? afterPressText[index] : [] {
                XCTAssertTrue(
                    accessibilityText(try XCTUnwrap(ownWindow)).contains(text),
                    "Missing post-press lifecycle content: \(text)"
                )
            }
        }
        var captureView: NSView = hosting
        if let sheetAttachmentName {
            var sheet = try XCTUnwrap(window.sheets.first, "Manage Project sheet was not presented")
            while let nestedSheet = sheet.sheets.first {
                sheet = nestedSheet
            }
            let sheetContent = try XCTUnwrap(sheet.contentView, "Presented sheet has no content view")
            await Task.yield()
            sheetContent.layoutSubtreeIfNeeded()
            sheet.displayIfNeeded()
            sheetContent.displayIfNeeded()
            let bitmap = try XCTUnwrap(sheetContent.bitmapImageRepForCachingDisplay(in: sheetContent.bounds))
            sheetContent.cacheDisplay(in: sheetContent.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = sheetAttachmentName
            attachment.lifetime = .keepAlways
            add(attachment)
            if pressTitles.isEmpty {
                captureView = sheetContent
            }
        }
        for pressTitle in pressTitles {
            let button = try XCTUnwrap(
                accessibilityButton(try XCTUnwrap(ownWindow), title: pressTitle),
                "Missing accessibility button titled \(pressTitle)"
            )
            XCTAssertEqual(AXUIElementPerformAction(button, kAXPressAction as CFString), .success)
            try await Task.sleep(for: .milliseconds(300))
        }
        for identifier in postActionIdentifiers {
            XCTAssertNotNil(
                accessibilityElement(try XCTUnwrap(ownWindow), identifier: identifier),
                "Missing post-action accessibility element \(identifier)"
            )
        }
        for identifier in eventuallyPostActionIdentifiers {
            let element = try await waitForAccessibilityElement(identifier: identifier)
            XCTAssertNotNil(
                element,
                "Missing eventual post-action accessibility element \(identifier)"
            )
        }
        for identifier in postActionVisibleIdentifiers {
            let element = try XCTUnwrap(
                accessibilityElement(try XCTUnwrap(ownWindow), identifier: identifier),
                "Missing visible post-action accessibility element \(identifier)"
            )
            let elementFrame = try XCTUnwrap(accessibilityFrame(element))
            let windowFrame = try XCTUnwrap(accessibilityFrame(try XCTUnwrap(ownWindow)))
            XCTAssertTrue(
                windowFrame.intersects(elementFrame) && !windowFrame.intersection(elementFrame).isEmpty,
                "Post-action accessibility element \(identifier) is outside the visible window"
            )
        }
        let postActionActual = accessibilityText(try XCTUnwrap(ownWindow))
        for text in postActionText {
            XCTAssertTrue(postActionActual.contains(text), "Missing post-action text \(text)")
        }
        if let postActionFocusedIdentifier {
            let focusedElement = try XCTUnwrap(
                accessibilityElement(try XCTUnwrap(ownWindow), identifier: postActionFocusedIdentifier),
                "Missing focused post-action element \(postActionFocusedIdentifier)"
            )
            var focusedValue: CFTypeRef?
            XCTAssertEqual(
                AXUIElementCopyAttributeValue(focusedElement, kAXFocusedAttribute as CFString, &focusedValue),
                .success
            )
            XCTAssertEqual(focusedValue as? Bool, true)
        }
        let actual = accessibilityText(try XCTUnwrap(ownWindow))
        if let expected {
            XCTAssertTrue(
                initialActual.contains(expected.status) || actual.contains(expected.status),
                "Missing actual guidance status: \(expected.status)"
            )
        }
        for text in expectedText {
            XCTAssertTrue(actual.contains(text), "Missing actual lifecycle content: \(text)")
        }
        for text in absentText {
            XCTAssertFalse(actual.contains(text), "Unexpected lifecycle content: \(text)")
        }
        if name.contains("managed-unavailable") {
            XCTAssertTrue(actual.contains("catalog acceptance"), "Missing actual pending-catalog recovery")
            XCTAssertFalse(actual.contains("Copy setup prompt"))
            XCTAssertFalse(actual.contains("Copy repair prompt"))
        }
        if name.hasPrefix("m5-overview"), let action = expected?.actionTitle { XCTAssertTrue(actual.contains(action)) }
        for (identifier, minimumSize) in minimumElementSizes {
            let element = try XCTUnwrap(
                accessibilityElement(try XCTUnwrap(ownWindow), identifier: identifier),
                "Missing accessibility element \(identifier)"
            )
            var value: CFTypeRef?
            XCTAssertEqual(AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value), .success)
            var size = CGSize.zero
            let rawValue = try XCTUnwrap(value)
            XCTAssertEqual(CFGetTypeID(rawValue), AXValueGetTypeID())
            let axValue = rawValue as! AXValue
            XCTAssertTrue(AXValueGetValue(axValue, .cgSize, &size))
            XCTAssertGreaterThanOrEqual(size.width, minimumSize.width, "\(identifier) is too narrow")
            XCTAssertGreaterThanOrEqual(size.height, minimumSize.height, "\(identifier) is too short")
        }
        print("M5 isolated render PID \(ProcessInfo.processInfo.processIdentifier): actual AX status and recovery verified; capture \(name)")
        let bitmap = try XCTUnwrap(captureView.bitmapImageRepForCachingDisplay(in: captureView.bounds))
        captureView.cacheDisplay(in: captureView.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root], count = 0
        while let element = pending.popLast(), count < 1000 {
            count += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier {
                return element
            }
            var role: CFTypeRef?
            if ["project-health-reauthorize", "project-health-manage-roots"].contains(identifier),
               AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
               role as? String == kAXButtonRole {
                for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                    if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                       (value as? String)?.contains(identifier == "project-health-reauthorize" ? "Restore folder access" : "Manage Repository Roots") == true {
                        return element
                    }
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }

    private func accessibilityFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, CFGetTypeID(positionValue) == AXValueGetTypeID(),
              let sizeValue, CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func accessibilityButton(_ root: AXUIElement, title: String) -> AXUIElement? {
        var pending = [root], count = 0
        while let element = pending.popLast(), count < 1000 {
            count += 1
            var role: CFTypeRef?
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
               role as? String == kAXButtonRole {
                for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                    if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                       (value as? String)?.contains(title) == true {
                        return element
                    }
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }
}

import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class TicketLaneOrderingNativeAcceptanceTests: XCTestCase {
    func testPhaseBoardUsesFullLaneAnchorsAndSingleFlightPendingState() async throws {
        let nativeSession: (id: String, pauseSeconds: Double)?
        if let sessionID = ProcessInfo.processInfo.environment["RELEASE_RADAR_TICKET_ORDERING_NATIVE_SESSION"] {
            guard !sessionID.isEmpty,
                  sessionID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
                XCTFail("The ticket ordering native session must contain only letters, numbers, hyphens and underscores.")
                return
            }
            guard let pauseSeconds = ProcessInfo.processInfo.environment["RR_TICKET_ORDERING_INSPECT_SECONDS"]
                .flatMap(Double.init), pauseSeconds > 0 else {
                XCTFail("The ticket ordering native session requires a positive RR_TICKET_ORDERING_INSPECT_SECONDS value.")
                return
            }
            nativeSession = (sessionID, min(pauseSeconds, 60))
        } else {
            nativeSession = nil
        }

        let fixture = try await makeFixture()
        let selection = SelectionBox(fixture.target)
        let committedContext = TicketOrderingContext(
            projectID: fixture.projectID,
            digest: "committed-phase-order"
        )
        let probe = SuspendedOrderingProbe(reloadContext: committedContext)
        let host = try await host(
            PhaseBoardView(
                board: fixture.phaseBoard,
                selectedTicketID: selection.binding,
                filter: .constant(.unassigned),
                phaseSelectionStatus: .idle,
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                requestedFocus: .ticket(fixture.target),
                ticketOrderingContext: fixture.snapshot.context,
                ticketOrderingLanes: fixture.snapshot.lanes,
                reorderEligibleTicketIdentities: fixture.eligibleTicketIdentities,
                reorderTicket: { await probe.reorder($0, lane: $1, anchor: $2, context: $3) },
                reloadTicketOrdering: { await probe.reload() }
            ),
            title: nativeSession.map { "Ticket ordering phase pending — native session \($0.id)" }
                ?? "Ticket ordering phase pending"
        )
        defer { host.close() }

        if let nativeSession {
            func waitForStage(_ stage: String) async throws {
                let fileManager = FileManager.default
                let configurationPath = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]
                let configurationPresent = configurationPath != nil
                guard configurationPresent else {
                    XCTFail("The external ticket ordering journey requires the XCTest configuration environment key.")
                    throw NSError(domain: "TicketOrderingNativeSession", code: 1)
                }
                let configurationNonempty = configurationPath?.isEmpty == false
                let configurationExists = configurationPath.map {
                    !$0.isEmpty && fileManager.fileExists(atPath: $0)
                } ?? false
                let controlDirectory = fileManager.temporaryDirectory
                    .appendingPathComponent("release-radar-ticket-ordering", isDirectory: true)
                    .appendingPathComponent("native-\(nativeSession.id)", isDirectory: true)
                try fileManager.createDirectory(at: controlDirectory, withIntermediateDirectories: true)
                let ready = controlDirectory.appendingPathComponent("\(stage)-ready")
                let complete = controlDirectory.appendingPathComponent("\(stage)-complete")
                XCTAssertFalse(fileManager.fileExists(atPath: ready.path))
                XCTAssertFalse(fileManager.fileExists(atPath: complete.path))
                let identity = "token=\(nativeSession.id)\nstage=\(stage)\npid=\(ProcessInfo.processInfo.processIdentifier)\nwindow=\(host.title)\nxctest_configuration_present=\(configurationPresent)\nxctest_configuration_nonempty=\(configurationNonempty)\nxctest_configuration_exists=\(configurationExists)\n"
                XCTAssertTrue(fileManager.createFile(atPath: ready.path, contents: Data(identity.utf8)))
                print("TICKET ORDERING \(stage.uppercased()) READY: \(identity.replacingOccurrences(of: "\n", with: " "))")
                let attempts = max(1, Int((nativeSession.pauseSeconds * 5).rounded(.up)))
                for _ in 0..<attempts where !fileManager.fileExists(atPath: complete.path) {
                    try await Task.sleep(for: .milliseconds(200))
                }
                let completion = try String(contentsOf: complete, encoding: .utf8)
                XCTAssertEqual(completion.trimmingCharacters(in: .whitespacesAndNewlines), nativeSession.id)
            }

            try await waitForStage("initial-pending")
            try await waitUntil { await probe.invocationCount == 1 }
            let invocations = await probe.invocations
            let invocation = try XCTUnwrap(invocations.first)
            assertInvocation(
                invocation,
                target: fixture.target,
                lane: .backlog,
                anchor: .before(fixture.completedLeft),
                context: fixture.snapshot.context
            )
            XCTAssertEqual(invocations.count, 1)

            await probe.resolve(successResult(context: committedContext))
            try await waitUntil { await probe.reloadCount == 1 }
            try await waitForStage("committed-focus")
            XCTAssertEqual(selection.value, fixture.target)
            let invocationCount = await probe.invocationCount
            XCTAssertEqual(invocationCount, 1)
            return
        }

        var window = try requiredAccessibilityWindow(title: host.title)
        let earlierID = "move-ticket-earlier-\(fixture.target.rawValue)"
        let laterID = "move-ticket-later-\(fixture.target.rawValue)"
        let earlier = try XCTUnwrap(accessibilityElement(window, exactIdentifier: earlierID))
        XCTAssertNotNil(accessibilityElement(window, exactIdentifier: laterID))
        try press(earlier)

        try await waitUntil {
            let invocationCount = await probe.invocationCount
            let progressVisible = self.accessibilityElement(
                try self.requiredAccessibilityWindow(title: host.title),
                exactIdentifier: "ticket-ordering-progress"
            ) != nil
            return invocationCount == 1 && progressVisible
        }
        window = try requiredAccessibilityWindow(title: host.title)
        XCTAssertEqual(accessibilityBool(
            try XCTUnwrap(accessibilityElement(window, exactIdentifier: laterID)),
            kAXEnabledAttribute
        ), false)
        _ = AXUIElementPerformAction(
            try XCTUnwrap(accessibilityElement(window, exactIdentifier: laterID)),
            kAXPressAction as CFString
        )
        try await Task.sleep(for: .milliseconds(80))
        let pendingInvocationCount = await probe.invocationCount
        XCTAssertEqual(pendingInvocationCount, 1)
        XCTAssertEqual(visibleCardOrder(window, candidates: [fixture.target, fixture.phasePeer]), [
            Data(fixture.target.rawValue.utf8), Data(fixture.phasePeer.rawValue.utf8),
        ])

        let invocations = await probe.invocations
        let invocation = try XCTUnwrap(invocations.first)
        assertInvocation(
            invocation,
            target: fixture.target,
            lane: .backlog,
            anchor: .before(fixture.completedLeft),
            context: fixture.snapshot.context
        )
        await probe.resolve(successResult(context: committedContext))
        try await waitUntil {
            let reloadCount = await probe.reloadCount
            let progressHidden = self.accessibilityElement(
                try self.requiredAccessibilityWindow(title: host.title),
                exactIdentifier: "ticket-ordering-progress"
            ) == nil
            return reloadCount == 1 && progressHidden
        }

        window = try requiredAccessibilityWindow(title: host.title)
        XCTAssertEqual(selection.value, fixture.target)
        XCTAssertEqual(
            accessibilityBool(
                try XCTUnwrap(accessibilityElement(
                    window,
                    exactIdentifier: "ticket-\(fixture.target.rawValue)"
                )),
                kAXFocusedAttribute
            ),
            true
        )
        let invocationCount = await probe.invocationCount
        XCTAssertEqual(invocationCount, 1)
    }

    func testAllPhaseBoardUsesByteExactTargetAndHiddenAnchor() async throws {
        let fixture = try await makeFixture()
        XCTAssertEqual(fixture.composedTicket.rawValue, fixture.decomposedTicket.rawValue)
        XCTAssertNotEqual(
            Data(fixture.composedTicket.rawValue.utf8),
            Data(fixture.decomposedTicket.rawValue.utf8)
        )
        let selection = SelectionBox(fixture.decomposedTicket)
        let committedContext = TicketOrderingContext(
            projectID: fixture.projectID,
            digest: "committed-byte-order"
        )
        let probe = ScriptedOrderingProbe(
            result: successResult(context: committedContext),
            reloadResponses: [committedContext]
        )
        let host = try await host(
            AllPhaseBoardView(
                board: fixture.allPhaseBoard,
                selectedTicketID: selection.binding,
                filter: .constant(.goal(fixture.visibleGoal)),
                viewPhase: { _ in },
                requestedFocus: .ticket(fixture.decomposedTicket),
                ticketOrderingContext: fixture.snapshot.context,
                ticketOrderingLanes: fixture.snapshot.lanes,
                reorderEligibleTicketIdentities: fixture.eligibleTicketIdentities,
                reorderTicket: { await probe.reorder($0, lane: $1, anchor: $2, context: $3) },
                reloadTicketOrdering: { await probe.reload() }
            ),
            title: "Ticket ordering byte identity"
        )
        defer { host.close() }

        var window = try requiredAccessibilityWindow(title: host.title)
        XCTAssertNil(accessibilityElement(
            window,
            exactIdentifier: "ticket-\(fixture.composedTicket.rawValue)"
        ))
        let earlier = try XCTUnwrap(accessibilityElement(
            window,
            exactIdentifier: "move-ticket-earlier-\(fixture.decomposedTicket.rawValue)"
        ))
        try press(earlier)
        try await waitUntil {
            let invocationCount = await probe.invocationCount
            let reloadCount = await probe.reloadCount
            return invocationCount == 1 && reloadCount == 1
        }

        let invocations = await probe.invocations
        let invocation = try XCTUnwrap(invocations.first)
        assertInvocation(
            invocation,
            target: fixture.decomposedTicket,
            lane: .backlog,
            anchor: .before(fixture.composedTicket),
            context: fixture.snapshot.context
        )
        XCTAssertNotEqual(invocation.ticketID, Data(fixture.composedTicket.rawValue.utf8))
        XCTAssertEqual(invocations.count, 1)
        window = try requiredAccessibilityWindow(title: host.title)
        XCTAssertNotNil(accessibilityElement(
            window,
            exactIdentifier: "ticket-\(fixture.decomposedTicket.rawValue)"
        ))
        XCTAssertEqual(
            Data(selection.value.rawValue.utf8),
            Data(fixture.decomposedTicket.rawValue.utf8)
        )
    }

    func testStaleAndUnavailableFailuresOfferReloadWithoutRepeatingMutation() async throws {
        let fixture = try await makeFixture()
        let failures: [TicketOrderingError] = [
            .staleContext,
            .unavailable(.missingOrderRow(fixture.target)),
        ]
        for (index, failure) in failures.enumerated() {
            let probe = ScriptedOrderingProbe(
                result: failureResult(.ticketOrdering(failure)),
                reloadResponses: [fixture.snapshot.context]
            )
            let host = try await host(
                phaseView(fixture: fixture, probe: probe),
                title: "Ticket ordering recoverable failure \(index)"
            )
            defer { host.close() }

            var window = try requiredAccessibilityWindow(title: host.title)
            try press(try XCTUnwrap(accessibilityElement(
                window,
                exactIdentifier: "move-ticket-earlier-\(fixture.target.rawValue)"
            )))
            try await waitUntil {
                self.accessibilityElement(
                    try self.requiredAccessibilityWindow(title: host.title),
                    exactIdentifier: "failure-ticket-ordering"
                ) != nil
            }
            window = try requiredAccessibilityWindow(title: host.title)
            try press(try XCTUnwrap(accessibilityElement(
                window,
                exactIdentifier: "failure-ticket-ordering-action"
            )))
            try await waitUntil { await probe.reloadCount == 1 }
            let invocationCount = await probe.invocationCount
            XCTAssertEqual(invocationCount, 1)
        }
    }

    func testDependencyConflictShowsDetailedFailureWithoutRetry() async throws {
        let fixture = try await makeFixture()
        let prerequisite = TicketID(rawValue: "required-first")
        let dependent = TicketID(rawValue: "dependent-second")
        let conflict = TicketOrderingConflict(
            prerequisiteTicketID: prerequisite,
            dependentTicketID: dependent,
            witnessChain: [prerequisite, .init(rawValue: "hidden-middle"), dependent],
            lane: .backlog,
            prerequisitePhaseID: .init(rawValue: "phase-required"),
            prerequisitePhaseName: "Required phase",
            dependentPhaseID: .init(rawValue: "phase-dependent"),
            dependentPhaseName: "Dependent phase"
        )
        let probe = ScriptedOrderingProbe(
            result: failureResult(.ticketOrdering(.dependencyConflict(conflict))),
            reloadResponses: []
        )
        let host = try await host(
            phaseView(fixture: fixture, probe: probe),
            title: "Ticket ordering dependency failure"
        )
        defer { host.close() }

        var window = try requiredAccessibilityWindow(title: host.title)
        try press(try XCTUnwrap(accessibilityElement(
            window,
            exactIdentifier: "move-ticket-earlier-\(fixture.target.rawValue)"
        )))
        try await waitUntil {
            self.accessibilityElement(
                try self.requiredAccessibilityWindow(title: host.title),
                exactIdentifier: "failure-ticket-ordering"
            ) != nil
        }
        window = try requiredAccessibilityWindow(title: host.title)
        let text = accessibilityText(window)
        for expected in [
            prerequisite.rawValue, dependent.rawValue, "hidden-middle", "backlog",
            "Required phase", "Dependent phase",
        ] {
            XCTAssertTrue(text.contains(expected), "Missing typed dependency detail: \(expected)")
        }
        XCTAssertNil(accessibilityElement(window, exactIdentifier: "failure-ticket-ordering-action"))
        let invocationCount = await probe.invocationCount
        let reloadCount = await probe.reloadCount
        XCTAssertEqual(invocationCount, 1)
        XCTAssertEqual(reloadCount, 0)
    }

    func testCommittedMoveWithUnavailableOrMismatchedReloadNeverRepeatsMutation() async throws {
        let fixture = try await makeFixture()
        let committedContext = TicketOrderingContext(
            projectID: fixture.projectID,
            digest: "committed-needs-refresh"
        )
        let mismatchedContext = TicketOrderingContext(
            projectID: fixture.projectID,
            digest: "wrong-refresh"
        )
        for (index, firstReload) in [nil, mismatchedContext].enumerated() {
            let probe = ScriptedOrderingProbe(
                result: successResult(context: committedContext),
                reloadResponses: [firstReload, committedContext]
            )
            let host = try await host(
                phaseView(fixture: fixture, probe: probe),
                title: "Ticket ordering saved refresh \(index)"
            )
            defer { host.close() }

            var window = try requiredAccessibilityWindow(title: host.title)
            try press(try XCTUnwrap(accessibilityElement(
                window,
                exactIdentifier: "move-ticket-earlier-\(fixture.target.rawValue)"
            )))
            try await waitUntil {
                self.accessibilityElement(
                    try self.requiredAccessibilityWindow(title: host.title),
                    exactIdentifier: "ticket-ordering-saved-needs-reload"
                ) != nil
            }
            window = try requiredAccessibilityWindow(title: host.title)
            XCTAssertTrue(accessibilityText(window).contains(
                "Ticket order saved. Reload to show the committed sequence."
            ))
            XCTAssertEqual(visibleCardOrder(window, candidates: [fixture.target, fixture.phasePeer]), [
                Data(fixture.target.rawValue.utf8), Data(fixture.phasePeer.rawValue.utf8),
            ])
            try press(try XCTUnwrap(accessibilityButton(window, title: "Reload ordering")))
            try await waitUntil {
                let reloadCount = await probe.reloadCount
                let savedFailureHidden = self.accessibilityElement(
                    try self.requiredAccessibilityWindow(title: host.title),
                    exactIdentifier: "ticket-ordering-saved-needs-reload"
                ) == nil
                return reloadCount == 2 && savedFailureHidden
            }
            let invocationCount = await probe.invocationCount
            XCTAssertEqual(invocationCount, 1)
        }
    }

    func testAppModelReorderUsesAuthorizedOwnerBoundaryAndExactContext() async throws {
        let fixture = try await makeFixture()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true,
            seedSampleData: false
        )
        model.dashboard = fixture.dashboard

        let result = await model.reorderTicket(
            projectID: fixture.projectID,
            ticketID: fixture.phasePeer,
            expectedLane: .backlog,
            anchor: .before(fixture.target),
            expectedOrderingContext: fixture.snapshot.context
        )
        XCTAssertNil(result.error)
        let returnedContext = try XCTUnwrap(result.ticketOrderingContext)
        XCTAssertEqual(
            Data(returnedContext.projectID.rawValue.utf8),
            Data(fixture.projectID.rawValue.utf8)
        )

        let committed = try await fixture.store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: fixture.projectID, connection: $0)
        }
        XCTAssertEqual(returnedContext.digest, committed.context.digest)
        let backlog = committed.ticketIDs(in: .backlog).map { Data($0.rawValue.utf8) }
        let peerIndex = try XCTUnwrap(backlog.firstIndex(of: Data(fixture.phasePeer.rawValue.utf8)))
        let targetIndex = try XCTUnwrap(backlog.firstIndex(of: Data(fixture.target.rawValue.utf8)))
        XCTAssertEqual(peerIndex + 1, targetIndex)
        let requestCount = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
        }
        XCTAssertEqual(requestCount, 1)
    }

    private func phaseView(
        fixture: NativeOrderingFixture,
        probe: ScriptedOrderingProbe
    ) -> some View {
        PhaseBoardView(
            board: fixture.phaseBoard,
            selectedTicketID: .constant(fixture.target),
            filter: .constant(.unassigned),
            phaseSelectionStatus: .idle,
            selectActivePhase: { _ in },
            reloadActivePhase: {},
            reauthorizeActivePhase: { _ in },
            requestedFocus: .ticket(fixture.target),
            ticketOrderingContext: fixture.snapshot.context,
            ticketOrderingLanes: fixture.snapshot.lanes,
            reorderEligibleTicketIdentities: fixture.eligibleTicketIdentities,
            reorderTicket: { await probe.reorder($0, lane: $1, anchor: $2, context: $3) },
            reloadTicketOrdering: { await probe.reload() }
        )
    }

    private func makeFixture() async throws -> NativeOrderingFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-native-ordering-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let bookmarks = NativeOrderingBookmarkStore()
        let bookmark = try bookmarks.makeBookmark(for: projectRoot)
        let projectID = ProjectID(rawValue: "native-ordering-project")
        let openPhase = PhaseID(rawValue: "phase-open")
        let hiddenPhase = PhaseID(rawValue: "phase-hidden")
        let completedPhase = PhaseID(rawValue: "phase-completed")
        let target = TicketID(rawValue: "phase-target")
        let phasePeer = TicketID(rawValue: "phase-peer")
        let completedLeft = TicketID(rawValue: "completed-left")
        let completedRight = TicketID(rawValue: "completed-right")
        let composedTicket = TicketID(rawValue: "ticket-\u{e9}")
        let decomposedTicket = TicketID(rawValue: "ticket-e\u{301}")
        let bytePeer = TicketID(rawValue: "byte-peer")
        let visibleGoal = DeliveryGoalID(rawValue: "goal-visible")

        try await store.transact(actor: .init(id: "native-ordering-fixture"), reason: "Seed native ticket ordering") { connection in
            try connection.execute(
                "INSERT INTO projects (id,name,first_dashboard_opened) VALUES (?,?,1)",
                bindings: [.text(projectID.rawValue), .text("Native ordering")]
            )
            try connection.execute(
                "INSERT INTO project_roots (id,project_id,path) VALUES ('native-root',?,?)",
                bindings: [.text(projectID.rawValue), .text(projectRoot.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id,path,bookmark_data,is_stale) VALUES (?,?,?,0)",
                bindings: [.text(projectID.rawValue), .text(projectRoot.path), .blob(bookmark)]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES (?,'native-registration',1,'complete')",
                bindings: [.text(projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO phases (id,project_id,name) VALUES (?,?,?),(?,?,?),(?,?,?)",
                bindings: [
                    .text(openPhase.rawValue), .text(projectID.rawValue), .text("Open phase"),
                    .text(hiddenPhase.rawValue), .text(projectID.rawValue), .text("Hidden phase"),
                    .text(completedPhase.rawValue), .text(projectID.rawValue), .text("Completed phase"),
                ]
            )
            try connection.execute(
                "INSERT INTO project_active_phases (project_id,phase_id) VALUES (?,?)",
                bindings: [.text(projectID.rawValue), .text(openPhase.rawValue)]
            )
            try connection.execute(
                "UPDATE phase_lifecycles SET lifecycle='completed',revision=1,completion_baseline_digest=?,completed_at='2026-10-09T00:00:00Z',updated_at='2026-10-09T00:00:00Z' WHERE project_id=? AND phase_id=?",
                bindings: [
                    .text(String(repeating: "c", count: 64)),
                    .text(projectID.rawValue), .text(completedPhase.rawValue),
                ]
            )
            let tickets: [(TicketID, PhaseID, String)] = [
                (completedLeft, completedPhase, "Completed left anchor"),
                (target, openPhase, "Visible phase target"),
                (completedRight, completedPhase, "Completed right anchor"),
                (phasePeer, openPhase, "Visible phase peer"),
                (composedTicket, hiddenPhase, "Hidden composed ticket"),
                (decomposedTicket, openPhase, "Visible decomposed ticket"),
                (bytePeer, openPhase, "Visible byte peer"),
            ]
            for (ticket, phase, outcome) in tickets {
                try connection.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,?,?,?, 'backlog')",
                    bindings: [
                        .text(ticket.rawValue), .text(projectID.rawValue),
                        .text(phase.rawValue), .text(outcome),
                    ]
                )
            }
            try connection.execute(
                "INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES (?,?,?,'Visible goal','Visible byte path','draft',0,'2026-10-09T00:00:00Z','2026-10-09T00:00:00Z'),(?,?,'goal-hidden','Hidden goal','Hidden byte path','draft',1,'2026-10-09T00:00:00Z','2026-10-09T00:00:00Z')",
                bindings: [
                    .text(projectID.rawValue), .text(openPhase.rawValue), .text(visibleGoal.rawValue),
                    .text(projectID.rawValue), .text(hiddenPhase.rawValue),
                ]
            )
            try connection.execute(
                "INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES (?,?,?,?),(?,?,'goal-hidden',?),(?,?,?,?)",
                bindings: [
                    .text(projectID.rawValue), .text(openPhase.rawValue),
                    .text(visibleGoal.rawValue), .text(decomposedTicket.rawValue),
                    .text(projectID.rawValue), .text(hiddenPhase.rawValue), .text(composedTicket.rawValue),
                    .text(projectID.rawValue), .text(openPhase.rawValue),
                    .text(visibleGoal.rawValue), .text(bytePeer.rawValue),
                ]
            )
            try connection.execute(
                "DELETE FROM ticket_lane_order WHERE project_id=?",
                bindings: [.text(projectID.rawValue)]
            )
            for (index, ticket) in tickets.map(\.0).enumerated() {
                let binary = String(index, radix: 2)
                let key = String(repeating: "0", count: 3 - binary.count) + binary + "1"
                try connection.execute(
                    "INSERT INTO ticket_lane_order (project_id,ticket_id,lane,order_key) VALUES (?,?,'backlog',?)",
                    bindings: [.text(projectID.rawValue), .text(ticket.rawValue), .text(key)]
                )
            }
        }

        let dashboard = try await DashboardProjection.load(from: store, bookmarkStore: bookmarks)
        let snapshot = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: projectID, connection: $0)
        }
        let phaseBoard = try XCTUnwrap(dashboard.board(for: projectID, phaseID: openPhase))
        let allPhaseBoard = try XCTUnwrap(dashboard.allPhaseBoard(for: projectID))
        let eligible = [target, phasePeer, composedTicket, decomposedTicket, bytePeer]
            .map { Data($0.rawValue.utf8) }
        return NativeOrderingFixture(
            store: store,
            onboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks),
            dashboard: dashboard,
            snapshot: snapshot,
            phaseBoard: phaseBoard,
            allPhaseBoard: allPhaseBoard,
            eligibleTicketIdentities: eligible,
            projectID: projectID,
            target: target,
            phasePeer: phasePeer,
            completedLeft: completedLeft,
            composedTicket: composedTicket,
            decomposedTicket: decomposedTicket,
            visibleGoal: visibleGoal
        )
    }

    private func host<V: View>(_ view: V, title: String) async throws -> NativeOrderingHost {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = title
        window.appearance = NSAppearance(named: .darkAqua)
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        hosting.appearance = window.appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(250))
        hosting.layoutSubtreeIfNeeded()
        return NativeOrderingHost(
            window: window,
            contentView: hosting,
            title: title,
            previousPolicy: previousPolicy
        )
    }

    private func requiredAccessibilityWindow(title: String) throws -> AXUIElement {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success,
        let windows = value as? [AXUIElement],
        let window = windows.first(where: {
            accessibilityAttribute($0, kAXTitleAttribute) == title
        }) else {
            throw XCTSkip("The XCTest host exposed no self-accessibility window for native ticket ordering.")
        }
        return window
    }

    private func accessibilityElement(
        _ root: AXUIElement,
        exactIdentifier identifier: String
    ) -> AXUIElement? {
        let expected = Data(identifier.utf8)
        return accessibilityElements(root).first {
            accessibilityAttribute($0, kAXIdentifierAttribute).map { Data($0.utf8) } == expected
        }
    }

    private func accessibilityButton(_ root: AXUIElement, title: String) -> AXUIElement? {
        accessibilityElements(root).first {
            accessibilityAttribute($0, kAXRoleAttribute) == (kAXButtonRole as String)
                && accessibilityAttribute($0, kAXTitleAttribute) == title
        }
    }

    private func accessibilityElements(_ root: AXUIElement) -> [AXUIElement] {
        var pending = [root]
        var result: [AXUIElement] = []
        while !pending.isEmpty, result.count < 3_000 {
            let element = pending.removeFirst()
            result.append(element)
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element,
                kAXChildrenAttribute as CFString,
                &children
            ) == .success,
            let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return result
    }

    private func accessibilityAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return value as? String
    }

    private func accessibilityBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return value as? Bool
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        accessibilityElements(root).flatMap { element in
            [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute]
                .compactMap { accessibilityAttribute(element, $0) }
        }.joined(separator: "\n")
    }

    private func visibleCardOrder(
        _ root: AXUIElement,
        candidates: [TicketID]
    ) -> [Data] {
        let candidateIDs = candidates.map { Data("ticket-\($0.rawValue)".utf8) }
        return accessibilityElements(root).compactMap { element in
            guard let identifier = accessibilityAttribute(element, kAXIdentifierAttribute) else {
                return nil
            }
            let identity = Data(identifier.utf8)
            guard let index = candidateIDs.firstIndex(of: identity) else { return nil }
            return Data(candidates[index].rawValue.utf8)
        }
    }

    private func press(_ element: AXUIElement) throws {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard result == .success else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result.rawValue))
        }
    }

    private func waitUntil(
        timeout: Duration = .seconds(3),
        _ condition: @escaping @MainActor () async throws -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(40))
        }
        XCTFail("Timed out waiting for native ticket-ordering state")
    }

    private func assertInvocation(
        _ invocation: NativeOrderingInvocation,
        target: TicketID,
        lane: TicketLane,
        anchor: TicketOrderAnchor,
        context: TicketOrderingContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(invocation.ticketID, Data(target.rawValue.utf8), file: file, line: line)
        XCTAssertEqual(invocation.lane, lane, file: file, line: line)
        assertAnchor(invocation.anchor, equals: anchor, file: file, line: line)
        XCTAssertEqual(
            Data(invocation.context.projectID.rawValue.utf8),
            Data(context.projectID.rawValue.utf8),
            file: file,
            line: line
        )
        XCTAssertEqual(invocation.context.digest, context.digest, file: file, line: line)
    }

    private func assertAnchor(
        _ actual: TicketOrderAnchor,
        equals expected: TicketOrderAnchor,
        file: StaticString,
        line: UInt
    ) {
        switch (actual, expected) {
        case let (.before(actualID), .before(expectedID)),
             let (.after(actualID), .after(expectedID)):
            XCTAssertEqual(
                Data(actualID.rawValue.utf8),
                Data(expectedID.rawValue.utf8),
                file: file,
                line: line
            )
        default:
            XCTFail("Ticket ordering anchor direction changed", file: file, line: line)
        }
    }
}

private struct NativeOrderingFixture {
    let store: DeliveryStore
    let onboarding: FolderProjectOnboarding
    let dashboard: DashboardProjection
    let snapshot: TicketOrderingSnapshot
    let phaseBoard: PhaseBoardProjection
    let allPhaseBoard: AllPhaseBoardProjection
    let eligibleTicketIdentities: [Data]
    let projectID: ProjectID
    let target: TicketID
    let phasePeer: TicketID
    let completedLeft: TicketID
    let composedTicket: TicketID
    let decomposedTicket: TicketID
    let visibleGoal: DeliveryGoalID
}

@MainActor
private final class SelectionBox {
    var value: TicketID

    init(_ value: TicketID) {
        self.value = value
    }

    var binding: Binding<TicketID> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

@MainActor
private struct NativeOrderingHost {
    let window: NSWindow
    let contentView: NSView
    let title: String
    let previousPolicy: NSApplication.ActivationPolicy

    func close() {
        window.close()
        NSApp.setActivationPolicy(previousPolicy)
    }
}

private struct NativeOrderingInvocation: Sendable {
    let ticketID: Data
    let lane: TicketLane
    let anchor: TicketOrderAnchor
    let context: TicketOrderingContext
}

private actor SuspendedOrderingProbe {
    private(set) var invocations: [NativeOrderingInvocation] = []
    private(set) var reloadCount = 0
    private let reloadContext: TicketOrderingContext
    private var continuation: CheckedContinuation<AgentCommandResult, Never>?

    init(reloadContext: TicketOrderingContext) {
        self.reloadContext = reloadContext
    }

    var invocationCount: Int { invocations.count }

    func reorder(
        _ ticketID: TicketID,
        lane: TicketLane,
        anchor: TicketOrderAnchor,
        context: TicketOrderingContext
    ) async -> AgentCommandResult {
        invocations.append(.init(
            ticketID: Data(ticketID.rawValue.utf8),
            lane: lane,
            anchor: anchor,
            context: context
        ))
        return await withCheckedContinuation { continuation = $0 }
    }

    func reload() -> TicketOrderingContext? {
        reloadCount += 1
        return reloadContext
    }

    func resolve(_ result: AgentCommandResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private actor ScriptedOrderingProbe {
    private(set) var invocations: [NativeOrderingInvocation] = []
    private(set) var reloadCount = 0
    private let result: AgentCommandResult
    private var reloadResponses: [TicketOrderingContext?]

    init(result: AgentCommandResult, reloadResponses: [TicketOrderingContext?]) {
        self.result = result
        self.reloadResponses = reloadResponses
    }

    var invocationCount: Int { invocations.count }

    func reorder(
        _ ticketID: TicketID,
        lane: TicketLane,
        anchor: TicketOrderAnchor,
        context: TicketOrderingContext
    ) -> AgentCommandResult {
        invocations.append(.init(
            ticketID: Data(ticketID.rawValue.utf8),
            lane: lane,
            anchor: anchor,
            context: context
        ))
        return result
    }

    func reload() -> TicketOrderingContext? {
        reloadCount += 1
        guard !reloadResponses.isEmpty else { return nil }
        return reloadResponses.removeFirst()
    }
}

private struct NativeOrderingBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.resolvingSymlinksInPath().path.utf8)
    }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(
            url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)),
            isStale: false
        )
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        try await body(resolve(bookmark))
    }
}

private func successResult(context: TicketOrderingContext) -> AgentCommandResult {
    .init(
        entityIDs: [],
        auditEventID: .init(rawValue: "native-ordering-audit"),
        error: nil,
        ticketOrderingContext: context
    )
}

private func failureResult(_ error: AgentCommandError) -> AgentCommandResult {
    .init(entityIDs: [], auditEventID: nil, error: error)
}

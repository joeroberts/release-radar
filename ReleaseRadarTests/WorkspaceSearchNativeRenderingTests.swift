import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class WorkspaceSearchNativeRenderingTests: XCTestCase {
    func testSearchAndHelpTextFieldsUseThePinnedRDSQuietFieldTreatment() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let searchSource = try String(
            contentsOf: repositoryRoot.appending(path: "ReleaseRadar/Search/WorkspaceSearchView.swift"),
            encoding: .utf8
        )
        let helpSource = try String(
            contentsOf: repositoryRoot.appending(path: "ReleaseRadar/Help/WorkspaceHelpView.swift"),
            encoding: .utf8
        )
        let toolbarSource = try String(
            contentsOf: repositoryRoot.appending(path: "ReleaseRadar/Navigation/WorkspaceToolbar.swift"),
            encoding: .utf8
        )

        XCTAssertEqual(searchSource.components(separatedBy: ".textFieldStyle(RekonQuietTextFieldStyle())").count - 1, 0)
        XCTAssertEqual(helpSource.components(separatedBy: ".textFieldStyle(RekonQuietTextFieldStyle())").count - 1, 1)
        XCTAssertEqual(toolbarSource.components(separatedBy: ".textFieldStyle(RekonQuietTextFieldStyle())").count - 1, 1)
        XCTAssertTrue(toolbarSource.contains("RekonSearchField("))
        XCTAssertTrue(toolbarSource.contains("HStack(spacing: RekonTheme.Spacing.micro) {\n                searchField\n                saveButton\n            }"))
        XCTAssertFalse(toolbarSource.contains("Button(\"Save query\")"))
        XCTAssertFalse(searchSource.contains(".textFieldStyle(.roundedBorder)"))
        XCTAssertFalse(helpSource.contains(".textFieldStyle(.roundedBorder)"))
    }

    func testSearchAndHelpTextFieldsRenderWithPinnedRDSTreatmentInInertHost() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchRDSRender-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            externalServicesSuppressed: true,
            seedSampleData: false
        )
        await model.loadDashboard()
        await model.navigate(to: .search)

        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(x: 0, y: 0, width: 1_500, height: 900)
        try await settle(hosting)
        try capture(hosting, name: "search-rds-quiet-fields")

        await model.navigate(to: .help)
        try await settle(hosting)
        try capture(hosting, name: "help-rds-quiet-field")
    }

    func testSearchRecoveryControlsAndSharedHelpContentAreNativeAndActionable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchRecoveryNative-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "native-recovery-project")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed native Search recovery") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Native recovery project')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'native-registration-before', 1, 'complete')", bindings: [.text(projectID.rawValue)])
        }
        let repository = WorkspaceSearchPreferencesRepository(store: store)
        let saved = try await repository.saveQuery(
            id: "native-restored-query",
            name: "Restored native query",
            definition: .init(
                text: "Native recovery",
                scope: .registrations([.init(projectID: projectID, registrationID: "native-registration-before")]),
                domains: [.project]
            )
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Rotate native Search recovery") { connection in
            try connection.execute("UPDATE application_recovery_state SET incarnation_id = '22222222-2222-4222-8222-222222222222' WHERE singleton_id = 1")
            try connection.execute("UPDATE project_registrations SET registration_id = 'native-registration-after' WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
            try connection.execute(
                "INSERT INTO workspace_search_preferences (singleton_id, payload_version, payload_data, updated_at) VALUES (1, 99, ?, '2026-09-10T12:00:00Z') ON CONFLICT(singleton_id) DO UPDATE SET payload_version = 99, payload_data = excluded.payload_data, updated_at = excluded.updated_at",
                bindings: [.blob(Data("future-working-query".utf8))]
            )
        }

        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.loadWorkspaceSearchPreferences(runSearch: false)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_000, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        let token = ProcessInfo.processInfo.environment["RR_PHASE6E_NATIVE_SESSION"]
        window.title = token.map { "Phase 6E Search recovery — focused native acceptance — \($0)" }
            ?? "Phase 6E Search recovery — focused native acceptance"
        defer { window.close() }
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.appearance = window.appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        try await settle(hosting)
        await model.navigate(to: .search)
        try await settle(hosting)
        if let token {
            print("PHASE6E SEARCH RECOVERY READY: inspect the isolated unsupported search warning and recovery controls before marking the session complete")
            try await waitForExternalNativeJourney(token: token, window: window)
        }
        var nativeWindow = try requiredAccessibilityWindow(title: window.title)
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Saved working search needs a newer Release Radar"))
        let runButton = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-run"))
        let saveButton = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-save"))
        XCTAssertEqual(accessibilityBool(runButton, kAXEnabledAttribute), false)
        XCTAssertEqual(accessibilityBool(saveButton, kAXEnabledAttribute), false)
        try press(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-reset-unsupported")))
        try await settle(hosting)
        nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        XCTAssertFalse(model.workspaceSearchPreferenceIsUnsupported)
        XCTAssertEqual(
            accessibilityBool(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-run")), kAXEnabledAttribute),
            true
        )
        XCTAssertEqual(
            accessibilityBool(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-save")), kAXEnabledAttribute),
            true
        )
        let opaqueVersion = try await store.read {
            try $0.scalarInt("SELECT payload_version FROM workspace_search_preferences WHERE singleton_id = 1")
        }
        XCTAssertEqual(opaqueVersion, 99)
        try capture(hosting, name: "phase6e-search-unsupported-reset")

        await model.loadWorkspaceSavedQuery(.supported(saved))
        try await settle(hosting)
        nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        XCTAssertTrue(model.workspaceSearchNeedsScopeReselection)
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Search unavailable"))
        XCTAssertEqual(model.workspaceSearchDefinition.scope, saved.definition.scope)
        XCTAssertEqual(accessibilityBool(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-run")), kAXEnabledAttribute), false)
        XCTAssertEqual(accessibilityBool(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-save")), kAXEnabledAttribute), false)
        try press(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-scope-all-recovery")))
        try await settle(hosting)
        XCTAssertEqual(model.workspaceSearchDefinition.scope, .allAuthorized)
        XCTAssertFalse(model.workspaceSearchNeedsScopeReselection)

        await model.loadWorkspaceSavedQuery(.supported(saved))
        try await settle(hosting)
        nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        try press(try XCTUnwrap(accessibilityElement(
            nativeWindow,
            identifier: "workspace-search-scope-project-recovery-native-registration-after"
        )))
        try await settle(hosting)
        XCTAssertEqual(
            model.workspaceSearchDefinition.scope,
            .registrations([.init(projectID: projectID, registrationID: "native-registration-after")])
        )
        XCTAssertFalse(model.workspaceSearchNeedsScopeReselection)
        XCTAssertEqual(accessibilityBool(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-run")), kAXEnabledAttribute), true)
        XCTAssertEqual(accessibilityBool(try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-save")), kAXEnabledAttribute), true)
        try capture(hosting, name: "phase6e-search-exact-rescope")

        await model.navigate(to: .help)
        try await settle(hosting)
        nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-search-field"))
        XCTAssertTrue(accessibilityText(nativeWindow).contains(WorkspaceHelpContent.deliveryEvidenceBoundary))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-action-readiness-acceptance"))
        try capture(hosting, name: "phase6e-help-recovery-guidance")
    }

    func testSearchNoMatchStateRendersNatively() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchStateNative-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed native Search state fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('native-state-project', 'Native state project')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('native-state-project', 'native-state-registration', 1, 'complete')")
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .search)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        let token = ProcessInfo.processInfo.environment["RR_PHASE6E_NATIVE_SESSION"]
        window.title = token.map { "Phase 6E Search no-match — isolated native acceptance — \($0)" }
            ?? "Phase 6E Search no-match — isolated native acceptance"
        defer { window.close() }
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.appearance = window.appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        model.setWorkspaceSearchText("absent-native-state")
        await model.runWorkspaceSearch()
        try await settle(hosting)
        if let token {
            print("PHASE6E SEARCH NO-MATCH READY: inspect the isolated committed no-match display before marking the session complete")
            try await waitForExternalNativeJourney(token: token, window: window)
        }
        var nativeWindow = try requiredAccessibilityWindow(title: window.title)
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-empty"))
        XCTAssertFalse(model.workspaceSearchIsLoading)
        XCTAssertNotNil(model.workspaceSearchProjection)

    }

    func testSearchSavedViewsAndHelpRenderWideAndCompact() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchNative-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let longTicketTitle = "Retired result with deliberately extended factual context that must remain readable across several compact lines, including the recorded retirement state and exact work identity, before reaching the late native-detail match phrase."
        try await store.transact(
            actor: .init(id: "search-native-test"),
            reason: "Seed native-detail mixed-domain Search fixture",
            auditEventID: .init(rawValue: "native-detail-audit"),
            auditScope: .init(projectID: projectID, entityType: .ticket, entityID: "native-detail-ticket")
        ) { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'search-native-registration', 1, 'complete')",
                bindings: [.text(projectID.rawValue)]
            )
            try connection.execute("UPDATE projects SET name = 'Native-detail project with a deliberately long factual identity' WHERE id = ?", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('native-detail-phase', ?, 'Native detail phase')", bindings: [.text(projectID.rawValue)])
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('native-detail-ticket', ?, 'native-detail-phase', ?, 'accepted')",
                bindings: [.text(projectID.rawValue), .text(longTicketTitle)]
            )
            try connection.execute("INSERT INTO ticket_retirements (project_id, ticket_id, disposition, reason, last_phase_id, last_lane, audit_event_id, retired_at) VALUES (?, 'native-detail-ticket', 'replaced', 'Native detail retirement', 'native-detail-phase', 'accepted', 'native-detail-audit', '2026-10-09T00:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES (?, 'native-detail-phase', 'native-detail-delivery', 'Delivery result', 'Long delivery outcome for native detail inspection', 'draft', 0, '2026-10-09T00:00:00Z', '2026-10-09T00:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('native-detail-thread', ?, 'completed', '2026-10-09T00:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('native-detail-execution', ?, 'native-detail-thread', 'Completed', 'Long execution context for native detail inspection', '2026-10-09T00:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('native-detail-review', ?, 'native-detail-ticket', 'completion', 'Long review history context for native detail inspection', 'resolved')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES ('native-detail-completion', ?, 'native-detail-ticket', 'Long completion context for native detail inspection', '2026-10-09T00:01:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO notification_events (id, fingerprint, state, ticket_id, project_id, title, message, created_at) VALUES ('native-detail-notification', 'native-detail-notification-fingerprint', 'delivered', 'native-detail-ticket', ?, 'Native detail notification', 'Long notification context for native detail inspection', '2026-10-09T00:02:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO ticket_reference_link_sets (project_id, ticket_id, revision, created_at, updated_at) VALUES (?, 'native-detail-ticket', 1, '2026-10-09T00:00:00Z', '2026-10-09T00:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO ticket_reference_links (project_id, ticket_id, id, kind, repository_id, artifact_id, current_version, relationship, created_at, updated_at) VALUES (?, 'native-detail-ticket', 'native-detail-decision-link', 'decision', '11111111-1111-4111-8111-111111111111', 'native-detail-artifact', 1, 'current', '2026-10-09T00:00:00Z', '2026-10-09T00:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO ticket_reference_versions (project_id, ticket_id, link_id, version, content_digest, source_local_id, locator, catalog_version, catalog_digest, observed_path, observed_lifecycle, observed_authority, created_at) VALUES (?, 'native-detail-ticket', 'native-detail-decision-link', 1, ?, 'NATIVE-DETAIL-DECISION', 'Native detail decision heading', 1, ?, 'docs/native-detail-decision.md', 'active', 'controlling', '2026-10-09T00:00:00Z')", bindings: [.text(projectID.rawValue), .text(String(repeating: "a", count: 64)), .text(String(repeating: "b", count: 64))])
        }
        let repository = WorkspaceSearchPreferencesRepository(store: store)
        let savedDefinition = WorkspaceSearchDefinition(
            text: "native-detail",
            scope: .allAuthorized,
            domains: Set(WorkspaceSearchDomain.allCases),
            sort: .domainThenTitle
        )
        _ = try await repository.saveQuery(id: "native-ticket", name: "Mixed record review", definition: savedDefinition)
        _ = try await repository.saveQuery(id: "native-newer", name: "Future filters", definition: savedDefinition)
        try await store.transact(actor: .init(id: "search-native-test"), reason: "Seed recoverable newer-version Search state") { connection in
            try connection.execute(
                "UPDATE workspace_saved_queries SET payload_version = 99, payload_data = ? WHERE id = 'native-newer'",
                bindings: [.blob(Data("future-saved-query".utf8))]
            )
        }

        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .search)
        model.setWorkspaceSearchText(savedDefinition.text)
        model.setWorkspaceSearchSort(.domainThenTitle)
        await model.runWorkspaceSearch()
        await model.loadWorkspaceSearchPreferences(runSearch: false)
        await model.navigate(to: .projects)
        let results = try XCTUnwrap(model.workspaceSearchProjection?.results)
        XCTAssertEqual(Set(results.map(\.domain)), Set(WorkspaceSearchDomain.allCases))
        let result = try XCTUnwrap(results.first {
            guard case let .ticket(_, _, ticketID, _) = $0.identity else { return false }
            return ticketID.rawValue == "native-detail-ticket"
        })
        XCTAssertEqual(result.title, longTicketTitle)
        model.selectWorkspaceSearchResult(result.id)
        model.setWorkspaceSearchViewportOffset(42)
        try await store.transact(actor: .init(id: "search-native-test"), reason: "Seed recoverable newer-version working Search state") { connection in
            try connection.execute(
                "UPDATE workspace_search_preferences SET payload_version = 99, payload_data = ? WHERE singleton_id = 1",
                bindings: [.blob(Data("future-working-query".utf8))]
            )
        }
        await model.loadWorkspaceSearchPreferences(runSearch: false)

        let activePhaseBefore = try await activePhase(in: store, projectID: projectID)
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        let token = ProcessInfo.processInfo.environment["RR_PHASE6E_NATIVE_SESSION"]
        window.title = token.map { "Phase 6E Search — isolated native acceptance — \($0)" }
            ?? "Phase 6E Search — isolated native acceptance"
        defer { window.close() }
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.appearance = window.appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await settle(hosting)
        await model.navigate(to: .search)
        try await settle(hosting)

        if let token {
            for width in [1_500.0, 760.0] {
                window.setContentSize(NSSize(width: width, height: 900))
                hosting.frame = window.contentView?.bounds ?? .zero
                try await Task.sleep(for: .milliseconds(250))
                hosting.layoutSubtreeIfNeeded()
                let widthToken = "\(token)-\(Int(width))"
                print("PHASE6E SEARCH \(Int(width)) READY: visually inspect the exact-width surface and screenshot for clipping; inspect all six result domains and the selected retired middle Ticket; verify the selected Ticket title wraps through the late native-detail match phrase, unique-project rows omit Registration search-native-registration, full factual detail/source-specific dates, compact row-detail-row order, selected AX state, Up/Down plus Return/Space row behavior, Tab/Shift-Tab/Escape focus, exact-record Open/Back restoration, and truthful actions before marking this exact-width session complete")
                try await waitForExternalNativeJourney(token: widthToken, window: window)
            }
        }

        for width in [1_500.0, 760.0] {
            window.setContentSize(NSSize(width: width, height: 900))
            hosting.frame = window.contentView?.bounds ?? .zero
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()
            let nativeWindow = try requiredAccessibilityWindow(title: window.title)
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-field"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-filters"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-detail"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-saved-query-native-ticket"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-saved-query-native-newer"))
            XCTAssertTrue(accessibilityText(nativeWindow).contains("Newer version"))
            if token != nil {
                XCTAssertTrue(accessibilityText(nativeWindow).contains(longTicketTitle))
                XCTAssertFalse(accessibilityText(nativeWindow).contains("Registration search-native-registration"))
            }
            try capture(hosting, name: "phase6e-search-\(Int(width))")
        }

        await model.navigate(to: .help)
        for width in [1_500.0, 760.0] {
            window.setContentSize(NSSize(width: width, height: 900))
            hosting.frame = window.contentView?.bounds ?? .zero
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()
            let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-help"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-search-field"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-action-saved-query-recovery"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-action-search-navigation"))
            try capture(hosting, name: "phase6e-help-\(Int(width))")
        }
        await model.goBack()
        window.setContentSize(NSSize(width: 1_500, height: 900))
        hosting.frame = window.contentView?.bounds ?? .zero
        try await Task.sleep(for: .milliseconds(250))
        hosting.layoutSubtreeIfNeeded()

        let activePhaseAfter = try await activePhase(in: store, projectID: projectID)
        XCTAssertEqual(activePhaseAfter, activePhaseBefore)
        XCTAssertNil(model.dashboardError)
    }

    func testSameNameProjectRegistrationsRemainDistinctAcrossCompactSearchPresentation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchRegistrationLabels-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let firstProjectID = ProjectID(rawValue: "same-name-project-a")
        let secondProjectID = ProjectID(rawValue: "same-name-project-b")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed same-name Search projects") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name) VALUES (?, 'Same name project'), (?, 'Same name project')",
                bindings: [.text(firstProjectID.rawValue), .text(secondProjectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'same-name-registration-before', 1, 'complete'), (?, 'same-name-registration-b', 1, 'complete')",
                bindings: [.text(firstProjectID.rawValue), .text(secondProjectID.rawValue)]
            )
        }
        let repository = WorkspaceSearchPreferencesRepository(store: store)
        let saved = try await repository.saveQuery(
            id: "same-name-saved",
            name: "Same-name recovery",
            definition: .init(
                text: "Same name project",
                scope: .registrations([.init(
                    projectID: firstProjectID,
                    registrationID: "same-name-registration-before"
                )]),
                domains: [.project]
            )
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Rotate same-name Search registration") { connection in
            try connection.execute(
                "UPDATE project_registrations SET registration_id = 'same-name-registration-a' WHERE project_id = ?",
                bindings: [.text(firstProjectID.rawValue)]
            )
        }

        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.loadWorkspaceSavedQuery(.supported(saved))
        XCTAssertTrue(model.workspaceSearchNeedsScopeReselection)
        await model.navigate(to: .projects)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        let token = ProcessInfo.processInfo.environment["RR_PHASE6E_NATIVE_SESSION"]
        window.title = token.map { "Phase 6E same-name registration presentation — \($0)" }
            ?? "Phase 6E same-name registration presentation"
        defer { window.close() }
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.appearance = window.appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await settle(hosting)
        await model.navigate(to: .search)
        try await settle(hosting)

        let nativeWindow = try requiredAccessibilityWindow(title: window.title)
        for registrationID in ["same-name-registration-a", "same-name-registration-b"] {
            let recovery = try XCTUnwrap(accessibilityElement(
                nativeWindow,
                identifier: "workspace-search-scope-project-recovery-\(registrationID)"
            ))
            XCTAssertTrue(accessibilityText(recovery).contains(registrationID))
        }
        try capture(hosting, name: "phase6e-search-same-name-recovery-wide")
        if let token {
            for width in [1_500.0, 760.0] {
                window.setContentSize(NSSize(width: width, height: 900))
                hosting.frame = window.contentView?.bounds ?? .zero
                try await Task.sleep(for: .milliseconds(250))
                hosting.layoutSubtreeIfNeeded()
                let widthToken = "\(token)-\(Int(width))"
                print("PHASE6E SAME-NAME SEARCH \(Int(width)) READY: inspect both recovery labels, choose all authorized projects and run the existing project-only query if still needed; at 1500 verify otherwise-identical project rows retain distinct Registration values, at 760 verify compact rows use name/lifecycle without Registration while selected detail retains exact project/registration identity; use Up/Down and Return/Space across both rows, inspect the selected detail/action and scope-menu choices, and visually inspect this exact-width surface for clipping")
                try await waitForExternalNativeJourney(token: widthToken, window: window)
            }
            try await settle(hosting)
            let results = try XCTUnwrap(model.workspaceSearchProjection?.results)
            XCTAssertEqual(results.map(\.project.registrationID).sorted(), [
                "same-name-registration-a",
                "same-name-registration-b",
            ])
            XCTAssertNotNil(model.selectedWorkspaceSearchResultID)
            let renderedWindow = try requiredAccessibilityWindow(title: window.title)
            for result in results {
                let row = try XCTUnwrap(accessibilityElement(
                    renderedWindow,
                    identifier: "workspace-search-result-\(result.id.base64EncodedString())"
                ))
                XCTAssertFalse(accessibilityText(row).contains("Registration"))
            }
            let selectedID = try XCTUnwrap(model.selectedWorkspaceSearchResultID)
            let selected = try XCTUnwrap(results.first { $0.id == selectedID })
            let detail = try XCTUnwrap(accessibilityElement(renderedWindow, identifier: "workspace-search-detail"))
            XCTAssertTrue(accessibilityText(detail).contains(selected.project.registrationID))
        }
        try capture(hosting, name: "phase6e-search-same-name-compact")
    }

    private func activePhase(in store: DeliveryStore, projectID: ProjectID) async throws -> String? {
        try await store.read {
            try $0.scalarText(
                "SELECT phase_id FROM project_active_phases WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
    }

    private func waitForExternalNativeJourney(token: String, window: NSWindow) async throws {
        XCTAssertFalse(token.isEmpty)
        let controlDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-phase6e-native-\(token)", isDirectory: true)
        try FileManager.default.createDirectory(at: controlDirectory, withIntermediateDirectories: true)
        let readyURL = controlDirectory.appendingPathComponent("ready")
        let completeURL = controlDirectory.appendingPathComponent("complete")
        XCTAssertFalse(FileManager.default.fileExists(atPath: readyURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: completeURL.path))
        let identity = "token=\(token)\npid=\(ProcessInfo.processInfo.processIdentifier)\nwindow=\(window.title)\ncontrol=\(controlDirectory.path)\n"
        XCTAssertTrue(FileManager.default.createFile(atPath: readyURL.path, contents: Data(identity.utf8)))
        print("PHASE6E NATIVE READY: \(identity.replacingOccurrences(of: "\n", with: " "))")

        for _ in 0..<1_200 where !FileManager.default.fileExists(atPath: completeURL.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        let completion = try String(contentsOf: completeURL, encoding: .utf8)
        XCTAssertEqual(completion.trimmingCharacters(in: .whitespacesAndNewlines), token)
    }

    private func accessibilityWindow(title: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success else {
            return nil
        }
        return (value as? [AXUIElement])?.first {
            accessibilityAttribute($0, kAXTitleAttribute) == title
        }
    }

    private func requiredAccessibilityWindow(title: String) throws -> AXUIElement {
        guard let window = accessibilityWindow(title: title) else {
            throw XCTSkip(
                "The XCTest host exposed no self-AX windows after Search took focus; run the disposable external native toolbar journey for keyboard and AX verification."
            )
        }
        return window
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        var inspected = 0
        while let element = pending.popLast(), inspected < 3_000 {
            inspected += 1
            if accessibilityAttribute(element, kAXIdentifierAttribute) == identifier { return element }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }

    private func accessibilityAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func accessibilityBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    private func press(_ element: AXUIElement) throws {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard result == .success else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result.rawValue))
        }
    }

    private func settle<V: View>(_ hosting: NSHostingView<V>) async throws {
        try await Task.sleep(for: .milliseconds(200))
        hosting.layoutSubtreeIfNeeded()
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root]
        var text: [String] = []
        var inspected = 0
        while let element = pending.popLast(), inspected < 3_000 {
            inspected += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                if let value = accessibilityAttribute(element, attribute) { text.append(value) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return text.joined(separator: "\n")
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
}

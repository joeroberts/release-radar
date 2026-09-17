import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionLifecycleTests: XCTestCase {
    private struct Fixture {
        let store: DeliveryStore
        let files: ProjectExecutionFileStore
        let assignment: ProjectExecutionAssignment
        let scope: AuditScope
    }
    private func fixture(observeAtConstruction: Bool = false) async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let execution = root.appendingPathComponent("Execution")
        let executionRoot: @Sendable () throws -> URL = { execution }
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("fixture.sqlite"), executionAssignmentRoot: observeAtConstruction ? executionRoot : nil)
        let project = ProjectID(rawValue: "project-one")
        let registration = ProjectRegistration(projectID: project, registrationID: "registration-one", requestGeneration: 1)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed current registered work") { c in
            try c.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('project-one','Fixture',1)")
            try c.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root-one','project-one',?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id,path,bookmark_data,is_stale) VALUES ('project-one',?, ?,0)", bindings: [.text(root.path), .blob(Data([0]))])
            try c.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('project-one','registration-one',1,'complete')")
            try DeliveryPlanningPolicy.upsertPhase(projectID: project, phaseID: .init(rawValue: "phase-one"), name: "Phase", mode: .governed, connection: c)
            try c.execute("UPDATE phase_lifecycles SET lifecycle='in_delivery',revision=2 WHERE project_id='project-one' AND phase_id='phase-one'")
            try c.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('ticket-one','project-one','phase-one','Approved outcome','in_progress')")
            _ = try TicketTaskPlanningPolicy.revisePlan(projectID: project, ticketID: .init(rawValue: "ticket-one"), expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "work-one"), label: "A", title: "Approved task", sortOrder: 0)], definitionRevisions: [], supersededTaskIDs: [], connection: c)
            // A deferred constraint exercises a genuine failure at COMMIT, after
            // conservative filesystem revocation, without a validator or mock.
            try c.execute("CREATE TABLE late_failure (project_id TEXT REFERENCES projects(id) DEFERRABLE INITIALLY DEFERRED)")
        }
        let work = try await store.read { c in
            try ProjectExecutionWork.read(projectID: project, ticketID: "ticket-one", taskID: "work-one", taskPlanRevision: 1, phaseRevision: 2, connection: c)
        }
        let files = try ProjectExecutionFileStore(root: execution, create: true)
        let policy = ProjectExecutionPolicy(registration: registration, primaryRoot: root.path, appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/RR/handler")
        try files.savePolicy(policy, expected: nil)
        let assignment = ProjectExecutionAssignment(id: "assignment-one", registration: registration, checkoutPath: execution.appendingPathComponent("Worktrees/project-one/assignment-one").path,
            role: .delivery, permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: "medium", authorization: "Existing authorized work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))], excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], work: work)
        try files.saveAssignment(assignment, expected: nil)
        if !observeAtConstruction { try await store.observeExecutionAssignments(root: { execution }) }
        return .init(store: store, files: files, assignment: assignment, scope: .init(projectID: project, entityType: .ticketTaskPlan, entityID: "ticket-one"))
    }

    func testChangedAssignedWorkRevokesBeforeCommitAndUnrelatedScopePreservesLease() async throws {
        let f = try await fixture()
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Unrelated evidence", auditScope: .init(projectID: f.scope.projectID, entityType: .evidence, entityID: "evidence-one")) { _ in }
        XCTAssertEqual(try f.files.assignment(projectID: "project-one", taskID: "assignment-one").state, .authorized)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Revise assigned work", auditScope: f.scope) { c in
            try c.execute("UPDATE ticket_tasks SET title='Changed task' WHERE project_id='project-one' AND ticket_id='ticket-one'")
        }
        XCTAssertEqual(try f.files.assignment(projectID: "project-one", taskID: "assignment-one").state, .revoked)
    }

    func testConstructionConfiguredObserverProtectsMutationBeforeBridgeStartup() async throws {
        let f = try await fixture(observeAtConstruction: true)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Change before bridge startup", auditScope: f.scope) { c in
            try c.execute("UPDATE ticket_tasks SET title='Changed task' WHERE project_id='project-one' AND ticket_id='ticket-one'")
        }
        XCTAssertEqual(try f.files.assignment(projectID: "project-one", taskID: "assignment-one").state, .revoked)
    }

    func testSqlRollbackNeverReauthorizesRevokedFilesystemLease() async throws {
        let f = try await fixture()
        do {
            try await f.store.transact(actor: .init(id: "fixture"), reason: "Fail after revocation", auditScope: f.scope) { c in
                try c.execute("UPDATE ticket_tasks SET title='Changed task' WHERE project_id='project-one' AND ticket_id='ticket-one'")
                try c.execute("INSERT INTO late_failure (project_id) VALUES ('missing-project')")
            }
            XCTFail("Deferred constraint must fail COMMIT")
        } catch {}
        let title = try await f.store.read { try $0.scalarText("SELECT title FROM ticket_tasks WHERE project_id='project-one' AND ticket_id='ticket-one'") }
        XCTAssertEqual(title, "Approved task")
        XCTAssertEqual(try f.files.assignment(projectID: "project-one", taskID: "assignment-one").state, .revoked)
    }

    func testFailedRevocationBlocksWorkMutationAndPreservesSqlState() async throws {
        let f = try await fixture()
        let lock = f.files.root.appendingPathComponent("Assignments/project-one/assignment-one/.assignment.json.lock")
        try FileManager.default.removeItem(at: lock)
        try FileManager.default.createSymbolicLink(at: lock, withDestinationURL: f.files.root.appendingPathComponent("Projects/project-one/policy.json"))
        do {
            try await f.store.transact(actor: .init(id: "fixture"), reason: "Revocation unavailable", auditScope: f.scope) { c in
                try c.execute("UPDATE ticket_tasks SET title='Changed task' WHERE project_id='project-one' AND ticket_id='ticket-one'")
            }
            XCTFail("Unrecorded revocation must not commit an authority mutation")
        } catch {}
        let title = try await f.store.read { try $0.scalarText("SELECT title FROM ticket_tasks WHERE project_id='project-one' AND ticket_id='ticket-one'") }
        XCTAssertEqual(title, "Approved task")
        XCTAssertEqual(try f.files.assignment(projectID: "project-one", taskID: "assignment-one").state, .authorized)
    }
}
